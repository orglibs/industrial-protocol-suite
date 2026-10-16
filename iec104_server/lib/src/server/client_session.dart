import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../protocol/apci.dart';
import '../protocol/asdu.dart';
import '../protocol/asdu_types.dart';
import '../protocol/codec.dart';
import 'station.dart';
import 'traffic_logger.dart';

typedef CommandCallback = void Function(Asdu command, StationPoint? point);

class ClientSession {
  final Socket? socket;
  final String remoteAddress;
  final int sessionId;
  final Map<int, Station> stations;
  final CommandCallback? onCommandReceived;
  final void Function(ClientSession session)? onClosed;
  final void Function(ClientSession session)? onStateChanged;

  // Protocol parameters
  final int t0Seconds; // Connection timeout (default 30)
  final int t1Seconds; // APDU send timeout (default 15)
  final int t2Seconds; // ACK timeout (default 10)
  final int t3Seconds; // Test frame timeout (default 20)
  final int k;         // Max unacknowledged I frames (default 12)
  final int w;         // Send ACK after w I frames (default 8)

  final int cotSize;
  final int caSize;
  final int ioaSize;

  // State
  bool isDataTransferActive = false;
  int txSeq = 0; // Transmit sequence number N(S)
  int rxSeq = 0; // Receive sequence number N(R)
  int _unconfirmedRxCount = 0;
  Timer? _t2Timer;
  Timer? _t3Timer;

  final BytesBuilder _rxBuffer = BytesBuilder();
  StreamSubscription<Uint8List>? _subscription;

  ClientSession({
    this.socket,
    String? customRemoteAddress,
    required this.sessionId,
    required this.stations,
    this.onCommandReceived,
    this.onClosed,
    this.onStateChanged,
    this.t0Seconds = 30,
    this.t1Seconds = 15,
    this.t2Seconds = 10,
    this.t3Seconds = 20,
    this.k = 12,
    this.w = 8,
    this.cotSize = 2,
    this.caSize = 2,
    this.ioaSize = 3,
  }) : remoteAddress = customRemoteAddress ??
            (socket != null ? '${socket.remoteAddress.address}:${socket.port}' : 'VirtualClient') {
    _init();
  }

  void _init() {
    if (socket != null) {
      _subscription = socket!.listen(
        _onData,
        onError: (err) => close(),
        onDone: () => close(),
        cancelOnError: true,
      );
    }
    _restartT3Timer();
  }

  /// Injects incoming raw bytes (for virtual client or direct pipe)
  void receiveBytes(Uint8List data) => _onData(data);

  void _onData(Uint8List data) {
    _rxBuffer.add(data);
    _processRxBuffer();
  }

  void _processRxBuffer() {
    Uint8List buffer = _rxBuffer.toBytes();

    while (buffer.isNotEmpty) {
      // Find 0x68 start byte
      int startIdx = buffer.indexOf(0x68);
      if (startIdx == -1) {
        _rxBuffer.clear();
        return;
      }

      if (startIdx > 0) {
        buffer = buffer.sublist(startIdx);
      }

      if (buffer.length < 2) {
        _rxBuffer.clear();
        _rxBuffer.add(buffer);
        return;
      }

      final length = buffer[1];
      final totalFrameLen = 2 + length;

      if (buffer.length < totalFrameLen) {
        // Frame not fully received yet
        _rxBuffer.clear();
        _rxBuffer.add(buffer);
        return;
      }

      final frameBytes = Uint8List.fromList(buffer.sublist(0, totalFrameLen));
      buffer = buffer.sublist(totalFrameLen);

      _rxBuffer.clear();
      if (buffer.isNotEmpty) {
        _rxBuffer.add(buffer);
      }

      _handleIncomingFrame(frameBytes);
    }
  }

