import 'package:flutter/material.dart';

import '../services/biometric_service.dart';
import '../state/app_state.dart';
import 'dashboard_page.dart';
import 'login_page.dart';

enum _GateState { loading, biometric, loggedIn, loggedOut }

/// Loads saved login (if any) then shows [DashboardPage], biometric gate, or [LoginPage].
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  _GateState _state = _GateState.loading;
  bool _bioLoading = false;
  String? _savedUsername;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final app = AppStateScope.of(context);
    await app.loadPersistedSession();
    if (!mounted) return;

    if (app.isLoggedIn) {
      setState(() => _state = _GateState.loggedIn);
      return;
    }

    final hasCreds = await BiometricService.instance.hasCredentials();
    final bioAvail  = await BiometricService.instance.isAvailable();
    _savedUsername  = await BiometricService.instance.savedUsername();

    if (!mounted) return;
    if (hasCreds && bioAvail) {
      setState(() => _state = _GateState.biometric);
      _doBiometric();
    } else {
      setState(() => _state = _GateState.loggedOut);
    }
  }

  Future<void> _doBiometric() async {
    if (_bioLoading) return;
    setState(() => _bioLoading = true);
    final ok = await AppStateScope.of(context).tryBiometricRelogin();
    if (!mounted) return;
    if (ok) {
      setState(() => _state = _GateState.loggedIn);
    } else {
      setState(() => _bioLoading = false);
    }
  }

  void _goToLogin() {
    setState(() => _state = _GateState.loggedOut);
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _GateState.loading:
        return const _SplashScreen();
      case _GateState.biometric:
        return _BiometricGate(
          username:    _savedUsername ?? '',
          loading:     _bioLoading,
          onRetry:     _doBiometric,
          onUsePassword: _goToLogin,
        );
      case _GateState.loggedIn:
        return const DashboardPage();
      case _GateState.loggedOut:
        return const LoginPage();
    }
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF0D0912),
    body: Center(
      child: CircularProgressIndicator(color: Color(0xFFC9956C), strokeWidth: 2.5),
    ),
  );
}

// ── Biometric gate screen ─────────────────────────────────────────────────────
class _BiometricGate extends StatelessWidget {
  const _BiometricGate({
    required this.username,
    required this.loading,
    required this.onRetry,
    required this.onUsePassword,
  });

  final String   username;
  final bool     loading;
  final VoidCallback onRetry;
  final VoidCallback onUsePassword;

  @override
  Widget build(BuildContext context) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : 'S';
    return Scaffold(
      backgroundColor: const Color(0xFF0D0912),
      body: Stack(children: [
        // Background orbs
        Positioned(top: -80, right: -100,
          child: _orb(260, const Color(0x22C9956C))),
        Positioned(bottom: 60, left: -120,
          child: _orb(300, const Color(0x188B5CF6))),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Logo / avatar
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE0B585), Color(0xFFC9956C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x60C9956C),
                          blurRadius: 28, offset: Offset(0, 10)),
                    ],
                  ),
                  child: Center(
                    child: Text(initial,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 36,
                        fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Welcome Back',
                  style: TextStyle(color: Color(0xFFF5EEE8),
                      fontSize: 26, fontWeight: FontWeight.w800,
                      letterSpacing: 0.3)),
                const SizedBox(height: 6),
                if (username.isNotEmpty)
                  Text(username,
                    style: const TextStyle(color: Color(0xFFC9956C),
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Use biometrics to sign in',
                  style: TextStyle(color: Color(0x80F5EEE8), fontSize: 13)),

                const SizedBox(height: 52),

                // Fingerprint button
                GestureDetector(
                  onTap: loading ? null : onRetry,
                  child: Container(
                    width: 84, height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: loading
                          ? const Color(0xFF1E1A26)
                          : const Color(0xFF1B1525),
                      border: Border.all(
                        color: const Color(0xFFC9956C).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: loading ? [] : const [
                        BoxShadow(color: Color(0x40C9956C),
                            blurRadius: 20, spreadRadius: 2),
                      ],
                    ),
                    child: loading
                        ? const Center(
                            child: SizedBox(width: 28, height: 28,
                              child: CircularProgressIndicator(
                                  color: Color(0xFFC9956C), strokeWidth: 2.5)))
                        : const Icon(Icons.fingerprint_rounded,
                            color: Color(0xFFC9956C), size: 44),
                  ),
                ),

                const SizedBox(height: 20),
                const Text('Tap to authenticate',
                  style: TextStyle(color: Color(0x60F5EEE8), fontSize: 12)),

                const Spacer(),

                // Use password instead
                TextButton(
                  onPressed: onUsePassword,
                  child: const Text('Use password instead',
                    style: TextStyle(
                      color: Color(0x80F5EEE8), fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0x50F5EEE8),
                    )),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

