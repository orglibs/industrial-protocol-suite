import 'package:flutter/material.dart';
import '../../models/client_variable_model.dart';

class CreateDataSetDialog extends StatefulWidget {
  final List<ClientVariableModel> allVariables;
  final void Function(String name, List<ClientVariableModel> selectedMembers) onCreated;

  const CreateDataSetDialog({
    super.key,
    required this.allVariables,
    required this.onCreated,
  });

  @override
  State<CreateDataSetDialog> createState() => _CreateDataSetDialogState();
}

class _CreateDataSetDialogState extends State<CreateDataSetDialog> {
  final TextEditingController _nameCtrl = TextEditingController(text: 'dsDynamic1');
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedRefs = {};
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _filter = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final members = widget.allVariables.where((v) => _selectedRefs.contains(v.reference)).toList();
    if (members.isEmpty) return;

    widget.onCreated(name, members);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter.isEmpty
        ? widget.allVariables
        : widget.allVariables.where((v) =>
            v.reference.toLowerCase().contains(_filter) ||
            v.shortRef.toLowerCase().contains(_filter)).toList();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.dataset_outlined),
          SizedBox(width: 8),
          Text('创建动态数据集 (Create Dynamic DataSet)'),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '数据集名称 (DataSet Name)',
                hintText: '如 dsMeasurements, dsEvents',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: '快速搜索变量测点...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('已选成员: ${_selectedRefs.length} / ${widget.allVariables.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedRefs.length == filtered.length) {
                        _selectedRefs.clear();
                      } else {
                        _selectedRefs.addAll(filtered.map((v) => v.reference));
                      }
                    });
                  },
                  child: Text(_selectedRefs.length == filtered.length ? '取消全选' : '全选筛选项'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final v = filtered[index];
                  final isChecked = _selectedRefs.contains(v.reference);

                  return CheckboxListTile(
                    dense: true,
                    value: isChecked,
                    title: Text(v.shortRef, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text('Type: ${v.type.name}  |  FC: ${v.fcCode}', style: const TextStyle(fontSize: 11)),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedRefs.add(v.reference);
                        } else {
                          _selectedRefs.remove(v.reference);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('确认创建'),
          onPressed: _selectedRefs.isEmpty ? null : _submit,
        ),
      ],
    );
  }
}