  void _handleIncomingFrame(Uint8List rawFrame) {
    TrafficLogger.instance.log(
      direction: TrafficDirection.rx,
      remoteAddress: remoteAddress,
      rawBytes: rawFrame,
      cotSize: cotSize,
      caSize: caSize,
      ioaSize: ioaSize,
    );

    try {
      final apci = ApciHeader.decode(rawFrame);

      switch (apci.type) {
        case ApciType.uFormat:
          _handleUFormat(apci);
          break;

        case ApciType.sFormat:
          _handleSFormat(apci);
          break;

        case ApciType.iFormat:
          _handleIFormat(apci, rawFrame);
          break;
      }
    } catch (e) {
      // Frame parsing error
    }

    _restartT3Timer();
  }

  void _handleUFormat(ApciHeader apci) {
    switch (apci.uType) {
      case UFormatType.startDtAct:
        isDataTransferActive = true;
        _sendUFormat(UFormatType.startDtCon);
        onStateChanged?.call(this);
        // Optional: send End of Initialization
        _sendEndOfInitialization();
        break;

      case UFormatType.stopDtAct:
        isDataTransferActive = false;
        _sendUFormat(UFormatType.stopDtCon);
        onStateChanged?.call(this);
        break;

      case UFormatType.testFrAct:
        _sendUFormat(UFormatType.testFrCon);
        break;

      default:
        break;
    }
  }

  void _handleSFormat(ApciHeader apci) {
    // Master is acknowledging our transmitted I frames up to apci.rxSeq
  }

  void _handleIFormat(ApciHeader apci, Uint8List rawFrame) {
    // Update our receive sequence number N(R)
    rxSeq = ((apci.txSeq ?? 0) + 1) & 0x7FFF;
    _unconfirmedRxCount++;

    if (_unconfirmedRxCount >= w) {
      _sendSFormat();
    } else {
      _startT2Timer();
    }

    // Decode and process ASDU if present
    if (rawFrame.length > 6) {
      try {
        final asdu = Iec104Codec.decodeAsdu(
          rawFrame,
          6,
          rawFrame.length - 6,
          cotSize: cotSize,
          caSize: caSize,
          ioaSize: ioaSize,
        );
        _processAsdu(asdu);
      } catch (_) {}
    }
  }

  void _processAsdu(Asdu asdu) {
    final station = stations[asdu.commonAddress] ?? stations.values.firstOrNull;

    switch (asdu.typeId) {
      // 1. General Interrogation (总召唤 C_IC_NA_1 / Type 100)
      case AsduTypeId.cIcNa1:
        _handleGeneralInterrogation(asdu, station);
        break;

      // 2. Counter Interrogation (电能量总召唤 C_CI_NA_1 / Type 101)
      case AsduTypeId.cCiNa1:
        _handleCounterInterrogation(asdu, station);
        break;

      // 3. Read Command (读命令 C_RD_NA_1 / Type 102)
      case AsduTypeId.cRdNa1:
        _handleReadCommand(asdu, station);
        break;

      // 4. Clock Synchronization (时钟同步 C_CS_NA_1 / Type 103)
      case AsduTypeId.cCsNa1:
        _handleClockSynchronization(asdu);
        break;

      // 5. Reset Process (复位进程 C_RP_NA_1 / Type 105)
      case AsduTypeId.cRpNa1:
        _handleResetProcess(asdu);
        break;

      // 6. Remote Control Commands (遥控与设定值命令)
      case AsduTypeId.cScNa1:
      case AsduTypeId.cScTa1:
      case AsduTypeId.cDcNa1:
      case AsduTypeId.cDcTa1:
      case AsduTypeId.cRcNa1:
      case AsduTypeId.cRcTa1:
      case AsduTypeId.cSeNa1:
      case AsduTypeId.cSeTa1:
      case AsduTypeId.cSeNb1:
      case AsduTypeId.cSeTb1:
      case AsduTypeId.cSeNc1:
      case AsduTypeId.cSeTc1:
      case AsduTypeId.cBoNa1:
      case AsduTypeId.cBoTa1:
        _handleControlCommand(asdu, station);
        break;

      default:
        break;
    }
  }

