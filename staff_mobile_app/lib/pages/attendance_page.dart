import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/staff_member.dart';
import '../state/app_state.dart';

const Color _forest  = Color(0xFF1B3A2D);
const Color _emerald = Color(0xFF2D6A4F);
const Color _canvas  = Color(0xFFF2F5F2);
const Color _surface = Colors.white;
const Color _ink     = Color(0xFF111827);
const Color _muted   = Color(0xFF6B7280);
const Color _border  = Color(0xFFE5E7EB);

// ─── Status meta ─────────────────────────────────────────────────────────────
const _statuses = ['present', 'absent', 'leave', 'late'];

const _statusLabels = {
  'present': 'Present',
  'absent':  'Absent',
  'leave':   'Leave',
  'late':    'Late',
};

const _statusColors = {
  'present': Color(0xFF047857),
  'absent':  Color(0xFFDC2626),
  'leave':   Color(0xFFD97706),
  'late':    Color(0xFF7C3AED),
};

const _statusBgColors = {
  'present': Color(0xFFD1FAE5),
  'absent':  Color(0xFFFEE2E2),
  'leave':   Color(0xFFFEF3C7),
  'late':    Color(0xFFEDE9FE),
};

const _statusIcons = {
  'present': Icons.check_circle_rounded,
  'absent':  Icons.cancel_rounded,
  'leave':   Icons.beach_access_rounded,
  'late':    Icons.watch_later_rounded,
};

