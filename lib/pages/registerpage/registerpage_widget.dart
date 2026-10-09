import 'dart:async';

import '/services/auth/auth_service.dart';
import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'registerpage_model.dart';
export 'registerpage_model.dart';

class RegisterpageWidget extends StatefulWidget {
  const RegisterpageWidget({super.key});

  static String routeName = 'registerpage';
  static String routePath = '/registerpage';

  @override
  State<RegisterpageWidget> createState() => _RegisterpageWidgetState();
}

class _RegisterpageWidgetState extends State<RegisterpageWidget> {
  late RegisterpageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstNameController = TextEditingController();

  final TextEditingController lastNameController = TextEditingController();

  final TextEditingController usernameController = TextEditingController();

  final TextEditingController phoneController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  final TextEditingController countryController = TextEditingController();

  final TextEditingController referralController = TextEditingController();
  Timer? _usernameCheckTimer;
  final Map<String, Timer?> _contactCheckTimers = {
    'email': null,
    'phone': null,
  };
  int _usernameCheckRequestId = 0;
  String? _usernameCheckResultFor;
  bool? _usernameAvailable;
  bool _usernameChecking = false;
  String? _usernameCheckError;
  final Map<String, int> _contactCheckRequestIds = {'email': 0, 'phone': 0};
  final Map<String, String?> _contactCheckResultFor = {
    'email': null,
    'phone': null,
  };
  final Map<String, bool?> _contactAvailable = {
    'email': null,
    'phone': null,
  };
  final Map<String, bool> _contactChecking = {'email': false, 'phone': false};
  final Map<String, String?> _contactCheckErrors = {
    'email': null,
    'phone': null,
  };

  final CountryService _countryService = CountryService();

  String? _selectedCountry = 'United States';
  String _selectedCountryCode = '+1';

  final Map<String, String> _countryCodeMap = {
    '+1': 'United States',
    '+44': 'United Kingdom',
    '+33': 'France',
    '+49': 'Germany',
    '+39': 'Italy',
    '+34': 'Spain',
    '+31': 'Netherlands',
    '+32': 'Belgium',
    '+43': 'Austria',
    '+41': 'Switzerland',
    '+46': 'Sweden',
    '+47': 'Norway',
    '+45': 'Denmark',
    '+358': 'Finland',
    '+353': 'Ireland',
    '+48': 'Poland',
    '+420': 'Czech Republic',
    '+36': 'Hungary',
    '+40': 'Romania',
    '+359': 'Bulgaria',
    '+30': 'Greece',
    '+351': 'Portugal',
    '+385': 'Croatia',
    '+386': 'Slovenia',
    '+81': 'Japan',
    '+86': 'China',
    '+91': 'India',
    '+65': 'Singapore',
    '+60': 'Malaysia',
    '+66': 'Thailand',
    '+84': 'Vietnam',
    '+62': 'Indonesia',
    '+63': 'Philippines',
    '+82': 'South Korea',
    '+234': 'Nigeria',
    '+254': 'Kenya',
    '+27': 'South Africa',
    '+256': 'Uganda',
    '+255': 'Tanzania',
    '+212': 'Morocco',
    '+213': 'Algeria',
    '+20': 'Egypt',
    '+216': 'Tunisia',
    '+55': 'Brazil',
    '+54': 'Argentina',
    '+56': 'Chile',
    '+57': 'Colombia',
    '+51': 'Peru',
    '+52': 'Mexico',
    '+507': 'Panama',
    '+505': 'Nicaragua',
    '+502': 'Guatemala',
    '+503': 'El Salvador',
  };

