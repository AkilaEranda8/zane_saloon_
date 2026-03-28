import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/commission_record.dart';
import '../models/staff_commission_summary.dart';
import '../state/app_state.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _forest  = Color(0xFF1B3A2D);
const Color _emerald = Color(0xFF2D6A4F);
const Color _gold    = Color(0xFFC9956C);
const Color _goldL   = Color(0xFFFFF7ED);
const Color _goldB   = Color(0xFFFDBA74);
const Color _canvas  = Color(0xFFF2F5F2);
const Color _surface = Color(0xFFFFFFFF);
const Color _border  = Color(0xFFE5E7EB);
const Color _ink     = Color(0xFF111827);
const Color _muted   = Color(0xFF6B7280);

// ── Month helpers ─────────────────────────────────────────────────────────────
const _monthNames = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _monthLabel(String ym) {
  try {
    final parts = ym.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return '${_monthNames[m]} $y';
  } catch (_) { return ym; }
}

String _fmtDate(String raw) {
  try {
    final d = DateTime.parse(raw);
    return '${d.day.toString().padLeft(2, '0')} '
        '${_monthNames[d.month].substring(0, 3)} ${d.year}';
  } catch (_) { return raw; }
}

// ─────────────────────────────────────────────────────────────────────────────
class CommissionPage extends StatefulWidget {
  const CommissionPage({super.key});
  @override
  State<CommissionPage> createState() => _CommissionPageState();
}

class _CommissionPageState extends State<CommissionPage> {
  bool _loading = true;
  String? _error;
  String _month = _currentMonth();
  double _total = 0;
  String? _staffName;
  List<CommissionRecord> _rows = const [];
  List<StaffCommissionSummary> _summaries = const [];
  String? _selectedStaffId;
  bool _depsLoaded = false;

