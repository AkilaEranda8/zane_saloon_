import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/staff_user.dart';
import '../state/app_state.dart';
import 'ai_chat_page.dart';
import 'appointments_page.dart';
import 'calendar_page.dart';
import 'commission_page.dart';
import 'customers_page.dart';
import 'login_page.dart';
import 'payments_page.dart';
import 'permissions_page.dart';
import 'reminders_page.dart';
import 'services_page.dart';
import 'staff_page.dart';
import 'walkin_page.dart';

// ─── Colour tokens ────────────────────────────────────────────────────────────
const _kBg = Color(0xFFF6F2EE);
const _kCard = Colors.white;
const _kGold = Color(0xFFC9956C);
const _kGoldLight = Color(0xFFE8C9A8);
const _kHeaderTop = Color(0xFF180D2A);
const _kHeaderBot = Color(0xFF2E1A48);
const _kText = Color(0xFF1A1025);
const _kMuted = Color(0xFF7B6E78);
// ─────────────────────────────────────────────────────────────────────────────

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  Future<void>? _initialLoad;
  String? _dashboardError;
  late AnimationController _ac;
  late Animation<double> _fade;
  final ScrollController _scrollCtrl = ScrollController();
  bool _isCollapsed = false;

  // expanded height minus toolbar height = collapse threshold
  static const double _expandedHeight = 220;
  static const double _collapseAt = _expandedHeight - kToolbarHeight;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    Future.microtask(() => _ac.forward());

    _scrollCtrl.addListener(() {
      final collapsed =
          _scrollCtrl.hasClients && _scrollCtrl.offset > _collapseAt;
      if (collapsed != _isCollapsed) setState(() => _isCollapsed = collapsed);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initialLoad ??= _loadInitial();
  }

  @override
  void dispose() {
    _ac.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final s = AppStateScope.of(context);
    try {
      if (s.hasPermission(StaffPermission.canViewAppointments)) {
        await s.loadAppointments();
      }
      if (s.hasPermission(StaffPermission.canViewCustomers)) {
        await s.loadCustomers();
      }
      await s.loadServices();
    } catch (_) {
      if (mounted) {
        setState(() => _dashboardError =
            'Could not load data. Check your connection.');
      }
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _dateStr {
    final n = DateTime.now();
    const m = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    const d = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${d[n.weekday - 1]}, ${m[n.month - 1]} ${n.day}';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStateScope.of(context);
    final user = s.currentUser;

    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fade,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: _expandedHeight,
              pinned: true,
              floating: false,
              elevation: 0,
              automaticallyImplyLeading: false,
              backgroundColor: _kHeaderTop,
              // title is null when expanded — only appears after collapse
              title: _isCollapsed
                  ? _CollapsedTitle(onLogout: () {
                      s.logout();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (_) => false,
                      );
                    })
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _HeaderBanner(
                  greeting: _greeting,
                  dateStr: _dateStr,
                  userName: user?.displayName ?? 'Staff',
                  role: user?.role ?? 'staff',
                  onLogout: () {
                    s.logout();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (_) => false,
                    );
                  },
                ),
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Stats row
                  _statsRow(s, user),
                  const SizedBox(height: 28),

                  // Quick actions
                  _sectionLabel('Quick Actions'),
                  const SizedBox(height: 14),
                  _actionsGrid(context, s),
                  const SizedBox(height: 28),

                  // Recent appointments
                  _recentHeader(context, s),
                  const SizedBox(height: 14),
                  if (_initialLoad != null)
                    FutureBuilder<void>(
                      future: _initialLoad,
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: _kGold, strokeWidth: 2.5),
                            ),
                          );
                        }
                        return _recentList(s);
                      },
                    )
                  else
                    _recentList(s),

                  if (_dashboardError != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: _dashboardError!),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  Widget _statsRow(AppState s, StaffUser? user) {
    return Row(children: [
      Expanded(
        child: _StatCard(
          label: 'Appointments',
          value: '${s.appointments.length}',
          icon: Icons.event_rounded,
          accent: _kGold,
          onTap: s.hasPermission(StaffPermission.canViewAppointments)
              ? () => _push(context, const AppointmentsPage())
              : null,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatCard(
          label: 'Customers',
          value: '${s.customers.length}',
          icon: Icons.people_rounded,
          accent: const Color(0xFF059669),
          onTap: s.hasPermission(StaffPermission.canViewCustomers)
              ? () => _push(context, const CustomersPage())
              : null,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatCard(
          label: 'Services',
          value: '${s.services.length}',
          icon: Icons.content_cut_rounded,
          accent: const Color(0xFF7C3AED),
        ),
      ),
    ]);
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String title) {
    return Row(children: [
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kGoldLight, _kGold],
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
            color: _kText,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          )),
    ]);
  }

  // ── Quick actions grid ─────────────────────────────────────────────────────

  Widget _actionsGrid(BuildContext context, AppState s) {
    final items = [
      _Action('Appointments', Icons.calendar_month_rounded,
          const Color(0xFFFFF3E8), _kGold, const AppointmentsPage(),
          enabled: s.hasPermission(StaffPermission.canViewAppointments)),
      _Action('Customers', Icons.people_alt_rounded,
          const Color(0xFFECFDF5), const Color(0xFF059669), const CustomersPage(),
          enabled: s.hasPermission(StaffPermission.canViewCustomers)),
      _Action('Services', Icons.design_services_rounded,
          const Color(0xFFF5F3FF), const Color(0xFF7C3AED), const ServicesPage()),
      _Action('Payments', Icons.payments_rounded,
          const Color(0xFFEFF6FF), const Color(0xFF2563EB), const PaymentsPage()),
      _Action('Calendar', Icons.calendar_today_rounded,
          const Color(0xFFFDF2F8), const Color(0xFFDB2777), const CalendarPage()),
      _Action('Walk-in', Icons.directions_walk_rounded,
          const Color(0xFFFFFBEB), const Color(0xFFD97706), const WalkInPage()),
      _Action('Staff', Icons.badge_rounded,
          const Color(0xFFECFEFF), const Color(0xFF0891B2), const StaffPage()),
      _Action('Commission', Icons.monetization_on_rounded,
          const Color(0xFFF0FDF4), const Color(0xFF16A34A), const CommissionPage()),
      _Action('AI Chat', Icons.smart_toy_rounded,
          const Color(0xFFFAF5FF), const Color(0xFF9333EA), const AiChatPage()),
      _Action('Reminders', Icons.notifications_rounded,
          const Color(0xFFFFF1F2), const Color(0xFFE11D48), const RemindersPage()),
      _Action('Permissions', Icons.admin_panel_settings_rounded,
          const Color(0xFFF8FAFC), const Color(0xFF475569), const PermissionsPage(),
          enabled: s.hasPermission(StaffPermission.canManagePermissions)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _ActionTile(
        item: items[i],
        onTap: items[i].enabled
            ? () => _push(context, items[i].page)
            : () => _noPermission(context),
      ),
    );
  }

  // ── Recent appointments ────────────────────────────────────────────────────

  Widget _recentHeader(BuildContext context, AppState s) {
    return Row(children: [
      Expanded(child: _sectionLabel('Recent Appointments')),
      GestureDetector(
        onTap: s.hasPermission(StaffPermission.canViewAppointments)
            ? () => _push(context, const AppointmentsPage())
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _kGold.withValues(alpha: 0.12),
            border: Border.all(color: _kGold.withValues(alpha: 0.35)),
          ),
          child: const Row(children: [
            Text('See all',
                style: TextStyle(
                    color: _kGold, fontSize: 12, fontWeight: FontWeight.w700)),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, color: _kGold, size: 13),
          ]),
        ),
      ),
    ]);
  }

  Widget _recentList(AppState s) {
    if (!s.hasPermission(StaffPermission.canViewAppointments)) {
      return _HintCard(
          icon: Icons.lock_outline_rounded,
          text: 'No permission to view appointments.');
    }
    final sorted = s.appointments.toList()
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : a.time.compareTo(b.time);
      });
    final top = sorted.reversed.take(3).toList();
    if (top.isEmpty) {
      return _HintCard(
          icon: Icons.event_busy_rounded,
          text: 'No appointments yet. Tap Appointments to add one.');
    }
    return Column(
      children: top
          .map((appt) => _ApptCard(appt: appt))
          .toList(),
    );
  }

  void _push(BuildContext context, Widget page) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => page));

  void _noPermission(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('No permission for this section'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _kHeaderTop,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

// ── Header banner ──────────────────────────────────────────────────────────

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({
    required this.greeting,
    required this.dateStr,
    required this.userName,
    required this.role,
    required this.onLogout,
  });

  final String greeting;
  final String dateStr;
  final String userName;
  final String role;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kHeaderTop, _kHeaderBot, Color(0xFF3D1F5A)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -50,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x14C9956C),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 30,
            child: Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0EC9956C),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x109333EA),
              ),
            ),
          ),

          // Gold top border line
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  Color(0x80C9956C),
                  _kGold,
                  Color(0x80C9956C),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // Bottom fade — thin, doesn't cover badges
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 28,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, _kBg],
                ),
              ),
            ),
          ),

          // Content — full height column, SafeArea handles status bar
          SafeArea(
            bottom: false,
            child: Padding(
              // top: space for the toolbar row that overlays this background
              // kToolbarHeight ≈ 56; add 4px breathing room
              padding: const EdgeInsets.fromLTRB(22, kToolbarHeight + 4, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Greeting
                  Text(greeting,
                      style: const TextStyle(
                        color: Color(0x90F5EEE8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      )),
                  const SizedBox(height: 4),
                  Text(userName,
                      style: const TextStyle(
                        color: Color(0xFFF5EEE8),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      )),
                  const SizedBox(height: 14),

                  // Badges row
                  Row(children: [
                    _Badge(
                        icon: Icons.calendar_today_rounded,
                        label: dateStr,
                        color: _kGold),
                    const SizedBox(width: 8),
                    _Badge(
                        icon: Icons.shield_rounded,
                        label: role.toUpperCase(),
                        color: const Color(0xFFA78BFA)),
                  ]),
                ],
              ),
            ),
          ),

          // Toolbar-level row — scissors logo + salon name + logout
          // Sits at the top, same height as the pinned SliverAppBar toolbar
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: const LinearGradient(
                            colors: [_kGoldLight, _kGold]),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55C9956C),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          )
                        ],
                      ),
                      child: const Icon(Icons.content_cut_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('ZANE SALON',
                        style: TextStyle(
                          color: Color(0xFFF5EEE8),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                        )),
                    const Spacer(),
                    GestureDetector(
                      onTap: onLogout,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(Icons.logout_rounded,
                            color: _kGold, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: const LinearGradient(colors: [_kGoldLight, _kGold]),
          ),
          child: const Icon(Icons.content_cut_rounded,
              color: Colors.white, size: 15),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Zane Salon',
            style: TextStyle(
                color: Color(0xFFF5EEE8),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3),
          ),
        ),
        GestureDetector(
          onTap: onLogout,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.08),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(Icons.logout_rounded, color: _kGold, size: 17),
          ),
        ),
      ],
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            const BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(color: accent.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    color: _kText,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(color: _kMuted, fontSize: 11.5)),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('View →',
                    style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Action tile ────────────────────────────────────────────────────────────

class _Action {
  const _Action(
      this.label, this.icon, this.bgColor, this.iconColor, this.page,
      {this.enabled = true});
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final Widget page;
  final bool enabled;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.item, required this.onTap});
  final _Action item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = item.enabled;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: item.iconColor.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                  const BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
          border: Border.all(
            color: enabled
                ? item.iconColor.withValues(alpha: 0.12)
                : const Color(0x10000000),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: enabled
                    ? item.bgColor
                    : const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                item.icon,
                color: enabled ? item.iconColor : const Color(0xFFCBD5E1),
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: enabled ? _kText : const Color(0xFFCBD5E1),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Appointment card ───────────────────────────────────────────────────────

class _ApptCard extends StatelessWidget {
  const _ApptCard({required this.appt});
  final dynamic appt;

  Color _accent() {
    switch ((appt.status as String).toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF2563EB);
      case 'completed':
        return const Color(0xFF059669);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0C000000), blurRadius: 14, offset: Offset(0, 5)),
        ],
        border: Border(
          left: BorderSide(color: accent, width: 4),
          top: BorderSide(color: const Color(0x10000000), width: 1),
          right: BorderSide(color: const Color(0x10000000), width: 1),
          bottom: BorderSide(color: const Color(0x10000000), width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(children: [
          // Time
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
              border:
                  Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(
                appt.time,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appt.customerName,
                    style: const TextStyle(
                        color: _kText,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(appt.serviceName,
                    style: const TextStyle(color: _kMuted, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(appt.date,
                    style: const TextStyle(
                        color: Color(0xFFB0A8B0), fontSize: 11.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.30)),
            ),
            child: Text(appt.status,
                style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ── Hint / empty card ──────────────────────────────────────────────────────

class _HintCard extends StatelessWidget {
  const _HintCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x09000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0x12000000)),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFFCBD5E1), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style:
                  const TextStyle(color: _kMuted, fontSize: 13.5)),
        ),
      ]),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFDC2626), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
