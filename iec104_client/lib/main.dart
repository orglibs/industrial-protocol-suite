import 'package:flutter/material.dart';
import 'src/client/iec104_client.dart';
import 'src/ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = Iec104Client();
  await client.loadWorkspace();

  runApp(Iec104ClientApp(client: client));
}

class Iec104ClientApp extends StatefulWidget {
  final Iec104Client client;

  const Iec104ClientApp({super.key, required this.client});

  @override
  State<Iec104ClientApp> createState() => _Iec104ClientAppState();
}

class _Iec104ClientAppState extends State<Iec104ClientApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = (_themeMode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IEC 60870-5-104 Client Simulator',
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
        client: widget.client,
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}