  /// Handles General Interrogation (GI / 总召唤)
  void _handleGeneralInterrogation(Asdu asdu, Station? station) {
    final ca = asdu.commonAddress;

    // Step 1: Send Activation Confirmation (COT=7 ActCon)
    sendAsdu(Asdu(
      typeId: AsduTypeId.cIcNa1,
      cot: CauseOfTransmission.activationConfirmation,
      commonAddress: ca,
      objects: asdu.objects,
    ));

    if (station != null) {
      // Step 2: Send all Single Points (COT=20)
      final spObjects = station.pointList
          .where((p) => p.typeId == AsduTypeId.mSpNa1 || p.typeId == AsduTypeId.mSpTb1)
          .map((p) => p.toInformationObject())
          .toList();
      if (spObjects.isNotEmpty) {
        sendAsdu(Asdu(
          typeId: AsduTypeId.mSpNa1,
          cot: CauseOfTransmission.interrogatedByStation,
          commonAddress: ca,
          objects: spObjects,
        ));
      }

      // Send all Double Points (COT=20)
      final dpObjects = station.pointList
          .where((p) => p.typeId == AsduTypeId.mDpNa1 || p.typeId == AsduTypeId.mDpTb1)
          .map((p) => p.toInformationObject())
          .toList();
      if (dpObjects.isNotEmpty) {
        sendAsdu(Asdu(
          typeId: AsduTypeId.mDpNa1,
          cot: CauseOfTransmission.interrogatedByStation,
          commonAddress: ca,
          objects: dpObjects,
        ));
      }

      // Send all Step Position points (COT=20)
      final stObjects = station.pointList
          .where((p) => p.typeId == AsduTypeId.mStNa1 || p.typeId == AsduTypeId.mStTb1)
          .map((p) => p.toInformationObject())
          .toList();
      if (stObjects.isNotEmpty) {
        sendAsdu(Asdu(
          typeId: AsduTypeId.mStNa1,
          cot: CauseOfTransmission.interrogatedByStation,
          commonAddress: ca,
          objects: stObjects,
        ));
      }

      // Send all Normalized Measured values (COT=20)
      final meNaObjects = station.pointList
          .where((p) => p.typeId == AsduTypeId.mMeNa1 || p.typeId == AsduTypeId.mMeTd1)
          .map((p) => p.toInformationObject())
          .toList();
      if (meNaObjects.isNotEmpty) {
        sendAsdu(Asdu(
          typeId: AsduTypeId.mMeNa1,
          cot: CauseOfTransmission.interrogatedByStation,
          commonAddress: ca,
          objects: meNaObjects,
        ));
      }

      // Send all Scaled Measured values (COT=20)
      final meNbObjects = station.pointList
          .where((p) => p.typeId == AsduTypeId.mMeNb1 || p.typeId == AsduTypeId.mMeTe1)
          .map((p) => p.toInformationObject())
          .toList();
      if (meNbObjects.isNotEmpty) {
        sendAsdu(Asdu(
          typeId: AsduTypeId.mMeNb1,
          cot: CauseOfTransmission.interrogatedByStation,
          commonAddress: ca,
          objects: meNbObjects,
        ));
      }

      // Send all Short Float values (COT=20)
      final meNcObjects = station.pointList
          .where((p) => p.typeId == AsduTypeId.mMeNc1 || p.typeId == AsduTypeId.mMeTf1)
          .map((p) => p.toInformationObject())
          .toList();
      if (meNcObjects.isNotEmpty) {
        sendAsdu(Asdu(
          typeId: AsduTypeId.mMeNc1,
          cot: CauseOfTransmission.interrogatedByStation,
          commonAddress: ca,
          objects: meNcObjects,
        ));
      }
    }

    // Step 3: Send Activation Termination (COT=10 ActTerm)
    sendAsdu(Asdu(
      typeId: AsduTypeId.cIcNa1,
      cot: CauseOfTransmission.activationTermination,
      commonAddress: ca,
      objects: asdu.objects,
    ));
  }

