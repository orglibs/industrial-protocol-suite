import '../i18n/app_i18n.dart';
import 'asdu_types.dart';

/// Common ASDU Type IDs used in IEC 60870-5-104
enum AsduTypeId {
  // --- Monitor Direction ---
  mSpNa1(1, 'M_SP_NA_1', 'Single point'),
  mSpTa1(2, 'M_SP_TA_1', 'Single point with CP24Time2a'),
  mDpNa1(3, 'M_DP_NA_1', 'Double point'),
  mDpTa1(4, 'M_DP_TA_1', 'Double point with CP24Time2a'),
  mStNa1(5, 'M_ST_NA_1', 'Step position'),
  mStTa1(6, 'M_ST_TA_1', 'Step position with CP24Time2a'),
  mBoNa1(7, 'M_BO_NA_1', 'Bitstring of 32 bits'),
  mBoTa1(8, 'M_BO_TA_1', 'Bitstring with CP24Time2a'),
  mMeNa1(9, 'M_ME_NA_1', 'Measured value, normalized'),
  mMeTa1(10, 'M_ME_TA_1', 'Measured normalized with CP24Time2a'),
  mMeNb1(11, 'M_ME_NB_1', 'Measured value, scaled'),
  mMeTb1(12, 'M_ME_TB_1', 'Measured scaled with CP24Time2a'),
  mMeNc1(13, 'M_ME_NC_1', 'Measured value, short float'),
  mMeTc1(14, 'M_ME_TC_1', 'Measured short float with CP24Time2a'),
  mItNa1(15, 'M_IT_NA_1', 'Integrated totals'),
  mItTa1(16, 'M_IT_TA_1', 'Integrated totals with CP24Time2a'),
  mMeNd1(21, 'M_ME_ND_1', 'Normalized without quality'),

  // --- Monitor Direction CP56Time2a ---
  mSpTb1(30, 'M_SP_TB_1', 'Single point with CP56Time2a'),
  mDpTb1(31, 'M_DP_TB_1', 'Double point with CP56Time2a'),
  mStTb1(32, 'M_ST_TB_1', 'Step position with CP56Time2a'),
  mBoTb1(33, 'M_BO_TB_1', 'Bitstring with CP56Time2a'),
  mMeTd1(34, 'M_ME_TD_1', 'Normalized with CP56Time2a'),
  mMeTe1(35, 'M_ME_TE_1', 'Scaled with CP56Time2a'),
  mMeTf1(36, 'M_ME_TF_1', 'Short float with CP56Time2a'),
  mItTb1(37, 'M_IT_TB_1', 'Integrated totals with CP56Time2a'),

  // --- Control Direction ---
  cScNa1(45, 'C_SC_NA_1', 'Single command'),
  cDcNa1(46, 'C_DC_NA_1', 'Double command'),
  cRcNa1(47, 'C_RC_NA_1', 'Regulating step command'),
  cSeNa1(48, 'C_SE_NA_1', 'Setpoint normalized'),
  cSeNb1(49, 'C_SE_NB_1', 'Setpoint scaled'),
  cSeNc1(50, 'C_SE_NC_1', 'Setpoint short float'),
  cBoNa1(51, 'C_BO_NA_1', 'Bitstring 32 command'),

  // --- Control Direction CP56Time2a ---
  cScTa1(58, 'C_SC_TA_1', 'Single command with CP56Time2a'),
  cDcTa1(59, 'C_DC_TA_1', 'Double command with CP56Time2a'),
  cRcTa1(60, 'C_RC_TA_1', 'Regulating step with CP56Time2a'),
  cSeTa1(61, 'C_SE_TA_1', 'Setpoint normalized with CP56Time2a'),
  cSeTb1(62, 'C_SE_TB_1', 'Setpoint scaled with CP56Time2a'),
  cSeTc1(63, 'C_SE_TC_1', 'Setpoint short float with CP56Time2a'),
  cBoTa1(64, 'C_BO_TA_1', 'Bitstring 32 with CP56Time2a'),

