import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:socket_io_client/socket_io_client.dart' show OptionBuilder;

import '../state/app_state.dart';

/// Displays a HelaPOS / LankaQR code and polls until the payment succeeds or
/// the user cancels.
///
/// Usage:
/// ```dart
/// final confirmed = await QrPaymentDialog.show(context, amount: 1500.0);
/// if (confirmed) { /* continue with booking */ }
/// ```
class QrPaymentDialog extends StatefulWidget {
  final double amount;

  const QrPaymentDialog._({required this.amount});

  /// Shows the dialog and returns [true] when the payment succeeds,
  /// or [false] when the user dismisses it.
  static Future<bool> show(BuildContext context, {required double amount}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QrPaymentDialog._(amount: amount),
    );
    return result ?? false;
  }

  @override
  State<QrPaymentDialog> createState() => _QrPaymentDialogState();
}

enum _QrStatus { loading, ready, success, failed }


class _QrPaymentDialogState extends State<QrPaymentDialog> {
  _QrStatus _status = _QrStatus.loading;
  String? _qrString;
  String? _reference;
  String? _qrReference;
  String? _errorMsg;
  AppState? _appState;

  Timer? _pollTimer;
  // Slow poll to avoid HelaPOS rate-limiting (they block at ~1 req/3s)
  static const _pollInterval = Duration(seconds: 6);
  int _pollCount = 0;
  static const _maxPolls = 100; // ~10 minutes max

  // Socket.IO for instant webhook-based confirmation
  sio.Socket? _socket;

  // --- payment_status values from HelaPOS API ---
  static const int _statusPending = 0;
  static const int _statusSuccess = 2;
  static const int _statusFailed = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = AppStateScope.of(context);
    if (_appState != appState) {
      _appState = appState;
      _generateQR();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _disconnectSocket();
    super.dispose();
  }

  Future<void> _generateQR() async {
    try {
      final appState = _appState;
      if (appState == null) return;
      final result = await appState.generateQRPayment(amount: widget.amount);

      final qrString   = result['qr_string']   as String?;
      final reference  = result['reference']    as String?;
      final qrRef      = result['qr_reference'] as String?;

      if (!mounted) return;

      if (qrString == null || qrString.isEmpty) {
        setState(() {
          _status   = _QrStatus.failed;
          _errorMsg = 'No QR data received from server.';
        });
        return;
      }

      setState(() {
        _qrString    = qrString;
        _reference   = reference;
        _qrReference = qrRef;
        _status      = _QrStatus.ready;
      });

      _connectSocket();
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status   = _QrStatus.failed;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Socket.IO: listen for instant webhook confirmation ─────────────────────
  void _connectSocket() {
    try {
      final apiBase = _appState?.apiBaseUrl ?? '';
      if (apiBase.isEmpty) return;

      // Derive socket origin from API base URL (same as WalkInQueueSocket)
      final u = Uri.parse(apiBase);
      final port = u.hasPort ? ':${u.port}' : '';
      final origin = '${u.scheme}://${u.host}$port';

      _socket = sio.io(
        origin,
        OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(2000)
            .enableForceNew()
            .build(),
      );

      _socket!.on('qr:payment', (data) {
        if (!mounted || _status == _QrStatus.success) return;

        final map = data is Map ? data : <String, dynamic>{};
        final ref = map['reference']?.toString() ?? '';
        final qrRef = map['qr_reference']?.toString() ?? '';

        // Only accept events for THIS payment
        final matchesRef = _reference != null && _reference!.isNotEmpty && ref == _reference;
        final matchesQr  = _qrReference != null && _qrReference!.isNotEmpty && qrRef == _qrReference;

        if (!matchesRef && !matchesQr) return;

        final rawStatus = map['payment_status'];
        final payStatus = rawStatus is int
            ? rawStatus
            : int.tryParse('$rawStatus') ?? _statusPending;

        if (payStatus == _statusSuccess) {
          _pollTimer?.cancel();
          setState(() => _status = _QrStatus.success);
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        } else if (payStatus == _statusFailed) {
          _pollTimer?.cancel();
          setState(() {
            _status   = _QrStatus.failed;
            _errorMsg = 'Payment was declined or cancelled by the bank.';
          });
        }
      });
    } catch (_) {
      // Socket connection is optional — polling is the fallback
    }
  }

  void _disconnectSocket() {
    final s = _socket;
    _socket = null;
    if (s != null) {
      s.dispose();
    }
  }

  void _startPolling() {
    _pollCount = 0;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;
    _pollCount++;

    // Safety: stop polling after max attempts
    if (_pollCount > _maxPolls) {
      _pollTimer?.cancel();
      if (_status == _QrStatus.ready) {
        setState(() {
          _status   = _QrStatus.failed;
          _errorMsg = 'Payment timed out. Please try again.';
        });
      }
      return;
    }

    try {
      final appState = _appState;
      if (appState == null) return;
      final data = await appState.checkQRPaymentStatus(
        reference:   _reference,
        qrReference: _qrReference,
      );

      if (!mounted) return;

      final rawStatus = data['payment_status'];
      final payStatus = rawStatus is int ? rawStatus : int.tryParse('$rawStatus') ?? _statusPending;

      if (payStatus == _statusSuccess) {
        _pollTimer?.cancel();
        setState(() => _status = _QrStatus.success);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).pop(true);
      } else if (payStatus == _statusFailed) {
        _pollTimer?.cancel();
        setState(() {
          _status   = _QrStatus.failed;
          _errorMsg = 'Payment was declined or cancelled by the bank.';
        });
      }
      // _statusPending → keep polling
    } catch (_) {
      // Transient network error or rate limit – keep polling silently
    }
  }

  void _cancel() {
    _pollTimer?.cancel();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gradient header
            Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 0),
              child: Column(
                children: [
                  Icon(Icons.qr_code_2_rounded, size: 44, color: Colors.white),
                  const SizedBox(height: 6),
                  Text('QR Payment', style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Amount', style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey[600])),
                  const SizedBox(height: 2),
                  Text(
                    'Rs. ${widget.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF059669), fontWeight: FontWeight.w900, fontSize: 28),
                  ),
                  const SizedBox(height: 18),
                  _buildBody(),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _buildActions(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _QrStatus.loading:
        return const Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        );

      case _QrStatus.ready:
        return Column(
          children: [
            QrImageView(
              data: _qrString!,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            const Text(
              'Scan with your banking app to pay',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Waiting for payment…', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        );

      case _QrStatus.success:
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green),
            SizedBox(height: 10),
            Text('Payment Received!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
          ]),
        );

      case _QrStatus.failed:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: Colors.red),
            const SizedBox(height: 10),
            Text(
              _errorMsg ?? 'Payment failed.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ]),
        );
    }
  }

  List<Widget> _buildActions() {
    if (_status == _QrStatus.success) return [];
    final List<Widget> actions = [];
    actions.add(
      TextButton(
        onPressed: _cancel,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF059669),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        child: Text(_status == _QrStatus.failed ? 'Close' : 'Cancel'),
      ),
    );
    if (_status == _QrStatus.failed) {
      actions.add(const SizedBox(width: 8));
      actions.add(
        ElevatedButton(
          onPressed: () {
            setState(() {
              _status   = _QrStatus.loading;
              _errorMsg = null;
              _qrString = null;
            });
            _generateQR();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          child: const Text('Retry'),
        ),
      );
    }
    return actions;
  }
}
