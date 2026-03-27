import 'package:flutter/material.dart';

import 'add_service_modal.dart';
import '../state/app_state.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  Future<void>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<void> _load() async {
    final appState = AppStateScope.of(context);
    await appState.loadServices();
  }

  Future<void> _addProduct() async {
    final appState = AppStateScope.of(context);
    final categorySet = <String>{};
    for (final service in appState.services) {
      final c = service.category.trim();
      if (c.isNotEmpty) categorySet.add(c);
    }
    if (categorySet.isEmpty) {
      categorySet.add('Other');
    }
    final payload = await AddServiceModal.show(
      context,
      categories: categorySet.toList()..sort(),
    );
    if (payload == null) return;
    if (!mounted) return;
    final ok = await appState.addService(
      name: payload.name,
      category: payload.category,
      durationMinutes: payload.durationMinutes,
      price: payload.price,
      description: payload.description,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.lastError ?? 'Failed to save product')),
      );
      return;
    }
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Services / Products'),
        actions: [
          IconButton(onPressed: _addProduct, icon: const Icon(Icons.add_business)),
          IconButton(
            onPressed: () => setState(() {
              _future = _load();
            }),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load services.'));
          }
          if (appState.services.isEmpty) {
            return const Center(child: Text('No products/services found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: appState.services.length,
            itemBuilder: (context, index) {
              final s = appState.services[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.content_cut),
                  title: Text(s.name),
                  subtitle: Text('${s.category} • ${s.durationMinutes} min'),
                  trailing: Text('LKR ${s.price.toStringAsFixed(0)}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