  List<String> get _countries => {
        ..._countryService.getAll().map((country) => country.name),
        'Afghanistan',
        'Albania',
        'Algeria',
        'Andorra',
        'Angola',
        'Argentina',
        'Armenia',
        'Australia',
        'Austria',
        'Azerbaijan',
        'Bahamas',
        'Bahrain',
        'Bangladesh',
        'Barbados',
        'Belarus',
        'Belgium',
        'Belize',
        'Benin',
        'Bhutan',
        'Bolivia',
        'Bosnia and Herzegovina',
        'Botswana',
        'Brazil',
        'Brunei',
        'Bulgaria',
        'Burkina Faso',
        'Burundi',
        'Cambodia',
        'Cameroon',
        'Canada',
        'Cape Verde',
        'Central African Republic',
        'Chad',
        'Chile',
        'China',
        'Colombia',
        'Comoros',
        'Congo',
        'Costa Rica',
        'Croatia',
        'Cuba',
        'Cyprus',
        'Czech Republic',
        'Denmark',
        'Djibouti',
        'Dominica',
        'Dominican Republic',
        'Ecuador',
        'Egypt',
        'El Salvador',
        'Equatorial Guinea',
        'Eritrea',
        'Estonia',
        'Eswatini',
        'Ethiopia',
        'Fiji',
        'Finland',
        'France',
        'Gabon',
        'Gambia',
        'Georgia',
        'Germany',
        'Ghana',
        'Greece',
        'Grenada',
        'Guatemala',
        'Guinea',
        'Guinea-Bissau',
        'Guyana',
        'Haiti',
        'Honduras',
        'Hungary',
        'Iceland',
        'India',
        'Indonesia',
        'Iran',
        'Iraq',
        'Ireland',
        'Israel',
        'Italy',
        'Jamaica',
        'Japan',
        'Jordan',
        'Kazakhstan',
        'Kenya',
        'Kiribati',
        'Kosovo',
        'Kuwait',
        'Kyrgyzstan',
        'Laos',
        'Latvia',
        'Lebanon',
        'Lesotho',
        'Liberia',
        'Libya',
        'Liechtenstein',
        'Lithuania',
        'Luxembourg',
        'Madagascar',
        'Malawi',
        'Malaysia',
        'Maldives',
        'Mali',
        'Malta',
        'Marshall Islands',
        'Mauritania',
        'Mauritius',
        'Mexico',
        'Micronesia',
        'Moldova',
        'Monaco',
        'Mongolia',
        'Montenegro',
        'Morocco',
        'Mozambique',
        'Myanmar',
        'Namibia',
        'Nauru',
        'Nepal',
        'Netherlands',
        'New Zealand',
        'Nicaragua',
        'Niger',
        'Nigeria',
        'North Korea',
        'North Macedonia',
        'Norway',
        'Oman',
        'Pakistan',
        'Palau',
        'Palestine',
        'Panama',
        'Papua New Guinea',
        'Paraguay',
        'Peru',
        'Philippines',
        'Poland',
        'Portugal',
        'Qatar',
        'Romania',
        'Russia',
        'Rwanda',
        'Saint Kitts and Nevis',
        'Saint Lucia',
        'Saint Vincent and the Grenadines',
        'Samoa',
        'San Marino',
        'Sao Tome and Principe',
        'Saudi Arabia',
        'Senegal',
        'Serbia',
        'Seychelles',
        'Sierra Leone',
        'Singapore',
        'Slovakia',
        'Slovenia',
        'Solomon Islands',
        'Somalia',
        'South Africa',
        'South Korea',
        'South Sudan',
        'Spain',
        'Sri Lanka',
        'Sudan',
        'Suriname',
        'Sweden',
        'Switzerland',
        'Syria',
        'Taiwan',
        'Tajikistan',
        'Tanzania',
        'Thailand',
        'Timor-Leste',
        'Togo',
        'Tonga',
        'Trinidad and Tobago',
        'Tunisia',
        'Turkey',
        'Turkmenistan',
        'Tuvalu',
        'Uganda',
        'Ukraine',
        'United Arab Emirates',
        'United Kingdom',
        'United States',
        'Uruguay',
        'Uzbekistan',
        'Vanuatu',
        'Vatican City',
        'Venezuela',
        'Vietnam',
        'Yemen',
        'Zambia',
        'Zimbabwe',
      }.toList()
        ..sort();

