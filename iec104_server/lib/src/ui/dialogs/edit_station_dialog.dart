import 'package:flutter/material.dart';
import '../../server/iec104_server.dart';
import '../../server/station.dart';

class EditStationDialog extends StatefulWidget {
  final Iec104Server server;
  final Station station;
  final ValueChanged<int>? onStationChanged;
  final VoidCallback? onStationDeleted;

  const EditStationDialog({
    super.key,
    required this.server,
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

  void _confirmDeleteStation() {
    if (widget.server.stations.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少需要保留一个从站，无法删除最后一个从站'), backgroundColor: Colors.orange),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除从站?'),
        content: Text('确定要删除从站 [COA=${widget.station.commonAddress}] "${widget.station.name}" 及其包含的所有 ${widget.station.points.length} 个点位吗？该操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final deletedCa = widget.station.commonAddress;
              widget.server.removeStation(deletedCa);
              Navigator.pop(ctx);
              Navigator.pop(context);
              widget.onStationDeleted?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已删除从站 [COA=$deletedCa]'), backgroundColor: Colors.red),
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
                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '当前站包含 $pointCount 个信息体点位。修改从站公共地址 (COA) 将同步更新其下属所有点位的从站归属。',
                          style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _caCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '从站公共地址 (COA / Common Address)',
                    helperText: '有效范围 1 ~ 65535',
                    prefixIcon: Icon(Icons.tag),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final v = int.tryParse(val ?? '');
                    if (v == null || v < 1 || v > 65535) {
                      return '请输入 1 ~ 65535 之间的有效整数';
                    }
                    if (v != widget.station.commonAddress && widget.server.stations.containsKey(v)) {
                      return '从站地址 (COA=$v) 已被其他从站占用';
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
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return '从站名称不能为空';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('快速套用模板:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.electric_bolt, size: 16),
                      label: const Text('配网工程模板'),
                      onPressed: () {
                        widget.station.applyTemplate('distribution');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已导入配网工程模板点位')),
                        );
                        setState(() {});
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.account_balance, size: 16),
                      label: const Text('变电站工程模板'),
                      onPressed: () {
                        widget.station.applyTemplate('substation');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已导入变电站工程模板点位')),
                        );
                        setState(() {});
                      },
                    ),
                  ],
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
              onPressed: widget.server.stations.length > 1 ? _confirmDeleteStation : null,
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
                  final oldCa = widget.station.commonAddress;
                  final newCa = int.parse(_caCtrl.text.trim());
                  final newName = _nameCtrl.text.trim();

                  widget.server.updateStation(oldCa, newCa, newName);
                  Navigator.pop(context);
                  widget.onStationChanged?.call(newCa);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已更新从站: $newName (COA=$newCa)'),
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
