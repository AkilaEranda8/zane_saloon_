import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';

const Color _forest  = Color(0xFF1B3A2D);
const Color _emerald = Color(0xFF2D6A4F);
const Color _canvas  = Color(0xFFF2F5F2);
const Color _surface = Colors.white;
const Color _ink     = Color(0xFF111827);
const Color _muted   = Color(0xFF6B7280);
const Color _border  = Color(0xFFE5E7EB);

// ─── Role meta ────────────────────────────────────────────────────────────────
const _roles = ['staff', 'manager', 'admin'];

const _roleLabels = {
  'superadmin': 'Super Admin',
  'admin':      'Admin',
  'manager':    'Manager',
  'staff':      'Staff',
};

const _roleColors = {
  'superadmin': Color(0xFF7C3AED),
  'admin':      Color(0xFF1D4ED8),
  'manager':    Color(0xFF047857),
  'staff':      Color(0xFF6B7280),
};

const _roleBgColors = {
  'superadmin': Color(0xFFEDE9FE),
  'admin':      Color(0xFFDBEAFE),
  'manager':    Color(0xFFD1FAE5),
  'staff':      Color(0xFFF3F4F6),
};

const _roleCapabilities = {
  'superadmin': ['Full system access', 'Manage users & roles', 'All branches', 'Delete records'],
  'admin':      ['All branches view', 'Manage staff', 'Expenses & reports', 'No user deletion'],
  'manager':    ['Own branch only', 'Add/edit appointments', 'Walk-in management', 'Expenses view'],
  'staff':      ['View appointments', 'Walk-in queue', 'Basic access only'],
};

// ─── Page ─────────────────────────────────────────────────────────────────────
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final app   = AppStateScope.of(context);
      final users = await app.loadAppUsers();
      if (!mounted) return;
      setState(() {
        _users   = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error   = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user, String newRole) async {
    final app = AppStateScope.of(context);
    final ok  = await app.changeUserRole(
      userId: '${user['id']}',
      role:   newRole,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        final idx = _users.indexWhere((u) => u['id'] == user['id']);
        if (idx != -1) _users = List.from(_users)..[idx] = {..._users[idx], 'role': newRole};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user['name']} role updated to ${_roleLabels[newRole] ?? newRole}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _forest,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(app.lastError ?? 'Failed to update role'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app  = AppStateScope.of(context);
    final myRole = (app.currentUser?.role ?? '').toLowerCase();
    final isSuperAdmin = myRole == 'superadmin';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _canvas,
        body: Column(children: [
          _buildHeader(),
          Expanded(child: _buildBody(isSuperAdmin)),
        ]),
      ),
    );
  }

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
          child: Row(children: [
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Staff Permissions',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                SizedBox(height: 2),
                Text('Manage role-based access per user',
                  style: TextStyle(color: Color(0xFFE5F6EC),
                      fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBody(bool isSuperAdmin) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _forest, strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: _muted, size: 40),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _muted),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      ));
    }
    if (_users.isEmpty) {
      return const Center(
          child: Text('No users found.', style: TextStyle(color: _muted)));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _users.length,
      itemBuilder: (ctx, i) {
        final user    = _users[i];
        final role    = (user['role'] ?? 'staff').toString().toLowerCase();
        final isSelf  = user['id'].toString() ==
            AppStateScope.of(context).currentUser?.id;
        final isSuper = role == 'superadmin';
        final canEdit = isSuperAdmin && !isSelf && !isSuper;
        return _UserRoleCard(
          user:     user,
          role:     role,
          canEdit:  canEdit,
          onRole:   canEdit
              ? (newRole) => _changeRole(user, newRole)
              : null,
        );
      },
    );
  }
}

// ─── User Role Card ───────────────────────────────────────────────────────────
class _UserRoleCard extends StatelessWidget {
  const _UserRoleCard({
    required this.user,
    required this.role,
    required this.canEdit,
    this.onRole,
  });

  final Map<String, dynamic> user;
  final String      role;
  final bool        canEdit;
  final void Function(String role)? onRole;

  @override
  Widget build(BuildContext context) {
    final color   = _roleColors[role]   ?? const Color(0xFF6B7280);
    final bgColor = _roleBgColors[role] ?? const Color(0xFFF3F4F6);
    final label   = _roleLabels[role]   ?? role;
    final caps    = _roleCapabilities[role] ?? [];
    final branch  = user['branch'] is Map
        ? '${(user['branch'] as Map)['name'] ?? ''}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Name row
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: Text(
                  (user['name'] ?? '?').toString().trim().isNotEmpty
                      ? (user['name'] as String).trim()[0].toUpperCase()
                      : '?',
                  style: TextStyle(color: color, fontSize: 16,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${user['name'] ?? ''}',
                  style: const TextStyle(color: _ink, fontSize: 14,
                      fontWeight: FontWeight.w700)),
                Text('@${user['username'] ?? ''}${branch.isNotEmpty ? '  ·  $branch' : ''}',
                  style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            )),
            // Current role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: bgColor, borderRadius: BorderRadius.circular(20)),
              child: Text(label,
                style: TextStyle(color: color, fontSize: 11,
                    fontWeight: FontWeight.w800)),
            ),
          ]),

          const SizedBox(height: 12),

          // Capabilities
          Wrap(
            spacing: 6, runSpacing: 6,
            children: caps.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _border),
              ),
              child: Text(c,
                style: const TextStyle(color: _muted, fontSize: 11,
                    fontWeight: FontWeight.w600)),
            )).toList(),
          ),

          // Role picker (only for editable users)
          if (canEdit) ...[
            const SizedBox(height: 14),
            const Text('Change role',
              style: TextStyle(color: _muted, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            const SizedBox(height: 8),
            Row(
              children: _roles.map((r) {
                final isActive = r == role;
                final rc = _roleColors[r]   ?? const Color(0xFF6B7280);
                final rb = _roleBgColors[r] ?? const Color(0xFFF3F4F6);
                return Expanded(child: GestureDetector(
                  onTap: isActive ? null : () => onRole?.call(r),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color:         isActive ? rc        : rb,
                      borderRadius:  BorderRadius.circular(10),
                      border:        Border.all(
                          color: isActive ? rc : _border),
                    ),
                    child: Center(
                      child: Text(
                        _roleLabels[r] ?? r,
                        style: TextStyle(
                          color:      isActive ? Colors.white : rc,
                          fontSize:   11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ));
              }).toList(),
            ),
          ],

          if (!canEdit && role != 'superadmin')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: const [
                Icon(Icons.lock_outline_rounded, size: 13, color: _muted),
                SizedBox(width: 5),
                Text('Only superadmin can change roles',
                  style: TextStyle(color: _muted, fontSize: 11)),
              ]),
            ),
        ]),
      ),
    );
  }
}
