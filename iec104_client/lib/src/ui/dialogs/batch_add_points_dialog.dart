import 'package:flutter/material.dart';
import '../../client/station_data.dart';
import '../../protocol/asdu.dart';

class BatchAddPointsDialog extends StatefulWidget {
  final ClientStationModel station;
  final VoidCallback? onGenerated;

  const BatchAddPointsDialog({
    super.key,
    required this.station,
    this.onGenerated,
  });

  @override
  State<BatchAddPointsDialog> createState() => _BatchAddPointsDialogState();
}

class _BatchAddPointsDialogState extends State<BatchAddPointsDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _startIoaCtrl;
  late TextEditingController _countCtrl;
  late TextEditingController _prefixCtrl;
  AsduTypeId _selectedType = AsduTypeId.mMeNc1;
  bool _overwriteExisting = true;

  @override
  void initState() {
    super.initState();
    _startIoaCtrl = TextEditingController(text: '16385');
    _countCtrl = TextEditingController(text: '16');
    _prefixCtrl = TextEditingController(text: '模拟遥测通道');
  }

  @override
  void dispose() {
    _startIoaCtrl.dispose();
    _countCtrl.dispose();
    _prefixCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(AsduTypeId? type) {
    if (type == null) return;
    setState(() {
      _selectedType = type;
      if (type == AsduTypeId.mSpNa1) {
        _startIoaCtrl.text = '1';
        _prefixCtrl.text = '配电单点开关';
      } else if (type == AsduTypeId.mDpNa1) {
        _startIoaCtrl.text = '1001';
        _prefixCtrl.text = '双位置隔离开关';
      } else if (type == AsduTypeId.mItNa1) {
        _startIoaCtrl.text = '25601';
        _prefixCtrl.text = '进出线电能量表';
      } else if (type == AsduTypeId.mMeNa1) {
        _startIoaCtrl.text = '16385';
        _prefixCtrl.text = '归一化遥测通道';
      } else if (type == AsduTypeId.mMeNb1) {
        _startIoaCtrl.text = '16385';
        _prefixCtrl.text = '标度化遥测通道';
      } else {
        _startIoaCtrl.text = '16385';
        _prefixCtrl.text = '短浮点遥测通道';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.playlist_add, color: Colors.blue),
          const SizedBox(width: 8),
          Text('批量生成点号 (从站 CA: ${widget.station.commonAddress})'),
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
                const Text(
                  '按旧版信息对象组 (InformationObjectGroup) 批量规则，快速递增生成点号：',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AsduTypeId>(
                  initialValue: _selectedType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '点号类型 (ASDU Type)',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: AsduTypeId.mSpNa1, child: Text('Type 1: 单点遥信 (M_SP_NA_1)')),
                    DropdownMenuItem(value: AsduTypeId.mDpNa1, child: Text('Type 3: 双点遥信 (M_DP_NA_1)')),
                    DropdownMenuItem(value: AsduTypeId.mMeNc1, child: Text('Type 13: 短浮点遥测 (M_ME_NC_1)')),
                    DropdownMenuItem(value: AsduTypeId.mMeNa1, child: Text('Type 9: 归一化遥测 (M_ME_NA_1)')),
                    DropdownMenuItem(value: AsduTypeId.mMeNb1, child: Text('Type 11: 标度化遥测 (M_ME_NB_1)')),
                    DropdownMenuItem(value: AsduTypeId.mItNa1, child: Text('Type 15: 电能量遥脉 (M_IT_NA_1)')),
                  ],
                  onChanged: _onTypeChanged,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _startIoaCtrl,
                        decoration: const InputDecoration(
                          labelText: '起始点号 (Start IOA)',
                          helperText: '常规: 遥信1 / 遥测16385',
                          prefixIcon: Icon(Icons.pin),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0 || n > 16777215) {
                            return '请输入有效正整数';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _countCtrl,
                        decoration: const InputDecoration(
                          labelText: '生成数量 (Count)',
                          helperText: '1 ~ 1000',
                          prefixIcon: Icon(Icons.format_list_numbered),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0 || n > 2000) {
                            return '1 ~ 2000';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _prefixCtrl,
                  decoration: const InputDecoration(
                    labelText: '点位名称前缀 (Prefix)',
                    helperText: '例如: 出线断路器 -> 生成 出线断路器 #1, #2...',
                    prefixIcon: Icon(Icons.drive_file_rename_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '前缀不能为空';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('覆盖已有冲突点号', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('若目标 IOA 已存在，将替换为新生成的配置', style: TextStyle(fontSize: 12)),
                  value: _overwriteExisting,
                  onChanged: (val) => setState(() => _overwriteExisting = val),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.bolt, size: 18),
          label: const Text('开始生成'),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final startIoa = int.parse(_startIoaCtrl.text.trim());
              final count = int.parse(_countCtrl.text.trim());
              final prefix = _prefixCtrl.text.trim();

              int addedCount = 0;
              for (int i = 0; i < count; i++) {
                final ioa = startIoa + i;
                if (!_overwriteExisting && widget.station.getPoint(ioa) != null) {
                  continue;
                }

                dynamic val;
                if (_selectedType == AsduTypeId.mSpNa1) {
                  val = false;
                } else if (_selectedType == AsduTypeId.mDpNa1) {
                  val = 1;
                } else if (_selectedType == AsduTypeId.mMeNc1) {
                  val = 0.0;
                } else {
                  val = 0;
                }

                widget.station.addPoint(ClientPointModel(
                  commonAddress: widget.station.commonAddress,
                  ioa: ioa,
                  typeId: _selectedType,
                  name: '$prefix #${i + 1}',
                  value: val,
                ));
                addedCount++;
              }

              Navigator.pop(context);
              widget.onGenerated?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已批量生成 $addedCount 个点号 (起始 IOA: $startIoa)'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
