import 'package:flutter/material.dart';
import 'src/server/iec104_server.dart';
import 'src/ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Instantiate the core IEC 104 Server
  final server = Iec104Server();
  await server.loadWorkspace();

  // Auto-start server on port 2404
  try {
    await server.start();
  } catch (e) {
    debugPrint('Auto-start server error: $e');
  }

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IEC 60870-5-104 Server Simulator',
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
      home: HomeScreen(
        server: widget.server,
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}