  // --- System Supervision Commands ---
  mEiNa1(70, 'M_EI_NA_1', 'End of initialization'),
  cIcNa1(100, 'C_IC_NA_1', 'Interrogation command'),
  cCiNa1(101, 'C_CI_NA_1', 'Counter interrogation command'),
  cRdNa1(102, 'C_RD_NA_1', 'Read command'),
  cCsNa1(103, 'C_CS_NA_1', 'Clock synchronization'),
  cRpNa1(105, 'C_RP_NA_1', 'Reset process command'),
  cTsTa1(107, 'C_TS_TA_1', 'Test command with CP56Time2a');

  final int id;
  final String nameString;
  final String englishDescription;

  const AsduTypeId(this.id, this.nameString, this.englishDescription);

  String get description {
    final key = 'asdu_${name}';
    final translated = AppI18n.instance.t(key);
    return translated != key ? translated : englishDescription;
  }

  String get label => description;

  static AsduTypeId? fromId(int id) {
    for (final v in AsduTypeId.values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

/// Cause of Transmission (COT - 传送原因)
enum CauseOfTransmission {
  periodic(1, 'Periodic/Cyclic'),
  backgroundScan(2, 'Background Scan'),
  spontaneous(3, 'Spontaneous'),
  initialized(4, 'Initialized'),
  request(5, 'Request/Requested'),
  activation(6, 'Activation'),
  activationConfirmation(7, 'Activation Con'),
  deactivation(8, 'Deactivation'),
  deactivationConfirmation(9, 'Deactivation Con'),
  activationTermination(10, 'Activation Term'),
  returnInfoRemote(11, 'Return Info Remote'),
  returnInfoLocal(12, 'Return Info Local'),
  fileTransfer(13, 'File Transfer'),
  interrogatedByStation(20, 'Interrogated by Station GI'),
  interrogatedByGroup1(21, 'Interrogated by Group 1'),
  interrogatedByGroup2(22, 'Interrogated by Group 2'),
  interrogatedByCounter(37, 'Interrogated by Counter GI'),
  unknownTypeId(44, 'Unknown Type ID'),
  unknownCot(45, 'Unknown COT'),
  unknownCommonAddress(46, 'Unknown CA'),
  unknownIoa(47, 'Unknown IOA');

  final int id;
  final String englishDescription;

  const CauseOfTransmission(this.id, this.englishDescription);

  String get description {
    final key = 'cot_${name}';
    final translated = AppI18n.instance.t(key);
    return translated != key ? translated : englishDescription;
  }

  String get label => description;

  static CauseOfTransmission fromId(int id) {
    for (final v in CauseOfTransmission.values) {
      if (v.id == id) return v;
    }
    return CauseOfTransmission.spontaneous;
  }
}

/// Represents an ASDU (Application Service Data Unit) in IEC 60870-5-104
class Asdu {
  final AsduTypeId typeId;
  final bool isSequence; // Variable Structure Qualifier bit 7 (SQ)
  final CauseOfTransmission cot;
  final bool isTest;            // COT bit 7
  final bool isNegativeConfirm; // COT bit 6 (P/N)
  final int originatorAddress;  // OA (1 byte, typically 0)
  final int commonAddress;      // COA (1 or 2 bytes, station address)
  final List<InformationObject> objects;

  Asdu({
    required this.typeId,
    this.isSequence = false,
    required this.cot,
    this.isTest = false,
    this.isNegativeConfirm = false,
    this.originatorAddress = 0,
    required this.commonAddress,
    required this.objects,
  });

  int get count => objects.length;

  @override
  String toString() {
    return 'ASDU(${typeId.nameString}[${typeId.id}], COT: ${cot.name}[${cot.id}], COA: $commonAddress, Objects: ${objects.length})';
  }
}
