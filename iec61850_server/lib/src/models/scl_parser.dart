import 'scl_models.dart';
import 'server_variable_model.dart';
import 'simulation_config.dart';

class SclParseResult {
  final String iedName;
  final String? ip;
  final int port;
  final SclIED ied;
  final List<ServerVariableModel> variables;
  final List<SclDataSet> dataSets;
  final List<SclReportControl> reportControls;
  final List<SclGSEControl> gseControls;
  final List<SclSampledValueControl> svControls;
  final int numOfSG;

  SclParseResult({
    required this.iedName,
    this.ip,
    this.port = 102,
    required this.ied,
    required this.variables,
    required this.dataSets,
    required this.reportControls,
    required this.gseControls,
    required this.svControls,
    this.numOfSG = 1,
  });
}

class SclParser {
  /// Parses SCL XML content (ICD, CID, SCD, SSD)
  static SclParseResult parse(String xmlContent) {
    // 1. Extract IED name
    final iedNameMatch = RegExp(r'<IED\s+[^>]*name=["\x27]([^"\x27]+)["\x27]').firstMatch(xmlContent);
    final iedName = iedNameMatch?.group(1) ?? 'IED1';

    // 2. Extract IP and Port from Communication section
    String? ip;
    int port = 102;
    final ipMatch = RegExp(r'<P\s+[^>]*type=["\x27]IP["\x27][^>]*>([^<]+)</P>').firstMatch(xmlContent);
    if (ipMatch != null) ip = ipMatch.group(1)?.trim();

    final portMatch = RegExp(r'<P\s+[^>]*type=["\x27]MMS-Port["\x27][^>]*>([^<]+)</P>').firstMatch(xmlContent);
    if (portMatch != null) {
      final p = int.tryParse(portMatch.group(1)?.trim() ?? '');
      if (p != null) port = p;
    }

    // 3. Extract DataTypeTemplates
    final enumTypes = _parseEnumTypes(xmlContent);
    final daTypes = _parseDATypes(xmlContent);
    final doTypes = _parseDOTypes(xmlContent);
    final lnTypes = _parseLNTypes(xmlContent);

    // 4. Extract IED LDevices & LNs
    final iedDesc = RegExp(r'<IED\s+[^>]*desc=["\x27]([^"\x27]*?)["\x27]').firstMatch(xmlContent)?.group(1);
    final ied = SclIED(name: iedName, desc: iedDesc);
    final variables = <ServerVariableModel>[];
    final allDataSets = <SclDataSet>[];
    final allReportControls = <SclReportControl>[];
    final allGseControls = <SclGSEControl>[];
    final allSvControls = <SclSampledValueControl>[];
    int numOfSG = 1;

    // Scan LDevice elements
    final ldRegex = RegExp(r'<LDevice\s+([^>]*inst=["\x27]([^"\x27]+)["\x27][^>]*)>([\s\S]*?)</LDevice>');
    final ldMatches = ldRegex.allMatches(xmlContent);

    for (final ldMatch in ldMatches) {
      final ldAttrs = ldMatch.group(1)!;
      final ldInst = ldMatch.group(2)!;
      final ldBody = ldMatch.group(3)!;
      final ldDesc = RegExp(r'desc=["\x27]([^"\x27]*?)["\x27]').firstMatch(ldAttrs)?.group(1);
      final lDevice = SclLDevice(
        inst: ldInst,
        desc: ldDesc,
        nameKey: _inferLDeviceNameKey(ldInst),
      );
      ied.lDevices.add(lDevice);

      // Scan LN0 and LN elements inside LDevice
      final lnRegex = RegExp(r'<(LN0|LN)\s+([^>]+)>([\s\S]*?)</\1>');
      final lnMatches = lnRegex.allMatches(ldBody);

      for (final lnMatch in lnMatches) {
        final lnAttrs = lnMatch.group(2)!;
        final lnBody = lnMatch.group(3)!;

        final lnClassMatch = RegExp(r'lnClass=["\x27]([^"\x27]+)["\x27]').firstMatch(lnAttrs);
        final lnClass = lnClassMatch?.group(1) ?? (lnMatch.group(1) == 'LN0' ? 'LLN0' : 'GGIO');

        final instMatch = RegExp(r'inst=["\x27]([^"\x27]*?)["\x27]').firstMatch(lnAttrs);
        final inst = instMatch?.group(1) ?? '';

        final prefixMatch = RegExp(r'prefix=["\x27]([^"\x27]*?)["\x27]').firstMatch(lnAttrs);
        final prefix = prefixMatch?.group(1) ?? '';

        final lnTypeMatch = RegExp(r'lnType=["\x27]([^"\x27]+)["\x27]').firstMatch(lnAttrs);
        final lnTypeId = lnTypeMatch?.group(1) ?? '';
        final lnDesc = RegExp(r'desc=["\x27]([^"\x27]*?)["\x27]').firstMatch(lnAttrs)?.group(1);

        final ln = SclLN(
          lnClass: lnClass,
          inst: inst,
          prefix: prefix,
          lnType: lnTypeId,
          desc: lnDesc,
          nameKey: _inferLnNameKey(lnClass, inst),
        );
        lDevice.logicalNodes.add(ln);

        // 4.1 Parse DataSets inside LN
        final dsRegex = RegExp(r'<DataSet\s+[^>]*name=["\x27]([^"\x27]+)["\x27][^>]*>([\s\S]*?)</DataSet>');
        for (final dsMatch in dsRegex.allMatches(lnBody)) {
          final dsName = dsMatch.group(1)!;
          final dsBody = dsMatch.group(2)!;
          final ds = SclDataSet(
            name: dsName,
            nameKey: _inferDataSetNameKey(dsName),
            ldInst: ldInst,
            lnName: ln.lnName,
          );

          final fcdaRegex = RegExp(
            r'<FCDA\s+ldInst=["\x27]([^"\x27]+)["\x27]\s*(?:prefix=["\x27]([^"\x27]*?)["\x27])?\s*lnClass=["\x27]([^"\x27]+)["\x27]\s*(?:lnInst=["\x27]([^"\x27]*?)["\x27])?\s*doName=["\x27]([^"\x27]+)["\x27]\s*(?:daName=["\x27]([^"\x27]+)["\x27])?\s*fc=["\x27]([^"\x27]+)["\x27]',
          );
          for (final fcdaMatch in fcdaRegex.allMatches(dsBody)) {
            final fcda = SclFCDA(
              ldInst: fcdaMatch.group(1)!,
              prefix: fcdaMatch.group(2) ?? '',
              lnClass: fcdaMatch.group(3)!,
              lnInst: fcdaMatch.group(4) ?? '',
              doName: fcdaMatch.group(5)!,
              daName: fcdaMatch.group(6),
              fc: FunctionalConstraint.fromCode(fcdaMatch.group(7)!),
            );
            ds.fcdaList.add(fcda);
          }
          ln.dataSets.add(ds);
          allDataSets.add(ds);
        }

        // 4.2 Parse ReportControls
        final rptRegex = RegExp(r'<ReportControl\s+([^>]+)>([\s\S]*?)</ReportControl>');
        for (final rptMatch in rptRegex.allMatches(lnBody)) {
          final attrs = rptMatch.group(1)!;
          final body = rptMatch.group(2)!;

          final name = RegExp(r'name=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? 'RCB';
          final rptId = RegExp(r'rptID=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? name;
          final buffered = RegExp(r'buffered=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1)?.toLowerCase() == 'true';
          final datSet = RegExp(r'datSet=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '';
          final bufTime = int.tryParse(RegExp(r'bufTime=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '') ?? 50;
          final intgPd = int.tryParse(RegExp(r'intgPd=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '') ?? 1000;
          final confRev = int.tryParse(RegExp(r'confRev=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '') ?? 1;

          final trgOps = TriggerOptions();
          final trgMatch = RegExp(r'<TrgOps\s+([^>]+)/>').firstMatch(body);
          if (trgMatch != null) {
            final tAttr = trgMatch.group(1)!;
            trgOps.dataChange = RegExp(r'dchg=["\x27]true["\x27]').hasMatch(tAttr);
            trgOps.qualityChange = RegExp(r'qchg=["\x27]true["\x27]').hasMatch(tAttr);
            trgOps.dataUpdate = RegExp(r'dupd=["\x27]true["\x27]').hasMatch(tAttr);
            trgOps.integrity = RegExp(r'period=["\x27]true["\x27]').hasMatch(tAttr);
            trgOps.generalInterrogation = RegExp(r'gi=["\x27]true["\x27]').hasMatch(tAttr);
          }

          final rpt = SclReportControl(
            name: name,
            nameKey: _inferRcbNameKey(name),
            rptId: rptId,
            buffered: buffered,
            bufTime: bufTime,
            datSet: datSet,
            intgPd: intgPd,
            confRev: confRev,
            trgOps: trgOps,
            ldInst: ldInst,
            lnName: ln.lnName,
          );
          ln.reportControls.add(rpt);
          allReportControls.add(rpt);
        }

        // 4.3 Parse GSEControl (GOOSE)
        final gseRegex = RegExp(r'<GSEControl\s+([^>]+)(?:/>|>([\s\S]*?)</GSEControl>)');
        for (final gseMatch in gseRegex.allMatches(lnBody)) {
          final attrs = gseMatch.group(1)!;
          final name = RegExp(r'name=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? 'GCB';
          final appID = RegExp(r'appID=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? name;
          final datSet = RegExp(r'datSet=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '';
          final confRev = int.tryParse(RegExp(r'confRev=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '') ?? 1;

          final gcb = SclGSEControl(
            name: name,
            nameKey: _inferGcbNameKey(name),
            goId: appID,
            datSet: datSet,
            confRev: confRev,
          );
          ln.gseControls.add(gcb);
          allGseControls.add(gcb);
        }

        // 4.4 Parse SampledValueControl (SV)
        final svRegex = RegExp(r'<SampledValueControl\s+([^>]+)(?:/>|>([\s\S]*?)</SampledValueControl>)');
        for (final svMatch in svRegex.allMatches(lnBody)) {
          final attrs = svMatch.group(1)!;
          final name = RegExp(r'name=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? 'SVCB';
          final smvID = RegExp(r'smvID=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? name;
          final datSet = RegExp(r'datSet=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '';
          final smpRate = int.tryParse(RegExp(r'smpRate=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '') ?? 4000;
          final noASDU = int.tryParse(RegExp(r'nofASDU=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '') ?? 1;

          final svcb = SclSampledValueControl(
            name: name,
            svId: smvID,
            datSet: datSet,
            smpRate: smpRate,
            noASDU: noASDU,
          );
          ln.svControls.add(svcb);
          allSvControls.add(svcb);
        }

        // 4.5 Instantiate Server Variables for this LN from LNodeType
        final lnType = lnTypes[lnTypeId];
        if (lnType != null) {
          for (final doElem in lnType.doList) {
            final doType = doTypes[doElem.type];
            if (doType != null) {
              _instantiateDO(
                variables: variables,
                iedName: iedName,
                ldInst: ldInst,
                lnName: ln.lnName,
                doName: doElem.name,
                doType: doType,
                doTypes: doTypes,
                daTypes: daTypes,
                enumTypes: enumTypes,
              );
            }
          }
        }
      }
    }

    // 5. If no variables were found (e.g. empty SCL), create standard default power models
    if (variables.isEmpty) {
      variables.addAll(_createDefaultVariables(iedName));
    }

    return SclParseResult(
      iedName: iedName,
      ip: ip ?? '0.0.0.0',
      port: port,
      ied: ied,
      variables: variables,
      dataSets: allDataSets,
      reportControls: allReportControls,
      gseControls: allGseControls,
      svControls: allSvControls,
      numOfSG: numOfSG,
    );
  }

  static void _instantiateDO({
    required List<ServerVariableModel> variables,
    required String iedName,
    required String ldInst,
    required String lnName,
    required String doName,
    required SclDOType doType,
    required Map<String, SclDOType> doTypes,
    required Map<String, SclDAType> daTypes,
    required Map<String, SclEnumType> enumTypes,
    String prefix = '',
  }) {
    for (final da in doType.daList) {
      final daFullName = prefix.isEmpty ? da.name : '$prefix.${da.name}';

      if (da.bType == 'Struct' && da.type != null && daTypes.containsKey(da.type)) {
        // Expand structured DA (e.g. mag -> f, i)
        final subDAType = daTypes[da.type!]!;
        for (final subElem in subDAType.elements) {
          final leafRef = '$iedName/$ldInst/$lnName.$doName.$daFullName.${subElem.name}';
          final bType = IecBasicType.fromString(subElem.bType);
          final inferredKey = ServerVariableModel.inferNameKey(
            doName: doName,
            daName: '$daFullName.${subElem.name}',
            lnName: lnName,
            ref: leafRef,
          );

          final model = ServerVariableModel(
            reference: leafRef,
            iedName: iedName,
            ldInst: ldInst,
            lnName: lnName,
            doName: doName,
            daName: '$daFullName.${subElem.name}',
            fc: da.fc,
            type: bType,
            cdc: doType.cdc,
            name: '$doName.$daFullName.${subElem.name}',
            nameKey: inferredKey,
            initialValue: bType == IecBasicType.float32 ? 220.0 : null,
            simulation: bType == IecBasicType.float32
                ? SimulationConfig(
                    enabled: true,
                    waveType: EaseWaveType.sine,
                    min: 215,
                    max: 225,
                    durationMs: 3000,
                  )
                : null,
          );
          variables.add(model);
        }
      } else {
        // Leaf DA
        final leafRef = '$iedName/$ldInst/$lnName.$doName.$daFullName';
        final bType = IecBasicType.fromString(da.bType);

        dynamic initialVal;
        if (da.name == 'stVal') {
          initialVal = bType == IecBasicType.boolean ? true : 1;
        } else if (da.name == 'q') {
          initialVal = 0;
        } else if (bType == IecBasicType.float32) {
          initialVal = 50.0;
        }

        final inferredKey = ServerVariableModel.inferNameKey(
          doName: doName,
          daName: daFullName,
          lnName: lnName,
          ref: leafRef,
        );

        final model = ServerVariableModel(
          reference: leafRef,
          iedName: iedName,
          ldInst: ldInst,
          lnName: lnName,
          doName: doName,
          daName: daFullName,
          fc: da.fc,
          type: bType,
          cdc: doType.cdc,
          name: '$doName.$daFullName',
          nameKey: inferredKey,
          initialValue: initialVal,
          desc: '${doType.cdc} - ${da.name}',
        );
        variables.add(model);
      }
    }

    // Expand SDOs (Sub Data Objects)
    for (final sdo in doType.sdoList) {
      final subDOType = doTypes[sdo.type];
      if (subDOType != null) {
        _instantiateDO(
          variables: variables,
          iedName: iedName,
          ldInst: ldInst,
          lnName: lnName,
          doName: '$doName.${sdo.name}',
          doType: subDOType,
          doTypes: doTypes,
          daTypes: daTypes,
          enumTypes: enumTypes,
        );
      }
    }
  }

  // --- Parser Helpers for DataTypeTemplates ---

  static Map<String, SclEnumType> _parseEnumTypes(String xml) {
    final map = <String, SclEnumType>{};
    final regex = RegExp(r'<EnumType\s+[^>]*id=["\x27]([^"\x27]+)["\x27][^>]*>([\s\S]*?)</EnumType>');
    for (final m in regex.allMatches(xml)) {
      final id = m.group(1)!;
      final body = m.group(2)!;
      final values = <int, String>{};
      final valRegex = RegExp(r'<EnumVal\s+ord=["\x27](\d+)["\x27][^>]*>([^<]+)</EnumVal>');
      for (final vm in valRegex.allMatches(body)) {
        values[int.parse(vm.group(1)!)] = vm.group(2)!.trim();
      }
      map[id] = SclEnumType(id: id, values: values);
    }
    return map;
  }

  static Map<String, SclDAType> _parseDATypes(String xml) {
    final map = <String, SclDAType>{};
    final regex = RegExp(r'<DAType\s+[^>]*id=["\x27]([^"\x27]+)["\x27][^>]*>([\s\S]*?)</DAType>');
    for (final m in regex.allMatches(xml)) {
      final id = m.group(1)!;
      final body = m.group(2)!;
      final elements = <SclDAElement>[];

      final bdaRegex = RegExp(
        r'<BDA\s+name=["\x27]([^"\x27]+)["\x27]\s+bType=["\x27]([^"\x27]+)["\x27](?:\s+type=["\x27]([^"\x27]+)["\x27])?',
      );
      for (final bm in bdaRegex.allMatches(body)) {
        elements.add(SclDAElement(
          name: bm.group(1)!,
          bType: bm.group(2)!,
          type: bm.group(3),
          fc: FunctionalConstraint.mx,
        ));
      }
      map[id] = SclDAType(id: id, elements: elements);
    }
    return map;
  }

  static Map<String, SclDOType> _parseDOTypes(String xml) {
    final map = <String, SclDOType>{};
    final regex = RegExp(r'<DOType\s+([^>]+)>([\s\S]*?)</DOType>');
    for (final m in regex.allMatches(xml)) {
      final attrs = m.group(1)!;
      final body = m.group(2)!;

      final id = RegExp(r'id=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '';
      final cdc = RegExp(r'cdc=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? 'SPS';
      final desc = RegExp(r'desc=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1);

      final daList = <SclDAElement>[];
      final daRegex = RegExp(
        r'<DA\s+name=["\x27]([^"\x27]+)["\x27]\s+bType=["\x27]([^"\x27]+)["\x27](?:\s+type=["\x27]([^"\x27]+)["\x27])?\s+fc=["\x27]([^"\x27]+)["\x27]',
      );
      for (final dm in daRegex.allMatches(body)) {
        daList.add(SclDAElement(
          name: dm.group(1)!,
          bType: dm.group(2)!,
          type: dm.group(3),
          fc: FunctionalConstraint.fromCode(dm.group(4)!),
        ));
      }

      final sdoList = <SclSDOElement>[];
      final sdoRegex = RegExp(r'<SDO\s+name=["\x27]([^"\x27]+)["\x27]\s+type=["\x27]([^"\x27]+)["\x27]');
      for (final sm in sdoRegex.allMatches(body)) {
        sdoList.add(SclSDOElement(name: sm.group(1)!, type: sm.group(2)!));
      }

      map[id] = SclDOType(id: id, cdc: cdc, desc: desc, daList: daList, sdoList: sdoList);
    }
    return map;
  }

  static Map<String, SclLNodeType> _parseLNTypes(String xml) {
    final map = <String, SclLNodeType>{};
    final regex = RegExp(r'<LNodeType\s+([^>]+)>([\s\S]*?)</LNodeType>');
    for (final m in regex.allMatches(xml)) {
      final attrs = m.group(1)!;
      final body = m.group(2)!;

      final id = RegExp(r'id=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '';
      final lnClass = RegExp(r'lnClass=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? 'GGIO';
      final desc = RegExp(r'desc=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1);

      final doList = <SclDOElement>[];
      final doRegex = RegExp(r'<DO\s+name=["\x27]([^"\x27]+)["\x27]\s+type=["\x27]([^"\x27]+)["\x27]');
      for (final dm in doRegex.allMatches(body)) {
        doList.add(SclDOElement(name: dm.group(1)!, type: dm.group(2)!));
      }

      map[id] = SclLNodeType(id: id, lnClass: lnClass, desc: desc, doList: doList);
    }
    return map;
  }

  static List<ServerVariableModel> _createDefaultVariables(String iedName) {
    return [
      ServerVariableModel(
        reference: '$iedName/GenericIO/GGIO1.AnIn1.mag.f',
        iedName: iedName,
        ldInst: 'GenericIO',
        lnName: 'GGIO1',
        doName: 'AnIn1',
        daName: 'mag.f',
        fc: FunctionalConstraint.mx,
        type: IecBasicType.float32,
        cdc: 'MV',
        name: 'Phase A Voltage Ua (kV)',
        nameKey: 'point_volt_a',
        initialValue: 220.5,
        isMonitored: true,
        simulation: SimulationConfig(enabled: true, waveType: EaseWaveType.sine, min: 215, max: 225),
      ),
      ServerVariableModel(
        reference: '$iedName/GenericIO/GGIO1.AnIn1.q',
        iedName: iedName,
        ldInst: 'GenericIO',
        lnName: 'GGIO1',
        doName: 'AnIn1',
        daName: 'q',
        fc: FunctionalConstraint.mx,
        type: IecBasicType.quality,
        cdc: 'MV',
        name: 'AnIn1 Quality',
        nameKey: null,
        initialValue: 0,
      ),
      ServerVariableModel(
        reference: '$iedName/GenericIO/GGIO1.SPCSO1.stVal',
        iedName: iedName,
        ldInst: 'GenericIO',
        lnName: 'GGIO1',
        doName: 'SPCSO1',
        daName: 'stVal',
        fc: FunctionalConstraint.st,
        type: IecBasicType.boolean,
        cdc: 'SPC',
        name: '101 Breaker Closed Status',
        nameKey: 'point_breaker_101',
        initialValue: true,
        isMonitored: true,
      ),
      ServerVariableModel(
        reference: '$iedName/GenericIO/GGIO1.SPCSO1.q',
        iedName: iedName,
        ldInst: 'GenericIO',
        lnName: 'GGIO1',
        doName: 'SPCSO1',
        daName: 'q',
        fc: FunctionalConstraint.st,
        type: IecBasicType.quality,
        cdc: 'SPC',
        name: 'SPCSO1 Quality',
        nameKey: null,
        initialValue: 0,
      ),
    ];
  }

  static String? _inferLDeviceNameKey(String ldInst) {
    final lower = ldInst.toLowerCase();
    if (lower == 'genericio') return 'ld_generic_io';
    if (lower == 'prot') return 'ld_prot';
    if (lower == 'ctrl' || lower == 'control') return 'ld_ctrl';
    if (lower == 'meas' || lower == 'measurements') return 'ld_meas';
    if (lower == 'dwtg') return 'ld_dwtg';
    return null;
  }

  static String? _inferLnNameKey(String lnClass, String inst) {
    final upper = lnClass.toUpperCase();
    if (upper == 'LLN0') return 'ln_lln0';
    if (upper == 'LPHD') return 'ln_lphd';
    if (upper == 'GGIO') return 'ln_ggio';
    if (upper == 'MMXU') return 'ln_mmxu';
    if (upper == 'CSWI') return 'ln_cswi';
    if (upper == 'XCBR') return 'ln_xcbr';
    if (upper == 'XSWI') return 'ln_xswi';
    if (upper == 'PTOC') return 'ln_ptoc';
    if (upper == 'PTRC') return 'ln_ptrc';
    return null;
  }

  static String? _inferDataSetNameKey(String dsName) {
    final lower = dsName.toLowerCase();
    if (lower == 'events') return 'preset_ds_events';
    if (lower == 'events2') return 'preset_ds_events2';
    if (lower == 'measurements') return 'preset_ds_measurements';
    if (lower == 'controlevents') return 'preset_ds_control_events';
    if (lower.contains('goose')) return 'preset_ds_goose';
    if (lower.contains('alarm')) return 'preset_ds_alarms';
    return null;
  }

  static String? _inferRcbNameKey(String rptName) {
    final lower = rptName.toLowerCase();
    if (lower == 'eventsrcb') return 'preset_rcb_events';
    if (lower == 'eventsrcbpreconf') return 'preset_rcb_events_preconf';
    if (lower == 'eventsindexed') return 'preset_rcb_events_indexed';
    if (lower == 'eventsbrcb') return 'preset_rcb_events_brcb';
    if (lower == 'eventsbrcbpreconf') return 'preset_rcb_events_brcb_preconf';
    if (lower == 'measurements') return 'preset_rcb_measurements';
    if (lower == 'controleventsrcb') return 'preset_rcb_control_events';
    return null;
  }

  static String? _inferGcbNameKey(String gcbName) {
    final lower = gcbName.toLowerCase();
    if (lower.contains('trip')) return 'preset_gcb_trip';
    if (lower.contains('gcb') || lower.contains('goose')) return 'preset_gcb_goose';
    return null;
  }
}
