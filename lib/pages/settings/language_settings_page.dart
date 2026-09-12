import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/localization/app_locale_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/flutter_flow/flutter_flow_theme.dart';

class LanguageSettingsPageWidget extends StatefulWidget {
  const LanguageSettingsPageWidget({super.key});

  static String routeName = 'LanguageSettingsPage';
  static String routePath = '/language';

  @override
  State<LanguageSettingsPageWidget> createState() =>
      _LanguageSettingsPageWidgetState();
}

class _LanguageSettingsPageWidgetState
    extends State<LanguageSettingsPageWidget> {
  bool loading = true;

  String selectedLanguageCode = 'en';

  final List<Map<String, dynamic>> languages = [
    {
      'name': 'English',
      'native': 'English',
      'code': 'en',
      'locale': Locale('en'),
    },
    {
      'name': 'Swahili',
      'native': 'Kiswahili',
      'code': 'sw',
      'locale': Locale('sw'),
    },
    {
      'name': 'French',
      'native': 'Français',
      'code': 'fr',
      'locale': Locale('fr'),
    },
    {
      'name': 'Spanish',
      'native': 'Español',
      'code': 'es',
      'locale': Locale('es'),
    },
    {
      'name': 'Arabic',
      'native': 'العربية',
      'code': 'ar',
      'locale': Locale('ar'),
    },
  ];

  @override
  void initState() {
    super.initState();
    loadLanguage();
  }

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('language') ?? context.locale.languageCode;
    final savedCode = languages.any((lang) => lang['code'] == saved)
        ? saved
        : context.locale.languageCode;

    if (!mounted) return;

    setState(() {
      selectedLanguageCode =
          languages.any((lang) => lang['code'] == savedCode) ? savedCode : 'en';
      loading = false;
    });
  }

  Future<void> changeLanguage(
    Map<String, dynamic> lang,
  ) async {
    final Locale locale = lang['locale'];
    final String languageCode = lang['code'];

    await AppLocaleService.setLocale(context, locale);

    if (!mounted) return;

    setState(() {
      selectedLanguageCode = languageCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        title: Text(
          'language'.tr(),
        ),
        elevation: 0,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: languages.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final lang = languages[index];
                final isSelected = selectedLanguageCode == lang['code'];

                return ListTile(
                  title: Text(
                    lang['native'],
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: FlutterFlowTheme.of(context).primary,
                        )
                      : null,
                  onTap: () => changeLanguage(lang),
                );
              },
            ),
    );
  }
}
