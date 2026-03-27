import 'package:flutter/material.dart';

class AddCustomerModalResult {
  const AddCustomerModalResult({
    required this.name,
    required this.phone,
    required this.email,
    required this.branchId,
  });

  final String name;
  final String phone;
  final String email;
  final String? branchId;
}

class AddCustomerModal extends StatefulWidget {
  const AddCustomerModal({
    required this.branches,
    this.initialBranchId,
    super.key,
  });

  final List<Map<String, String>> branches;
  final String? initialBranchId;

  static Future<AddCustomerModalResult?> show(
    BuildContext context, {
    required List<Map<String, String>> branches,
    String? initialBranchId,
  }) {
    return showDialog<AddCustomerModalResult>(
      context: context,
      builder: (_) => AddCustomerModal(
        branches: branches,
        initialBranchId: initialBranchId,
      ),
    );
  }

  @override
  State<AddCustomerModal> createState() => _AddCustomerModalState();
}

class _AddCustomerModalState extends State<AddCustomerModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.initialBranchId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AddCustomerModalResult(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        branchId: _selectedBranchId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Customer'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Name required';
                return null;
              },
            ),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Phone required';
                return null;
              },
            ),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            if (widget.branches.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedBranchId,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: widget.branches
                    .map(
                      (branch) => DropdownMenuItem<String>(
                        value: branch['id'],
                        child: Text(branch['name'] ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBranchId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Branch required';
                  return null;
                },
              ),
            ],
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
