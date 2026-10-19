import '../i18n/app_i18n.dart';
import 'dictionary_service.dart';

/// Standard IEC 61850 Functional Constraints (FC)
enum FunctionalConstraint {
  st('ST', 'Status (ST)'),
  mx('MX', 'Measurand (MX)'),
  co('CO', 'Control (CO)'),
  sp('SP', 'Setpoint (SP)'),
  sv('SV', 'Substitution (SV)'),
  cf('CF', 'Configuration (CF)'),
  dc('DC', 'Description (DC)'),
  sg('SG', 'Setting Group (SG)'),
  se('SE', 'Setting Group Edit (SE)'),
  rp('RP', 'Unbuffered Report (RP)'),
  br('BR', 'Buffered Report (BR)'),
  lg('LG', 'Log Control (LG)'),
  go('GO', 'GOOSE Control (GO)'),
  ms('MS', 'Multicast SV (MS)'),
  us('US', 'Unicast SV (US)');

  final String code;
  final String englishLabel;
  const FunctionalConstraint(this.code, this.englishLabel);

  String get label {
    final key = 'fc_${code.toLowerCase()}';
    final translated = AppI18n.instance.t(key);
    return translated.isNotEmpty && translated != key ? translated : englishLabel;
  }

  static FunctionalConstraint fromCode(String code) {
    final upper = code.toUpperCase().trim();
    for (final fc in FunctionalConstraint.values) {
      if (fc.code == upper) return fc;
    }
    return FunctionalConstraint.st;
  }
}

/// IEC 61850 Basic Data Types (Part 7-2)
enum IecBasicType {
  boolean('BOOLEAN'),
  int8('INT8'),
  int16('INT16'),
  int32('INT32'),
  int64('INT64'),
  uint8('INT8U'),
  uint16('INT16U'),
  uint32('INT32U'),
  float32('FLOAT32'),
  float64('FLOAT64'),
  bitString('BIT_STRING'),
  octetString('OCTET_STRING'),
  visibleString('VISIBLE_STRING'),
  unicodeString('UNICODE_STRING'),
  utcTime('TIMESTAMP'),
  quality('Quality'),
  check('Check'),
  tcmd('Tcmd'),
  dbpos('Dbpos');

  final String name;
  const IecBasicType(this.name);

  static IecBasicType fromString(String str) {
    final s = str.toUpperCase().trim();
    if (s == 'BOOLEAN') return IecBasicType.boolean;
    if (s == 'INT8') return IecBasicType.int8;
    if (s == 'INT16') return IecBasicType.int16;
    if (s == 'INT32') return IecBasicType.int32;
    if (s == 'INT64') return IecBasicType.int64;
    if (s == 'INT8U') return IecBasicType.uint8;
    if (s == 'INT16U') return IecBasicType.uint16;
    if (s == 'INT32U') return IecBasicType.uint32;
    if (s == 'FLOAT32') return IecBasicType.float32;
    if (s == 'FLOAT64') return IecBasicType.float64;
    if (s.contains('BIT')) return IecBasicType.bitString;
    if (s.contains('OCTET')) return IecBasicType.octetString;
    if (s.contains('TIME') || s == 'TIMESTAMP') return IecBasicType.utcTime;
    if (s == 'QUALITY') return IecBasicType.quality;
    return IecBasicType.visibleString;
  }
}

/// SCL FCDA (Function Constraint Data Attribute in DataSet)
class SclFCDA {
  final String ldInst;
  final String prefix;
  final String lnClass;
  final String lnInst;
  final String doName;
  final String? daName;
  final FunctionalConstraint fc;

  SclFCDA({
    required this.ldInst,
    this.prefix = '',
    required this.lnClass,
    this.lnInst = '',
    required this.doName,
    this.daName,
    required this.fc,
  });

  String get lnName => '$prefix$lnClass$lnInst';
  String get fullLnName => lnName;
  String get dataRef => daName != null ? '$doName.$daName' : doName;
  String get fullPath => '$ldInst/$lnName.$dataRef';
}

/// SCL DataSet Model
class SclDataSet {
  final String name;
  String? nameKey;
  final String? desc;
  String ldInst;
  String lnName;
  final List<SclFCDA> fcdaList;

  SclDataSet({
    required this.name,
    this.nameKey,
    this.desc,
    this.ldInst = '',
    this.lnName = '',
    List<SclFCDA>? fcdaList,
  }) : fcdaList = fcdaList ?? [];

  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : name;

