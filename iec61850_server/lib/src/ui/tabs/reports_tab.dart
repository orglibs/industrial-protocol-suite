import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../../models/scl_models.dart';
import '../../protocol/iec61850_server_manager.dart';

class ReportsTab extends StatefulWidget {
  final Iec61850ServerManager manager;
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

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rcbs = widget.manager.engine.reportControls;

    if (rcbs.isEmpty) {
      return Center(
        child: Text(i18n.t('noRcbConfigured'), style: const TextStyle(color: Colors.grey)),
      );
    }

    return Row(
      children: [
        // Left Column: List of Report Controls
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: rcbs.length,
              separatorBuilder: (_, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final rcb = rcbs[index];
                final isSelected = _selectedRcb?.name == rcb.name;

                return Card(
                  elevation: isSelected ? 3 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isSelected
                        ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                        : BorderSide.none,
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
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rcb.displayName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (rcb.displayName != rcb.name)
                                      Text(
                                        rcb.name,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: rcb.rptEna,
                                onChanged: (val) {
                                  setState(() {
                                    rcb.rptEna = val;
                                  });
                                  widget.onDataChanged();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'DataSet: ${rcb.datSet}  |  RptID: ${rcb.rptId}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('${i18n.t("bufferLabel")}: ${rcb.bufTime}ms', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(width: 12),
                              Text('${i18n.t("periodLabel")}: ${rcb.intgPd}ms', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const Spacer(),
                              Text('${i18n.t("sentLabel")}: ${rcb.sqNum}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
        ),

        // Right Column: Details & Actions for selected RCB
        Expanded(
          flex: 6,
          child: _selectedRcb == null
              ? Center(child: Text(i18n.t('selectRcbHint'), style: const TextStyle(color: Colors.grey)))
              : _buildRcbDetails(_selectedRcb!),
        ),
      ],
    );
  }

  Widget _buildRcbDetails(SclReportControl rcb) {
    final i18n = AppI18n.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ds = widget.manager.engine.dataSets.firstWhere(
      (d) => d.name == rcb.datSet,
      orElse: () => SclDataSet(name: rcb.datSet),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rcb.buffered ? Colors.indigo : Colors.deepPurple,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rcb.buffered ? i18n.t('brcbTitle') : i18n.t('urcbTitle'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rcb.displayName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (rcb.displayName != rcb.name)
                      Text(
                        rcb.name,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.flash_on, size: 16),
                label: Text(i18n.t('triggerGi')),
                onPressed: () {
                  widget.manager.engine.triggerReport(rcb, isGI: true);
                  setState(() {});
                  widget.onDataChanged();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${i18n.t("triggerGiSuccess")} (${rcb.name})'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Control Parameters Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i18n.t('rcbParamsTitle'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _infoRow(i18n.t('rptIdLabel'), rcb.rptId),
                  _infoRow(i18n.t('relDataSet'), rcb.datSet),
                  _infoRow(i18n.t('confRevLabel'), rcb.confRev.toString()),
                  _infoRow(i18n.t('bufTimeLabel'), '${rcb.bufTime} ms'),
                  _infoRow(i18n.t('intgPdLabel'), '${rcb.intgPd} ms'),
                  _infoRow(i18n.t('maxClientsLabel'), '${rcb.maxClients}'),
                  const Divider(height: 20),
                  Text(i18n.t('triggerOptions'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _tagChip(i18n.t('trgDchg'), rcb.trgOps.dataChange),
                      _tagChip(i18n.t('trgQchg'), rcb.trgOps.qualityChange),
                      _tagChip(i18n.t('trgDupd'), rcb.trgOps.dataUpdate),
                      _tagChip(i18n.t('trgIntegrity'), rcb.trgOps.integrity),
                      _tagChip(i18n.t('trgGi'), rcb.trgOps.generalInterrogation),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(i18n.t('optFields'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _tagChip(i18n.t('optSeqNum'), rcb.optFields.sequenceNumber),
                      _tagChip(i18n.t('optTimestamp'), rcb.optFields.reportTimestamp),
                      _tagChip(i18n.t('optReasonCode'), rcb.optFields.reasonCode),
                      _tagChip(i18n.t('optDataSet'), rcb.optFields.dataSet),
                      _tagChip(i18n.t('optEntryId'), rcb.optFields.entryId),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // DataSet Member Variables Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dataset, size: 18),
                      const SizedBox(width: 8),
                      Text('${i18n.t("relDataSetMembers")} [${ds.displayName}] (${ds.entries.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (ds.entries.isEmpty)
                    Text(i18n.t('noFcdaEntries'), style: const TextStyle(color: Colors.grey))
                  else
                    ...ds.entries.map((fcda) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(fcda.fc.code,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${fcda.ldInst}/${fcda.fullLnName}.${fcda.dataRef}',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String text, bool active) {
    return Chip(
      label: Text(text, style: TextStyle(fontSize: 11, color: active ? Colors.white : Colors.grey)),
      backgroundColor: active ? Colors.blue[700] : Colors.grey.withOpacity(0.15),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
