import 'dart:async';

import 'package:flutter/material.dart';

class AdminPageRefreshCoordinator {
  AdminPageRefreshCoordinator._();

  static final ValueNotifier<int> _refreshSignal = ValueNotifier<int>(0);

  static void requestRefresh() {
    _refreshSignal.value++;
  }
}

mixin AdminPageRefreshMixin<T extends StatefulWidget> on State<T> {
  int _lastRefreshSignal = 0;

  Future<void> refreshAdminPage();

  void _handleRefreshSignal() {
    final signal = AdminPageRefreshCoordinator._refreshSignal.value;
    if (!mounted || signal == _lastRefreshSignal) return;
    _lastRefreshSignal = signal;
    unawaited(refreshAdminPage());
  }

  @override
  void initState() {
    super.initState();
    _lastRefreshSignal = AdminPageRefreshCoordinator._refreshSignal.value;
    AdminPageRefreshCoordinator._refreshSignal.addListener(_handleRefreshSignal);
  }

  @override
  void dispose() {
    AdminPageRefreshCoordinator._refreshSignal
        .removeListener(_handleRefreshSignal);
    super.dispose();
  }
}
