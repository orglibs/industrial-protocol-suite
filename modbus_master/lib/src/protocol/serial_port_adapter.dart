import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

typedef _COpen = Int32 Function(Pointer<Uint8> pathname, Int32 flags);
typedef _DartOpen = int Function(Pointer<Uint8> pathname, int flags);

typedef _CClose = Int32 Function(Int32 fd);
typedef _DartClose = int Function(int fd);

typedef _CRead = IntPtr Function(Int32 fd, Pointer<Uint8> buf, IntPtr count);
typedef _DartRead = int Function(int fd, Pointer<Uint8> buf, int count);

typedef _CWrite = IntPtr Function(Int32 fd, Pointer<Uint8> buf, IntPtr count);
typedef _DartWrite = int Function(int fd, Pointer<Uint8> buf, int count);

typedef _CMalloc = Pointer<Uint8> Function(IntPtr size);
typedef _DartMalloc = Pointer<Uint8> Function(int size);

typedef _CFree = Void Function(Pointer<Void> ptr);
typedef _DartFree = void Function(Pointer<Void> ptr);

class SerialPortAdapter {
  String portName;
  int baudRate;
  int dataBits;
  int parity; // 0: None, 1: Odd, 2: Even
  int stopBits;

  int _fd = -1;
  bool get isOpen => _fd >= 0;

  Timer? _readTimer;
  Pointer<Uint8>? _rxNativeBuf;
  static const int _bufSize = 1024;

  final StreamController<Uint8List> _dataController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get onData => _dataController.stream;

  // Libc handles
  DynamicLibrary? _libc;
  _DartOpen? _cOpen;
  _DartClose? _cClose;
  _DartRead? _cRead;
  _DartWrite? _cWrite;
  _DartMalloc? _cMalloc;
  _DartFree? _cFree;

  SerialPortAdapter({
    this.portName = '/dev/ttyUSB0',
    this.baudRate = 9600,
    this.dataBits = 8,
    this.parity = 0,
    this.stopBits = 1,
  }) {
    _initLibc();
  }

  void _initLibc() {
    try {
      if (Platform.isLinux || Platform.isAndroid) {
        _libc = DynamicLibrary.open('libc.so.6');
      } else if (Platform.isMacOS) {
        _libc = DynamicLibrary.open('libSystem.B.dylib');
      }

      if (_libc != null) {
        _cOpen = _libc!.lookupFunction<_COpen, _DartOpen>('open');
        _cClose = _libc!.lookupFunction<_CClose, _DartClose>('close');
        _cRead = _libc!.lookupFunction<_CRead, _DartRead>('read');
        _cWrite = _libc!.lookupFunction<_CWrite, _DartWrite>('write');
        _cMalloc = _libc!.lookupFunction<_CMalloc, _DartMalloc>('malloc');
        _cFree = _libc!.lookupFunction<_CFree, _DartFree>('free');
      }
    } catch (_) {
      // Libc not available on Windows without specialized wrapper
    }
  }

  /// Discovers available serial ports in the system
  static List<String> getAvailablePorts() {
    final ports = <String>{};

    if (Platform.isLinux) {
      // 1. Check /sys/class/tty/ for hardware devices
      try {
        final dir = Directory('/sys/class/tty');
        if (dir.existsSync()) {
          for (final entity in dir.listSync()) {
            final name = entity.path.split('/').last;
            // Filter real hardware or USB serial devices
            if (File('${entity.path}/device').existsSync() ||
                name.startsWith('ttyUSB') ||
                name.startsWith('ttyACM')) {
              ports.add('/dev/$name');
            }
          }
        }
      } catch (_) {}

      // 2. Scan /dev directly for USB or ACM serial
      try {
        final devDir = Directory('/dev');
        if (devDir.existsSync()) {
          for (final entity in devDir.listSync()) {
            final path = entity.path;
            if (path.startsWith('/dev/ttyUSB') ||
                path.startsWith('/dev/ttyACM')) {
              ports.add(path);
            }
          }
        }
      } catch (_) {}
    } else if (Platform.isWindows) {
      for (int i = 1; i <= 16; i++) {
        ports.add('COM$i');
      }
    } else if (Platform.isMacOS) {
      try {
        final devDir = Directory('/dev');
        for (final entity in devDir.listSync()) {
          final p = entity.path;
          if (p.startsWith('/dev/cu.') || p.startsWith('/dev/tty.')) {
            ports.add(p);
          }
        }
      } catch (_) {}
    }

    final sorted = ports.toList()..sort((a, b) {
      // Prioritize USB and ACM ports
      final aUsb = a.contains('USB') || a.contains('ACM');
      final bUsb = b.contains('USB') || b.contains('ACM');
      if (aUsb && !bUsb) return -1;
      if (!aUsb && bUsb) return 1;
      return a.compareTo(b);
    });

    return sorted;
  }

