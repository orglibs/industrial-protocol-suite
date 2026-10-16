import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../client/iec104_client.dart';
import '../../client/station_data.dart';
import '../../i18n/app_i18n.dart';

class StationImportExportDialog extends StatefulWidget {
  final Iec104Client client;
  final ClientStationModel currentStation;
  final VoidCallback? onImported;

  const StationImportExportDialog({
    super.key,
    required this.client,
    required this.currentStation,
    this.onImported,
  });

  @override
  State<StationImportExportDialog> createState() => _StationImportExportDialogState();
}

class _StationImportExportDialogState extends State<StationImportExportDialog> {
  late TextEditingController _textCtrl;
  bool _exportAll = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
    _refreshExportText();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _refreshExportText() {
    if (_exportAll) {
      final list = widget.client.stations.values.map((s) => s.toJson()).toList();
      _textCtrl.text = const JsonEncoder.withIndent('  ').convert({'stations': list});
    } else {
      _textCtrl.text = const JsonEncoder.withIndent('  ').convert(widget.currentStation.toJson());
    }
  }

  void _doImport() {
    final i18n = AppI18n.instance;
    try {
      final json = jsonDecode(_textCtrl.text);
      if (json is Map<String, dynamic>) {
        if (json.containsKey('stations') && json['stations'] is List) {
          // Import multiple stations
          int count = 0;
          for (final item in json['stations']) {
            if (item is Map<String, dynamic>) {
              final ca = item['commonAddress'] as int? ?? 1;
              final st = widget.client.getStation(ca);
              st.loadFromJson(item);
              count++;
            }
          }
          Navigator.pop(context);
          widget.onImported?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${i18n.t('importSuccess')}: $count'), backgroundColor: Colors.green),
          );
        } else if (json.containsKey('commonAddress')) {
          // Import single station
          final ca = json['commonAddress'] as int? ?? widget.currentStation.commonAddress;
          final st = widget.client.getStation(ca);
          st.loadFromJson(json);
          Navigator.pop(context);
          widget.onImported?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${i18n.t('importSuccess')}: CA=$ca (${st.points.length})'), backgroundColor: Colors.green),
          );
        } else {
          throw FormatException(i18n.t('invalidJson'));
        }
      } else {
        throw const FormatException('Invalid JSON Object');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${i18n.t('importFailed')}: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.import_export, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(i18n.t('importExportTitle')),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: Text('${i18n.t('currentStation')} (${widget.currentStation.name})'),
                  selected: !_exportAll,
                  onSelected: (sel) {
                    if (sel) {
                      setState(() {
                        _exportAll = false;
                        _refreshExportText();
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('${i18n.t('allStations')} (${widget.client.stations.length})'),
                  selected: _exportAll,
                  onSelected: (sel) {
                    if (sel) {
                      setState(() {
                        _exportAll = true;
                        _refreshExportText();
                      });
                    }
                  },
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(i18n.t('copyJson')),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _textCtrl.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(i18n.t('copiedToClipboard'))),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'JSON',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.file_upload, size: 18),
              label: Text(i18n.t('importFromJson')),
              onPressed: _doImport,
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(i18n.t('close')),
            ),
          ],
        ),
      ],
    );
  }
}
