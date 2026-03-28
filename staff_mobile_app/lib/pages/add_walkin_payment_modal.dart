import 'package:flutter/material.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _pGreen  = Color(0xFF059669);
const Color _pDark   = Color(0xFF047857);
const Color _pGreenL = Color(0xFFECFDF5);
const Color _pGreenB = Color(0xFFA7F3D0);
const Color _pBg     = Color(0xFFF9FAFB);
const Color _pBorder = Color(0xFFE5E7EB);
const Color _pInk    = Color(0xFF111827);
const Color _pMuted  = Color(0xFF6B7280);

// ─────────────────────────────────────────────────────────────────────────────
class AddWalkInPaymentModalResult {
  const AddWalkInPaymentModalResult({
    required this.method,
    required this.amount,
  });

  final String method;
  final String amount;
}

// ─────────────────────────────────────────────────────────────────────────────
class AddWalkInPaymentModal extends StatefulWidget {
  const AddWalkInPaymentModal({
    required this.initialAmount,
    this.customerName = '',
    this.serviceName  = '',
    super.key,
  });

  final String initialAmount;
  final String customerName;
  final String serviceName;

  static Future<AddWalkInPaymentModalResult?> show(
    BuildContext context, {
    required String initialAmount,
    String customerName = '',
    String serviceName  = '',
  }) {
    return showModalBottomSheet<AddWalkInPaymentModalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddWalkInPaymentModal(
        initialAmount: initialAmount,
        customerName:  customerName,
        serviceName:   serviceName,
      ),
    );
  }

  @override
  State<AddWalkInPaymentModal> createState() =>
      _AddWalkInPaymentModalState();
}

class _AddWalkInPaymentModalState
    extends State<AddWalkInPaymentModal> {
  static const _methods = [
    'Cash', 'Card', 'Online Transfer', 'Loyalty Points', 'Package',
  ];
  static const _methodIcons = <String, IconData>{
    'Cash':            Icons.payments_rounded,
    'Card':            Icons.credit_card_rounded,
    'Online Transfer': Icons.account_balance_rounded,
    'Loyalty Points':  Icons.stars_rounded,
    'Package':         Icons.card_giftcard_rounded,
  };

  final _formKey  = GlobalKey<FormState>();
  late final TextEditingController _amtCtrl;
  String _method  = 'Cash';

  @override
  void initState() {
    super.initState();
    _amtCtrl = TextEditingController(text: widget.initialAmount);
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(AddWalkInPaymentModalResult(
      method: _method,
      amount: _amtCtrl.text.trim(),
    ));
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
      style: const TextStyle(
        color: _pMuted, fontSize: 11.5,
        fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );

  @override
  Widget build(BuildContext context) {
    final bottom   = MediaQuery.of(context).viewInsets.bottom;
    final name     = widget.customerName;
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ')
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .take(2).join()
        : '?';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Drag handle ─────────────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 18),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(99)),
                ),
              ),

              // ── Title row ───────────────────────────────────────────
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: _pGreenL,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _pGreenB),
                  ),
                  child: const Icon(Icons.payments_rounded,
                      color: _pGreen, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Collect Payment',
                        style: TextStyle(
                          color: _pInk, fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2)),
                      Text('Walk-in payment',
                        style: TextStyle(
                          color: Color(0xFFADB5BD), fontSize: 12,
                          fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: _pMuted),
                  ),
                ),
              ]),

              const SizedBox(height: 16),

              // ── Customer info card ──────────────────────────────────
              if (name.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _pGreenL,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _pGreenB),
                  ),
                  child: Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_pDark, _pGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(initials,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                            style: const TextStyle(
                              color: _pInk, fontSize: 14,
                              fontWeight: FontWeight.w800)),
                          if (widget.serviceName.isNotEmpty)
                            Text(widget.serviceName,
                              style: const TextStyle(
                                color: _pMuted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ]),
                ),

              const SizedBox(height: 18),

              // ── Amount ───────────────────────────────────────────────
              _label('AMOUNT (LKR)'),
              TextFormField(
                controller: _amtCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: _pInk),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: const TextStyle(
                      color: Color(0xFFB0B8B0), fontSize: 18),
                  prefixIcon: const Icon(Icons.payments_outlined,
                      color: _pGreen, size: 20),
                  filled: true, fillColor: _pBg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _pBorder)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _pBorder)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: _pGreen, width: 1.8)),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: _pGreen, width: 1.8)),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFF43F5E))),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Amount required';
                  }
                  if ((double.tryParse(v.trim()) ?? 0) <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ── Payment method ──────────────────────────────────────
              _label('PAYMENT METHOD'),
              Wrap(
                spacing: 7, runSpacing: 7,
                children: _methods.map((m) {
                  final sel = _method == m;
                  return GestureDetector(
                    onTap: () => setState(() => _method = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? _pGreenL : _pBg,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: sel ? _pGreen : _pBorder,
                          width: sel ? 1.5 : 1),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          _methodIcons[m] ?? Icons.payments_rounded,
                          size: 14,
                          color: sel ? _pGreen
                                     : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 6),
                        Text(m,
                          style: TextStyle(
                            color: sel ? _pGreen
                                       : const Color(0xFF6B7280),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              Container(height: 1, color: _pBorder,
                  margin: const EdgeInsets.only(bottom: 20)),

              // ── Confirm button ──────────────────────────────────────
              GestureDetector(
                onTap: _submit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_pDark, _pGreen],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                      color: _pGreen.withValues(alpha: 0.30),
                      blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 9),
                      Text('Confirm Payment',
                        style: TextStyle(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2)),
                    ],
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
