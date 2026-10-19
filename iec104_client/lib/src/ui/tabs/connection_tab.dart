import 'dart:async';
import 'package:flutter/material.dart';
import '../../client/iec104_client.dart';
import '../../client/traffic_logger.dart';
import '../../i18n/app_i18n.dart';
import '../../models/connection_config.dart';
import '../dialogs/edit_connection_dialog.dart';

class ConnectionTab extends StatefulWidget {
  final List<Iec104ClientConnectionConfig> connections;
  final Iec104ClientConnectionConfig activeConnection;
  final ValueChanged<Iec104ClientConnectionConfig> onSelectConnection;
  final VoidCallback onConfigChanged;
  final VoidCallback onAddConnection;
  final ValueChanged<Iec104ClientConnectionConfig> onDeleteConnection;
  final Iec104Client? client;

  const ConnectionTab({
    super.key,
    required this.connections,
    required this.activeConnection,
    required this.onSelectConnection,
    required this.onConfigChanged,
    required this.onAddConnection,
    required this.onDeleteConnection,
    this.client,
  });

  @override
  State<ConnectionTab> createState() => _ConnectionTabState();
}

class _ConnectionTabState extends State<ConnectionTab> {
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _caCtrl;
  late TextEditingController _kCtrl;
  late TextEditingController _wCtrl;
  late TextEditingController _t0Ctrl;
  late TextEditingController _t1Ctrl;
  late TextEditingController _t2Ctrl;
  late TextEditingController _t3Ctrl;

  late TextEditingController _giPeriodCtrl;
  late TextEditingController _clockPeriodCtrl;
  late TextEditingController _counterPeriodCtrl;

  bool _isVerifying = false;
  List<String>? _verifyResults;

  StreamSubscription<ClientConnectionState>? _stateSub;
  StreamSubscription<TrafficEntry>? _trafficSub;

  Iec104Client get _currentClient => widget.activeConnection.client;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _subscribeClient();
    _trafficSub = TrafficLogger.instance.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _initControllers() {
    final c = widget.activeConnection;
    _hostCtrl = TextEditingController(text: c.host);
    _portCtrl = TextEditingController(text: c.port.toString());
    _caCtrl = TextEditingController(text: c.defaultCa.toString());
    _kCtrl = TextEditingController(text: c.k.toString());
    _wCtrl = TextEditingController(text: c.w.toString());
    _t0Ctrl = TextEditingController(text: c.t0.toString());
    _t1Ctrl = TextEditingController(text: c.t1.toString());
    _t2Ctrl = TextEditingController(text: c.t2.toString());
    _t3Ctrl = TextEditingController(text: c.t3.toString());

    _giPeriodCtrl = TextEditingController(text: c.generalInterrogationPeriod.toString());
    _clockPeriodCtrl = TextEditingController(text: c.clockSyncPeriod.toString());
    _counterPeriodCtrl = TextEditingController(text: c.counterInterrogationPeriod.toString());
  }

  void _subscribeClient() {
    _stateSub?.cancel();
    _stateSub = _currentClient.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ConnectionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeConnection != widget.activeConnection) {
      final c = widget.activeConnection;
      _hostCtrl.text = c.host;
      _portCtrl.text = c.port.toString();
      _caCtrl.text = c.defaultCa.toString();
      _kCtrl.text = c.k.toString();
      _wCtrl.text = c.w.toString();
      _t0Ctrl.text = c.t0.toString();
      _t1Ctrl.text = c.t1.toString();
      _t2Ctrl.text = c.t2.toString();
      _t3Ctrl.text = c.t3.toString();
      _giPeriodCtrl.text = c.generalInterrogationPeriod.toString();
      _clockPeriodCtrl.text = c.clockSyncPeriod.toString();
      _counterPeriodCtrl.text = c.counterInterrogationPeriod.toString();
      _subscribeClient();
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _trafficSub?.cancel();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _caCtrl.dispose();
    _kCtrl.dispose();
    _wCtrl.dispose();
    _t0Ctrl.dispose();
    _t1Ctrl.dispose();
    _t2Ctrl.dispose();
    _t3Ctrl.dispose();
    _giPeriodCtrl.dispose();
    _clockPeriodCtrl.dispose();
    _counterPeriodCtrl.dispose();
    super.dispose();
  }

