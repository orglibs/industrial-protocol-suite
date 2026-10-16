import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowManagerHelper {
  static bool isInitialized = false;

  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static Future<void> initialize() async {
    if (!isSupportedPlatform) return;
    try {
      await windowManager.ensureInitialized();
      isInitialized = true;
      const windowOptions = WindowOptions(
        size: Size(1280, 750),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint('WindowManager init warning: $e');
    }
  }

  static void minimize() {
    if (isInitialized) {
      try {
        windowManager.minimize();
      } catch (_) {}
    }
  }

  static Future<void> toggleMaximize() async {
    if (isInitialized) {
      try {
        final isMax = await windowManager.isMaximized();
        if (isMax) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      } catch (_) {}
    }
  }

  static void close() {
    if (isInitialized) {
      try {
        windowManager.close();
      } catch (_) {}
    }
  }
}

class WindowControls extends StatefulWidget {
  final Brightness brightness;

  const WindowControls({super.key, required this.brightness});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> {
  bool _isCloseHovered = false;
  bool _isMaxHovered = false;
  bool _isMinHovered = false;

  @override
  Widget build(BuildContext context) {
    if (!WindowManagerHelper.isSupportedPlatform) {
      return const SizedBox.shrink();
    }

    final isDark = widget.brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white70 : Colors.black87;
    final hoverBg = isDark ? Colors.white12 : Colors.black12;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Minimize
        MouseRegion(
          onEnter: (_) => setState(() => _isMinHovered = true),
          onExit: (_) => setState(() => _isMinHovered = false),
          child: GestureDetector(
            onTap: WindowManagerHelper.minimize,
            child: Container(
              width: 42,
              alignment: Alignment.center,
              color: _isMinHovered ? hoverBg : Colors.transparent,
              child: Icon(Icons.remove, size: 16, color: iconColor),
            ),
          ),
        ),
        // Maximize / Restore
        MouseRegion(
          onEnter: (_) => setState(() => _isMaxHovered = true),
          onExit: (_) => setState(() => _isMaxHovered = false),
          child: GestureDetector(
            onTap: WindowManagerHelper.toggleMaximize,
            child: Container(
              width: 42,
              alignment: Alignment.center,
              color: _isMaxHovered ? hoverBg : Colors.transparent,
              child: Icon(Icons.crop_square, size: 14, color: iconColor),
            ),
          ),
        ),
        // Close Button
        MouseRegion(
          onEnter: (_) => setState(() => _isCloseHovered = true),
          onExit: (_) => setState(() => _isCloseHovered = false),
          child: GestureDetector(
            onTap: WindowManagerHelper.close,
            child: Container(
              width: 46,
              alignment: Alignment.center,
              color: _isCloseHovered ? const Color(0xFFE81123) : Colors.transparent,
              child: Icon(
                Icons.close,
                size: 16,
                color: _isCloseHovered ? Colors.white : iconColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
