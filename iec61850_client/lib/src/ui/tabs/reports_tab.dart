import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/scl_models.dart';
import '../../protocol/iec61850_client_manager.dart';

class ReportsTab extends StatefulWidget {
  final Iec61850ClientManager manager;
  final VoidCallback onDataChanged;

  const ReportsTab({
    super.key,
    required this.manager,
    required this.onDataChanged,
  });

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  SclReportControl? _selectedRcb;
  final TextEditingController _searchController = TextEditingController();
  bool _isOperating = false;

  @override
  void initState() {
    super.initState();
    final engine = widget.manager.activeEngine;
    if (engine != null) {
      engine.onReportReceived = (event) {
        if (mounted) setState(() {});
      };
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;
    final engine = widget.manager.activeEngine;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (engine == null) {
      return Center(
        child: Text(i18n.t('selectConnFirstReports'), style: const TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    final rcbs = engine.reportControls;

    return Row(
      children: [
        // Left Column: List of Report Controls & Actions
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                // Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252526) : const Color(0xFFF3F3F3),
                    border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_unread_outlined, size: 20, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        'BRCB / URCB [${rcbs.length}]',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      if (_isOperating)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: rcbs.isEmpty
                      ? Center(
                          child: Text(
                            i18n.t('noRcbConnHint'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, height: 1.5),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: rcbs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final rcb = rcbs[index];
                            final isSelected = _selectedRcb?.name == rcb.name;

                            return Card(
                              elevation: isSelected ? 3 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: isSelected
                                    ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                                    : BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => setState(() => _selectedRcb = rcb),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: rcb.buffered ? Colors.indigo : Colors.deepPurple,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              rcb.buffered ? 'BRCB' : 'URCB',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              rcb.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Tooltip(
                                            message: rcb.rptEna ? i18n.t('rptEnaActive') : i18n.t('rptEnaInactive'),
                                            child: Switch(
                                              value: rcb.rptEna,
                                              activeColor: Colors.greenAccent,
                                              onChanged: engine.isConnected && !_isOperating
                                                  ? (val) async {
                                                      setState(() => _isOperating = true);
                                                      await engine.configureReport(rcb, rptEna: val);
                                                      setState(() => _isOperating = false);
                                                      widget.onDataChanged();
                                                    }
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'DataSet: ${rcb.datSet.isEmpty ? "(None)" : rcb.datSet}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            'BufTm: ${rcb.bufTime}ms',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'RptID: ${rcb.rptId}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey[500] : Colors.grey[700],
                                            ),
                                          ),
                                          FilledButton.tonalIcon(
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            icon: const Icon(Icons.sync, size: 14),
                                            label: Text(i18n.t('triggerGiClient'), style: const TextStyle(fontSize: 11)),
                                            onPressed: engine.isConnected && !_isOperating
                                                ? () async {
                                                    setState(() => _isOperating = true);
                                                    final ok = await engine.configureReport(rcb, gi: true);
                                                    setState(() => _isOperating = false);
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(ok
                                                              ? AppI18n.instance.tf('giSentSuccess', {'name': rcb.name})
                                                              : AppI18n.instance.t('giSentFailed')),
                                                          duration: const Duration(seconds: 2),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Selected RCB Inspector Details
                if (_selectedRcb != null) _buildSelectedRcbDetails(_selectedRcb!, isDark),
              ],
            ),
          ),
        ),

        // Right Column: Received InformationReport Event Stream
        Expanded(
          flex: 6,
          child: Column(
            children: [
              // Header & Controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252526) : const Color(0xFFF3F3F3),
                  border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 20, color: Colors.orangeAccent),
                    const SizedBox(width: 8),
                    Text(
                      'InformationReport [${engine.reportEvents.length}]',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: i18n.t('clearEventsTooltip'),
                      onPressed: () {
                        setState(() {
                          engine.reportEvents.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: engine.reportEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: isDark ? Colors.grey[700] : Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              i18n.t('noReportEvents'),
                              style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              i18n.t('noReportEventsHint'),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: engine.reportEvents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          // Show newest first
                          final event = engine.reportEvents[engine.reportEvents.length - 1 - index];
                          final timeStr = DateFormat('HH:mm:ss.SSS').format(event.timestamp);

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.orangeAccent,
                                child: Icon(Icons.bolt, size: 16, color: Colors.white),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    event.rcbName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${event.count} items',
                                      style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '$timeStr | DataSet: ${event.dataSetName.isEmpty ? "(Default)" : event.dataSetName}',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        i18n.t('changeDetails'),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      if (event.details.isEmpty)
                                        Text(i18n.t('noDetails'), style: const TextStyle(fontSize: 11, color: Colors.grey))
                                      else
                                        ...event.details.map((d) => Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 2),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.arrow_right, size: 16, color: Colors.tealAccent),
                                                  Expanded(
                                                    child: Text(
                                                      d,
                                                      style: const TextStyle(
                                                        fontFamily: 'monospace',
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedRcbDetails(SclReportControl rcb, bool isDark) {
    final i18n = AppI18n.instance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEBEBEB),
        border: Border(top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.blueAccent),
              const SizedBox(width: 6),
              Text(
                '${rcb.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildBadge(i18n.t('modeLabel'), rcb.buffered ? i18n.t('brcbMode') : i18n.t('urcbMode'), Colors.indigo),
              _buildBadge('ConfRev', '${rcb.confRev}', Colors.blueGrey),
              _buildBadge('BufTime', '${rcb.bufTime} ms', Colors.teal),
              _buildBadge('TrgOps.dchg', '${rcb.trgOps.dataChange}', rcb.trgOps.dataChange ? Colors.green : Colors.grey),
              _buildBadge('TrgOps.qchg', '${rcb.trgOps.qualityChange}', rcb.trgOps.qualityChange ? Colors.green : Colors.grey),
              _buildBadge('TrgOps.intg', '${rcb.trgOps.integrity}', rcb.trgOps.integrity ? Colors.green : Colors.grey),
              _buildBadge('Opt.seq-num', '${rcb.optFields.sequenceNumber}', Colors.purple),
              _buildBadge('Opt.time-stamp', '${rcb.optFields.reportTimestamp}', Colors.purple),
              _buildBadge('Opt.dataset', '${rcb.optFields.dataSet}', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }
}
