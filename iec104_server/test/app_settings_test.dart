import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iec104_server/src/i18n/app_i18n.dart';
import 'package:iec104_server/src/models/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('iec104_server AppSettings & Persistence Tests', () {
    late Directory tempDir;
    late String customSettingsFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('iec104_server_settings_test_');
      customSettingsFile = '${tempDir.path}/app_settings.json';
      AppSettingsStorage.setCustomSettingsFilePath(customSettingsFile);
    });

    tearDown(() {
      AppSettingsStorage.setCustomSettingsFilePath(null);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('AppLanguage.fromCode parses valid codes and falls back safely', () {
      expect(AppLanguage.fromCode('zh-CN'), equals(AppLanguage.zhCN));
      expect(AppLanguage.fromCode('en-US'), equals(AppLanguage.enUS));
      expect(AppLanguage.fromCode('de-DE'), equals(AppLanguage.deDE));
      expect(AppLanguage.fromCode('ja-JP'), equals(AppLanguage.jaJP));
      expect(AppLanguage.fromCode('zh'), equals(AppLanguage.zhCN));
      expect(AppLanguage.fromCode('en'), equals(AppLanguage.enUS));
      expect(AppLanguage.fromCode(null), isNotNull);
    });

    test('Loads default settings when file does not exist', () async {
      final settings = await AppSettingsStorage.load();
      expect(settings.themeMode, equals(ThemeMode.dark));
      expect(settings.language, isNotNull);
    });

    test('Persists and restores language and theme mode', () async {
      // 1. Save language
      final ok1 = await AppSettingsStorage.saveLanguage(AppLanguage.deDE);
      expect(ok1, isTrue);

      var loaded = await AppSettingsStorage.load();
      expect(loaded.language, equals(AppLanguage.deDE));
      expect(loaded.themeMode, equals(ThemeMode.dark));

      // 2. Save theme mode
      final ok2 = await AppSettingsStorage.saveThemeMode(ThemeMode.light);
      expect(ok2, isTrue);

      loaded = await AppSettingsStorage.load();
      expect(loaded.language, equals(AppLanguage.deDE));
      expect(loaded.themeMode, equals(ThemeMode.light));

      // 3. Switch language to zh-CN
      await AppSettingsStorage.saveLanguage(AppLanguage.zhCN);
      loaded = await AppSettingsStorage.load();
      expect(loaded.language, equals(AppLanguage.zhCN));
      expect(loaded.themeMode, equals(ThemeMode.light));
    });
  });
}
