import "../../i18n/app_i18n.dart";
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
      title: Text('${AppI18n.instance.t("editPoint")} [IOA: ${widget.point.ioa}]'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppI18n.instance.t("pointName")}: ${widget.point.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('ASDU: ${widget.point.typeId.nameString}',
                style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            const Divider(height: 24),
            Text('${AppI18n.instance.t("currValue")}:', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (isSinglePoint) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: true, label: const Text('1 (ON)')),
                  ButtonSegment<bool>(value: false, label: const Text('0 (OFF)')),
                ],
                selected: {_boolVal},
                onSelectionChanged: (newSet) {
                  setState(() => _boolVal = newSet.first);
                },
              ),
            ] else if (isDoublePoint) ...[
              DropdownButtonFormField<int>(
                initialValue: _dpVal,
                decoration: InputDecoration(border: OutlineInputBorder(), labelText: 'DP State'),
                items: const [
                  DropdownMenuItem(value: 1, child: const Text('01: OFF')),
                  DropdownMenuItem(value: 2, child: const Text('10: ON')),
                  DropdownMenuItem(value: 0, child: const Text('00: Indeterminate')),
                  DropdownMenuItem(value: 3, child: const Text('11: Fault')),
                ],
                onChanged: (v) => setState(() => _dpVal = v!),
              ),
            ] else ...[
              TextField(
                controller: _valController,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('currValue'),
                  border: const OutlineInputBorder(),
                  helperText: widget.point.typeId == AsduTypeId.mMeNa1
                      ? '-1.0 ~ 1.0'
                      : widget.point.typeId == AsduTypeId.mMeNb1
                          ? '-32768 ~ 32767'
                          : 'Number',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
            ],
            const SizedBox(height: 16),
            Text('${AppI18n.instance.t("qualityFlags")}:', style: const TextStyle(fontWeight: FontWeight.w600)),
            CheckboxListTile(
              dense: true,
              title: const Text('IV: Invalid'),
              value: _invalid,
              onChanged: (v) => setState(() => _invalid = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('BL: Blocked'),
              value: _blocked,
              onChanged: (v) => setState(() => _blocked = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('SB: Substituted'),
              value: _substituted,
              onChanged: (v) => setState(() => _substituted = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('NT: Non-topical'),
              value: _nonTopical,
              onChanged: (v) => setState(() => _nonTopical = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('OV: Overflow'),
              value: _overflow,
              onChanged: (v) => setState(() => _overflow = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppI18n.instance.t('cancel')),
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
          child: Text(AppI18n.instance.t('spontaneousPush')),
        ),
      ],
    );
  }
}