  String _flagForCountry(String country) {
    final countryData = _countryService.findByName(country);
    if (countryData != null) {
      return countryData.flagEmoji;
    }

    const countryIso = {
      'Afghanistan': 'AF',
      'Albania': 'AL',
      'Algeria': 'DZ',
      'Andorra': 'AD',
      'Angola': 'AO',
      'Argentina': 'AR',
      'Armenia': 'AM',
      'Australia': 'AU',
      'Austria': 'AT',
      'Azerbaijan': 'AZ',
      'Bahamas': 'BS',
      'Bahrain': 'BH',
      'Bangladesh': 'BD',
      'Barbados': 'BB',
      'Belarus': 'BY',
      'Belgium': 'BE',
      'Belize': 'BZ',
      'Benin': 'BJ',
      'Bhutan': 'BT',
      'Bolivia': 'BO',
      'Bosnia and Herzegovina': 'BA',
      'Botswana': 'BW',
      'Brazil': 'BR',
      'Brunei': 'BN',
      'Bulgaria': 'BG',
      'Burkina Faso': 'BF',
      'Burundi': 'BI',
      'Cambodia': 'KH',
      'Cameroon': 'CM',
      'Canada': 'CA',
      'Cabo Verde': 'CV',
      'Cape Verde': 'CV',
      'Central African Republic': 'CF',
      'Chad': 'TD',
      'Chile': 'CL',
      'China': 'CN',
      'Colombia': 'CO',
      'Comoros': 'KM',
      'Congo': 'CG',
      'Costa Rica': 'CR',
      'Croatia': 'HR',
      'Cuba': 'CU',
      'Cyprus': 'CY',
      'Czech Republic': 'CZ',
      'Denmark': 'DK',
      'Djibouti': 'DJ',
      'Dominica': 'DM',
      'Dominican Republic': 'DO',
      'Ecuador': 'EC',
      'Egypt': 'EG',
      'El Salvador': 'SV',
      'Equatorial Guinea': 'GQ',
      'Eritrea': 'ER',
      'Estonia': 'EE',
      'Eswatini': 'SZ',
      'Ethiopia': 'ET',
      'Fiji': 'FJ',
      'Finland': 'FI',
      'France': 'FR',
      'Gabon': 'GA',
      'Gambia': 'GM',
      'Georgia': 'GE',
      'Germany': 'DE',
      'Ghana': 'GH',
      'Greece': 'GR',
      'Grenada': 'GD',
      'Guatemala': 'GT',
      'Guinea': 'GN',
      'Guinea-Bissau': 'GW',
      'Guyana': 'GY',
      'Haiti': 'HT',
      'Honduras': 'HN',
      'Hungary': 'HU',
      'Iceland': 'IS',
      'India': 'IN',
      'Indonesia': 'ID',
      'Iran': 'IR',
      'Iraq': 'IQ',
      'Ireland': 'IE',
      'Israel': 'IL',
      'Italy': 'IT',
      'Jamaica': 'JM',
      'Japan': 'JP',
      'Jordan': 'JO',
      'Kazakhstan': 'KZ',
      'Kenya': 'KE',
      'Kiribati': 'KI',
      'Kosovo': 'XK',
      'Kuwait': 'KW',
      'Kyrgyzstan': 'KG',
      'Laos': 'LA',
      'Latvia': 'LV',
      'Lebanon': 'LB',
      'Lesotho': 'LS',
      'Liberia': 'LR',
      'Libya': 'LY',
      'Liechtenstein': 'LI',
      'Lithuania': 'LT',
      'Luxembourg': 'LU',
      'Madagascar': 'MG',
      'Malawi': 'MW',
      'Malaysia': 'MY',
      'Maldives': 'MV',
      'Mali': 'ML',
      'Malta': 'MT',
      'Marshall Islands': 'MH',
      'Mauritania': 'MR',
      'Mauritius': 'MU',
      'Mexico': 'MX',
      'Micronesia': 'FM',
      'Moldova': 'MD',
      'Monaco': 'MC',
      'Mongolia': 'MN',
      'Montenegro': 'ME',
      'Morocco': 'MA',
      'Mozambique': 'MZ',
      'Myanmar': 'MM',
      'Namibia': 'NA',
      'Nauru': 'NR',
      'Nepal': 'NP',
      'Netherlands': 'NL',
      'New Zealand': 'NZ',
      'Nicaragua': 'NI',
      'Niger': 'NE',
      'Nigeria': 'NG',
      'North Korea': 'KP',
      'North Macedonia': 'MK',
      'Norway': 'NO',
      'Oman': 'OM',
      'Pakistan': 'PK',
      'Palau': 'PW',
      'Palestine': 'PS',
      'Panama': 'PA',
      'Papua New Guinea': 'PG',
      'Paraguay': 'PY',
      'Peru': 'PE',
      'Philippines': 'PH',
      'Poland': 'PL',
      'Portugal': 'PT',
      'Qatar': 'QA',
      'Romania': 'RO',
      'Russia': 'RU',
      'Rwanda': 'RW',
      'Saint Kitts and Nevis': 'KN',
      'Saint Lucia': 'LC',
      'Saint Vincent and the Grenadines': 'VC',
      'Samoa': 'WS',
      'San Marino': 'SM',
      'Sao Tome and Principe': 'ST',
      'Saudi Arabia': 'SA',
      'Senegal': 'SN',
      'Serbia': 'RS',
      'Seychelles': 'SC',
      'Sierra Leone': 'SL',
      'Singapore': 'SG',
      'Slovakia': 'SK',
      'Slovenia': 'SI',
      'Solomon Islands': 'SB',
      'Somalia': 'SO',
      'South Africa': 'ZA',
      'South Korea': 'KR',
      'South Sudan': 'SS',
      'Spain': 'ES',
      'Sri Lanka': 'LK',
      'Sudan': 'SD',
      'Suriname': 'SR',
      'Sweden': 'SE',
      'Switzerland': 'CH',
      'Syria': 'SY',
      'Taiwan': 'TW',
      'Tajikistan': 'TJ',
      'Tanzania': 'TZ',
      'Thailand': 'TH',
      'Timor-Leste': 'TL',
      'Togo': 'TG',
      'Tonga': 'TO',
      'Trinidad and Tobago': 'TT',
      'Tunisia': 'TN',
      'Turkey': 'TR',
      'Turkmenistan': 'TM',
      'Tuvalu': 'TV',
      'Uganda': 'UG',
      'Ukraine': 'UA',
      'United Arab Emirates': 'AE',
      'United Kingdom': 'GB',
      'United States': 'US',
      'Uruguay': 'UY',
      'Uzbekistan': 'UZ',
      'Vanuatu': 'VU',
      'Vatican City': 'VA',
      'Venezuela': 'VE',
      'Vietnam': 'VN',
      'Yemen': 'YE',
      'Zambia': 'ZM',
      'Zimbabwe': 'ZW',
    };

    final iso = countryIso[country];
    if (iso == null || iso.length != 2) {
      return '';
    }

    final codeUnits = iso.toUpperCase().codeUnits;
    return String.fromCharCodes(
      codeUnits.map((unit) => unit + 0x1F1A5),
    );
  }

