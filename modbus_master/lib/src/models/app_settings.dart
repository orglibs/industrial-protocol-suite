import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../i18n/app_i18n.dart';
import 'workspace_storage.dart';

const bool kIsWeb = identical(0, 0.0);

class AppSettings {
  final AppLanguage language;
  final ThemeMode themeMode;

  const AppSettings({
    required this.language,
    required this.themeMode,
  });

  Map<String, dynamic> toJson() => {
        'language': language.code,
        'themeMode': themeMode == ThemeMode.dark ? 'dark' : 'light',
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final langStr = json['language'] as String?;
    final themeStr = json['themeMode'] as String?;
    return AppSettings(
      language: AppLanguage.fromCode(langStr),
      themeMode: (themeStr == 'light') ? ThemeMode.light : ThemeMode.dark,
    );
  }

  AppSettings copyWith({
    AppLanguage? language,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class AppSettingsStorage {
  static String? _customSettingsFilePath;

  /// Allows setting a custom settings file path for testing
  @visibleForTesting
  static void setCustomSettingsFilePath(String? path) {
    _customSettingsFilePath = path;
  }

  static String get settingsFilePath {
    if (_customSettingsFilePath != null) return _customSettingsFilePath!;
    if (kIsWeb) return 'localStorage:modbus_master_settings';
    try {
      final workspacePath = WorkspaceStorage.defaultFilePath;
      final dir = File(workspacePath).parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return Platform.isWindows
          ? '${dir.path}\\app_settings.json'
          : '${dir.path}/app_settings.json';
    } catch (_) {}
    return 'app_settings.json';
  }

  static Future<AppSettings> load() async {
    if (kIsWeb) {
      return AppSettings(
        language: AppLanguage.fromSystem(),
        themeMode: ThemeMode.dark,
      );
    }
    try {
      final path = settingsFilePath;
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final json = jsonDecode(content);
          if (json is Map<String, dynamic>) {
            return AppSettings.fromJson(json);
          }
        }
      }
      // Fallback check settings.json
      final altPath = path.replaceAll('app_settings.json', 'settings.json');
      final altFile = File(altPath);
      if (await altFile.exists()) {
        final content = await altFile.readAsString();
        if (content.trim().isNotEmpty) {
          final json = jsonDecode(content);
          if (json is Map<String, dynamic>) {
            return AppSettings.fromJson(json);
          }
        }
      }
    } catch (_) {}

    return AppSettings(
      language: AppLanguage.fromSystem(),
      themeMode: ThemeMode.dark,
    );
  }

  static Future<bool> save(AppSettings settings) async {
    if (kIsWeb) return false;
    try {
      final path = settingsFilePath;
      final file = File(path);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      final tempFile = File('$path.tmp');
      final jsonStr = const JsonEncoder.withIndent('  ').convert(settings.toJson());
      await tempFile.writeAsString(jsonStr, flush: true);
      await tempFile.rename(path);
      return true;
    } catch (_) {
      try {
        final file = File(settingsFilePath);
        final jsonStr = const JsonEncoder.withIndent('  ').convert(settings.toJson());
        await file.writeAsString(jsonStr, flush: true);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  static Future<bool> saveLanguage(AppLanguage language) async {
    final current = await load();
    return save(current.copyWith(language: language));
  }

  static Future<bool> saveThemeMode(ThemeMode themeMode) async {
    final current = await load();
    return save(current.copyWith(themeMode: themeMode));
  }
}
