import '../../i18n/app_i18n.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../protocol/goose_receiver.dart';
import '../../protocol/iec61850_client_manager.dart';

class GooseTab extends StatefulWidget {
  final Iec61850ClientManager manager;
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
  final GooseReceiverService _gooseService = GooseReceiverService.instance;
  GooseMessage? _selectedMessage;
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _gooseService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _gooseService.removeListener(_onServiceUpdate);
    _filterController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  List<GooseMessage> get _filteredMessages {
    final list = _gooseService.messages;
    if (_filter.isEmpty) return list;
    return list.where((m) {
      final q = _filter.toLowerCase();
      return m.gocbRef.toLowerCase().contains(q) ||
          m.datSet.toLowerCase().contains(q) ||
          m.goId.toLowerCase().contains(q) ||
          m.appId.toRadixString(16).toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = _filteredMessages;

    return Column(
      children: [
        // Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252526) : const Color(0xFFF3F3F3),
            border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal[700],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radar, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      i18n.t('gooseMonitorTitle'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.withOpacity(0.4)),
                ),
                child: Text(
                  '${_gooseService.messages.length} ${i18n.t("frames")}',
                  style: const TextStyle(fontSize: 12, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              // Filter field
              SizedBox(
                width: 200,
                height: 32,
                child: TextField(
                  controller: _filterController,
                  decoration: InputDecoration(
                    hintText: i18n.t('filterGooseHint'),
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            onPressed: () {
                              _filterController.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onChanged: (val) => setState(() => _filter = val.trim()),
                ),
              ),
              const Spacer(),
              // Test Simulation Button
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.flash_on, size: 16, color: Colors.amber),
                label: Text(i18n.t('simReceiveGoose'), style: const TextStyle(fontSize: 12)),
                onPressed: _injectSampleGoosePacket,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: i18n.t('clearGooseTooltip'),
                onPressed: () {
                  setState(() {
                    _gooseService.clear();
                    _selectedMessage = null;
                  });
                },
              ),
            ],
          ),
        ),

        // Main Content: Left Table & Right Inspector
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stream, size: 56, color: isDark ? Colors.grey[700] : Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        i18n.t('emptyGoosePrompt'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        i18n.t('emptyGooseSubPrompt'),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    // Messages List Table
                    Expanded(
                      flex: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: messages.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            // Show newest first
                            final msg = messages[messages.length - 1 - index];
                            final isSelected = _selectedMessage == msg;
                            final timeStr = DateFormat('HH:mm:ss.SSS').format(msg.receivedTime);

                            return Card(
                              elevation: isSelected ? 2 : 0,
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: isSelected
                                    ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                                    : BorderSide(color: isDark ? Colors.grey[850]! : Colors.grey[250]!),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => setState(() => _selectedMessage = msg),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.teal[800],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '0x${msg.appId.toRadixString(16).padLeft(4, '0').toUpperCase()}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              msg.gocbRef,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'stNum: ${msg.stNum}  |  sqNum: ${msg.sqNum}  |  TAL: ${msg.timeAllowedToLive}ms',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${msg.allData.length} entries',
                                              style: const TextStyle(fontSize: 10, color: Colors.blueAccent),
                                            ),
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
                    ),

                    // Inspector Details & Hex Dump
                    Expanded(
                      flex: 5,
                      child: _selectedMessage == null
                          ? Center(
                              child: Text(
                                i18n.t('selectGooseFrameHint'),
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : _buildGooseInspector(_selectedMessage!, isDark),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildGooseInspector(GooseMessage msg, bool isDark) {
    final i18n = AppI18n.instance;
    final hexDump = _formatHexDump(msg.rawBytes);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Title
        Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Colors.tealAccent),
            const SizedBox(width: 8),
            Text(
              i18n.t('gooseAsnTitle'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            Text(
              '${msg.rawBytes.length} ${i18n.t("bytesUnit")}',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Parameter Grid
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldRow('gocbRef', msg.gocbRef),
                _buildFieldRow('goID', msg.goId),
                _buildFieldRow('datSet', msg.datSet),
                _buildFieldRow('APPID', '0x${msg.appId.toRadixString(16).padLeft(4, '0').toUpperCase()} (${msg.appId})'),
                _buildFieldRow('timeAllowedToLive', '${msg.timeAllowedToLive} ms'),
                _buildFieldRow(i18n.t('stNumTag'), '${msg.stNum}'),
                _buildFieldRow(i18n.t('sqNumTag'), '${msg.sqNum}'),
                _buildFieldRow(i18n.t('testTag'), '${msg.test}'),
                _buildFieldRow(i18n.t('confRevTag'), '${msg.confRev}'),
                _buildFieldRow(i18n.t('ndsComTag'), '${msg.ndsCom}'),
                _buildFieldRow('numDatSetEntries', '${msg.numDatSetEntries}'),
                _buildFieldRow('Timestamp (t)', msg.timestamp.toIso8601String()),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        // AllData Entries
        Text(
          i18n.t('datasetContent'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
          ),
          child: msg.allData.isEmpty
              ? Text(i18n.t('noDataItems'), style: const TextStyle(color: Colors.grey, fontSize: 12))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(msg.allData.length, (i) {
                    final val = msg.allData[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '#${i + 1}',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.tealAccent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$val (${val.runtimeType})',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        ),

        const SizedBox(height: 12),
        // Raw Hex Dump
        Text(
          i18n.t('rawEthHexDump'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : const Color(0xFFEFEFEF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isDark ? Colors.grey[850]! : Colors.grey[300]!),
          ),
          child: SelectableText(
            hexDump,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatHexDump(Uint8List bytes) {
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

  void _injectSampleGoosePacket() {
    // Generate a sample GOOSE packet: APPID 0x0001, gocbRef "Device1/LLN0$GO$gcb01"
    final gocbRef = utf8.encode('Device1/LLN0\$GO\$gcb01');
    final datSet = utf8.encode('Device1/LLN0\$dsGoose');
    final goId = utf8.encode('GOOSE_TRIP_ID');

    final payload = <int>[
      0x61, 0x3E, // goosePdu
      0x80, gocbRef.length, ...gocbRef,
      0x81, 0x02, 0x07, 0xD0, // TAL 2000ms
      0x82, datSet.length, ...datSet,
      0x83, goId.length, ...goId,
      0x84, 0x08, 0x67, 0x0E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // t
      0x85, 0x01, 0x02, // stNum 2
      0x86, 0x01, 0x05, // sqNum 5
      0x87, 0x01, 0x00, // test false
      0x88, 0x01, 0x01, // confRev 1
      0x89, 0x01, 0x00, // ndsCom false
      0x8A, 0x01, 0x02, // numEntries 2
      0xAB, 0x06, // allData
      0x83, 0x01, 0xFF, // boolean true (Trip signal)
      0x84, 0x01, 0x00, // bit-string quality Good
    ];

    final packet = Uint8List.fromList([
      0x00, 0x01, // APPID 0x0001
      0x00, 0x42, // Length
      0x00, 0x00, // Reserved 1
      0x00, 0x00, // Reserved 2
      ...payload,
    ]);

    _gooseService.processPacket(packet);
    if (mounted) setState(() {});
  }
}
