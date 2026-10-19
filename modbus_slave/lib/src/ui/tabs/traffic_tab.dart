import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/app_i18n.dart';
import '../../services/traffic_logger.dart';

class TrafficTab extends StatefulWidget {
  const TrafficTab({super.key});

  @override
  State<TrafficTab> createState() => _TrafficTabState();
}

class _TrafficTabState extends State<TrafficTab> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<TrafficEntry>? _sub;

  bool _autoScroll = true;
  String _filterConnection = 'ALL';
  String _filterDirection = 'ALL';
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _sub = TrafficLogger.instance.onNewEntry.listen((_) {
      if (mounted) {
        setState(() {});
        if (_autoScroll && _scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<TrafficEntry> _filteredEntries() {
    final list = TrafficLogger.instance.entries;
    return list.where((e) {
      if (_filterConnection != 'ALL' && e.connectionName != _filterConnection) {
        return false;
      }
      if (_filterDirection == 'RX' && e.direction != TrafficDirection.rx) {
        return false;
      }
      if (_filterDirection == 'TX' && e.direction != TrafficDirection.tx) {
        return false;
      }
      if (_searchKeyword.isNotEmpty) {
        final kw = _searchKeyword.toLowerCase();
        final matchHex = e.hexString.toLowerCase().contains(kw);
        final matchDesc = e.description.toLowerCase().contains(kw);
        final matchUnit = e.unitId.toString().contains(kw);
        if (!matchHex && !matchDesc && !matchUnit) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;
    final allEntries = TrafficLogger.instance.entries;
    final filtered = _filteredEntries();

    // Distinct connections for filter
    final connNames = <String>{'ALL'};
    for (final e in allEntries) {
      connNames.add(e.connectionName);
    }

    return Scaffold(
      body: Column(
        children: [
          // Filter & Action Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Connection Filter (width: 195, menuWidth: 320)
                  Tooltip(
                    message: _filterConnection == 'ALL' ? i18n.t('allConn') : _filterConnection,
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 195,
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      alignment: Alignment.center,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        menuWidth: 320,
                        menuMaxHeight: 400,
                        value: connNames.contains(_filterConnection) ? _filterConnection : 'ALL',
                        underline: const SizedBox(),
                        isDense: true,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        items: connNames
                            .map((c) {
                              final text = c == 'ALL' ? i18n.t('allConn') : c;
                              return DropdownMenuItem(
                                value: c,
                                child: Tooltip(
                                  message: text,
                                  waitDuration: const Duration(milliseconds: 150),
                                  child: Text(
                                    text,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            })
                            .toList(),
                        onChanged: (v) => setState(() => _filterConnection = v ?? 'ALL'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Direction Filter (width: 130, menuWidth: 160)
                  Tooltip(
                    message: _filterDirection == 'ALL'
                        ? i18n.t('allDir')
                        : (_filterDirection == 'RX' ? i18n.t('rxOnly') : i18n.t('txOnly')),
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 130,
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      alignment: Alignment.center,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        menuWidth: 160,
                        value: _filterDirection,
                        underline: const SizedBox(),
                        isDense: true,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        items: [
                          DropdownMenuItem(
                            value: 'ALL',
                            child: Tooltip(
                              message: i18n.t('allDir'),
                              waitDuration: const Duration(milliseconds: 150),
                              child: Text(i18n.t('allDir'), style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'RX',
                            child: Tooltip(
                              message: i18n.t('rxOnly'),
                              waitDuration: const Duration(milliseconds: 150),
                              child: Text(i18n.t('rxOnly'), style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'TX',
                            child: Tooltip(
                              message: i18n.t('txOnly'),
                              waitDuration: const Duration(milliseconds: 150),
                              child: Text(i18n.t('txOnly'), style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _filterDirection = v ?? 'ALL'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Search Box (width: 180)
                  SizedBox(
                    width: 180,
                    height: 32,
                    child: TextField(
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: i18n.t('searchHexHint'),
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onChanged: (v) => setState(() => _searchKeyword = v.trim()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Auto scroll
                  SizedBox(
                    height: 32,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _autoScroll,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) => setState(() => _autoScroll = v ?? true),
                        ),
                        const SizedBox(width: 4),
                        Text(i18n.t('autoScroll'), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(
                      TrafficLogger.instance.isPaused ? Icons.play_arrow : Icons.pause,
                      color: TrafficLogger.instance.isPaused ? Colors.green : Colors.orange,
                    ),
                    tooltip: TrafficLogger.instance.isPaused ? i18n.t('resumeLog') : i18n.t('pauseLog'),
                    onPressed: () => setState(() => TrafficLogger.instance.isPaused = !TrafficLogger.instance.isPaused),
                  ),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: i18n.t('clearLog'),
                    onPressed: () => setState(() => TrafficLogger.instance.clear()),
                  ),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.copy_all),
                    tooltip: i18n.t('copyLogText'),
                    onPressed: () {
                      final text = TrafficLogger.instance.exportToText();
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(i18n.t('copiedClipboard'))),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Traffic Table Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Tooltip(
                    message: '# (Index)',
                    waitDuration: const Duration(milliseconds: 200),
                    child: const Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Tooltip(
                    message: 'Time (HH:mm:ss.ms)',
                    waitDuration: const Duration(milliseconds: 200),
                    child: const Text('Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Tooltip(
                    message: 'Direction (RX/TX)',
                    waitDuration: const Duration(milliseconds: 200),
                    child: const Text('Dir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 55,
                  child: Tooltip(
                    message: 'Unit ID / Slave ID',
                    waitDuration: const Duration(milliseconds: 200),
                    child: const Text('Slave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                SizedBox(
                  width: 75,
                  child: Tooltip(
                    message: 'Function Code (FC)',
                    waitDuration: const Duration(milliseconds: 200),
                    child: const Text('Function', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Tooltip(
                    message: 'Hex Frame Payload',
                    waitDuration: const Duration(milliseconds: 200),
                    child: const Text('Hex Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Tooltip(
                    message: 'Decoded Packet Description',
                    waitDuration: const Duration(milliseconds: 200),
                    child: const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 28),
              ],
            ),
          ),
          // Traffic List View
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync_alt, size: 48, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            i18n.t('emptyTrafficHint'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.outline),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      Color badgeColor;
                      switch (item.direction) {
                        case TrafficDirection.rx:
                          badgeColor = Colors.green;
                          break;
                        case TrafficDirection.tx:
                          badgeColor = Colors.blue;
                          break;
                        case TrafficDirection.err:
                          badgeColor = Colors.red;
                          break;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 50,
                                    child: Text(
                                      '#${item.index}',
                                      style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      item.timeStr,
                                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: badgeColor.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      item.direction.name.toUpperCase(),
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 55,
                                    child: Text(
                                      'ID:${item.unitId}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 75,
                                    child: Text(
                                      'FC:0x${item.functionCode.toRadixString(16).padLeft(2, "0").toUpperCase()}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: Tooltip(
                                message: item.hexString,
                                waitDuration: const Duration(milliseconds: 200),
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    item.hexString,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: Tooltip(
                                message: item.description,
                                waitDuration: const Duration(milliseconds: 200),
                                child: Text(
                                  item.description,
                                  style: TextStyle(
                                    color: item.direction == TrafficDirection.err ? Colors.red : null,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: AppI18n.instance.t('copyHex'),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: item.hexString));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${AppI18n.instance.t('copiedClipboard')}: ${item.hexString}'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
