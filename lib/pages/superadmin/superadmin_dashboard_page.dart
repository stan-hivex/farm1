import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'superadmin_revenue_chart.dart';
import '/core/app_theme.dart';
import '/pages/loginpage/loginpage_widget.dart';
import '/pages/superadmin/add_admin_page.dart';
import '/pages/superadmin/superadmin_wallet_page.dart';
import '/pages/superadmin/fee_management_page.dart';
import '/admin/pages/user_management_page.dart';
import '/admin/pages/kyc_management_page.dart';
import '/admin/pages/transactions_management_page.dart';
import '/admin/pages/escrow_management_page.dart';
import '/admin/pages/merchant_kyb_management_page.dart';
import '/admin/pages/add_superadmin_page.dart';
import '/admin/pages/support_inbox_page.dart';
import '/admin/core/admin_navigation.dart';
import '/admin/services/admin_api_service.dart';
import '/admin/services/admin_page_refresh_coordinator.dart';
import '/services/auth/auth_service.dart';
import '/core/localization/app_locale_service.dart';
import '/services/transaction_receipt_service.dart';

class SuperadminDashboardPage extends StatefulWidget {
  const SuperadminDashboardPage({super.key});

  static const String routeName = 'superadmin_dashboard';
  static const String routePath = '/superadmin/dashboard';

  @override
  State<SuperadminDashboardPage> createState() =>
      _SuperadminDashboardPageState();
}

