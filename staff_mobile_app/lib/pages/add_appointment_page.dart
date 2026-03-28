import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/salon_service.dart';
import '../models/staff_member.dart';
import '../state/app_state.dart';

// ── Design tokens (mirrors dashboard) ────────────────────────────────────────
const Color _kG900   = Color(0xFF1B3A2D);
const Color _kG700   = Color(0xFF2D6A4F);
const Color _kGold   = Color(0xFFC9956C);
const Color _kGoldL  = Color(0xFFE8C49A);
const Color _kBg     = Color(0xFFF2F5F2);
const Color _kBorder = Color(0xFFE5E7EB);

class AddAppointmentPage extends StatefulWidget {
  const AddAppointmentPage({super.key});

  @override
  State<AddAppointmentPage> createState() => _AddAppointmentPageState();
}

class _AddAppointmentPageState extends State<AddAppointmentPage> {
  final _formKey      = GlobalKey<FormState>();
  final _customerName = TextEditingController();
  final _phone        = TextEditingController();
  final _date         = TextEditingController();
  final _time         = TextEditingController();
  final _amount       = TextEditingController();
  final _notes        = TextEditingController();

  bool   _loading  = true;
  bool   _saving   = false;
  String? _error;

  List<SalonService>      _services  = const [];
  List<Map<String, String>> _branches = const [];
  List<StaffMember>       _staff     = const [];
  List<Customer>          _customers = const [];

  final List<String> _serviceIds = [];
  String _branchId = '';
  String _staffId  = '';
  String _custId   = '';

