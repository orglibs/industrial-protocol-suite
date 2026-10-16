import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/scl_models.dart';
import '../models/scl_parser.dart';
import '../models/server_config.dart';
import '../models/server_variable_model.dart';
import '../services/traffic_logger.dart';
import 'iso_acse_mms.dart';

class ClientAssociation {
  final String id;
  final String endpoint;
  final Set<String> enabledReports = {}; // Set of rcbName
  final Map<String, DateTime> sboSelections = {}; // varRef -> selectTime

  ClientAssociation({required this.id, required this.endpoint});
}

class MmsFileHandle {
  final int frsmId;
  final String filename;
  final RandomAccessFile file;
  final int fileSize;
  int currentOffset = 0;

  MmsFileHandle({
    required this.frsmId,
    required this.filename,
    required this.file,
    required this.fileSize,
  });
}

class Iec61850ServerEngine {
  final ServerConfig config;
  SclParseResult? scl;

  final Map<String, ServerVariableModel> _varByRef = {};
  final Map<String, ServerVariableModel> _varByMmsRef = {};
  final Map<String, SclDataSet> _dataSets = {};
  final Map<String, SclReportControl> _reportControls = {};

  final Map<String, ClientAssociation> _clients = {};
  final Map<int, MmsFileHandle> _openFiles = {};
  int _nextFrsmId = 1;

  void Function(SclReportControl rcb, Uint8List packet)? onReportGenerated;

  Iec61850ServerEngine({required this.config});

  List<ServerVariableModel> get allVariables => _varByRef.values.toList();
  List<SclDataSet> get dataSets => _dataSets.values.toList();
  List<SclReportControl> get reportControls => _reportControls.values.toList();

  void loadScl(SclParseResult result) {
    scl = result;
    _varByRef.clear();
    _varByMmsRef.clear();
    _dataSets.clear();
    _reportControls.clear();

    for (final v in result.variables) {
      _varByRef[v.reference] = v;
      // Normal MMS reference format: "GenericIO/GGIO1$ST$Ind1$stVal" or "GGIO1$ST$Ind1$stVal"
      final mmsFull = '${v.ldInst}/${v.lnName}\$${v.fcCode}\$${v.doName}\$${v.daName}';
      final mmsShort = '${v.lnName}\$${v.fcCode}\$${v.doName}\$${v.daName}';
      _varByMmsRef[mmsFull] = v;
      _varByMmsRef[mmsShort] = v;
      _varByMmsRef[v.shortRef] = v;
      _varByMmsRef[v.reference] = v;
    }

    for (final ds in result.dataSets) {
      _dataSets[ds.name] = ds;
      _dataSets['${ds.ldInst}/${ds.lnName}\$${ds.name}'] = ds;
    }

    for (final rcb in result.reportControls) {
      _reportControls[rcb.name] = rcb;
      _reportControls['${rcb.ldInst}/${rcb.lnName}\$RP\$${rcb.name}'] = rcb;
      _reportControls['${rcb.ldInst}/${rcb.lnName}\$BR\$${rcb.name}'] = rcb;
    }
  }

  void registerClient(String clientId, String endpoint) {
    _clients[clientId] = ClientAssociation(id: clientId, endpoint: endpoint);
  }

  void unregisterClient(String clientId) {
    _clients.remove(clientId);
  }

  /// Finds a variable by any form of reference (MMS, SCL, short, full)
  ServerVariableModel? findVariable(String ref) {
    final clean = ref.replaceAll('/', r'$').replaceAll('.', r'$');
    if (_varByRef.containsKey(ref)) return _varByRef[ref];
    if (_varByMmsRef.containsKey(ref)) return _varByMmsRef[ref];
    for (final entry in _varByMmsRef.entries) {
      if (entry.key.endsWith(ref) || ref.endsWith(entry.key)) {
        return entry.value;
      }
    }
    for (final v in _varByRef.values) {
      if (v.reference.endsWith(clean) || clean.endsWith(v.daName)) {
        return v;
      }
    }
    return null;
  }

  /// Dispatches incoming MMS PDU and returns response MMS PDU (or null if unconfirmed/no response needed)
  Uint8List? processMmsPdu(Uint8List mmsPdu, {required String clientId, required String clientEndpoint}) {
    if (mmsPdu.isEmpty) return null;

    final pduTag = mmsPdu[0];

    // 0xA0: Confirmed-RequestPdu
    if (pduTag == 0xA0) {
      return _handleConfirmedRequest(mmsPdu, clientId: clientId, clientEndpoint: clientEndpoint);
    }

    // 0xA8: Initiate-RequestPdu
    if (pduTag == 0xA8) {
      return IsoAcseMms.buildAareWithMmsInitiate();
    }

    return null;
  }

