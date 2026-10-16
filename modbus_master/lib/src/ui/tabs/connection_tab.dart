import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../../models/connection_config.dart';
import '../../models/register_group.dart';
import '../../models/slave_model.dart';
import '../../protocol/modbus_client.dart';
import '../../protocol/serial_port_adapter.dart';
import '../../services/polling_service.dart';
import '../dialogs/edit_connection_dialog.dart';
import '../dialogs/edit_slave_dialog.dart';
import '../dialogs/edit_group_dialog.dart';

class ConnectionTab extends StatefulWidget {
  final ModbusClient client;
  final PollingService pollingService;
  final List<ConnectionConfig> connections;
  final ConnectionConfig activeConnection;
  final ValueChanged<ConnectionConfig> onSelectConnection;
  final VoidCallback onConfigChanged;
  final VoidCallback onAddConnection;
  final ValueChanged<ConnectionConfig> onDeleteConnection;

  const ConnectionTab({
    super.key,
    required this.client,
    required this.pollingService,
    required this.connections,
    required this.activeConnection,
    required this.onSelectConnection,
    required this.onConfigChanged,
    required this.onAddConnection,
    required this.onDeleteConnection,
  });

  @override
  State<ConnectionTab> createState() => _ConnectionTabState();
}

class _ConnectionTabState extends State<ConnectionTab> {
  late TextEditingController _ipCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _timeoutCtrl;

  List<String> _availablePorts = [];
  static const List<int> _baudRates = [1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200];
  static const List<int> _dataBitsList = [8, 7];
  static const Map<int, String> _parityLabels = {0: 'None (0)', 1: 'Odd (1)', 2: 'Even (2)'};
  static const List<int> _stopBitsList = [1, 2];

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(text: widget.activeConnection.ip);
    _portCtrl = TextEditingController(text: widget.activeConnection.port.toString());
    _timeoutCtrl = TextEditingController(text: widget.activeConnection.timeoutMs.toString());

    _loadAvailablePorts();