  bool get _isSuperAdmin {
    final role = AppStateScope.of(context).currentUser?.role ?? '';
    return role == 'superadmin';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    final appState = AppStateScope.of(context);
    final d = DateTime.now();
    _date.text =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    setState(() { _loading = true; _error = null; });
    try {
      _services = await appState.loadServices();
      try { _customers = await appState.loadCustomers(); } catch (_) {}
      final userBranch = appState.currentUser?.branchId ?? '';
      _branchId = userBranch;
      if (_isSuperAdmin || userBranch.isEmpty) {
        _branches = await appState.loadBranches();
        if (_branchId.isEmpty && _branches.isNotEmpty) {
          _branchId = _branches.first['id'] ?? '';
        }
      }
      try {
        _staff = await appState.loadStaffList(
            branchId: _branchId.isEmpty ? null : _branchId);
      } catch (_) {}
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020), lastDate: DateTime(2035),
      initialDate: DateTime.tryParse(_date.text) ?? DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _kG900, onPrimary: Colors.white,
              surface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _date.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _kG900, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _time.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  double get _calcTotal {
    var sum = 0.0;
    for (final id in _serviceIds) {
      for (final s in _services) { if (s.id == id) sum += s.price; }
    }
    return sum;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_serviceIds.isEmpty) {
      _snack('Select at least one service'); return;
    }
    final appState = AppStateScope.of(context);
    final branch = (_isSuperAdmin ||
            (appState.currentUser?.branchId ?? '').isEmpty)
        ? _branchId
        : (appState.currentUser?.branchId ?? '');
    if (branch.trim().isEmpty) { _snack('Branch is required'); return; }
    setState(() => _saving = true);
    final ok = await appState.saveAppointment(
      branchId: branch,
      customerName: _customerName.text.trim(),
      phone: _phone.text.trim(),
      customerId: _custId,
      orderedServiceIds: List<String>.from(_serviceIds),
      date: _date.text.trim(),
      time: _time.text.trim(),
      staffId: _staffId,
      baseNotes: _notes.text.trim(),
      status: '',
      amountOverride: _amount.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) { _snack(appState.lastError ?? 'Save failed'); return; }
    Navigator.of(context).pop(true);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _customerName.dispose(); _phone.dispose(); _date.dispose();
    _time.dispose(); _amount.dispose(); _notes.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFADB5BD), fontSize: 14),
        prefixIcon: Icon(icon, color: _kG700, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kG700, width: 1.8)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF43F5E))),
      );

  Widget _card({required int step, required IconData icon,
      required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x07000000), blurRadius: 16, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Card header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            // Step circle
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: _kG900),
              child: Center(
                child: Text('$step',
                    style: const TextStyle(
                        color: _kGold, fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: _kG700, size: 17),
            const SizedBox(width: 7),
            Text(title,
                style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1)),
          ]),
        ),
        // Thin divider
        Container(height: 1, color: const Color(0xFFF3F4F6)),
        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children),
        ),
      ]),
    );
  }

  // ── Tap-to-pick date/time button ─────────────────────────────────────────────
  Widget _datePill(TextEditingController ctrl, String hint, IconData icon,
      VoidCallback onTap) {
    final filled = ctrl.text.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: filled ? _kG900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? _kG700 : _kBorder),
        ),
        child: Row(children: [
          Icon(icon,
              size: 17,
              color: filled ? _kGold : const Color(0xFFADB5BD)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              ctrl.text.isEmpty ? hint : ctrl.text,
              style: TextStyle(
                color: filled ? Colors.white : const Color(0xFFADB5BD),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (filled)
            const Icon(Icons.edit_rounded, size: 13, color: _kGold),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeServices = _services.where((s) => s.isActive).toList();

    return Scaffold(
      backgroundColor: _kBg,
      // ── Floating bottom bar ──────────────────────────────────────────────
      bottomNavigationBar: _loading || _error != null
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 20,
                      offset: Offset(0, -4)),
                ],
              ),
              child: Row(children: [
                // Summary pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kG900,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_serviceIds.length} service${_serviceIds.length == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                        Text('Rs. ${_calcTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: _kGold,
                                fontSize: 15,
                                fontWeight: FontWeight.w900)),
                      ]),
                ),
                const SizedBox(width: 10),
                // Create button
                Expanded(
                  child: GestureDetector(
                    onTap: _saving ? null : _save,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: _saving
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF224030), _kG700],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        color: _saving ? const Color(0xFFE9ECEF) : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _saving
                            ? []
                            : [
                                BoxShadow(
                                    color: _kG900.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5)),
                              ],
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_saving)
                              const SizedBox(
                                width: 17, height: 17,
                                child: CircularProgressIndicator(
                                    color: _kG700, strokeWidth: 2),
                              )
                            else
                              const Icon(Icons.event_available_rounded,
                                  color: _kGold, size: 18),
                            const SizedBox(width: 9),
                            Text(
                              _saving ? 'Creating...' : 'Book Appointment',
                              style: TextStyle(
                                color: _saving
                                    ? const Color(0xFF9CA3AF)
                                    : Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ]),
                    ),
                  ),
                ),
              ]),
            ),

      body: Column(children: [
        // ── Header ─────────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        color: const Color(0xFFF3F4F6),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF374151), size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New Appointment',
                            style: TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3)),
                        Text('Fill in the details to book',
                            style: TextStyle(
                                color: Color(0xFFADB5BD),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  // Booking date badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kG900,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: _kGold, size: 12),
                      const SizedBox(width: 5),
                      Text(_date.text.isNotEmpty ? _date.text : 'Today',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ),
              // Bottom accent line
              Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kG900, _kG700, Color(0xFF3A8C62)],
                  ),
                ),
              ),
            ]),
          ),
        ),

        // ── Body ───────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: _kG900,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.event_note_rounded,
                            color: _kGold, size: 26),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            color: _kG700, strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 12),
                      const Text('Loading booking details...',
                          style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.wifi_off_rounded,
                                color: Color(0xFFF43F5E), size: 28),
                          ),
                          const SizedBox(height: 14),
                          const Text('Could not load',
                              style: TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 13)),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: _loadInitial,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: _kG900,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('Try again',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ]),
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                        children: [

                          // ── Step 1: Customer ──────────────────────────────
                          _card(
                            step: 1,
                            icon: Icons.person_outline_rounded,
                            title: 'Customer',
                            children: [
                              Autocomplete<Customer>(
                                optionsBuilder: (textEditingValue) {
                                  final q = textEditingValue.text
                                      .trim()
                                      .toLowerCase();
                                  if (q.isEmpty) return _customers.take(15);
                                  return _customers
                                      .where((c) =>
                                          c.name
                                              .toLowerCase()
                                              .contains(q) ||
                                          c.phone.toLowerCase().contains(q))
                                      .take(20);
                                },
                                displayStringForOption: (c) => c.name,
                                onSelected: (customer) {
                                  setState(() {
                                    _customerName.text = customer.name;
                                    _phone.text = customer.phone;
                                    _custId = customer.id;
                                  });
                                },
                                fieldViewBuilder:
                                    (ctx, ctrl, focusNode, onSubmit) {
                                  ctrl.text = _customerName.text;
                                  return TextFormField(
                                    controller: ctrl,
                                    focusNode: focusNode,
                                    decoration: _inputDeco(
                                        'Search customer name or phone',
                                        Icons.search_rounded),
                                    onChanged: (v) {
                                      _customerName.text = v;
                                      _custId = '';
                                    },
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'Required'
                                            : null,
                                  );
                                },
                                optionsViewBuilder:
                                    (ctx, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 10,
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      shadowColor: Colors.black12,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxHeight: 230, maxWidth: 520),
                                        child: ListView.builder(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (_, i) {
                                            final c = options.elementAt(i);
                                            return ListTile(
                                              dense: true,
                                              leading: CircleAvatar(
                                                radius: 17,
                                                backgroundColor: _kG900
                                                    .withValues(alpha: 0.08),
                                                child: Text(
                                                  c.name.isNotEmpty
                                                      ? c.name[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                      color: _kG700,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 13),
                                                ),
                                              ),
                                              title: Text(c.name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13.5)),
                                              subtitle: c.phone.isNotEmpty
                                                  ? Text(c.phone,
                                                      style: const TextStyle(
                                                          fontSize: 12))
                                                  : null,
                                              onTap: () => onSelected(c),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                decoration: _inputDeco(
                                    'Phone number', Icons.call_outlined),
                              ),
                            ],
                          ),

                          // ── Step 2: Branch ────────────────────────────────
                          const SizedBox(height: 14),
                          _card(
                            step: 2,
                            icon: Icons.store_outlined,
                            title: 'Branch',
                            children: [
                              if (_isSuperAdmin ||
                                  (AppStateScope.of(context)
                                              .currentUser
                                              ?.branchId ??
                                          '')
                                      .isEmpty)
                                DropdownButtonFormField<String>(
                                  initialValue: _branchId.isEmpty
                                      ? null
                                      : _branchId,
                                  decoration: _inputDeco('Select branch',
                                      Icons.store_mall_directory_outlined),
                                  items: _branches
                                      .map((b) => DropdownMenuItem(
                                          value: b['id'],
                                          child: Text(b['name'] ?? '')))
                                      .toList(),
                                  onChanged: (v) async {
                                    setState(() => _branchId = v ?? '');
                                    final appState =
                                        AppStateScope.of(context);
                                    _staff =
                                        await appState.loadStaffList(
                                      branchId: _branchId.isEmpty
                                          ? null
                                          : _branchId,
                                    );
                                    if (mounted) setState(() {});
                                  },
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Branch required'
                                      : null,
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 15),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAF9),
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: _kBorder),
                                  ),
                                  child: Row(children: [
                                    const Icon(
                                        Icons.store_mall_directory_outlined,
                                        color: _kG700,
                                        size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      _branchId.isNotEmpty
                                          ? _branchId
                                          : 'Assigned branch',
                                      style: const TextStyle(
                                          color: Color(0xFF374151),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.lock_outline_rounded,
                                        size: 14,
                                        color: Color(0xFFD1D5DB)),
                                  ]),
                                ),
                            ],
                          ),

                          // ── Step 3: Services ──────────────────────────────
                          const SizedBox(height: 14),
                          _card(
                            step: 3,
                            icon: Icons.content_cut_rounded,
                            title: 'Services',
                            children: [
                              if (activeServices.isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  child: const Center(
                                    child: Text('No active services',
                                        style: TextStyle(
                                            color: Color(0xFFADB5BD),
                                            fontSize: 13)),
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: activeServices.map((s) {
                                    final on = _serviceIds.contains(s.id);
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (on) {
                                            _serviceIds.remove(s.id);
                                          } else {
                                            if (!_serviceIds
                                                .contains(s.id)) {
                                              _serviceIds.add(s.id);
                                            }
                                          }
                                          _amount.text = _calcTotal > 0
                                              ? _calcTotal.toStringAsFixed(0)
                                              : '';
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 160),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 9),
                                        decoration: BoxDecoration(
                                          color: on
                                              ? _kG900
                                              : const Color(0xFFF8F9FA),
                                          borderRadius:
                                              BorderRadius.circular(11),
                                          border: Border.all(
                                            color: on
                                                ? _kG700
                                                : const Color(0xFFE9ECEF),
                                          ),
                                        ),
                                        child: Row(
                                            mainAxisSize:
                                                MainAxisSize.min,
                                            children: [
                                              AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 160),
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: on
                                                      ? _kGold
                                                      : Colors.transparent,
                                                  border: Border.all(
                                                    color: on
                                                        ? _kGold
                                                        : const Color(
                                                            0xFFD1D5DB),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: on
                                                    ? const Icon(
                                                        Icons.check_rounded,
                                                        size: 11,
                                                        color: Colors.white)
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(s.name,
                                                      style: TextStyle(
                                                          color: on
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF374151),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 13)),
                                                  Text(
                                                      'Rs. ${s.price.toStringAsFixed(0)}',
                                                      style: TextStyle(
                                                          color: on
                                                              ? _kGoldL
                                                              : const Color(
                                                                  0xFFADB5BD),
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                ],
                                              ),
                                            ]),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 12),
                              // Total strip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_kG900, Color(0xFF2C5446)],
                                ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.receipt_long_rounded,
                                      color: _kGold, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    _serviceIds.isEmpty
                                        ? 'No services selected'
                                        : '${_serviceIds.length} service${_serviceIds.length == 1 ? '' : 's'} selected',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.70),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const Spacer(),
                                  Text(
                                      'Rs. ${_calcTotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          color: _kGold,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15)),
                                ]),
                              ),
                            ],
                          ),

                          // ── Step 4: Schedule ──────────────────────────────
                          const SizedBox(height: 14),
                          _card(
                            step: 4,
                            icon: Icons.schedule_rounded,
                            title: 'Schedule',
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _staffId.isEmpty ? null : _staffId,
                                decoration: _inputDeco(
                                    'Assign staff (optional)',
                                    Icons.badge_outlined),
                                items: [
                                  const DropdownMenuItem(
                                      value: '',
                                      child: Text('Any available')),
                                  ..._staff.map((s) => DropdownMenuItem(
                                      value: s.id, child: Text(s.name))),
                                ],
                                onChanged: (v) =>
                                    setState(() => _staffId = v ?? ''),
                              ),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: _datePill(
                                      _date, 'Date',
                                      Icons.calendar_today_rounded,
                                      _pickDate),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _datePill(
                                      _time, 'Time',
                                      Icons.access_time_rounded,
                                      _pickTime),
                                ),
                              ]),
                              // Hidden validators
                              Opacity(
                                opacity: 0,
                                child: SizedBox(
                                  height: 0,
                                  child: TextFormField(
                                    controller: _date,
                                    validator: (v) =>
                                        v == null || v.isEmpty
                                            ? 'Required'
                                            : null,
                                  ),
                                ),
                              ),
                              Opacity(
                                opacity: 0,
                                child: SizedBox(
                                  height: 0,
                                  child: TextFormField(
                                    controller: _time,
                                    validator: (v) =>
                                        v == null || v.isEmpty
                                            ? 'Required'
                                            : null,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ── Step 5: Payment & Notes ───────────────────────
                          const SizedBox(height: 14),
                          _card(
                            step: 5,
                            icon: Icons.payments_outlined,
                            title: 'Payment & Notes',
                            children: [
                              TextFormField(
                                controller: _amount,
                                keyboardType: TextInputType.number,
                                decoration: _inputDeco(
                                    'Total amount (Rs.)',
                                    Icons.currency_rupee_rounded),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _notes,
                                maxLines: 3,
                                decoration: _inputDeco(
                                    'Notes (optional)',
                                    Icons.sticky_note_2_outlined),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
        ),
      ]),
    );
  }
}
