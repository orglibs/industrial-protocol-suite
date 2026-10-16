import 'package:flutter/material.dart';
import '../../protocol/goose_publisher.dart';
import '../../protocol/iec61850_server_manager.dart';

class GooseTab extends StatefulWidget {
  final Iec61850ServerManager manager;
  final VoidCallback onDataChanged;

  const GooseTab({
    super.key,
    required this.manager,
    required this.onDataChanged,
  });

  @override
  State<GooseTab> createState() => _GooseTabState();
}

class _GooseTabState extends State<GooseTab> {
  GoosePublisherItem? _selectedItem;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = widget.manager.gooseService.items;
    final svControls = widget.manager.engine.scl?.svControls ?? [];

    if (items.isEmpty && svControls.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.send_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('当前 SCL 模型未配置 GOOSE 控制块 (GSEControl) 或采样值 (SampledValueControl)',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.auto_stories),
              label: const Text('加载内置 GOOSE 保护示例 (server_example_goose.icd)'),
              onPressed: () {
                // SCL tools tab can load this template
                DefaultTabController.of(context).animateTo(6);
              },
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Left Column: List of GOOSE Controls
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: items.length,
              separatorBuilder: (_, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = _selectedItem?.control.name == item.control.name;

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
                    onTap: () => setState(() => _selectedItem = item),
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
                                  color: Colors.teal[700],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'GOOSE GCB',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.control.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              Switch(
                                value: item.isPublishing,
                                onChanged: (val) {
                                  widget.manager.gooseService.toggleItem(item);
                                  setState(() {});
                                  widget.onDataChanged();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'APPID: 0x${item.control.appId.toRadixString(16).padLeft(4, '0')}  |  DataSet: ${item.control.datSet}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('stNum: ${item.stNum}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                              const SizedBox(width: 12),
                              Text('sqNum: ${item.sqNum}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const Spacer(),
                              Text('总发送: ${item.totalPacketsSent}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

        // Right Column: Details & Inspector
        Expanded(
          flex: 6,
          child: _selectedItem == null
              ? const Center(child: Text('在左侧选择一个 GOOSE 控制块查看报文及状态', style: TextStyle(color: Colors.grey)))
              : _buildItemDetails(_selectedItem!),
        ),
      ],
    );
  }

  Widget _buildItemDetails(GoosePublisherItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal[700],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('GOOSE 控制块', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.control.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.bolt, size: 16),
                label: const Text('模拟状态变位 (stNum++)'),
                onPressed: () {
                  widget.manager.gooseService.triggerItemEvent(item);
                  setState(() {});
                  widget.onDataChanged();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已触发 GOOSE ${item.control.name} 变位事件！stNum=${item.stNum}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Parameters Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GOOSE 发送参数 (IEC 61850-8-1)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _infoRow('GoID / AppID', '0x${item.control.appId.toRadixString(16).padLeft(4, '0')} (${item.control.goId})'),
                  _infoRow('组播目标 MAC (dstAddress)', item.control.dstAddress),
                  _infoRow('数据集名称 (datSet)', item.control.datSet),
                  _infoRow('配置版本 (ConfRev)', item.control.confRev.toString()),
                  _infoRow('最小重传间隔 (minTime)', '${item.control.minTime} ms'),
                  _infoRow('心跳保活间隔 (maxTime)', '${item.control.maxTime} ms'),
                  _infoRow('当前发送周期', '${item.currentIntervalMs} ms'),
                  _infoRow('状态编号 (stNum)', item.stNum.toString()),
                  _infoRow('序号 (sqNum)', item.sqNum.toString()),
                  _infoRow('累计发布包数', item.totalPacketsSent.toString()),
                  if (item.lastPublishTime != null)
                    _infoRow('最近发布时间', item.lastPublishTime!.toIso8601String().substring(11, 23)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Last Packet Hex Dump Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.code, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '最新发送 GOOSE 原始报文帧 (${item.lastPacket?.length ?? 0} 字节)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (item.lastPacket == null)
                    const Text('尚未发送报文，请先开启发布', style: TextStyle(color: Colors.grey))
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SelectableText(
                        _hexDump(item.lastPacket!),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 190,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _hexDump(List<int> bytes) {
    final sb = StringBuffer();
    for (int i = 0; i < bytes.length; i += 16) {
      final chunkEnd = (i + 16 < bytes.length) ? i + 16 : bytes.length;
      final chunk = bytes.sublist(i, chunkEnd);
      final hexPart = chunk.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      final asciiPart = chunk.map((b) => (b >= 32 && b <= 126) ? String.fromCharCode(b) : '.').join('');
      sb.writeln('${i.toRadixString(16).padLeft(4, '0')}:  ${hexPart.padRight(48)}  |$asciiPart|');
    }
    return sb.toString();
  }
}
