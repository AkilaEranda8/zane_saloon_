import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/salon_service.dart';
import '../models/staff_member.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _cForest  = Color(0xFF1B3A2D);
const Color _cEmerald = Color(0xFF2D6A4F);
const Color _cGreenL  = Color(0xFFECFDF5);
const Color _cGreenB  = Color(0xFFA7F3D0);
const Color _cBg      = Color(0xFFF9FAFB);
const Color _cBorder  = Color(0xFFE5E7EB);
const Color _cInk     = Color(0xFF111827);
const Color _cMuted   = Color(0xFF6B7280);

// ─────────────────────────────────────────────────────────────────────────────
class AddWalkInModalResult {
  const AddWalkInModalResult({
    required this.branchId,
    required this.customerName,
    required this.phone,
    required this.serviceId,
    required this.note,
    this.staffId,
  });

  final String branchId;
  final String customerName;
  final String phone;
  final String serviceId;
  final String note;
  final String? staffId;
}

// ─────────────────────────────────────────────────────────────────────────────
class AddWalkInModal extends StatefulWidget {
  const AddWalkInModal({
    required this.branches,
    required this.services,
    this.customers = const [],
    this.staffList = const [],
    this.initialBranchId,
    super.key,
  });

  final List<Map<String, String>> branches;
  final List<SalonService> services;
  final List<Customer> customers;
  final List<StaffMember> staffList;
  final String? initialBranchId;

  static Future<AddWalkInModalResult?> show(
    BuildContext context, {
    required List<Map<String, String>> branches,
    required List<SalonService> services,
    List<Customer> customers = const [],
    List<StaffMember> staffList = const [],
    String? initialBranchId,
  }) {
    return showModalBottomSheet<AddWalkInModalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddWalkInModal(
        branches: branches,
        services: services,
        customers: customers,
        staffList: staffList,
        initialBranchId: initialBranchId,
      ),
    );
  }

  @override
  State<AddWalkInModal> createState() => _AddWalkInModalState();
}

