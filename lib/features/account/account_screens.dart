import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_demo.dart';
import '../../core/aq/aq_documents.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_kit.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/config/app_version.dart';
import '../../core/config/backend_mode.dart';
import '../../core/domain/account_models.dart';
import '../../core/localization/entry_strings.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart';
import '../devbuild/db_repository.dart' show dbMyOrgProvider;
import '../entry/models/signup_purpose.dart';
import '../flow/widgets/flow_common.dart' show roleTitle;
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';

/// Signs out after an explicit confirmation, clears the session caches and returns to the start.
Future<void> aqSignOut(BuildContext context, WidgetRef ref) async {
  final f = FlowStrings.of(context);
  final ok = await aqConfirm(context, title: f.t('acc.signOut.t'), body: f.t('acc.signOut.b'), confirmLabel: f.t('account.signOut'));
  if (!ok) return;
  await ref.read(authRepositoryProvider).signOut();
  ref.invalidate(meProvider);
  ref.invalidate(verificationProvider);
  if (context.mounted) context.go('/entry');
}

String _initials(MeSession m) {
  final parts = [m.firstName, m.lastName].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
  if (parts.isEmpty) return '';
  return parts.map((p) => p.trim()[0].toUpperCase()).join();
}

/// Avatar + name + role, used at the top of the Account tab and the profile page.
class AQAccountHeader extends StatelessWidget {
  final MeSession me;
  const AQAccountHeader({super.key, required this.me});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final name = me.displayName.isEmpty ? f.t('acc.guestName') : me.displayName;
    final initials = _initials(me);
    return Container(
      padding: const EdgeInsets.all(AQSpacing.x4),
      margin: const EdgeInsets.only(bottom: AQSpacing.x4),
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.large), border: Border.all(color: c.hairline)),
      child: Row(children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: c.accent.withValues(alpha: 0.16),
          child: initials.isEmpty ? AQIcon('user', size: 26, color: c.accentDeep) : Text(initials, style: AQTypography.of(context, AQText.titleLarge, color: c.accentDeep)),
        ),
        const SizedBox(width: AQSpacing.x4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(VFmt.iso(name), style: AQTypography.of(context, AQText.headlineSmall)),
            if (me.email != null) Text(me.email!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
            const SizedBox(height: AQSpacing.x2),
            Wrap(spacing: AQSpacing.x2, runSpacing: 4, children: [
              if (me.purpose != null) AQStatusPill(roleTitle(context, me.purpose!), icon: 'user'),
              if (me.grant == GrantState.approved) AQStatusPill(f.t('acc.status.verified'), tone: AQPillTone.success, icon: 'verified'),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ personal profile

class PersonalProfileScreen extends ConsumerWidget {
  const PersonalProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final me = ref.watch(meProvider);
    void back() => aqBack(context, '/app/account');
    final m = me.valueOrNull;
    if (me.isLoading && m == null) return AQPlainPage(title: f.t('pf.title'), onBack: back, children: const [AQSkeletonRows(count: 4)]);
    if (m == null) {
      return AQPlainPage(title: f.t('pf.title'), onBack: back, children: [AQEmptyState(icon: 'lock', title: f.t('pf.signedOut.t'), body: f.t('pf.signedOut.b'), action: AQPrimaryButton(label: f.t('guest.login'), onPressed: () => context.push('/login')))]);
    }
    return AQPlainPage(
      title: f.t('pf.title'),
      subtitle: f.t('pf.sub'),
      onBack: back,
      bottom: AQBottomActionBar(primary: AQPrimaryButton(label: f.t('pf.edit'), leadingIcon: 'edit', trailingChevron: false, onPressed: () => context.push('/account/profile/edit'))),
      children: [
        AQAccountHeader(me: m),
        AQReviewSection(title: f.t('pf.title'), children: [
          AQKeyValue(f.t('pf.name'), m.displayName.isEmpty ? f.t('pf.notSet') : VFmt.iso(m.displayName)),
          AQKeyValue(f.t('pf.email'), m.email ?? f.t('pf.notSet')),
          AQKeyValue(f.t('pf.phone'), m.phoneLast4 == null ? f.t('pf.notSet') : '+968 •••• ${m.phoneLast4}'),
          if (m.purpose != null) AQKeyValue(f.t('pf.role'), roleTitle(context, m.purpose!)),
        ]),
        AQInfoCard(icon: 'phone', title: f.t('pf.phone'), body: f.t('pf.phoneNote')),
      ],
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  bool _loaded = false, _busy = false, _tried = false;
  String? _error;
  MeSession? _me;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  bool get _dirty => _me != null && (_first.text.trim() != (_me!.firstName ?? '') || _last.text.trim() != (_me!.lastName ?? ''));

  Future<void> _save() async {
    final f = FlowStrings.of(context);
    setState(() => _tried = true);
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty || _busy) return;
    if (!_dirty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(f.t('pf.edit.nothing'))));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountApiProvider).updateProfile(firstName: _first.text, lastName: _last.text);
      ref.invalidate(meProvider);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(f.t('pf.edit.saved'))));
      _me = null;
      aqBack(context, '/account/profile');
    } catch (_) {
      if (mounted) setState(() => _error = 'pf.edit.err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final f = FlowStrings.of(context);
    if (!_dirty) {
      aqBack(context, '/account/profile');
      return;
    }
    final ok = await aqConfirm(context, title: f.t('pf.edit.leave.t'), body: f.t('pf.edit.leave.b'), confirmLabel: f.t('pf.edit.leave.ok'), cancelLabel: f.t('pf.edit.leave.keep'));
    if (ok && mounted) aqBack(context, '/account/profile');
  }

  Future<void> _changeEmail() async {
    final f = FlowStrings.of(context);
    final ctrl = TextEditingController(text: _me?.email ?? '');
    String? err;
    final sent = await showAQSheet<bool>(
      context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x2),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(f.t('pf.edit.changeEmail'), style: AQTypography.of(ctx, AQText.headlineSmall)),
            const SizedBox(height: AQSpacing.x2),
            Text(f.t('pf.edit.emailNote'), style: AQTypography.of(ctx, AQText.bodyMedium, soft: true)),
            const SizedBox(height: AQSpacing.x4),
            AQTextField(label: f.t('field.email'), controller: ctrl, keyboardType: TextInputType.emailAddress, error: err),
            AQPrimaryButton(
              label: f.t('pf.edit.changeEmail'),
              trailingChevron: false,
              onPressed: () async {
                final v = ctrl.text.trim();
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                  set(() => err = f.t('err.email'));
                  return;
                }
                try {
                  await ref.read(authRepositoryProvider).updateEmail(v);
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (_) {
                  set(() => err = f.t('common.networkError'));
                }
              },
            ),
          ]),
        ),
      ),
    );
    ctrl.dispose();
    if (sent == true && mounted) {
      ref.invalidate(meProvider);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(f.t('pf.edit.emailSent'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final me = ref.watch(meProvider);
    final m = me.valueOrNull;
    if (!_loaded && m != null) {
      _loaded = true;
      _me = m;
      _first.text = m.firstName ?? '';
      _last.text = m.lastName ?? '';
    }
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AQPlainPage(
        title: f.t('pf.edit.title'),
        subtitle: f.t('pf.edit.sub'),
        onBack: _leave,
        bottom: AQBottomActionBar(primary: AQPrimaryButton(label: f.t('pf.edit.save'), loading: _busy, trailingChevron: false, onPressed: m == null ? null : _save)),
        children: [
          if (m == null && me.isLoading) const AQSkeletonRows(count: 3),
          if (m == null && me.hasError) AQRetryPanel(onRetry: () => ref.invalidate(meProvider)),
          if (_error != null) AQErrorBanner(text: f.t(_error!)),
          if (m != null) ...[
            AQTextField(label: f.t('field.firstName'), controller: _first, error: _tried && _first.text.trim().isEmpty ? f.t('common.required') : null, onChanged: (_) => setState(() {})),
            AQTextField(label: f.t('field.lastName'), controller: _last, error: _tried && _last.text.trim().isEmpty ? f.t('common.required') : null, onChanged: (_) => setState(() {})),
            AQInfoCard(icon: 'globe', title: f.t('pf.email'), body: m.email ?? f.t('pf.notSet'), children: [
              Text(f.t('pf.edit.emailNote'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              Align(alignment: AlignmentDirectional.centerEnd, child: AQTextButton(label: f.t('pf.edit.changeEmail'), trailingIcon: 'chevron-right', onPressed: _changeEmail)),
            ]),
            AQInfoCard(icon: 'phone', title: f.t('pf.phone'), body: m.phoneLast4 == null ? f.t('pf.notSet') : '+968 •••• ${m.phoneLast4}', children: [Text(f.t('pf.phoneNote'), style: AQTypography.of(context, AQText.bodySmall, soft: true))]),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ organisation

class OrganisationScreen extends ConsumerWidget {
  const OrganisationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final me = ref.watch(meProvider).valueOrNull;
    void back() => aqBack(context, '/app/account');
    final business = me?.purpose != null && (roleConfigs[me!.purpose]?.needsDocuments ?? false);
    if (me == null || !business) {
      return AQPlainPage(title: f.t('org.title'), onBack: back, children: [AQEmptyState(icon: 'home', title: f.t('org.none.t'), body: f.t('org.none.b'))]);
    }
    final info = ref.watch(verificationProvider);
    final agent = me.purpose == SignupPurpose.realEstateAgent;
    final approved = me.grant == GrantState.approved;
    final org = approved && !agent ? ref.watch(dbMyOrgProvider).valueOrNull : null;
    return AQPlainPage(
      title: f.t('org.title'),
      subtitle: f.t('org.sub'),
      onBack: back,
      children: [
        if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
        if (me.grant == GrantState.suspended) AQErrorBanner(text: f.t('org.suspended')),
        ...info.when(
          loading: () => [const AQSkeletonRows(count: 3)],
          error: (_, _) => [AQRetryPanel(onRetry: () => ref.invalidate(verificationProvider))],
          data: (v) => [
            AQReviewSection(title: f.t('org.title'), children: [
              AQKeyValue(f.t(agent ? 'org.agency' : 'org.name'), v.businessName == null ? f.t('pf.notSet') : VFmt.iso(v.businessName!)),
              AQKeyValue(f.t('org.type'), roleTitle(context, v.purpose)),
              if (v.reference != null) AQKeyValue(f.t('org.ref'), v.reference!),
              const SizedBox(height: AQSpacing.x2),
              Align(alignment: AlignmentDirectional.centerStart, child: AQStatusBadge(grant: v.grant, stage: v.stage)),
              AQTextButton(label: f.t('org.status.view'), trailingIcon: 'chevron-right', color: c.accentDeep, onPressed: () => context.push('/verification')),
            ]),
            AQReviewSection(title: f.t('org.docs'), children: [
              for (final d in v.documents) AQDocumentRow(title: f.t('doc.${d.kind.name}'), status: d),
              Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Text(f.t('org.docsNote'), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
            ]),
          ],
        ),
        if (approved && !agent) ...[
          AQInfoCard(icon: 'edit', title: f.t('org.edit'), body: f.t('org.editNote'), children: [AQSecondaryButton(label: f.t('org.edit'), trailingChevron: false, onPressed: () => context.push('/app/account/workspace/profile'))]),
          AQInfoCard(icon: 'eye', title: f.t('org.public'), body: f.t('org.publicNote'), children: [
            AQSecondaryButton(label: f.t('org.public'), trailingChevron: false, onPressed: org == null ? null : () => context.push('/build/pro/${org.id}')),
          ]),
        ],
        if (agent) AQInfoCard(icon: 'info', title: f.t('org.public'), body: f.t('org.agentPublic')),
        AQInfoCard(icon: 'user', title: f.t('org.members'), body: f.t('org.membersNote')),
      ],
    );
  }
}

// ------------------------------------------------------------------ settings

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final mode = ref.watch(themeModeProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final signedIn = ref.watch(meProvider).hasValue;
    Widget choice(String title, bool selected, VoidCallback onTap, {String icon = 'check'}) => AQListRow(icon: icon, title: title, trailing: selected ? '✓' : null, showChevron: false, onTap: onTap);
    return AQPlainPage(
      title: f.t('set.title'),
      onBack: () => aqBack(context, '/app/account'),
      children: [
        AQRowGroup(title: f.t('set.appearance'), rows: [
          choice(f.t('set.light'), mode == ThemeMode.light, () => ref.read(themeModeProvider.notifier).state = ThemeMode.light, icon: 'sun'),
          choice(f.t('set.dark'), mode == ThemeMode.dark, () => ref.read(themeModeProvider.notifier).state = ThemeMode.dark, icon: 'moon'),
          choice(f.t('set.system'), mode == ThemeMode.system, () => ref.read(themeModeProvider.notifier).state = ThemeMode.system, icon: 'sunrise'),
        ]),
        AQRowGroup(title: f.t('set.language'), rows: [
          choice('English', lang == 'en', () => ref.read(localeProvider.notifier).state = const Locale('en'), icon: 'globe'),
          choice('العربية', lang == 'ar', () => ref.read(localeProvider.notifier).state = const Locale('ar'), icon: 'globe'),
        ]),
        AQRowGroup(rows: [
          AQListRow(icon: 'activity', title: f.t('set.notifications'), subtitle: f.t('set.notifications.sub'), onTap: () => context.push('/account/notification-settings')),
          if (signedIn) AQListRow(icon: 'lock', title: f.t('set.security'), subtitle: f.t('set.security.sub'), onTap: () => context.push('/account/security')),
          AQListRow(icon: 'shield', title: f.t('set.legal'), subtitle: f.t('acc.legal.sub'), onTap: () => context.push('/account/privacy')),
          AQListRow(icon: 'info', title: f.t('acc.help'), subtitle: f.t('acc.help.sub'), onTap: () => context.push('/help')),
        ]),
        AQInfoCard(icon: 'info', title: f.t('set.about'), body: f.t('set.version', {'v': kAppVersion}), children: [Text(f.t('set.motion'), style: AQTypography.of(context, AQText.bodySmall, soft: true))]),
      ],
    );
  }
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    return AQPlainPage(
      title: f.t('ns.title'),
      subtitle: f.t('ns.sub'),
      onBack: () => aqBack(context, '/account/settings'),
      children: [
        AQErrorBanner(tone: AQBannerTone.info, text: f.t('ns.push')),
        AQRowGroup(title: f.t('ns.required'), rows: [
          for (final k in ['verification', 'viewing', 'booking', 'security']) AQListRow(icon: 'check', title: f.t('ns.$k'), trailing: f.t('ns.required')),
        ]),
        AQInfoCard(icon: 'info', title: f.t('ns.optional'), body: f.t('ns.optional.b')),
        AQSecondaryButton(label: f.t('ns.inbox'), trailingChevron: false, onPressed: () => context.push('/notifications')),
      ],
    );
  }
}

class PrivacyLegalScreen extends StatelessWidget {
  const PrivacyLegalScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    return AQPlainPage(
      title: f.t('pl.title'),
      onBack: () => aqBack(context, '/app/account'),
      children: [
        AQRowGroup(rows: [
          AQListRow(icon: 'info', title: f.t('legal.terms'), subtitle: f.t('pl.terms.sub'), onTap: () => context.push('/legal/terms')),
          AQListRow(icon: 'shield', title: f.t('legal.privacy'), subtitle: f.t('pl.privacy.sub'), onTap: () => context.push('/legal/privacy')),
        ]),
        AQInfoCard(icon: 'check', title: f.t('pl.consent'), body: f.t('pl.consent.b')),
        AQInfoCard(icon: 'lock', title: f.t('pl.data'), body: f.t('pl.data.b')),
        Center(child: AQTextButton(label: f.t('pl.delete'), color: c.danger, onPressed: () => context.push('/account/delete'))),
      ],
    );
  }
}

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});
  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  String? _busy;
  String? _error;

  Future<void> _password(String? email) async {
    final f = FlowStrings.of(context);
    if (email == null) return;
    final ok = await aqConfirm(context, title: f.t('sec.password.t'), body: f.t('sec.password.b', {'email': email}), confirmLabel: f.t('sec.password.send'));
    if (!ok || !mounted) return;
    setState(() {
      _busy = 'password';
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(f.t('sec.password.sent'))));
    } catch (_) {
      if (mounted) setState(() => _error = 'sec.err');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _everywhere() async {
    final f = FlowStrings.of(context);
    final ok = await aqConfirm(context, title: f.t('sec.everywhere.t'), body: f.t('sec.everywhere.b'), confirmLabel: f.t('sec.everywhere.ok'), destructive: true);
    if (!ok || !mounted) return;
    setState(() {
      _busy = 'all';
      _error = null;
    });
    try {
      await ref.read(accountApiProvider).signOutEverywhere();
      await ref.read(authRepositoryProvider).signOut();
      ref.invalidate(meProvider);
      ref.invalidate(verificationProvider);
      if (mounted) context.go('/entry');
    } catch (_) {
      if (mounted) setState(() => _error = 'sec.err');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final m = ref.watch(meProvider).valueOrNull;
    return AQPlainPage(
      title: f.t('sec.title'),
      subtitle: f.t('sec.sub'),
      onBack: () => aqBack(context, '/account/settings'),
      children: [
        if (_error != null) AQErrorBanner(text: f.t(_error!)),
        AQRowGroup(rows: [
          AQListRow(icon: 'lock', title: f.t('sec.password'), subtitle: f.t('sec.password.sub'), trailing: _busy == 'password' ? '…' : null, onTap: _busy != null || m?.email == null ? null : () => _password(m!.email)),
          AQListRow(icon: 'alert', color: c.danger, title: f.t('sec.everywhere'), subtitle: f.t('sec.everywhere.sub'), trailing: _busy == 'all' ? '…' : null, onTap: _busy != null || m == null ? null : _everywhere),
        ]),
        AQInfoCard(icon: 'info', title: f.t('sec.devices'), body: f.t('sec.devices.b')),
      ],
    );
  }
}

/// Shown when the server says the session is no longer valid (revoked, expired or suspended).
class SessionExpiredScreen extends ConsumerWidget {
  const SessionExpiredScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    return AQViewingScaffold(
      emotional: true,
      showBack: false,
      title: f.t('se.title'),
      subtitle: f.t('se.sub'),
      hero: Center(child: AQIcon('lock', size: 56, color: AQColors.of(context).accentDeep)),
      bottom: AQBottomActionBar(
        stack: true,
        primary: AQPrimaryButton(label: f.t('se.login'), onPressed: () => context.go('/login')),
        secondary: AQBarSecondaryButton(label: f.t('se.home'), onPressed: () => context.go('/app/home')),
      ),
      children: const [],
    );
  }
}
