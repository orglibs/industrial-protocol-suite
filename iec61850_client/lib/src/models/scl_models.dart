import '../i18n/app_i18n.dart';
import 'dictionary_service.dart';

/// Functional Constraints defined in IEC 61850-7-2
enum FunctionalConstraint {
  st('ST', 'Status (ST)'),
  mx('MX', 'Measurand (MX)'),
  co('CO', 'Control (CO)'),
  sp('SP', 'Set Point (SP)'),
  sv('SV', 'Substitution (SV)'),
  cf('CF', 'Configuration (CF)'),
  dc('DC', 'Description (DC)'),
  sg('SG', 'Setting Group (SG)'),
  se('SE', 'Setting Group Editable (SE)'),
  sr('SR', 'Service Response (SR)'),
  or('OR', 'Operate Received (OR)'),
  bl('BL', 'Blocking (BL)'),
  ex('EX', 'Extended (EX)'),
  unknown('XX', 'Unknown Constraint');

  final String code;
  final String englishDesc;
  const FunctionalConstraint(this.code, this.englishDesc);

  String get desc {
    final key = 'fc_${code.toLowerCase()}';
    final translated = AppI18n.instance.t(key);
    return translated.isNotEmpty && translated != key ? translated : englishDesc;
  }

  static FunctionalConstraint fromCode(String code) {
    final upper = code.trim().toUpperCase();
    for (final fc in FunctionalConstraint.values) {
      if (fc.code == upper) return fc;
    }
    return FunctionalConstraint.unknown;
  }
}

/// IEC 61850 Basic Data Types
enum IecBasicType {
  boolean,
  int8,
  int16,
  int32,
  int64,
  uint8,
  uint16,
  uint32,
  float32,
  float64,
  visibleString,
  unicodeString,
  bitString,
  octetString,
  utcTime,
  quality,
  check,
  structure,
  unknown;

  static IecBasicType fromBType(String bType) {
    final lower = bType.trim().toLowerCase();
    switch (lower) {
      case 'boolean':
      case 'bool':
        return IecBasicType.boolean;
      case 'int8':
        return IecBasicType.int8;
      case 'int16':
        return IecBasicType.int16;
      case 'int32':
      case 'int':
        return IecBasicType.int32;
      case 'int64':
        return IecBasicType.int64;
      case 'int8u':
      case 'uint8':
        return IecBasicType.uint8;
      case 'int16u':
      case 'uint16':
        return IecBasicType.uint16;
      case 'int32u':
      case 'uint32':
        return IecBasicType.uint32;
      case 'float32':
      case 'float':
        return IecBasicType.float32;
      case 'float64':
      case 'double':
        return IecBasicType.float64;
      case 'visiblestring129':
      case 'visiblestring255':
      case 'visstring':
      case 'visiblestring':
        return IecBasicType.visibleString;
      case 'unicodestring':
        return IecBasicType.unicodeString;
      case 'bitstring':
        return IecBasicType.bitString;
      case 'octetstring':
      case 'octet64':
        return IecBasicType.octetString;
      case 'timestamp':
      case 'utctime':
        return IecBasicType.utcTime;
      case 'quality':
      case 'q':
        return IecBasicType.quality;
      case 'check':
        return IecBasicType.check;
      case 'struct':
      case 'structure':
        return IecBasicType.structure;
      default:
        return IecBasicType.visibleString;
    }
  }
}

/// SCL FCDA Entry
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
  final String? desc;
  String ldInst;
  String lnName;
  final List<SclFCDA> fcdaList;
  bool isDynamic;

  SclDataSet({
    required this.name,
    this.desc,
    this.ldInst = '',
    this.lnName = '',
    List<SclFCDA>? fcdaList,
    this.isDynamic = false,
  }) : fcdaList = fcdaList ?? [];

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
  final String rptId;
  final bool buffered;
  int bufTime; // in milliseconds
  final String datSet;
  int intgPd; // integrity period in milliseconds
  int confRev;
  final TriggerOptions trgOps;
  final ReportOptFields optFields;
  final int maxClients;
  String ldInst;
  String lnName;

  // Runtime client state
  bool rptEna;
  bool resv;
  int sqNum;
  DateTime? lastReportTime;

  SclReportControl({
    required this.name,
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
    this.resv = false,
    this.sqNum = 0,
    this.lastReportTime,
  })  : trgOps = trgOps ?? TriggerOptions(),
        optFields = optFields ?? ReportOptFields();
}

