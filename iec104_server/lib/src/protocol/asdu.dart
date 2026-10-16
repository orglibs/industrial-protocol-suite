import 'asdu_types.dart';

/// Common ASDU Type IDs used in IEC 60870-5-104
enum AsduTypeId {
  // --- 监视方向 (Monitor Direction) ---
  mSpNa1(1, 'M_SP_NA_1', '单点遥信 (Single point)'),
  mSpTa1(2, 'M_SP_TA_1', '带时标单点遥信 (Single point with CP24Time2a)'),
  mDpNa1(3, 'M_DP_NA_1', '双点遥信 (Double point)'),
  mDpTa1(4, 'M_DP_TA_1', '带时标双点遥信 (Double point with CP24Time2a)'),
  mStNa1(5, 'M_ST_NA_1', '步位置信息/分接头 (Step position)'),
  mStTa1(6, 'M_ST_TA_1', '带时标步位置 (Step position with CP24Time2a)'),
  mBoNa1(7, 'M_BO_NA_1', '32位二进制串 (Bitstring of 32 bits)'),
  mBoTa1(8, 'M_BO_TA_1', '带时标32位二进制串 (Bitstring with CP24Time2a)'),
  mMeNa1(9, 'M_ME_NA_1', '归一化遥测 (Measured value, normalized)'),
  mMeTa1(10, 'M_ME_TA_1', '带时标归一化遥测 (Measured normalized with CP24Time2a)'),
  mMeNb1(11, 'M_ME_NB_1', '标度化遥测 (Measured value, scaled)'),
  mMeTb1(12, 'M_ME_TB_1', '带时标标度化遥测 (Measured scaled with CP24Time2a)'),
  mMeNc1(13, 'M_ME_NC_1', '短浮点数遥测 (Measured value, short float)'),
  mMeTc1(14, 'M_ME_TC_1', '带时标短浮点遥测 (Measured short float with CP24Time2a)'),
  mItNa1(15, 'M_IT_NA_1', '累计量/电能量/遥脉 (Integrated totals)'),
  mItTa1(16, 'M_IT_TA_1', '带时标累计量 (Integrated totals with CP24Time2a)'),
  mMeNd1(21, 'M_ME_ND_1', '不带品质位归一化遥测 (Normalized without quality)'),

  // --- 监视方向 CP56Time2a 时标 (Monitor Direction with CP56Time2a) ---
  mSpTb1(30, 'M_SP_TB_1', '带CP56时标单点遥信 (Single point with CP56Time2a)'),
  mDpTb1(31, 'M_DP_TB_1', '带CP56时标双点遥信 (Double point with CP56Time2a)'),
  mStTb1(32, 'M_ST_TB_1', '带CP56时标步位置 (Step position with CP56Time2a)'),
  mBoTb1(33, 'M_BO_TB_1', '带CP56时标32位串 (Bitstring with CP56Time2a)'),
  mMeTd1(34, 'M_ME_TD_1', '带CP56时标归一化遥测 (Normalized with CP56Time2a)'),
  mMeTe1(35, 'M_ME_TE_1', '带CP56时标标度化遥测 (Scaled with CP56Time2a)'),
  mMeTf1(36, 'M_ME_TF_1', '带CP56时标短浮点遥测 (Short float with CP56Time2a)'),
  mItTb1(37, 'M_IT_TB_1', '带CP56时标累计量 (Integrated totals with CP56Time2a)'),

  // --- 控制方向 (Control Direction) ---
  cScNa1(45, 'C_SC_NA_1', '单命令遥控 (Single command)'),
  cDcNa1(46, 'C_DC_NA_1', '双命令遥控 (Double command)'),
  cRcNa1(47, 'C_RC_NA_1', '步调节命令 (Regulating step command)'),
  cSeNa1(48, 'C_SE_NA_1', '设定值命令, 归一化 (Setpoint normalized)'),
  cSeNb1(49, 'C_SE_NB_1', '设定值命令, 标度化 (Setpoint scaled)'),
  cSeNc1(50, 'C_SE_NC_1', '设定值命令, 短浮点 (Setpoint short float)'),
  cBoNa1(51, 'C_BO_NA_1', '32位二进制命令 (Bitstring 32 command)'),

