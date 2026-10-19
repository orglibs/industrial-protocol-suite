import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../../models/connection_config.dart';
import '../../models/register_group.dart';
import '../../models/register_model.dart';
import '../../models/slave_model.dart';
import '../../protocol/modbus_client.dart';
import '../../protocol/modbus_data_types.dart';
import '../../services/polling_service.dart';
import '../dialogs/write_single_coil_dialog.dart';
import '../dialogs/write_single_register_dialog.dart';
import '../dialogs/write_multiple_registers_dialog.dart';
import '../dialogs/edit_group_dialog.dart';

class RegisterViewTab extends StatefulWidget {
  final ModbusClient client;
  final PollingService pollingService;
  final List<ConnectionConfig> connections;
  final ConnectionConfig activeConnection;
  final ValueChanged<ConnectionConfig> onSelectConnection;
  final VoidCallback onConfigChanged;
  final VoidCallback onAddSlave;

  const RegisterViewTab({
    super.key,
    required this.client,
    required this.pollingService,
    required this.connections,
    required this.activeConnection,
    required this.onSelectConnection,
    required this.onConfigChanged,
    required this.onAddSlave,
  });

  @override
  State<RegisterViewTab> createState() => _RegisterViewTabState();
}

class _RegisterViewTabState extends State<RegisterViewTab> {
  SlaveModel? _selectedSlave;
  RegisterGroupModel? _selectedGroup;
  ModbusByteOrder _byteOrder = ModbusByteOrder.abcd;
  String _searchKeyword = '';