  Uint8List _handleConfirmedRequest(Uint8List mmsPdu, {required String clientId, required String clientEndpoint}) {
    final root = BerTlv.decode(mmsPdu);
    if (root == null) return _buildConfirmedError(1, 1, 1);

    // Root value contains: invokeID (tag 0x02) + confirmedService (tag 0xA1..0xAD, 0x48..0x4D)
    int invokeId = 1;
    int offset = 0;
    final body = root.value;

    final invokeTlv = BerTlv.decode(body, offset);
    if (invokeTlv != null && invokeTlv.tag == 0x02) {
      // Decode integer invokeID
      invokeId = 0;
      for (final b in invokeTlv.value) {
        invokeId = (invokeId << 8) | b;
      }
      offset += invokeTlv.headerSize + invokeTlv.length;
    }

    if (offset >= body.length) {
      return _buildConfirmedError(invokeId, 1, 1);
    }

    final serviceTlv = BerTlv.decode(body, offset);
    if (serviceTlv == null) {
      return _buildConfirmedError(invokeId, 1, 1);
    }

    switch (serviceTlv.tag) {
      case 0xA1: // GetNameList
        return _handleGetNameList(invokeId, serviceTlv.value, clientId: clientId, endpoint: clientEndpoint);

      case 0xA4: // Read
        return _handleRead(invokeId, serviceTlv.value, clientId: clientId, endpoint: clientEndpoint);

      case 0xA5: // Write
        return _handleWrite(invokeId, serviceTlv.value, clientId: clientId, endpoint: clientEndpoint);

      case 0xA6: // GetVariableAccessAttributes
        return _handleGetVariableAccessAttributes(invokeId, serviceTlv.value);

      case 0x48: // FileOpen
        return _handleFileOpen(invokeId, serviceTlv.value);

      case 0x49: // FileRead
        return _handleFileRead(invokeId, serviceTlv.value);

      case 0x4A: // FileClose
        return _handleFileClose(invokeId, serviceTlv.value);

      case 0x4D: // FileDirectory
        return _handleFileDirectory(invokeId, serviceTlv.value);

      default:
        // Service not supported: MMS service error
        return _buildConfirmedError(invokeId, 1, 2);
    }
  }

  /// Handles MMS GetNameList request
  Uint8List _handleGetNameList(int invokeId, Uint8List reqVal, {required String clientId, required String endpoint}) {
    // reqVal contains: extendedObjectClass (tag 0xA0) or objectClass (tag 0x80), objectScope (tag 0xA1/0x81/0x82)
    int objClass = 0; // 0=NAMED_VARIABLE, 1=NAMED_VARIABLE_LIST, 9=DOMAIN
    String domainName = '';

    for (int i = 0; i < reqVal.length - 2;) {
      final tlv = BerTlv.decode(reqVal, i);
      if (tlv == null) break;

      if (tlv.tag == 0x80) {
        // objectClass integer
        objClass = tlv.value.isNotEmpty ? tlv.value[0] : 0;
      } else if (tlv.tag == 0xA1) {
        // domainSpecific scope -> domain identifier
        domainName = _extractVisibleString(tlv.value);
      }
      i += tlv.headerSize + tlv.length;
    }

    final identifiers = <String>[];

    if (objClass == 9) {
      // DOMAIN names: list of Logical Devices
      if (scl != null) {
        for (final ld in scl!.ied.lDevices) {
          identifiers.add(ld.inst);
        }
      }
      if (identifiers.isEmpty) identifiers.add('GenericIO');
    } else if (objClass == 1) {
      // NAMED_VARIABLE_LIST (DataSets)
      for (final ds in _dataSets.values) {
        if (domainName.isEmpty || ds.ldInst == domainName || ds.name.startsWith(domainName)) {
          identifiers.add(ds.name);
        }
      }
    } else {
      // NAMED_VARIABLE
      for (final v in _varByRef.values) {
        if (domainName.isEmpty || v.ldInst == domainName) {
          identifiers.add('${v.lnName}\$${v.fcCode}\$${v.doName}\$${v.daName}');
        }
      }
    }

    TrafficLogger.instance.log(
      direction: TrafficDirection.rx,
      clientEndpoint: endpoint,
      protocol: 'MMS',
      service: 'GetNameList [ID: $invokeId]',
      rawBytes: reqVal,
      summary: 'GetNameList: objClass=$objClass, domain="$domainName", returning ${identifiers.length} items',
    );

    // Build Confirmed-ResponsePdu (0xA1):
    // [0] invokeID (0x02)
    // [1] getNameList (0xA1):
    //     listOfIdentifier (0xA0): array of VisibleString (0x1A)
    //     moreFollows (0x81 0x01 0x00)
    final idTlvs = <Uint8List>[];
    for (final id in identifiers.take(100)) { // Limit per response chunk
      idTlvs.add(BerTlv(0x1A, Uint8List.fromList(utf8.encode(id))).encode());
    }
    final listOfIdPayload = Uint8List.fromList(idTlvs.expand((x) => x).toList());
    final listOfIdTlv = BerTlv(0xA0, listOfIdPayload).encode();
    final moreFollowsTlv = BerTlv(0x81, Uint8List.fromList([identifiers.length > 100 ? 0xFF : 0x00])).encode();

    final getNameListResp = BerTlv(0xA1, Uint8List.fromList([...listOfIdTlv, ...moreFollowsTlv])).encode();
    final invokeTlv = BerTlv(0x02, _encodeInt(invokeId)).encode();

    return BerTlv(0xA1, Uint8List.fromList([...invokeTlv, ...getNameListResp])).encode();
  }

