import 'package:flutter/material.dart';
import '../../client/iec104_client.dart';
import '../../client/station_data.dart';

class EditStationDialog extends StatefulWidget {
  final Iec104Client client;
  final ClientStationModel station;
  final void Function(int ca)? onStationChanged;
  final VoidCallback? onStationDeleted;

  const EditStationDialog({
    super.key,
    required this.client,
    required this.station,
    this.onStationChanged,
    this.onStationDeleted,
  });

  @override
  State<EditStationDialog> createState() => _EditStationDialogState();
}

class _EditStationDialogState extends State<EditStationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _caCtrl;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _caCtrl = TextEditingController(text: widget.station.commonAddress.toString());
    _nameCtrl = TextEditingController(text: widget.station.name);
  }

  @override
  void dispose() {
    _caCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _confirmDelete() {
    if (widget.client.stations.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('至少需要保留一个从站，无法删除最后一个从站'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('确认删除从站？'),
          ],
        ),
        content: Text(
          '确定要删除从站【${widget.station.name}】(COA: ${widget.station.commonAddress}) 吗？\n该站内包含的 ${widget.station.points.length} 个点号数据将被全部清除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx); // Close confirm
              Navigator.pop(context); // Close edit dialog
              final deletedCa = widget.station.commonAddress;
              widget.client.removeStation(deletedCa);
              widget.onStationDeleted?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已成功删除从站 (COA: $deletedCa)'),
                ),
              );
            },
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pointCount = widget.station.points.length;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings_outlined, color: Colors.blue),
          SizedBox(width: 8),
          Text('管理从站配置 (Edit Station)'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '当前站内拥有 $pointCount 个监视点位。若修改 COA 地址，站内点位的从站地址将一并自动迁移。',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _caCtrl,
                  decoration: const InputDecoration(
                    labelText: '从站公共地址 (COA / CA)',
                    helperText: '范围: 1 ~ 65535',
                    prefixIcon: Icon(Icons.tag),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0 || n > 65535) {
                      return '请输入 1 ~ 65535 之间的有效整数';
                    }
                    if (n != widget.station.commonAddress && widget.client.stations.containsKey(n)) {
                      return '该 COA 地址 ($n) 已被其他从站使用';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '从站名称 (Station Name)',
                    prefixIcon: Icon(Icons.edit_note),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return '从站名称不能为空';
                    }
                    return null;
                  },
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
              label: const Text('删除从站', style: TextStyle(color: Colors.red)),
              onPressed: _confirmDelete,
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
                  final newCa = int.parse(_caCtrl.text.trim());
                  final newName = _nameCtrl.text.trim();
                  final oldCa = widget.station.commonAddress;

                  widget.client.updateStation(oldCa, newCa, newName);
                  Navigator.pop(context);
                  widget.onStationChanged?.call(newCa);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已保存从站修改: $newName (COA: $newCa)'),
                      backgroundColor: Colors.green,
                    ),
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
