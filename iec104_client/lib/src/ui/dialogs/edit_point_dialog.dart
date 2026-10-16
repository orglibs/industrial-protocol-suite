import 'package:flutter/material.dart';
import '../../client/station_data.dart';
import '../../protocol/asdu.dart';

class EditPointDialog extends StatefulWidget {
  final ClientStationModel station;
  final ClientPointModel point;
  final VoidCallback? onUpdated;
  final VoidCallback? onDeleted;

  const EditPointDialog({
    super.key,
    required this.station,
    required this.point,
    this.onUpdated,
    this.onDeleted,
  });

  @override
  State<EditPointDialog> createState() => _EditPointDialogState();
}

class _EditPointDialogState extends State<EditPointDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _valCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.point.name);
    _valCtrl = TextEditingController(text: widget.point.value.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valCtrl.dispose();
    super.dispose();
  }

  dynamic _parseValue() {
    final text = _valCtrl.text.trim();
    final typeId = widget.point.typeId;
    if (typeId == AsduTypeId.mSpNa1 || typeId == AsduTypeId.mSpTb1) {
      return text == '1' || text.toLowerCase() == 'true';
    } else if (typeId == AsduTypeId.mDpNa1 || typeId == AsduTypeId.mDpTb1) {
      return int.tryParse(text) ?? widget.point.value;
    } else if (typeId == AsduTypeId.mMeNc1 || typeId == AsduTypeId.mMeTf1) {
      return double.tryParse(text) ?? widget.point.value;
    } else {
      return int.tryParse(text) ?? widget.point.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.point;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit, color: Colors.blue),
          const SizedBox(width: 8),
          Text('编辑点号 (IOA: ${p.ioa})'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('所属从站: CA = ${widget.station.commonAddress} (${widget.station.name})'),
                const SizedBox(height: 4),
                Text('点号地址: IOA = ${p.ioa} (0x${p.ioa.toRadixString(16).toUpperCase()})'),
                const SizedBox(height: 4),
                Text('点位类型: ${p.typeCategory} (Type ${p.typeId.id})'),
                const Divider(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '点位名称 / 描述',
                    prefixIcon: Icon(Icons.label),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '点位名称不能为空';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valCtrl,
                  decoration: const InputDecoration(
                    labelText: '本地当前监视值',
                    helperText: '可手动校准/覆盖本地缓存数值',
                    prefixIcon: Icon(Icons.edit_note),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              label: const Text('删除点号', style: TextStyle(color: Colors.red)),
              onPressed: () {
                widget.station.removePoint(p.ioa);
                Navigator.pop(context);
                widget.onDeleted?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除点号: IOA = ${p.ioa}')),
                );
              },
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  p.name = _nameCtrl.text.trim();
                  p.update(_parseValue(), p.quality);
                  widget.station.onDataChanged?.call();
                  Navigator.pop(context);
                  widget.onUpdated?.call();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已更新点号: IOA = ${p.ioa}')),
                  );
                }
              },
              child: const Text('保存修改'),
            ),
          ],
        ),
      ],
    );
  }
}