  /// Handles Counter Interrogation (电能量总召)
  void _handleCounterInterrogation(Asdu asdu, Station? station) {
    final ca = asdu.commonAddress;

    // Send ActCon (COT=7)
    sendAsdu(Asdu(
      typeId: AsduTypeId.cCiNa1,
      cot: CauseOfTransmission.activationConfirmation,
      commonAddress: ca,
      objects: asdu.objects,
    ));

    if (station != null) {
      final counterObjects = station.pointList
          .where((p) => p.typeId == AsduTypeId.mItNa1 || p.typeId == AsduTypeId.mItTb1)
          .map((p) => p.toInformationObject())
          .toList();
      if (counterObjects.isNotEmpty) {
        sendAsdu(Asdu(
          typeId: AsduTypeId.mItNa1,
          cot: CauseOfTransmission.interrogatedByCounter,
          commonAddress: ca,
          objects: counterObjects,
        ));
      }
    }

    // Send ActTerm (COT=10)
    sendAsdu(Asdu(
      typeId: AsduTypeId.cCiNa1,
      cot: CauseOfTransmission.activationTermination,
      commonAddress: ca,
      objects: asdu.objects,
    ));
  }

  /// Handles Read Command (读命令)
  void _handleReadCommand(Asdu asdu, Station? station) {
    if (asdu.objects.isEmpty || station == null) return;
    final reqIoa = asdu.objects.first.ioa;
    final point = station.getPoint(reqIoa);
    if (point != null) {
      sendAsdu(Asdu(
        typeId: point.typeId,
        cot: CauseOfTransmission.request,
        commonAddress: asdu.commonAddress,
        objects: [point.toInformationObject()],
      ));
    }
  }

  /// Handles Clock Synchronization (时钟同步)
  void _handleClockSynchronization(Asdu asdu) {
    // Echo back ActCon (COT=7) with the same timestamp
    sendAsdu(Asdu(
      typeId: AsduTypeId.cCsNa1,
      cot: CauseOfTransmission.activationConfirmation,
      commonAddress: asdu.commonAddress,
      objects: asdu.objects,
    ));
  }

  /// Handles Reset Process
  void _handleResetProcess(Asdu asdu) {
    sendAsdu(Asdu(
      typeId: AsduTypeId.cRpNa1,
      cot: CauseOfTransmission.activationConfirmation,
      commonAddress: asdu.commonAddress,
      objects: asdu.objects,
    ));
  }

  /// Handles Remote Control Commands (遥控/设定值)
  void _handleControlCommand(Asdu asdu, Station? station) {
    if (asdu.objects.isEmpty) return;
    final obj = asdu.objects.first;
    StationPoint? targetPoint = station?.getPoint(obj.ioa);

    bool isSelect = false;
    dynamic targetValue;

    if (obj is SingleCommandObject) {
      isSelect = obj.isSelect;
      targetValue = obj.state;
    } else if (obj is DoubleCommandObject) {
      isSelect = obj.isSelect;
      targetValue = obj.state;
    } else if (obj is RegulatingStepCommandObject) {
      isSelect = obj.isSelect;
      if (targetPoint != null && targetPoint.value is num) {
        targetValue = (targetPoint.value as num) + (obj.step == 2 ? 1 : -1);
      }
    } else if (obj is SetpointNormalizedObject) {
      isSelect = obj.isSelect;
      targetValue = obj.value;
    } else if (obj is SetpointScaledObject) {
      isSelect = obj.isSelect;
      targetValue = obj.value;
    } else if (obj is SetpointShortFloatObject) {
      isSelect = obj.isSelect;
      targetValue = obj.value;
    } else if (obj is Bitstring32CommandObject) {
      targetValue = obj.value;
    }

    // Step 1: Send Activation Confirmation (COT=7)
    sendAsdu(Asdu(
      typeId: asdu.typeId,
      cot: CauseOfTransmission.activationConfirmation,
      commonAddress: asdu.commonAddress,
      objects: asdu.objects,
    ));

    // If Execute (not Select), apply the command to the point!
    if (!isSelect && targetPoint != null && targetValue != null) {
      station?.updatePointValue(targetPoint.ioa, targetValue);

      // Step 2: Send Activation Termination (COT=10)
      sendAsdu(Asdu(
        typeId: asdu.typeId,
        cot: CauseOfTransmission.activationTermination,
        commonAddress: asdu.commonAddress,
        objects: asdu.objects,
      ));

      // Step 3: Broadcast spontaneous change (COT=3)
      sendSpontaneous(targetPoint, asdu.commonAddress);
    }

    onCommandReceived?.call(asdu, targetPoint);
  }

