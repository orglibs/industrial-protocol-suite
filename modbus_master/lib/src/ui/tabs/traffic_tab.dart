import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/traffic_logger.dart';

class TrafficTab extends StatefulWidget {
  const TrafficTab({super.key});

  @override
  State<TrafficTab> createState() => _TrafficTabState();
}

class _TrafficTabState extends State<TrafficTab> {
  final TrafficLogger _logger = TrafficLogger.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  TrafficLogEntry? _selectedEntry;
  bool _isPaused = false;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _logger.stream.listen((_) {
      if (mounted && !_isPaused) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allEntries = _logger.entries.reversed.toList();
    final filtered = _filter.isEmpty
        ? allEntries
        : allEntries.where((e) {
            final f = _filter.toLowerCase();
            return e.summary.toLowerCase().contains(f) ||
                e.rawHex.toLowerCase().contains(f) ||
                e.sourceOrTarget.toLowerCase().contains(f) ||
                e.protocolDetail.toLowerCase().contains(f);
          }).toList();

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
              // Pause / Resume
              IconButton.filledTonal(
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                tooltip: _isPaused ? AppI18n.instance.t('resumeLog') : AppI18n.instance.t('pauseLog'),
                onPressed: () => setState(() => _isPaused = !_isPaused),
              ),
              const SizedBox(width: 8),
              // Clear
              IconButton.outlined(
                icon: const Icon(Icons.delete_sweep),
                tooltip: AppI18n.instance.t('clearLog'),
                onPressed: () {
                  setState(() {
                    _logger.clear();
                    _selectedEntry = null;
                  });
                },
              ),
              const SizedBox(width: 16),
              // Search box
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: AppI18n.instance.t('searchHexHint'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _filter = v.trim()),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${filtered.length} ${AppI18n.instance.t('frames')}',
                style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
              ),
            ],
          ),
        ),

        // Split view: Top Table, Bottom Inspector
        Expanded(
          flex: 6,
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_alt, size: 48, color: theme.colorScheme.outline),
                      const SizedBox(height: 12),
                      Text(AppI18n.instance.t('emptyTrafficHint')),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final item = filtered[idx];
                    final isSelected = item == _selectedEntry;
                    final isTx = item.direction == TrafficDirection.tx;
                    final badgeColor = item.isError ? Colors.red : (isTx ? Colors.blue : Colors.green);

                    return InkWell(
                      onTap: () => setState(() => _selectedEntry = item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                              : (idx % 2 == 0 ? Colors.transparent : theme.colorScheme.surfaceVariant.withOpacity(0.08)),
                          border: Border(bottom: BorderSide(color: theme.dividerColor)),
                        ),
                        child: Row(
                          children: [
                            // Direction badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: badgeColor.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.isError
                                        ? Icons.error_outline
                                        : (isTx ? Icons.arrow_upward : Icons.arrow_downward),
                                    size: 12,
                                    color: badgeColor,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    item.directionLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: badgeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Timestamp
                            Text(
                              item.timestampStr,
                              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: theme.colorScheme.outline),
                            ),
                            const SizedBox(width: 12),
                            // Target
                            SizedBox(
                              width: 140,
                              child: Text(
                                item.sourceOrTarget,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Summary
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.summary,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: item.isError ? Colors.red : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Hex preview
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.rawHex,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        const Divider(height: 1),

        // Bottom Details Panel
        Expanded(
          flex: 4,
          child: _selectedEntry == null
              ? Container(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
                  alignment: Alignment.center,
                  child: Text(AppI18n.instance.t('emptyTrafficHint'), style: TextStyle(color: theme.colorScheme.outline)),
                )
              : _buildInspector(theme, _selectedEntry!),
        ),
      ],
    );
  }

  Widget _buildInspector(ThemeData theme, TrafficLogEntry entry) {
    return Container(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_object, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '[${entry.directionLabel}] - ${entry.summary}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: Text(AppI18n.instance.t('copyHex')),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: entry.rawHex));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppI18n.instance.t('copiedClipboard')), duration: const Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.protocolDetail}',
                    style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color),
                  ),
                  const SizedBox(height: 8),
                  Text(AppI18n.instance.t('inputHex'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      entry.rawHex.isEmpty ? '<Empty>' : entry.rawHex,
                      style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 13),
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
}
