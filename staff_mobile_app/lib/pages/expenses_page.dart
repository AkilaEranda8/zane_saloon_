import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';

const Color _forest = Color(0xFF1B3A2D);
const Color _emerald = Color(0xFF2D6A4F);
const Color _canvas = Color(0xFFF2F5F2);
const Color _surface = Colors.white;
const Color _ink = Color(0xFF111827);
const Color _muted = Color(0xFF6B7280);
const Color _border = Color(0xFFE5E7EB);

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  double _totalAmount = 0;
  int _totalCount = 0;
  List<Map<String, String>> _branches = const [];
  String _selectedMonth = '';
  String _selectedCategory = '';

  static const List<String> _categories = [
    '',
    'rent',
    'salary',
    'utilities',
    'inventory',
    'maintenance',
    'marketing',
    'other',
  ];

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String _monthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (m < 1 || m > 12) return key;
    return '${names[m]} $y';
  }

  static String _displayDate(String raw) {
    if (raw.trim().isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      return '${d.day.toString().padLeft(2, '0')} ${_monthShort(d.month)} ${d.year}';
    } catch (_) {
      return raw;
    }
  }

  static String _monthShort(int m) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][m];

  static _CategoryStyle _categoryStyle(String categoryRaw) {
    final category = categoryRaw.toLowerCase();
    if (category == 'rent') {
      return const _CategoryStyle(
        text: Color(0xFF1D4ED8),
        bg: Color(0xFFDBEAFE),
        icon: Icons.home_work_rounded,
      );
    }
    if (category == 'salary') {
      return const _CategoryStyle(
        text: Color(0xFF7C3AED),
        bg: Color(0xFFEDE9FE),
        icon: Icons.badge_rounded,
      );
    }
    if (category == 'utilities') {
      return const _CategoryStyle(
        text: Color(0xFFD97706),
        bg: Color(0xFFFEF3C7),
        icon: Icons.bolt_rounded,
      );
    }
    if (category == 'inventory') {
      return const _CategoryStyle(
        text: Color(0xFF047857),
        bg: Color(0xFFD1FAE5),
        icon: Icons.inventory_2_rounded,
      );
    }
    return const _CategoryStyle(
      text: Color(0xFF0F766E),
      bg: Color(0xFFCCFBF1),
      icon: Icons.receipt_long_rounded,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final app = AppStateScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = (app.currentUser?.role ?? '').toLowerCase();
      if (role == 'superadmin') {
        final br = await app.loadBranches();
        _branches = br;
      }
      final result = await app.loadExpenses(
        branchId: app.currentUser?.branchId,
        page: 1,
        limit: 100,
        month: _selectedMonth.isEmpty ? null : _selectedMonth,
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
      );
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _error = app.lastError ?? 'Failed to load expenses';
          _loading = false;
        });
        return;
      }
      setState(() {
        _rows = result.data;
        _totalAmount = result.totalAmount;
        _totalCount = result.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openAdd() async {
    final app = AppStateScope.of(context);
    final role = (app.currentUser?.role ?? '').toLowerCase();
    if (role != 'superadmin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only superadmin can add expenses.')),
      );
      return;
    }

    if (_branches.isEmpty) {
      final loaded = await app.loadBranches();
      _branches = loaded;
    }

    final draft = await showModalBottomSheet<_ExpenseDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddExpenseSheet(
        branches: _branches,
        initialBranchId: app.currentUser?.branchId,
      ),
    );

    if (draft == null || !mounted) return;

    final ok = await app.addExpense(
      branchId: draft.branchId,
      category: draft.category,
      title: draft.title,
      amount: draft.amount,
      date: draft.date,
      paidTo: draft.paidTo,
      paymentMethod: draft.paymentMethod,
      receiptNumber: draft.receiptNumber,
      notes: draft.notes,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(app.lastError ?? 'Failed to add expense'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expense added successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, 1);
    final selected = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Select month',
      fieldHintText: 'MM/DD/YYYY',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedMonth = _monthKey(DateTime(selected.year, selected.month, 1));
    });
    await _load();
  }

  Widget _buildHeader(bool isSuperAdmin) {
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expenses',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Track branch spending and totals',
                          style: TextStyle(
                            color: Color(0xFFE5F6EC),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _TopMetricCard(
                      title: 'Month Total',
                      value: 'LKR ${_totalAmount.toStringAsFixed(2)}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TopMetricCard(
                      title: 'Records',
                      value: '$_totalCount',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _HeaderActionChip(
                      icon: Icons.calendar_month_rounded,
                      label: _selectedMonth.isEmpty
                          ? 'All months'
                          : _monthLabel(_selectedMonth),
                      onTap: _pickMonth,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeaderActionChip(
                      icon: Icons.category_rounded,
                      label: _selectedCategory.isEmpty ? 'All categories' : _selectedCategory,
                      onTap: () async {
                        final val = await showModalBottomSheet<String>(
                          context: context,
                          builder: (ctx) {
                            return SafeArea(
                              child: ListView(
                                shrinkWrap: true,
                                children: _categories
                                    .map(
                                      (c) => ListTile(
                                        leading: Icon(
                                          c.isEmpty ? Icons.grid_view_rounded : Icons.label_outline_rounded,
                                        ),
                                        title: Text(c.isEmpty ? 'All categories' : c),
                                        onTap: () => Navigator.of(ctx).pop(c),
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                          },
                        );
                        if (val == null || !mounted) return;
                        setState(() => _selectedCategory = val);
                        await _load();
                      },
                    ),
                  ),
                ],
              ),
              if (!isSuperAdmin) ...[
                const SizedBox(height: 8),
                const Text(
                  'Only superadmin can add expenses',
                  style: TextStyle(
                    color: Color(0xFFD1FAE5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final isSuperAdmin = (app.currentUser?.role ?? '').toLowerCase() == 'superadmin';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _canvas,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: isSuperAdmin
            ? Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: _openAdd,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_forest, _emerald],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _forest.withValues(alpha: 0.34),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Add Expense',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
        body: Column(
          children: [
            _buildHeader(isSuperAdmin),
            Expanded(
              child: RefreshIndicator(
                color: _forest,
                onRefresh: _load,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: _forest,
                          strokeWidth: 2.5,
                        ),
                      )
                    : _error != null
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: _muted),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: TextButton(
                                  onPressed: _load,
                                  child: const Text('Tap to retry'),
                                ),
                              ),
                            ],
                          )
                        : _rows.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Text(
                                      'No expenses found for this filter',
                                      style: TextStyle(
                                        color: _muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 92),
                                itemCount: _rows.length,
                                itemBuilder: (ctx, i) {
                                  final row = _rows[i];
                                  final amount = double.tryParse('${row['amount'] ?? 0}') ?? 0;
                                  final branch = (row['branch'] is Map)
                                      ? '${(row['branch'] as Map)['name'] ?? ''}'
                                      : '';
                                  final creator = (row['creator'] is Map)
                                      ? '${(row['creator'] as Map)['name'] ?? ''}'
                                      : '';
                                  return _ExpenseCard(
                                    title: '${row['title'] ?? 'Expense'}',
                                    category: '${row['category'] ?? 'other'}',
                                    amount: amount,
                                    date: _displayDate('${row['date'] ?? ''}'),
                                    branch: branch,
                                    creator: creator,
                                    notes: '${row['notes'] ?? ''}',
                                    paidTo: '${row['paid_to'] ?? ''}',
                                    method: '${row['payment_method'] ?? ''}',
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.branch,
    required this.creator,
    required this.notes,
    required this.paidTo,
    required this.method,
  });

  final String title;
  final String category;
  final double amount;
  final String date;
  final String branch;
  final String creator;
  final String notes;
  final String paidTo;
  final String method;

  @override
  Widget build(BuildContext context) {
    final style = _ExpensesPageState._categoryStyle(category);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(style.icon, size: 18, color: style.text),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: style.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'LKR ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: _emerald,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$date${branch.isEmpty ? '' : '  •  $branch'}${creator.isEmpty ? '' : '  •  $creator'}',
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (notes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              notes,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
              ),
            ),
          ],
          if (paidTo.trim().isNotEmpty || method.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${paidTo.trim().isEmpty ? '' : 'Paid to: $paidTo'}${(paidTo.trim().isNotEmpty && method.trim().isNotEmpty) ? '  •  ' : ''}${method.trim().isEmpty ? '' : 'Method: $method'}',
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryStyle {
  const _CategoryStyle({
    required this.text,
    required this.bg,
    required this.icon,
  });

  final Color text;
  final Color bg;
  final IconData icon;
}

class _TopMetricCard extends StatelessWidget {
  const _TopMetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD1FAE5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionChip extends StatelessWidget {
  const _HeaderActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDraft {
  _ExpenseDraft({
    required this.branchId,
    required this.category,
    required this.title,
    required this.amount,
    required this.date,
    this.paidTo,
    this.paymentMethod,
    this.receiptNumber,
    this.notes,
  });

  final String branchId;
  final String category;
  final String title;
  final String amount;
  final String date;
  final String? paidTo;
  final String? paymentMethod;
  final String? receiptNumber;
  final String? notes;
}

class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet({required this.branches, this.initialBranchId});

  final List<Map<String, String>> branches;
  final String? initialBranchId;

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  static const _methodOptions = <String>[
    'cash',
    'card',
    'online transfer',
    'bank transfer',
    'other',
  ];

  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _category = TextEditingController(text: 'other');
  final _date = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _paidTo = TextEditingController();
  final _paymentMethod = TextEditingController(text: 'cash');
  final _receiptNumber = TextEditingController();
  final _notes = TextEditingController();
  String _branchId = '';

  Future<void> _pickExpenseDate() async {
    final now = DateTime.now();
    final parts = _date.text.split('-');
    DateTime initial = now;
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        initial = DateTime(y, m, d);
      }
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  @override
  void initState() {
    super.initState();
    final ids = widget.branches.map((b) => b['id'] ?? '').toSet();
    final initId = widget.initialBranchId ?? '';
    if (initId.isNotEmpty && ids.contains(initId)) {
      _branchId = initId;
    } else if (widget.branches.isNotEmpty) {
      _branchId = widget.branches.first['id'] ?? '';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _category.dispose();
    _date.dispose();
    _paidTo.dispose();
    _paymentMethod.dispose();
    _receiptNumber.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_branchId.isEmpty) return;

    Navigator.of(context).pop(
      _ExpenseDraft(
      branchId: _branchId,
      category: _category.text.trim(),
      title: _title.text.trim(),
      amount: _amount.text.trim(),
      date: _date.text.trim(),
      paidTo: _paidTo.text.trim().isEmpty ? null : _paidTo.text.trim(),
      paymentMethod: _paymentMethod.text.trim().isEmpty ? null : _paymentMethod.text.trim(),
      receiptNumber: _receiptNumber.text.trim().isEmpty ? null : _receiptNumber.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    ),
    );
  }

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0B8B0), fontSize: 14),
        prefixIcon: Icon(icon, color: _emerald, size: 19),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _emerald, width: 1.8),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: _emerald),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Add Expense',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label('Branch'),
                DropdownButtonFormField<String>(
                  value: _branchId.isEmpty ? null : _branchId,
                  decoration: _deco('Select branch', Icons.store_mall_directory_rounded),
                  items: widget.branches
                      .map((b) => DropdownMenuItem<String>(
                            value: b['id'] ?? '',
                            child: Text(b['name'] ?? ''),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _branchId = v ?? ''),
                  validator: (v) => (v == null || v.isEmpty) ? 'Branch required' : null,
                ),
                const SizedBox(height: 10),
                _label('Title'),
                TextFormField(
                  controller: _title,
                  decoration: _deco('Expense title', Icons.title_rounded),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                _label('Category'),
                DropdownButtonFormField<String>(
                  value: _category.text,
                  decoration: _deco('Select category', Icons.category_rounded),
                  items: _ExpensesPageState._categories
                      .where((c) => c.isNotEmpty)
                      .map((c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _category.text = v ?? 'other'),
                ),
                const SizedBox(height: 10),
                _label('Amount'),
                TextFormField(
                  controller: _amount,
                  decoration: _deco('0.00', Icons.payments_rounded),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _label('Date'),
                TextFormField(
                  controller: _date,
                  readOnly: true,
                  onTap: _pickExpenseDate,
                  decoration: _deco('YYYY-MM-DD', Icons.calendar_today_rounded),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                _label('Paid To (optional)'),
                TextFormField(
                  controller: _paidTo,
                  decoration: _deco('Supplier / person', Icons.person_outline_rounded),
                ),
                const SizedBox(height: 10),
                _label('Payment Method'),
                DropdownButtonFormField<String>(
                  value: _paymentMethod.text.trim().isEmpty ? 'cash' : _paymentMethod.text,
                  decoration: _deco('Select method', Icons.account_balance_wallet_rounded),
                  items: _methodOptions
                      .map((m) => DropdownMenuItem<String>(
                            value: m,
                            child: Text(m),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _paymentMethod.text = v ?? 'cash'),
                ),
                const SizedBox(height: 10),
                _label('Receipt No (optional)'),
                TextFormField(
                  controller: _receiptNumber,
                  decoration: _deco('Receipt number', Icons.receipt_rounded),
                ),
                const SizedBox(height: 10),
                _label('Notes (optional)'),
                TextFormField(
                  controller: _notes,
                  decoration: _deco('Additional details', Icons.notes_rounded),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('Save Expense'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