  // --- 控制方向 CP56Time2a 时标 (Control Direction with CP56Time2a) ---
  cScTa1(58, 'C_SC_TA_1', '带时标单命令 (Single command with CP56Time2a)'),
  cDcTa1(59, 'C_DC_TA_1', '带时标双命令 (Double command with CP56Time2a)'),
  cRcTa1(60, 'C_RC_TA_1', '带时标步调节 (Regulating step with CP56Time2a)'),
  cSeTa1(61, 'C_SE_TA_1', '带时标归一化设定值 (Setpoint normalized with CP56Time2a)'),
  cSeTb1(62, 'C_SE_TB_1', '带时标标度化设定值 (Setpoint scaled with CP56Time2a)'),
  cSeTc1(63, 'C_SE_TC_1', '带时标短浮点设定值 (Setpoint short float with CP56Time2a)'),
  cBoTa1(64, 'C_BO_TA_1', '带时标32位命令 (Bitstring 32 with CP56Time2a)'),

  // --- 系统信息与命令 (System Supervision Commands) ---
  mEiNa1(70, 'M_EI_NA_1', '初始化结束 (End of initialization)'),
  cIcNa1(100, 'C_IC_NA_1', '总召唤命令 (Interrogation command)'),
  cCiNa1(101, 'C_CI_NA_1', '电能量总召唤 (Counter interrogation command)'),
  cRdNa1(102, 'C_RD_NA_1', '读命令 (Read command)'),
  cCsNa1(103, 'C_CS_NA_1', '时钟同步命令 (Clock synchronization)'),
  cRpNa1(105, 'C_RP_NA_1', '复位进程命令 (Reset process command)'),
  cTsTa1(107, 'C_TS_TA_1', '带时标测试命令 (Test command with CP56Time2a)');

  final int id;
  final String nameString;
  final String description;

  const AsduTypeId(this.id, this.nameString, this.description);

  static AsduTypeId? fromId(int id) {
    for (final v in AsduTypeId.values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

/// Cause of Transmission (COT - 传送原因)
enum CauseOfTransmission {
  periodic(1, '周期/循环 (Periodic/Cyclic)'),
  backgroundScan(2, '背景扫描 (Background Scan)'),
  spontaneous(3, '突发/自发 (Spontaneous)'),
  initialized(4, '初始化 (Initialized)'),
  request(5, '请求/被请求 (Request/Requested)'),
  activation(6, '激活 (Activation)'),
  activationConfirmation(7, '激活确认 (Activation Con)'),
  deactivation(8, '停止 (Deactivation)'),
  deactivationConfirmation(9, '停止确认 (Deactivation Con)'),
  activationTermination(10, '激活终止 (Activation Term)'),
  returnInfoRemote(11, '远方引起的返送信息 (Return Info Remote)'),
  returnInfoLocal(12, '当地引起的返送信息 (Return Info Local)'),
  fileTransfer(13, '文件传输 (File Transfer)'),
  interrogatedByStation(20, '响应站总召唤 (Interrogated by Station GI)'),
  interrogatedByGroup1(21, '响应第1组召唤 (Interrogated by Group 1)'),
  interrogatedByGroup2(22, '响应第2组召唤 (Interrogated by Group 2)'),
  interrogatedByCounter(37, '响应电能量总召唤 (Interrogated by Counter GI)'),
  unknownTypeId(44, '未知的类型标识 (Unknown Type ID)'),
  unknownCot(45, '未知的传送原因 (Unknown COT)'),
  unknownCommonAddress(46, '未知的公共地址 (Unknown CA)'),
  unknownIoa(47, '未知的信息对象地址 (Unknown IOA)');

  final int id;
  final String description;

  const CauseOfTransmission(this.id, this.description);

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