  /// Sends a spontaneous event (COT=3) for a changed point
  void sendSpontaneous(StationPoint point, int commonAddress) {
    if (!isDataTransferActive) return;

    sendAsdu(Asdu(
      typeId: point.typeId,
      cot: CauseOfTransmission.spontaneous,
      commonAddress: commonAddress,
      objects: [point.toInformationObject(withTimestamp: true)],
    ));
  }

  /// Sends an ASDU formatted into an I-format frame
  void sendAsdu(Asdu asdu) {
    final currentTx = txSeq;
    final currentRx = rxSeq;

    txSeq = (txSeq + 1) & 0x7FFF;
    _unconfirmedRxCount = 0;
    _t2Timer?.cancel();

    final apci = ApciHeader.iFormat(
      txSeq: currentTx,
      rxSeq: currentRx,
      asduLength: 0, // Will be computed in encodeApdu
    );

    final rawBytes = Iec104Codec.encodeApdu(
      apci: apci,
      asdu: asdu,
      cotSize: cotSize,
      caSize: caSize,
      ioaSize: ioaSize,
    );

    _sendBytes(rawBytes);
  }

  void _sendUFormat(UFormatType uType) {
    final apci = ApciHeader.uFormat(uType: uType);
    _sendBytes(apci.encode());
  }

  void _sendSFormat() {
    _t2Timer?.cancel();
    _unconfirmedRxCount = 0;
    final apci = ApciHeader.sFormat(rxSeq: rxSeq);
    _sendBytes(apci.encode());
  }

  void _sendEndOfInitialization() {
    final ca = stations.keys.firstOrNull ?? 1;
    sendAsdu(Asdu(
      typeId: AsduTypeId.mEiNa1,
      cot: CauseOfTransmission.initialized,
      commonAddress: ca,
      objects: [EndOfInitObject(ioa: 0, coi: 0)],
    ));
  }

  void _sendBytes(Uint8List bytes) {
    try {
      if (socket != null) {
        socket!.add(bytes);
      }
      TrafficLogger.instance.log(
        direction: TrafficDirection.tx,
        remoteAddress: remoteAddress,
        rawBytes: bytes,
        cotSize: cotSize,
        caSize: caSize,
        ioaSize: ioaSize,
      );
    } catch (_) {
      close();
    }
  }

  void _startT2Timer() {
    _t2Timer?.cancel();
    _t2Timer = Timer(Duration(seconds: t2Seconds), () {
      if (_unconfirmedRxCount > 0) {
        _sendSFormat();
      }
    });
  }

  void _restartT3Timer() {
    _t3Timer?.cancel();
    _t3Timer = Timer(Duration(seconds: t3Seconds), () {
      // Send TESTFR act to test idle link
      _sendUFormat(UFormatType.testFrAct);
    });
  }

  void close() {
    _t2Timer?.cancel();
    _t3Timer?.cancel();
    _subscription?.cancel();
    try {
      socket?.destroy();
    } catch (_) {}
    onClosed?.call(this);
  }
}