  /// Handles MMS Read request
  Uint8List _handleRead(int invokeId, Uint8List reqVal, {required String clientId, required String endpoint}) {
    final varRefs = <String>[];
    bool isDataSet = false;
    String dataSetName = '';

    // Parse variableAccessSpecification
    for (int i = 0; i < reqVal.length - 2;) {
      final tlv = BerTlv.decode(reqVal, i);
      if (tlv == null) break;

      if (tlv.tag == 0xA0) {
        // listOfVariable
        for (int j = 0; j < tlv.value.length - 2;) {
          final varSpec = BerTlv.decode(tlv.value, j);
          if (varSpec == null) break;
          final str = _extractVisibleString(varSpec.value);
          if (str.isNotEmpty) varRefs.add(str);
          j += varSpec.headerSize + varSpec.length;
        }
      } else if (tlv.tag == 0xA1) {
        // variableListName (DataSet)
        isDataSet = true;
        dataSetName = _extractVisibleString(tlv.value);
      }
      i += tlv.headerSize + tlv.length;
    }

    final results = <Uint8List>[];

    if (isDataSet && _dataSets.containsKey(dataSetName)) {
      final ds = _dataSets[dataSetName]!;
      for (final fcda in ds.entries) {
        ServerVariableModel? found;
        for (final v in _varByRef.values) {
          if (v.ldInst == fcda.ldInst && v.lnName == fcda.fullLnName && v.doName == fcda.doName) {
            if (fcda.daName == null || v.daName == fcda.daName) {
              found = v;
              break;
            }
          }
        }
        if (found != null) {
          results.add(MmsValueEncoder.encodeVariable(found));
        } else {
          // Object non-existent
          results.add(Uint8List.fromList([0x80, 0x01, 0x0A]));
        }
      }
    } else {
      for (final ref in varRefs) {
        final v = findVariable(ref);
        if (v != null) {
          results.add(MmsValueEncoder.encodeVariable(v));
        } else {
          // Object non-existent error (tag 0x80 0x01 0x0A)
          results.add(Uint8List.fromList([0x80, 0x01, 0x0A]));
        }
      }
    }

    TrafficLogger.instance.log(
      direction: TrafficDirection.rx,
      clientEndpoint: endpoint,
      protocol: 'MMS',
      service: 'Read [ID: $invokeId]',
      rawBytes: reqVal,
      summary: 'Read: ${isDataSet ? "DataSet $dataSetName" : "${varRefs.length} variables"} -> returned ${results.length} values',
    );

    // Build Confirmed-ResponsePdu (0xA1) -> Read Response (0xA4) -> listOfAccessResult (0xA0)
    final listPayload = Uint8List.fromList(results.expand((x) => x).toList());
    final listTlv = BerTlv(0xA0, listPayload).encode();
    final readResp = BerTlv(0xA4, listTlv).encode();
    final invokeTlv = BerTlv(0x02, _encodeInt(invokeId)).encode();

    return BerTlv(0xA1, Uint8List.fromList([...invokeTlv, ...readResp])).encode();
  }

