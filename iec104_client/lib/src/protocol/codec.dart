import 'dart:typed_data';
import 'apci.dart';
import 'asdu.dart';
import 'asdu_types.dart';

class Iec104Codec {
  /// Encodes a full APDU frame (APCI + optional ASDU)
  static Uint8List encodeApdu({
    required ApciHeader apci,
    Asdu? asdu,
    int cotSize = 2,
    int caSize = 2,
    int ioaSize = 3,
  }) {
    Uint8List? asduBytes;
    if (asdu != null) {
      asduBytes = encodeAsdu(
        asdu,
        cotSize: cotSize,
        caSize: caSize,
        ioaSize: ioaSize,
      );
    }

    final asduLen = asduBytes?.length ?? 0;
    ApciHeader finalApci = apci;
    if (apci.type == ApciType.iFormat && apci.apduLength != 4 + asduLen) {
      finalApci = ApciHeader.iFormat(
        txSeq: apci.txSeq ?? 0,
        rxSeq: apci.rxSeq ?? 0,
        asduLength: asduLen,
      );
    }

    final apciBytes = finalApci.encode();
    if (asduBytes == null || asduBytes.isEmpty) {
      return apciBytes;
    }

    final fullApdu = Uint8List(apciBytes.length + asduBytes.length);
    fullApdu.setRange(0, apciBytes.length, apciBytes);
    fullApdu.setRange(apciBytes.length, fullApdu.length, asduBytes);
    return fullApdu;
  }

  /// Encodes an ASDU structure to bytes
  static Uint8List encodeAsdu(
    Asdu asdu, {
    int cotSize = 2,
    int caSize = 2,
    int ioaSize = 3,
  }) {
    final buffer = BytesBuilder();

    // 1. Type ID (1 byte)
    buffer.addByte(asdu.typeId.id);

    // 2. VSQ (1 byte): SQ (bit 7) | count (bits 0-6)
    final vsq = (asdu.isSequence ? 0x80 : 0x00) | (asdu.objects.length & 0x7F);
    buffer.addByte(vsq);

    // 3. COT (1 or 2 bytes)
    int cotByte1 = asdu.cot.id & 0x3F;
    if (asdu.isNegativeConfirm) cotByte1 |= 0x40;
    if (asdu.isTest) cotByte1 |= 0x80;
    buffer.addByte(cotByte1);

    if (cotSize == 2) {
      buffer.addByte(asdu.originatorAddress & 0xFF);
    }

    // 4. Common Address of ASDU (COA - 1 or 2 bytes)
    buffer.addByte(asdu.commonAddress & 0xFF);
    if (caSize == 2) {
      buffer.addByte((asdu.commonAddress >> 8) & 0xFF);
    }

    // 5. Information Objects
    for (int i = 0; i < asdu.objects.length; i++) {
      final obj = asdu.objects[i];

      // In non-sequence (SQ=0), every object has its IOA.
      // In sequence (SQ=1), only the first object has its IOA.
      if (!asdu.isSequence || i == 0) {
        _writeIoa(buffer, obj.ioa, ioaSize);
      }

      _encodeObjectElement(buffer, asdu.typeId, obj);
    }

    return buffer.toBytes();
  }

  static void _writeIoa(BytesBuilder buffer, int ioa, int ioaSize) {
    buffer.addByte(ioa & 0xFF);
    if (ioaSize >= 2) buffer.addByte((ioa >> 8) & 0xFF);
    if (ioaSize >= 3) buffer.addByte((ioa >> 16) & 0xFF);
  }

  static int _readIoa(Uint8List data, int offset, int ioaSize) {
    int ioa = data[offset];
    if (ioaSize >= 2) ioa |= (data[offset + 1] << 8);
    if (ioaSize >= 3) ioa |= (data[offset + 2] << 16);
    return ioa;
  }

