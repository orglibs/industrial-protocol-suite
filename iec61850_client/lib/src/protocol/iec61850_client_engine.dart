import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/client_variable_model.dart';
import '../models/connection_config.dart';
import '../models/scl_models.dart';
import '../models/scl_parser.dart';
import '../services/traffic_logger.dart';
import 'iso_acse_mms.dart';
import 'tpkt_cotp.dart';

class ReportEventEntry {
  final DateTime timestamp;
  final String rcbName;
  final String dataSetName;
  final int count;
  final List<String> details;

  ReportEventEntry({
    required this.timestamp,
    required this.rcbName,
    required this.dataSetName,
    required this.count,
    required this.details,
  });
}

class Iec61850ClientEngine {
  final ConnectionConfig config;
  Socket? _socket;
  final List<int> _rxBuffer = [];
  int _invokeSequence = 1;

  final Map<int, Completer<Uint8List>> _pendingRequests = {};
  Completer<Uint8List>? _cotpCcCompleter;
  Completer<Uint8List>? _aareCompleter;

  SclParseResult? scl;
  final Map<String, ClientVariableModel> _varByRef = {};
  final Map<String, ClientVariableModel> _varByMmsRef = {};
  final Map<String, SclDataSet> _dataSets = {};
  final Map<String, SclReportControl> _reportControls = {};

  final List<ReportEventEntry> reportEvents = [];
  void Function(ReportEventEntry event)? onReportReceived;

  Timer? _pollTimer;

  Iec61850ClientEngine({required this.config});

  List<ClientVariableModel> get allVariables => _varByRef.values.toList();
  List<SclDataSet> get dataSets => _dataSets.values.toList();
  List<SclReportControl> get reportControls => _reportControls.values.toList();
  bool get isConnected => config.isConnected;

  void bindSclModel(SclParseResult result) {
    scl = result;
    _varByRef.clear();
    _varByMmsRef.clear();
    _dataSets.clear();
    _reportControls.clear();

    for (final v in result.variables) {
      _varByRef[v.reference] = v;
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
    }
    config.notifyUpdated();
  }

