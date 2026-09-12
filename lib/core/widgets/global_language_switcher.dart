import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '/core/localization/app_locale_service.dart';

class GlobalLanguageSwitcher extends StatelessWidget {
  const GlobalLanguageSwitcher({super.key});

  static const _languages = <({String code, String label, Locale locale})>[
    (code: 'en', label: 'English', locale: Locale('en')),
    (code: 'sw', label: 'Kiswahili', locale: Locale('sw')),
    (code: 'fr', label: 'Francais', locale: Locale('fr')),
    (code: 'es', label: 'Espanol', locale: Locale('es')),
    (code: 'ar', label: 'العربية', locale: Locale('ar')),
  ];

  @override
  Widget build(BuildContext context) {
    final currentCode = context.locale.languageCode;

    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      elevation: 3,
      shape: const CircleBorder(),
      child: PopupMenuButton<Locale>(
        tooltip: 'language'.tr(),
        icon: const Icon(Icons.language),
        onSelected: (locale) => AppLocaleService.setLocale(context, locale),
        itemBuilder: (context) => [
          for (final language in _languages)
            PopupMenuItem<Locale>(
              value: language.locale,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    child: language.code == currentCode
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  ),
                  Text(language.label),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
