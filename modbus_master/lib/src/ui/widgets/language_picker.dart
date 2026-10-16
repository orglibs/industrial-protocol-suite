import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';

class LanguagePickerButton extends StatelessWidget {
  final VoidCallback onLanguageChanged;

  const LanguagePickerButton({super.key, required this.onLanguageChanged});

  @override
  Widget build(BuildContext context) {
    final current = AppI18n.instance.currentLanguage;

    return PopupMenuButton<AppLanguage>(
      tooltip: '${AppI18n.instance.t('langName')}: ${current.label}',
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language, size: 18),
          const SizedBox(width: 4),
          Text(
            current.code.split('-')[0].toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      initialValue: current,
      onSelected: (lang) {
        AppI18n.instance.setLanguage(lang);
        onLanguageChanged();
      },
      itemBuilder: (ctx) {
        return AppLanguage.values.map((lang) {
          final isSelected = lang == current;
          return PopupMenuItem<AppLanguage>(
            value: lang,
            child: Row(
              children: [
                if (isSelected)
                  const Icon(Icons.check, size: 16, color: Colors.green)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(
                  '${lang.label} (${lang.code})',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
