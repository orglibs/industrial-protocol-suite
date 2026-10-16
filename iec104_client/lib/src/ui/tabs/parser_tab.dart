import 'package:flutter/material.dart';
import '../../protocol/parser.dart';

class ParserTab extends StatefulWidget {
  const ParserTab({super.key});

  @override
  State<ParserTab> createState() => _ParserTabState();
}

class _ParserTabState extends State<ParserTab> {
  final TextEditingController _hexController = TextEditingController(
    text: '68 0e 00 00 00 00 64 01 06 00 01 00 00 00 00 14',
  );

  ParsedFrame? _parsed;

  @override
  void initState() {
    super.initState();
    _parseCurrent();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _parseCurrent() {
    final text = _hexController.text.trim();
    if (text.isEmpty) {
      setState(() => _parsed = null);
      return;
    }

    final res = Iec104Parser.parseHex(text);
    setState(() => _parsed = res);
  }

  void _setSample(String hex) {
    _hexController.text = hex;
    _parseCurrent();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Input Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('输入 IEC 60870-5-104 报文十六进制字节码 (Hex Stream):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _hexController,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '例如: 68 0e 00 00 00 00 64 01 06 00 01 00 00 00 00 14',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _parseCurrent(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('快捷测试样本:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('总召唤激活 (C_IC_NA_1)'),
                          onPressed: () => _setSample('68 0e 00 00 00 00 64 01 06 00 01 00 00 00 00 14'),
                        ),
                        ActionChip(
                          label: const Text('STARTDT act'),
                          onPressed: () => _setSample('68 04 07 00 00 00'),
                        ),
                        ActionChip(
                          label: const Text('STARTDT con'),
                          onPressed: () => _setSample('68 04 0b 00 00 00'),
                        ),
                        ActionChip(
                          label: const Text('S-Format ACK'),
                          onPressed: () => _setSample('68 04 01 00 02 00'),
                        ),
                        ActionChip(
                          label: const Text('单点遥信 (M_SP_NA_1)'),
                          onPressed: () => _setSample('68 0e 00 00 00 00 01 01 03 00 01 00 01 00 00 01'),
                        ),
                        ActionChip(
                          label: const Text('短浮点遥测 (M_ME_NC_1)'),
                          onPressed: () => _setSample('68 12 00 00 00 00 0d 01 03 00 01 00 01 40 00 00 00 28 42 00'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Parse Results
        if (_parsed == null)
          const Center(child: Text('请输入合法的十六进制数据'))
        else ...[
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: _parsed!.isValid ? Colors.blue.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _parsed!.isValid ? Icons.insights : Icons.error_outline,
                    size: 36,
                    color: _parsed!.isValid ? Colors.blue.shade700 : Colors.red.shade700,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _parsed!.summary,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _parsed!.isValid ? Colors.blue.shade900 : Colors.red.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '报文 HEX: ${_parsed!.rawHex}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('报文各层协议字段详解 (Protocol Breakdown):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _parsed!.fields.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final field = _parsed!.fields[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(field.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          if (field.hex.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'HEX: 0x${field.hex}',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field.value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                            ),
                          ),
                          if (field.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              field.description,
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
