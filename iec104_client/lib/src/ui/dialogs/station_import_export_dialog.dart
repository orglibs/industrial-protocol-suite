import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../client/iec104_client.dart';
import '../../client/station_data.dart';

class StationImportExportDialog extends StatefulWidget {
  final Iec104Client client;
  final ClientStationModel currentStation;
  final VoidCallback? onImported;

  const StationImportExportDialog({
    super.key,
    required this.client,
    required this.currentStation,
    this.onImported,
  });

  @override
  State<StationImportExportDialog> createState() => _StationImportExportDialogState();
}

class _StationImportExportDialogState extends State<StationImportExportDialog> {
  late TextEditingController _textCtrl;
  bool _exportAll = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
    _refreshExportText();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _refreshExportText() {
    if (_exportAll) {
      final list = widget.client.stations.values.map((s) => s.toJson()).toList();
      _textCtrl.text = const JsonEncoder.withIndent('  ').convert({'stations': list});
    } else {
      _textCtrl.text = const JsonEncoder.withIndent('  ').convert(widget.currentStation.toJson());
    }
  }

  void _doImport() {
    try {
      final json = jsonDecode(_textCtrl.text);
      if (json is Map<String, dynamic>) {
        if (json.containsKey('stations') && json['stations'] is List) {
          // Import multiple stations
          int count = 0;
          for (final item in json['stations']) {
            if (item is Map<String, dynamic>) {
              final ca = item['commonAddress'] as int? ?? 1;
              final st = widget.client.getStation(ca);
              st.loadFromJson(item);
              count++;
            }
          }
          Navigator.pop(context);
          widget.onImported?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功导入 $count 个从站及其点号表'), backgroundColor: Colors.green),
          );
        } else if (json.containsKey('commonAddress')) {
          // Import single station
          final ca = json['commonAddress'] as int? ?? widget.currentStation.commonAddress;
          final st = widget.client.getStation(ca);
          st.loadFromJson(json);
          Navigator.pop(context);
          widget.onImported?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功导入从站 [CA=$ca] 点号表 (${st.points.length} 点)'), backgroundColor: Colors.green),
          );
        } else {
          throw const FormatException('未识别到有效的从站 JSON 格式 (缺少 commonAddress 或 stations 键)');
        }
      } else {
        throw const FormatException('JSON 必须是对象格式');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入解析失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.import_export, color: Colors.blue),
          SizedBox(width: 8),
          Text('从站点号表 导入 / 导出 (Export & Import)'),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: Text('当前站 (${widget.currentStation.name})'),
                  selected: !_exportAll,
                  onSelected: (sel) {
                    if (sel) {
                      setState(() {
                        _exportAll = false;
                        _refreshExportText();
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('全部从站 (${widget.client.stations.length} 站)'),
                  selected: _exportAll,
                  onSelected: (sel) {
                    if (sel) {
                      setState(() {
                        _exportAll = true;
                        _refreshExportText();
                      });
                    }
                  },
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制配置'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _textCtrl.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('配置已复制到剪贴板')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  labelText: '点号 JSON 文本 (可直接编辑或粘贴导入)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.file_upload, size: 18),
              label: const Text('从上方 JSON 文本导入'),
              onPressed: _doImport,
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      ],
    );
  }
}
