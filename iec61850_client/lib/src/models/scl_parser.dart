import 'client_variable_model.dart';
import 'scl_models.dart';

class SclParseResult {
  final String iedName;
  final String? ip;
  final int port;
  final SclIED ied;
  final List<ClientVariableModel> variables;
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
  static SclParseResult parseString(String xmlContent) => parse(xmlContent);

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
    final ied = SclIED(name: iedName);
    final variables = <ClientVariableModel>[];
    final allDataSets = <SclDataSet>[];
    final allReportControls = <SclReportControl>[];
    final allGseControls = <SclGSEControl>[];
    final allSvControls = <SclSampledValueControl>[];
    int numOfSg = 1;

    // Check Setting Groups count
    final confSgMatch = RegExp(r'<ConfSG\s+[^>]*numOfSGs=["\x27](\d+)["\x27]').firstMatch(xmlContent);
    if (confSgMatch != null) {
      numOfSg = int.tryParse(confSgMatch.group(1)!) ?? 1;
    }

    final ldRegex = RegExp(r'<LDevice\s+[^>]*inst=["\x27]([^"\x27]+)["\x27][^>]*>([\s\S]*?)</LDevice>');
    for (final ldMatch in ldRegex.allMatches(xmlContent)) {
      final ldInst = ldMatch.group(1)!;
      final ldBody = ldMatch.group(2)!;
      final lDevice = SclLDevice(inst: ldInst);
      ied.lDevices.add(lDevice);

      final lnRegex = RegExp(r'<(?:LN0|LN)\s+([^>]+)(?:/>|>([\s\S]*?)</(?:LN0|LN)>)');
      for (final lnMatch in lnRegex.allMatches(ldBody)) {
        final lnAttrs = lnMatch.group(1)!;
        final lnBody = lnMatch.group(2) ?? '';

        final lnClassMatch = RegExp(r'lnClass=["\x27]([^"\x27]+)["\x27]').firstMatch(lnAttrs);
        final lnClass = lnClassMatch?.group(1) ?? 'LLN0';

        final instMatch = RegExp(r'inst=["\x27]([^"\x27]*?)["\x27]').firstMatch(lnAttrs);
        final inst = instMatch?.group(1) ?? '';

        final prefixMatch = RegExp(r'prefix=["\x27]([^"\x27]*?)["\x27]').firstMatch(lnAttrs);
        final prefix = prefixMatch?.group(1) ?? '';

        final lnTypeMatch = RegExp(r'lnType=["\x27]([^"\x27]+)["\x27]').firstMatch(lnAttrs);
        final lnTypeId = lnTypeMatch?.group(1) ?? '';

        final ln = SclLN(
          lnClass: lnClass,
          inst: inst,
          prefix: prefix,
          lnType: lnTypeId,
        );
        lDevice.logicalNodes.add(ln);

        // 4.1 Parse DataSets inside LN
        final dsRegex = RegExp(r'<DataSet\s+[^>]*name=["\x27]([^"\x27]+)["\x27][^>]*>([\s\S]*?)</DataSet>');
        for (final dsMatch in dsRegex.allMatches(lnBody)) {
          final dsName = dsMatch.group(1)!;
          final dsBody = dsMatch.group(2)!;
          final ds = SclDataSet(
            name: dsName,
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

        // 4.5 Instantiate Client Variables for this LN from LNodeType
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
                daTypes: daTypes,
                enumTypes: enumTypes,
              );
            }
          }
        }
      }
    }

    return SclParseResult(
      iedName: iedName,
      ip: ip,
      port: port,
      ied: ied,
      variables: variables,
      dataSets: allDataSets,
      reportControls: allReportControls,
      gseControls: allGseControls,
      svControls: allSvControls,
      numOfSG: numOfSg,
    );
  }

  static void _instantiateDO({
    required List<ClientVariableModel> variables,
    required String iedName,
    required String ldInst,
    required String lnName,
    required String doName,
    required SclDOType doType,
    required Map<String, SclDAType> daTypes,
    required Map<String, SclEnumType> enumTypes,
  }) {
    for (final daElem in doType.daList) {
      if (daElem.bType == IecBasicType.structure) {
        // Expand DAType recursively
        final daType = daTypes[daElem.type];
        if (daType != null) {
          for (final bda in daType.bdaList) {
            _addVariable(
              variables: variables,
              iedName: iedName,
              ldInst: ldInst,
              lnName: lnName,
              doName: doName,
              daName: '${daElem.name}.${bda.name}',
              fc: bda.fc != FunctionalConstraint.unknown ? bda.fc : daElem.fc,
              type: bda.bType,
              cdc: doType.cdc,
              initialVal: bda.val ?? daElem.val,
            );
          }
        }
      } else {
        _addVariable(
          variables: variables,
          iedName: iedName,
          ldInst: ldInst,
          lnName: lnName,
          doName: doName,
          daName: daElem.name,
          fc: daElem.fc,
          type: daElem.bType,
          cdc: doType.cdc,
          initialVal: daElem.val,
        );
      }
    }
  }

  static void _addVariable({
    required List<ClientVariableModel> variables,
    required String iedName,
    required String ldInst,
    required String lnName,
    required String doName,
    required String daName,
    required FunctionalConstraint fc,
    required IecBasicType type,
    required String cdc,
    dynamic initialVal,
  }) {
    final ref = '$iedName$ldInst/$lnName.$doName.$daName';

    dynamic parsedVal;
    if (initialVal != null) {
      if (type == IecBasicType.boolean) {
        parsedVal = initialVal.toString().toLowerCase() == 'true' || initialVal.toString() == '1';
      } else if (type == IecBasicType.float32 || type == IecBasicType.float64) {
        parsedVal = double.tryParse(initialVal.toString());
      } else if (type.name.startsWith('int') || type.name.startsWith('uint')) {
        parsedVal = int.tryParse(initialVal.toString());
      } else {
        parsedVal = initialVal.toString();
      }
    }

    final inferredKey = ClientVariableModel.inferNameKey(
      lnName: lnName,
      doName: doName,
      daName: daName,
      reference: ref,
    );

    final v = ClientVariableModel(
      reference: ref,
      iedName: iedName,
      ldInst: ldInst,
      lnName: lnName,
      doName: doName,
      daName: daName,
      fc: fc,
      type: type,
      cdc: cdc,
      initialValue: parsedVal,
      nameKey: inferredKey,
    );

    variables.add(v);
  }

  static Map<String, SclEnumType> _parseEnumTypes(String xml) {
    final map = <String, SclEnumType>{};
    final enumRegex = RegExp(r'<EnumType\s+[^>]*id=["\x27]([^"\x27]+)["\x27][^>]*>([\s\S]*?)</EnumType>');
    for (final m in enumRegex.allMatches(xml)) {
      final id = m.group(1)!;
      final body = m.group(2)!;
      final valMap = <int, String>{};
      final valRegex = RegExp(r'<EnumVal\s+[^>]*ord=["\x27](\d+)["\x27][^>]*>([^<]+)</EnumVal>');
      for (final vm in valRegex.allMatches(body)) {
        final ord = int.tryParse(vm.group(1)!) ?? 0;
        final name = vm.group(2)!.trim();
        valMap[ord] = name;
      }
      map[id] = SclEnumType(id: id, values: valMap);
    }
    return map;
  }

  static Map<String, SclDAType> _parseDATypes(String xml) {
    final map = <String, SclDAType>{};
    final daRegex = RegExp(r'<DAType\s+[^>]*id=["\x27]([^"\x27]+)["\x27][^>]*>([\s\S]*?)</DAType>');
    for (final m in daRegex.allMatches(xml)) {
      final id = m.group(1)!;
      final body = m.group(2)!;
      final daType = SclDAType(id: id);

      final bdaRegex = RegExp(r'<BDA\s+([^>]+)(?:/>|>([\s\S]*?)</BDA>)');
      for (final bm in bdaRegex.allMatches(body)) {
        final bAttrs = bm.group(1)!;
        final valContent = bm.group(2);

        final name = RegExp(r'name=["\x27]([^"\x27]+)["\x27]').firstMatch(bAttrs)?.group(1);
        if (name == null) continue;

        final bTypeStr = RegExp(r'bType=["\x27]([^"\x27]+)["\x27]').firstMatch(bAttrs)?.group(1) ?? 'Struct';
        final type = RegExp(r'type=["\x27]([^"\x27]+)["\x27]').firstMatch(bAttrs)?.group(1);
        final fcStr = RegExp(r'fc=["\x27]([^"\x27]+)["\x27]').firstMatch(bAttrs)?.group(1);

        String? val;
        if (valContent != null) {
          final vMatch = RegExp(r'<Val>([^<]+)</Val>').firstMatch(valContent);
          if (vMatch != null) val = vMatch.group(1)?.trim();
        }

        daType.bdaList.add(SclDATypeElement(
          name: name,
          bType: IecBasicType.fromBType(bTypeStr),
          fc: fcStr != null ? FunctionalConstraint.fromCode(fcStr) : FunctionalConstraint.unknown,
          type: type,
          val: val,
        ));
      }
      map[id] = daType;
    }
    return map;
  }

  static Map<String, SclDOType> _parseDOTypes(String xml) {
    final map = <String, SclDOType>{};
    final doRegex = RegExp(r'<DOType\s+([^>]+)>([\s\S]*?)</DOType>');
    for (final m in doRegex.allMatches(xml)) {
      final attrs = m.group(1)!;
      final body = m.group(2)!;

      final id = RegExp(r'id=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '';
      final cdc = RegExp(r'cdc=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '';

      final doType = SclDOType(id: id, cdc: cdc);

      final daRegex = RegExp(r'<DA\s+([^>]+)(?:/>|>([\s\S]*?)</DA>)');
      for (final dm in daRegex.allMatches(body)) {
        final daAttrs = dm.group(1)!;
        final valContent = dm.group(2);

        final name = RegExp(r'name=["\x27]([^"\x27]+)["\x27]').firstMatch(daAttrs)?.group(1);
        if (name == null) continue;

        final bTypeStr = RegExp(r'bType=["\x27]([^"\x27]+)["\x27]').firstMatch(daAttrs)?.group(1) ?? 'Struct';
        final type = RegExp(r'type=["\x27]([^"\x27]+)["\x27]').firstMatch(daAttrs)?.group(1) ?? '';
        final fcStr = RegExp(r'fc=["\x27]([^"\x27]+)["\x27]').firstMatch(daAttrs)?.group(1) ?? 'ST';

        String? val;
        if (valContent != null) {
          final vMatch = RegExp(r'<Val>([^<]+)</Val>').firstMatch(valContent);
          if (vMatch != null) val = vMatch.group(1)?.trim();
        }

        doType.daList.add(SclDOTypeElement(
          name: name,
          type: type,
          fc: FunctionalConstraint.fromCode(fcStr),
          bType: IecBasicType.fromBType(bTypeStr),
          val: val,
        ));
      }
      map[id] = doType;
    }
    return map;
  }

  static Map<String, SclLNodeType> _parseLNTypes(String xml) {
    final map = <String, SclLNodeType>{};
    final lnRegex = RegExp(r'<LNodeType\s+([^>]+)>([\s\S]*?)</LNodeType>');
    for (final m in lnRegex.allMatches(xml)) {
      final attrs = m.group(1)!;
      final body = m.group(2)!;

      final id = RegExp(r'id=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '';
      final lnClass = RegExp(r'lnClass=["\x27]([^"\x27]+)["\x27]').firstMatch(attrs)?.group(1) ?? '';

      final lnType = SclLNodeType(id: id, lnClass: lnClass);

      final doRegex = RegExp(r'<DO\s+name=["\x27]([^"\x27]+)["\x27]\s+type=["\x27]([^"\x27]+)["\x27]');
      for (final dm in doRegex.allMatches(body)) {
        final name = dm.group(1)!;
        final type = dm.group(2)!;
        lnType.doList.add(SclLNodeTypeElement(name: name, type: type));
      }
      map[id] = lnType;
    }
    return map;
  }
}