  String _shortCodeForCountry(String country) {
    final flagRunes = _flagForCountry(country).runes.where(
          (rune) => rune >= 0x1F1E6 && rune <= 0x1F1FF,
        );
    return String.fromCharCodes(flagRunes.map((rune) => rune - 0x1F1A5));
  }

  List<Country> get _registrationCountries =>
      _countries.map(_countryService.findByName).whereType<Country>().toList();

  void _onUsernameChanged(String value) {
    _usernameCheckTimer?.cancel();
    final requestId = ++_usernameCheckRequestId;
    final username = value.trim().toLowerCase();
    setState(() {
      _usernameCheckResultFor = null;
      _usernameAvailable = null;
      _usernameChecking = false;
      _usernameCheckError = null;
    });

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) return;

    setState(() => _usernameChecking = true);
    _usernameCheckTimer = Timer(const Duration(milliseconds: 450), () {
      _checkUsernameAvailability(username, requestId);
    });
  }

  Future<bool?> _checkUsernameAvailability(
    String username,
    int requestId,
  ) async {
    try {
      final query = Uri(queryParameters: {'username': username}).query;
      final response = await ApiService.request(
        method: 'GET',
        path: '/auth/username-availability?$query',
        requiresAuth: false,
      );
      final data = response['data'];
      final available =
          data is Map<String, dynamic> && data['available'] is bool
              ? data['available'] as bool
              : null;
      if (available == null) {
        throw const FormatException('Invalid username availability response');
      }

      if (mounted && requestId == _usernameCheckRequestId) {
        setState(() {
          _usernameCheckResultFor = username;
          _usernameAvailable = available;
          _usernameChecking = false;
          _usernameCheckError = null;
        });
      }
      return available;
    } catch (error) {
      if (mounted && requestId == _usernameCheckRequestId) {
        setState(() {
          _usernameCheckResultFor = username;
          _usernameAvailable = null;
          _usernameChecking = false;
          _usernameCheckError = error.toString();
        });
      }
      return null;
    }
  }

  Future<bool?> _checkCurrentUsernameNow() {
    _usernameCheckTimer?.cancel();
    final username = usernameController.text.trim().toLowerCase();
    final requestId = ++_usernameCheckRequestId;
    setState(() {
      _usernameCheckResultFor = null;
      _usernameAvailable = null;
      _usernameChecking = true;
      _usernameCheckError = null;
    });
    return _checkUsernameAvailability(username, requestId);
  }

  String _contactValue(String field) {
    if (field == 'email') return emailController.text.trim().toLowerCase();
    return '$_selectedCountryCode${phoneController.text.trim()}';
  }

  bool _isValidContact(String field, String value) {
    if (field == 'email') {
      return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
    }
    return RegExp(r'^\+?[1-9]\d{7,14}$').hasMatch(value);
  }

  void _onContactChanged(String field) {
    _contactCheckTimers[field]?.cancel();
    final requestId = (_contactCheckRequestIds[field] ?? 0) + 1;
    final value = _contactValue(field);
    setState(() {
      _contactCheckRequestIds[field] = requestId;
      _contactCheckResultFor[field] = null;
      _contactAvailable[field] = null;
      _contactChecking[field] = false;
      _contactCheckErrors[field] = null;
    });
    if (!_isValidContact(field, value)) return;

    setState(() => _contactChecking[field] = true);
    _contactCheckTimers[field] = Timer(const Duration(milliseconds: 450), () {
      _checkContactAvailability(field, value, requestId);
    });
  }

  Future<bool?> _checkContactAvailability(
    String field,
    String value,
    int requestId,
  ) async {
    try {
      final query = Uri(queryParameters: {field: value}).query;
      final response = await ApiService.request(
        method: 'GET',
        path: '/auth/registration-availability?$query',
        requiresAuth: false,
      );
      final data = response['data'];
      final availabilityKey =
          field == 'email' ? 'emailAvailable' : 'phoneAvailable';
      final available = data is Map && data[availabilityKey] is bool
          ? data[availabilityKey] as bool
          : null;
      if (available == null) {
        throw const FormatException('Invalid contact availability response');
      }

      if (mounted && requestId == _contactCheckRequestIds[field]) {
        setState(() {
          _contactCheckResultFor[field] = value;
          _contactAvailable[field] = available;
          _contactChecking[field] = false;
          _contactCheckErrors[field] = null;
        });
      }
      return available;
    } catch (error) {
      if (mounted && requestId == _contactCheckRequestIds[field]) {
        setState(() {
          _contactCheckResultFor[field] = value;
          _contactAvailable[field] = null;
          _contactChecking[field] = false;
          _contactCheckErrors[field] = error.toString();
        });
      }
      return null;
    }
  }

  Future<bool?> _checkCurrentContactNow(String field) {
    _contactCheckTimers[field]?.cancel();
    final value = _contactValue(field);
    final requestId = (_contactCheckRequestIds[field] ?? 0) + 1;
    setState(() {
      _contactCheckRequestIds[field] = requestId;
      _contactCheckResultFor[field] = null;
      _contactAvailable[field] = null;
      _contactChecking[field] = true;
      _contactCheckErrors[field] = null;
    });
    return _checkContactAvailability(field, value, requestId);
  }

  String _dialCodeForCountry(Country country) {
    for (final entry in _countryCodeMap.entries) {
      if (entry.value == country.name) {
        return entry.key;
      }
    }
    return '+${country.phoneCode}';
  }

  Future<String?> _showSearchableCountryPicker({
    required String title,
  }) async {
    final searchController = TextEditingController();
    try {
      return await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final query = searchController.text.trim().toLowerCase();
              final matches = _registrationCountries
                  .where((country) =>
                      country.name.toLowerCase().contains(query) ||
                      country.countryCode.toLowerCase().contains(query) ||
                      country.phoneCode.contains(query))
                  .toList();

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                  ),
                  child: SizedBox(
                    height: MediaQuery.sizeOf(sheetContext).height * 0.7,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(title,
                              style: FlutterFlowTheme.of(context).titleMedium),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: TextField(
                            controller: searchController,
                            onChanged: (_) => setSheetState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search country or code',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: matches.isEmpty
                              ? const Center(child: Text('No countries found'))
                              : ListView.builder(
                                  itemCount: matches.length,
                                  itemBuilder: (context, index) {
                                    final country = matches[index];
                                    return ListTile(
                                      leading: Text(
                                        country.flagEmoji,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                      title: Text(
                                        '${country.countryCode}  +${country.phoneCode}  ${country.name}',
                                      ),
                                      onTap: () => Navigator.of(context)
                                          .pop(country.countryCode),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      searchController.dispose();
    }
  }

  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  Widget passwordRequirement(
    BuildContext context, {
    required String label,
    required bool met,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16.0,
          color: met ? Colors.green : theme.secondaryText,
        ),
        const SizedBox(width: 6.0),
        Text(
          label,
          style: TextStyle(
            color: met ? Colors.green : theme.secondaryText,
            fontSize: 12.0,
          ),
        ),
      ],
    );
  }

  Widget passwordRequirements(BuildContext context) {
    final password = passwordController.text;
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 16.0,
        runSpacing: 6.0,
        children: [
          passwordRequirement(
            context,
            label: '12 characters',
            met: password.length >= 12,
          ),
          passwordRequirement(
            context,
            label: 'Capital letter',
            met: RegExp(r'[A-Z]').hasMatch(password),
          ),
          passwordRequirement(
            context,
            label: 'Small letter',
            met: RegExp(r'[a-z]').hasMatch(password),
          ),
          passwordRequirement(
            context,
            label: 'Number',
            met: RegExp(r'[0-9]').hasMatch(password),
          ),
          passwordRequirement(
            context,
            label: 'Punctuation mark',
            met: RegExp(r'''[^A-Za-z0-9\s]''').hasMatch(password),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(
      context,
      () => RegisterpageModel(),
    );
  }

  @override
  void dispose() {
    _usernameCheckTimer?.cancel();
    for (final timer in _contactCheckTimers.values) {
      timer?.cancel();
    }
    firstNameController.dispose();
    lastNameController.dispose();
    usernameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    countryController.dispose();
    referralController.dispose();

    _model.dispose();

    super.dispose();
  }

  InputDecoration inputDecoration(
    BuildContext context,
    String hint,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: FlutterFlowTheme.of(context).secondaryText,
      ),
      filled: true,
      fillColor: FlutterFlowTheme.of(context).secondaryBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 18.0,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  Widget buildLabel(
    BuildContext context,
    String text,
  ) {
    return Text(
      text,
      style: FlutterFlowTheme.of(context).labelLarge.override(
            font: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
            ),
            letterSpacing: 0.0,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SingleChildScrollView(
          primary: false,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 64.0,
                        height: 64.0,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primaryText,
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        alignment: const AlignmentDirectional(0.0, 0.0),
                        child: SizedBox(
                          width: 40.0,
                          height: 50.0,
                          child: Stack(
                            alignment: const AlignmentDirectional(-1.0, -1.0),
                            children: [
                              Align(
                                alignment: const AlignmentDirectional(0.0, 0.0),
                                child: Container(
                                  width: 6.0,
                                  height: 50.0,
                                  decoration: BoxDecoration(
                                    color:
                                        FlutterFlowTheme.of(context).onPrimary,
                                    borderRadius: BorderRadius.circular(2.0),
                                  ),
                                ),
                              ),
                              Align(
                                alignment:
                                    const AlignmentDirectional(-1.0, -0.6),
                                child: Container(
                                  width: 24.0,
                                  height: 6.0,
                                  decoration: BoxDecoration(
                                    color:
                                        FlutterFlowTheme.of(context).onPrimary,
                                    borderRadius: BorderRadius.circular(2.0),
                                  ),
                                ),
                              ),
                              Align(
                                alignment:
                                    const AlignmentDirectional(-1.0, 0.0),
                                child: Container(
                                  width: 18.0,
                                  height: 6.0,
                                  decoration: BoxDecoration(
                                    color:
                                        FlutterFlowTheme.of(context).onPrimary,
                                    borderRadius: BorderRadius.circular(2.0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        'FARM',
                        style: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .override(
                              font: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                              ),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.0,
                            ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'a loop of growth',
                        style: FlutterFlowTheme.of(context).labelSmall.override(
                              font: GoogleFonts.plusJakartaSans(),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32.0),
                  Text(
                    'Create your account',
                    style: FlutterFlowTheme.of(context).titleLarge.override(
                          font: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                          ),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.0,
                        ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Secure your financial future today',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(),
                          color: FlutterFlowTheme.of(context).secondaryText,
                          letterSpacing: 0.0,
                        ),
                  ),
                  const SizedBox(height: 24.0),
                  buildLabel(context, 'First Name'),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: firstNameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'First name is required';
                      }
                      return null;
                    },
                    decoration: inputDecoration(
                      context,
                      'Enter first name',
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(context, 'Last Name'),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: lastNameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Last name is required';
                      }
                      return null;
                    },
                    decoration: inputDecoration(
                      context,
                      'Enter last name',
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(context, 'Username'),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: usernameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Username required';
                      }

                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                        return 'Letters, numbers and underscores only';
                      }

                      final username = value.trim().toLowerCase();
                      if (_usernameCheckResultFor == username &&
                          _usernameAvailable == false) {
                        return 'Username already exists. Choose another username.';
                      }

                      return null;
                    },
                    onChanged: _onUsernameChanged,
                    decoration:
                        inputDecoration(context, 'Enter username').copyWith(
                      helperText: _usernameCheckError != null
                          ? 'Could not check username. Try again before continuing.'
                          : _usernameCheckResultFor ==
                                      usernameController.text
                                          .trim()
                                          .toLowerCase() &&
                                  _usernameAvailable == false
                              ? 'Username already exists. Choose another username.'
                              : _usernameCheckResultFor ==
                                          usernameController.text
                                              .trim()
                                              .toLowerCase() &&
                                      _usernameAvailable == true
                                  ? 'Username is available.'
                                  : _usernameChecking
                                      ? 'Checking username...'
                                      : null,
                      helperStyle: TextStyle(
                        color: _usernameCheckError != null ||
                                (_usernameAvailable == false &&
                                    _usernameCheckResultFor ==
                                        usernameController.text
                                            .trim()
                                            .toLowerCase())
                            ? Colors.red
                            : _usernameAvailable == true
                                ? Colors.green
                                : null,
                      ),
                      suffixIcon: _usernameChecking
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _usernameCheckResultFor ==
                                      usernameController.text
                                          .trim()
                                          .toLowerCase() &&
                                  _usernameAvailable == true
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : _usernameCheckResultFor ==
                                          usernameController.text
                                              .trim()
                                              .toLowerCase() &&
                                      _usernameAvailable == false
                                  ? const Icon(Icons.error, color: Colors.red)
                                  : null,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(context, 'Phone Number'),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: FormField<String>(
                          key: ValueKey(_selectedCountryCode),
                          initialValue: _selectedCountryCode,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Country code required';
                            }
                            return null;
                          },
                          builder: (field) {
                            final country = _selectedCountry ?? '';
                            final flag = _flagForCountry(country);
                            final shortCode = _shortCodeForCountry(country);
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                final selected =
                                    await _showSearchableCountryPicker(
                                  title: 'Select country code',
                                );
                                if (selected == null || !mounted) return;
                                final selectedCountry =
                                    _countryService.findByCode(selected);
                                if (selectedCountry == null) return;
                                setState(() {
                                  _selectedCountry = selectedCountry.name;
                                  _selectedCountryCode =
                                      _dialCodeForCountry(selectedCountry);
                                });
                                _onContactChanged('phone');
                                field.didChange(_selectedCountryCode);
                              },
                              child: InputDecorator(
                                decoration:
                                    inputDecoration(context, 'Code').copyWith(
                                  errorText: field.errorText,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 16,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      flag,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '$shortCode $_selectedCountryCode',
                                        overflow: TextOverflow.ellipsis,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        flex: 7,
                        child: TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Phone number required';
                            }
                            if (!RegExp(r'^[0-9]{6,15}$').hasMatch(value)) {
                              return 'Enter valid phone number';
                            }
                            final phone = _contactValue('phone');
                            if (_contactCheckResultFor['phone'] == phone &&
                                _contactAvailable['phone'] == false) {
                              return 'Phone number already exists. Use another number.';
                            }
                            return null;
                          },
                          onChanged: (_) => _onContactChanged('phone'),
                          decoration: inputDecoration(
                            context,
                            '700123456',
                          ).copyWith(
                            helperText: _contactCheckErrors['phone'] != null
                                ? 'Could not check phone number. Try again before continuing.'
                                : _contactCheckResultFor['phone'] ==
                                            _contactValue('phone') &&
                                        _contactAvailable['phone'] == false
                                    ? 'Phone number already exists. Use another number.'
                                    : _contactCheckResultFor['phone'] ==
                                                _contactValue('phone') &&
                                            _contactAvailable['phone'] == true
                                        ? 'Phone number is available.'
                                        : _contactChecking['phone'] == true
                                            ? 'Checking phone number...'
                                            : null,
                            helperStyle: TextStyle(
                              color: _contactCheckErrors['phone'] != null ||
                                      (_contactAvailable['phone'] == false &&
                                          _contactCheckResultFor['phone'] ==
                                              _contactValue('phone'))
                                  ? Colors.red
                                  : _contactAvailable['phone'] == true
                                      ? Colors.green
                                      : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(context, 'Email'),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      final email = value.trim().toLowerCase();
                      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(email)) {
                        return 'Enter a valid email address';
                      }
                      if (_contactCheckResultFor['email'] == email &&
                          _contactAvailable['email'] == false) {
                        return 'Email already exists. Use another email.';
                      }
                      return null;
                    },
                    onChanged: (_) => _onContactChanged('email'),
                    decoration:
                        inputDecoration(context, 'Enter email').copyWith(
                      helperText: _contactCheckErrors['email'] != null
                          ? 'Could not check email. Try again before continuing.'
                          : _contactCheckResultFor['email'] ==
                                      _contactValue('email') &&
                                  _contactAvailable['email'] == false
                              ? 'Email already exists. Use another email.'
                              : _contactCheckResultFor['email'] ==
                                          _contactValue('email') &&
                                      _contactAvailable['email'] == true
                                  ? 'Email is available.'
                                  : _contactChecking['email'] == true
                                      ? 'Checking email...'
                                      : null,
                      helperStyle: TextStyle(
                        color: _contactCheckErrors['email'] != null ||
                                (_contactAvailable['email'] == false &&
                                    _contactCheckResultFor['email'] ==
                                        _contactValue('email'))
                            ? Colors.red
                            : _contactAvailable['email'] == true
                                ? Colors.green
                                : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(context, 'Password'),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: passwordController,
                    obscureText: !passwordVisible,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password required';
                      }

                      if (value.length < 12) {
                        return 'Minimum 12 characters';
                      }
                      if (!RegExp(r'[A-Z]').hasMatch(value)) {
                        return 'Include a capital letter';
                      }
                      if (!RegExp(r'[a-z]').hasMatch(value)) {
                        return 'Include a small letter';
                      }
                      if (!RegExp(r'[0-9]').hasMatch(value)) {
                        return 'Include a number';
                      }
                      if (!RegExp(r'''[^A-Za-z0-9\s]''').hasMatch(value)) {
                        return 'Include a punctuation mark';
                      }

                      return null;
                    },
                    decoration: inputDecoration(
                      context,
                      'Enter password',
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            passwordVisible = !passwordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  Text(
                    '(Use at least 12 characters, including a capital letter, '
                    'small letter, number, and punctuation mark)',
                    style: TextStyle(
                      color: FlutterFlowTheme.of(context).secondaryText,
                      fontSize: 12.0,
                    ),
                  ),
                  passwordRequirements(context),
                  const SizedBox(height: 16.0),
                  buildLabel(
                    context,
                    'Confirm Password',
                  ),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: !confirmPasswordVisible,
                    validator: (value) {
                      if (value != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    decoration: inputDecoration(
                      context,
                      'Confirm password',
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          confirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            confirmPasswordVisible = !confirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(context, 'Country'),
                  const SizedBox(height: 8.0),
                  FormField<String>(
                    initialValue: _selectedCountry,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Country required';
                      }
                      return null;
                    },
                    builder: (field) {
                      final country = _selectedCountry ?? '';
                      final flag = _flagForCountry(country);
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final selected = await _showSearchableCountryPicker(
                            title: 'Select country',
                          );
                          if (selected == null || !mounted) return;
                          final selectedCountry =
                              _countryService.findByCode(selected);
                          if (selectedCountry == null) return;
                          setState(() {
                            _selectedCountry = selectedCountry.name;
                            _selectedCountryCode =
                                _dialCodeForCountry(selectedCountry);
                          });
                          _onContactChanged('phone');
                          field.didChange(selectedCountry.name);
                        },
                        child: InputDecorator(
                          decoration: inputDecoration(
                            context,
                            'Select country',
                          ).copyWith(
                            errorText: field.errorText,
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                          ),
                          child: Row(
                            children: [
                              if (flag.isNotEmpty) ...[
                                Text(flag),
                                const SizedBox(width: 6.0),
                              ],
                              Expanded(
                                child: Text(
                                  country,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(
                    context,
                    'Referral Code',
                  ),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: referralController,
                    decoration: inputDecoration(
                      context,
                      'Optional referral',
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  FFButtonWidget(
                    onPressed: () async {
                      FocusScope.of(context).unfocus();

                      if (!_formKey.currentState!.validate()) {
                        return;
                      }

                      final usernameAvailable =
                          await _checkCurrentUsernameNow();
                      if (!mounted) return;
                      if (usernameAvailable != true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              usernameAvailable == false
                                  ? 'Username already exists. Choose another username.'
                                  : 'Could not check username. Please try again.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final contactAvailability = await Future.wait<bool?>([
                        _checkCurrentContactNow('email'),
                        _checkCurrentContactNow('phone'),
                      ]);
                      if (!mounted) return;
                      if (contactAvailability[0] != true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              contactAvailability[0] == false
                                  ? 'Email already exists. Use another email.'
                                  : 'Could not check email. Please try again.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (contactAvailability[1] != true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              contactAvailability[1] == false
                                  ? 'Phone number already exists. Use another number.'
                                  : 'Could not check phone number. Please try again.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final fullPhone =
                          '$_selectedCountryCode${phoneController.text.trim()}';
                      final email = emailController.text.trim().toLowerCase();
                      final password = passwordController.text.trim();

                      if (!email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('auth.valid_email'.tr()),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      try {
                        await AuthService().signUp(
                          email: email,
                          password: password,
                          firstName: firstNameController.text.trim(),
                          lastName: lastNameController.text.trim(),
                          username:
                              usernameController.text.trim().toLowerCase(),
                          phone: fullPhone,
                          country: _selectedCountry,
                          referralCode: referralController.text.trim(),
                        );

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'auth.registration_success'.tr(),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );

                        Future.delayed(
                          const Duration(seconds: 1),
                          () {
                            context.pushNamed('loginpage');
                          },
                        );
                      } catch (e) {
                        print('ERROR: $e');

                        final errorText = e.toString().toLowerCase();
                        final message = errorText
                                .contains('could not connect to backend server')
                            ? 'common.network_error'.tr()
                            : errorText.contains('username taken')
                                ? 'Username already exists. Choose another username.'
                                : errorText.contains('phone already registered')
                                    ? 'Phone number already exists. Use another number.'
                                    : errorText.contains(
                                            'email already registered')
                                        ? 'Email already exists. Use another email.'
                                        : 'auth.registration_failed'.tr();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    text: 'auth.create_account'.tr(),
                    options: FFButtonOptions(
                      width: double.infinity,
                      height: 54.0,
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16.0,
                        0.0,
                        16.0,
                        0.0,
                      ),
                      iconPadding: const EdgeInsetsDirectional.fromSTEB(
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                      ),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1F1F1F)
                          : FlutterFlowTheme.of(context).primary,
                      textStyle:
                          FlutterFlowTheme.of(context).titleSmall.override(
                                font: GoogleFonts.interTight(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: Colors.white,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                              ),
                      elevation: 0.0,
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                            ),
                      ),
                      const SizedBox(width: 4.0),
                      InkWell(
                        onTap: () {
                          context.pushNamed('loginpage');
                        },
                        child: Text(
                          'Login',
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: FlutterFlowTheme.of(context).primary,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32.0),
                  Align(
                    alignment: const AlignmentDirectional(0.0, 0.0),
                    child: Container(
                      width: 40.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).alternate,
                        borderRadius: BorderRadius.circular(9999.0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
