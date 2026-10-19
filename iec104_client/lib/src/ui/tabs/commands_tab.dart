import 'dart:async';
import 'package:flutter/material.dart';
import '../../client/iec104_client.dart';
import '../../client/station_data.dart';
import '../../i18n/app_i18n.dart';
import '../../protocol/asdu.dart';

import '../../models/connection_config.dart';

class CommandsTab extends StatefulWidget {
  final List<Iec104ClientConnectionConfig>? connections;
  final Iec104ClientConnectionConfig? activeConnection;
  final ValueChanged<Iec104ClientConnectionConfig>? onSelectConnection;
  final Iec104Client? client;

  const CommandsTab({
    super.key,
    this.connections,
    this.activeConnection,
    this.onSelectConnection,
    this.client,
  });

  @override
  State<CommandsTab> createState() => _CommandsTabState();
}

class _CommandsTabState extends State<CommandsTab> {
  int _ca = 1;
  final List<CommandResultEvent> _history = [];
  StreamSubscription<CommandResultEvent>? _cmdSub;
  StreamSubscription<ClientConnectionState>? _stateSub;
  StreamSubscription<List<ClientStationModel>>? _stationSub;

  // Single Command
  final _scIoaCtrl = TextEditingController(text: '1');
  bool _scVal = true;
  bool _scSelect = false;

  // Double Command
  final _dcIoaCtrl = TextEditingController(text: '10');
  int _dcVal = 2; // 1 = OFF, 2 = ON
  bool _dcSelect = false;

  // Step Command
  final _rcIoaCtrl = TextEditingController(text: '30');
  int _rcStep = 2; // 1 = Lower, 2 = Higher
  bool _rcSelect = false;

  // Setpoint Float
  final _seIoaCtrl = TextEditingController(text: '16385');
  final _seValCtrl = TextEditingController(text: '110.5');
  bool _seSelect = false;

  // Read point
  final _rdIoaCtrl = TextEditingController(text: '16385');

  Iec104Client get _currentClient => widget.activeConnection?.client ?? widget.client!;

  @override
  void initState() {
    super.initState();
    _initSelection();
    _subscribe();
  }

  void _initSelection() {
    final c = _currentClient;
    if (c.stations.isNotEmpty) {
      if (!c.stations.containsKey(_ca)) {
        _ca = c.stations.keys.first;
      }
    }
  }

  void _subscribe() {
    _cmdSub?.cancel();
    _stateSub?.cancel();
    _stationSub?.cancel();

    final c = _currentClient;
    _cmdSub = c.commandResultStream.listen((event) {
      if (mounted) {
        setState(() {
          _history.insert(0, event);
          if (_history.length > 50) _history.removeLast();
        });
      }
    });
    _stateSub = c.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _stationSub = c.stationsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant CommandsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeConnection != widget.activeConnection) {
      _initSelection();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _cmdSub?.cancel();
    _stateSub?.cancel();
    _stationSub?.cancel();
    _scIoaCtrl.dispose();
    _dcIoaCtrl.dispose();
    _rcIoaCtrl.dispose();
    _seIoaCtrl.dispose();
    _seValCtrl.dispose();
    _rdIoaCtrl.dispose();
    super.dispose();
  }

