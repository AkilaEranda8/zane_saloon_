import 'package:flutter/material.dart';

import '../models/salon_service.dart';

class AddWalkInModalResult {
  const AddWalkInModalResult({
    required this.branchId,
    required this.customerName,
    required this.phone,
    required this.serviceId,
    required this.note,
  });

  final String branchId;
  final String customerName;
  final String phone;
  final String serviceId;
  final String note;
}

class AddWalkInModal extends StatefulWidget {
  const AddWalkInModal({
    required this.branches,
    required this.services,
    this.initialBranchId,
    super.key,
  });

  final List<Map<String, String>> branches;
  final List<SalonService> services;
  final String? initialBranchId;

  static Future<AddWalkInModalResult?> show(
    BuildContext context, {
    required List<Map<String, String>> branches,
    required List<SalonService> services,
    String? initialBranchId,
  }) {
    return showDialog<AddWalkInModalResult>(
      context: context,
      builder: (_) => AddWalkInModal(
        branches: branches,
        services: services,
        initialBranchId: initialBranchId,
      ),
    );
  }

  @override
  State<AddWalkInModal> createState() => _AddWalkInModalState();
}

class _AddWalkInModalState extends State<AddWalkInModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  String? _branchId;
  String? _serviceId;

  @override
  void initState() {
    super.initState();
    _branchId = widget.initialBranchId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AddWalkInModalResult(
        branchId: (_branchId ?? '').trim(),
        customerName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        serviceId: (_serviceId ?? '').trim(),
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeServices = widget.services.where((s) => s.isActive).toList();
    return AlertDialog(
      title: const Text('Add Walk-in'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _branchId,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: widget.branches
                    .map((b) => DropdownMenuItem<String>(value: b['id'], child: Text(b['name'] ?? '')))
                    .toList(),
                onChanged: (value) => setState(() => _branchId = value),
                validator: (value) => value == null || value.trim().isEmpty ? 'Branch required' : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Customer Name'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Customer name required' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _serviceId,
                decoration: const InputDecoration(labelText: 'Service'),
                items: activeServices
                    .map((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.name)))
                    .toList(),
                onChanged: (value) => setState(() => _serviceId = value),
                validator: (value) => value == null || value.trim().isEmpty ? 'Service required' : null,
              ),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
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
