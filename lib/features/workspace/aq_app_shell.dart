import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/aq/aq_demo.dart';
import '../../core/aq/aq_documents.dart';
import '../../core/aq/aq_kit.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/config/backend_mode.dart';
import '../../core/domain/account_models.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart';
import '../devbuild/db_models.dart' show proTypeOfPurpose;
import '../flow/screens/approval_screens.dart' show workspaceCaps;
import '../flow/widgets/flow_common.dart';
import '../account/account_screens.dart' show AQAccountHeader, aqSignOut;
import '../notifications/notifications.dart';
import 'aq_explore.dart';
import '../role_home/role_home_screen.dart';

const _tabs = ['/app/home', '/app/explore', '/app/activity', '/app/account'];

/// Authenticated shell: quiet backdrop, the page, and the floating glass nav.
/// Only this shell hosts [AQGlassNav].
class AQAppShell extends StatefulWidget {
  final Widget child;
  const AQAppShell({super.key, required this.child});
  @override
  State<AQAppShell> createState() => _AQAppShellState();
}

class _AQAppShellState extends State<AQAppShell> {
  final _nav = AQNavController();

  @override
  void dispose() {
    _nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final location = GoRouterState.of(context).uri.path;
    final index = _tabs.indexWhere(location.startsWith).clamp(0, _tabs.length - 1);
    final items = [
      AQNavItem('home', f.t('nav.home')),
      AQNavItem('explore', f.t('nav.explore')),
      AQNavItem('activity', f.t('nav.activity')),
      AQNavItem('account', f.t('nav.account')),
    ];
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(fit: StackFit.expand, children: [
        const AQBackdrop(asset: 'assets/entry/oman_terrace_2k.jpg', quiet: true),
        NotificationListener<ScrollNotification>(onNotification: _nav.onScroll, child: widget.child),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AQGlassNav(
            items: items,
            index: index,
            controller: _nav,
            onSelected: (i) {
              _nav.setCompact(false);
              // Tapping the tab you are already on returns to that tab's first page (e.g. out of a workspace or directory page).
              if (i != index || location != _tabs[i]) context.go(_tabs[i]);
            },
          ),
        ),
      ]),
    );
  }
}

/// Shared page frame for the tabs: title, scrolling body, room for the nav.
class _TabPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _TabPage({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x6, AQSpacing.gutter, 128),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(title, style: AQTypography.of(context, AQText.displaySmall))),
              const SizedBox(height: AQSpacing.x6),
              ...children,
            ]),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: AQTypography.of(context, AQText.bodyMedium, soft: true));
}

/// Role and verification cards for a signed-in session.
List<Widget> _sessionSections(BuildContext context, MeSession m) {
  final f = FlowStrings.of(context);
  final cfg = m.purpose == null ? null : roleConfigs[m.purpose];
  final business = cfg != null && cfg.needsDocuments && m.grant != null;
  return [
    if (business)
      AQReviewSection(title: f.t('home.verification'), children: [
        const SizedBox(height: AQSpacing.x2),
        Align(alignment: AlignmentDirectional.centerStart, child: AQStatusBadge(grant: m.grant!, stage: m.stage)),
        const SizedBox(height: AQSpacing.x2),
        if (m.grant == GrantState.approved) _Body(f.t('home.verified')),
        AQTextButton(label: f.t('home.viewStatus'), trailingIcon: 'chevron-right', onPressed: () => context.go('/verification')),
      ]),
    if (business && m.grant == GrantState.approved && m.purpose != null)
      AQReviewSection(title: f.t('home.workspace'), children: [
        Padding(padding: const EdgeInsets.only(top: AQSpacing.x2, bottom: AQSpacing.x1), child: Text(f.t('ws.t.${m.purpose!.name}'), style: AQTypography.of(context, AQText.titleSmall))),
        for (final k in workspaceCaps(m.purpose!)) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(f.t(k), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
        if (proTypeOfPurpose(m.purpose) != null) Padding(padding: const EdgeInsets.only(top: AQSpacing.x3), child: AQPrimaryButton(label: f.t('db.ws.open'), trailingChevron: false, onPressed: () => context.push('/app/account/workspace'))),
      ]),
  ];
}

Widget _guestCard(BuildContext context) {
  final f = FlowStrings.of(context);
  return AQReviewSection(title: f.t('guest.title'), children: [
    const SizedBox(height: AQSpacing.x2),
    _Body(f.t('guest.body')),
    const SizedBox(height: AQSpacing.x4),
    AQPrimaryButton(label: f.t('guest.create'), onPressed: () => context.push('/onboarding/purpose')),
    const SizedBox(height: AQSpacing.x2),
    AQSecondaryButton(label: f.t('guest.login'), trailingChevron: false, onPressed: () => context.push('/login')),
    const SizedBox(height: AQSpacing.x1),
  ]);
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) => const RoleHomeScreen();
}

