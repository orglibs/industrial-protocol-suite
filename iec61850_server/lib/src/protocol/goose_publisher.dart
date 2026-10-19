import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../models/scl_models.dart';
import '../models/server_variable_model.dart';
import '../services/traffic_logger.dart';
import 'iso_acse_mms.dart';

class GoosePublisherItem {
  final SclGSEControl control;
  final SclDataSet? dataSet;
  final List<ServerVariableModel> variables;
  bool isPublishing = false;

  int stNum = 1;
  int sqNum = 0;
  int minTimeMs = 10;
  int maxTimeMs = 1000;
  int currentIntervalMs = 1000;
  DateTime? lastPublishTime;
  Uint8List? lastPacket;
  int totalPacketsSent = 0;

  Timer? _timer;

  GoosePublisherItem({
    required this.control,
    required this.dataSet,
    required this.variables,
  });

  void start() {
    isPublishing = true;
    currentIntervalMs = maxTimeMs;
    _scheduleNext();
  }

  void stop() {
    isPublishing = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Triggers a state change (stNum++, sqNum=0, fast retransmission)
  void triggerDataChange() {
    stNum++;
    sqNum = 0;
    currentIntervalMs = minTimeMs;
    _publishNow();
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (!isPublishing) return;

    _timer = Timer(Duration(milliseconds: currentIntervalMs), () {
      sqNum++;
      _publishNow();
      // Exponential backoff until reaching maxTimeMs
      if (currentIntervalMs < maxTimeMs) {
        currentIntervalMs = (currentIntervalMs * 2).clamp(minTimeMs, maxTimeMs);
      }
      _scheduleNext();
    });
  }

  void _publishNow() {
    final packet = buildGoosePacket();
    lastPacket = packet;
    lastPublishTime = DateTime.now();
    totalPacketsSent++;

    TrafficLogger.instance.log(
      direction: TrafficDirection.tx,
      clientEndpoint: 'Multicast 01-0C-CD-01-00-01 (APPID: ${control.appId})',
      protocol: 'GOOSE (IEC 61850-8-1)',
      service: 'GOOSE PDU [stNum: $stNum, sqNum: $sqNum]',
      rawBytes: packet,
      summary: 'GOOSE ${control.name} published with ${variables.length} items',
      details: 'GocbRef: ${control.name}, DatSet: ${control.datSet}, StNum: $stNum, SqNum: $sqNum',
    );
  }

  Uint8List buildGoosePacket() {
    // Build allData sequence (Tag 0xAB)
    final dataItems = <Uint8List>[];
    for (final v in variables) {
      dataItems.add(MmsValueEncoder.encodeVariable(v));
    }
    final allDataPayload = Uint8List.fromList(dataItems.expand((b) => b).toList());
    final allDataTlv = BerTlv(0xAB, allDataPayload).encode();

    // GOOSE PDU Fields
    final gocbRef = BerTlv(0x80, Uint8List.fromList(utf8.encode(control.name))).encode();
    final timeAllowedToLive = BerTlv(0x81, Uint8List.fromList([(maxTimeMs * 2 >> 8) & 0xFF, (maxTimeMs * 2) & 0xFF])).encode();
    final datSet = BerTlv(0x82, Uint8List.fromList(utf8.encode(control.datSet))).encode();
    final goId = BerTlv(0x83, Uint8List.fromList(utf8.encode(control.goId.isNotEmpty ? control.goId : control.name))).encode();

    // UtcTime (8B)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final tBytes = Uint8List(8);
    final bd = ByteData.sublistView(tBytes);
    bd.setUint32(0, nowMs ~/ 1000, Endian.big);
    bd.setUint32(4, (((nowMs % 1000) * 16777216) ~/ 1000) << 8 | 0x0A, Endian.big);
    final t = BerTlv(0x84, tBytes).encode();

    final stNumBytes = BerTlv(0x85, Uint8List.fromList([(stNum >> 8) & 0xFF, stNum & 0xFF])).encode();
    final sqNumBytes = BerTlv(0x86, Uint8List.fromList([(sqNum >> 8) & 0xFF, sqNum & 0xFF])).encode();
    final testBytes = BerTlv(0x87, Uint8List.fromList([0x00])).encode(); // false
    final confRevBytes = BerTlv(0x88, Uint8List.fromList([control.confRev & 0xFF])).encode();
    final ndsComBytes = BerTlv(0x89, Uint8List.fromList([0x00])).encode(); // false
    final numEntriesBytes = BerTlv(0x8A, Uint8List.fromList([variables.length & 0xFF])).encode();

    final goosePayload = Uint8List.fromList([
      ...gocbRef,
      ...timeAllowedToLive,
      ...datSet,
      ...goId,
      ...t,
      ...stNumBytes,
      ...sqNumBytes,
      ...testBytes,
      ...confRevBytes,
      ...ndsComBytes,
      ...numEntriesBytes,
      ...allDataTlv,
    ]);

    // Tag 0x61 = goosePdu
    final goosePdu = BerTlv(0x61, goosePayload).encode();

    // IEC 61850-8-1 Ethertype Header:
    // APPID (2B) + Length (2B) + Reserved1 (2B) + Reserved2 (2B)
    final appIdInt = control.appId;
    final totalLen = 8 + goosePdu.length;
    final header = Uint8List(8);
    final hbd = ByteData.sublistView(header);
    hbd.setUint16(0, appIdInt, Endian.big);
    hbd.setUint16(2, totalLen, Endian.big);
    hbd.setUint16(4, 0x0000, Endian.big); // Reserved 1
    hbd.setUint16(6, 0x0000, Endian.big); // Reserved 2

    return Uint8List.fromList([...header, ...goosePdu]);
  }
}

class GoosePublisherService {
  static final GoosePublisherService instance = GoosePublisherService._();
  GoosePublisherService._();
  GoosePublisherService();

  final List<GoosePublisherItem> _items = [];
  final List<void Function()> _listeners = [];

  List<GoosePublisherItem> get items => List.unmodifiable(_items);

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void notifyUpdated() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void initialize({
    required List<SclGSEControl> controls,
    required List<SclDataSet> dataSets,
    required List<ServerVariableModel> allVariables,
  }) {
    stopAll();
    _items.clear();

    final dsMap = {for (final ds in dataSets) ds.name: ds};

    for (final c in controls) {
      final ds = dsMap[c.datSet];
      final vars = <ServerVariableModel>[];
      if (ds != null) {
        for (final fcda in ds.entries) {
          // Match variable by LD/LN/DO/DA
          for (final v in allVariables) {
            if (v.ldInst == fcda.ldInst && v.lnName == fcda.fullLnName && v.doName == fcda.doName) {
              if (fcda.daName == null || v.daName == fcda.daName) {
                vars.add(v);
              }
            }
          }
        }
      }
      _items.add(GoosePublisherItem(
        control: c,
        dataSet: ds,
        variables: vars,
      ));
    }
    notifyUpdated();
  }

  void startAll() {
    for (final item in _items) {
      item.start();
    }
    notifyUpdated();
  }

  void stopAll() {
    for (final item in _items) {
      item.stop();
    }
    notifyUpdated();
  }

  void toggleItem(GoosePublisherItem item) {
    if (item.isPublishing) {
      item.stop();
    } else {
      item.start();
    }
    notifyUpdated();
  }

  void triggerItemEvent(GoosePublisherItem item) {
    item.triggerDataChange();
    notifyUpdated();
  }
}
