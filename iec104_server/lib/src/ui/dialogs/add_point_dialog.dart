import 'package:flutter/material.dart';
import '../../protocol/asdu.dart';
import '../../server/station.dart';

class AddPointDialog extends StatefulWidget {
  final Station station;
  final void Function(StationPoint point) onAdd;

  const AddPointDialog({
    super.key,
    required this.station,
    required this.onAdd,
  });

  @override
  State<AddPointDialog> createState() => _AddPointDialogState();
}

class _AddPointDialogState extends State<AddPointDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ioaController;
  late TextEditingController _nameController;
  late TextEditingController _valController;

  AsduTypeId _selectedType = AsduTypeId.mMeNc1;

  @override
  void initState() {
    super.initState();
    // Default IOA to max IOA + 1
    int nextIoa = 1;
    if (widget.station.pointList.isNotEmpty) {
      nextIoa = widget.station.pointList.map((p) => p.ioa).reduce((a, b) => a > b ? a : b) + 1;
    }
    _ioaController = TextEditingController(text: nextIoa.toString());
    _nameController = TextEditingController(text: '遥测点位 #$nextIoa');
    _valController = TextEditingController(text: '0.0');
  }

  @override
  void dispose() {
    _ioaController.dispose();
    _nameController.dispose();
    _valController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加新信息对象点位'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _ioaController,
                decoration: const InputDecoration(
                  labelText: '信息对象地址 (IOA)',
                  helperText: '十进制整数 (1 ~ 16777215)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return '请输入有效的正整数';
                  if (widget.station.getPoint(n) != null) return '该 IOA 已存在于当前站中';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AsduTypeId>(
                initialValue: _selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'ASDU 协议类型',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: AsduTypeId.mSpNa1, child: Text('Type 1: M_SP_NA_1 单点遥信')),
                  DropdownMenuItem(value: AsduTypeId.mSpTb1, child: Text('Type 30: M_SP_TB_1 带时标单点遥信')),
                  DropdownMenuItem(value: AsduTypeId.mDpNa1, child: Text('Type 3: M_DP_NA_1 双点遥信')),
                  DropdownMenuItem(value: AsduTypeId.mDpTb1, child: Text('Type 31: M_DP_TB_1 带时标双点遥信')),
                  DropdownMenuItem(value: AsduTypeId.mStNa1, child: Text('Type 5: M_ST_NA_1 步位置/分接头')),
                  DropdownMenuItem(value: AsduTypeId.mBoNa1, child: Text('Type 7: M_BO_NA_1 32位二进制串')),
                  DropdownMenuItem(value: AsduTypeId.mMeNa1, child: Text('Type 9: M_ME_NA_1 归一化遥测')),
                  DropdownMenuItem(value: AsduTypeId.mMeNb1, child: Text('Type 11: M_ME_NB_1 标度化遥测')),
                  DropdownMenuItem(value: AsduTypeId.mMeNc1, child: Text('Type 13: M_ME_NC_1 短浮点数遥测')),
                  DropdownMenuItem(value: AsduTypeId.mMeTf1, child: Text('Type 36: M_ME_TF_1 带时标短浮点遥测')),
                  DropdownMenuItem(value: AsduTypeId.mItNa1, child: Text('Type 15: M_IT_NA_1 累计量/电能量/遥脉')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedType = v;
                      if (v == AsduTypeId.mSpNa1 || v == AsduTypeId.mSpTb1) {
                        _nameController.text = '单点遥信 #${_ioaController.text}';
                        _valController.text = 'false';
                      } else if (v == AsduTypeId.mDpNa1 || v == AsduTypeId.mDpTb1) {
                        _nameController.text = '双点遥信 #${_ioaController.text}';
                        _valController.text = '1';
                      } else if (v == AsduTypeId.mItNa1) {
                        _nameController.text = '电能量遥脉 #${_ioaController.text}';
                        _valController.text = '0';
                      } else {
                        _nameController.text = '遥测点位 #${_ioaController.text}';
                        _valController.text = '0.0';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '点位名称 / 描述',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入点位名称' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valController,
                decoration: const InputDecoration(
                  labelText: '初始数值',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入初始数值' : null,
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
              final ioa = int.parse(_ioaController.text.trim());
              final name = _nameController.text.trim();
              final rawVal = _valController.text.trim();

              dynamic val;
              if (_selectedType == AsduTypeId.mSpNa1 || _selectedType == AsduTypeId.mSpTb1) {
                val = rawVal == 'true' || rawVal == '1';
              } else if (_selectedType == AsduTypeId.mDpNa1 || _selectedType == AsduTypeId.mDpTb1) {
                val = int.tryParse(rawVal) ?? 1;
              } else if (_selectedType == AsduTypeId.mMeNb1 ||
                  _selectedType == AsduTypeId.mStNa1 ||
                  _selectedType == AsduTypeId.mBoNa1 ||
                  _selectedType == AsduTypeId.mItNa1) {
                val = int.tryParse(rawVal) ?? 0;
              } else {
                val = double.tryParse(rawVal) ?? 0.0;
              }

              widget.onAdd(StationPoint(
                ioa: ioa,
                typeId: _selectedType,
                name: name,
                value: val,
              ));
              Navigator.pop(context);
            }
          },
          child: const Text('添加'),
        ),
      ],
    );
  }
}
