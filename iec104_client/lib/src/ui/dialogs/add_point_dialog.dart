import 'package:flutter/material.dart';
import '../../client/station_data.dart';
import '../../protocol/asdu.dart';

class AddPointDialog extends StatefulWidget {
  final ClientStationModel station;
  final void Function(ClientPointModel newPoint)? onAdded;

  const AddPointDialog({
    super.key,
    required this.station,
    this.onAdded,
  });

  @override
  State<AddPointDialog> createState() => _AddPointDialogState();
}

class _AddPointDialogState extends State<AddPointDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ioaCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _valCtrl;
  AsduTypeId _selectedType = AsduTypeId.mMeNc1;

  @override
  void initState() {
    super.initState();
    // Default IOA to max existing IOA + 1 or 1
    int nextIoa = 1;
    if (widget.station.points.isNotEmpty) {
      nextIoa = widget.station.points.keys.reduce((a, b) => a > b ? a : b) + 1;
    }
    _ioaCtrl = TextEditingController(text: nextIoa.toString());
    _nameCtrl = TextEditingController(text: '遥测通道 #$nextIoa');
    _valCtrl = TextEditingController(text: '0.0');
  }

  @override
  void dispose() {
    _ioaCtrl.dispose();
    _nameCtrl.dispose();
    _valCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(AsduTypeId? type) {
    if (type == null) return;
    setState(() {
      _selectedType = type;
      final ioaStr = _ioaCtrl.text.trim();
      if (type == AsduTypeId.mSpNa1 || type == AsduTypeId.mSpTb1) {
        _nameCtrl.text = '单点遥信 #$ioaStr';
        _valCtrl.text = 'false';
      } else if (type == AsduTypeId.mDpNa1 || type == AsduTypeId.mDpTb1) {
        _nameCtrl.text = '双点遥信 #$ioaStr';
        _valCtrl.text = '1';
      } else if (type == AsduTypeId.mItNa1 || type == AsduTypeId.mItTb1) {
        _nameCtrl.text = '电能量遥脉 #$ioaStr';
        _valCtrl.text = '0';
      } else if (type == AsduTypeId.mStNa1 || type == AsduTypeId.mStTb1) {
        _nameCtrl.text = '变压器档位 #$ioaStr';
        _valCtrl.text = '0';
      } else if (type == AsduTypeId.mBoNa1 || type == AsduTypeId.mBoTb1) {
        _nameCtrl.text = '32位二进制串 #$ioaStr';
        _valCtrl.text = '0';
      } else {
        _nameCtrl.text = '短浮点遥测 #$ioaStr';
        _valCtrl.text = '0.0';
      }
    });
  }

  dynamic _parseValue() {
    final text = _valCtrl.text.trim();
    if (_selectedType == AsduTypeId.mSpNa1 || _selectedType == AsduTypeId.mSpTb1) {
      return text == '1' || text.toLowerCase() == 'true';
    } else if (_selectedType == AsduTypeId.mDpNa1 || _selectedType == AsduTypeId.mDpTb1) {
      return int.tryParse(text) ?? 1;
    } else if (_selectedType == AsduTypeId.mMeNc1 || _selectedType == AsduTypeId.mMeTf1) {
      return double.tryParse(text) ?? 0.0;
    } else {
      return int.tryParse(text) ?? (double.tryParse(text)?.toInt() ?? 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.add_circle_outline, color: Colors.blue),
          const SizedBox(width: 8),
          Text('添加点号 (从站 CA: ${widget.station.commonAddress})'),
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
                TextFormField(
                  controller: _ioaCtrl,
                  decoration: const InputDecoration(
                    labelText: '信息对象地址 (IOA / 点号)',
                    helperText: '范围: 1 ~ 16777215 (十进制)',
                    prefixIcon: Icon(Icons.pin),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0 || n > 16777215) {
                      return '请输入 1 ~ 16777215 之间的有效整数';
                    }
                    if (widget.station.getPoint(n) != null) {
                      return '该点号 IOA ($n) 在本从站已存在';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AsduTypeId>(
                  initialValue: _selectedType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'ASDU 协议数据类型',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: AsduTypeId.mSpNa1, child: Text('Type 1: M_SP_NA_1 单点遥信')),
                    DropdownMenuItem(value: AsduTypeId.mSpTb1, child: Text('Type 30: M_SP_TB_1 带CP56时标单点遥信')),
                    DropdownMenuItem(value: AsduTypeId.mDpNa1, child: Text('Type 3: M_DP_NA_1 双点遥信')),
                    DropdownMenuItem(value: AsduTypeId.mDpTb1, child: Text('Type 31: M_DP_TB_1 带CP56时标双点遥信')),
                    DropdownMenuItem(value: AsduTypeId.mMeNc1, child: Text('Type 13: M_ME_NC_1 短浮点数遥测')),
                    DropdownMenuItem(value: AsduTypeId.mMeTf1, child: Text('Type 36: M_ME_TF_1 带CP56时标短浮点遥测')),
                    DropdownMenuItem(value: AsduTypeId.mMeNa1, child: Text('Type 9: M_ME_NA_1 归一化值遥测')),
                    DropdownMenuItem(value: AsduTypeId.mMeNb1, child: Text('Type 11: M_ME_NB_1 标度化值遥测')),
                    DropdownMenuItem(value: AsduTypeId.mItNa1, child: Text('Type 15: M_IT_NA_1 电能量累计脉冲')),
                    DropdownMenuItem(value: AsduTypeId.mStNa1, child: Text('Type 5: M_ST_NA_1 变压器步位置分接头')),
                    DropdownMenuItem(value: AsduTypeId.mBoNa1, child: Text('Type 7: M_BO_NA_1 32位二进制串')),
                  ],
                  onChanged: _onTypeChanged,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '点位名称 / 变量名 (Name)',
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
                  decoration: InputDecoration(
                    labelText: '初始监视值 (Initial Value)',
                    helperText: (_selectedType == AsduTypeId.mSpNa1 || _selectedType == AsduTypeId.mSpTb1)
                        ? '遥信开关: 1 (合闸/true) 或 0 (分闸/false)'
                        : ((_selectedType == AsduTypeId.mDpNa1 || _selectedType == AsduTypeId.mDpTb1)
                            ? '双点状态: 2 (合), 1 (分), 0/3 (未决)'
                            : '遥测/遥脉浮点数值'),
                    prefixIcon: const Icon(Icons.numbers),
                    border: const OutlineInputBorder(),
                  ),
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
          icon: const Icon(Icons.check, size: 18),
          label: const Text('确定添加'),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final ioa = int.parse(_ioaCtrl.text.trim());
              final name = _nameCtrl.text.trim();
              final val = _parseValue();

              final newPoint = ClientPointModel(
                commonAddress: widget.station.commonAddress,
                ioa: ioa,
                typeId: _selectedType,
                name: name,
                value: val,
              );

              widget.station.addPoint(newPoint);
              Navigator.pop(context);
              widget.onAdded?.call(newPoint);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已成功添加点号: $name (IOA: $ioa)'),
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
