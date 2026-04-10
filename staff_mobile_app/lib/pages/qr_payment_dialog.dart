import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

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

  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 3);

  // --- payment_status values from HelaPOS API ---
  static const int _statusPending = 0;
  static const int _statusSuccess = 2;
  static const int _statusFailed = -1;

  @override
  void initState() {
    super.initState();
    _generateQR();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateQR() async {
    try {
      final appState = AppStateScope.of(context);
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

      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status   = _QrStatus.failed;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;
    try {
      final appState = AppStateScope.of(context);
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
      // Transient network error – keep polling silently
    }
  }

  void _cancel() {
    _pollTimer?.cancel();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.qr_code_2_rounded, size: 28),
        const SizedBox(width: 10),
        const Text('QR Payment'),
      ]),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Amount: Rs. ${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            _buildBody(),
          ],
        ),
      ),
      actions: _buildActions(),
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

    return [
      TextButton(
        onPressed: _cancel,
        child: Text(_status == _QrStatus.failed ? 'Close' : 'Cancel'),
      ),
      if (_status == _QrStatus.failed)
        TextButton(
          onPressed: () {
            setState(() {
              _status   = _QrStatus.loading;
              _errorMsg = null;
              _qrString = null;
            });
            _generateQR();
          },
          child: const Text('Retry'),
        ),
    ];
  }
}
