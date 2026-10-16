import 'package:flutter/material.dart';
import '../../client/traffic_logger.dart';

class TrafficTab extends StatefulWidget {
  const TrafficTab({super.key});

  @override
  State<TrafficTab> createState() => _TrafficTabState();
}

class _TrafficTabState extends State<TrafficTab> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _directionFilter = 'ALL';
  String _searchQuery = '';
  TrafficEntry? _selectedEntry;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeAutoScroll() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<TrafficEntry>(
      stream: TrafficLogger.instance.stream,
      builder: (context, snapshot) {
        _maybeAutoScroll();

        final allEntries = TrafficLogger.instance.entries;
        final filtered = allEntries.where((e) {
          if (_directionFilter == 'RX' && e.direction != TrafficDirection.rx) return false;
          if (_directionFilter == 'TX' && e.direction != TrafficDirection.tx) return false;
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            return e.rawHex.toLowerCase().contains(q) ||
                e.summary.toLowerCase().contains(q) ||
                e.remoteAddress.toLowerCase().contains(q);
          }
          return true;
        }).toList();

        final rxCount = allEntries.where((e) => e.direction == TrafficDirection.rx).length;
        final txCount = allEntries.where((e) => e.direction == TrafficDirection.tx).length;

        return Column(
          children: [
            // Top Toolbar matching modbus_slave style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Text('总报文: ${allEntries.length} (收: $rxCount, 发: $txCount)',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Wrap(
                    spacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('全部'),
                        selected: _directionFilter == 'ALL',
                        onSelected: (_) => setState(() => _directionFilter = 'ALL'),
                      ),
                      ChoiceChip(
                        label: const Text('接收 [RX]'),
                        selected: _directionFilter == 'RX',
                        onSelected: (_) => setState(() => _directionFilter = 'RX'),
                      ),
                      ChoiceChip(
                        label: const Text('发送 [TX]'),
                        selected: _directionFilter == 'TX',
                        onSelected: (_) => setState(() => _directionFilter = 'TX'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _autoScroll,
                        onChanged: (v) => setState(() => _autoScroll = v ?? true),
                      ),
                      const Text('自动滚动', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '过滤十六进制或摘要...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('清空记录'),
                    onPressed: () {
                      setState(() {
                        TrafficLogger.instance.clear();
                        _selectedEntry = null;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Main Content: List + Detail Inspector
            Expanded(
              child: Row(
                children: [
                  // Traffic List
                  Expanded(
                    flex: 6,
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync_alt, size: 48, color: theme.colorScheme.outline),
                                const SizedBox(height: 12),
                                const Text('暂无通信报文记录'),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = filtered[index];
                              final isSelected = _selectedEntry?.id == entry.id;
                              final isRx = entry.direction == TrafficDirection.rx;
                              final timeStr = entry.timestamp.toIso8601String().substring(11, 23);
                              final badgeColor = isRx ? Colors.blue : Colors.green;

                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: badgeColor.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    isRx ? 'RX 收' : 'TX 发',
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      timeStr,
                                      style: TextStyle(fontSize: 12, color: theme.colorScheme.outline, fontFamily: 'monospace'),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(entry.remoteAddress, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        entry.summary,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  entry.rawHex,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                                  ),
                                ),
                                onTap: () => setState(() => _selectedEntry = entry),
                              );
                            },
                          ),
                  ),

                  // Detail Inspector Panel
                  if (_selectedEntry != null) ...[
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 4,
                      child: Container(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('报文详细剖析 (Frame Detail)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () => setState(() => _selectedEntry = null),
                                ),
                              ],
                            ),
                            const Divider(),
                            Text(
                              '原始报文十六进制:',
                              style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.outline, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              _selectedEntry!.rawHex,
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            const Text('协议字段分解:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView(
                                children: _selectedEntry!.parsed.fields.map((f) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: theme.cardColor,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: theme.dividerColor),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              if (f.hex.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                  child: Text(
                                                    '0x${f.hex}',
                                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            f.value,
                                            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                          ),
                                          if (f.description.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              f.description,
                                              style: TextStyle(color: theme.colorScheme.outline, fontSize: 11),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
