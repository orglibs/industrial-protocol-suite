import 'package:flutter/material.dart';
import 'src/i18n/app_i18n.dart';
import 'src/ui/home_screen.dart';
import 'src/ui/widgets/window_title_bar.dart';

import 'src/models/server_config.dart';
import 'src/models/app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowManagerHelper.initialize();
  final settings = await AppSettingsStorage.load();
  AppI18n.instance.setLanguage(settings.language);
  runApp(Iec61850App(initialThemeMode: settings.themeMode));
}

class Iec61850App extends StatefulWidget {
  final List<ServerConfig>? initialConnections;
  final ThemeMode? initialThemeMode;

  const Iec61850App({super.key, this.initialConnections, this.initialThemeMode});

  @override
  State<Iec61850App> createState() => _Iec61850AppState();
}

class _Iec61850AppState extends State<Iec61850App> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode ?? ThemeMode.dark;
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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
          seedColor: const Color(0xFF007ACC),
          brightness: Brightness.light,
        ),
        cardTheme: const CardThemeData(
          elevation: 1,
          margin: EdgeInsets.zero,
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFFF3F4F6),
          indicatorColor: Color(0xFF007ACC),
          selectedIconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E639C),
          brightness: Brightness.dark,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF252526),
          elevation: 2,
          margin: EdgeInsets.zero,
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFF181818),
          indicatorColor: Color(0xFF0E639C),
          selectedIconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: Directionality(
        textDirection: i18n.currentLanguage.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: HomeScreen(
          initialConnections: widget.initialConnections,
          onToggleTheme: _toggleTheme,
          isDarkMode: _themeMode == ThemeMode.dark,
          onLanguageChanged: _onLanguageChanged,
        ),
      ),
    );
  }
}
