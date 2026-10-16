import 'dart:io';
import 'package:flutter/material.dart';
import '../../protocol/iec61850_server_manager.dart';

class FilesAndSettingsTab extends StatefulWidget {
  final Iec61850ServerManager manager;
  final VoidCallback onDataChanged;

  const FilesAndSettingsTab({
    super.key,
    required this.manager,
    required this.onDataChanged,
  });

  @override
  State<FilesAndSettingsTab> createState() => _FilesAndSettingsTabState();
}

class _FilesAndSettingsTabState extends State<FilesAndSettingsTab> {
  List<File> _files = [];
  int _activeSg = 1;
  final int _editSg = 1;

  @override
  void initState() {
    super.initState();
    _refreshFiles();
  }

  void _refreshFiles() {
    final dirPath = widget.manager.config.fileTransferDirectory;
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }

    if (dir.existsSync()) {
      setState(() {
        _files = dir.listSync().whereType<File>().toList();
      });
    }
  }

  void _createNewTestFile() {
    final dirPath = widget.manager.config.fileTransferDirectory;
    final now = DateTime.now();
    final name = 'event_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour}${now.minute}${now.second}.txt';
    final file = File('$dirPath/$name');
    file.writeAsStringSync('IEC 61850 MMS File Service Test Log\nCreated: ${now.toIso8601String()}\nStatus: Normal');
    _refreshFiles();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scl = widget.manager.engine.scl;
    final numOfSg = scl?.numOfSG ?? 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MMS File Services Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_shared, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'MMS 文件服务工作区 (File Services: FileDirectory / FileOpen / FileRead / FileDelete)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('刷新列表'),
                        onPressed: _refreshFiles,
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('新建测试文件'),
                        onPressed: _createNewTestFile,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当前目录：${widget.manager.config.fileTransferDirectory}',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  if (_files.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: const Text('文件服务目录当前为空，可点击右上角创建测试文件或放置 COMTRADE 录波文件。',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(4),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(3),
                        3: FlexColumnWidth(1),
                      },
                      border: TableBorder(
                        horizontalInside: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                      ),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[100]),
                          children: const [
                            Padding(padding: EdgeInsets.all(8), child: Text('文件名', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(8), child: Text('大小', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(8), child: Text('修改时间', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(8), child: Text('操作', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                        ..._files.map((file) {
                          final stat = file.statSync();
                          final name = file.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'file');
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.insert_drive_file, size: 16, color: Colors.blue),
                                    const SizedBox(width: 6),
                                    Text(name, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('${stat.size} 字节', style: const TextStyle(fontSize: 12)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(stat.modified.toIso8601String().substring(0, 19), style: const TextStyle(fontSize: 12)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () {
                                    file.deleteSync();
                                    _refreshFiles();
                                  },
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Setting Groups Control (SGCB) Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune, size: 20),
                      SizedBox(width: 8),
                      Text('定值区控制 (Setting Group Control - SGCB)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _sgMetric('支持定值区总数 (NumOfSG)', '$numOfSg 组'),
                      const SizedBox(width: 24),
                      _sgMetric('当前运行定值区 (ActSG)', '第 $_activeSg 组'),
                      const SizedBox(width: 24),
                      _sgMetric('编辑定值区 (EditSG)', '第 $_editSg 组'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('快速切换当前激活定值区 (Switch ActSG):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: List.generate(numOfSg.clamp(1, 16), (index) {
                      final sgIdx = index + 1;
                      final isActive = _activeSg == sgIdx;
                      return ChoiceChip(
                        label: Text('定值区 $sgIdx'),
                        selected: isActive,
                        onSelected: (sel) {
                          if (sel) {
                            setState(() => _activeSg = sgIdx);
                            widget.onDataChanged();
                          }
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sgMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
