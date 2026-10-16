import 'package:flutter/material.dart';
import '../../protocol/asdu.dart';
import '../../server/station.dart';

class BatchInitDialog extends StatefulWidget {
  final Station station;
  final void Function({
    required AsduTypeId typeId,
    required int startIoa,
    required int count,
    required String prefix,
  }) onGenerate;

  const BatchInitDialog({
    super.key,
    required this.station,
    required this.onGenerate,
  });

  @override
  State<BatchInitDialog> createState() => _BatchInitDialogState();
}

class _BatchInitDialogState extends State<BatchInitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _startIoaController = TextEditingController(text: '16385');
  final _countController = TextEditingController(text: '10');
  final _prefixController = TextEditingController(text: '模拟遥测通道');
  AsduTypeId _selectedType = AsduTypeId.mMeNc1;

  @override
  void dispose() {
    _startIoaController.dispose();
    _countController.dispose();
    _prefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('批量生成信息对象点位'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AsduTypeId>(
                initialValue: _selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '点位类型',
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
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedType = v;
                      if (v == AsduTypeId.mSpNa1) {
                        _startIoaController.text = '1001';
                        _prefixController.text = '模拟遥信开关';
                      } else if (v == AsduTypeId.mDpNa1) {
                        _startIoaController.text = '2001';
                        _prefixController.text = '模拟双点开关';
                      } else if (v == AsduTypeId.mItNa1) {
                        _startIoaController.text = '25601';
                        _prefixController.text = '模拟电能表';
                      } else {
                        _startIoaController.text = '16385';
                        _prefixController.text = '模拟遥测通道';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startIoaController,
                decoration: const InputDecoration(
                  labelText: '起始 IOA 地址',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return '请输入有效的正整数';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _countController,
                decoration: const InputDecoration(
                  labelText: '生成数量',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0 || n > 500) return '数量范围 1 ~ 500';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _prefixController,
                decoration: const InputDecoration(
                  labelText: '点位名称前缀',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入名称前缀' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final startIoa = int.parse(_startIoaController.text.trim());
              final count = int.parse(_countController.text.trim());
              final prefix = _prefixController.text.trim();

              widget.onGenerate(
                typeId: _selectedType,
                startIoa: startIoa,
                count: count,
                prefix: prefix,
              );
              Navigator.pop(context);
            }
          },
          child: const Text('开始生成'),
        ),
      ],
    );
  }
}
