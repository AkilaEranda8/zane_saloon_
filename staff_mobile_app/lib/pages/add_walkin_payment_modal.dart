import 'package:flutter/material.dart';

class AddWalkInPaymentModalResult {
  const AddWalkInPaymentModalResult({
    required this.method,
    required this.amount,
  });

  final String method;
  final String amount;
}

class AddWalkInPaymentModal extends StatefulWidget {
  const AddWalkInPaymentModal({
    required this.initialAmount,
    super.key,
  });

  final String initialAmount;

  static Future<AddWalkInPaymentModalResult?> show(
    BuildContext context, {
    required String initialAmount,
  }) {
    return showDialog<AddWalkInPaymentModalResult>(
      context: context,
      builder: (_) => AddWalkInPaymentModal(initialAmount: initialAmount),
    );
  }

  @override
  State<AddWalkInPaymentModal> createState() => _AddWalkInPaymentModalState();
}

class _AddWalkInPaymentModalState extends State<AddWalkInPaymentModal> {
  static const _methods = <String>['Cash', 'Card', 'Online Transfer'];
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  String _method = _methods.first;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.initialAmount);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AddWalkInPaymentModalResult(
        method: _method,
        amount: _amountController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Payment'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: _methods.map((m) => DropdownMenuItem<String>(value: m, child: Text(m))).toList(),
              onChanged: (value) {
                if (value == null || value.trim().isEmpty) return;
                setState(() => _method = value);
              },
            ),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Amount required';
                if ((double.tryParse(value.trim()) ?? 0) <= 0) return 'Enter valid amount';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
