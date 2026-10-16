import 'package:flutter/material.dart';
import 'src/i18n/app_i18n.dart';
import 'src/models/connection_config.dart';
import 'src/models/workspace_storage.dart';
import 'src/ui/home_screen.dart';
import 'src/ui/widgets/window_title_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowManagerHelper.initialize();
  final connections = await WorkspaceStorage.loadConnections();
  runApp(ModbusSlaveApp(initialConnections: connections));
}

class ModbusSlaveApp extends StatefulWidget {
  final List<ConnectionConfig> initialConnections;

  const ModbusSlaveApp({super.key, required this.initialConnections});

  @override
  State<ModbusSlaveApp> createState() => _ModbusSlaveAppState();
}

class _ModbusSlaveAppState extends State<ModbusSlaveApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = (_themeMode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void _onLanguageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppI18n.instance.t('appTitle'),
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      builder: (context, child) {
        return Directionality(
          textDirection: AppI18n.instance.currentLanguage.isRtl
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child ?? const SizedBox(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E24),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          color: const Color(0xFF25252D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      home: HomeScreen(
        initialConnections: widget.initialConnections,
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
        onLanguageChanged: _onLanguageChanged,
      ),
    );
  }
}