  /// Handles MMS Write request
  Uint8List _handleWrite(int invokeId, Uint8List reqVal, {required String clientId, required String endpoint}) {
    // Write request: variableAccessSpecification + listOfData (tag 0xA0)
    final varRefs = <String>[];
    final writeResults = <Uint8List>[];

    // Simple parsing of write payload
    for (int i = 0; i < reqVal.length - 2;) {
      final tlv = BerTlv.decode(reqVal, i);
      if (tlv == null) break;

      if (tlv.tag == 0xA0 && varRefs.isEmpty) {
        // Variable names
        for (int j = 0; j < tlv.value.length - 2;) {
          final varSpec = BerTlv.decode(tlv.value, j);
          if (varSpec == null) break;
          final str = _extractVisibleString(varSpec.value);
          if (str.isNotEmpty) varRefs.add(str);
          j += varSpec.headerSize + varSpec.length;
        }
      } else if (tlv.tag == 0xA0 && varRefs.isNotEmpty) {
        // List of Data values to apply
        int varIdx = 0;
        for (int k = 0; k < tlv.value.length - 2 && varIdx < varRefs.length;) {
          final dataTlv = BerTlv.decode(tlv.value, k);
          if (dataTlv == null) break;

          final ref = varRefs[varIdx++];
          _applyWrite(ref, dataTlv, clientId: clientId);
          // Success access result: tag 0x80 length 0
          writeResults.add(Uint8List.fromList([0x80, 0x00]));
          k += dataTlv.headerSize + dataTlv.length;
        }
      }
      i += tlv.headerSize + tlv.length;
    }

    if (writeResults.isEmpty) {
      writeResults.add(Uint8List.fromList([0x80, 0x00]));
    }

    TrafficLogger.instance.log(
      direction: TrafficDirection.rx,
      clientEndpoint: endpoint,
      protocol: 'MMS',
      service: 'Write [ID: $invokeId]',
      rawBytes: reqVal,
      summary: 'Write: ${varRefs.join(", ")} updated successfully',
    );

    // Build Confirmed-ResponsePdu (0xA1) -> Write Response (0xA5) -> listOfAccessResult
    final listPayload = Uint8List.fromList(writeResults.expand((x) => x).toList());
    final listTlv = BerTlv(0xA0, listPayload).encode();
    final writeResp = BerTlv(0xA5, listTlv).encode();
    final invokeTlv = BerTlv(0x02, _encodeInt(invokeId)).encode();

    return BerTlv(0xA1, Uint8List.fromList([...invokeTlv, ...writeResp])).encode();
  }

  void _applyWrite(String ref, ({int tag, int length, int headerSize, Uint8List value}) dataTlv, {required String clientId}) {
    // 1. Check if writing to Report Control Block (e.g. RptEna, GI, Resv)
    for (final rcb in _reportControls.values) {
      if (ref.contains(rcb.name)) {
        if (ref.endsWith('RptEna')) {
          final ena = dataTlv.value.isNotEmpty && dataTlv.value[0] != 0;
          rcb.rptEna = ena;
          final client = _clients[clientId];
          if (client != null) {
            if (ena) {
              client.enabledReports.add(rcb.name);
            } else {
              client.enabledReports.remove(rcb.name);
            }
          }
          return;
        } else if (ref.endsWith('GI')) {
          final gi = dataTlv.value.isNotEmpty && dataTlv.value[0] != 0;
          if (gi) {
            triggerReport(rcb, isGI: true);
          }
          return;
        }
      }
    }

    // 2. Regular Variable write or Control Model execution
    final v = findVariable(ref);
    if (v == null) return;

    dynamic parsedValue;
    switch (dataTlv.tag) {
      case 0x83: // boolean
        parsedValue = dataTlv.value.isNotEmpty && dataTlv.value[0] != 0;
        break;
      case 0x85: // integer
        int n = 0;
        for (final b in dataTlv.value) {
          n = (n << 8) | b;
        }
        parsedValue = n;
        break;
      case 0x86: // unsigned
        int u = 0;
        for (final b in dataTlv.value) {
          u = (u << 8) | b;
        }
        parsedValue = u;
        break;
      case 0x87: // float
        if (dataTlv.value.length >= 5) {
          final bd = ByteData.sublistView(dataTlv.value, 1);
          parsedValue = bd.getFloat32(0, Endian.big);
        }
        break;
      default:
        parsedValue = utf8.decode(dataTlv.value, allowMalformed: true);
        break;
    }

    v.value = parsedValue;

    // Control execution: if this is an Oper.ctlVal, reflect change in corresponding stVal
    if (ref.contains('Oper') || ref.contains('ctlVal')) {
      final stValRef = ref.replaceAll('Oper', 'stVal').replaceAll('ctlVal', 'stVal').replaceAll(r'$CO$', r'$ST$');
      final stVar = findVariable(stValRef);
      if (stVar != null) {
        stVar.value = parsedValue;
      }
    }
  }