  ClientVariableModel? findVariable(String ref) {
    if (_varByRef.containsKey(ref)) return _varByRef[ref];
    if (_varByMmsRef.containsKey(ref)) return _varByMmsRef[ref];
    final clean = ref.replaceAll('/', r'$').replaceAll('.', r'$');
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

  Future<bool> connect() async {
    if (isConnected) return true;

    try {
      config.statusMessage = 'Connecting to ${config.ip}:${config.port} ...';
      config.notifyUpdated();

      _socket = await Socket.connect(config.ip, config.port, timeout: const Duration(seconds: 5));
      _socket!.done.catchError((err) {
        _onDisconnected('Connection disconnected: $err');
      });
      _socket!.listen(
        _onDataReceived,
        onError: (err) => _onDisconnected('Connection error: $err'),
        onDone: () => _onDisconnected('Server closed connection'),
        cancelOnError: true,
      );

      TrafficLogger.instance.log(
        direction: TrafficDirection.tx,
        endpoint: '${config.ip}:${config.port}',
        protocol: 'TCP',
        service: 'Connect',
        rawBytes: Uint8List(0),
        summary: 'TCP Socket connected to ${config.ip}:${config.port}',
      );

      // 1. COTP Connection Request (CR) Handshake
      _cotpCcCompleter = Completer<Uint8List>();
      final cr = CotpFrame.buildConnectionRequest(
        dstRef: 0x0000,
        srcRef: 0x0001,
        localTsap: config.localTsap,
        remoteTsap: config.remoteTsap,
      );
      final tpktCr = TpktFrame.wrap(cr);
      _socket!.add(tpktCr);
      config.txCount++;

      TrafficLogger.instance.log(
        direction: TrafficDirection.tx,
        endpoint: '${config.ip}:${config.port}',
        protocol: 'COTP',
        service: 'Connection Request (CR)',
        rawBytes: tpktCr,
        summary: 'COTP CR sent (SrcRef: 0x0001, TSAP: 0x${config.localTsap.toRadixString(16)})',
      );

      await _cotpCcCompleter!.future.timeout(const Duration(seconds: 4));

      // 2. ACSE AARQ + MMS Initiate Handshake
      _aareCompleter = Completer<Uint8List>();
      final aarqSession = IsoAcseMms.buildAarqWithMmsInitiate();
      final tpktAarq = TpktFrame.wrap(CotpFrame.wrapDataTransfer(aarqSession));
      _socket!.add(tpktAarq);
      config.txCount++;

      TrafficLogger.instance.log(
        direction: TrafficDirection.tx,
        endpoint: '${config.ip}:${config.port}',
        protocol: 'ACSE',
        service: 'Association Request (AARQ)',
        rawBytes: tpktAarq,
        summary: 'ACSE AARQ sent with MMS Initiate Request',
      );

      await _aareCompleter!.future.timeout(const Duration(seconds: 4));

      config.isConnected = true;
      config.lastConnectTime = DateTime.now();
      config.statusMessage = 'Connected to server: ${config.ip}:${config.port}';
      config.notifyUpdated();

      _startPollingTimer();
      return true;
    } catch (e) {
      _onDisconnected('Connection failed: $e');
      return false;
    }
  }

  void disconnect() {
    _socket?.destroy();
    _onDisconnected('User disconnected');
  }

  void _onDisconnected(String reason) {
    _stopPollingTimer();
    _socket = null;
    _rxBuffer.clear();
    _pendingRequests.forEach((_, c) {
      if (!c.isCompleted) c.completeError('Connection closed');
    });
    _pendingRequests.clear();

    config.isConnected = false;
    config.lastDisconnectTime = DateTime.now();
    config.statusMessage = reason;
    config.notifyUpdated();

    TrafficLogger.instance.log(
      direction: TrafficDirection.rx,
      endpoint: '${config.ip}:${config.port}',
      protocol: 'TCP',
      service: 'Disconnect',
      rawBytes: Uint8List(0),
      summary: 'Connection disconnected: $reason',
    );
  }

  void _onDataReceived(List<int> chunk) {
    _rxBuffer.addAll(chunk);
    config.rxCount++;
    config.notifyUpdated();

    while (_rxBuffer.isNotEmpty) {
      final bufferBytes = Uint8List.fromList(_rxBuffer);
      final frame = TpktFrame.extract(bufferBytes);
      if (frame == null) break;

      _rxBuffer.removeRange(0, frame.consumed);
      _handleTpktPayload(frame.payload);
    }
  }

  void _handleTpktPayload(Uint8List tpktPayload) {
    if (tpktPayload.isEmpty) return;

    // 1. COTP CC
    if (CotpFrame.isConnectionConfirm(tpktPayload)) {
      TrafficLogger.instance.log(
        direction: TrafficDirection.rx,
        endpoint: '${config.ip}:${config.port}',
        protocol: 'COTP',
        service: 'Connection Confirm (CC)',
        rawBytes: tpktPayload,
        summary: 'COTP CC received (Accepted)',
      );
      if (_cotpCcCompleter != null && !_cotpCcCompleter!.isCompleted) {
        _cotpCcCompleter!.complete(tpktPayload);
      }
      return;
    }

    // 2. COTP DT
    final cotpData = CotpFrame.extractDataPayload(tpktPayload);
    if (cotpData == null || cotpData.isEmpty) return;

    // Check ACSE AARE (only during association handshake)
    if (_aareCompleter != null && !_aareCompleter!.isCompleted) {
      if (IsoAcseMms.isAare(cotpData)) {
        TrafficLogger.instance.log(
          direction: TrafficDirection.rx,
          endpoint: '${config.ip}:${config.port}',
          protocol: 'ACSE',
          service: 'Association Response (AARE)',
          rawBytes: cotpData,
          summary: 'ACSE AARE received with MMS Initiate Response',
        );
        _aareCompleter!.complete(cotpData);
        return;
      }
    }

    // MMS PDU
    final mmsPdu = IsoAcseMms.extractMmsPdu(cotpData);
    if (mmsPdu != null) {
      _handleMmsPdu(mmsPdu);
    }
  }

  void _handleMmsPdu(Uint8List mmsPdu) {
    if (mmsPdu.isEmpty) return;
    final tag = mmsPdu[0];

    // Tag 0xA3: UnconfirmedPdu (InformationReport from server)
    if (tag == 0xA3) {
      _handleInformationReport(mmsPdu);
      return;
    }

    // Tag 0xA1: Confirmed-ResponsePdu
    // Tag 0xA2: Confirmed-ErrorPdu
    if (tag == 0xA1 || tag == 0xA2) {
      final root = BerTlv.decode(mmsPdu);
      if (root != null) {
        final invokeTlv = BerTlv.decode(root.value);
        if (invokeTlv != null && invokeTlv.tag == 0x02) {
          int invokeId = 0;
          for (final b in invokeTlv.value) {
            invokeId = (invokeId << 8) | b;
          }
          final completer = _pendingRequests.remove(invokeId);
          if (completer != null && !completer.isCompleted) {
            if (tag == 0xA2) {
              completer.completeError('MMS Confirmed-Error received (InvokeID: $invokeId)');
            } else {
              final offset = invokeTlv.headerSize + invokeTlv.length;
              final serviceResp = offset < root.value.length ? root.value.sublist(offset) : Uint8List(0);
              completer.complete(serviceResp);
            }
          }
        }
      }
    }
  }

  void _handleInformationReport(Uint8List mmsPdu) {
    // 0xA3 UnconfirmedPdu -> 0xA0 informationReport -> variableAccessSpecification + listOfAccessResult
    String dataSetName = 'Unknown_DataSet';
    final receivedValues = <String>[];

    final root = BerTlv.decode(mmsPdu);
    if (root != null) {
      // If tag is 0xA3, root.value contains 0xA0 informationReport
      Uint8List infoVal = root.value;
      if (root.tag == 0xA3) {
        final inner = BerTlv.decode(root.value);
        if (inner != null && inner.tag == 0xA0) {
          infoVal = inner.value;
        }
      }

      for (int j = 0; j < infoVal.length - 2;) {
        final subTlv = BerTlv.decode(infoVal, j);
        if (subTlv == null) break;

        if (subTlv.tag == 0xA1) {
          // variableListName
          dataSetName = utf8.decode(subTlv.value, allowMalformed: true);
        } else if (subTlv.tag == 0xA0) {
          // listOfAccessResult: data values
          final ds = _dataSets[dataSetName];
          int varIdx = 0;
          for (int k = 0; k < subTlv.value.length - 2;) {
            final decoded = MmsValueCodec.decodeValue(subTlv.value, k);
            if (decoded.consumed <= 0) break;

            if (ds != null && varIdx < ds.entries.length) {
              final fcda = ds.entries[varIdx++];
              final targetVar = findVariable(fcda.fullPath);
              if (targetVar != null) {
                targetVar.value = decoded.value;
                if (decoded.quality != 0) targetVar.quality = decoded.quality;
                if (decoded.timestamp != null) targetVar.timestamp = decoded.timestamp!;
              }
            }
            receivedValues.add('${decoded.value}');
            k += decoded.consumed;
          }
        }
        j += subTlv.headerSize + subTlv.length;
      }
    }

    final entry = ReportEventEntry(
      timestamp: DateTime.now(),
      rcbName: dataSetName,
      dataSetName: dataSetName,
      count: receivedValues.length,
      details: receivedValues,
    );

    reportEvents.add(entry);
    if (reportEvents.length > 500) {
      reportEvents.removeRange(0, reportEvents.length - 500);
    }

    TrafficLogger.instance.log(
      direction: TrafficDirection.rx,
      endpoint: '${config.ip}:${config.port}',
      protocol: 'MMS',
      service: 'InformationReport',
      rawBytes: mmsPdu,
      summary: 'Report received for DataSet [$dataSetName] with ${receivedValues.length} values',
      details: receivedValues.join(', '),
    );

    onReportReceived?.call(entry);
    config.notifyUpdated();
  }

  Future<Uint8List> _sendConfirmedRequest(Uint8List confirmedServiceRequest) async {
    if (!isConnected || _socket == null) {
      throw 'Not connected to IEC 61850 server';
    }

    final invokeId = _invokeSequence++;
    final completer = Completer<Uint8List>();
    _pendingRequests[invokeId] = completer;

    // Confirmed-RequestPdu (0xA0) = invokeID (0x02) + confirmedServiceRequest
    final invokeTlv = BerTlv(0x02, _encodeInt(invokeId)).encode();
    final pduPayload = Uint8List.fromList([...invokeTlv, ...confirmedServiceRequest]);
    final mmsPdu = BerTlv(0xA0, pduPayload).encode();

    final tpkt = TpktFrame.wrap(CotpFrame.wrapDataTransfer(IsoAcseMms.wrapMmsPdu(mmsPdu)));
    try {
      _socket!.add(tpkt);
      config.txCount++;
    } catch (e) {
      _pendingRequests.remove(invokeId);
      _onDisconnected('Failed to send data: $e');
      rethrow;
    }

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingRequests.remove(invokeId);
        throw 'Request timeout (InvokeID: $invokeId)';
      },
    );
  }

  // MMS Services: GetNameList
  Future<List<String>> getDomainNames() async {
    // GetNameList (0xA1): objectScope VMD (0xA0 0x00), objectClass DOMAIN (0x80 0x01 0x09)
    final req = Uint8List.fromList([
      0xA1, 0x05,
      0x80, 0x01, 0x09, // DOMAIN
      0xA0, 0x00,
    ]);

    final resp = await _sendConfirmedRequest(req);
    return _parseListOfIdentifiers(resp);
  }

  Future<List<String>> getVariableNames(String domainName) async {
    // GetNameList: objectScope domainSpecific (0xA1), objectClass NAMED_VARIABLE (0x80 0x01 0x00)
    final domainBytes = utf8.encode(domainName);
    final scopeTlv = BerTlv(0xA1, Uint8List.fromList([0x1A, domainBytes.length, ...domainBytes])).encode();
    final req = BerTlv(0xA1, Uint8List.fromList([
      0x80, 0x01, 0x00, // NAMED_VARIABLE
      ...scopeTlv,
    ])).encode();

    final resp = await _sendConfirmedRequest(req);
    return _parseListOfIdentifiers(resp);
  }

  Future<List<String>> getDataSetNames(String domainName) async {
    final domainBytes = utf8.encode(domainName);
    final scopeTlv = BerTlv(0xA1, Uint8List.fromList([0x1A, domainBytes.length, ...domainBytes])).encode();
    final req = BerTlv(0xA1, Uint8List.fromList([
      0x80, 0x01, 0x01, // NAMED_VARIABLE_LIST
      ...scopeTlv,
    ])).encode();

    final resp = await _sendConfirmedRequest(req);
    return _parseListOfIdentifiers(resp);
  }

  List<String> _parseListOfIdentifiers(Uint8List mmsPdu) {
    final results = <String>[];
    for (int i = 0; i < mmsPdu.length - 2;) {
      final tlv = BerTlv.decode(mmsPdu, i);
      if (tlv == null) break;

      if (tlv.tag == 0xA1) {
        // getNameList response
        for (int j = 0; j < tlv.value.length - 2;) {
          final sub = BerTlv.decode(tlv.value, j);
          if (sub == null) break;

          if (sub.tag == 0xA0) {
            // listOfIdentifier
            for (int k = 0; k < sub.value.length - 1;) {
              final idTlv = BerTlv.decode(sub.value, k);
              if (idTlv == null) break;
              if (idTlv.tag == 0x1A || idTlv.tag == 0x80) {
                final idStr = utf8.decode(idTlv.value, allowMalformed: true);
                if (idStr.isNotEmpty) results.add(idStr);
              }
              k += idTlv.headerSize + idTlv.length;
            }
          }
          j += sub.headerSize + sub.length;
        }
      }
      i += tlv.headerSize + tlv.length;
    }
    return results;
  }

  // Dynamic Online Model Discovery
  Future<bool> discoverOnlineModel() async {
    if (!isConnected) return false;

    try {
      config.statusMessage = 'Discovering online model (MMS GetNameList) ...';
      config.notifyUpdated();

      final domains = await getDomainNames();
      if (domains.isEmpty) domains.add('GenericIO');

      final ied = SclIED(name: 'ServerIED');
      final discoveredVars = <ClientVariableModel>[];
      final discoveredDataSets = <SclDataSet>[];

      for (final dom in domains) {
        final ld = SclLDevice(inst: dom);
        ied.lDevices.add(ld);

        final varNames = await getVariableNames(dom);
        for (final varName in varNames) {
          // Parse MMS name: e.g. "GGIO1$ST$Ind1$stVal" or "LN$FC$DO$DA"
          final parts = varName.split(r'$');
          final lnName = parts.isNotEmpty ? parts[0] : 'LLN0';
          final fcCode = parts.length > 1 ? parts[1] : 'ST';
          final doName = parts.length > 2 ? parts[2] : 'DO';
          final daName = parts.length > 3 ? parts[3] : 'stVal';

          final v = ClientVariableModel(
            reference: 'ServerIED$dom/$lnName.$doName.$daName',
            iedName: 'ServerIED',
            ldInst: dom,
            lnName: lnName,
            doName: doName,
            daName: daName,
            fc: FunctionalConstraint.fromCode(fcCode),
            type: daName == 'stVal' && fcCode == 'ST' ? IecBasicType.boolean : IecBasicType.float32,
          );
          discoveredVars.add(v);
        }

        final dsNames = await getDataSetNames(dom);
        for (final dsName in dsNames) {
          discoveredDataSets.add(SclDataSet(name: dsName, ldInst: dom));
        }
      }

      final parseRes = SclParseResult(
        iedName: 'ServerIED',
        ied: ied,
        variables: discoveredVars.isNotEmpty ? discoveredVars : allVariables,
        dataSets: discoveredDataSets.isNotEmpty ? discoveredDataSets : dataSets,
        reportControls: reportControls,
        gseControls: scl?.gseControls ?? [],
        svControls: scl?.svControls ?? [],
      );

      bindSclModel(parseRes);
      config.statusMessage = 'Online discovery succeeded: found ${domains.length} domain(s), ${discoveredVars.length} data point(s).';
      config.notifyUpdated();
      return true;
    } catch (e) {
      config.statusMessage = 'Online discovery error: $e';
      config.notifyUpdated();
      return false;
    }
  }

  // MMS Read Service
  Future<bool> readVariable(ClientVariableModel variable) async {
    return readVariables([variable]);
  }

  Future<bool> readVariables(List<ClientVariableModel> vars) async {
    if (vars.isEmpty || !isConnected) return false;

    try {
      final varSpecs = <Uint8List>[];
      for (final v in vars) {
        final refBytes = utf8.encode(v.mmsRef);
        final itemTlv = BerTlv(0x1A, Uint8List.fromList(refBytes)).encode();
        final varSpec = BerTlv(0x30, itemTlv).encode();
        varSpecs.add(varSpec);
      }

      final listOfVarPayload = Uint8List.fromList(varSpecs.expand((x) => x).toList());
      final listOfVarTlv = BerTlv(0xA0, listOfVarPayload).encode();
      final readReq = BerTlv(0xA4, listOfVarTlv).encode();

      final resp = await _sendConfirmedRequest(readReq);

      // Parse read response: 0xA4 -> 0xA0 listOfAccessResult
      int varIdx = 0;
      for (int i = 0; i < resp.length - 2;) {
        final tlv = BerTlv.decode(resp, i);
        if (tlv == null) break;

        if (tlv.tag == 0xA4) {
          for (int j = 0; j < tlv.value.length - 2;) {
            final sub = BerTlv.decode(tlv.value, j);
            if (sub == null) break;

            if (sub.tag == 0xA0) {
              for (int k = 0; k < sub.value.length - 2 && varIdx < vars.length;) {
                final decoded = MmsValueCodec.decodeValue(sub.value, k);
                if (decoded.consumed <= 0) break;

                final targetVar = vars[varIdx++];
                targetVar.value = decoded.value;
                if (decoded.quality != 0) targetVar.quality = decoded.quality;
                if (decoded.timestamp != null) targetVar.timestamp = decoded.timestamp!;
                k += decoded.consumed;
              }
            }
            j += sub.headerSize + sub.length;
          }
        }
        i += tlv.headerSize + tlv.length;
      }

      TrafficLogger.instance.log(
        direction: TrafficDirection.rx,
        endpoint: '${config.ip}:${config.port}',
        protocol: 'MMS',
        service: 'Read Response',
        rawBytes: resp,
        summary: 'Read ${vars.length} variables successfully',
      );

      config.notifyUpdated();
      return true;
    } catch (e) {
      TrafficLogger.instance.log(
        direction: TrafficDirection.rx,
        endpoint: '${config.ip}:${config.port}',
        protocol: 'MMS',
        service: 'Read Error',
        rawBytes: Uint8List(0),
        summary: 'Read failed: $e',
      );
      return false;
    }
  }

  // MMS Read DataSet
  Future<bool> readDataSet(SclDataSet dataSet) async {
    if (!isConnected) return false;

    try {
      final nameBytes = utf8.encode(dataSet.name);
      final varListTlv = BerTlv(0xA1, Uint8List.fromList(nameBytes)).encode();
      final readReq = BerTlv(0xA4, varListTlv).encode();

      final resp = await _sendConfirmedRequest(readReq);

      // Decode and update members
      int memberIdx = 0;
      for (int i = 0; i < resp.length - 2;) {
        final tlv = BerTlv.decode(resp, i);
        if (tlv == null) break;

        if (tlv.tag == 0xA4) {
          for (int j = 0; j < tlv.value.length - 2;) {
            final sub = BerTlv.decode(tlv.value, j);
            if (sub == null) break;

            if (sub.tag == 0xA0) {
              for (int k = 0; k < sub.value.length - 2 && memberIdx < dataSet.entries.length;) {
                final decoded = MmsValueCodec.decodeValue(sub.value, k);
                if (decoded.consumed <= 0) break;

                final fcda = dataSet.entries[memberIdx++];
                final targetVar = findVariable(fcda.fullPath);
                if (targetVar != null) {
                  targetVar.value = decoded.value;
                  if (decoded.quality != 0) targetVar.quality = decoded.quality;
                  if (decoded.timestamp != null) targetVar.timestamp = decoded.timestamp!;
                }
                k += decoded.consumed;
              }
            }
            j += sub.headerSize + sub.length;
          }
        }
        i += tlv.headerSize + tlv.length;
      }

      config.notifyUpdated();
      return true;
    } catch (_) {
      return false;
    }
  }

  // MMS Write Service
  Future<bool> writeVariable(ClientVariableModel variable, dynamic value) async {
    if (!isConnected) return false;

    try {
      final refBytes = utf8.encode(variable.mmsRef);
      final itemTlv = BerTlv(0x1A, Uint8List.fromList(refBytes)).encode();
      final varSpec = BerTlv(0x30, itemTlv).encode();
      final varAccessTlv = BerTlv(0xA0, varSpec).encode();

      final dataTlv = MmsValueCodec.encodeValue(value, variable.type);
      final listOfDataTlv = BerTlv(0xA0, dataTlv).encode();

      final writeReq = BerTlv(0xA5, Uint8List.fromList([...varAccessTlv, ...listOfDataTlv])).encode();
      final resp = await _sendConfirmedRequest(writeReq);

      variable.value = value;
      config.notifyUpdated();

      TrafficLogger.instance.log(
        direction: TrafficDirection.rx,
        endpoint: '${config.ip}:${config.port}',
        protocol: 'MMS',
        service: 'Write Response',
        rawBytes: resp,
        summary: 'Write ${variable.mmsRef} = $value success',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Controllable Operation (Direct / SBO)
  Future<bool> operateControl(ClientVariableModel variable, dynamic value, {bool isSbo = false}) async {
    if (isSbo) {
      // Step 1: Select
      final selectRef = variable.mmsRef.replaceAll('Oper', 'SBO').replaceAll('ctlVal', 'SBO');
      final selBytes = utf8.encode(selectRef);
      final itemTlv = BerTlv(0x1A, Uint8List.fromList(selBytes)).encode();
      final varSpec = BerTlv(0x30, itemTlv).encode();
      final varAccessTlv = BerTlv(0xA0, varSpec).encode();
      final dataTlv = MmsValueCodec.encodeValue(value, variable.type);
      final listOfDataTlv = BerTlv(0xA0, dataTlv).encode();

      final selReq = BerTlv(0xA5, Uint8List.fromList([...varAccessTlv, ...listOfDataTlv])).encode();
      await _sendConfirmedRequest(selReq);
    }

    // Step 2: Operate
    return writeVariable(variable, value);
  }

  // Report Control Block Configuration (Enable/Disable, GI)
  Future<bool> configureReport(SclReportControl rcb, {bool? rptEna, bool? gi, bool? resv}) async {
    if (!isConnected) return false;

    if (rptEna != null) {
      final rptEnaRef = '${rcb.name}\$RptEna';
      final refBytes = utf8.encode(rptEnaRef);
      final itemTlv = BerTlv(0x1A, Uint8List.fromList(refBytes)).encode();
      final varSpec = BerTlv(0x30, itemTlv).encode();
      final varAccessTlv = BerTlv(0xA0, varSpec).encode();
      final dataTlv = BerTlv(0x83, Uint8List.fromList([rptEna ? 0xFF : 0x00])).encode();
      final listOfData = BerTlv(0xA0, dataTlv).encode();

      final req = BerTlv(0xA5, Uint8List.fromList([...varAccessTlv, ...listOfData])).encode();
      await _sendConfirmedRequest(req);
      rcb.rptEna = rptEna;
    }

    if (gi != null && gi) {
      final giRef = '${rcb.name}\$GI';
      final refBytes = utf8.encode(giRef);
      final itemTlv = BerTlv(0x1A, Uint8List.fromList(refBytes)).encode();
      final varSpec = BerTlv(0x30, itemTlv).encode();
      final varAccessTlv = BerTlv(0xA0, varSpec).encode();
      final dataTlv = BerTlv(0x83, Uint8List.fromList([0xFF])).encode();
      final listOfData = BerTlv(0xA0, dataTlv).encode();

      final req = BerTlv(0xA5, Uint8List.fromList([...varAccessTlv, ...listOfData])).encode();
      await _sendConfirmedRequest(req);
    }

    config.notifyUpdated();
    return true;
  }

  // MMS File Services
  Future<List<({String name, int size})>> listRemoteFiles() async {
    if (!isConnected) return [];

    try {
      final req = BerTlv(0x4D, Uint8List(0)).encode(); // FileDirectory
      final resp = await _sendConfirmedRequest(req);
      final files = <({String name, int size})>[];

      for (int i = 0; i < resp.length - 2;) {
        final tlv = BerTlv.decode(resp, i);
        if (tlv == null) break;

        if (tlv.tag == 0xCD) {
          for (int j = 0; j < tlv.value.length - 2;) {
            final sub = BerTlv.decode(tlv.value, j);
            if (sub == null) break;

            if (sub.tag == 0xA0) {
              for (int k = 0; k < sub.value.length - 2;) {
                final entryTlv = BerTlv.decode(sub.value, k);
                if (entryTlv == null) break;
                if (entryTlv.tag == 0x30) {
                  String fname = '';
                  int fsize = 0;
                  for (int m = 0; m < entryTlv.value.length - 1;) {
                    final item = BerTlv.decode(entryTlv.value, m);
                    if (item == null) break;
                    if (item.tag == 0x1A) {
                      fname = utf8.decode(item.value, allowMalformed: true);
                    } else if (item.tag == 0x80) {
                      for (final b in item.value) {
                        fsize = (fsize << 8) | b;
                      }
                    }
                    m += item.headerSize + item.length;
                  }
                  if (fname.isNotEmpty) files.add((name: fname, size: fsize));
                }
                k += entryTlv.headerSize + entryTlv.length;
              }
            }
            j += sub.headerSize + sub.length;
          }
        }
        i += tlv.headerSize + tlv.length;
      }
      return files;
    } catch (_) {
      return [];
    }
  }

  Future<bool> downloadFile(String remoteFilename, String localSavePath, {void Function(int received, int total)? onProgress}) async {
    if (!isConnected) return false;

    try {
      // 1. FileOpen
      final nameBytes = utf8.encode(remoteFilename);
      final openReq = BerTlv(0x48, Uint8List.fromList([0x1A, nameBytes.length, ...nameBytes])).encode();
      final openResp = await _sendConfirmedRequest(openReq);

      int frsmId = 1;
      int totalSize = 0;

      for (int i = 0; i < openResp.length - 2;) {
        final tlv = BerTlv.decode(openResp, i);
        if (tlv == null) break;
        if (tlv.tag == 0xC8) {
          for (int j = 0; j < tlv.value.length - 1;) {
            final sub = BerTlv.decode(tlv.value, j);
            if (sub == null) break;
            if (sub.tag == 0x80) {
              for (final b in sub.value) {
                frsmId = (frsmId << 8) | b;
              }
            } else if (sub.tag == 0x81) {
              for (final b in sub.value) {
                totalSize = (totalSize << 8) | b;
              }
            }
            j += sub.headerSize + sub.length;
          }
        }
        i += tlv.headerSize + tlv.length;
      }

      // 2. Loop FileRead
      final outBytes = <int>[];
      bool moreFollows = true;

      while (moreFollows) {
        final readReq = BerTlv(0x49, _encodeInt(frsmId)).encode();
        final readResp = await _sendConfirmedRequest(readReq);

        for (int i = 0; i < readResp.length - 2;) {
          final tlv = BerTlv.decode(readResp, i);
          if (tlv == null) break;
          if (tlv.tag == 0xC9) {
            for (int j = 0; j < tlv.value.length - 1;) {
              final sub = BerTlv.decode(tlv.value, j);
              if (sub == null) break;
              if (sub.tag == 0x80) {
                outBytes.addAll(sub.value);
              } else if (sub.tag == 0x81) {
                moreFollows = sub.value.isNotEmpty && sub.value[0] != 0;
              }
              j += sub.headerSize + sub.length;
            }
          }
          i += tlv.headerSize + tlv.length;
        }

        onProgress?.call(outBytes.length, totalSize);
      }

      // 3. FileClose
      final closeReq = BerTlv(0x4A, _encodeInt(frsmId)).encode();
      await _sendConfirmedRequest(closeReq);

      // Save locally
      final f = File(localSavePath);
      f.writeAsBytesSync(outBytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Setting Group Control Block (SGCB)
  Future<bool> switchSettingGroup(int sgNum) async {
    if (!isConnected) return false;
    try {
      final actSgRef = 'SGCB\$ActSG';
      final refBytes = utf8.encode(actSgRef);
      final itemTlv = BerTlv(0x1A, Uint8List.fromList(refBytes)).encode();
      final varSpec = BerTlv(0x30, itemTlv).encode();
      final varAccessTlv = BerTlv(0xA0, varSpec).encode();

      final dataTlv = BerTlv(0x86, _encodeInt(sgNum)).encode(); // uint
      final listOfData = BerTlv(0xA0, dataTlv).encode();

      final req = BerTlv(0xA5, Uint8List.fromList([...varAccessTlv, ...listOfData])).encode();
      await _sendConfirmedRequest(req);
      config.notifyUpdated();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Periodic Polling
  void _startPollingTimer() {
    _stopPollingTimer();
    _pollTimer = Timer.periodic(Duration(milliseconds: config.pollIntervalMs), (_) {
      if (!isConnected) return;
      final pollingVars = allVariables.where((v) => v.isPolling).toList();
      if (pollingVars.isNotEmpty) {
        readVariables(pollingVars);
      }
    });
  }

  void _stopPollingTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
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
}