class _AddWalkInModalState extends State<AddWalkInModal> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl  = TextEditingController();

  String? _branchId;
  String? _serviceId;
  String? _staffId;

  @override
  void initState() {
    super.initState();
    _branchId = widget.initialBranchId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(AddWalkInModalResult(
      branchId:     (_branchId ?? '').trim(),
      customerName: _nameCtrl.text.trim(),
      phone:        _phoneCtrl.text.trim(),
      serviceId:    (_serviceId ?? '').trim(),
      note:         _noteCtrl.text.trim(),
      staffId:      _staffId?.trim().isEmpty == true ? null : _staffId?.trim(),
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
      style: const TextStyle(
        color: _cMuted, fontSize: 11.5,
        fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );

  InputDecoration _deco(String hint, IconData icon,
      {bool required = false}) =>
      InputDecoration(
        hintText: required ? hint : '$hint (optional)',
        hintStyle: const TextStyle(
            color: Color(0xFFB0B8B0), fontSize: 14),
        prefixIcon: Icon(icon, color: _cForest, size: 19),
        filled: true,
        fillColor: _cBg,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _cBorder)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _cBorder)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _cForest, width: 1.8)),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _cForest, width: 1.8)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF43F5E))),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final activeServices =
        widget.services.where((s) => s.isActive).toList();

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
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _cGreenL,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cGreenB),
                  ),
                  child: const Icon(Icons.directions_walk_rounded,
                      color: _cForest, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New Walk-in',
                        style: TextStyle(
                          color: _cInk, fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2)),
                      Text('Add customer to the queue',
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
                        size: 16, color: _cMuted),
                  ),
                ),
              ]),

              const SizedBox(height: 22),

              // ── Customer (autocomplete) ──────────────────────────────
              _label('CUSTOMER'),
              Autocomplete<Customer>(
                optionsBuilder: (val) {
                  final q = val.text.trim().toLowerCase();
                  final all = widget.customers;
                  if (q.isEmpty) return all.take(10);
                  return all
                      .where((c) =>
                          c.name.toLowerCase().contains(q) ||
                          c.phone.contains(q))
                      .take(15);
                },
                displayStringForOption: (c) => c.name,
                onSelected: (c) {
                  setState(() {
                    _nameCtrl.text  = c.name;
                    _phoneCtrl.text = c.phone;
                  });
                },
                fieldViewBuilder: (ctx, ctrl, fn, _) {
                  if (_nameCtrl.text.isNotEmpty &&
                      ctrl.text != _nameCtrl.text) {
                    ctrl.text = _nameCtrl.text;
                  }
                  return TextFormField(
                    controller: ctrl,
                    focusNode: fn,
                    textCapitalization: TextCapitalization.words,
                    decoration: _deco(
                        widget.customers.isEmpty
                            ? 'Full name'
                            : 'Search or type name',
                        Icons.person_search_rounded,
                        required: true),
                    onChanged: (v) {
                      _nameCtrl.text = v;
                    },
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                  );
                },
                optionsViewBuilder: widget.customers.isEmpty
                    ? null
                    : (ctx, onSel, opts) => Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(14),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxHeight: 200, maxWidth: 420),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              itemCount: opts.length,
                              itemBuilder: (_, i) {
                                final c = opts.elementAt(i);
                                final init = c.name.isNotEmpty
                                    ? c.name[0].toUpperCase()
                                    : '?';
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: _cGreenL,
                                    child: Text(init,
                                        style: const TextStyle(
                                            color: _cForest,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13)),
                                  ),
                                  title: Text(c.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5)),
                                  subtitle: c.phone.isNotEmpty
                                      ? Text(c.phone,
                                          style: const TextStyle(
                                              color: _cMuted, fontSize: 12))
                                      : null,
                                  onTap: () => onSel(c),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 14),

              // ── Phone ────────────────────────────────────────────────
              _label('PHONE NUMBER'),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                    _deco('e.g. 0771234567', Icons.phone_outlined),
              ),

              const SizedBox(height: 14),

              // ── Service chips ────────────────────────────────────────
              _label('SERVICE'),
              if (activeServices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cBorder)),
                  child: const Text('No active services available',
                    style: TextStyle(color: _cMuted, fontSize: 13)),
                )
              else
                Wrap(
                  spacing: 7, runSpacing: 7,
                  children: activeServices.map((s) {
                    final on = _serviceId == s.id;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _serviceId = on ? null : s.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: on ? _cGreenL : _cBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: on ? _cForest : _cBorder,
                            width: on ? 1.5 : 1),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min, children: [
                          if (on)
                            const Padding(
                              padding: EdgeInsets.only(right: 5),
                              child: Icon(Icons.check_circle_rounded,
                                  size: 13, color: _cForest),
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name,
                                style: TextStyle(
                                  color: on ? _cForest
                                           : const Color(0xFF374151),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700)),
                              Text('LKR ${s.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: on
                                      ? _cForest.withValues(alpha: 0.65)
                                      : const Color(0xFFADB5BD),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              // Validation hint
              if (_serviceId == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Text('Please select a service',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 11.5)),
                ),

              const SizedBox(height: 14),

              // ── Branch ───────────────────────────────────────────────
              if (widget.branches.isNotEmpty) ...[
                _label('BRANCH'),
                DropdownButtonFormField<String>(
                  initialValue: _branchId,
                  isExpanded: true,
                  decoration: _deco('Select branch',
                      Icons.store_mall_directory_outlined,
                      required: true),
                  items: widget.branches
                      .map((b) => DropdownMenuItem(
                            value: b['id'],
                            child: Text(b['name'] ?? '',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _branchId = v),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Branch required' : null,
                ),
                const SizedBox(height: 14),
              ],

              // ── Staff ────────────────────────────────────────────────
              if (widget.staffList.isNotEmpty) ...[
                _label('ASSIGN STAFF'),
                DropdownButtonFormField<String>(
                  initialValue: _staffId,
                  isExpanded: true,
                  decoration: _deco('Select staff member (optional)',
                      Icons.badge_outlined),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('— No assignment —',
                          style: TextStyle(color: Color(0xFFADB5BD))),
                    ),
                    ...widget.staffList.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Row(children: [
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: _cGreenL,
                            shape: BoxShape.circle,
                            border: Border.all(color: _cGreenB),
                          ),
                          child: Center(
                            child: Text(
                              s.name.isNotEmpty
                                  ? s.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: _cForest,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(s.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ),
                      ]),
                    )),
                  ],
                  onChanged: (v) => setState(() => _staffId = v),
                ),
                const SizedBox(height: 14),
              ],

              // ── Note ─────────────────────────────────────────────────
              _label('NOTE'),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Any special requests… (optional)',
                  hintStyle: const TextStyle(
                      color: Color(0xFFB0B8B0), fontSize: 14),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 22),
                    child: Icon(Icons.notes_rounded,
                        color: _cForest, size: 19),
                  ),
                  filled: true, fillColor: _cBg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cBorder)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cBorder)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: _cForest, width: 1.8)),
                ),
              ),

              const SizedBox(height: 24),

              Container(height: 1, color: _cBorder,
                  margin: const EdgeInsets.only(bottom: 20)),

              // ── Submit ───────────────────────────────────────────────
              GestureDetector(
                onTap: () {
                  if (_serviceId == null) {
                    setState(() {}); // trigger validation hint
                    return;
                  }
                  _submit();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_cForest, _cEmerald],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                      color: _cForest.withValues(alpha: 0.28),
                      blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_walk_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 9),
                      Text('Add to Queue',
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
