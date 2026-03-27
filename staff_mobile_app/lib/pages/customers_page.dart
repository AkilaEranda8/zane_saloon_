import 'package:flutter/material.dart';

import 'add_customer_modal.dart';
import '../models/customer.dart';
import '../models/staff_user.dart';
import '../state/app_state.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  Future<List<Customer>>? _customersFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _customersFuture ??= _loadCustomers();
  }

  Future<List<Customer>> _loadCustomers() {
    final appState = AppStateScope.of(context);
    return appState.loadCustomers();
  }

  Future<void> _showAddDialog() async {
    final appState = AppStateScope.of(context);
    List<Map<String, String>> branchOptions = const [];
    final fixedBranchId = appState.currentUser?.branchId;
    if (fixedBranchId == null || fixedBranchId.isEmpty) {
      try {
        if (appState.branches.isEmpty) {
          await appState.loadBranches();
        }
        branchOptions = appState.branches;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appState.lastError ?? 'Failed to load branches')),
        );
        return;
      }
    } else {
      final existing = appState.branches.firstWhere(
        (b) => b['id'] == fixedBranchId,
        orElse: () => {'id': fixedBranchId, 'name': 'My Branch'},
      );
      branchOptions = [existing];
    }
    if (!mounted) return;

    final payload = await AddCustomerModal.show(
      context,
      branches: branchOptions,
      initialBranchId: fixedBranchId,
    );
    if (payload == null) return;
    if (!mounted) return;

    final ok = await appState.addCustomer(
      name: payload.name,
      phone: payload.phone,
      email: payload.email,
      branchId: payload.branchId,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.lastError ?? 'Failed to add customer')),
      );
    }
    if (mounted) {
      setState(() {
        _customersFuture = _loadCustomers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final allowed = appState.hasPermission(StaffPermission.canViewCustomers);
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customers')),
        body: const Center(child: Text('No permission to view customers.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.person_add_alt_1),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _customersFuture = _loadCustomers();
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Customer>>(
        future: _customersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load customers.'));
          }
          final customers = snapshot.data ?? const [];
          if (customers.isEmpty) {
            return const Center(child: Text('No customers found.'));
          }
          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final c = customers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(c.name),
                  subtitle: Text('${c.phone}\n${c.email}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
