import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/scl_models.dart';
import '../../protocol/iec61850_client_manager.dart';

class FilesAndSettingsTab extends StatefulWidget {
  final Iec61850ClientManager manager;
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
  List<({String name, int size})> _remoteFiles = [];
  bool _isLoadingFiles = false;
  bool _isSwitchingSg = false;
  int _selectedSg = 1;
  String _statusMsg = '';

  @override
  void initState() {
    super.initState();
    _selectedSg = 1;
  }

  Future<void> _queryRemoteFiles() async {
    final engine = widget.manager.activeEngine;
    if (engine == null || !engine.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先连接到服务端再查询远端文件')),
      );
      return;
    }

    setState(() {
      _isLoadingFiles = true;
      _statusMsg = '正在查询服务端文件目录 (FileDirectory)...';
    });

    try {
      final list = await engine.listRemoteFiles();
      setState(() {
        _remoteFiles = list;
        _isLoadingFiles = false;
        _statusMsg = '获取到 ${list.length} 个远端文件';
      });
    } catch (e) {
      setState(() {
        _isLoadingFiles = false;
        _statusMsg = '查询文件失败: $e';
      });
    }
  }

  Future<void> _downloadFile(String filename) async {
    final engine = widget.manager.activeEngine;
    if (engine == null || !engine.isConnected) return;

    final downloadsDir = Directory('${Platform.environment['HOME'] ?? '.'}/Downloads');
    if (!downloadsDir.existsSync()) {
      downloadsDir.createSync(recursive: true);
    }
    final targetPath = '${downloadsDir.path}/$filename';

    setState(() {
      _statusMsg = '正在下载 $filename ...';
    });

    final ok = await engine.downloadFile(
      filename,
      targetPath,
      onProgress: (received, total) {
        if (mounted) {
          setState(() {
            _statusMsg = '正在下载 $filename: $received / $total 字节';
          });
        }
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '文件下载成功，已保存至 $targetPath' : '下载失败，请检查连接或文件权限'),
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() {
        _statusMsg = ok ? '下载完成: $filename' : '下载失败';
      });
    }
  }

  Future<void> _switchActiveSg(int sgNum) async {
    final engine = widget.manager.activeEngine;
    if (engine == null || !engine.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先连接到服务端再切换定值区')),
      );
      return;
    }

    setState(() => _isSwitchingSg = true);
    final ok = await engine.switchSettingGroup(sgNum);
    setState(() => _isSwitchingSg = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '定值区成功切换至第 $sgNum 区 (ActSG = $sgNum)' : '定值区切换失败'),
          duration: const Duration(seconds: 2),
        ),
      );
      if (ok) {
        setState(() => _selectedSg = sgNum);
        widget.onDataChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engine = widget.manager.activeEngine;
    final scl = engine?.scl;
    final numOfSg = scl?.numOfSG ?? 4;

    // Filter setting variables (FC=SG or FC=SE)
    final sgVars = engine?.allVariables
            .where((v) => v.fc == FunctionalConstraint.sg || v.fc == FunctionalConstraint.se)
            .toList() ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MMS File Services Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_shared, size: 20, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      const Text(
                        'MMS 远端文件服务 (File Services: FileDirectory / FileOpen / FileRead)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: _isLoadingFiles
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cloud_download_outlined, size: 16),
                        label: const Text('查询远端文件列表'),
                        onPressed: (engine?.isConnected ?? false) && !_isLoadingFiles ? _queryRemoteFiles : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '支持从远端 IEC 61850 装置浏览并下载录波文件 (COMTRADE .cfg / .dat) 或事件日志文件',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  if (_statusMsg.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_statusMsg, style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_remoteFiles.isEmpty)
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? Colors.grey[850]! : Colors.grey[300]!),
                      ),
                      child: const Center(
                        child: Text(
                          '未查询到文件或尚未进行目录查询\n点击右上角 "查询远端文件列表" 获取远端目录',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _remoteFiles.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        ),
                        itemBuilder: (context, index) {
                          final f = _remoteFiles[index];
                          final isComtrade = f.name.endsWith('.cfg') || f.name.endsWith('.dat');

                          return ListTile(
                            leading: Icon(
                              isComtrade ? Icons.show_chart : Icons.insert_drive_file_outlined,
                              color: isComtrade ? Colors.orangeAccent : Colors.blueGrey,
                            ),
                            title: Text(
                              f.name,
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('${(f.size / 1024).toStringAsFixed(2)} KB (${f.size} 字节)'),
                            trailing: FilledButton.tonalIcon(
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('下载到本地'),
                              onPressed: () => _downloadFile(f.name),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Setting Group Control Block (SGCB) Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, size: 20, color: Colors.purpleAccent),
                      const SizedBox(width: 8),
                      const Text(
                        '定值分组控制区 (SGCB: Setting Group Control Block)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      if (_isSwitchingSg)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '支持切换当前装置活动定值区 (ActSG)，并实时查看定值参数 (FC=SG/SE)',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),

                  // Setting Group Selector Buttons
                  Row(
                    children: [
                      const Text('活动定值区 (ActSG): ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 12),
                      Wrap(
                        spacing: 8,
                        children: List.generate(numOfSg, (i) {
                          final sgNum = i + 1;
                          final isCurrent = _selectedSg == sgNum;
                          return ChoiceChip(
                            label: Text('第 $sgNum 区 (SG$sgNum)'),
                            selected: isCurrent,
                            selectedColor: Colors.purple.withOpacity(0.3),
                            onSelected: (engine?.isConnected ?? false) && !_isSwitchingSg
                                ? (selected) {
                                    if (selected) _switchActiveSg(sgNum);
                                  }
                                : null,
                          );
                        }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Text('定值参数列表 (FC=SG/SE):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (sgVars.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Text(
                          '当前模型未配置定值变量 (FC=SG/SE)',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    Table(
                      border: TableBorder.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(4),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(2),
                        3: FlexColumnWidth(3),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF252526) : const Color(0xFFEBEBEB),
                          ),
                          children: const [
                            Padding(padding: EdgeInsets.all(8), child: Text('定值参数全称 (Reference)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(8), child: Text('FC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(8), child: Text('类型', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(8), child: Text('当前值 (Live Value)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                        ...sgVars.map(
                          (v) => TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(v.shortRef, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(v.fcCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purpleAccent)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(v.type.name, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('${v.value}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