class _SuperadminDashboardPageState extends State<SuperadminDashboardPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _superadminWallet;
  List<Map<String, dynamic>> _revenueSeries = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _loadingRevenueSeries = true;
  String? _error;
  String? _revenueSeriesError;

  bool _loadingExchangeRates = true;
  bool _savingExchangeRates = false;
  bool _loadingCurrencyRate = true;
  bool _savingCurrencyRate = false;
  final TextEditingController _kesToFarmCtrl = TextEditingController();
  final TextEditingController _farmToKesCtrl = TextEditingController();
  final TextEditingController _usdToKesCtrl = TextEditingController();
  final TextEditingController _farmToUsdCtrl = TextEditingController();

  bool _isCreatingAdmin = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint(
        '[SuperadminDashboardPage] initState: starting dashboard initialization');
    _loadDashboardData();
    _loadSuperadminWallet();
    _loadExchangeRates();
    _loadCurrencyRate();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _kesToFarmCtrl.dispose();
    _farmToKesCtrl.dispose();
    _usdToKesCtrl.dispose();
    _farmToUsdCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _startPeriodicRefresh();
      unawaited(_refreshSessionAndReload());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _refreshTimer?.cancel();
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      unawaited(_refreshSessionAndReload());
    });
  }

  Future<void> _refreshSessionAndReload() async {
    if (!mounted) return;
    try {
      await AdminApiService.ensureValidSession();
      final token = await AdminApiService.getValidAccessToken();
      if (token.isEmpty) return;
      AdminPageRefreshCoordinator.requestRefresh();
      await Future.wait([
        _loadDashboardData(),
        _loadSuperadminWallet(),
        _loadExchangeRates(),
        _loadCurrencyRate(),
      ]);
    } catch (_) {}
  }

  Future<void> _loadSuperadminWallet() async {
    try {
      final response = await AdminApiService.getSuperadminWallet();
      if (mounted) {
        setState(() => _superadminWallet = response['data'] ?? response);
      }
    } catch (e) {
      debugPrint('[SuperadminDashboardPage] _loadSuperadminWallet failed: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    debugPrint('[SuperadminDashboardPage] _loadDashboardData started');
    setState(() {
      _loading = _dashboardData == null;
      _error = null;
      _loadingRevenueSeries = true;
      _revenueSeriesError = null;
    });
    try {
      final decoded = await AdminApiService.getSuperadminDashboard();

      if (decoded['status'] == 'success' || decoded['data'] != null) {
        if (mounted) {
          setState(() => _dashboardData = decoded['data'] ?? decoded);
        }
        try {
          final analytics = await AdminApiService.getAnalytics();
          final analyticsPayload = analytics['data'];
          final analyticsData = analyticsPayload is Map
              ? Map<String, dynamic>.from(analyticsPayload)
              : analytics;
          final rawSeries = analyticsData['revenue_series'];
          if (rawSeries is! List) {
            throw Exception(
                'Revenue analytics did not include a revenue series.');
          }
          if (mounted) {
            setState(() {
              _revenueSeries = rawSeries
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .where((item) => item['value'] != null)
                  .toList();
            });
          }
        } catch (e) {
          debugPrint(
              '[SuperadminDashboardPage] Revenue analytics load failed: $e');
          if (mounted) {
            setState(() {
              _revenueSeriesError = e.toString().replaceAll('Exception: ', '');
            });
          }
        } finally {
          if (mounted) setState(() => _loadingRevenueSeries = false);
        }
      } else {
        throw Exception(decoded['message'] ?? 'Failed to load dashboard');
      }
    } catch (e, st) {
      debugPrint('[SuperadminDashboardPage] _loadDashboardData failed: $e');
      debugPrint(st.toString());
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      _loadSuperadminWallet();
    }
  }

  Widget _wrapWithWillPop(Widget child) {
    return PopScope(canPop: true, child: child);
  }

  Future<void> _logout() async {
    debugPrint('[SuperadminDashboardPage] _logout called');
    try {
      await AuthService().logout();
    } catch (e) {
      debugPrint('[SuperadminDashboardPage] logout error: $e');
    }
    if (mounted) {
      await AppLocaleService.resetToEnglish(context);
      AuthNavigation.replaceAllWithBuilder(
        context,
        (_) => LoginpageWidget(),
      );
    }
  }

  Future<void> _loadExchangeRates() async {
    setState(() {
      _loadingExchangeRates = true;
    });
    try {
      final response = await AdminApiService.getExchangeRates();
      final rates = response['data'] as List<dynamic>? ?? [];

      String kesFarm = '1';
      String farmKes = '1';
      for (final item in rates) {
        final base = item['base_currency']?.toString().toUpperCase();
        final target = item['target_currency']?.toString().toUpperCase();
        final rate = item['rate']?.toString() ?? '';
        if (base == 'KES' && target == 'FARM') {
          kesFarm = rate;
        }
        if (base == 'FARM' && target == 'KES') {
          farmKes = rate;
        }
      }

      if (mounted) {
        _kesToFarmCtrl.text = kesFarm;
        _farmToKesCtrl.text = farmKes;
      }
    } catch (e, st) {
      debugPrint('[SuperadminDashboardPage] _loadExchangeRates failed: $e');
      debugPrint(st.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load exchange rates: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingExchangeRates = false;
        });
      }
    }
  }

  Future<void> _saveExchangeRates() async {
    if (_kesToFarmCtrl.text.isEmpty || _farmToKesCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill both KES→FARM and FARM→KES rates')),
      );
      return;
    }

    setState(() {
      _savingExchangeRates = true;
    });
    try {
      final response = await AdminApiService.updateExchangeRates([
        {
          'base_currency': 'KES',
          'target_currency': 'FARM',
          'rate': double.parse(_kesToFarmCtrl.text.trim()),
        },
        {
          'base_currency': 'FARM',
          'target_currency': 'KES',
          'rate': double.parse(_farmToKesCtrl.text.trim()),
        },
      ]);
      final message = response['message'] ?? 'Exchange rates updated';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
      await _loadExchangeRates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error saving exchange rates: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingExchangeRates = false);
    }
  }

  Future<void> _openSystemUsersPage() async {
    if (!mounted) return;
    await _openAdminPage(const UserManagementPage());
  }

  Future<void> _openMerchantKybPage() async {
    if (!mounted) return;
    await _openAdminPage(const MerchantKybManagementPage());
  }

  Future<void> _openAdminPage(Widget page) async {
    if (!mounted) return;
    final themedPage = page is UserManagementPage ||
            page is KycManagementPage ||
            page is TransactionsManagementPage ||
            page is EscrowManagementPage ||
            page is MerchantKybManagementPage ||
            page is SupportInboxPage
        ? Theme(data: AppTheme.lightTheme(), child: page)
        : page;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => themedPage),
    );
  }

  Widget _buildSystemUsersCard(Color cardColor, Color accent, Color muted) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Users',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Open the dedicated users page to manage accounts, roles, and KYC statuses.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Icon(Icons.people, color: accent),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openSystemUsersPage,
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.black),
              label: Text('Open System Users',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantKybCard(Color cardColor, Color accent, Color muted) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merchant',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Review merchant KYB details and approve or reject applications.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Icon(Icons.storefront_rounded, color: accent),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openMerchantKybPage,
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.black),
              label: Text(
                'Open Merchant KYB',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeManagementCard(Color cardColor, Color accent, Color muted) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.percent_rounded, color: accent, size: 24),
              const SizedBox(width: 12),
              Text(
                'Fee Management',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Review and update platform fee configurations.',
            style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _openAdminPage(const FeeManagementPage()),
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.black),
              label: Text(
                'Open Fee Management',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddAdminPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddAdminPage()),
    );
    await _loadDashboardData();
  }

  Future<void> _openAddSuperadminPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddSuperadminPage()),
    );
    await _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFF0B1320);
    final cardColor = const Color(0xFF111B2A);
    final accent = const Color(0xFFD4AF37);
    final muted = Colors.white70;

    if (_loading && _dashboardData == null) {
      return _wrapWithWillPop(Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      ));
    }

    if (_error != null && _dashboardData == null) {
      return _wrapWithWillPop(Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading dashboard',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadDashboardData,
                style: ElevatedButton.styleFrom(backgroundColor: accent),
                child: Text(
                  'Retry',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
    }

    final data = _dashboardData ?? {};

    return _wrapWithWillPop(Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          edgeOffset: 0,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(accent, muted),
                const SizedBox(height: 28),
                _buildKPICards(data, cardColor, accent),
                const SizedBox(height: 28),
                _buildExchangeRatesSection(data, cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildCurrencyConversionRatesSection(cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildSuperadminFees(
                    _superadminWallet, cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildFeeManagementCard(cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildRevenueOverview(cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildKYCEarnings(data, cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildSystemHealth(data, cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildMonitoringCards(data, cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildAddAdminSection(data, cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildSystemUsersCard(cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildMerchantKybCard(cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildRecentActivities(data, cardColor, muted),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildHeader(Color accent, Color muted) {
    final isPhone = MediaQuery.of(context).size.width < 600;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Title column. On small screens show a visible logout button here.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Superadmin Dashboard',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Monitor all platform activities and metrics',
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 13,
              ),
            ),
            if (isPhone) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: Tooltip(
                      message: 'Logout',
                      child: InkWell(
                        onTap: _logout,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),

        // Right-side quick actions (wallet + logout). Shield icon removed.
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Wallet',
                child: InkWell(
                  onTap: () {
                    debugPrint('[SuperadminDashboardPage] wallet icon tapped');
                    context.push(SuperadminWalletPage.routePath);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Keep the logout here for non-phone layouts as well.
            if (!isPhone)
              Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: 'Logout',
                  child: InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminActivityCard(String title, String value, Color accent,
      Color cardColor, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddAdminSection(
      Map<String, dynamic> data, Color cardColor, Color accent, Color muted) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Admin',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a new admin account and monitor approval activity.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: accent,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildAdminActivityCard(
                  'Pending KYC',
                  '${data['pending_kyc'] ?? 0}',
                  accent,
                  cardColor,
                  () => _openAdminPage(const KycManagementPage())),
              const SizedBox(width: 12),
              _buildAdminActivityCard(
                  'Flagged Tx',
                  '${data['flagged_transactions'] ?? 0}',
                  Colors.orange,
                  cardColor,
                  () => _openAdminPage(const TransactionsManagementPage())),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAdminActivityCard(
                  'Open Tickets',
                  '${data['support_tickets'] ?? 0}',
                  Colors.blue,
                  cardColor,
                  () => _openAdminPage(const SupportInboxPage())),
              const SizedBox(width: 12),
              _buildAdminActivityCard(
                  'Disputes',
                  '${data['pending_disputes'] ?? 0}',
                  Colors.red,
                  cardColor,
                  () => _openAdminPage(const EscrowManagementPage())),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isCreatingAdmin ? null : _openAddAdminPage,
              icon: const Icon(Icons.person_add_alt_1_rounded,
                  color: Colors.black),
              label: Text('Create Admin',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _openAddSuperadminPage,
              icon: Icon(Icons.admin_panel_settings_rounded, color: accent),
              label: Text(
                'Add Superadmin',
                style: GoogleFonts.plusJakartaSans(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openSystemUsersPage,
              icon: const Icon(Icons.people_rounded, color: Colors.black),
              label: Text('System Users',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICards(
      Map<String, dynamic> data, Color cardColor, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Indicators',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          children: [
            _kpiCard(
                'Total Users',
                '${data['total_users'] ?? 0}',
                'users',
                accent,
                cardColor,
                () => _openAdminPage(const UserManagementPage())),
            _kpiCard(
                'Total Revenue',
                '${data['total_revenue'] ?? 0} FARM',
                'platform fees',
                accent,
                cardColor,
                () => _openAdminPage(const SuperadminWalletPage())),
            _kpiCard(
                'Active Transactions',
                '${data['active_transactions'] ?? 0}',
                'pending',
                accent,
                cardColor,
                () => _openAdminPage(const TransactionsManagementPage())),
            _kpiCard('System Health', '${data['system_health'] ?? 98}%',
                'operational', accent, cardColor, null),
          ],
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value, String subtitle, Color accent,
      Color cardColor, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.trending_up, size: 14, color: accent),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueOverview(Color cardColor, Color accent, Color muted) {
    final values = _revenueSeries
        .map((item) => double.tryParse(item['value'].toString()) ?? 0)
        .toList();
    final maximum =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final previousTotal = values.length > 3
        ? values.sublist(0, values.length - 3).fold<double>(0, (a, b) => a + b)
        : 0.0;
    final recentTotal = values.length > 3
        ? values.sublist(values.length - 3).fold<double>(0, (a, b) => a + b)
        : values.fold<double>(0, (a, b) => a + b);
    final change = previousTotal == 0
        ? (recentTotal > 0 ? 100.0 : 0.0)
        : ((recentTotal - previousTotal) / previousTotal) * 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue Overview',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Completed platform fees, last 7 days',
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                  style: GoogleFonts.plusJakartaSans(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loadingRevenueSeries)
            SizedBox(
              height: 210,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accent,
                ),
              ),
            )
          else if (_revenueSeriesError != null)
            SizedBox(
              height: 210,
              child: Center(
                child: Text(
                  'Unable to load revenue data: $_revenueSeriesError',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else if (_revenueSeries.isEmpty)
            SizedBox(
              height: 210,
              child: Center(
                child: Text(
                  'No completed fee revenue in this period',
                  style: GoogleFonts.plusJakartaSans(color: muted),
                ),
              ),
            )
          else
            SuperadminRevenueChart(
              series: _revenueSeries,
              maximum: maximum,
              accent: accent,
              muted: muted,
            ),
        ],
      ),
    );
  }

  Widget _buildKYCEarnings(
      Map<String, dynamic> data, Color cardColor, Color accent, Color muted) {
    final creationEarnings = data['escrow_creation_earnings'] ?? 0.0;
    final releaseEarnings = data['escrow_release_earnings'] ?? 0.0;
    final withdrawEarnings = data['withdraw_fee_earnings'] ?? 0.0;
    final creationCount = data['escrow_creation_count'] ?? 0;
    final releaseCount = data['escrow_release_count'] ?? 0;
    final withdrawCount =
        data['withdraw_transaction_count'] ?? data['withdraw_count'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Revenue',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All platform fee sources',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.analytics_rounded,
                      color: accent,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _earningsBreakdownCard(
                      'Creation Fee',
                      '${creationEarnings.toStringAsFixed(2)} FARM',
                      'From $creationCount escrow creations',
                      Colors.green,
                      cardColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _earningsBreakdownCard(
                      'Release Fee',
                      '${releaseEarnings.toStringAsFixed(2)} FARM',
                      'From $releaseCount escrow releases',
                      Colors.blue,
                      cardColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _earningsBreakdownCard(
                'Withdraw Fee',
                '${withdrawEarnings.toStringAsFixed(2)} FARM',
                'From $withdrawCount withdraws',
                Colors.purple,
                cardColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuperadminFees(Map<String, dynamic>? wallet, Color cardColor,
      Color accent, Color muted) {
    final balance = wallet == null
        ? 0.0
        : (wallet['available_balance'] ?? wallet['balance'] ?? 0.0);
    final displayBalance = (balance is num)
        ? (balance).toDouble()
        : double.tryParse(balance.toString()) ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Revenues',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SuperadminWalletPage(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escrow + Withdrawals',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${displayBalance.toStringAsFixed(2)} FARM',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Operations wallet balance',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: accent,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _earningsBreakdownCard(String title, String amount, String description,
      Color colorAccent, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(
              color: colorAccent,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemHealth(
      Map<String, dynamic> data, Color cardColor, Color accent, Color muted) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Health',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Operational',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _healthItem('API Servers', '99.8%', Colors.green, cardColor),
          const SizedBox(height: 12),
          _healthItem('Database', '99.9%', Colors.green, cardColor),
          const SizedBox(height: 12),
          _healthItem('Payment Gateway', '99.5%', Colors.green, cardColor),
          const SizedBox(height: 12),
          _healthItem('Storage', '98.7%', Colors.orange, cardColor),
        ],
      ),
    );
  }

  Widget _healthItem(
      String name, String status, Color statusColor, Color cardColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: GoogleFonts.plusJakartaSans(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExchangeRatesSection(
      Map<String, dynamic> data, Color cardColor, Color accent, Color muted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exchange Rates',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adjust the KES ⇄ FARM conversion rates used by wallet balance displays and payment calculations.',
            style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_loadingExchangeRates)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildRateField(
                'KES → FARM', _kesToFarmCtrl, 'Example: 1.00', accent),
            const SizedBox(height: 16),
            _buildRateField(
                'FARM → KES', _farmToKesCtrl, 'Example: 1.00', accent),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _savingExchangeRates ? null : _saveExchangeRates,
                  style: ElevatedButton.styleFrom(backgroundColor: accent),
                  child: Text(
                    _savingExchangeRates ? 'Saving...' : 'Save Rates',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Changes here are reflected in user wallet balance interfaces and deposit/withdraw conversion calculations.',
                    style:
                        GoogleFonts.plusJakartaSans(color: muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadCurrencyRate() async {
    setState(() => _loadingCurrencyRate = true);
    try {
      final response = await AdminApiService.getCurrencyRates();
      final rows = response['data'] as List<dynamic>? ?? [];
      if (rows.isEmpty) {
        _usdToKesCtrl.text = '150';
        _farmToUsdCtrl.text = '0.00666667';
        return;
      }

      final current = rows.first as Map<String, dynamic>;
      final usdKes = (current['usd_kes_rate'] ?? 150).toString();
      final farmUsd =
          (current['farm_usd_rate'] ?? (1 / double.parse(usdKes)).toString())
              .toString();
      if (mounted) {
        _usdToKesCtrl.text = usdKes;
        _farmToUsdCtrl.text = farmUsd;
      }
    } catch (e, st) {
      debugPrint('[SuperadminDashboardPage] _loadCurrencyRate failed: $e');
      debugPrint(st.toString());
    } finally {
      if (mounted) setState(() => _loadingCurrencyRate = false);
    }
  }

  Future<void> _saveCurrencyRate() async {
    if (_usdToKesCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide the USD/KES rate')),
      );
      return;
    }

    setState(() => _savingCurrencyRate = true);
    try {
      final response = await AdminApiService.updateCurrencyRate(
        double.parse(_usdToKesCtrl.text.trim()),
      );
      final message = response['message'] ?? 'Conversion rate updated';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
      await _loadCurrencyRate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error saving conversion rate: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCurrencyRate = false);
    }
  }

  Widget _buildCurrencyConversionRatesSection(
      Color cardColor, Color accent, Color muted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currency Conversion Rates',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set the authoritative USD/KES rate. FARM is fixed at 1 KES and all crypto conversion values are derived from this single source.',
            style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_loadingCurrencyRate)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildRateField(
                'USD → KES', _usdToKesCtrl, 'Example: 150.00', accent),
            const SizedBox(height: 16),
            _buildRateField(
                'FARM → USD', _farmToUsdCtrl, 'Auto-derived', accent),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _savingCurrencyRate ? null : _saveCurrencyRate,
                  style: ElevatedButton.styleFrom(backgroundColor: accent),
                  child: Text(
                    _savingCurrencyRate ? 'Saving...' : 'Save Conversion Rate',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '1 FARM = 1 KES and 1 FARM = 1 / USD_KES_RATE USD. USDC and USDT use the same derived value.',
                    style:
                        GoogleFonts.plusJakartaSans(color: muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRateField(String label, TextEditingController controller,
      String hint, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF0A121F),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accent),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildMonitoringCards(
      Map<String, dynamic> data, Color cardColor, Color accent, Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Monitoring',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        _monitoringCard(
            'Pending KYC Reviews',
            '${data['pending_kyc'] ?? 0}',
            accent,
            cardColor,
            Icons.verified_user,
            () => _openAdminPage(const KycManagementPage())),
        const SizedBox(height: 12),
        _monitoringCard(
            'Flagged Transactions',
            '${data['flagged_transactions'] ?? 0}',
            accent,
            cardColor,
            Icons.warning_rounded,
            () => _openAdminPage(const TransactionsManagementPage())),
        const SizedBox(height: 12),
        _monitoringCard(
            'Support Tickets',
            '${data['support_tickets'] ?? 0}',
            accent,
            cardColor,
            Icons.support_agent,
            () => _openAdminPage(const SupportInboxPage())),
        const SizedBox(height: 12),
        _monitoringCard(
            'Pending Disputes',
            '${data['pending_disputes'] ?? 0}',
            accent,
            cardColor,
            Icons.gavel_rounded,
            () => _openAdminPage(
                const EscrowManagementPage(initialFilter: 'disputed'))),
      ],
    );
  }

  Widget _monitoringCard(String title, String count, Color accent,
      Color cardColor, IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count,
                style: GoogleFonts.plusJakartaSans(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities(
      Map<String, dynamic> data, Color cardColor, Color muted) {
    final activities = data['recent_activities'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activities',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: activities.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No recent activities',
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: (activities.length > 5 ? 5 : activities.length),
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.white10,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final activity = activities[index] as Map<String, dynamic>?;
                    return InkWell(
                      onTap: activity == null
                          ? null
                          : () => TransactionReceiptService.showDetails(
                              context, Map<String, dynamic>.from(activity)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity?['description'] ?? 'Activity',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    activity?['timestamp'] ?? '',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                activity?['type'] ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