  List<RegisterModel> get _filteredRegisters {
    if (_selectedGroup == null) return [];
    if (_searchKeyword.isEmpty) return _selectedGroup!.registers;
    return _selectedGroup!.registers.where((r) {
      final addrStr = r.address.toString();
      final aliasStr = (r.displayAlias ?? '').toLowerCase();
      final commentStr = (r.displayComment ?? '').toLowerCase();
      final hexStr = (r.rawValue & 0xFFFF).toRadixString(16).toLowerCase();
      return addrStr.contains(_searchKeyword) ||
          aliasStr.contains(_searchKeyword) ||
          commentStr.contains(_searchKeyword) ||
          hexStr.contains(_searchKeyword);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _initSelection();
    widget.pollingService.onGroupUpdated.listen((updatedGroup) {
      if (mounted && updatedGroup == _selectedGroup) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant RegisterViewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeConnection != widget.activeConnection ||
        _selectedSlave == null ||
        !widget.activeConnection.slaves.contains(_selectedSlave)) {
      _initSelection();
    }
  }

  void _initSelection() {
    if (widget.activeConnection.slaves.isNotEmpty) {
      _selectedSlave = widget.activeConnection.slaves.first;
      _byteOrder = _selectedSlave!.byteOrder;
      if (_selectedSlave!.groups.isNotEmpty) {
        _selectedGroup = _selectedSlave!.groups.first;
      } else {
        _selectedGroup = null;
      }
    } else {
      _selectedSlave = null;
      _selectedGroup = null;
    }
  }

  void _scanCurrentGroup() async {
    if (_selectedSlave == null || _selectedGroup == null) return;
    await widget.pollingService.scanGroup(_selectedSlave!, _selectedGroup!);
    if (mounted) setState(() {});
  }

  void _onEditCell(RegisterModel reg) async {
    if (_selectedGroup == null || _selectedSlave == null) return;

    if (_selectedGroup!.registerType == ModbusRegisterType.coils) {
      final res = await WriteSingleCoilDialog.show(
        context,
        client: widget.client,
        slaveId: _selectedSlave!.slaveId,
        address: reg.address,
        initialValue: reg.rawValue != 0,
      );
      if (res == true) {
        _scanCurrentGroup();
      }
    } else if (_selectedGroup!.registerType == ModbusRegisterType.holdingRegisters) {
      final res = await WriteSingleRegisterDialog.show(
        context,
        client: widget.client,
        slaveId: _selectedSlave!.slaveId,
        address: reg.address,
        initialValue: reg.rawValue,
      );
      if (res == true) {
        _scanCurrentGroup();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedGroup!.registerType.label} (${AppI18n.instance.t('readOnly')})'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onEditAliasAndComment(RegisterModel reg) {
    final aliasCtrl = TextEditingController(text: reg.displayAlias ?? '');
    final commentCtrl = TextEditingController(text: reg.displayComment ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${AppI18n.instance.t('edit')} [${AppI18n.instance.t('colAddr')}: ${reg.address}]'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: aliasCtrl,
              decoration: InputDecoration(
                labelText: AppI18n.instance.t('colAlias'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              decoration: InputDecoration(
                labelText: AppI18n.instance.t('colComment'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppI18n.instance.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final newAlias = aliasCtrl.text.trim();
                if (newAlias.isEmpty) {
                  reg.alias = null;
                  reg.aliasKey = null;
                } else {
                  if (reg.aliasKey != null && newAlias == AppI18n.instance.t(reg.aliasKey!)) {
                    // Kept current translated text
                  } else {
                    reg.aliasKey = null;
                    reg.alias = newAlias;
                  }
                }

                final newComment = commentCtrl.text.trim();
                if (newComment.isEmpty) {
                  reg.comment = null;
                  reg.commentKey = null;
                } else {
                  if (reg.commentKey != null && newComment == AppI18n.instance.t(reg.commentKey!)) {
                    // Kept current translated text
                  } else {
                    reg.commentKey = null;
                    reg.comment = newComment;
                  }
                }
              });
              widget.onConfigChanged();
              Navigator.of(ctx).pop();
            },
            child: Text(AppI18n.instance.t('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeConnection.slaves.isEmpty) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.device_unknown, size: 64, color: Colors.blueGrey),
                const SizedBox(height: 16),
                Text(
                  AppI18n.instance.t('noSlaveHint'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(AppI18n.instance.t('noSlaveHint'), style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(AppI18n.instance.t('newSlave')),
                  onPressed: widget.onAddSlave,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_selectedSlave == null || !widget.activeConnection.slaves.contains(_selectedSlave)) {
      _selectedSlave = widget.activeConnection.slaves.first;
    }

    if (_selectedGroup == null || !_selectedSlave!.groups.contains(_selectedGroup)) {
      _selectedGroup = _selectedSlave!.groups.isNotEmpty ? _selectedSlave!.groups.first : null;
    }

    final theme = Theme.of(context);
    final i18n = AppI18n.instance;

    final activeConnDesc = widget.activeConnection.mode == ModbusTransportMode.serialRtu
        ? (widget.activeConnection.serialPortName ?? i18n.t('serialPort'))
        : (widget.activeConnection.mode == ModbusTransportMode.virtual ? i18n.t('virtualSim') : '${widget.activeConnection.ip}:${widget.activeConnection.port}');

    return Column(
      children: [
        // Top Toolbar (Compact, horizontal scroll, hover tooltips)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 1. Connection Dropdown (width: 195, height: 32)
                Tooltip(
                  message: '${widget.activeConnection.displayName} ($activeConnDesc)',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 195,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        Icon(Icons.hub, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ConnectionConfig>(
                              isExpanded: true,
                              isDense: true,
                              menuWidth: 320,
                              menuMaxHeight: 400,
                              value: widget.connections.contains(widget.activeConnection) ? widget.activeConnection : null,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                              items: widget.connections.map((c) {
                                final desc = c.mode == ModbusTransportMode.serialRtu
                                    ? (c.serialPortName ?? i18n.t('serialPort'))
                                    : (c.mode == ModbusTransportMode.virtual ? i18n.t('virtualSim') : '${c.ip}:${c.port}');
                                final text = '${c.displayName} ($desc)';
                                return DropdownMenuItem(
                                  value: c,
                                  child: Tooltip(
                                    message: text,
                                    waitDuration: const Duration(milliseconds: 150),
                                    child: Text(text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                  ),
                                );
                              }).toList(),
                              onChanged: (c) {
                                if (c != null && c != widget.activeConnection) {
                                  widget.onSelectConnection(c);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Slave Dropdown (width: 175, height: 32)
                Tooltip(
                  message: _selectedSlave != null
                      ? '${_selectedSlave!.displayName} [ID: ${_selectedSlave!.slaveId}]'
                      : i18n.t('selectSlave'),
                  waitDuration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 175,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        const Icon(Icons.developer_board, size: 16, color: Colors.teal),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<SlaveModel>(
                              isExpanded: true,
                              isDense: true,
                              menuWidth: 280,
                              menuMaxHeight: 400,
                              value: _selectedSlave,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                              items: widget.activeConnection.slaves.map((s) {
                                final text = '${s.displayName} [ID: ${s.slaveId}]';
                                return DropdownMenuItem(
                                  value: s,
                                  child: Tooltip(
                                    message: text,
                                    waitDuration: const Duration(milliseconds: 150),
                                    child: Text(text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                  ),
                                );
                              }).toList(),
                              onChanged: (s) {
                                setState(() {
                                  _selectedSlave = s;
                                  _byteOrder = s?.byteOrder ?? ModbusByteOrder.abcd;
                                  _selectedGroup = s?.groups.isNotEmpty == true ? s!.groups.first : null;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Group Dropdown (width: 220, height: 32)
                if (_selectedSlave != null && _selectedSlave!.groups.isNotEmpty) ...[
                  Tooltip(
                    message: _selectedGroup != null
                        ? '${_selectedGroup!.displayGroupName} [${_selectedGroup!.registerType.prefix}] (${_selectedGroup!.quantity} ${i18n.t("pointsCount")})'
                        : i18n.t('selectGroup'),
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 220,
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        children: [
                          Icon(Icons.folder_open, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<RegisterGroupModel>(
                                isExpanded: true,
                                isDense: true,
                                menuWidth: 340,
                                menuMaxHeight: 400,
                                value: _selectedGroup,
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                                items: _selectedSlave!.groups.map((g) {
                                  final text = '${g.displayGroupName} [${g.registerType.prefix}] (${g.quantity})';
                                  return DropdownMenuItem(
                                    value: g,
                                    child: Tooltip(
                                      message: text,
                                      waitDuration: const Duration(milliseconds: 150),
                                      child: Text(text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (g) => setState(() => _selectedGroup = g),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // 4. Byte Order Dropdown (width: 140, height: 32)
                Tooltip(
                  message: '${i18n.t("byteOrder")}: ${_byteOrder.label}',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 140,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, size: 16, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ModbusByteOrder>(
                              isExpanded: true,
                              isDense: true,
                              value: _byteOrder,
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                              items: ModbusByteOrder.values.map((order) {
                                return DropdownMenuItem(
                                  value: order,
                                  child: Tooltip(
                                    message: order.label,
                                    waitDuration: const Duration(milliseconds: 150),
                                    child: Text(
                                      order.name.toUpperCase(),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _byteOrder = v;
                                    _selectedSlave?.byteOrder = v;
                                  });
                                  widget.onConfigChanged();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 5. Search box (width: 160, height: 32)
                Tooltip(
                  message: i18n.t('searchHint'),
                  waitDuration: const Duration(milliseconds: 300),
                  child: SizedBox(
                    width: 160,
                    height: 32,
                    child: TextField(
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: i18n.t('searchHint'),
                        hintStyle: TextStyle(fontSize: 12, color: theme.hintColor),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onChanged: (v) => setState(() => _searchKeyword = v.trim().toLowerCase()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 6. Scan Once button
                Tooltip(
                  message: i18n.t('scanOnce'),
                  waitDuration: const Duration(milliseconds: 300),
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      minimumSize: const Size(0, 32),
                      maximumSize: const Size(double.infinity, 32),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(i18n.t('scanOnce')),
                    onPressed: _scanCurrentGroup,
                  ),
                ),
                const SizedBox(width: 8),

                // 7. Batch Write (if holding registers)
                if (_selectedGroup?.registerType == ModbusRegisterType.holdingRegisters) ...[
                  Tooltip(
                    message: i18n.t('batchFillTitle'),
                    waitDuration: const Duration(milliseconds: 300),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        minimumSize: const Size(0, 32),
                        maximumSize: const Size(double.infinity, 32),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      icon: const Icon(Icons.playlist_add_check, size: 16),
                      label: Text(i18n.t('batchFill')),
                      onPressed: () async {
                        if (_selectedSlave == null || _selectedGroup == null) return;
                        final res = await WriteMultipleRegistersDialog.show(
                          context,
                          client: widget.client,
                          slaveId: _selectedSlave!.slaveId,
                          startAddress: _selectedGroup!.startAddress,
                        );
                        if (res == true) _scanCurrentGroup();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // 8. Edit Group button
                if (_selectedGroup != null)
                  Tooltip(
                    message: i18n.t('editGroup'),
                    waitDuration: const Duration(milliseconds: 300),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(Icons.settings),
                        onPressed: () async {
                          final res = await EditGroupDialog.show(context, group: _selectedGroup);
                          if (res != null) {
                            setState(() {});
                            widget.onConfigChanged();
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Group Status Bar (Compact, hover tooltips)
        if (_selectedGroup != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
            child: Row(
              children: [
                Icon(
                  (_selectedGroup!.lastScanStatus?.contains('OK') == true || _selectedGroup!.lastScanStatus?.contains('Success') == true)
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 15,
                  color: (_selectedGroup!.lastScanStatus?.contains('OK') == true || _selectedGroup!.lastScanStatus?.contains('Success') == true)
                      ? Colors.green
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: '${i18n.t('status')}: ${_selectedGroup!.lastScanStatus ?? i18n.t('ready')} | ${i18n.t('latency')}: ${_selectedGroup!.lastLatencyMs}ms | ${i18n.t('statusOk')}: ${_selectedGroup!.successCount} | ${i18n.t('statusErr')}: ${_selectedGroup!.errorCount}',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Text(
                    '${i18n.t('status')}: ${_selectedGroup!.lastScanStatus ?? i18n.t('ready')} | ${_selectedGroup!.lastLatencyMs}ms | OK: ${_selectedGroup!.successCount} | Err: ${_selectedGroup!.errorCount}',
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: '${i18n.t('lastScan')}: ${_selectedGroup!.lastScanTime != null ? _selectedGroup!.lastScanTime.toString().substring(11, 19) : "--:--:--"}',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Text(
                    '${i18n.t('lastScan')}: ${_selectedGroup!.lastScanTime != null ? _selectedGroup!.lastScanTime.toString().substring(11, 19) : "--:--:--"}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                  ),
                ),
              ],
            ),
          ),

        // Main Table (Fixed Column Widths, Hover Tooltips on Header & Cells)
        Expanded(
          child: _selectedGroup == null
              ? Center(child: Text(i18n.t('noGroupHint')))
              : _buildRegistersTable(),
        ),
      ],
    );
  }

  Widget _buildRegistersTable() {
    final theme = Theme.of(context);
    final group = _selectedGroup!;
    final slave = _selectedSlave!;
    final i18n = AppI18n.instance;
    final displayList = _filteredRegisters;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth - 24,
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceVariant.withOpacity(0.25),
                ),
                headingRowHeight: 38,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 40,
                horizontalMargin: 12,
                columnSpacing: 16,
                columns: [
                  DataColumn(
                    tooltip: i18n.t('colAddr'),
                    label: SizedBox(
                      width: 85,
                      child: Tooltip(
                        message: i18n.t('colAddr'),
                        waitDuration: const Duration(milliseconds: 200),
                        child: Text(
                          i18n.t('colAddr'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    tooltip: i18n.t('colAlias'),
                    label: SizedBox(
                      width: 160,
                      child: Tooltip(
                        message: i18n.t('colAlias'),
                        waitDuration: const Duration(milliseconds: 200),
                        child: Text(
                          i18n.t('colAlias'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    tooltip: i18n.t('colHex'),
                    label: SizedBox(
                      width: 85,
                      child: Tooltip(
                        message: i18n.t('colHex'),
                        waitDuration: const Duration(milliseconds: 200),
                        child: Text(
                          i18n.t('colHex'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    tooltip: i18n.t('colValue'),
                    label: SizedBox(
                      width: 130,
                      child: Tooltip(
                        message: i18n.t('colValue'),
                        waitDuration: const Duration(milliseconds: 200),
                        child: Text(
                          i18n.t('colValue'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    tooltip: i18n.t('dataFormat'),
                    label: SizedBox(
                      width: 140,
                      child: Tooltip(
                        message: i18n.t('dataFormat'),
                        waitDuration: const Duration(milliseconds: 200),
                        child: Text(
                          i18n.t('dataFormat'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    tooltip: i18n.t('colComment'),
                    label: SizedBox(
                      width: 180,
                      child: Tooltip(
                        message: i18n.t('colComment'),
                        waitDuration: const Duration(milliseconds: 200),
                        child: Text(
                          i18n.t('colComment'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    tooltip: i18n.t('colAction'),
                    label: SizedBox(
                      width: 80,
                      child: Tooltip(
                        message: i18n.t('colAction'),
                        waitDuration: const Duration(milliseconds: 200),
                        child: Text(
                          i18n.t('colAction'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
                rows: displayList.map((reg) {
                  final idx = group.registers.indexOf(reg);
                  final neighborWords = <int>[];
                  if (idx >= 0) {
                    for (int k = idx + 1; k < group.registers.length && k <= idx + 4; k++) {
                      neighborWords.add(group.registers[k].rawValue);
                    }
                  }

                  final displayStr = reg.getDisplayValue(_byteOrder, neighborWords);
                  final hexStr = '0x${(reg.rawValue & 0xFFFF).toRadixString(16).padLeft(4, "0").toUpperCase()}';
                  final formattedAddr = slave.formatAddress(reg.address, group.registerType);
                  final isCoilOrDiscrete = group.registerType == ModbusRegisterType.coils ||
                      group.registerType == ModbusRegisterType.discreteInputs;

                  return DataRow(
                    cells: [
                      // 1. Address
                      DataCell(
                        SizedBox(
                          width: 85,
                          child: Tooltip(
                            message: '$formattedAddr (${reg.address})',
                            waitDuration: const Duration(milliseconds: 200),
                            child: Text(
                              '$formattedAddr (${reg.address})',
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        onDoubleTap: () => _onEditAliasAndComment(reg),
                      ),

                      // 2. Alias
                      DataCell(
                        SizedBox(
                          width: 160,
                          child: Tooltip(
                            message: reg.displayAlias ?? '-',
                            waitDuration: const Duration(milliseconds: 200),
                            child: InkWell(
                              onTap: () => _onEditAliasAndComment(reg),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      reg.displayAlias ?? 'Point',
                                      style: TextStyle(
                                        color: (reg.alias != null || reg.aliasKey != null) ? theme.colorScheme.primary : Colors.grey,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 13, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 3. Hex
                      DataCell(
                        SizedBox(
                          width: 85,
                          child: Tooltip(
                            message: hexStr,
                            waitDuration: const Duration(milliseconds: 200),
                            child: Text(
                              hexStr,
                              style: const TextStyle(fontFamily: 'monospace', color: Colors.blueGrey, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),

                      // 4. Value
                      DataCell(
                        SizedBox(
                          width: 130,
                          child: Tooltip(
                            message: '$displayStr (${i18n.t("colValue")})',
                            waitDuration: const Duration(milliseconds: 200),
                            child: InkWell(
                              onDoubleTap: () => _onEditCell(reg),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  displayStr,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isCoilOrDiscrete
                                        ? (reg.rawValue != 0 ? Colors.green : Colors.grey)
                                        : theme.colorScheme.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 5. Data Format Dropdown
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Tooltip(
                            message: reg.valueFormat.label,
                            waitDuration: const Duration(milliseconds: 200),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<RegisterDataFormat>(
                                isExpanded: true,
                                isDense: true,
                                value: reg.valueFormat,
                                items: RegisterDataFormat.values.map((f) {
                                  return DropdownMenuItem(
                                    value: f,
                                    child: Text(
                                      f.label,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (fmt) {
                                  if (fmt != null) {
                                    setState(() {
                                      reg.valueFormat = fmt;
                                    });
                                    widget.onConfigChanged();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 6. Comment
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Tooltip(
                            message: reg.displayComment ?? '-',
                            waitDuration: const Duration(milliseconds: 200),
                            child: InkWell(
                              onTap: () => _onEditAliasAndComment(reg),
                              child: Text(
                                reg.displayComment ?? '-',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 7. Action
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (group.registerType == ModbusRegisterType.coils)
                                IconButton(
                                  icon: Icon(
                                    reg.rawValue != 0 ? Icons.toggle_on : Icons.toggle_off,
                                    color: reg.rawValue != 0 ? Colors.green : Colors.grey,
                                    size: 26,
                                  ),
                                  tooltip: i18n.t('colAction'),
                                  onPressed: () async {
                                    final nextVal = reg.rawValue == 0;
                                    try {
                                      await widget.client.writeSingleCoil(
                                        unitId: slave.slaveId,
                                        address: reg.address,
                                        value: nextVal,
                                      );
                                      _scanCurrentGroup();
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('${i18n.t('parseError')}: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              if (group.registerType == ModbusRegisterType.holdingRegisters)
                                IconButton(
                                  icon: Icon(Icons.edit, size: 16, color: theme.colorScheme.primary),
                                  tooltip: i18n.t('edit'),
                                  onPressed: () => _onEditCell(reg),
                                ),
                              if (group.registerType == ModbusRegisterType.discreteInputs ||
                                  group.registerType == ModbusRegisterType.inputRegisters)
                                Tooltip(
                                  message: i18n.t('readOnly'),
                                  waitDuration: const Duration(milliseconds: 200),
                                  child: Chip(
                                    label: Text(i18n.t('readOnly'), style: const TextStyle(fontSize: 10)),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
