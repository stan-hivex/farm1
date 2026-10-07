import 'package:farm/admin/services/admin_page_refresh_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('refreshes the mounted page without recreating its state',
      (tester) async {
    final key = GlobalKey<_RefreshAwarePageState>();
    await tester.pumpWidget(
      MaterialApp(home: _RefreshAwarePage(key: key)),
    );
    final initialState = key.currentState;

    AdminPageRefreshCoordinator.requestRefresh();
    await tester.pump();

    expect(find.text('Refresh count: 1'), findsOneWidget);
    expect(identical(key.currentState, initialState), isTrue);
  });
}

class _RefreshAwarePage extends StatefulWidget {
  const _RefreshAwarePage({super.key});

  @override
  State<_RefreshAwarePage> createState() => _RefreshAwarePageState();
}

class _RefreshAwarePageState extends State<_RefreshAwarePage>
    with AdminPageRefreshMixin<_RefreshAwarePage> {
  int _refreshCount = 0;

  @override
  Future<void> refreshAdminPage() async {
    setState(() => _refreshCount++);
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text('Refresh count: $_refreshCount'));
}
