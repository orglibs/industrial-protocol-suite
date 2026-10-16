import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/traffic_logger.dart';

class TrafficTab extends StatefulWidget {
  const TrafficTab({super.key});

  @override
  State<TrafficTab> createState() => _TrafficTabState();
}

class _TrafficTabState extends State<TrafficTab> {
  final TrafficLogger _logger = TrafficLogger.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  TrafficEntry? _selectedEntry;
  bool _autoScroll = true;
  String _protocolFilter = 'ALL';
  String _directionFilter = 'ALL';
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _logger.addListener(_onNewTraffic);
    _searchCtrl.addListener(() {
      setState(() {
        _searchText = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _logger.removeListener(_onNewTraffic);
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onNewTraffic() {
    if (!mounted) return;
    setState(() {});
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _exportLog() {
    final text = _logger.exportToText();
    final home = Platform.environment['HOME'] ?? '.';
    final path = '$home/iec61850_traffic_${DateTime.now().millisecondsSinceEpoch}.log';
    final f = File(path);
    f.writeAsStringSync(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('报文日志已成功导出至：$path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allEntries = _logger.entries;

    final filtered = allEntries.where((e) {
      if (_directionFilter == 'RX' && e.direction != TrafficDirection.rx) return false;
      if (_directionFilter == 'TX' && e.direction != TrafficDirection.tx) return false;
      if (_protocolFilter != 'ALL' && !e.protocol.toUpperCase().contains(_protocolFilter)) return false;
      if (_searchText.isNotEmpty) {
        return e.service.toLowerCase().contains(_searchText) ||
            e.summary.toLowerCase().contains(_searchText) ||
            e.clientEndpoint.toLowerCase().contains(_searchText);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '搜索报文内容...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Protocol Dropdown
              DropdownButton<String>(
                value: _protocolFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('协议: 全部')),
                  DropdownMenuItem(value: 'MMS', child: Text('协议: MMS')),
                  DropdownMenuItem(value: 'GOOSE', child: Text('协议: GOOSE')),
                  DropdownMenuItem(value: 'COTP', child: Text('协议: COTP')),
                  DropdownMenuItem(value: 'ACSE', child: Text('协议: ACSE')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _protocolFilter = val);
                },
              ),
              const SizedBox(width: 12),
              // Direction Dropdown
              DropdownButton<String>(
                value: _directionFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('方向: 全部 (RX/TX)')),
                  DropdownMenuItem(value: 'RX', child: Text('方向: 仅接收 (RX)')),
                  DropdownMenuItem(value: 'TX', child: Text('方向: 仅发送 (TX)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _directionFilter = val);
                },
              ),
              const Spacer(),
              // Auto-Scroll Toggle
              FilterChip(
                label: const Text('自动滚屏'),
                selected: _autoScroll,
                onSelected: (val) => setState(() => _autoScroll = val),
              ),
              const SizedBox(width: 8),
              // Capture Pause/Resume
              IconButton(
                icon: Icon(_logger.isLoggingEnabled ? Icons.pause_circle : Icons.play_circle),
                color: _logger.isLoggingEnabled ? Colors.orange : Colors.green,
                tooltip: _logger.isLoggingEnabled ? '暂停抓包' : '恢复抓包',
                onPressed: () {
                  setState(() {
                    _logger.isLoggingEnabled = !_logger.isLoggingEnabled;
                  });
                },
              ),
              // Clear Log
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '清空报文',
                onPressed: () {
                  _logger.clear();
                  setState(() => _selectedEntry = null);
                },
              ),
              // Export Log
              IconButton(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: '导出报文日志',
                onPressed: _exportLog,
              ),
            ],
          ),
        ),

        // Content Area: Split View
        Expanded(
          child: Row(
            children: [
              // Left Column: Packet List
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                  ),
                  child: filtered.isEmpty
                      ? const Center(child: Text('暂无报文数据', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            final isSelected = _selectedEntry?.id == entry.id;

                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                              leading: _dirBadge(entry.direction),
                              title: Row(
                                children: [
                                  _protoBadge(entry.protocol),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      entry.service,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    entry.timestamp.toIso8601String().substring(11, 23),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${entry.clientEndpoint}  |  ${entry.summary}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedEntry = entry;
                                });
                              },
                            );
                          },
                        ),
                ),
              ),

              // Right Column: Packet Details & Hex Dump
              Expanded(
                flex: 6,
                child: _selectedEntry == null
                    ? const Center(child: Text('在左侧列表中点击报文查看十六进制与结构解析', style: TextStyle(color: Colors.grey)))
                    : _buildPacketDetails(_selectedEntry!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPacketDetails(TrafficEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _dirBadge(entry.direction),
              const SizedBox(width: 8),
              _protoBadge(entry.protocol),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.service,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${entry.rawBytes.length} 字节',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '时间: ${entry.timestamp.toIso8601String()}  |  对端地址: ${entry.clientEndpoint}',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('报文摘要与字段解析', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  SelectableText(entry.summary, style: const TextStyle(fontSize: 13)),
                  if (entry.details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SelectableText(entry.details, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Hex Dump Card (Wireshark-Style)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.terminal, size: 16),
                      SizedBox(width: 6),
                      Text('原始十六进制转储 (Hex & ASCII Dump)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      entry.rawBytes.isEmpty ? '(空载荷)' : entry.hexDump,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dirBadge(TrafficDirection dir) {
    final isRx = dir == TrafficDirection.rx;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isRx ? Colors.blue : Colors.orange[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isRx ? 'RX' : 'TX',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _protoBadge(String proto) {
    Color bg = Colors.blueGrey;
    if (proto.contains('MMS')) bg = Colors.indigo;
    if (proto.contains('GOOSE')) bg = Colors.teal;
    if (proto.contains('COTP')) bg = Colors.brown;
    if (proto.contains('ACSE')) bg = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        proto,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