/// SCL GOOSE Control Block (GCB)
class SclGSEControl {
  final String name;
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
    required this.goId,
    required this.datSet,
    this.confRev = 1,
    this.dstAddress = '01-0C-CD-01-00-01',
    this.appId = 0x0001,
    this.vlanId = 0,
    this.minTime = 4,
    this.maxTime = 1000,
  });
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
  final String? desc;
  final List<SclDataSet> dataSets;
  final List<SclReportControl> reportControls;
  final List<SclGSEControl> gseControls;
  final List<SclSampledValueControl> svControls;

  SclLN({
    required this.lnClass,
    this.inst = '',
    this.prefix = '',
    required this.lnType,
    this.desc,
    List<SclDataSet>? dataSets,
    List<SclReportControl>? reportControls,
    List<SclGSEControl>? gseControls,
    List<SclSampledValueControl>? svControls,
  })  : dataSets = dataSets ?? [],
        reportControls = reportControls ?? [],
        gseControls = gseControls ?? [],
        svControls = svControls ?? [];

  String get lnName => '$prefix$lnClass$inst';
  String? get displayDesc {
    if (desc != null && desc!.isNotEmpty) return desc;
    return DictionaryService.instance.lookupLn(lnClass);
  }
}

/// SCL Logical Device (LDevice)
class SclLDevice {
  final String inst;
  final String? desc;
  final List<SclLN> logicalNodes;

  SclLDevice({
    required this.inst,
    this.desc,
    List<SclLN>? logicalNodes,
  }) : logicalNodes = logicalNodes ?? [];
}

/// SCL IED (Intelligent Electronic Device)
class SclIED {
  final String name;
  final String? desc;
  final List<SclLDevice> lDevices;

  SclIED({
    required this.name,
    this.desc,
    List<SclLDevice>? lDevices,
  }) : lDevices = lDevices ?? [];
}

// DataTypeTemplates elements
class SclDOTypeElement {
  final String name;
  final String type;
  final FunctionalConstraint fc;
  final IecBasicType bType;
  final String? desc;
  final dynamic val;

  SclDOTypeElement({
    required this.name,
    required this.type,
    required this.fc,
    required this.bType,
    this.desc,
    this.val,
  });

  String? get displayDesc {
    if (desc != null && desc!.isNotEmpty) return desc;
    return DictionaryService.instance.lookupDo(name);
  }
}

class SclDOType {
  final String id;
  final String cdc;
  final String? desc;
  final List<SclDOTypeElement> daList;

  SclDOType({
    required this.id,
    required this.cdc,
    this.desc,
    List<SclDOTypeElement>? daList,
  }) : daList = daList ?? [];

  String? get displayDesc {
    if (desc != null && desc!.isNotEmpty) return desc;
    return DictionaryService.instance.lookupCdc(cdc);
  }
}

class SclLNodeTypeElement {
  final String name;
  final String type;
  final String? desc;

  SclLNodeTypeElement({
    required this.name,
    required this.type,
    this.desc,
  });

  String? get displayDesc {
    if (desc != null && desc!.isNotEmpty) return desc;
    return DictionaryService.instance.lookupDo(name);
  }
}

class SclLNodeType {
  final String id;
  final String lnClass;
  final String? desc;
  final List<SclLNodeTypeElement> doList;

  SclLNodeType({
    required this.id,
    required this.lnClass,
    this.desc,
    List<SclLNodeTypeElement>? doList,
  }) : doList = doList ?? [];

  String? get displayDesc {
    if (desc != null && desc!.isNotEmpty) return desc;
    return DictionaryService.instance.lookupLn(lnClass);
  }
}

class SclDATypeElement {
  final String name;
  final IecBasicType bType;
  final FunctionalConstraint fc;
  final String? type;
  final dynamic val;

  SclDATypeElement({
    required this.name,
    required this.bType,
    required this.fc,
    this.type,
    this.val,
  });

  String? get displayDesc {
    return DictionaryService.instance.lookupDa(name);
  }
}

class SclDAType {
  final String id;
  final List<SclDATypeElement> bdaList;

  SclDAType({
    required this.id,
    List<SclDATypeElement>? bdaList,
  }) : bdaList = bdaList ?? [];
}

class SclEnumType {
  final String id;
  final Map<int, String> values;

  SclEnumType({required this.id, required this.values});
}
