import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'dashboard_page.dart';
import 'login_page.dart';

/// Loads saved login (if any) then shows [DashboardPage] or [LoginPage].
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    await AppStateScope.of(context).loadPersistedSession();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final loggedIn = AppStateScope.of(context).isLoggedIn;
    return loggedIn ? const DashboardPage() : const LoginPage();
  }
}