  /// Triggers an InformationReport (BRCB / URCB)
  void triggerReport(SclReportControl rcb, {bool isGI = false}) {
    // 没开启使能 RptEna = FALSE 不推送变更报告 (GI 总召唤除外)
    if (!rcb.rptEna && !isGI) return;

    final ds = _dataSets[rcb.datSet];
    if (ds == null) return;

    final dataList = <Uint8List>[];
    for (final fcda in ds.entries) {
      for (final v in _varByRef.values) {
        if (v.ldInst == fcda.ldInst && v.lnName == fcda.fullLnName && v.doName == fcda.doName) {
          if (fcda.daName == null || v.daName == fcda.daName) {
            dataList.add(MmsValueEncoder.encodeVariable(v));
          }
        }
      }
    }

    // Build InformationReport (tag 0xA3 unconfirmed -> 0xA0 informationReport)
    // variableAccessSpecification (0xA1 variableListName)
    final varListTlv = BerTlv(0xA1, Uint8List.fromList(utf8.encode(rcb.datSet))).encode();

    // listOfAccessResult (0xA0)
    final accessResultTlv = BerTlv(0xA0, Uint8List.fromList(dataList.expand((x) => x).toList())).encode();

    final infoReportTlv = BerTlv(0xA0, Uint8List.fromList([...varListTlv, ...accessResultTlv])).encode();
    final unconfirmedPdu = BerTlv(0xA3, infoReportTlv).encode();

    rcb.sqNum++;
    rcb.lastReportTime = DateTime.now();

    TrafficLogger.instance.log(
      direction: TrafficDirection.tx,
      clientEndpoint: 'All Clients',
      protocol: 'MMS',
      service: 'InformationReport [${rcb.name}]',
      rawBytes: unconfirmedPdu,
      summary: 'Report ${rcb.name} (${isGI ? "GI" : "Event"}) sent with ${dataList.length} items',
    );

    onReportGenerated?.call(rcb, unconfirmedPdu);
  }

  Uint8List _handleGetVariableAccessAttributes(int invokeId, Uint8List reqVal) {
    // Type description response: mmsDeletable=false (0x80 0x01 0x00), TypeSpecification (0xA2 structure)
    final typeSpec = BerTlv(0x83, Uint8List.fromList([0x01])).encode(); // Simple boolean/structure
    final invokeTlv = BerTlv(0x02, _encodeInt(invokeId)).encode();
    final attrResp = BerTlv(0xA6, Uint8List.fromList([0x80, 0x01, 0x00, ...typeSpec])).encode();
    return BerTlv(0xA1, Uint8List.fromList([...invokeTlv, ...attrResp])).encode();
  }

  // MMS File Services
  Uint8List _handleFileDirectory(int invokeId, Uint8List reqVal) {
    final dir = Directory(config.fileTransferDirectory);
    final entries = <Uint8List>[];

    if (dir.existsSync()) {
      for (final entity in dir.listSync()) {
        if (entity is File) {
          final stat = entity.statSync();
          final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'file');
          final nameTlv = BerTlv(0x1A, Uint8List.fromList(utf8.encode(name))).encode();
          final sizeTlv = BerTlv(0x80, _encodeInt(stat.size)).encode();
          final entryTlv = BerTlv(0x30, Uint8List.fromList([...nameTlv, ...sizeTlv])).encode();
          entries.add(entryTlv);
        }
      }
    }

    final listTlv = BerTlv(0xA0, Uint8List.fromList(entries.expand((x) => x).toList())).encode();
    final moreFollows = BerTlv(0x81, Uint8List.fromList([0x00])).encode();
    final fileDirResp = BerTlv(0xCD, Uint8List.fromList([...listTlv, ...moreFollows])).encode();
    final invokeTlv = BerTlv(0x02, _encodeInt(invokeId)).encode();

