import '../../i18n/app_i18n.dart';
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
        SnackBar(content: Text(AppI18n.instance.t('connectFirstFiles'))),
      );
      return;
    }

    setState(() {
      _isLoadingFiles = true;
      _statusMsg = AppI18n.instance.t('queryingFiles');
    });

    try {
      final list = await engine.listRemoteFiles();
      setState(() {
        _remoteFiles = list;
        _isLoadingFiles = false;
        _statusMsg = '${list.length} files';
      });
    } catch (e) {
      setState(() {
        _isLoadingFiles = false;
        _statusMsg = 'Error: $e';
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
      _statusMsg = 'Downloading $filename...';
    });

    final ok = await engine.downloadFile(
      filename,
      targetPath,
      onProgress: (received, total) {
        if (mounted) {
          setState(() {
            _statusMsg = 'Downloading $filename: $received / $total B';
          });
        }
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Download success: $targetPath' : AppI18n.instance.t('downloadFailedMsg')),
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() {
        _statusMsg = ok ? 'Downloaded: $filename' : AppI18n.instance.t('downloadFail');
      });
    }
  }

  Future<void> _switchActiveSg(int sgNum) async {
    final engine = widget.manager.activeEngine;
    if (engine == null || !engine.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppI18n.instance.t('connectFirstSg'))),
      );
      return;
    }

    setState(() => _isSwitchingSg = true);
    final ok = await engine.switchSettingGroup(sgNum);
    setState(() => _isSwitchingSg = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'ActSG -> SG$sgNum' : AppI18n.instance.t('sgSwitchFailed')),
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
    final i18n = AppI18n.instance;
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
                        i18n.t('remoteFilesService'),
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
                        label: Text(i18n.t('queryRemoteFiles')),
                        onPressed: (engine?.isConnected ?? false) && !_isLoadingFiles ? _queryRemoteFiles : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i18n.t('remoteFilesDesc'),
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
                          i18n.t('emptyRemoteFiles'),
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
                            subtitle: Text('${(f.size / 1024).toStringAsFixed(2)} KB (${f.size} ${i18n.t("bytesUnit")})'),
                            trailing: FilledButton.tonalIcon(
                              icon: const Icon(Icons.download, size: 16),
                              label: Text(i18n.t('downloadToLocal')),
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
                        i18n.t('sgcbTitle'),
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
                    i18n.t('tplSgDesc'),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),

                  // Setting Group Selector Buttons
                  Row(
                    children: [
                      Text('${i18n.t("actSgLabel")}: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 12),
                      Wrap(
                        spacing: 8,
                        children: List.generate(numOfSg, (i) {
                          final sgNum = i + 1;
                          final isCurrent = _selectedSg == sgNum;
                          return ChoiceChip(
                            label: Text('SG$sgNum (${i18n.t("nthGroupPrefix")}$sgNum${i18n.t("nthGroupSuffix")})'),
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
                  Text(i18n.t('sgParamsList'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                          i18n.t('noSgVarsConfigured'),
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
                            Padding(padding: const EdgeInsets.all(8), child: Text(i18n.t('colSgRef'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(8), child: Text('FC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(i18n.t('colType'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(i18n.t('colVal'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
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
