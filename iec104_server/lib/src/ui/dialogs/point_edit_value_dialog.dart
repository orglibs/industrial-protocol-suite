import 'package:flutter/material.dart';
import '../../protocol/asdu.dart';
import '../../protocol/asdu_types.dart';
import '../../server/station.dart';

class PointEditValueDialog extends StatefulWidget {
  final StationPoint point;
  final void Function(dynamic newValue, QualityDescriptor quality) onSave;

  const PointEditValueDialog({
    super.key,
    required this.point,
    required this.onSave,
  });

  @override
  State<PointEditValueDialog> createState() => _PointEditValueDialogState();
}

class _PointEditValueDialogState extends State<PointEditValueDialog> {
  late TextEditingController _valController;
  late bool _boolVal;
  late int _dpVal;
  late bool _invalid;
  late bool _blocked;
  late bool _substituted;
  late bool _nonTopical;
  late bool _overflow;

  @override
  void initState() {
    super.initState();
    _valController = TextEditingController(text: widget.point.value.toString());
    _boolVal = widget.point.value == true || widget.point.value == 1;
    _dpVal = widget.point.value is int ? widget.point.value as int : 1;

    final q = widget.point.quality;
    _invalid = q.invalid;
    _blocked = q.blocked;
    _substituted = q.substituted;
    _nonTopical = q.nonTopical;
    _overflow = q.overflow;
  }

  @override
  void dispose() {
    _valController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSinglePoint = widget.point.typeId == AsduTypeId.mSpNa1 || widget.point.typeId == AsduTypeId.mSpTb1;
    final isDoublePoint = widget.point.typeId == AsduTypeId.mDpNa1 || widget.point.typeId == AsduTypeId.mDpTb1;

    return AlertDialog(
      title: Text('修改点位数据 [IOA: ${widget.point.ioa}]'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('点位名称: ${widget.point.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('ASDU类型: ${widget.point.typeId.nameString} (${widget.point.typeId.description})',
                style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            const Divider(height: 24),
            const Text('设置点位数值:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (isSinglePoint) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: true, label: Text('1 (合闸 / ON)')),
                  ButtonSegment<bool>(value: false, label: Text('0 (分闸 / OFF)')),
                ],
                selected: {_boolVal},
                onSelectionChanged: (newSet) {
                  setState(() => _boolVal = newSet.first);
                },
              ),
            ] else if (isDoublePoint) ...[
              DropdownButtonFormField<int>(
                initialValue: _dpVal,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '双点状态'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('01: 分闸 (OFF)')),
                  DropdownMenuItem(value: 2, child: Text('10: 合闸 (ON)')),
                  DropdownMenuItem(value: 0, child: Text('00: 不确定态 (Indeterminate)')),
                  DropdownMenuItem(value: 3, child: Text('11: 故障态 (Fault)')),
                ],
                onChanged: (v) => setState(() => _dpVal = v!),
              ),
            ] else ...[
              TextField(
                controller: _valController,
                decoration: InputDecoration(
                  labelText: '数值',
                  border: const OutlineInputBorder(),
                  helperText: widget.point.typeId == AsduTypeId.mMeNa1
                      ? '归一化数值范围: -1.0 到 1.0'
                      : widget.point.typeId == AsduTypeId.mMeNb1
                          ? '标度化数值范围: -32768 到 32767'
                          : '支持浮点数或整数',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
            ],
            const SizedBox(height: 16),
            const Text('品质位 (Quality Flags):', style: TextStyle(fontWeight: FontWeight.w600)),
            CheckboxListTile(
              dense: true,
              title: const Text('IV: 无效 (Invalid)'),
              value: _invalid,
              onChanged: (v) => setState(() => _invalid = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('BL: 闭锁 (Blocked)'),
              value: _blocked,
              onChanged: (v) => setState(() => _blocked = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('SB: 人工置入 (Substituted)'),
              value: _substituted,
              onChanged: (v) => setState(() => _substituted = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('NT: 非当前值 (Non-topical)'),
              value: _nonTopical,
              onChanged: (v) => setState(() => _nonTopical = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('OV: 溢出 (Overflow)'),
              value: _overflow,
              onChanged: (v) => setState(() => _overflow = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            dynamic newVal;
            if (isSinglePoint) {
              newVal = _boolVal;
            } else if (isDoublePoint) {
              newVal = _dpVal;
            } else {
              final text = _valController.text.trim();
              if (int.tryParse(text) != null &&
                  widget.point.typeId != AsduTypeId.mMeNc1 &&
                  widget.point.typeId != AsduTypeId.mMeNa1) {
                newVal = int.parse(text);
              } else {
                newVal = double.tryParse(text) ?? 0.0;
              }
            }

            final q = QualityDescriptor(
              invalid: _invalid,
              blocked: _blocked,
              substituted: _substituted,
              nonTopical: _nonTopical,
              overflow: _overflow,
            );

            widget.onSave(newVal, q);
            Navigator.pop(context);
          },
          child: const Text('保存并突发推送 (COT=3)'),
        ),
      ],
    );
  }
}