  Widget _buildTopSelector(
      ThemeData theme, AppI18n i18n, Iec104Client c, bool isActive, List<int> availableCas) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (widget.connections != null && widget.connections!.isNotEmpty) ...[
          Text('${i18n.t('connAlias')}: ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.dividerColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Iec104ClientConnectionConfig>(
                  isExpanded: true,
                  value: widget.connections!.contains(widget.activeConnection)
                      ? widget.activeConnection
                      : widget.connections!.firstOrNull,
                  items: widget.connections!.map((conn) {
                    return DropdownMenuItem(
                      value: conn,
                      child: Text(
                        '${conn.displayName} (${conn.host}:${conn.port})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (newConn) {
                    if (newConn != null && newConn != widget.activeConnection) {
                      widget.onSelectConnection?.call(newConn);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
        Text('${i18n.t('targetCoa')}: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        DropdownButton<int>(
          value: _ca,
          items: availableCas.map((ca) {
            final stName = c.stations[ca]?.displayName;
            final label = stName != null
                ? 'CA=$ca ($stName)'
                : (ca == 65535 ? i18n.t('broadcastCoa') : 'CA=$ca');
            return DropdownMenuItem(
              value: ca,
              child: Text(label, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _ca = val);
          },
        ),
        if (!isActive)
          Text(
            i18n.t('linkNotActiveHint'),
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildCommandPanels(BuildContext context, ThemeData theme, AppI18n i18n,
      Iec104Client c, bool isActive, List<int> availableCas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Connection & CA Selector
        _buildTopSelector(theme, i18n, c, isActive, availableCas),
        const SizedBox(height: 16),

        // Group 1: General Commands
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n.t('systemCallCommands'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.sync, size: 18),
                      label: Text(i18n.t('sendGeneralInterrogation')),
                      onPressed: isActive ? () => c.sendGeneralInterrogation(ca: _ca, qoi: 20) : null,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text(i18n.t('clockSyncCmd')),
                      onPressed: isActive ? () => c.sendClockSynchronization(ca: _ca) : null,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.flash_on, size: 18),
                      label: Text(i18n.t('counterInterrogation')),
                      onPressed: isActive ? () => c.sendCounterInterrogation(ca: _ca, rqt: 5) : null,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: Text(i18n.t('resetProcess')),
                      onPressed: isActive ? () => c.sendResetProcess(ca: _ca, qrp: 1) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Group 2: Single Command (C_SC_NA_1)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n.t('singleCommand'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _scIoaCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          labelText: i18n.t('ioa'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: false, label: Text(i18n.t('switchOff'))),
                        ButtonSegment(value: true, label: Text(i18n.t('switchOn'))),
                      ],
                      selected: {_scVal},
                      onSelectionChanged: (val) => setState(() => _scVal = val.first),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _scSelect,
                          onChanged: (val) => setState(() => _scSelect = val ?? false),
                        ),
                        Text(i18n.t('selectExecute')),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send, size: 16),
                      label: Text(_scSelect ? i18n.t('sendSelect') : i18n.t('sendExecute')),
                      onPressed: isActive
                          ? () {
                              final ioa = int.tryParse(_scIoaCtrl.text.trim()) ?? 1;
                              c.sendSingleCommand(
                                  ca: _ca, ioa: ioa, value: _scVal, select: _scSelect);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Group 3: Double Command (C_DC_NA_1)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n.t('doubleCommand'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _dcIoaCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          labelText: i18n.t('ioa'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 1, label: Text(i18n.t('switchOff'))),
                        ButtonSegment(value: 2, label: Text(i18n.t('switchOn'))),
                      ],
                      selected: {_dcVal},
                      onSelectionChanged: (val) => setState(() => _dcVal = val.first),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _dcSelect,
                          onChanged: (val) => setState(() => _dcSelect = val ?? false),
                        ),
                        Text(i18n.t('selectExecute')),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send, size: 16),
                      label: Text(_dcSelect ? i18n.t('sendSelect') : i18n.t('sendExecute')),
                      onPressed: isActive
                          ? () {
                              final ioa = int.tryParse(_dcIoaCtrl.text.trim()) ?? 10;
                              c.sendDoubleCommand(
                                  ca: _ca, ioa: ioa, value: _dcVal, select: _dcSelect);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Group 4: Step Command (C_RC_NA_1)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n.t('stepCommand'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _rcIoaCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          labelText: i18n.t('ioa'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 1, label: Text(i18n.t('stepDown'))),
                        ButtonSegment(value: 2, label: Text(i18n.t('stepUp'))),
                      ],
                      selected: {_rcStep},
                      onSelectionChanged: (val) => setState(() => _rcStep = val.first),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _rcSelect,
                          onChanged: (val) => setState(() => _rcSelect = val ?? false),
                        ),
                        Text(i18n.t('selectExecute')),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send, size: 16),
                      label: Text(i18n.t('stepCommand')),
                      onPressed: isActive
                          ? () {
                              final ioa = int.tryParse(_rcIoaCtrl.text.trim()) ?? 30;
                              c.sendStepCommand(
                                  ca: _ca, ioa: ioa, step: _rcStep, select: _rcSelect);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Group 5: Short Float Setpoint (C_SE_NC_1) & Read (C_RD_NA_1)
        LayoutBuilder(
          builder: (context, boxConstraints) {
            final isWidePair = boxConstraints.maxWidth >= 640;
            final setpointCard = Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i18n.t('setpointFloat'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _seIoaCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              labelText: i18n.t('ioa'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _seValCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              labelText: '${i18n.t('setValue')} (Float)',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _seSelect,
                              onChanged: (val) => setState(() => _seSelect = val ?? false),
                            ),
                            Text(i18n.t('selectExecute')),
                          ],
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send, size: 16),
                          label: Text(i18n.t('sendExecute')),
                          onPressed: isActive
                              ? () {
                                  final ioa = int.tryParse(_seIoaCtrl.text.trim()) ?? 16385;
                                  final val = double.tryParse(_seValCtrl.text.trim()) ?? 0.0;
                                  c.sendSetpointFloat(
                                      ca: _ca, ioa: ioa, value: val, select: _seSelect);
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            final readCard = Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('C_RD_NA_1 (Read)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _rdIoaCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              labelText: i18n.t('ioa'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(i18n.t('singlePointRefresh')),
                          onPressed: isActive
                              ? () {
                                  final ioa = int.tryParse(_rdIoaCtrl.text.trim()) ?? 16385;
                                  c.sendReadCommand(ca: _ca, ioa: ioa);
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Query current value from slave by IOA',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            );

            if (isWidePair) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: setpointCard),
                  const SizedBox(width: 16),
                  Expanded(child: readCard),
                ],
              );
            } else {
              return Column(
                children: [
                  setpointCard,
                  const SizedBox(height: 16),
                  readCard,
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildCommandResponsesLog(ThemeData theme, AppI18n i18n, {bool isFlex = true}) {
    final content = Container(
      margin: isFlex
          ? const EdgeInsets.only(top: 16, right: 16, bottom: 16)
          : const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Command Responses',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.clear_all, size: 20),
                tooltip: i18n.t('clearLog'),
                onPressed: () => setState(() => _history.clear()),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: _history.isEmpty
                ? Center(
                    child: Text(
                      i18n.t('noPointsPrompt'),
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  )
                : ListView.separated(
                    itemCount: _history.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final ev = _history[idx];
                      final timeStr = ev.timestamp.toIso8601String().substring(11, 23);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          ev.message,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        subtitle: Text(
                          '$timeStr | COT: ${ev.cot.description}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        leading: Icon(
                          ev.cot == CauseOfTransmission.activationConfirmation ||
                                  ev.cot == CauseOfTransmission.activationTermination
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          size: 18,
                          color: ev.cot == CauseOfTransmission.activationConfirmation
                              ? Colors.green
                              : (ev.cot == CauseOfTransmission.activationTermination
                                  ? Colors.blue
                                  : Colors.orange),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (isFlex) {
      return SizedBox(
        width: 360,
        child: content,
      );
    } else {
      return SizedBox(
        height: 320,
        child: content,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;
    final c = _currentClient;
    final isActive = c.state == ClientConnectionState.active;
    final availableCas = {...c.stations.keys, 65535}.toList()..sort();
    if (!availableCas.contains(_ca)) {
      _ca = availableCas.first;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildCommandPanels(
                      context, theme, i18n, c, isActive, availableCas),
                ),
              ),
              _buildCommandResponsesLog(theme, i18n, isFlex: true),
            ],
          );
        } else {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCommandPanels(
                    context, theme, i18n, c, isActive, availableCas),
                const SizedBox(height: 16),
                _buildCommandResponsesLog(theme, i18n, isFlex: false),
              ],
            ),
          );
        }
      },
    );
  }
}