  static String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsLoaded) return;
    _depsLoaded = true;
    _load();
  }

  /// Team mode: load all staff in scope (branch for staff/manager; all branches for superadmin/admin unless filtered).
  bool get _teamMode {
    final r = AppStateScope.of(context).currentUser?.role ?? '';
    return r == 'superadmin' ||
        r == 'admin' ||
        r == 'manager' ||
        r == 'staff';
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final app = AppStateScope.of(context);
      if (_teamMode) {
        final summaries = await app.loadStaffCommissionSummary(month: _month);
        if (!mounted) return;
        var sel = _selectedStaffId;
        if (sel != null && sel.isNotEmpty &&
            !summaries.any((s) => s.staffId == sel)) {
          sel = null;
          setState(() => _selectedStaffId = null);
        }
        if (sel != null && sel.isNotEmpty) {
          final detail = await app.loadStaffCommissionReport(
            staffId: sel,
            month: _month,
          );
          if (!mounted) return;
          StaffCommissionSummary? match;
          for (final s in summaries) {
            if (s.staffId == sel) {
              match = s;
              break;
            }
          }
          final name = detail.staffName ?? match?.staffName;
          setState(() {
            _summaries = summaries;
            _rows = detail.records;
            _total = detail.total;
            _staffName = name;
            _loading = false;
          });
        } else {
          final grand = summaries.fold(
              0.0, (double s, StaffCommissionSummary x) => s + x.totalCommission);
          setState(() {
            _summaries = summaries;
            _rows = const [];
            _total = grand;
            _staffName = null;
            _loading = false;
          });
        }
      } else {
        final result = await app.loadMyCommission(month: _month);
        if (!mounted) return;
        setState(() {
          _summaries = const [];
          _selectedStaffId = null;
          _rows = result.records;
          _total = result.total;
          _staffName = result.staffName;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickMonth() async {
    final base = DateTime.tryParse('$_month-01') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12),
      initialDatePickerMode: DatePickerMode.year,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _forest, onPrimary: Colors.white,
            surface: _surface, onSurface: _ink)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() =>
        _month = '${picked.year}-${picked.month.toString().padLeft(2, '0')}');
    _load();
  }

  // ── Commission % / sales ──────────────────────────────────────────────────
  double get _salesTotal {
    if (_teamMode && _selectedStaffId == null) {
      return _summaries.fold(0.0, (s, x) => s + x.totalRevenue);
    }
    return _rows.fold(0.0, (s, r) => s + r.totalAmount);
  }

  double get _commissionRate {
    final sales = _salesTotal;
    return sales > 0 ? (_total / sales) * 100 : 0;
  }

  int get _paymentCountStat {
    if (_teamMode && _selectedStaffId == null) {
      return _summaries.fold(0, (s, x) => s + x.appointmentCount);
    }
    return _rows.length;
  }

  bool get _isEmptyState {
    if (_teamMode && _selectedStaffId == null) return _summaries.isEmpty;
    if (_teamMode && _selectedStaffId != null) return _rows.isEmpty;
    return _rows.isEmpty;
  }

  String _filterAvatarLabel() {
    for (final s in _summaries) {
      if (s.staffId == _selectedStaffId) {
        final parts = s.staffName.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2 &&
            parts[0].isNotEmpty &&
            parts[1].isNotEmpty) {
          return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
        }
        return s.staffName.isNotEmpty ? s.staffName[0].toUpperCase() : '?';
      }
    }
    final n = (_staffName ?? '').trim();
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _canvas,
        body: RefreshIndicator(
          color: _forest,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: _forest, strokeWidth: 2.5)),
                )
              else if (_error != null)
                SliverFillRemaining(child: _buildError())
              else if (_isEmptyState)
                SliverFillRemaining(child: _buildEmpty())
              else ...[
                if (_teamMode &&
                    _selectedStaffId == null &&
                    _summaries.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    sliver: SliverToBoxAdapter(
                      child: _sectionLabel(
                          'ALL STAFF  •  ${_summaries.length} members'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _StaffSummaryCard(
                          row: _summaries[i],
                          onTap: () {
                            setState(() =>
                                _selectedStaffId = _summaries[i].staffId);
                            _load();
                          },
                        ),
                        childCount: _summaries.length,
                      ),
                    ),
                  ),
                ],
                if (_rows.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    sliver: SliverToBoxAdapter(
                      child: _sectionLabel(
                          'BREAKDOWN  •  ${_rows.length} records'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _CommissionCard(record: _rows[i]),
                        childCount: _rows.length,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Header block ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _canvas,
      child: SafeArea(
        bottom: false,
        child: Column(children: [

          // ── Top bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _surface,
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: _forest, size: 15),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Row(children: [
                  Icon(Icons.workspace_premium_rounded,
                      color: _forest, size: 18),
                  SizedBox(width: 6),
                  Text('Commission',
                    style: TextStyle(
                      color: _forest, fontSize: 16,
                      fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                ]),
              ),
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _surface, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: _forest, size: 17),
                ),
              ),
            ]),
          ),

          // ── Staff + month row ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              // Staff pill (team: filter all staff vs one person)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: _teamMode
                      ? Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_forest, _emerald],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                              shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                _selectedStaffId == null
                                    ? '∑'
                                    : (_filterAvatarLabel()),
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: _selectedStaffId,
                                hint: const Text('All staff',
                                    style: TextStyle(
                                        color: _ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800)),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                    color: _forest, size: 18),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All staff',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  ..._summaries.map((s) =>
                                      DropdownMenuItem<String?>(
                                        value: s.staffId,
                                        child: Text(s.staffName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                      )),
                                ],
                                onChanged: (v) {
                                  setState(() => _selectedStaffId = v);
                                  _load();
                                },
                              ),
                            ),
                          ),
                        ])
                      : Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_forest, _emerald],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                              shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                (_staffName ?? 'Me').trim().isNotEmpty
                                    ? (_staffName ?? 'Me').trim().split(' ')
                                        .map((e) => e.isNotEmpty
                                            ? e[0].toUpperCase() : '')
                                        .take(2).join()
                                    : 'Me',
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _staffName ?? 'My Commission',
                                  style: const TextStyle(
                                    color: _ink, fontSize: 13,
                                    fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis),
                                const Text('Staff member',
                                  style: TextStyle(
                                    color: _muted, fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ]),
                ),
              ),
              const SizedBox(width: 10),
              // Month picker
              GestureDetector(
                onTap: _pickMonth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_month_rounded,
                        color: _forest, size: 15),
                    const SizedBox(width: 6),
                    Text(_monthLabel(_month),
                      style: const TextStyle(
                        color: _forest, fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _forest, size: 15),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Commission summary card ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_forest, _emerald],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(
                  color: _forest.withValues(alpha: 0.30),
                  blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month label
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Colors.white60, size: 12),
                    const SizedBox(width: 5),
                    Text(_monthLabel(_month),
                      style: const TextStyle(
                        color: Colors.white60, fontSize: 12,
                        fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 12),
                  // Total commission row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Commission',
                              style: TextStyle(
                                color: Colors.white70, fontSize: 12,
                                fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            _loading
                                ? Container(
                                    width: 120, height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                          alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8)))
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      const Text('LKR ',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                      Text(_total.toStringAsFixed(0),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1)),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                      // Stats pills
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!_loading) ...[
                            _StatPill(
                              icon: Icons.receipt_rounded,
                              label: _teamMode && _selectedStaffId == null
                                  ? '$_paymentCountStat appts'
                                  : '$_paymentCountStat payments'),
                            const SizedBox(height: 6),
                            _StatPill(
                              icon: Icons.trending_up_rounded,
                              label: 'Sales LKR ${_salesTotal.toStringAsFixed(0)}'),
                            if (_commissionRate > 0) ...[
                              const SizedBox(height: 6),
                              _StatPill(
                                icon: Icons.percent_rounded,
                                label: '${_commissionRate.toStringAsFixed(1)}% rate'),
                            ],
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
      style: const TextStyle(
        color: _muted, fontSize: 11.5,
        fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );

  Widget _buildError() => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.wifi_off_rounded,
          color: Color(0xFFDC2626), size: 26),
    ),
    const SizedBox(height: 14),
    Text(_error!,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _ink, fontSize: 14,
          fontWeight: FontWeight.w600)),
    const SizedBox(height: 10),
    GestureDetector(
      onTap: _load,
      child: const Text('Tap to retry',
        style: TextStyle(color: _emerald, fontSize: 13,
            fontWeight: FontWeight.w600)),
    ),
  ]));

  Widget _buildEmpty() => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_forest.withValues(alpha: 0.12),
                   _emerald.withValues(alpha: 0.06)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        shape: BoxShape.circle),
      child: const Icon(Icons.workspace_premium_rounded,
          color: _forest, size: 30),
    ),
    const SizedBox(height: 16),
    const Text('No commission records',
      style: TextStyle(color: _ink, fontSize: 16,
          fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    Text('No data for ${_monthLabel(_month)}',
      style: const TextStyle(color: _muted, fontSize: 13)),
    const SizedBox(height: 16),
    GestureDetector(
      onTap: _pickMonth,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_month_rounded,
              color: _forest, size: 15),
          SizedBox(width: 7),
          Text('Change month',
            style: TextStyle(
              color: _forest, fontSize: 13,
              fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  ]));
}