    return BerTlv(0xA1, Uint8List.fromList([...invokeTlv, ...fileDirResp])).encode();
  }

  Uint8List _handleFileOpen(int invokeId, Uint8List reqVal) {
    final filename = _extractVisibleString(reqVal);
    final fullPath = '${config.fileTransferDirectory}/$filename';
    final file = File(fullPath);

    if (!file.existsSync()) {
      return _buildConfirmedError(invokeId, 2, 1); // File not found
    }

    final raf = file.openSync(mode: FileMode.read);
    final frsmId = _nextFrsmId++;
    final fileSize = raf.lengthSync();

    _openFiles[frsmId] = MmsFileHandle(
      frsmId: frsmId,
      filename: filename,
      file: raf,
      fileSize: fileSize,
    );

    final frsmIdTlv = BerTlv(0x80, _encodeInt(frsmId)).encode();
    final fileSizeTlv = BerTlv(0x81, _encodeInt(fileSize)).encode();
    final fileOpenResp = BerTlv(0xC8, Uint8List.fromList([...frsmIdTlv, ...fileSizeTlv])).encode();
    final invokeTlv = BerTlv(0x02, _encodeInt(invokeId)).encode();

    return BerTlv(0xA1, Uint8List.fromList([...invokeTlv, ...fileOpenResp])).encode();
  }

  Uint8List _handleFileRead(int invokeId, Uint8List reqVal) {
    int frsmId = 1;
    final idTlv = BerTlv.decode(reqVal);
    if (idTlv != null) {
      frsmId = 0;
      for (final b in idTlv.value) {
        frsmId = (frsmId << 8) | b;
      }
    }

    final handle = _openFiles[frsmId];
    if (handle == null) {
      return _buildConfirmedError(invokeId, 2, 2);
    }

    const chunkSize = 1024;
    final bytes = handle.file.readSync(chunkSize);
    handle.currentOffset += bytes.length;
    final moreFollows = handle.currentOffset < handle.fileSize;

    final fileDataTlv = BerTlv(0x80, bytes).encode();
    final moreTlv = BerTlv(0x81, Uint8List.fromList([moreFollows ? 0xFF : 0x00])).encode();
    final fileReadResp = BerTlv(0xC9, Uint8List.fromList([...fileDataTlv, ...moreTlv])).encode();
    final invokeTlv = BerTlv(0x02, _encodeInt(invokeId)).encode();

    return BerTlv(0xA1, Uint8List.fromList([...invokeTlv, ...fileReadResp])).encode();
  }

  Uint8List _handleFileClose(int invokeId, Uint8List reqVal) {
    int frsmId = 1;
    final idTlv = BerTlv.decode(reqVal);
    if (idTlv != null) {
      frsmId = 0;
      for (final b in idTlv.value) {
        frsmId = (frsmId << 8) | b;
      }
    }

    final handle = _openFiles.remove(frsmId);
    handle?.file.closeSync();

    final fileCloseResp = BerTlv(0xCA, Uint8List(0)).encode();
    final invokeTlv = BerTlv(0x02, _encodeInt(invokeId)).encode();

    return BerTlv(0xA1, Uint8List.fromList([...invokeTlv, ...fileCloseResp])).encode();
  }

  Uint8List _buildConfirmedError(int invokeId, int errorClass, int errorCode) {
    final invokeTlv = BerTlv(0x02, _encodeInt(invokeId)).encode();
    final errPayload = Uint8List.fromList([
      0x80, 0x01, errorClass & 0xFF,
      0x81, 0x01, errorCode & 0xFF,
    ]);
    final errTlv = BerTlv(0xA2, Uint8List.fromList([...invokeTlv, ...errPayload])).encode();
    return errTlv;
  }

  static Uint8List _encodeInt(int value) {
    if (value <= 0xFF) return Uint8List.fromList([value]);
    if (value <= 0xFFFF) return Uint8List.fromList([(value >> 8) & 0xFF, value & 0xFF]);
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  static String _extractVisibleString(Uint8List bytes) {
    for (int i = 0; i < bytes.length - 1; i++) {
      final tag = bytes[i];
      if (tag == 0x1A || tag == 0x80 || tag == 0x81) {
        final len = bytes[i + 1];
        if (i + 2 + len <= bytes.length) {
          final sub = bytes.sublist(i + 2, i + 2 + len);
          return utf8.decode(sub, allowMalformed: true);
        }
      }
    }
    return '';
  }
}