// ─── Page ─────────────────────────────────────────────────────────────────────
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool _loading = true;
  String? _error;
  List<StaffMember> _staffList = const [];
  List<Map<String, dynamic>> _records = const [];
  DateTime _selectedDate = DateTime.now();

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _isToday {
    final n = DateTime.now();
    return _selectedDate.year == n.year &&
        _selectedDate.month == n.month &&
        _selectedDate.day == n.day;
  }

  String get _dateLabel {
    if (_isToday) return 'Today';
    const mn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${mn[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
  }

  int _count(String status) =>
      _records.where((r) => (r['status'] ?? '') == status).length;

  Map<String, dynamic>? _recordFor(String staffId) {
    for (final r in _records) {
      if (r['staff_id'].toString() == staffId) return r;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final app      = AppStateScope.of(context);
      final branchId = app.currentUser?.branchId;
      final results  = await Future.wait([
        app.loadStaffList(branchId: branchId?.isNotEmpty == true ? branchId : null),
        app.loadAttendance(
          branchId: branchId?.isNotEmpty == true ? branchId : null,
          date:     _fmtDate(_selectedDate),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _staffList = results[0] as List<StaffMember>;
        _records   = results[1] as List<Map<String, dynamic>>;
        _loading   = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error   = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _selectedDate,
      firstDate:   DateTime(now.year - 1),
      lastDate:    now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _forest, onPrimary: Colors.white, surface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
    await _load();
  }

  Future<void> _openMark(StaffMember staff) async {
    final app  = AppStateScope.of(context);
    final role = (app.currentUser?.role ?? '').toLowerCase();
    if (role != 'superadmin' && role != 'admin' && role != 'manager') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only manager and above can mark attendance.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final existing = _recordFor(staff.id);
    final result   = await showModalBottomSheet<Map<String, String?>>(
      context:             context,
      isScrollControlled:  true,
      backgroundColor:     Colors.transparent,
      builder: (_) => _MarkSheet(
        staffName: staff.name,
        date:      _dateLabel,
        existing:  existing,
      ),
    );
    if (result == null || !mounted) return;

    final ok = await app.saveAttendance(
      staffId:  staff.id,
      date:     _fmtDate(_selectedDate),
      status:   result['status'],
      checkIn:  result['checkIn'],
      checkOut: result['checkOut'],
      note:     result['note'],
    );
    if (!mounted) return;
    if (ok) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(app.lastError ?? 'Failed to save'),
          backgroundColor: Colors.red.shade700,
          behavior:        SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _canvas,
        body: Column(children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_forest, _emerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(children: [
            // Title row
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attendance',
                      style: TextStyle(color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    SizedBox(height: 2),
                    Text('Mark and track staff attendance',
                      style: TextStyle(color: Color(0xFFE5F6EC),
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ]),

            const SizedBox(height: 14),

            // Date picker + stats row
            Row(children: [
              // Date chip
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _isToday
                        ? Colors.white.withValues(alpha: 0.15)
                        : const Color(0xFFFFF7ED).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _isToday ? Colors.white30 : Colors.orange.shade300),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_today_rounded, size: 13,
                        color: _isToday ? Colors.white : Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Text(_dateLabel,
                      style: TextStyle(
                        color: _isToday ? Colors.white : Colors.orange.shade800,
                        fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16,
                        color: _isToday ? Colors.white60 : Colors.orange.shade600),
                  ]),
                ),
              ),

              const Spacer(),

              // Stat pills
              if (!_loading) ...[
                _StatPill(label: 'Present', count: _count('present'),
                    color: const Color(0xFF34D399)),
                const SizedBox(width: 6),
                _StatPill(label: 'Absent',  count: _count('absent'),
                    color: const Color(0xFFF87171)),
                const SizedBox(width: 6),
                _StatPill(label: 'Late',    count: _count('late'),
                    color: const Color(0xFFA78BFA)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _forest, strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: _muted, size: 44),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _muted),
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      ));
    }
    if (_staffList.isEmpty) {
      return const Center(
          child: Text('No staff found.', style: TextStyle(color: _muted)));
    }

    final unmarked = _staffList.length -
        _records.where((r) => _statusLabels.containsKey(r['status'])).length;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      itemCount: _staffList.length + (unmarked > 0 ? 1 : 0),
      itemBuilder: (ctx, i) {
        // Summary notice at top if some staff not marked
        if (i == 0 && unmarked > 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFD97706), size: 16),
                const SizedBox(width: 8),
                Text('$unmarked staff not yet marked for $_dateLabel',
                  style: const TextStyle(
                    color: Color(0xFF92400E), fontSize: 12,
                    fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        }

        final staffIdx = i - (unmarked > 0 ? 1 : 0);
        final staff    = _staffList[staffIdx];
        final record   = _recordFor(staff.id);
        return _StaffCard(
          staff:  staff,
          record: record,
          onTap:  () => _openMark(staff),
        );
      },
    );
  }
}

// ─── Staff attendance card ────────────────────────────────────────────────────
class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.staff,
    required this.record,
    required this.onTap,
  });

  final StaffMember          staff;
  final Map<String, dynamic>? record;
  final VoidCallback          onTap;

  @override
  Widget build(BuildContext context) {
    final status  = record?['status'] as String?;
    final color   = status != null
        ? (_statusColors[status]   ?? _muted)
        : const Color(0xFF9CA3AF);
    final bgColor = status != null
        ? (_statusBgColors[status] ?? const Color(0xFFF3F4F6))
        : const Color(0xFFF3F4F6);
    final icon    = status != null
        ? (_statusIcons[status]    ?? Icons.help_outline_rounded)
        : Icons.radio_button_unchecked_rounded;
    final label   = status != null
        ? (_statusLabels[status]   ?? status!)
        : 'Not marked';

    final checkIn  = record?['check_in']  as String?;
    final checkOut = record?['check_out'] as String?;
    final note     = record?['note']      as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: status != null ? bgColor : _border),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Text(
                staff.name.trim().isNotEmpty
                    ? staff.name.trim()[0].toUpperCase()
                    : '?',
                style: TextStyle(color: color, fontSize: 17,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + time info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(staff.name,
                style: const TextStyle(color: _ink, fontSize: 14,
                    fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              if (checkIn != null || checkOut != null)
                Text(
                  [
                    if (checkIn  != null) 'In: ${_trimSec(checkIn)}',
                    if (checkOut != null) 'Out: ${_trimSec(checkOut)}',
                  ].join('  ·  '),
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                )
              else
                Text('Tap to mark attendance',
                  style: TextStyle(color: _muted.withValues(alpha: 0.7),
                      fontSize: 11.5)),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(note, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11,
                      fontStyle: FontStyle.italic)),
              ],
            ],
          )),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label,
                style: TextStyle(color: color, fontSize: 11,
                    fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _trimSec(String t) =>
      t.length >= 5 ? t.substring(0, 5) : t;
}

// ─── Mark attendance bottom sheet ────────────────────────────────────────────
class _MarkSheet extends StatefulWidget {
  const _MarkSheet({
    required this.staffName,
    required this.date,
    this.existing,
  });

  final String               staffName;
  final String               date;
  final Map<String, dynamic>? existing;