    widget.client.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ConnectionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeConnection != widget.activeConnection) {
      _ipCtrl.text = widget.activeConnection.ip;
      _portCtrl.text = widget.activeConnection.port.toString();
      _timeoutCtrl.text = widget.activeConnection.timeoutMs.toString();
      _loadAvailablePorts();
    }
  }

  void _loadAvailablePorts() {
    final ports = SerialPortAdapter.getAvailablePorts();
    setState(() {
      _availablePorts = ports;
      if (widget.activeConnection.serialPortName != null &&
          widget.activeConnection.serialPortName!.isNotEmpty &&
          !_availablePorts.contains(widget.activeConnection.serialPortName)) {
        _availablePorts.add(widget.activeConnection.serialPortName!);
      }
      if ((widget.activeConnection.serialPortName == null || widget.activeConnection.serialPortName!.isEmpty) &&
          _availablePorts.isNotEmpty) {
        widget.activeConnection.serialPortName = _availablePorts.first;
      }
    });
  }

  void _showCustomPortDialog() {
    final textCtrl = TextEditingController(text: widget.activeConnection.serialPortName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppI18n.instance.t('serialPort')), 
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'e.g. /dev/ttyUSB0 | COM1',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: AppI18n.instance.t('serialPort'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.usb),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppI18n.instance.t('cancel'))),
          ElevatedButton(
            onPressed: () {
              final val = textCtrl.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  widget.activeConnection.serialPortName = val;
                  if (!_availablePorts.contains(val)) {
                    _availablePorts.add(val);
                  }
                });
                widget.onConfigChanged();
              }
              Navigator.of(ctx).pop();
            },
            child: Text(AppI18n.instance.t('confirm')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _timeoutCtrl.dispose();
    super.dispose();
  }

  void _toggleConnection() async {
    if (widget.client.state == ModbusConnectionState.connected) {
      widget.pollingService.stop();
      await widget.client.disconnect();
    } else {
      if (widget.activeConnection.mode == ModbusTransportMode.serialRtu) {
        if (widget.activeConnection.serialPortName == null || widget.activeConnection.serialPortName!.isEmpty) {
          if (_availablePorts.isNotEmpty) {
            widget.activeConnection.serialPortName = _availablePorts.first;
          } else {
            widget.activeConnection.serialPortName = '/dev/ttyUSB0';
          }
        }
      } else {
        widget.activeConnection.ip = _ipCtrl.text.trim();
        widget.activeConnection.port = int.tryParse(_portCtrl.text.trim()) ?? 502;
      }
      widget.activeConnection.timeoutMs = int.tryParse(_timeoutCtrl.text.trim()) ?? 1500;
      widget.pollingService.updateConfig(widget.activeConnection);
      widget.onConfigChanged();

      try {
        await widget.client.connect();
        if (widget.client.state == ModbusConnectionState.connected) {
          widget.pollingService.start();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppI18n.instance.t('connect')} failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _editCurrentConnection() async {
    final updated = await EditConnectionDialog.show(
      context,
      connection: widget.activeConnection,
    );
    if (updated != null) {
      _ipCtrl.text = updated.ip;
      _portCtrl.text = updated.port.toString();
      _timeoutCtrl.text = updated.timeoutMs.toString();
      widget.pollingService.updateConfig(updated);
      widget.onConfigChanged();
      setState(() {});
    }
  }

  void _deleteCurrentConnection() {
    if (widget.connections.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppI18n.instance.t('deleteConn'))),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppI18n.instance.t('deleteConn')),
        content: Text('${AppI18n.instance.t('deleteConn')} [${widget.activeConnection.name}]?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppI18n.instance.t('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onDeleteConnection(widget.activeConnection);
            },
            child: Text(AppI18n.instance.t('delete')),
          ),
        ],
      ),
    );
  }

  void _addSlave() async {
    final slave = await EditSlaveDialog.show(context);
    if (slave != null) {
      setState(() {
        widget.activeConnection.slaves.add(slave);
      });
      widget.onConfigChanged();
    }
  }

  void _editSlave(SlaveModel slave) async {
    final res = await EditSlaveDialog.show(context, slave: slave);
    if (res != null) {
      setState(() {});
      widget.onConfigChanged();
    }
  }

  void _copySlave(SlaveModel slave) {
    final usedIds = widget.activeConnection.slaves.map((s) => s.slaveId).toSet();
    int nextId = slave.slaveId + 1;
    while (usedIds.contains(nextId) && nextId <= 247) {
      nextId++;
    }
    if (nextId > 247) nextId = 1;

    final json = slave.toJson();
    final copied = SlaveModel.fromJson(json);
    copied.name = '${slave.name}_Copy';
    copied.slaveId = nextId;

    setState(() {
      widget.activeConnection.slaves.add(copied);
    });
    widget.onConfigChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${AppI18n.instance.t('copySlave')}: ${copied.name}')),
    );
  }

  void _deleteSlave(SlaveModel slave) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppI18n.instance.t('deleteSlave')),
        content: Text('${AppI18n.instance.t('deleteSlave')} [${slave.name}]?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppI18n.instance.t('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                widget.activeConnection.slaves.remove(slave);
              });
              widget.onConfigChanged();
              Navigator.of(ctx).pop();
            },
            child: Text(AppI18n.instance.t('delete')),
          ),
        ],
      ),
    );
  }

  void _addGroup(SlaveModel slave) async {
    final group = await EditGroupDialog.show(context);
    if (group != null) {
      setState(() {
        slave.groups.add(group);
      });
      widget.onConfigChanged();
    }
  }

  void _editGroup(RegisterGroupModel group) async {
    final res = await EditGroupDialog.show(context, group: group);
    if (res != null) {
      setState(() {});
      widget.onConfigChanged();
    }
  }

  void _deleteGroup(SlaveModel slave, RegisterGroupModel group) {
    setState(() {
      slave.groups.remove(group);
    });
    widget.onConfigChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = widget.client.state == ModbusConnectionState.connected;
    final isConnecting = widget.client.state == ModbusConnectionState.connecting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Connection Header & Selector Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                          Text('${AppI18n.instance.t('connAlias')}: ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<ConnectionConfig>(
                                value: widget.activeConnection,
                                items: widget.connections.map((c) {
                                  final desc = c.mode == ModbusTransportMode.serialRtu
                                      ? (c.serialPortName ?? AppI18n.instance.t('serialPort'))
                                      : (c.mode == ModbusTransportMode.virtual ? 'Virtual' : '${c.ip}:${c.port}');
                                  return DropdownMenuItem(
                                    value: c,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          c.mode == ModbusTransportMode.serialRtu
                                              ? Icons.usb
                                              : (c.mode == ModbusTransportMode.virtual ? Icons.memory : Icons.dns),
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text('${c.name} ($desc)', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: isConnected
                                    ? null
                                    : (newConn) {
                                        if (newConn != null && newConn != widget.activeConnection) {
                                          widget.onSelectConnection(newConn);
                                        }
                                      },
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
                              color: isConnected
                                  ? Colors.green.shade100
                                  : (isConnecting ? Colors.orange.shade100 : Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isConnected
                                    ? Colors.green
                                    : (isConnecting ? Colors.orange : Colors.grey),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isConnected
                                        ? Colors.green
                                        : (isConnecting ? Colors.orange : Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.client.state.label,
                                  style: TextStyle(
                                    color: isConnected
                                        ? Colors.green.shade900
                                        : (isConnecting ? Colors.orange.shade900 : Colors.grey.shade800),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: isConnected ? Colors.red.shade700 : theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: Icon(isConnected ? Icons.link_off : Icons.link, size: 18),
                            label: Text(isConnected ? AppI18n.instance.t('disconnect') : AppI18n.instance.t('connect')),
                            onPressed: isConnecting ? null : _toggleConnection,
                          ),

                          OutlinedButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(AppI18n.instance.t('newConn')),
                            onPressed: widget.onAddConnection,
                          ),

                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit, size: 16),
                            label: Text(AppI18n.instance.t('editParams')),
                            onPressed: isConnected ? null : _editCurrentConnection,
                          ),

                          if (widget.connections.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: AppI18n.instance.t('deleteConn'),
                              onPressed: isConnected ? null : _deleteCurrentConnection,
                            ),
                        ],
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  // Connection Parameters row
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Transport Mode
                      SizedBox(
                        width: 290,
                        child: DropdownButtonFormField<ModbusTransportMode>(
                          key: ValueKey(widget.activeConnection.mode),
                          isExpanded: true,
                          initialValue: widget.activeConnection.mode,
                          decoration: const InputDecoration(
                            labelText: AppI18n.instance.t('protoType'),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.settings_ethernet),
                          ),
                          items: ModbusTransportMode.values.map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(m.label, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: isConnected
                              ? null
                              : (m) {
                                  if (m != null) {
                                    setState(() {
                                      widget.activeConnection.mode = m;
                                      if (m == ModbusTransportMode.serialRtu) {
                                        widget.activeConnection.messageFrameFormat = 1;
                                        if (widget.activeConnection.serialPortName == null ||
                                            widget.activeConnection.serialPortName!.isEmpty) {
                                          if (_availablePorts.isNotEmpty) {
                                            widget.activeConnection.serialPortName = _availablePorts.first;
                                          } else {
                                            widget.activeConnection.serialPortName = '/dev/ttyUSB0';
                                          }
                                        }
                                      } else if (m == ModbusTransportMode.rtuOverTcp) {
                                        widget.activeConnection.messageFrameFormat = 1;
                                      } else if (m == ModbusTransportMode.tcp) {
                                        widget.activeConnection.messageFrameFormat = 0;
                                      }
                                    });
                                    widget.onConfigChanged();
                                  }
                                },
                        ),
                      ),

                      // Serial Port Settings (When in serialRtu mode)
                      if (widget.activeConnection.mode == ModbusTransportMode.serialRtu) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 200,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(widget.activeConnection.serialPortName),
                                isExpanded: true,
                                initialValue: _availablePorts.contains(widget.activeConnection.serialPortName)
                                    ? widget.activeConnection.serialPortName
                                    : (_availablePorts.isNotEmpty ? _availablePorts.first : null),
                                decoration: const InputDecoration(
                                  labelText: AppI18n.instance.t('serialPort'),
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.usb),
                                ),
                                items: _availablePorts.map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p, overflow: TextOverflow.ellipsis),
                                )).toList(),
                                onChanged: isConnected
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          setState(() {
                                            widget.activeConnection.serialPortName = val;
                                          });
                                          widget.onConfigChanged();
                                        }
                                      },
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_note),
                              tooltip: AppI18n.instance.t('serialPort'),
                              onPressed: isConnected ? null : _showCustomPortDialog,
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: AppI18n.instance.t('rescan'),
                              onPressed: isConnected ? null : _loadAvailablePorts,
                            ),
                          ],
                        ),

                        // Baud Rate
                        SizedBox(
                          width: 130,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey(widget.activeConnection.baudRate),
                            isExpanded: true,
                            initialValue: _baudRates.contains(widget.activeConnection.baudRate)
                                ? widget.activeConnection.baudRate
                                : 9600,
                            decoration: const InputDecoration(
                              labelText: AppI18n.instance.t('baudRate'),
                              border: OutlineInputBorder(),
                            ),
                            items: _baudRates.map((b) => DropdownMenuItem(
                              value: b,
                              child: Text(b.toString()),
                            )).toList(),
                            onChanged: isConnected
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() {
                                        widget.activeConnection.baudRate = val;
                                      });
                                      widget.onConfigChanged();
                                    }
                                  },
                          ),
                        ),

                        // Data Bits
                        SizedBox(
                          width: 100,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey(widget.activeConnection.dataBits),
                            isExpanded: true,
                            initialValue: _dataBitsList.contains(widget.activeConnection.dataBits)
                                ? widget.activeConnection.dataBits
                                : 8,
                            decoration: const InputDecoration(
                              labelText: AppI18n.instance.t('dataBits'),
                              border: OutlineInputBorder(),
                            ),
                            items: _dataBitsList.map((d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d Bits'),
                            )).toList(),
                            onChanged: isConnected
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() {
                                        widget.activeConnection.dataBits = val;
                                      });
                                      widget.onConfigChanged();
                                    }
                                  },
                          ),
                        ),

                        // Parity
                        SizedBox(
                          width: 140,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey(widget.activeConnection.parity),
                            isExpanded: true,
                            initialValue: _parityLabels.containsKey(widget.activeConnection.parity)
                                ? widget.activeConnection.parity
                                : 0,
                            decoration: const InputDecoration(
                              labelText: AppI18n.instance.t('parity'),
                              border: OutlineInputBorder(),
                            ),
                            items: _parityLabels.entries.map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value, overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: isConnected
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() {
                                        widget.activeConnection.parity = val;
                                      });
                                      widget.onConfigChanged();
                                    }
                                  },
                          ),
                        ),

                        // Stop Bits
                        SizedBox(
                          width: 100,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey(widget.activeConnection.stopBits),
                            isExpanded: true,
                            initialValue: _stopBitsList.contains(widget.activeConnection.stopBits)
                                ? widget.activeConnection.stopBits
                                : 1,
                            decoration: const InputDecoration(
                              labelText: AppI18n.instance.t('stopBits'),
                              border: OutlineInputBorder(),
                            ),
                            items: _stopBitsList.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text('$s Bits'),
                            )).toList(),
                            onChanged: isConnected
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() {
                                        widget.activeConnection.stopBits = val;
                                      });
                                      widget.onConfigChanged();
                                    }
                                  },
                          ),
                        ),
                      ],

                      // IP & Port for TCP modes
                      if (widget.activeConnection.mode == ModbusTransportMode.tcp ||
                          widget.activeConnection.mode == ModbusTransportMode.rtuOverTcp) ...[
                        SizedBox(
                          width: 190,
                          child: TextField(
                            controller: _ipCtrl,
                            enabled: !isConnected,
                            decoration: const InputDecoration(
                              labelText: AppI18n.instance.t('listenIp'),
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.dns),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _portCtrl,
                            enabled: !isConnected,
                            decoration: const InputDecoration(
                              labelText: AppI18n.instance.t('listenPort'),
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],

                      // Virtual mode notice
                      if (widget.activeConnection.mode == ModbusTransportMode.virtual)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.memory, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(AppI18n.instance.t('footerNote'), style: TextStyle(fontSize: 13, color: theme.colorScheme.primary)),
                            ],
                          ),
                        ),

                      // Timeout
                      SizedBox(
                        width: 130,
                        child: TextField(
                          controller: _timeoutCtrl,
                          enabled: !isConnected,
                          decoration: const InputDecoration(
                            labelText: AppI18n.instance.t('respDelay'),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.timer),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 2. Slaves & Groups Management Header for THIS Connection
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_tree, color: Colors.blueGrey, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '[${widget.activeConnection.name}] ${AppI18n.instance.t('slavesList')}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${widget.activeConnection.slaves.length}', style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.grey.shade100,
                  ),
                ],
              ),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: Text(AppI18n.instance.t('newSlave')),
                onPressed: _addSlave,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Slaves List belonging to THIS Connection
          if (widget.activeConnection.slaves.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.device_unknown, size: 48, color: Colors.blueGrey),
                      const SizedBox(height: 12),
                      Text(AppI18n.instance.t('noSlaveHint'), style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(AppI18n.instance.t('newSlave')),
                        onPressed: _addSlave,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...widget.activeConnection.slaves.map((slave) {
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Slave Header
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.developer_board, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${slave.name} [ID: ${slave.slaveId}]',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${slave.scanRate}ms | ${slave.byteOrder.name.toUpperCase()}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.edit, size: 16),
                                label: Text(AppI18n.instance.t('edit')),
                                onPressed: () => _editSlave(slave),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.copy, size: 16),
                                label: Text(AppI18n.instance.t('copySlave')),
                                onPressed: () => _copySlave(slave),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: Text(AppI18n.instance.t('addGroup')),
                                onPressed: () => _addGroup(slave),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: AppI18n.instance.t('deleteSlave'),
                                onPressed: () => _deleteSlave(slave),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Divider(height: 20),

                      // Groups List
                      if (slave.groups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            AppI18n.instance.t('noGroupHint'),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: slave.groups.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, gIdx) {
                            final group = slave.groups[gIdx];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              leading: Icon(
                                group.registerType == ModbusRegisterType.coils
                                    ? Icons.toggle_on
                                    : (group.registerType == ModbusRegisterType.discreteInputs
                                        ? Icons.input
                                        : Icons.table_chart),
                                color: Colors.teal,
                              ),
                              title: Text(group.groupName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${group.registerType.label} | ${AppI18n.instance.t('startAddr')}: ${group.startAddress} | ${AppI18n.instance.t('pointsCount')}: ${group.quantity}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: group.isPollingEnabled,
                                    onChanged: (val) {
                                      setState(() {
                                        group.isPollingEnabled = val;
                                      });
                                      widget.onConfigChanged();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _editGroup(group),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    onPressed: () => _deleteGroup(slave, group),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
