import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _filterConnection = '全部连接';
  String _filterDirection = '全部方向';
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
      if (_filterConnection != '全部连接' && e.connectionName != _filterConnection) {
        return false;
      }
      if (_filterDirection == '仅RX接收' && e.direction != TrafficDirection.rx) {
        return false;
      }
      if (_filterDirection == '仅TX发送' && e.direction != TrafficDirection.tx) {
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
    final allEntries = TrafficLogger.instance.entries;
    final filtered = _filteredEntries();

    // Distinct connections for filter
    final connNames = <String>{'全部连接'};
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
            child: Row(
              children: [
                DropdownButton<String>(
                  value: connNames.contains(_filterConnection) ? _filterConnection : '全部连接',
                  underline: const SizedBox(),
                  items: connNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _filterConnection = v ?? '全部连接'),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filterDirection,
                  underline: const SizedBox(),
                  items: const ['全部方向', '仅RX接收', '仅TX发送']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setState(() => _filterDirection = v ?? '全部方向'),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '搜索 Hex/说明...',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _searchKeyword = v.trim()),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Checkbox(
                      value: _autoScroll,
                      onChanged: (v) => setState(() => _autoScroll = v ?? true),
                    ),
                    const Text('自动滚屏'),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        TrafficLogger.instance.isPaused ? Icons.play_arrow : Icons.pause,
                        color: TrafficLogger.instance.isPaused ? Colors.green : Colors.orange,
                      ),
                      tooltip: TrafficLogger.instance.isPaused ? '恢复监听记录' : '暂停记录',
                      onPressed: () => setState(() => TrafficLogger.instance.isPaused = !TrafficLogger.instance.isPaused),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined),
                      tooltip: '清空报文记录',
                      onPressed: () => setState(() => TrafficLogger.instance.clear()),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_all),
                      tooltip: '复制所有报文为文本',
                      onPressed: () {
                        final text = TrafficLogger.instance.exportToText();
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制所有报文记录到剪贴板')),
                        );
                      },
                    ),
                  ],
                ),
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
                        const Text('暂无通信报文数据，启动服务端后外部主站发起请求时在此实时展示'),
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
                              width: 60,
                              child: Text(
                                'ID:${item.unitId}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                'FC:0x${item.functionCode.toRadixString(16).padLeft(2, "0").toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.hexString,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: Text(
                                item.description,
                                style: TextStyle(
                                  color: item.direction == TrafficDirection.err ? Colors.red : null,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: '复制十六进制报文',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: item.hexString));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已复制: ${item.hexString}'),
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