  List<SclFCDA> get entries => fcdaList;
}

/// Trigger Options for Report Control
class TriggerOptions {
  bool dataChange;
  bool qualityChange;
  bool dataUpdate;
  bool integrity;
  bool generalInterrogation;

  TriggerOptions({
    this.dataChange = false,
    this.qualityChange = false,
    this.dataUpdate = false,
    this.integrity = true,
    this.generalInterrogation = true,
  });
}

/// Optional Fields for Report Control
class ReportOptFields {
  bool sequenceNumber;
  bool reportTimestamp;
  bool reasonCode;
  bool dataSet;
  bool dataRef;
  bool bufferOverflow;
  bool entryId;
  bool configRevision;
  bool segmentation;

  ReportOptFields({
    this.sequenceNumber = true,
    this.reportTimestamp = true,
    this.reasonCode = true,
    this.dataSet = true,
    this.dataRef = false,
    this.bufferOverflow = false,
    this.entryId = true,
    this.configRevision = true,
    this.segmentation = false,
  });
}

/// SCL Report Control Block (BRCB / URCB)
class SclReportControl {
  final String name;
  String? nameKey;
  final String rptId;
  final bool buffered;
  final int bufTime; // in milliseconds
  final String datSet;
  final int intgPd; // integrity period in milliseconds
  final int confRev;
  final TriggerOptions trgOps;
  final ReportOptFields optFields;
  final int maxClients;
  String ldInst;
  String lnName;

  // Runtime fields
  bool rptEna;
  int sqNum;
  DateTime? lastReportTime;

  SclReportControl({
    required this.name,
    this.nameKey,
    required this.rptId,
    required this.buffered,
    this.bufTime = 50,
    required this.datSet,
    this.intgPd = 1000,
    this.confRev = 1,
    TriggerOptions? trgOps,
    ReportOptFields? optFields,
    this.maxClients = 1,
    this.ldInst = '',
    this.lnName = '',
    this.rptEna = false,
    this.sqNum = 0,
    this.lastReportTime,
  })  : trgOps = trgOps ?? TriggerOptions(),
        optFields = optFields ?? ReportOptFields();

  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : name;
}

/// SCL GOOSE Control Block (GCB)
class SclGSEControl {
  final String name;
  String? nameKey;
  final String goId;
  final String datSet;
  final int confRev;
  final String dstAddress;
  final int appId;
  final int vlanId;
  final int minTime; // in ms
  final int maxTime; // in ms

  SclGSEControl({
    required this.name,
    this.nameKey,
    required this.goId,
    required this.datSet,
    this.confRev = 1,
    this.dstAddress = '01-0C-CD-01-00-01',
    this.appId = 0x0001,
    this.vlanId = 0,
    this.minTime = 4,
    this.maxTime = 1000,
  });

  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : name;
}

/// SCL Sampled Value Control Block (SVCB)
class SclSampledValueControl {
  final String name;
  final String svId;
  final String datSet;
  final int confRev;
  final int smpRate; // e.g. 4000
  final int noASDU;
  final int appId;
  final int vlanId;
  final bool multicast;

  SclSampledValueControl({
    required this.name,
    required this.svId,
    required this.datSet,
    this.confRev = 1,
    this.smpRate = 4000,
    this.noASDU = 1,
    this.appId = 0x4000,
    this.vlanId = 0,
    this.multicast = true,
  });
}

/// SCL Logical Node (LN0 / LN)
class SclLN {
  final String lnClass;
  final String inst;
  final String prefix;
  final String lnType;
  String? nameKey;
  final String? desc;
  String? descKey;
  final List<SclDataSet> dataSets;
  final List<SclReportControl> reportControls;
  final List<SclGSEControl> gseControls;
  final List<SclSampledValueControl> svControls;

  SclLN({
    required this.lnClass,
    this.inst = '',
    this.prefix = '',
    required this.lnType,
    this.nameKey,
    this.desc,
    this.descKey,
    List<SclDataSet>? dataSets,
    List<SclReportControl>? reportControls,
    List<SclGSEControl>? gseControls,
    List<SclSampledValueControl>? svControls,
  })  : dataSets = dataSets ?? [],
        reportControls = reportControls ?? [],
        gseControls = gseControls ?? [],
        svControls = svControls ?? [];

