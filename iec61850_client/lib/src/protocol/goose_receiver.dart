import 'dart:convert';
import 'dart:typed_data';
import '../services/traffic_logger.dart';
import 'iso_acse_mms.dart';

class GooseMessage {
  final int appId;
  final String gocbRef;
  final int timeAllowedToLive;
  final String datSet;
  final String goId;
  final DateTime timestamp;
  final int stNum;
  final int sqNum;
  final bool test;
  final int confRev;
  final bool ndsCom;
  final int numDatSetEntries;
  final List<dynamic> allData;
  final Uint8List rawBytes;
  final DateTime receivedTime;

  GooseMessage({
    required this.appId,
    required this.gocbRef,
    required this.timeAllowedToLive,
    required this.datSet,
    required this.goId,
    required this.timestamp,
    required this.stNum,
    required this.sqNum,
    required this.test,
    required this.confRev,
    required this.ndsCom,
    required this.numDatSetEntries,
    required this.allData,
    required this.rawBytes,
    DateTime? receivedTime,
  }) : receivedTime = receivedTime ?? DateTime.now();
}

class GooseReceiverService {
  static final GooseReceiverService instance = GooseReceiverService._();
  GooseReceiverService._();

  final List<GooseMessage> _messages = [];
  final List<void Function()> _listeners = [];
  bool isEnabled = true;

  List<GooseMessage> get messages => List.unmodifiable(_messages);

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void notifyUpdated() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void clear() {
    _messages.clear();
    notifyUpdated();
  }

  /// Parses raw GOOSE packet (Ethertype 0x88B8 header + goosePdu 0x61)
  GooseMessage? processPacket(Uint8List packet) {
    if (packet.length < 10) return null;

    int appId = 0;
    int pduOffset = 0;

    // Check if Ethernet header + APPID (8B)
    if (packet[0] == 0x61) {
      // Direct goosePdu
      pduOffset = 0;
    } else if (packet.length >= 8) {
      final bd = ByteData.sublistView(packet);
      appId = bd.getUint16(0, Endian.big);
      pduOffset = 8;
    }

    if (pduOffset >= packet.length || packet[pduOffset] != 0x61) {
      return null;
    }

    final root = BerTlv.decode(packet, pduOffset);
    if (root == null) return null;

    String gocbRef = '';
    int timeAllowedToLive = 2000;
    String datSet = '';
    String goId = '';
    DateTime t = DateTime.now();
    int stNum = 1;
    int sqNum = 0;
    bool test = false;
    int confRev = 1;
    bool ndsCom = false;
    int numEntries = 0;
    final allData = <dynamic>[];

    final body = root.value;
    for (int i = 0; i < body.length - 2;) {
      final tlv = BerTlv.decode(body, i);
      if (tlv == null) break;

      switch (tlv.tag) {
        case 0x80: // gocbRef
          gocbRef = utf8.decode(tlv.value, allowMalformed: true);
          break;
        case 0x81: // timeAllowedToLive
          int n = 0;
          for (final b in tlv.value) {
            n = (n << 8) | b;
          }
          timeAllowedToLive = n;
          break;
        case 0x82: // datSet
          datSet = utf8.decode(tlv.value, allowMalformed: true);
          break;
        case 0x83: // goID
          goId = utf8.decode(tlv.value, allowMalformed: true);
          break;
        case 0x84: // t (UtcTime 8B)
          if (tlv.value.length >= 4) {
            final bd = ByteData.sublistView(tlv.value);
            final sec = bd.getUint32(0, Endian.big);
            t = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
          }
          break;
        case 0x85: // stNum
          int n = 0;
          for (final b in tlv.value) {
            n = (n << 8) | b;
          }
          stNum = n;
          break;
        case 0x86: // sqNum
          int n = 0;
          for (final b in tlv.value) {
            n = (n << 8) | b;
          }
          sqNum = n;
          break;
        case 0x87: // test
          test = tlv.value.isNotEmpty && tlv.value[0] != 0;
          break;
        case 0x88: // confRev
          int n = 0;
          for (final b in tlv.value) {
            n = (n << 8) | b;
          }
          confRev = n;
          break;
        case 0x89: // ndsCom
          ndsCom = tlv.value.isNotEmpty && tlv.value[0] != 0;
          break;
        case 0x8A: // numDatSetEntries
          int n = 0;
          for (final b in tlv.value) {
            n = (n << 8) | b;
          }
          numEntries = n;
          break;
        case 0xAB: // allData sequence
          for (int j = 0; j < tlv.value.length - 2;) {
            final decoded = MmsValueCodec.decodeValue(tlv.value, j);
            if (decoded.consumed <= 0) break;
            allData.add(decoded.value);
            j += decoded.consumed;
          }
          break;
      }
      i += tlv.headerSize + tlv.length;
    }

    final msg = GooseMessage(
      appId: appId,
      gocbRef: gocbRef,
      timeAllowedToLive: timeAllowedToLive,
      datSet: datSet,
      goId: goId,
      timestamp: t,
      stNum: stNum,
      sqNum: sqNum,
      test: test,
      confRev: confRev,
      ndsCom: ndsCom,
      numDatSetEntries: numEntries,
      allData: allData,
      rawBytes: packet,
    );

    _messages.add(msg);
    if (_messages.length > 500) {
      _messages.removeRange(0, _messages.length - 500);
    }

    TrafficLogger.instance.log(
      direction: TrafficDirection.rx,
      endpoint: 'GOOSE Multicast (APPID: 0x${appId.toRadixString(16)})',
      protocol: 'GOOSE',
      service: 'GOOSE PDU [stNum: $stNum, sqNum: $sqNum]',
      rawBytes: packet,
      summary: 'GOOSE $gocbRef received (${allData.length} entries)',
      details: 'GoID: $goId, DatSet: $datSet, TAL: ${timeAllowedToLive}ms',
    );

    notifyUpdated();
    return msg;
  }
}
