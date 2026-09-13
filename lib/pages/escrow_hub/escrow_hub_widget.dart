import '/backend/services/api_service.dart';
import '/backend/models/escrow_model.dart';
import '/components/escrow_item/escrow_item_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/core/theme_extensions.dart';
import '/services/app_session_manager.dart';

import '/services/transaction_authentication_service.dart';
import '/services/transaction_authorization_service.dart';
import '/services/transaction_receipt_service.dart';
import '/backend/api_requests/escrow_api_service.dart';
import '/backend/api_requests/user_api_service.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class EscrowHubWidget extends StatefulWidget {
  const EscrowHubWidget({super.key});

  static String routeName = 'EscrowHub';
  static String routePath = '/escrowHub';

  @override
  State<EscrowHubWidget> createState() => _EscrowHubWidgetState();
}

class _EscrowHubWidgetState extends State<EscrowHubWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool isLoading = false;

  String selectedFilter = 'all';

  List<EscrowModel> escrows = [];
  final Set<String> _selectedEscrows = <String>{};

  int activeCount = 0;
  double protectedAmount = 0;

  Map<String, dynamic> _escrowReceiptData(EscrowModel escrow) {
    final currentUserId = context.read<FFAppState>().userId;
    return {
      'transaction_type': 'Escrow',
      'id': escrow.id,
      'amount': escrow.amount,
      'status': escrow.status,
      'created_at': escrow.createdAt.toIso8601String(),
      'role': escrow.getRoleForUser(currentUserId),
      'counterparty': escrow.getCounterpartyDisplayName(currentUserId),
      'buyer_username': escrow.buyerUsername,
      'seller_username': escrow.sellerUsername,
    };
  }

  Future<void> _downloadSelectedEscrows() async {
    final selected = escrows
        .where((escrow) => _selectedEscrows.contains(escrow.id))
        .map(_escrowReceiptData)
        .toList();
    try {
      await TransactionReceiptService.downloadReceipts(selected);
      if (mounted) {
        setState(() => _selectedEscrows.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected receipts saved to gallery')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save receipts: $error')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchEscrows();
    });
  }

  Future<void> searchUsers(
      String value, TextEditingController controller) async {
    if (value.trim().isEmpty) {
      return;
    }

    try {
      await UserApiService.searchUsers(query: value.trim());
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> fetchEscrows() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final resp = await ApiService.getEscrows(
          status: selectedFilter == 'all' ? null : selectedFilter);

      if (!mounted) return;

      final items = List<dynamic>.from(resp['data'] ?? resp);

      setState(() {
        escrows = items
            .map((m) => EscrowModel.fromJson(m as Map<String, dynamic>))
            .toList();

        activeCount = escrows.where((e) => e.status == 'active').length;

        protectedAmount = escrows.where((e) => e.status == 'active').fold(
              0.0,
              (sum, item) => sum + item.amount,
            );
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to fetch escrows: $e',
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> releaseEscrow(String escrowId, {double? releaseAmount}) async {
    // Find the escrow to get the amount
    final escrow = escrows.firstWhere((e) => e.id == escrowId);
    final releaseFee = escrow.amount * 0.015;
    final amountAfterFee = escrow.amount - releaseFee;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Release'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Release breakdown:'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Escrow Amount:'),
                  Text('${escrow.amount.toStringAsFixed(2)} FARM'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Platform Fee (1.5%):'),
                  Text('-${releaseFee.toStringAsFixed(2)} FARM'),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Seller Receives:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${amountAfterFee.toStringAsFixed(2)} FARM',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text('Confirm Release'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final authResult = await TransactionAuthorizationService()
          .authorizeTransaction(
            localizedReason: 'Confirm escrow release',
          )
          .then((r) => r.toTransactionAuthenticationResult());
      if (authResult.biometricUsed == true) {
        await EscrowApiService.releaseEscrow(
          escrowId: escrowId,
          biometricAuth: true,
          deviceFingerprint: authResult.deviceFingerprint,
        );
      } else {
        final pinController = TextEditingController();
        final pin = await showDialog<String>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Enter transaction PIN'),
              content: TextField(
                controller: pinController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PIN'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, pinController.text.trim()),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );

        if (pin == null || pin.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Release cancelled')),
          );
          return;
        }

        await EscrowApiService.releaseEscrow(
          escrowId: escrowId,
          pin: pin,
        );
      }

      await AppSessionManager().syncNow(
        profileTimeoutSeconds: 5,
        walletTimeoutSeconds: 5,
        transactionsTimeoutSeconds: 5,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Funds released successfully. Seller receives ${amountAfterFee.toStringAsFixed(2)} FARM (after 1.5% fee).'),
        ),
      );

      fetchEscrows();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Release failed: $e'),
        ),
      );
    }
  }

  Future<void> disputeEscrow(String escrowId) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Raise Dispute'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter dispute reason',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text);
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    try {
      await ApiService.disputeEscrow(escrowId, reason);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispute raised'),
        ),
      );

      fetchEscrows();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispute failed: $e'),
        ),
      );
    }
  }

  Future<void> showCreateEscrowDialog() async {
    final sellerController = TextEditingController();
    final amountController = TextEditingController();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final pinFocusNode = FocusNode();
    final pinController = TextEditingController();
    TransactionAuthenticationResult? lastPinAuthResult;

    await showDialog(
      context: context,
      builder: (context) {
        bool pinEntryEnabled = false;
        bool isBiometricChecking = false;

        return StatefulBuilder(
          builder: (context, setState) {
            double amount = 0;
            double fee = 0;
            double totalRequired = 0;
            List<dynamic> suggestionUsers = [];

            Future<void> searchUsers(String value) async {
              if (!UserApiService.shouldSearchSuggestions(value)) {
                setState(() => suggestionUsers = []);
                return;
              }

              try {
                final users = await UserApiService.searchUsers(
                  query: value.trim(),
                );
                if (!mounted) return;
                setState(() => suggestionUsers = users);
              } catch (_) {
                if (!mounted) return;
                setState(() => suggestionUsers = []);
              }
            }

            // Update values if amount is valid
            try {
              if (amountController.text.isNotEmpty) {
                amount = double.parse(amountController.text.trim());
                fee = double.parse((amount * 0.015).toStringAsFixed(2));
                totalRequired = amount + fee;
              }
            } catch (_) {}

            return AlertDialog(
              title: Text('Create Escrow'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: sellerController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            hintText: 'Recipient username or phone number',
                            helperText:
                                'You can pick a seller by username or phone number',
                            helperStyle: TextStyle(
                              color: FlutterFlowTheme.of(context).secondaryText,
                              fontSize: 12,
                            ),
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryText
                                    .withAlpha(61),
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            searchUsers(value);
                          },
                        ),
                        if (suggestionUsers.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              border: Border.all(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryText
                                    .withAlpha(41),
                              ),
                            ),
                            child: Column(
                              children: suggestionUsers.map((u) {
                                final user = u is Map
                                    ? Map<String, dynamic>.from(u)
                                    : <String, dynamic>{};
                                final username =
                                    (user['username'] ?? '').toString().trim();
                                final phone = (user['phone'] ??
                                        user['phone_number'] ??
                                        user['mobile'] ??
                                        '')
                                    .toString()
                                    .trim();
                                final identifier = username.isNotEmpty
                                    ? username
                                    : phone;
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    child: Text(
                                      (username.isNotEmpty ? username : phone)
                                              .isNotEmpty
                                          ? (username.isNotEmpty
                                                  ? username
                                                  : phone)[0]
                                              .toUpperCase()
                                          : '?',
                                    ),
                                  ),
                                  title: Text(UserApiService.getSuggestionLabel(
                                    user,
                                  )),
                                  enabled: identifier.isNotEmpty,
                                  onTap: () {
                                    if (identifier.isEmpty) return;
                                    sellerController
                                      ..text = identifier
                                      ..selection = TextSelection.collapsed(
                                        offset: identifier.length,
                                      );
                                    setState(() => suggestionUsers = []);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount (FARM)',
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    // Fee breakdown section
                    if (amount > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fee Breakdown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Escrow Amount:'),
                                Text('${amount.toStringAsFixed(2)} FARM'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Platform Fee (1.5%):'),
                                Text('${fee.toStringAsFixed(2)} FARM'),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Required:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${totalRequired.toStringAsFixed(2)} FARM',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return TextField(
                          controller: pinController,
                          focusNode: pinFocusNode,
                          obscureText: true,
                          readOnly: !pinEntryEnabled || isBiometricChecking,
                          onTap: () async {
                            if (!pinEntryEnabled && !isBiometricChecking) {
                              setState(() => isBiometricChecking = true);
                              final result =
                                  await TransactionAuthorizationService()
                                      .authorizeTransaction(
                                        localizedReason:
                                            'Confirm escrow creation',
                                      )
                                      .then((r) => r
                                          .toTransactionAuthenticationResult());
                              lastPinAuthResult = result;
                              if (!mounted) return;

                              if (result.biometricUsed) {
                                setState(() => isBiometricChecking = false);
                                try {
                                  final amount = double.tryParse(
                                          amountController.text.trim()) ??
                                      0;
                                  if (amount <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Enter a valid amount')),
                                    );
                                    return;
                                  }

                                  final walletResp =
                                      await ApiService.getWallet();
                                  final wallet =
                                      walletResp['data'] ?? walletResp;
                                  final available = double.tryParse(
                                          (wallet['available_balance'] ??
                                                  wallet['balance'] ??
                                                  '0')
                                              .toString()) ??
                                      0;
                                  final fee = double.tryParse((amount * 0.015)
                                          .toStringAsFixed(2)) ??
                                      0;
                                  if (available < amount + fee) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Insufficient balance. You need at least ${(amount + fee).toStringAsFixed(2)} FARM to create this escrow (including ${fee.toStringAsFixed(2)} FARM fee).'),
                                      ),
                                    );
                                    return;
                                  }

                                  await ApiService.request(
                                    method: 'POST',
                                    path: '/escrow',
                                    body: {
                                      'seller_identifier':
                                          sellerController.text.trim(),
                                      'amount': amount,
                                      'title': titleController.text.trim(),
                                      'description':
                                          descriptionController.text.trim(),
                                      'pin': null,
                                      'biometric_auth': true,
                                      'device_fingerprint':
                                          result.deviceFingerprint,
                                    },
                                  );

                                  if (!mounted) return;
                                  await AppSessionManager().syncNow(
                                    profileTimeoutSeconds: 5,
                                    walletTimeoutSeconds: 5,
                                    transactionsTimeoutSeconds: 5,
                                  );
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Escrow created successfully. Fee deducted and credited to platform.'),
                                    ),
                                  );
                                  await fetchEscrows();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Escrow creation failed: $e')),
                                  );
                                }
                                return;
                              }

                              setState(() {
                                pinEntryEnabled = true;
                                isBiometricChecking = false;
                              });
                              pinFocusNode.requestFocus();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'PIN',
                            suffixIcon: isBiometricChecking
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final amount = double.parse(amountController.text.trim());
                      final fee =
                          double.parse((amount * 0.015).toStringAsFixed(2));

                      // Check wallet balance
                      final walletResp = await ApiService.getWallet();
                      final wallet = walletResp['data'] ?? walletResp;
                      final available = double.tryParse(
                              (wallet['available_balance'] ?? wallet['balance'])
                                  .toString()) ??
                          0;

                      if (available < amount + fee) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Insufficient balance. You need at least ${(amount + fee).toStringAsFixed(2)} FARM to create this escrow (including ${fee.toStringAsFixed(2)} FARM fee).'),
                          ),
                        );
                        return;
                      }

                      // Create escrow (backend handles fee deduction)
                      final authResult = lastPinAuthResult ??
                          await TransactionAuthorizationService()
                              .authorizeTransaction(
                                localizedReason: 'Confirm escrow creation',
                              )
                              .then(
                                  (r) => r.toTransactionAuthenticationResult());

                      if (authResult?.biometricUsed == true) {
                        await ApiService.request(
                          method: 'POST',
                          path: '/escrow',
                          body: {
                            'seller_identifier': sellerController.text.trim(),
                            'amount': amount,
                            'title': titleController.text.trim(),
                            'description': descriptionController.text.trim(),
                            'pin': null,
                            'biometric_auth': true,
                            'device_fingerprint': authResult?.deviceFingerprint,
                          },
                        );
                      } else {
                        if (pinController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Enter your transaction PIN')),
                          );
                          return;
                        }

                        await ApiService.request(
                          method: 'POST',
                          path: '/escrow',
                          body: {
                            'seller_identifier': sellerController.text.trim(),
                            'amount': amount,
                            'title': titleController.text.trim(),
                            'description': descriptionController.text.trim(),
                            'pin': pinController.text.trim(),
                          },
                        );
                      }

                      if (mounted) {
                        await AppSessionManager().syncNow(
                          profileTimeoutSeconds: 5,
                          walletTimeoutSeconds: 5,
                          transactionsTimeoutSeconds: 5,
                        );
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Escrow created successfully. Fee deducted and credited to platform.',
                            ),
                          ),
                        );

                        fetchEscrows();
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$e'),
                        ),
                      );
                    }
                  },
                  child: Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<EscrowModel> get filteredEscrows {
    if (selectedFilter == 'all') {
      return escrows;
    }

    return escrows.where((e) => e.status == selectedFilter).toList();
  }

  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget buildFilterButton(
    String label,
    String value,
  ) {
    final isSelected = selectedFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = value;
        });

        fetchEscrows();
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? FlutterFlowTheme.of(context).primaryText
              : FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: FlutterFlowTheme.of(context).alternate,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? FlutterFlowTheme.of(context).primaryBackground
                : FlutterFlowTheme.of(context).primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget buildEscrowCard(EscrowModel escrow) {
    final isPending = escrow.status == 'active';
    final currentUserId = context.read<FFAppState>().userId;
    final role = escrow.getRoleForUser(currentUserId);
    final counterpartyName = escrow.getCounterpartyDisplayName(currentUserId);

    final details = _escrowReceiptData(escrow);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => TransactionReceiptService.showDetails(context, details),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _selectedEscrows.contains(escrow.id),
              title: const Text('Select receipt'),
              onChanged: (selected) => setState(() {
                if (selected == true) {
                  _selectedEscrows.add(escrow.id);
                } else {
                  _selectedEscrows.remove(escrow.id);
                }
              }),
            ),
            EscrowItemWidget(
              amount: escrow.amount.toStringAsFixed(2),
              date: formatDate(escrow.createdAt),
              is_pending: isPending,
              role: role,
              status:
                  escrow.status[0].toUpperCase() + escrow.status.substring(1),
              username: counterpartyName,
            ),
            if (isPending)
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => releaseEscrow(escrow.id),
                        child: const Text('Release Funds'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => disputeEscrow(escrow.id),
                        child: const Text('Dispute'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: showCreateEscrowDialog,
          backgroundColor: FlutterFlowTheme.of(context).primaryText,
          label: Text(
            'Create Escrow',
            style: TextStyle(
              color: FlutterFlowTheme.of(context).primaryBackground,
            ),
          ),
          icon: Icon(
            Icons.add,
            color: FlutterFlowTheme.of(context).primaryBackground,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FlutterFlowIconButton(
                      borderRadius: 8,
                      buttonSize: 40,
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: FlutterFlowTheme.of(context).primaryText,
                      ),
                      onPressed: () {
                        context.goNamed('Dashboard');
                      },
                    ),
                    Text(
                      'Escrow Hub',
                      style: FlutterFlowTheme.of(context).titleLarge.override(
                            font: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                    FlutterFlowIconButton(
                      borderRadius: 8,
                      buttonSize: 40,
                      icon: Icon(
                        Icons.refresh,
                        color: FlutterFlowTheme.of(context).primaryText,
                      ),
                      onPressed: fetchEscrows,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: fetchEscrows,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).primaryText,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Escrow Protection',
                                style: TextStyle(
                                  color:
                                      FlutterFlowTheme.of(context).background70,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Safe & Secure Growth',
                                style: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .override(
                                      font: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                    ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Active',
                                          style: TextStyle(
                                            color: FlutterFlowTheme.of(context)
                                                .background50,
                                          ),
                                        ),
                                        Text(
                                          '$activeCount',
                                          style: FlutterFlowTheme.of(context)
                                              .titleLarge
                                              .override(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryBackground,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Protected',
                                          style: TextStyle(
                                            color: FlutterFlowTheme.of(context)
                                                .background50,
                                          ),
                                        ),
                                        Text(
                                          '${protectedAmount.toStringAsFixed(2)} FARM',
                                          style: FlutterFlowTheme.of(context)
                                              .titleLarge
                                              .override(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryBackground,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              buildFilterButton(
                                'All',
                                'all',
                              ),
                              const SizedBox(width: 12),
                              buildFilterButton(
                                'Active',
                                'active',
                              ),
                              const SizedBox(width: 12),
                              buildFilterButton(
                                'Completed',
                                'completed',
                              ),
                              const SizedBox(width: 12),
                              buildFilterButton(
                                'Disputed',
                                'disputed',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_selectedEscrows.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.download_rounded),
                              label: Text(
                                  'Download selected (${_selectedEscrows.length})'),
                              onPressed: _downloadSelectedEscrows,
                            ),
                          ),
                        if (isLoading)
                          Center(
                            child: CircularProgressIndicator(),
                          )
                        else if (filteredEscrows.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            alignment: Alignment.center,
                            child: Text(
                              'No escrows found',
                            ),
                          )
                        else
                          Column(
                            children: filteredEscrows
                                .map(
                                  (escrow) => buildEscrowCard(
                                    escrow,
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