  static void _encodeObjectElement(BytesBuilder buffer, AsduTypeId type, InformationObject obj) {
    switch (type) {
      case AsduTypeId.mSpNa1:
        final o = obj as SinglePointObject;
        buffer.addByte((o.value ? 0x01 : 0x00) | o.quality.toByte());
        break;

      case AsduTypeId.mSpTb1:
        final o = obj as SinglePointObject;
        buffer.addByte((o.value ? 0x01 : 0x00) | o.quality.toByte());
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.mDpNa1:
        final o = obj as DoublePointObject;
        buffer.addByte((o.value & 0x03) | o.quality.toByte());
        break;

      case AsduTypeId.mDpTb1:
        final o = obj as DoublePointObject;
        buffer.addByte((o.value & 0x03) | o.quality.toByte());
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.mStNa1:
        final o = obj as StepPositionObject;
        final vti = (o.value & 0x7F) | (o.isTransient ? 0x80 : 0x00);
        buffer.addByte(vti);
        buffer.addByte(o.quality.toByte());
        break;

      case AsduTypeId.mStTb1:
        final o = obj as StepPositionObject;
        final vti = (o.value & 0x7F) | (o.isTransient ? 0x80 : 0x00);
        buffer.addByte(vti);
        buffer.addByte(o.quality.toByte());
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.mBoNa1:
        final o = obj as Bitstring32Object;
        final bData = ByteData(4)..setUint32(0, o.value, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte(o.quality.toByte());
        break;

      case AsduTypeId.mBoTb1:
        final o = obj as Bitstring32Object;
        final bData = ByteData(4)..setUint32(0, o.value, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte(o.quality.toByte());
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.mMeNa1:
        final o = obj as MeasuredNormalizedObject;
        final raw = (o.value * 32767.0).round().clamp(-32768, 32767);
        final bData = ByteData(2)..setInt16(0, raw, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte(o.quality.toByte());
        break;

      case AsduTypeId.mMeTd1:
        final o = obj as MeasuredNormalizedObject;
        final raw = (o.value * 32767.0).round().clamp(-32768, 32767);
        final bData = ByteData(2)..setInt16(0, raw, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte(o.quality.toByte());
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.mMeNb1:
        final o = obj as MeasuredScaledObject;
        final bData = ByteData(2)..setInt16(0, o.value, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte(o.quality.toByte());
        break;

      case AsduTypeId.mMeTe1:
        final o = obj as MeasuredScaledObject;
        final bData = ByteData(2)..setInt16(0, o.value, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte(o.quality.toByte());
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.mMeNc1:
        final o = obj as MeasuredShortFloatObject;
        final bData = ByteData(4)..setFloat32(0, o.value, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte(o.quality.toByte());
        break;

      case AsduTypeId.mMeTf1:
        final o = obj as MeasuredShortFloatObject;
        final bData = ByteData(4)..setFloat32(0, o.value, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte(o.quality.toByte());
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.mItNa1:
        final o = obj as IntegratedTotalsObject;
        final bData = ByteData(4)..setInt32(0, o.counter, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        int flags = (o.sequenceNumber & 0x1F);
        if (o.hasCarry) flags |= 0x20;
        if (o.isAdjusted) flags |= 0x40;
        if (o.isInvalid) flags |= 0x80;
        buffer.addByte(flags);
        break;

      case AsduTypeId.mItTb1:
        final o = obj as IntegratedTotalsObject;
        final bData = ByteData(4)..setInt32(0, o.counter, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        int flags = (o.sequenceNumber & 0x1F);
        if (o.hasCarry) flags |= 0x20;
        if (o.isAdjusted) flags |= 0x40;
        if (o.isInvalid) flags |= 0x80;
        buffer.addByte(flags);
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.cScNa1:
        final o = obj as SingleCommandObject;
        int sco = (o.state ? 0x01 : 0x00) | ((o.qualifier & 0x1F) << 2);
        if (o.isSelect) sco |= 0x80;
        buffer.addByte(sco);
        break;

      case AsduTypeId.cScTa1:
        final o = obj as SingleCommandObject;
        int sco = (o.state ? 0x01 : 0x00) | ((o.qualifier & 0x1F) << 2);
        if (o.isSelect) sco |= 0x80;
        buffer.addByte(sco);
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.cDcNa1:
        final o = obj as DoubleCommandObject;
        int dco = (o.state & 0x03) | ((o.qualifier & 0x1F) << 2);
        if (o.isSelect) dco |= 0x80;
        buffer.addByte(dco);
        break;

      case AsduTypeId.cDcTa1:
        final o = obj as DoubleCommandObject;
        int dco = (o.state & 0x03) | ((o.qualifier & 0x1F) << 2);
        if (o.isSelect) dco |= 0x80;
        buffer.addByte(dco);
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.cRcNa1:
        final o = obj as RegulatingStepCommandObject;
        int rco = (o.step & 0x03) | ((o.qualifier & 0x1F) << 2);
        if (o.isSelect) rco |= 0x80;
        buffer.addByte(rco);
        break;

      case AsduTypeId.cRcTa1:
        final o = obj as RegulatingStepCommandObject;
        int rco = (o.step & 0x03) | ((o.qualifier & 0x1F) << 2);
        if (o.isSelect) rco |= 0x80;
        buffer.addByte(rco);
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.cSeNa1:
        final o = obj as SetpointNormalizedObject;
        final raw = (o.value * 32767.0).round().clamp(-32768, 32767);
        final bData = ByteData(2)..setInt16(0, raw, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte((o.qos & 0x7F) | (o.isSelect ? 0x80 : 0x00));
        break;

      case AsduTypeId.cSeTa1:
        final o = obj as SetpointNormalizedObject;
        final raw = (o.value * 32767.0).round().clamp(-32768, 32767);
        final bData = ByteData(2)..setInt16(0, raw, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte((o.qos & 0x7F) | (o.isSelect ? 0x80 : 0x00));
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.cSeNb1:
        final o = obj as SetpointScaledObject;
        final bData = ByteData(2)..setInt16(0, o.value, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte((o.qos & 0x7F) | (o.isSelect ? 0x80 : 0x00));
        break;

      case AsduTypeId.cSeTb1:
        final o = obj as SetpointScaledObject;
        final bData = ByteData(2)..setInt16(0, o.value, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte((o.qos & 0x7F) | (o.isSelect ? 0x80 : 0x00));
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.cSeNc1:
        final o = obj as SetpointShortFloatObject;
        final bData = ByteData(4)..setFloat32(0, o.value, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte((o.qos & 0x7F) | (o.isSelect ? 0x80 : 0x00));
        break;

      case AsduTypeId.cSeTc1:
        final o = obj as SetpointShortFloatObject;
        final bData = ByteData(4)..setFloat32(0, o.value, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.addByte((o.qos & 0x7F) | (o.isSelect ? 0x80 : 0x00));
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.cBoNa1:
        final o = obj as Bitstring32CommandObject;
        final bData = ByteData(4)..setUint32(0, o.value, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        break;

      case AsduTypeId.cBoTa1:
        final o = obj as Bitstring32CommandObject;
        final bData = ByteData(4)..setUint32(0, o.value, Endian.little);
        buffer.add(bData.buffer.asUint8List());
        buffer.add((o.timestamp ?? CP56Time2a.now()).encode());
        break;

      case AsduTypeId.cIcNa1:
        final o = obj as InterrogationCommandObject;
        buffer.addByte(o.qoi);
        break;

      case AsduTypeId.cCiNa1:
        final o = obj as CounterInterrogationCommandObject;
        buffer.addByte(o.qcc);
        break;

      case AsduTypeId.cRdNa1:
        // No additional body bytes for Read Command
        break;

      case AsduTypeId.cCsNa1:
        final o = obj as ClockSyncCommandObject;
        buffer.add(o.time.encode());
        break;

      case AsduTypeId.cRpNa1:
        final o = obj as ResetProcessCommandObject;
        buffer.addByte(o.qrp);
        break;

      case AsduTypeId.mEiNa1:
        final o = obj as EndOfInitObject;
        buffer.addByte(o.coi);
        break;

      default:
        break;
    }
  }

  /// Decodes an ASDU from bytes
  static Asdu decodeAsdu(
    Uint8List data,
    int offset,
    int length, {
    int cotSize = 2,
    int caSize = 2,
    int ioaSize = 3,
  }) {
    if (length < 2 + cotSize + caSize) {
      throw FormatException('ASDU length $length is too small for header');
    }

    int cur = offset;
    final typeByte = data[cur++];
    final typeId = AsduTypeId.fromId(typeByte);
    if (typeId == null) {
      throw FormatException('Unknown ASDU Type ID: $typeByte (0x${typeByte.toRadixString(16)})');
    }

    final vsq = data[cur++];
    final isSequence = (vsq & 0x80) != 0;
    final numObjects = vsq & 0x7F;

    final cotByte1 = data[cur++];
    final cotId = cotByte1 & 0x3F;
    final isNegative = (cotByte1 & 0x40) != 0;
    final isTest = (cotByte1 & 0x80) != 0;
    final cot = CauseOfTransmission.fromId(cotId);

    int oa = 0;
    if (cotSize == 2) {
      oa = data[cur++];
    }

    int commonAddress = data[cur++];
    if (caSize == 2) {
      commonAddress |= (data[cur++] << 8);
    }

    final objects = <InformationObject>[];
    int currentIoa = 0;

    for (int i = 0; i < numObjects; i++) {
      if (!isSequence || i == 0) {
        if (cur + ioaSize > offset + length) break;
        currentIoa = _readIoa(data, cur, ioaSize);
        cur += ioaSize;
      } else {
        currentIoa++;
      }

      final (obj, bytesRead) = _decodeObjectElement(data, cur, typeId, currentIoa);
      if (obj != null) {
        objects.add(obj);
      }
      cur += bytesRead;
      if (cur > offset + length) break;
    }

    return Asdu(
      typeId: typeId,
      isSequence: isSequence,
      cot: cot,
      isTest: isTest,
      isNegativeConfirm: isNegative,
      originatorAddress: oa,
      commonAddress: commonAddress,
      objects: objects,
    );
  }

  static (InformationObject?, int) _decodeObjectElement(Uint8List data, int cur, AsduTypeId type, int ioa) {
    switch (type) {
      case AsduTypeId.mSpNa1:
        final b = data[cur];
        return (
          SinglePointObject(
            ioa: ioa,
            value: (b & 0x01) != 0,
            quality: QualityDescriptor.fromByte(b),
          ),
          1,
        );

      case AsduTypeId.mSpTb1:
        final b = data[cur];
        final time = CP56Time2a.decode(data, cur + 1);
        return (
          SinglePointObject(
            ioa: ioa,
            value: (b & 0x01) != 0,
            quality: QualityDescriptor.fromByte(b),
            timestamp: time,
          ),
          8,
        );

      case AsduTypeId.mDpNa1:
        final b = data[cur];
        return (
          DoublePointObject(
            ioa: ioa,
            value: b & 0x03,
            quality: QualityDescriptor.fromByte(b),
          ),
          1,
        );

      case AsduTypeId.mDpTb1:
        final b = data[cur];
        final time = CP56Time2a.decode(data, cur + 1);
        return (
          DoublePointObject(
            ioa: ioa,
            value: b & 0x03,
            quality: QualityDescriptor.fromByte(b),
            timestamp: time,
          ),
          8,
        );

      case AsduTypeId.mStNa1:
        final vti = data[cur];
        final qds = data[cur + 1];
        int val = vti & 0x7F;
        if ((val & 0x40) != 0) val = val - 128; // sign extension for 7-bit signed
        return (
          StepPositionObject(
            ioa: ioa,
            value: val,
            isTransient: (vti & 0x80) != 0,
            quality: QualityDescriptor.fromByte(qds),
          ),
          2,
        );

      case AsduTypeId.mStTb1:
        final vti = data[cur];
        final qds = data[cur + 1];
        int val = vti & 0x7F;
        if ((val & 0x40) != 0) val = val - 128;
        final time = CP56Time2a.decode(data, cur + 2);
        return (
          StepPositionObject(
            ioa: ioa,
            value: val,
            isTransient: (vti & 0x80) != 0,
            quality: QualityDescriptor.fromByte(qds),
            timestamp: time,
          ),
          9,
        );

      case AsduTypeId.mBoNa1:
        final view = ByteData.sublistView(data, cur, cur + 4);
        final val = view.getUint32(0, Endian.little);
        final qds = data[cur + 4];
        return (
          Bitstring32Object(
            ioa: ioa,
            value: val,
            quality: QualityDescriptor.fromByte(qds),
          ),
          5,
        );

      case AsduTypeId.mBoTb1:
        final view = ByteData.sublistView(data, cur, cur + 4);
        final val = view.getUint32(0, Endian.little);
        final qds = data[cur + 4];
        final time = CP56Time2a.decode(data, cur + 5);
        return (
          Bitstring32Object(
            ioa: ioa,
            value: val,
            quality: QualityDescriptor.fromByte(qds),
            timestamp: time,
          ),
          12,
        );

      case AsduTypeId.mMeNa1:
        final view = ByteData.sublistView(data, cur, cur + 2);
        final raw = view.getInt16(0, Endian.little);
        final qds = data[cur + 2];
        return (
          MeasuredNormalizedObject(
            ioa: ioa,
            value: raw / 32767.0,
            quality: QualityDescriptor.fromByte(qds),
          ),
          3,
        );

      case AsduTypeId.mMeTd1:
        final view = ByteData.sublistView(data, cur, cur + 2);
        final raw = view.getInt16(0, Endian.little);
        final qds = data[cur + 2];
        final time = CP56Time2a.decode(data, cur + 3);
        return (
          MeasuredNormalizedObject(
            ioa: ioa,
            value: raw / 32767.0,
            quality: QualityDescriptor.fromByte(qds),
            timestamp: time,
          ),
          10,
        );

      case AsduTypeId.mMeNb1:
        final view = ByteData.sublistView(data, cur, cur + 2);
        final raw = view.getInt16(0, Endian.little);
        final qds = data[cur + 2];
        return (
          MeasuredScaledObject(
            ioa: ioa,
            value: raw,
            quality: QualityDescriptor.fromByte(qds),
          ),
          3,
        );

      case AsduTypeId.mMeTe1:
        final view = ByteData.sublistView(data, cur, cur + 2);
        final raw = view.getInt16(0, Endian.little);
        final qds = data[cur + 2];
        final time = CP56Time2a.decode(data, cur + 3);
        return (
          MeasuredScaledObject(
            ioa: ioa,
            value: raw,
            quality: QualityDescriptor.fromByte(qds),
            timestamp: time,
          ),
          10,
        );

      case AsduTypeId.mMeNc1:
        final view = ByteData.sublistView(data, cur, cur + 4);
        final val = view.getFloat32(0, Endian.little);
        final qds = data[cur + 4];
        return (
          MeasuredShortFloatObject(
            ioa: ioa,
            value: val,
            quality: QualityDescriptor.fromByte(qds),
          ),
          5,
        );

      case AsduTypeId.mMeTf1:
        final view = ByteData.sublistView(data, cur, cur + 4);
        final val = view.getFloat32(0, Endian.little);
        final qds = data[cur + 4];
        final time = CP56Time2a.decode(data, cur + 5);
        return (
          MeasuredShortFloatObject(
            ioa: ioa,
            value: val,
            quality: QualityDescriptor.fromByte(qds),
            timestamp: time,
          ),
          12,
        );

      case AsduTypeId.mItNa1:
        final view = ByteData.sublistView(data, cur, cur + 4);
        final cnt = view.getInt32(0, Endian.little);
        final flagByte = data[cur + 4];
        return (
          IntegratedTotalsObject(
            ioa: ioa,
            counter: cnt,
            sequenceNumber: flagByte & 0x1F,
            hasCarry: (flagByte & 0x20) != 0,
            isAdjusted: (flagByte & 0x40) != 0,
            isInvalid: (flagByte & 0x80) != 0,
          ),
          5,
        );

      case AsduTypeId.mItTb1:
        final view = ByteData.sublistView(data, cur, cur + 4);
        final cnt = view.getInt32(0, Endian.little);
        final flagByte = data[cur + 4];
        final time = CP56Time2a.decode(data, cur + 5);
        return (
          IntegratedTotalsObject(
            ioa: ioa,
            counter: cnt,
            sequenceNumber: flagByte & 0x1F,
            hasCarry: (flagByte & 0x20) != 0,
            isAdjusted: (flagByte & 0x40) != 0,
            isInvalid: (flagByte & 0x80) != 0,
            timestamp: time,
          ),
          12,
        );

      case AsduTypeId.cScNa1:
        final sco = data[cur];
        return (
          SingleCommandObject(
            ioa: ioa,
            state: (sco & 0x01) != 0,
            qualifier: (sco >> 2) & 0x1F,
            isSelect: (sco & 0x80) != 0,
          ),
          1,
        );

      case AsduTypeId.cScTa1:
        final sco = data[cur];
        final time = CP56Time2a.decode(data, cur + 1);
        return (
          SingleCommandObject(
            ioa: ioa,
            state: (sco & 0x01) != 0,
            qualifier: (sco >> 2) & 0x1F,
            isSelect: (sco & 0x80) != 0,
            timestamp: time,
          ),
          8,
        );

      case AsduTypeId.cDcNa1:
        final dco = data[cur];
        return (
          DoubleCommandObject(
            ioa: ioa,
            state: dco & 0x03,
            qualifier: (dco >> 2) & 0x1F,
            isSelect: (dco & 0x80) != 0,
          ),
          1,
        );

      case AsduTypeId.cDcTa1:
        final dco = data[cur];
        final time = CP56Time2a.decode(data, cur + 1);
        return (
          DoubleCommandObject(
            ioa: ioa,
            state: dco & 0x03,
            qualifier: (dco >> 2) & 0x1F,
            isSelect: (dco & 0x80) != 0,
            timestamp: time,
          ),
          8,
        );

      case AsduTypeId.cRcNa1:
        final rco = data[cur];
        return (
          RegulatingStepCommandObject(
            ioa: ioa,
            step: rco & 0x03,
            qualifier: (rco >> 2) & 0x1F,
            isSelect: (rco & 0x80) != 0,
          ),
          1,
        );

      case AsduTypeId.cRcTa1:
        final rco = data[cur];
        final time = CP56Time2a.decode(data, cur + 1);
        return (
          RegulatingStepCommandObject(
            ioa: ioa,
            step: rco & 0x03,
            qualifier: (rco >> 2) & 0x1F,
            isSelect: (rco & 0x80) != 0,
            timestamp: time,
          ),
          8,
        );

      case AsduTypeId.cSeNa1:
        final view = ByteData.sublistView(data, cur, cur + 2);
        final raw = view.getInt16(0, Endian.little);
        final qos = data[cur + 2];
        return (
          SetpointNormalizedObject(
            ioa: ioa,
            value: raw / 32767.0,
            qos: qos & 0x7F,
            isSelect: (qos & 0x80) != 0,
          ),
          3,
        );

      case AsduTypeId.cSeTa1:
        final view = ByteData.sublistView(data, cur, cur + 2);
        final raw = view.getInt16(0, Endian.little);
        final qos = data[cur + 2];
        final time = CP56Time2a.decode(data, cur + 3);
        return (
          SetpointNormalizedObject(
            ioa: ioa,
            value: raw / 32767.0,
            qos: qos & 0x7F,
            isSelect: (qos & 0x80) != 0,
            timestamp: time,
          ),
          10,
        );

      case AsduTypeId.cSeNb1:
        final view = ByteData.sublistView(data, cur, cur + 2);
        final raw = view.getInt16(0, Endian.little);
        final qos = data[cur + 2];
        return (
          SetpointScaledObject(
            ioa: ioa,
            value: raw,
            qos: qos & 0x7F,
            isSelect: (qos & 0x80) != 0,
          ),
          3,
        );

      case AsduTypeId.cSeTb1:
        final view = ByteData.sublistView(data, cur, cur + 2);
        final raw = view.getInt16(0, Endian.little);
        final qos = data[cur + 2];
        final time = CP56Time2a.decode(data, cur + 3);
        return (
          SetpointScaledObject(
            ioa: ioa,
            value: raw,
            qos: qos & 0x7F,
            isSelect: (qos & 0x80) != 0,
            timestamp: time,
          ),
          10,
        );

      case AsduTypeId.cSeNc1:
        final view = ByteData.sublistView(data, cur, cur + 4);
        final val = view.getFloat32(0, Endian.little);
        final qos = data[cur + 4];
        return (
          SetpointShortFloatObject(
            ioa: ioa,
            value: val,
            qos: qos & 0x7F,
            isSelect: (qos & 0x80) != 0,
          ),
          5,
        );

      case AsduTypeId.cSeTc1:
        final view = ByteData.sublistView(data, cur, cur + 4);
        final val = view.getFloat32(0, Endian.little);
        final qos = data[cur + 4];
        final time = CP56Time2a.decode(data, cur + 5);
        return (
          SetpointShortFloatObject(
            ioa: ioa,
            value: val,
            qos: qos & 0x7F,
            isSelect: (qos & 0x80) != 0,
            timestamp: time,
          ),
          12,
        );

      case AsduTypeId.cBoNa1:
        final view = ByteData.sublistView(data, cur, cur + 4);
        final val = view.getUint32(0, Endian.little);
        return (
          Bitstring32CommandObject(ioa: ioa, value: val),
          4,
        );

      case AsduTypeId.cBoTa1:
        final view = ByteData.sublistView(data, cur, cur + 4);
        final val = view.getUint32(0, Endian.little);
        final time = CP56Time2a.decode(data, cur + 4);
        return (
          Bitstring32CommandObject(ioa: ioa, value: val, timestamp: time),
          11,
        );

      case AsduTypeId.cIcNa1:
        final qoi = data[cur];
        return (InterrogationCommandObject(ioa: ioa, qoi: qoi), 1);

      case AsduTypeId.cCiNa1:
        final qcc = data[cur];
        return (CounterInterrogationCommandObject(ioa: ioa, qcc: qcc), 1);

      case AsduTypeId.cRdNa1:
        return (ReadCommandObject(ioa: ioa), 0);

      case AsduTypeId.cCsNa1:
        final time = CP56Time2a.decode(data, cur);
        return (ClockSyncCommandObject(ioa: ioa, time: time), 7);

      case AsduTypeId.cRpNa1:
        final qrp = data[cur];
        return (ResetProcessCommandObject(ioa: ioa, qrp: qrp), 1);

      case AsduTypeId.mEiNa1:
        final coi = data[cur];
        return (EndOfInitObject(ioa: ioa, coi: coi), 1);

      default:
        return (null, 0);
    }
  }
}
