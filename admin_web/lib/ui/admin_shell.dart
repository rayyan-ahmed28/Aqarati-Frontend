import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../data/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import 'admin_kit.dart';

class NavEntry {
  final String path, label;
  final IconData icon;
  final Permission? permission;
  const NavEntry(this.path, this.label, this.icon, [this.permission]);
}

const navEntries = [
  NavEntry('/dashboard', 'Dashboard', Icons.space_dashboard_outlined, Permission.viewQueue),
  NavEntry('/queue', 'Verification queue', Icons.fact_check_outlined, Permission.viewQueue),
  NavEntry('/moderation', 'Review moderation', Icons.rate_review_outlined, Permission.viewQueue),
  NavEntry('/accounts', 'Suspension & reinstatement', Icons.gpp_maybe_outlined, Permission.viewQueue),
  NavEntry('/invitations', 'Provider invitations', Icons.mail_outline, Permission.invite),
  NavEntry('/ads', 'Ad banners', Icons.campaign_outlined, Permission.manageAds),
  NavEntry('/audit', 'Audit log', Icons.receipt_long_outlined, Permission.viewAudit),
  NavEntry('/admins', 'Admin users', Icons.admin_panel_settings_outlined, Permission.manageAdmins),
  NavEntry('/roles', 'Roles & permissions', Icons.policy_outlined),
];

/// Desktop-first frame: a fixed sidebar on wide screens, a drawer on narrow ones. Only sections the
/// role may use are listed; the service still refuses anything else.
class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(adminAuthProvider);
    final user = auth.user;
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final location = GoRouterState.of(context).uri.path;
    final entries = navEntries.where((e) => e.permission == null || auth.can(e.permission!)).toList();
    final nav = _Sidebar(entries: entries, location: location, user: user, closeOnTap: !wide);
    final c = AdminColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: c.sidebar,
              foregroundColor: Colors.white,
              title: const Text('AQARATI Admin'),
            ),
      drawer: wide ? null : Drawer(backgroundColor: c.sidebar, child: nav),
      body: Row(children: [
        if (wide) SizedBox(width: 272, child: nav),
        Expanded(child: child),
      ]),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final List<NavEntry> entries;
  final String location;
  final AdminUser? user;
  final bool closeOnTap;
  const _Sidebar({required this.entries, required this.location, required this.user, required this.closeOnTap});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AdminColors.of(context);
    const fg = Color(0xFFF1E8DB);
    return Container(
      color: c.sidebar,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AdminSpace.x5, AdminSpace.x6, AdminSpace.x5, AdminSpace.x2),
            child: Row(children: [
              SvgPicture.asset('assets/logo/aqarati_logo_mark.svg', width: 34, colorFilter: const ColorFilter.mode(Color(0xFFD1A47F), BlendMode.srcIn)),
              const SizedBox(width: AdminSpace.x3),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('AQARATI', style: adminDisplay(context, size: 20, color: fg)), Text('Admin Web Console', style: adminText(context, size: 11, color: fg.withValues(alpha: 0.7)))])),
            ]),
          ),
          const SizedBox(height: AdminSpace.x4),
          Expanded(
            child: ListView(children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AdminSpace.x3, vertical: 2),
                  child: Material(
                    color: location.startsWith(e.path) ? const Color(0x33D1A47F) : Colors.transparent,
                    borderRadius: BorderRadius.circular(AdminSpace.radiusSmall),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AdminSpace.radiusSmall),
                      onTap: () {
                        if (closeOnTap) Navigator.of(context).maybePop();
                        context.go(e.path);
                      },
                      child: Semantics(
                        selected: location.startsWith(e.path),
                        button: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AdminSpace.x3, vertical: 11),
                          child: Row(children: [Icon(e.icon, size: 19, color: fg), const SizedBox(width: AdminSpace.x3), Expanded(child: Text(e.label, style: adminText(context, color: fg, weight: location.startsWith(e.path) ? FontWeight.w700 : FontWeight.w500)))]),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(AdminSpace.x4),
              child: Container(
                padding: const EdgeInsets.all(AdminSpace.x3),
                decoration: BoxDecoration(color: const Color(0x1AF1E8DB), borderRadius: BorderRadius.circular(AdminSpace.radiusSmall)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user!.name, style: adminText(context, color: fg, weight: FontWeight.w700)),
                  Text('${roleLabel(user!.role)} · ${user!.email}', style: adminText(context, size: 12, color: fg.withValues(alpha: 0.75))),
                  const SizedBox(height: AdminSpace.x2),
                  Row(children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: fg),
                      onPressed: () async {
                        await ref.read(adminAuthProvider).signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('Sign out'),
                    ),
                  ]),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