  /// Opens the serial port with configured baud rate, parity, data bits, stop bits
  Future<void> open() async {
    if (isOpen) close();

    if (_cOpen == null || _cWrite == null || _cRead == null) {
      throw Exception('Underlying C serial interface not loaded on current platform');
    }

    if (Platform.isLinux || Platform.isMacOS) {
      // Configure termios via stty
      final sttyArgs = <String>['-F', portName, 'raw', '$baudRate'];
      if (dataBits == 7) {
        sttyArgs.addAll(['cs7']);
      } else {
        sttyArgs.addAll(['cs8']);
      }

      if (parity == 1) {
        sttyArgs.addAll(['parenb', 'parodd']); // Odd
      } else if (parity == 2) {
        sttyArgs.addAll(['parenb', '-parodd']); // Even
      } else {
        sttyArgs.addAll(['-parenb']); // None
      }

      if (stopBits == 2) {
        sttyArgs.add('cstopb');
      } else {
        sttyArgs.add('-cstopb');
      }

      sttyArgs.addAll(['-echo', '-echoe', '-echok', '-echonl', '-noflsh']);

      try {
        final res = await Process.run('stty', sttyArgs);
        if (res.exitCode != 0 && !portName.startsWith('/dev/pts/')) {
          // If stty had an error on a real device, still attempt opening
        }
      } catch (_) {}
    }

    // Allocate C string path
    final pathBytes = utf8.encode(portName);
    final cPath = _cMalloc!(pathBytes.length + 1);
    for (int i = 0; i < pathBytes.length; i++) {
      cPath[i] = pathBytes[i];
    }
    cPath[pathBytes.length] = 0;

    // O_RDWR (2) | O_NOCTTY (256) | O_NONBLOCK (2048) = 2306
    _fd = _cOpen!(cPath, 2306);
    _cFree!(cPath.cast());

    if (_fd < 0) {
      throw Exception('Cannot open serial port "$portName" (Permission denied or port in use. Try: sudo chmod 666 $portName)');
    }

    _rxNativeBuf = _cMalloc!(_bufSize);

    // Start cyclic read loop (every 10ms)
    _readTimer = Timer.periodic(const Duration(milliseconds: 10), (_) => _pollRead());
  }

  void _pollRead() {
    if (_fd < 0 || _cRead == null || _rxNativeBuf == null) return;

    final bytesRead = _cRead!(_fd, _rxNativeBuf!, _bufSize);
    if (bytesRead > 0) {
      final data = Uint8List(bytesRead);
      for (int i = 0; i < bytesRead; i++) {
        data[i] = _rxNativeBuf![i];
      }
      _dataController.add(data);
    }
  }

  /// Transmits raw Modbus RTU bytes across the serial bus
  void write(Uint8List data) {
    if (!isOpen || _cWrite == null) {
      throw Exception('Serial port is not open, unable to transmit data');
    }

    final txBuf = _cMalloc!(data.length);
    for (int i = 0; i < data.length; i++) {
      txBuf[i] = data[i];
    }

    _cWrite!(_fd, txBuf, data.length);
    _cFree!(txBuf.cast());
  }

  void close() {
    _readTimer?.cancel();
    _readTimer = null;

    if (_rxNativeBuf != null && _cFree != null) {
      _cFree!(_rxNativeBuf!.cast());
      _rxNativeBuf = null;
    }

    if (_fd >= 0 && _cClose != null) {
      _cClose!(_fd);
      _fd = -1;
    }
  }

  void dispose() {
    close();
    _dataController.close();
  }
}
