import 'dart:async';
import 'package:flutter/material.dart';
import '../../client/iec104_client.dart';
import '../../client/station_data.dart';
import '../../protocol/asdu.dart';

class CommandsTab extends StatefulWidget {
  final Iec104Client client;

  const CommandsTab({super.key, required this.client});

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

  @override
  void initState() {
    super.initState();
    if (widget.client.stations.isNotEmpty) {
      _ca = widget.client.stations.keys.first;
    }
    _cmdSub = widget.client.commandResultStream.listen((event) {
      if (mounted) {
        setState(() {
          _history.insert(0, event);
          if (_history.length > 50) _history.removeLast();
        });
      }
    });
    _stateSub = widget.client.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _stationSub = widget.client.stationsStream.listen((_) {
      if (mounted) setState(() {});
    });
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

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final isActive = c.state == ClientConnectionState.active;
    final availableCas = {...c.stations.keys, 65535}.toList()..sort();
    if (!availableCas.contains(_ca)) {
      _ca = availableCas.first;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Command Panels
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CA Selector
                Row(
                  children: [
                    const Text('目标公共地址 (COA): ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    DropdownButton<int>(
                      value: _ca,
                      items: availableCas.map((ca) {
                        final stName = c.stations[ca]?.name;
                        final label = stName != null
                            ? 'CA=$ca ($stName)'
                            : (ca == 65535 ? 'CA=65535 (全局广播)' : 'CA=$ca');
                        return DropdownMenuItem(value: ca, child: Text(label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _ca = val);
                      },
                    ),
                    const Spacer(),
                    if (!isActive)
                      const Text(
                        '提示: 请先建立连接并激活链路 (STARTDT)',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Group 1: General Commands
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('常用系统召唤与同步命令', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.sync),
                              label: const Text('全站总召唤 (C_IC_NA_1)'),
                              onPressed: isActive ? () => c.sendGeneralInterrogation(ca: _ca, qoi: 20) : null,
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.access_time),
                              label: const Text('时钟同步 (C_CS_NA_1)'),
                              onPressed: isActive ? () => c.sendClockSynchronization(ca: _ca) : null,
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.flash_on),
                              label: const Text('电能量总召 (C_CI_NA_1)'),
                              onPressed: isActive ? () => c.sendCounterInterrogation(ca: _ca, rqt: 5) : null,
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('复位进程 (C_RP_NA_1)'),
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
                        const Text('单命令遥控 (C_SC_NA_1, Type 45)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _scIoaCtrl,
                                decoration: const InputDecoration(labelText: '信息对象地址 (IOA)', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: false, label: Text('分闸 (OFF)')),
                                ButtonSegment(value: true, label: Text('合闸 (ON)')),
                              ],
                              selected: {_scVal},
                              onSelectionChanged: (val) => setState(() => _scVal = val.first),
                            ),
                            const SizedBox(width: 12),
                            Checkbox(
                              value: _scSelect,
                              onChanged: (val) => setState(() => _scSelect = val ?? false),
                            ),
                            const Text('预置选择(S/E)'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.send),
                              label: Text(_scSelect ? '发送单命令预置选择 (Select)' : '发送单命令直接执行 (Execute)'),
                              onPressed: isActive
                                  ? () {
                                      final ioa = int.tryParse(_scIoaCtrl.text.trim()) ?? 1;
                                      c.sendSingleCommand(ca: _ca, ioa: ioa, value: _scVal, select: _scSelect);
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
                        const Text('双命令遥控 (C_DC_NA_1, Type 46)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _dcIoaCtrl,
                                decoration: const InputDecoration(labelText: '信息对象地址 (IOA)', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 1, label: Text('分闸 (01)')),
                                ButtonSegment(value: 2, label: Text('合闸 (10)')),
                              ],
                              selected: {_dcVal},
                              onSelectionChanged: (val) => setState(() => _dcVal = val.first),
                            ),
                            const SizedBox(width: 12),
                            Checkbox(
                              value: _dcSelect,
                              onChanged: (val) => setState(() => _dcSelect = val ?? false),
                            ),
                            const Text('预置选择(S/E)'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send),
                          label: Text(_dcSelect ? '发送双命令预置选择' : '发送双命令直接执行'),
                          onPressed: isActive
                              ? () {
                                  final ioa = int.tryParse(_dcIoaCtrl.text.trim()) ?? 10;
                                  c.sendDoubleCommand(ca: _ca, ioa: ioa, value: _dcVal, select: _dcSelect);
                                }
                              : null,
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
                        const Text('步调节命令 (C_RC_NA_1, Type 47)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _rcIoaCtrl,
                                decoration: const InputDecoration(labelText: '信息对象地址 (IOA)', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 1, label: Text('降一步 (1)')),
                                ButtonSegment(value: 2, label: Text('升一步 (2)')),
                              ],
                              selected: {_rcStep},
                              onSelectionChanged: (val) => setState(() => _rcStep = val.first),
                            ),
                            const SizedBox(width: 12),
                            Checkbox(
                              value: _rcSelect,
                              onChanged: (val) => setState(() => _rcSelect = val ?? false),
                            ),
                            const Text('预置选择'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send),
                          label: const Text('发送步调节命令'),
                          onPressed: isActive
                              ? () {
                                  final ioa = int.tryParse(_rcIoaCtrl.text.trim()) ?? 30;
                                  c.sendStepCommand(ca: _ca, ioa: ioa, step: _rcStep, select: _rcSelect);
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Group 5: Short Float Setpoint (C_SE_NC_1) & Read (C_RD_NA_1)
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('短浮点设定值 (C_SE_NC_1)', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _seIoaCtrl,
                                decoration: const InputDecoration(labelText: 'IOA', border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _seValCtrl,
                                decoration: const InputDecoration(labelText: '设定值 (Float)', border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _seSelect,
                                    onChanged: (val) => setState(() => _seSelect = val ?? false),
                                  ),
                                  const Text('预置选择'),
                                  const Spacer(),
                                  ElevatedButton(
                                    onPressed: isActive
                                        ? () {
                                            final ioa = int.tryParse(_seIoaCtrl.text.trim()) ?? 16385;
                                            final val = double.tryParse(_seValCtrl.text.trim()) ?? 0.0;
                                            c.sendSetpointFloat(ca: _ca, ioa: ioa, value: val, select: _seSelect);
                                          }
                                        : null,
                                    child: const Text('下发设定值'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('读单点命令 (C_RD_NA_1)', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _rdIoaCtrl,
                                decoration: const InputDecoration(labelText: '读取目标 IOA', border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 8),
                              const Text('向从站索取指定 IOA 的最新当前值'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: isActive
                                    ? () {
                                        final ioa = int.tryParse(_rdIoaCtrl.text.trim()) ?? 16385;
                                        c.sendReadCommand(ca: _ca, ioa: ioa);
                                      }
                                    : null,
                                child: const Text('下发读单点'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Right Column: Command Feedback & Log
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    const Text('命令反馈日志 (Command Responses)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      tooltip: '清空反馈',
                      onPressed: () => setState(() => _history.clear()),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: _history.isEmpty
                      ? const Center(child: Text('暂无命令回执', style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          itemCount: _history.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final ev = _history[idx];
                            final timeStr = ev.timestamp.toIso8601String().substring(11, 23);
                            return ListTile(
                              dense: true,
                              title: Text(ev.message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text('$timeStr | COT: ${ev.cot.description}'),
                              leading: Icon(
                                ev.cot == CauseOfTransmission.activationConfirmation || ev.cot == CauseOfTransmission.activationTermination
                                    ? Icons.check_circle_outline
                                    : Icons.info_outline,
                                color: ev.cot == CauseOfTransmission.activationConfirmation
                                    ? Colors.green
                                    : (ev.cot == CauseOfTransmission.activationTermination ? Colors.blue : Colors.orange),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
