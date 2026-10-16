import 'package:flutter/material.dart';
import 'src/ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Iec61850App());
}

class Iec61850App extends StatefulWidget {
  const Iec61850App({super.key});

  @override
  State<Iec61850App> createState() => _Iec61850AppState();
}

class _Iec61850AppState extends State<Iec61850App> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IEC 61850 MMS & GOOSE Server Simulator',
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
      home: HomeScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}
