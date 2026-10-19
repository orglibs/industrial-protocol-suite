import '../../i18n/app_i18n.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    final path = '$home/iec61850_client_traffic_${DateTime.now().millisecondsSinceEpoch}.log';
    final f = File(path);
    f.writeAsStringSync(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${AppI18n.instance.t("trafficExported")} $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allEntries = _logger.entries;

    final filtered = allEntries.where((e) {
      if (_directionFilter == 'RX' && e.direction != TrafficDirection.rx) return false;
      if (_directionFilter == 'TX' && e.direction != TrafficDirection.tx) return false;
      if (_protocolFilter != 'ALL' && !e.protocol.toUpperCase().contains(_protocolFilter)) return false;
      if (_searchText.isNotEmpty) {
        return e.service.toLowerCase().contains(_searchText) ||
            e.summary.toLowerCase().contains(_searchText) ||
            e.endpoint.toLowerCase().contains(_searchText);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252526) : const Color(0xFFF3F3F3),
            border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  height: 32,
                  child: Tooltip(
                    message: i18n.t('searchTrafficHint'),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: i18n.t('searchTrafficHint'),
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Protocol Filter
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[350]!),
                  ),
                  child: Tooltip(
                    message: 'Protocol: $_protocolFilter',
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _protocolFilter,
                        isDense: true,
                        items: [
                          DropdownMenuItem(value: 'ALL', child: Text(i18n.t('protoAll'), style: const TextStyle(fontSize: 12))),
                          const DropdownMenuItem(value: 'COTP', child: Text('COTP (ISO 8073)', style: TextStyle(fontSize: 12))),
                          const DropdownMenuItem(value: 'ACSE', child: Text('ACSE (ISO 8650)', style: TextStyle(fontSize: 12))),
                          const DropdownMenuItem(value: 'MMS', child: Text('MMS (ISO 9506)', style: TextStyle(fontSize: 12))),
                          const DropdownMenuItem(value: 'GOOSE', child: Text('GOOSE (8-1)', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _protocolFilter = val);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Direction Filter
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[350]!),
                  ),
                  child: Tooltip(
                    message: 'Direction: $_directionFilter',
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _directionFilter,
                        isDense: true,
                        items: [
                          DropdownMenuItem(value: 'ALL', child: Text(i18n.t('dirAll'), style: const TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'RX', child: Text(i18n.t('dirRxDesc'), style: const TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'TX', child: Text(i18n.t('dirTxDesc'), style: const TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _directionFilter = val);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Auto-scroll toggle
                Tooltip(
                  message: i18n.t('autoScroll'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _autoScroll,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) => setState(() => _autoScroll = val ?? true),
                      ),
                      Text(i18n.t('autoScroll'), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Logging Enable Toggle
                IconButton(
                  icon: Icon(
                    _logger.isLoggingEnabled ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    color: _logger.isLoggingEnabled ? Colors.green : Colors.grey,
                  ),
                  tooltip: _logger.isLoggingEnabled ? i18n.t('pauseCapture') : i18n.t('resumeCapture'),
                  constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _logger.isLoggingEnabled = !_logger.isLoggingEnabled;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: i18n.t('exportTraffic'),
                  constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                  padding: EdgeInsets.zero,
                  onPressed: _exportLog,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: i18n.t('clearLog'),
                  constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _logger.clear();
                      _selectedEntry = null;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        // Traffic Table & Hex Inspector
        Expanded(
          child: Row(
            children: [
              // Left Traffic Packet List
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                  ),
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        height: 32,
                        color: isDark ? Colors.grey[900] : Colors.grey[200],
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            const SizedBox(width: 50, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            SizedBox(width: 85, child: Text(i18n.t('timeLabel'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            SizedBox(width: 50, child: Text(i18n.t('directionLabel'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            SizedBox(width: 65, child: Text(i18n.t('protocolLabel'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            SizedBox(width: 140, child: Text(i18n.t('serviceTypeLabel'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Expanded(child: Text(i18n.t('packetSummaryLabel'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            SizedBox(width: 60, child: Text(i18n.t('sizeLabel'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          ],
                        ),
                      ),
                      // Table Rows
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(child: Text(i18n.t('noMatchingPackets'), style: const TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final e = filtered[index];
                                  final isSelected = _selectedEntry?.id == e.id;
                                  final timeStr = DateFormat('HH:mm:ss.SSS').format(e.timestamp);

                                  return InkWell(
                                    onTap: () => setState(() => _selectedEntry = e),
                                    child: Container(
                                      height: 28,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                          : (index % 2 == 1
                                              ? (isDark ? Colors.grey[900]!.withOpacity(0.4) : Colors.grey[50])
                                              : Colors.transparent),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 50,
                                            child: Text(
                                              '${e.id}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                color: isDark ? Colors.grey[500] : Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 85,
                                            child: Text(timeStr, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                                          ),
                                          SizedBox(
                                            width: 50,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: e.direction == TrafficDirection.rx
                                                    ? Colors.green.withOpacity(0.2)
                                                    : Colors.blue.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                e.direction == TrafficDirection.rx ? 'RX' : 'TX',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: e.direction == TrafficDirection.rx ? Colors.green : Colors.blueAccent,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 65,
                                            child: Text(
                                              e.protocol,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: _getProtocolColor(e.protocol),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 140,
                                            child: Text(
                                              e.service,
                                              style: const TextStyle(fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              e.summary,
                                              style: const TextStyle(fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 60,
                                            child: Text(
                                              '${e.rawBytes.length} B',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right Hex & Details Inspector
              Expanded(
                flex: 5,
                child: _selectedEntry == null
                    ? Center(
                        child: Text(
                          i18n.t('clickTrafficHintClient'),
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.code, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '#${_selectedEntry!.id} ${_selectedEntry!.protocol} - ${_selectedEntry!.service}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const Spacer(),
                                Text(
                                  '${_selectedEntry!.rawBytes.length} ${i18n.t("bytesUnit")}',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_selectedEntry!.endpoint}  |  ${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(_selectedEntry!.timestamp)}',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            if (_selectedEntry!.details.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _selectedEntry!.details,
                                style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
                              ),
                            ],
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            // Hex Dump Viewer
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF141414) : const Color(0xFFEFEFEF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? Colors.grey[850]! : Colors.grey[300]!),
                                ),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    _selectedEntry!.hexDump.isEmpty ? i18n.t('emptyPayloadClient') : _selectedEntry!.hexDump,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getProtocolColor(String protocol) {
    switch (protocol.toUpperCase()) {
      case 'COTP':
        return Colors.amber[700]!;
      case 'ACSE':
        return Colors.orange[700]!;
      case 'MMS':
        return Colors.blue[600]!;
      case 'GOOSE':
        return Colors.teal[600]!;
      default:
        return Colors.grey;
    }
  }
}
