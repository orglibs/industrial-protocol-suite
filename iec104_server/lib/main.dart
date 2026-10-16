import 'package:flutter/material.dart';
import 'src/i18n/app_i18n.dart';
import 'src/server/iec104_server.dart';
import 'src/ui/home_screen.dart';
import 'src/ui/widgets/window_title_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowManagerHelper.initialize();

  // Instantiate the core IEC 104 Server
  final server = Iec104Server();
  await server.loadWorkspace();

  // Core IEC 104 Server does not start automatically by default; started manually via UI.
  runApp(Iec104SimulatorApp(server: server));
}

class Iec104SimulatorApp extends StatefulWidget {
  final Iec104Server server;

  const Iec104SimulatorApp({super.key, required this.server});

  @override
  State<Iec104SimulatorApp> createState() => _Iec104SimulatorAppState();
}

class _Iec104SimulatorAppState extends State<Iec104SimulatorApp> {
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
          server: widget.server,
          onToggleTheme: _toggleTheme,
          isDarkMode: _themeMode == ThemeMode.dark,
          onLanguageChanged: _onLanguageChanged,
        ),
      ),
    );
  }
}