  void _applyParams() {
    final c = widget.activeConnection;
    c.host = _hostCtrl.text.trim();
    c.port = int.tryParse(_portCtrl.text.trim()) ?? 2404;
    c.defaultCa = int.tryParse(_caCtrl.text.trim()) ?? 1;
    c.k = int.tryParse(_kCtrl.text.trim()) ?? 12;
    c.w = int.tryParse(_wCtrl.text.trim()) ?? 8;
    c.t0 = int.tryParse(_t0Ctrl.text.trim()) ?? 30;
    c.t1 = int.tryParse(_t1Ctrl.text.trim()) ?? 15;
    c.t2 = int.tryParse(_t2Ctrl.text.trim()) ?? 10;
    c.t3 = int.tryParse(_t3Ctrl.text.trim()) ?? 20;

    c.generalInterrogationPeriod = int.tryParse(_giPeriodCtrl.text.trim()) ?? 0;
    c.clockSyncPeriod = int.tryParse(_clockPeriodCtrl.text.trim()) ?? 0;
    c.counterInterrogationPeriod = int.tryParse(_counterPeriodCtrl.text.trim()) ?? 0;

    c.syncConfigToClient();
    c.notifyListeners();
    widget.onConfigChanged();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppI18n.instance.t('configApplied'))),
    );
  }

  void _editCurrentConnection() async {
    final updated = await EditConnectionDialog.show(
      context,
      connection: widget.activeConnection,
    );
    if (updated != null) {
      _hostCtrl.text = updated.host;
      _portCtrl.text = updated.port.toString();
      _caCtrl.text = updated.defaultCa.toString();
      _kCtrl.text = updated.k.toString();
      _wCtrl.text = updated.w.toString();
      _t0Ctrl.text = updated.t0.toString();
      _t1Ctrl.text = updated.t1.toString();
      _t2Ctrl.text = updated.t2.toString();
      _t3Ctrl.text = updated.t3.toString();
      widget.onConfigChanged();
      setState(() {});
    }
  }

  void _deleteCurrentConnection() {
    final i18n = AppI18n.instance;
    if (widget.connections.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.t('deleteConn'))),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t('deleteConn')),
        content: Text('${i18n.t('deleteConn')} [${widget.activeConnection.displayName}]?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(i18n.t('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onDeleteConnection(widget.activeConnection);
            },
            child: Text(i18n.t('delete')),
          ),
        ],
      ),
    );
  }

  Future<void> _runVerification() async {
    final i18n = AppI18n.instance;
    setState(() {
      _isVerifying = true;
      _verifyResults = null;
    });

    try {
      final res = await _currentClient.runAutomatedVerification();
      if (mounted) {
        setState(() {
          _verifyResults = res;
          _isVerifying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifyResults = ['${i18n.t('parseError')}: $e'];
          _isVerifying = false;
        });
      }
    }
  }

  String _getStateLabel(ClientConnectionState state, AppI18n i18n) {
    switch (state) {
      case ClientConnectionState.disconnected:
        return i18n.t('disconnected');
      case ClientConnectionState.connecting:
        return i18n.t('connecting');
      case ClientConnectionState.connected:
        return i18n.t('connected');
      case ClientConnectionState.active:
        return i18n.t('stateActive');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;
    final conn = widget.activeConnection;
    final c = _currentClient;
    final isConnected = c.state != ClientConnectionState.disconnected;
    final isActive = c.state == ClientConnectionState.active;

    Color badgeColor = Colors.grey;
    if (c.state == ClientConnectionState.connecting) badgeColor = Colors.orange;
    if (c.state == ClientConnectionState.connected) badgeColor = Colors.blue;
    if (c.state == ClientConnectionState.active) badgeColor = Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Connection Header & Multi-Connection Selector Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Connection dropdown + Add/Edit/Delete + Status
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hub, color: theme.colorScheme.primary, size: 28),
                          const SizedBox(width: 8),
                          Text('${i18n.t('connAlias')}: ',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: theme.dividerColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Iec104ClientConnectionConfig>(
                                  isExpanded: true,
                                  value: widget.connections.contains(conn) ? conn : widget.connections.firstOrNull,
                                  items: widget.connections.map((item) {
                                    final text = '${item.displayName} (${item.host}:${item.port})';
                                    return DropdownMenuItem(
                                      value: item,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.dns,
                                            size: 16,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              text,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newConn) {
                                    if (newConn != null && newConn != conn) {
                                      widget.onSelectConnection(newConn);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Actions on connections
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor.withAlpha(38),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: badgeColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getStateLabel(c.state, i18n),
                                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),

                          // Connect / Disconnect button
                          if (!isConnected)
                            FilledButton.icon(
                              icon: const Icon(Icons.link),
                              label: Text(i18n.t('connect')),
                              onPressed: () async {
                                _applyParams();
                                try {
                                  await c.connect();
                                  setState(() {});
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${i18n.t('connectFailed')}: $e')),
                                    );
                                  }
                                }
                              },
                            )
                          else
                            ElevatedButton.icon(
                              icon: const Icon(Icons.link_off),
                              label: Text(i18n.t('disconnect')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                await c.disconnect();
                                setState(() {});
                              },
                            ),

                          // Edit Connection
                          IconButton.outlined(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: i18n.t('editConnTitle'),
                            onPressed: _editCurrentConnection,
                          ),

                          // Add Connection
                          IconButton.outlined(
                            icon: const Icon(Icons.add, size: 18),
                            tooltip: i18n.t('newConn'),
                            onPressed: widget.onAddConnection,
                          ),

                          // Delete Connection
                          IconButton.outlined(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: i18n.t('deleteConn'),
                            onPressed: widget.connections.length > 1 ? _deleteCurrentConnection : null,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  // Protocol Controls Row
                  Row(
                    children: [
                      Text(
                        'N(S): ${c.sendSeq} | N(R): ${c.recvSeq} | ${i18n.t('unconfirmed')}: ${c.unconfirmedRecvCount}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      if (c.isWebVirtualMode) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.shade700),
                          ),
                          child: Text(i18n.t('webVirtualMode'),
                              style: const TextStyle(color: Colors.brown, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.play_circle_outline),
                        label: Text(i18n.t('startdtAct')),
                        onPressed: isConnected ? () => c.sendStartDt() : null,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(i18n.t('stopdtAct')),
                        onPressed: isConnected ? () => c.sendStopDt() : null,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.favorite_border),
                        label: Text(i18n.t('testfrAct')),
                        onPressed: isConnected ? () => c.sendTestFr() : null,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.done_all),
                        label: Text(i18n.t('sendSFrame')),
                        onPressed: isConnected ? () => c.sendSFrame() : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.sync),
                        label: Text(i18n.t('sendGeneralInterrogation')),
                        onPressed: isActive ? () => c.sendGeneralInterrogation() : null,
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.access_time),
                        label: Text(i18n.t('clockSyncCmd')),
                        onPressed: isActive ? () => c.sendClockSynchronization() : null,
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.flash_on),
                        label: Text(i18n.t('counterInterrogation')),
                        onPressed: isActive ? () => c.sendCounterInterrogation() : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Network Parameters Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(i18n.t('connAndParam'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      FilledButton.icon(
                        icon: const Icon(Icons.save, size: 16),
                        label: Text(i18n.t('applyAndSave')),
                        onPressed: _applyParams,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _hostCtrl,
                          decoration: InputDecoration(
                            labelText: i18n.t('targetIp'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.computer),
                          ),
                          enabled: !isConnected,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _portCtrl,
                          decoration: InputDecoration(
                            labelText: i18n.t('port'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.tag),
                          ),
                          enabled: !isConnected,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _caCtrl,
                          decoration: InputDecoration(
                            labelText: i18n.t('coa'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.location_city),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('IEC 60870-5-104 Timers & Parameters',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _kCtrl,
                          decoration: InputDecoration(
                              labelText: 'k', border: const OutlineInputBorder(), helperText: i18n.t('kValue')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _wCtrl,
                          decoration: InputDecoration(
                              labelText: 'w', border: const OutlineInputBorder(), helperText: i18n.t('wValue')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _t0Ctrl,
                          decoration: const InputDecoration(
                              labelText: 't0 (s)', border: OutlineInputBorder(), helperText: 'Connect Timeout'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _t1Ctrl,
                          decoration: InputDecoration(
                              labelText: 't1 (s)', border: const OutlineInputBorder(), helperText: i18n.t('t1Timeout')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _t2Ctrl,
                          decoration: const InputDecoration(
                              labelText: 't2 (s)', border: OutlineInputBorder(), helperText: 'Ack Timeout'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _t3Ctrl,
                          decoration: InputDecoration(
                              labelText: 't3 (s)', border: const OutlineInputBorder(), helperText: i18n.t('testfrInterval')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Automation Settings Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Automation & Periodic Tasks',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(i18n.t('autoStartdt')),
                    value: conn.autoStartDt,
                    onChanged: (val) {
                      setState(() {
                        conn.autoStartDt = val;
                        conn.client.autoStartDt = val;
                      });
                      widget.onConfigChanged();
                    },
                  ),
                  SwitchListTile(
                    title: Text(i18n.t('autoGeneralInterrogation')),
                    value: conn.autoGeneralInterrogation,
                    onChanged: (val) {
                      setState(() {
                        conn.autoGeneralInterrogation = val;
                        conn.client.autoGeneralInterrogation = val;
                      });
                      widget.onConfigChanged();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _giPeriodCtrl,
                          decoration: const InputDecoration(
                            labelText: 'GI Period (s)',
                            helperText: '0 = Disabled',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _clockPeriodCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Clock Sync Period (s)',
                            helperText: '0 = Disabled',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _counterPeriodCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Counter GI Period (s)',
                            helperText: '0 = Disabled',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 4. Automated Verification Card
          Card(
            elevation: 1,
            color: theme.colorScheme.primaryContainer.withAlpha(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary.withAlpha(80)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'IEC 104 Client Self-Test',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: _isVerifying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.play_arrow),
                        label: Text(_isVerifying ? 'Verifying...' : 'Run Self-Test'),
                        onPressed: _isVerifying ? null : _runVerification,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Automated sequence: Connect -> STARTDT -> GI -> Clock Sync -> Telecontrol -> Counter -> Read -> S-Ack -> TestFR -> Disconnect.'),
                  if (_verifyResults != null) ...[
                    const Divider(height: 24),
                    for (final r in _verifyResults!)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              (r.contains('FAIL') || r.contains('Error') || r.contains('\u5931\u8d25'))
                                  ? Icons.cancel
                                  : Icons.check_circle,
                              size: 18,
                              color: (r.contains('FAIL') || r.contains('Error') || r.contains('\u5931\u8d25'))
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r,
                                style: TextStyle(
                                  color: (r.contains('FAIL') || r.contains('Error') || r.contains('\u5931\u8d25'))
                                      ? Colors.red.shade900
                                      : Colors.green.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
