import '../../i18n/app_i18n.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/client_variable_model.dart';

class ControlOperationDialog extends StatefulWidget {
  final ClientVariableModel variable;
  final Future<bool> Function(ClientVariableModel variable, dynamic value, {bool isSbo}) onOperate;

  const ControlOperationDialog({
    super.key,
    required this.variable,
    required this.onOperate,
  });

  @override
  State<ControlOperationDialog> createState() => _ControlOperationDialogState();
}

class _ControlOperationDialogState extends State<ControlOperationDialog> {
  bool _isSbo = true;
  bool _commandVal = true; // true = 合闸 / ON, false = 分闸 / OFF
  bool _synchroCheck = true;
  bool _interlockCheck = true;

  bool _isSelecting = false;
  bool _isOperating = false;
  bool _isSelectSuccess = false;
  int _sboRemainingSeconds = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Default to SBO if controllable point
    _isSbo = widget.variable.ctlModel == null || widget.variable.ctlModel == 2 || widget.variable.ctlModel == 4;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _doSelect() async {
    setState(() {
      _isSelecting = true;
    });

    try {
      final ok = await widget.onOperate(widget.variable, _commandVal, isSbo: true);
      if (ok && mounted) {
        setState(() {
          _isSelectSuccess = true;
          _sboRemainingSeconds = 10;
        });

        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (_sboRemainingSeconds > 0) {
            setState(() => _sboRemainingSeconds--);
          } else {
            t.cancel();
            setState(() => _isSelectSuccess = false);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  void _doOperate() async {
    setState(() {
      _isOperating = true;
    });

    try {
      final ok = await widget.onOperate(widget.variable, _commandVal, isSbo: false);
      if (ok && mounted) {
        _countdownTimer?.cancel();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppI18n.instance.t("commandResult")}: ${widget.variable.shortRef} -> ${_commandVal ? AppI18n.instance.t("switchOn") : AppI18n.instance.t("switchOff")}'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.power_settings_new, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(i18n.t('controlWinTitle')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Target Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.variable.shortRef,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MMS Reference: ${widget.variable.reference}',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Chip(
                          label: Text('FC: ${widget.variable.fcCode}', style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 8),
                        Text('${i18n.t("currValue")}: ${widget.variable.displayValue}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Control Mode Selection
              Row(
                children: [
                  Text(i18n.t('controlModel'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: Text(i18n.t('sboMode')),
                    selected: _isSbo,
                    onSelected: (sel) {
                      if (sel) setState(() => _isSbo = true);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(i18n.t('directMode')),
                    selected: !_isSbo,
                    onSelected: (sel) {
                      if (sel) setState(() => _isSbo = false);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Command Value Selection
              Text(i18n.t('controlCmd'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _commandVal ? Colors.red[700] : null,
                        foregroundColor: _commandVal ? Colors.white : null,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.flash_on),
                      label: Text(i18n.t('cmdClose'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => setState(() => _commandVal = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_commandVal ? Colors.green[700] : null,
                        foregroundColor: !_commandVal ? Colors.white : null,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.flash_off),
                      label: Text(i18n.t('cmdTrip'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => setState(() => _commandVal = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Check Conditions
              Text(i18n.t('checkConditions'), style: const TextStyle(fontWeight: FontWeight.w600)),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(i18n.t('synchroCheck')),
                value: _synchroCheck,
                onChanged: (val) => setState(() => _synchroCheck = val ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(i18n.t('interlockCheck')),
                value: _interlockCheck,
                onChanged: (val) => setState(() => _interlockCheck = val ?? false),
              ),

              if (_isSbo && _isSelectSuccess) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SBO ($_sboRemainingSeconds s) -> ${i18n.t("step2Operate")}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n.t('cancel')),
        ),
        if (_isSbo) ...[
          OutlinedButton.icon(
            icon: _isSelecting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.touch_app),
            label: Text(i18n.t('step1Select')),
            onPressed: _isSelecting || _isSelectSuccess ? null : _doSelect,
          ),
          FilledButton.icon(
            icon: _isOperating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow),
            label: Text(i18n.t('step2Operate')),
            onPressed: _isSelectSuccess && !_isOperating ? _doOperate : null,
          ),
        ] else ...[
          FilledButton.icon(
            icon: _isOperating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
            label: Text(i18n.t('operateNow')),
            onPressed: _isOperating ? null : _doOperate,
          ),
        ],
      ],
    );
  }
}
