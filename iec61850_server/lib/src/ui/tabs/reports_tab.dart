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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rcbs = widget.manager.engine.reportControls;

    if (rcbs.isEmpty) {
      return const Center(
        child: Text('当前 SCL 模型未配置报告控制块 (BRCB / URCB)', style: TextStyle(color: Colors.grey)),
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
                                child: Text(
                                  rcb.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                              Text('缓冲: ${rcb.bufTime}ms', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(width: 12),
                              Text('周期: ${rcb.intgPd}ms', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const Spacer(),
                              Text('已发: ${rcb.sqNum}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
              ? const Center(child: Text('请在左侧选择一个报告控制块', style: TextStyle(color: Colors.grey)))
              : _buildRcbDetails(_selectedRcb!),
        ),
      ],
    );
  }

  Widget _buildRcbDetails(SclReportControl rcb) {
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
                  rcb.buffered ? '缓存报告控制块 (BRCB)' : '非缓存报告控制块 (URCB)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rcb.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.flash_on, size: 16),
                label: const Text('触发总召唤 (GI)'),
                onPressed: () {
                  widget.manager.engine.triggerReport(rcb, isGI: true);
                  setState(() {});
                  widget.onDataChanged();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已触发报告控制块 ${rcb.name} 的总召唤 (GI) 上送！'),
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
                  const Text('报告控制参数 (Report Parameters)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _infoRow('报告标识 (RptID)', rcb.rptId),
                  _infoRow('关联数据集 (DataSet)', rcb.datSet),
                  _infoRow('配置版本 (ConfRev)', rcb.confRev.toString()),
                  _infoRow('缓冲等待时间 (BufTime)', '${rcb.bufTime} ms'),
                  _infoRow('完整性周期 (IntgPd)', '${rcb.intgPd} ms'),
                  _infoRow('最大支持客户端', '${rcb.maxClients}'),
                  const Divider(height: 20),
                  const Text('触发选项 (Trigger Options):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _tagChip('数据改变 (dchg)', rcb.trgOps.dataChange),
                      _tagChip('品质改变 (qchg)', rcb.trgOps.qualityChange),
                      _tagChip('数据刷新 (dupd)', rcb.trgOps.dataUpdate),
                      _tagChip('周期完整性 (period)', rcb.trgOps.integrity),
                      _tagChip('总召唤 (gi)', rcb.trgOps.generalInterrogation),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('可选字段 (Optional Fields):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _tagChip('序号 (SeqNum)', rcb.optFields.sequenceNumber),
                      _tagChip('时间戳 (Timestamp)', rcb.optFields.reportTimestamp),
                      _tagChip('原因码 (ReasonCode)', rcb.optFields.reasonCode),
                      _tagChip('数据集名 (DataSet)', rcb.optFields.dataSet),
                      _tagChip('条目标识 (EntryID)', rcb.optFields.entryId),
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
                      Text('关联数据集成员 [${ds.name}] (${ds.entries.length} 项)',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (ds.entries.isEmpty)
                    const Text('该数据集中无 FCDA 条目', style: TextStyle(color: Colors.grey))
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