// ═════════════════════════════════════════════════════════════════════════════
// STAFF SUMMARY ROW (team / all staff view)
// ═════════════════════════════════════════════════════════════════════════════
class _StaffSummaryCard extends StatelessWidget {
  const _StaffSummaryCard({required this.row, required this.onTap});
  final StaffCommissionSummary row;
  final VoidCallback onTap;

  static const List<List<Color>> _gradients = [
    [Color(0xFF1B3A2D), Color(0xFF2D6A4F)],
    [Color(0xFF1E3A5F), Color(0xFF2563EB)],
    [Color(0xFF4C1D95), Color(0xFF7C3AED)],
    [Color(0xFF7F1D1D), Color(0xFFDC2626)],
  ];

  @override
  Widget build(BuildContext context) {
    final initials = row.staffName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2).map((e) => e[0].toUpperCase()).join();
    final g = _gradients[row.staffName.hashCode.abs() % _gradients.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle),
            child: Center(
              child: Text(
                initials.isNotEmpty ? initials : '?',
                style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.staffName,
                  style: const TextStyle(
                    color: _ink, fontSize: 14.5, fontWeight: FontWeight.w800)),
                if (row.branchName.isNotEmpty)
                  Text(row.branchName,
                    style: const TextStyle(color: _muted, fontSize: 11.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('LKR ${row.totalCommission.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: _forest, fontSize: 15, fontWeight: FontWeight.w900)),
              Text('${row.appointmentCount} appts',
                style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
        ]),
      ),
    );
  }
}

// ── Stat pill ─────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Colors.white70),
      const SizedBox(width: 5),
      Text(label,
        style: const TextStyle(
          color: Colors.white, fontSize: 11.5,
          fontWeight: FontWeight.w700)),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// COMMISSION CARD
// ═════════════════════════════════════════════════════════════════════════════
class _CommissionCard extends StatelessWidget {
  const _CommissionCard({required this.record});
  final CommissionRecord record;

  @override
  Widget build(BuildContext context) {
    final r        = record;
    final name     = r.customerName.isEmpty ? 'Walk-in' : r.customerName;
    final initials = name.trim().split(' ')
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .take(2).join();

    // Commission % for this record
    final rate = r.totalAmount > 0
        ? (r.commissionAmount / r.totalAmount) * 100
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(children: [

          // Avatar
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_forest, _emerald],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: _forest.withValues(alpha: 0.22),
                blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Center(
              child: Text(initials,
                style: const TextStyle(
                  color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w800)),
            ),
          ),

          const SizedBox(width: 13),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                  style: const TextStyle(
                    color: _ink, fontSize: 14.5,
                    fontWeight: FontWeight.w800, letterSpacing: -0.1)),
                const SizedBox(height: 3),
                if (r.serviceName.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.content_cut_rounded,
                        size: 11, color: _muted),
                    const SizedBox(width: 4),
                    Text(r.serviceName,
                      style: const TextStyle(
                        color: _muted, fontSize: 12.5,
                        fontWeight: FontWeight.w500)),
                  ]),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 11, color: _muted),
                  const SizedBox(width: 4),
                  Text(_fmtDate(r.date),
                    style: const TextStyle(
                      color: _muted, fontSize: 11.5,
                      fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  // Rate badge
                  if (rate > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _goldL,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: _goldB.withValues(alpha: 0.5))),
                      child: Text('${rate.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: _gold, fontSize: 10.5,
                          fontWeight: FontWeight.w800)),
                    ),
                ]),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Amounts
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('LKR',
              style: TextStyle(
                color: _forest.withValues(alpha: 0.55),
                fontSize: 10, fontWeight: FontWeight.w700)),
            Text(r.commissionAmount.toStringAsFixed(0),
              style: const TextStyle(
                color: _forest, fontSize: 20,
                fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            Text('of ${r.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: _muted, fontSize: 10.5,
                fontWeight: FontWeight.w500)),
          ]),

        ]),
      ),
    );
  }
}