  @override
  State<_MarkSheet> createState() => _MarkSheetState();
}

class _MarkSheetState extends State<_MarkSheet> {
  String  _status   = 'present';
  String? _checkIn;
  String? _checkOut;
  final   _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _status   = widget.existing!['status'] ?? 'present';
      _checkIn  = widget.existing!['check_in']  as String?;
      _checkOut = widget.existing!['check_out'] as String?;
      _noteCtrl.text = widget.existing!['note'] ?? '';
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  static String _trimSec(String? t) =>
      (t != null && t.length >= 5) ? t.substring(0, 5) : (t ?? '');

  Future<void> _pickTime(bool isCheckIn) async {
    TimeOfDay? initial;
    final raw = isCheckIn ? _checkIn : _checkOut;
    if (raw != null && raw.length >= 5) {
      final parts = raw.split(':');
      initial = TimeOfDay(
        hour:   int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    final picked = await showTimePicker(
      context:     context,
      initialTime: initial ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _forest, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final str =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isCheckIn) _checkIn  = str;
      else           _checkOut = str;
    });
  }

  void _save() {
    Navigator.of(context).pop(<String, String?>{
      'status':   _status,
      'checkIn':  _checkIn,
      'checkOut': _checkOut,
      'note':     _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(99)),
          )),
          const SizedBox(height: 16),

          // Title
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_forest, _emerald],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.fact_check_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.staffName,
                  style: const TextStyle(color: _ink, fontSize: 15,
                      fontWeight: FontWeight.w800)),
                Text(widget.date,
                  style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            )),
          ]),
          const SizedBox(height: 20),

          // Status picker
          const Text('STATUS', style: TextStyle(color: _muted, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(children: _statuses.map((s) {
            final isActive = _status == s;
            final col      = _statusColors[s]   ?? _muted;
            final bg       = _statusBgColors[s] ?? const Color(0xFFF3F4F6);
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _status = s),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color:        isActive ? col : bg,
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(
                      color: isActive ? col : _border),
                ),
                child: Center(child: Text(
                  _statusLabels[s] ?? s,
                  style: TextStyle(
                    color: isActive ? Colors.white : col,
                    fontSize: 11, fontWeight: FontWeight.w800),
                )),
              ),
            ));
          }).toList()),

          const SizedBox(height: 18),

          // Check-in / Check-out
          Row(children: [
            Expanded(child: _timeTile(
              label:   'Check-in',
              value:   _trimSec(_checkIn),
              icon:    Icons.login_rounded,
              onTap:   () => _pickTime(true),
              onClear: _checkIn != null ? () => setState(() => _checkIn = null) : null,
            )),
            const SizedBox(width: 10),
            Expanded(child: _timeTile(
              label:   'Check-out',
              value:   _trimSec(_checkOut),
              icon:    Icons.logout_rounded,
              onTap:   () => _pickTime(false),
              onClear: _checkOut != null ? () => setState(() => _checkOut = null) : null,
            )),
          ]),

          const SizedBox(height: 14),

          // Note
          const Text('NOTE (optional)', style: TextStyle(color: _muted,
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add a note...',
              hintStyle: const TextStyle(color: Color(0xFFB0B8B0), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _emerald, width: 1.8)),
            ),
          ),

          const SizedBox(height: 18),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: GestureDetector(
              onTap: _save,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_forest, _emerald],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                    color: _forest.withValues(alpha: 0.30),
                    blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.existing != null ? 'Update Attendance' : 'Save Attendance',
                    style: const TextStyle(color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w800),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _timeTile({
    required String  label,
    required String  value,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback?    onClear,
  }) {
    final hasValue = value.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasValue ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: hasValue ? const Color(0xFF6EE7B7) : _border),
        ),
        child: Row(children: [
          Icon(icon, size: 15,
              color: hasValue ? _forest : _muted),
          const SizedBox(width: 6),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(
                  color: _muted, fontSize: 10, fontWeight: FontWeight.w600)),
              Text(hasValue ? value : 'Tap to set',
                style: TextStyle(
                  color: hasValue ? _forest : _muted,
                  fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          )),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded,
                  size: 15, color: _muted),
            ),
        ]),
      ),
    );
  }
}

// ─── Header stat pill ─────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int    count;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$count',
          style: TextStyle(color: color, fontSize: 14,
              fontWeight: FontWeight.w900)),
        Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 9,
              fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
