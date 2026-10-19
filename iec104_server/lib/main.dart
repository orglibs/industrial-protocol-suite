import 'package:flutter/material.dart';
import 'src/i18n/app_i18n.dart';
import 'src/models/app_settings.dart';
import 'src/models/connection_config.dart';
import 'src/server/iec104_server.dart';
import 'src/server/workspace_storage.dart';
import 'src/ui/home_screen.dart';
import 'src/ui/widgets/window_title_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowManagerHelper.initialize();

  // Load app settings (language and theme)
  final settings = await AppSettingsStorage.load();
  AppI18n.instance.setLanguage(settings.language);

  // Load connections from workspace storage (with auto-migration from legacy single server)
  final connections = await WorkspaceStorage.loadConnections();

  runApp(Iec104SimulatorApp(
    initialConnections: connections,
    initialThemeMode: settings.themeMode,
  ));
}

class Iec104SimulatorApp extends StatefulWidget {
  final List<Iec104ConnectionConfig>? initialConnections;
  final Iec104Server? server;
  final ThemeMode? initialThemeMode;

  const Iec104SimulatorApp({
    super.key,
    this.initialConnections,
    this.server,
    this.initialThemeMode,
  });

  @override
  State<Iec104SimulatorApp> createState() => _Iec104SimulatorAppState();
}

class _Iec104SimulatorAppState extends State<Iec104SimulatorApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode ?? ThemeMode.dark;
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = (_themeMode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    });
    AppSettingsStorage.saveThemeMode(_themeMode);
  }

  void _onLanguageChanged() {
    setState(() {});
    AppSettingsStorage.saveLanguage(AppI18n.instance.currentLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;

    return MaterialApp(
      title: i18n.t('appTitle'),
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
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
      home: Directionality(
        textDirection: i18n.currentLanguage.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: HomeScreen(
          initialConnections: widget.initialConnections,
          server: widget.server,
          onToggleTheme: _toggleTheme,
          isDarkMode: _themeMode == ThemeMode.dark,
          onLanguageChanged: _onLanguageChanged,
        ),
      ),
    );
  }
}
