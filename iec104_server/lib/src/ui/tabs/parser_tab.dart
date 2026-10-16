import "../../i18n/app_i18n.dart";
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
    final theme = Theme.of(context);
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
                Text(AppI18n.instance.t('inputHex'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _hexController,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '68 0e 00 00 00 00 64 01 06 00 01 00 00 00 00 14',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _parseCurrent(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Samples:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: Text(AppI18n.instance.t('generalInterrogation')),
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
                          label: const Text('M_SP_NA_1'),
                          onPressed: () => _setSample('68 0e 00 00 00 00 01 01 03 00 01 00 01 00 00 01'),
                        ),
                        ActionChip(
                          label: const Text('M_ME_NC_1'),
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
          Center(child: Text(AppI18n.instance.t('convertFailed')))
        else ...[
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _parsed!.isValid
                    ? theme.colorScheme.primary.withAlpha(80)
                    : theme.colorScheme.error.withAlpha(80),
              ),
            ),
            color: _parsed!.isValid
                ? theme.colorScheme.primaryContainer.withAlpha(40)
                : theme.colorScheme.errorContainer.withAlpha(40),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _parsed!.isValid ? Icons.insights : Icons.error_outline,
                    size: 36,
                    color: _parsed!.isValid ? theme.colorScheme.primary : theme.colorScheme.error,
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
                            color: _parsed!.isValid ? theme.colorScheme.primary : theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hex: ${_parsed!.rawHex}',
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
          Text('Protocol Breakdown:',
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
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(field.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                          if (field.hex.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
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
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (field.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              field.description,
                              style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
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
