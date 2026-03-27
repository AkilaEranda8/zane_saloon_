import 'package:flutter/material.dart';

import '../state/app_state.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  bool _initialized = false;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    final appState = AppStateScope.of(context);
    try {
      await appState.loadStaffList();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: RefreshIndicator(
        onRefresh: _loadStaff,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appState.staffUsers.length,
          itemBuilder: (context, index) {
            final staff = appState.staffUsers[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(staff.displayName),
                subtitle: Text(staff.username),
                trailing: Text(staff.isActive ? 'Active' : 'Inactive'),
              ),
            );
          },
        ),
      ),
    );
  }
}
