import 'package:flutter/material.dart';

class AddServiceModalResult {
  const AddServiceModalResult({
    required this.name,
    required this.category,
    required this.durationMinutes,
    required this.price,
    required this.description,
  });

  final String name;
  final String category;
  final String durationMinutes;
  final String price;
  final String description;
}

class AddServiceModal extends StatefulWidget {
  const AddServiceModal({
    required this.categories,
    super.key,
  });

  final List<String> categories;

  static Future<AddServiceModalResult?> show(
    BuildContext context, {
    required List<String> categories,
  }) {
    return showDialog<AddServiceModalResult>(
      context: context,
      builder: (_) => AddServiceModal(categories: categories),
    );
  }

  @override
  State<AddServiceModal> createState() => _AddServiceModalState();
}

class _AddServiceModalState extends State<AddServiceModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Other';

  @override
  void initState() {
    super.initState();
    final valid = widget.categories.where((c) => c.trim().isNotEmpty).toList();
    _selectedCategory = valid.isNotEmpty ? valid.first : 'Other';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AddServiceModalResult(
        name: _nameController.text.trim(),
        category: _selectedCategory,
        durationMinutes: _durationController.text.trim(),
        price: _priceController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Product/Service'),
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
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: widget.categories
                  .where((c) => c.trim().isNotEmpty)
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null || value.trim().isEmpty) return;
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration (min)'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Duration required';
                final minutes = int.tryParse(value.trim());
                if (minutes == null || minutes <= 0) return 'Enter a valid duration';
                return null;
              },
            ),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Price required';
                return null;
              },
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
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