class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});
  @override
  Widget build(BuildContext context) => const AQExploreScreen();
}

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final me = ref.watch(meProvider);
    final m = me.valueOrNull;
    final c = AQColors.of(context);
    final business = m?.purpose != null && (roleConfigs[m!.purpose]?.needsDocuments ?? false);
    final unread = m == null ? 0 : ref.watch(unreadNotificationsProvider);
    return _TabPage(title: f.t('account.title'), children: [
      const AQDemoNotice(),
      if (kUseDemoBackend) const SizedBox(height: AQSpacing.x4),
      if (me.isLoading && m == null) const AQSkeleton(),
      if (m == null && me.hasError) _guestCard(context),
      if (m != null) AQAccountHeader(me: m),
      if (m != null) ..._sessionSections(context, m),
      if (m != null)
        AQRowGroup(title: f.t('acc.g.account'), rows: [
          AQListRow(icon: 'user', title: f.t('acc.profile'), subtitle: f.t('acc.profile.sub'), onTap: () => context.push('/account/profile')),
          if (business) AQListRow(icon: 'development', title: f.t('acc.org'), subtitle: f.t('acc.org.sub'), onTap: () => context.push('/account/organisation')),
          if (m.providerGrant != null) AQListRow(icon: 'construction', title: f.t('acc.provider'), subtitle: f.t('acc.provider.sub'), onTap: () => context.push('/provider')),
        ]),
      AQRowGroup(title: f.t('acc.g.activity'), rows: [
        if (m != null) AQListRow(icon: 'activity', title: f.t('ntf.row'), subtitle: f.t('acc.notifications.sub'), trailing: unread > 0 ? f.t('ntf.unread', {'n': '$unread'}) : null, onTap: () => context.push('/notifications')),
        AQListRow(icon: 'star', title: f.t('account.saved'), subtitle: f.t('acc.saved.sub'), onTap: () => context.push('/saved')),
        if (m != null) AQListRow(icon: 'home', title: f.t('acc.listings'), subtitle: f.t('acc.listings.sub'), onTap: () => context.push('/listings')),
        AQListRow(icon: 'plus', title: f.t('acc.sell'), subtitle: f.t('acc.sell.sub'), onTap: () => context.push('/sell')),
        if (m != null) AQListRow(icon: 'agent', title: f.t('acc.engagements'), subtitle: f.t('acc.engagements.sub'), onTap: () => context.push('/engagements')),
        if (m != null) AQListRow(icon: 'star-fill', title: f.t('acc.reviews'), subtitle: f.t('acc.reviews.sub'), onTap: () => context.push('/reviews/mine')),
        AQListRow(icon: 'calendar', title: f.t('account.tools'), subtitle: f.t('acc.tools.sub'), onTap: () => context.push('/calculators')),
      ]),
      AQRowGroup(title: f.t('acc.g.preferences'), rows: [
        AQListRow(icon: 'sun', title: f.t('acc.settings'), subtitle: f.t('acc.settings.sub'), onTap: () => context.push('/account/settings')),
      ]),
      AQRowGroup(title: f.t('acc.g.support'), rows: [
        AQListRow(icon: 'info', title: f.t('acc.help'), subtitle: f.t('acc.help.sub'), onTap: () => context.push('/help')),
        AQListRow(icon: 'shield', title: f.t('acc.legal'), subtitle: f.t('acc.legal.sub'), onTap: () => context.push('/account/privacy')),
      ]),
      if (m != null) AQSecondaryButton(label: f.t('account.signOut'), trailingChevron: false, onPressed: () => aqSignOut(context, ref)),
      if (m != null) ...[
        const SizedBox(height: AQSpacing.x3),
        Center(child: AQTextButton(label: f.t('del.row'), color: c.danger, onPressed: () => context.push('/account/delete'))),
      ],
    ]);
  }
}