  String get lnName => '$prefix$lnClass$inst';

  String get displayName {
    if (nameKey != null && nameKey!.isNotEmpty) {
      return AppI18n.instance.t(nameKey!);
    }
    final dictDesc = DictionaryService.instance.getLogicalNode(lnClass);
    if (dictDesc != null) {
      return '$lnName (${dictDesc.display})';
    }
    return lnName;
  }

  String? get displayDesc {
    if (descKey != null && descKey!.isNotEmpty) {
      return AppI18n.instance.t(descKey!);
    }
    final dictDesc = DictionaryService.instance.getLogicalNode(lnClass);
    if (dictDesc != null) {
      return dictDesc.display;
    }
    return desc;
  }
}

/// SCL Logical Device (LDevice)
class SclLDevice {
  final String inst;
  String? nameKey;
  final String? desc;
  String? descKey;
  final List<SclLN> logicalNodes;

  SclLDevice({
    required this.inst,
    this.nameKey,
    this.desc,
    this.descKey,
    List<SclLN>? logicalNodes,
  }) : logicalNodes = logicalNodes ?? [];

  String get displayName {
    if (nameKey != null && nameKey!.isNotEmpty) {
      return AppI18n.instance.t(nameKey!);
    }
    return inst;
  }

  String? get displayDesc {
    if (descKey != null && descKey!.isNotEmpty) {
      return AppI18n.instance.t(descKey!);
    }
    return desc;
  }

  SclLN? findLN(String name) {
    for (final ln in logicalNodes) {
      if (ln.lnName == name) return ln;
    }
    return null;
  }
}

/// SCL IED (Intelligent Electronic Device)
class SclIED {
  final String name;
  String? nameKey;
  final String? desc;
  String? descKey;
  final String? type;
  final String? manufacturer;
  final List<SclLDevice> lDevices;

  SclIED({
    required this.name,
    this.nameKey,
    this.desc,
    this.descKey,
    this.type,
    this.manufacturer,
    List<SclLDevice>? lDevices,
  }) : lDevices = lDevices ?? [];

  String get displayName {
    if (nameKey != null && nameKey!.isNotEmpty) {
      return AppI18n.instance.t(nameKey!);
    }
    return name;
  }

  String? get displayDesc {
    if (descKey != null && descKey!.isNotEmpty) {
      return AppI18n.instance.t(descKey!);
    }
    return desc;
  }

  SclLDevice? findLDevice(String inst) {
    for (final ld in lDevices) {
      if (ld.inst == inst) return ld;
    }
    return null;
  }
}

/// SCL DataTypeTemplates: DOType, DAType, LNodeType, EnumType
class SclEnumType {
  final String id;
  final Map<int, String> values; // ord -> enum string
  SclEnumType({required this.id, required this.values});
}

class SclDAType {
  final String id;
  final List<SclDAElement> elements;
  SclDAType({required this.id, required this.elements});
}

class SclDAElement {
  final String name;
  final String bType;
  final String? type; // references DAType or EnumType
  final FunctionalConstraint fc;
  final String? dchg;
  final String? qchg;

  SclDAElement({
    required this.name,
    required this.bType,
    this.type,
    required this.fc,
    this.dchg,
    this.qchg,
  });
}

class SclDOType {
  final String id;
  final String cdc;
  final String? desc;
  final List<SclDAElement> daList;
  final List<SclSDOElement> sdoList;

  SclDOType({
    required this.id,
    required this.cdc,
    this.desc,
    List<SclDAElement>? daList,
    List<SclSDOElement>? sdoList,
  })  : daList = daList ?? [],
        sdoList = sdoList ?? [];

  String get cdcDisplay {
    final d = DictionaryService.instance.getCdc(cdc);
    return d != null ? '$cdc (${d.display})' : cdc;
  }
}

class SclSDOElement {
  final String name;
  final String type; // references another DOType
  SclSDOElement({required this.name, required this.type});
}

class SclLNodeType {
  final String id;
  final String lnClass;
  final String? desc;
  final List<SclDOElement> doList;

  SclLNodeType({
    required this.id,
    required this.lnClass,
    this.desc,
    List<SclDOElement>? doList,
  }) : doList = doList ?? [];
}

class SclDOElement {
  final String name;
  final String type; // references DOType
  final String? desc;
  SclDOElement({required this.name, required this.type, this.desc});
}
