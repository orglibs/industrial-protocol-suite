import 'package:flutter/material.dart';
import 'src/i18n/app_i18n.dart';
import 'src/ui/home_screen.dart';
import 'src/ui/widgets/window_title_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowManagerHelper.initialize();
  runApp(const ModbusMasterApp());
}

class ModbusMasterApp extends StatefulWidget {
  const ModbusMasterApp({super.key});

  @override
  State<ModbusMasterApp> createState() => _ModbusMasterAppState();
}

class _ModbusMasterAppState extends State<ModbusMasterApp> {
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
          onToggleTheme: _toggleTheme,
          isDarkMode: _themeMode == ThemeMode.dark,
          onLanguageChanged: _onLanguageChanged,
        ),
      ),
    );
  }
}
