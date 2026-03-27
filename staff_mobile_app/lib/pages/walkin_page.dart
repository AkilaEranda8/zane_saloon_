import 'package:flutter/material.dart';

import '../models/salon_service.dart';
import '../models/walkin_entry.dart';
import '../state/app_state.dart';
import 'add_walkin_modal.dart';
import 'add_walkin_payment_modal.dart';

class WalkInPage extends StatefulWidget {
  const WalkInPage({super.key});

  @override
  State<WalkInPage> createState() => _WalkInPageState();
}

class _WalkInPageState extends State<WalkInPage> {
  Future<void>? _future;
  List<WalkInEntry> _walkIns = const [];
  List<SalonService> _services = const [];
  List<Map<String, String>> _branches = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<void> _load() async {
    final appState = AppStateScope.of(context);
    final userBranchId = appState.currentUser?.branchId;
    final services = await appState.loadServices();
    final branches = userBranchId == null || userBranchId.isEmpty
        ? await appState.loadBranches()
        : <Map<String, String>>[
            appState.branches.firstWhere(
              (b) => b['id'] == userBranchId,
              orElse: () => {'id': userBranchId, 'name': 'My Branch'},
            ),
          ];
    if (branches.isEmpty) {
      if (!mounted) return;
      setState(() {
        _services = services;
        _branches = const [];
        _walkIns = const [];
      });
      return;
    }
    final branchId = userBranchId ?? branches.first['id'] ?? '';
    final queue = await appState.loadWalkIns(branchId: branchId);
    if (!mounted) return;
    setState(() {
      _services = services;
      _branches = branches;
      _walkIns = queue;
    });
  }

  Future<void> _openAddWalkIn() async {
    final appState = AppStateScope.of(context);
    var branchOptions = _branches;
    final fixedBranchId = appState.currentUser?.branchId;
    if (branchOptions.isEmpty) {
      try {
        if (fixedBranchId == null || fixedBranchId.isEmpty) {
          branchOptions = await appState.loadBranches();
        } else {
          branchOptions = [
            {'id': fixedBranchId, 'name': 'My Branch'},
          ];
        }
      } catch (_) {
        branchOptions = const [];
      }
    }
    if (!mounted) return;
    if (branchOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.lastError ?? 'No branches available for walk-in')),
      );
      return;
    }
    setState(() {
      _branches = branchOptions;
    });

    final payload = await AddWalkInModal.show(
      context,
      branches: branchOptions,
      services: _services,
      initialBranchId: fixedBranchId,
    );
    if (payload == null) return;
    if (!mounted) return;
    final ok = await appState.addWalkIn(
      branchId: payload.branchId,
      customerName: payload.customerName,
      serviceId: payload.serviceId,
      phone: payload.phone,
      note: payload.note,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.lastError ?? 'Failed to add walk-in')),
      );
      return;
    }
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<void> _startWalkIn(WalkInEntry entry) async {
    final appState = AppStateScope.of(context);
    final ok = await appState.updateWalkInStatus(
      walkInId: entry.id,
      status: 'serving',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.lastError ?? 'Failed to update status')),
      );
      return;
    }
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<void> _collectPayment(WalkInEntry entry) async {
    final appState = AppStateScope.of(context);
    final service = _services.firstWhere(
      (s) => s.id == entry.serviceId,
      orElse: () => SalonService(
        id: entry.serviceId,
        name: entry.serviceName,
        category: 'Other',
        price: 0,
        durationMinutes: 30,
      ),
    );
    final payload = await AddWalkInPaymentModal.show(
      context,
      initialAmount: service.price.toStringAsFixed(0),
    );
    if (payload == null) return;
    if (!mounted) return;
    final ok = await appState.addManualPayment(
      branchId: entry.branchId,
      serviceId: entry.serviceId,
      staffId: entry.staffId.isEmpty ? null : entry.staffId,
      customerName: entry.customerName,
      totalAmount: payload.amount,
      loyaltyDiscount: '0',
      method: payload.method,
      paidAmount: payload.amount,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.lastError ?? 'Payment failed')),
      );
      return;
    }
    final statusOk = await appState.updateWalkInStatus(
      walkInId: entry.id,
      status: 'completed',
    );
    if (!statusOk && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.lastError ?? 'Payment saved, status update failed')),
      );
    }
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'waiting':
        return 'Waiting';
      case 'serving':
        return 'In Service';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk-in'),
        actions: [
          IconButton(onPressed: _openAddWalkIn, icon: const Icon(Icons.add)),
          IconButton(
            onPressed: () {
              setState(() {
                _future = _load();
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddWalkIn,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: FutureBuilder<void>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load walk-in queue.'));
          }
          if (_walkIns.isEmpty) {
            return const Center(child: Text('No walk-ins found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _walkIns.length,
            itemBuilder: (context, index) {
              final item = _walkIns[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(item.token.isEmpty ? '#' : item.token),
                  ),
                  title: Text('${item.customerName} - ${item.serviceName}'),
                  subtitle: Text(
                    '${item.phone}\n${_statusLabel(item.status)}${item.estimatedWait > 0 ? ' • ~${item.estimatedWait} min' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      if (item.status == 'waiting')
                        OutlinedButton(
                          onPressed: () => _startWalkIn(item),
                          child: const Text('Start'),
                        ),
                      if (item.status == 'serving')
                        FilledButton(
                          onPressed: () => _collectPayment(item),
                          child: const Text('Payment'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
