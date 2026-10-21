import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../ui/admin_kit.dart';

// ----------------------------------------------------------------- suspension

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});
  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  String _q = '';

  Future<void> _suspend(CustomerAccount a) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Suspend ${a.name}?', style: adminDisplay(ctx, size: 22)),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Suspension hides the business, its listings, projects, banners and profile; cancels future viewings and bookings with notice to the other party; freezes reviews; and signs the account out everywhere.', style: adminText(ctx, soft: true)),
            const SizedBox(height: AdminSpace.x4),
            TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason (recorded in the audit log)', helperText: 'No ID or document numbers.')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AdminColors.of(ctx).danger), onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: const Text('Suspend')),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null || !mounted) return;
    await runAdmin(context, ref, () => ref.read(adminApiProvider).suspend(a.id, reason), success: 'Account suspended.');
  }

  Future<void> _reinstate(CustomerAccount a) async {
    final ok = await confirmAdmin(context, title: 'Reinstate ${a.name}?', body: 'Content returns to approved without a new review unless the suspension reason requires one. Cancelled viewings and bookings are not restored; customers rebook.', confirm: 'Reinstate');
    if (ok && mounted) await runAdmin(context, ref, () => ref.read(adminApiProvider).reinstate(a.id), success: 'Account reinstated.');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(adminAuthProvider);
    final async = ref.watch(accountsProvider);
    return AdminPage(
      title: 'Suspension & reinstatement',
      subtitle: 'Senior Reviewers and Super Admins can suspend or reinstate. Both need a fresh authenticator code.',
      children: [
        SizedBox(width: 320, child: TextField(decoration: const InputDecoration(labelText: 'Search accounts', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _q = v.trim().toLowerCase()))),
        const SizedBox(height: AdminSpace.x4),
        AdminAsync<List<CustomerAccount>>(
          value: async,
          what: 'accounts',
          onRetry: () => ref.invalidate(accountsProvider),
          data: (list) {
            final shown = list.where((a) => _q.isEmpty || a.name.toLowerCase().contains(_q) || a.kind.toLowerCase().contains(_q)).toList();
            if (shown.isEmpty) return const AdminEmpty(title: 'No accounts match', body: 'Try another search.');
            return AdminCard(children: [
              for (final a in shown)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(a.name),
                  subtitle: Text([a.kind, if (a.suspensionReason != null) 'Reason: ${a.suspensionReason}'].join(' · ')),
                  trailing: Wrap(spacing: AdminSpace.x2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    AdminChip(a.status == AccountStatus.active ? 'Active' : 'Suspended', tone: a.status == AccountStatus.active ? Tone.success : Tone.danger),
                    if (auth.can(Permission.suspend))
                      a.status == AccountStatus.active
                          ? OutlinedButton(onPressed: () => _suspend(a), child: const Text('Suspend'))
                          : OutlinedButton(onPressed: () => _reinstate(a), child: const Text('Reinstate')),
                  ]),
                ),
              if (!auth.can(Permission.suspend)) Text('Your role can view accounts but cannot suspend or reinstate.', style: adminText(context, size: 12, soft: true)),
            ]);
          },
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- invitations

class InvitationsScreen extends ConsumerStatefulWidget {
  const InvitationsScreen({super.key});
  @override
  ConsumerState<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends ConsumerState<InvitationsScreen> {
  final _company = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _company.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(adminAuthProvider);
    if (!auth.can(Permission.invite)) return const AdminPage(title: 'Provider invitations', children: [AdminForbiddenPanel(what: 'provider invitations')]);
    final async = ref.watch(invitationsProvider);
    Tone tone(InvitationStatus s) => switch (s) {
          InvitationStatus.sent => Tone.pending,
          InvitationStatus.accepted => Tone.success,
          InvitationStatus.expired => Tone.neutral,
          InvitationStatus.revoked => Tone.danger,
        };
    return AdminPage(
      title: 'Provider invitations',
      subtitle: 'Maintenance providers join by invitation only. The business accepts a one-time link, creates its credentials and goes through the same verification queue.',
      children: [
        AdminCard(title: 'Invite a maintenance provider', children: [
          Wrap(spacing: AdminSpace.x3, runSpacing: AdminSpace.x3, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 280, child: TextField(controller: _company, decoration: const InputDecoration(labelText: 'Company name'))),
            SizedBox(width: 280, child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Business email'))),
            FilledButton(
              onPressed: () async {
                final r = await runAdmin(context, ref, () => ref.read(adminApiProvider).invite(_company.text, _email.text), success: 'Invitation created (demo: no email is sent).');
                if (r != null) {
                  _company.clear();
                  _email.clear();
                }
              },
              child: const Text('Create invitation'),
            ),
          ]),
          const SizedBox(height: AdminSpace.x2),
          Text('Links are valid for 7 days (DERIVED; the expiry period is not fixed in the architecture). Demo customer-app link: /invite/demo-invite', style: adminText(context, size: 12, soft: true)),
        ]),
        AdminAsync<List<ProviderInvite>>(
          value: async,
          what: 'invitations',
          onRetry: () => ref.invalidate(invitationsProvider),
          data: (list) => list.isEmpty
              ? const AdminEmpty(title: 'No invitations yet', body: 'Invitations you create appear here with their status.')
              : AdminCard(children: [
                  for (final i in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i.companyName),
                      subtitle: Text('${i.email} · created ${fmtTime(i.createdAt)} by ${i.createdBy} · expires ${fmtTime(i.expiresAt)}'),
                      trailing: Wrap(spacing: AdminSpace.x2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        AdminChip(i.status.name, tone: tone(i.status)),
                        if (i.status == InvitationStatus.sent)
                          OutlinedButton(
                            onPressed: () async {
                              final ok = await confirmAdmin(context, title: 'Revoke this invitation?', body: 'The link stops working straight away.', confirm: 'Revoke', destructive: true);
                              if (ok && context.mounted) await runAdmin(context, ref, () => ref.read(adminApiProvider).revokeInvitation(i.id), success: 'Invitation revoked.');
                            },
                            child: const Text('Revoke'),
                          ),
                      ]),
                    ),
                ]),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- moderation

class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});
  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  bool _openOnly = true;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(adminAuthProvider);
    final async = ref.watch(moderationProvider);
    final c = AdminColors.of(context);
    String kind(ModerationKind k) => switch (k) {
          ModerationKind.newReview => 'New review',
          ModerationKind.editedReview => 'Edited review',
          ModerationKind.reported => 'Reported review',
        };
    Tone tone(ModerationStatus s) => switch (s) {
          ModerationStatus.pendingModeration => Tone.pending,
          ModerationStatus.underReview => Tone.warning,
          ModerationStatus.published => Tone.success,
          ModerationStatus.removed || ModerationStatus.rejected => Tone.danger,
        };
    return AdminPage(
      title: 'Review moderation',
      subtitle: 'Every new or edited review is published only after approval. Reported reviews are hidden while they are checked again.',
      actions: [FilterChip(label: const Text('Open only'), selected: _openOnly, onSelected: (v) => setState(() => _openOnly = v))],
      children: [
        AdminAsync<List<ModerationItem>>(
          value: async,
          what: 'the moderation queue',
          onRetry: () => ref.invalidate(moderationProvider),
          data: (list) {
            final shown = list.where((m) => !_openOnly || m.status == ModerationStatus.pendingModeration || m.status == ModerationStatus.underReview).toList();
            if (shown.isEmpty) return const AdminEmpty(title: 'Nothing waiting', body: 'All reviews have been moderated.');
            return Column(children: [
              for (final m in shown)
                AdminCard(
                  title: '${kind(m.kind)} · ${m.targetName}',
                  trailing: AdminChip(m.status.name, tone: tone(m.status)),
                  children: [
                    Text('${m.targetType} · ${'★' * m.stars}${'☆' * (5 - m.stars)} · ${fmtTime(m.submittedAt)}', style: adminText(context, size: 12, soft: true)),
                    const SizedBox(height: AdminSpace.x2),
                    Text(m.comment, style: adminText(context)),
                    if (m.reportReason != null) Padding(padding: const EdgeInsets.only(top: AdminSpace.x2), child: Text('Report: ${m.reportReason}', style: adminText(context, color: c.warning))),
                    if (m.decidedBy != null) Padding(padding: const EdgeInsets.only(top: AdminSpace.x2), child: Text('Decided by ${m.decidedBy}', style: adminText(context, size: 12, soft: true))),
                    const SizedBox(height: AdminSpace.x3),
                    if (auth.can(Permission.moderateReviews))
                      Wrap(spacing: AdminSpace.x2, children: [
                        if (m.status == ModerationStatus.pendingModeration) ...[
                          FilledButton(onPressed: () => runAdmin(context, ref, () => ref.read(adminApiProvider).moderate(m.id, ModerationStatus.published), success: 'Review published.'), child: const Text('Publish')),
                          OutlinedButton(onPressed: () => runAdmin(context, ref, () => ref.read(adminApiProvider).moderate(m.id, ModerationStatus.rejected), success: 'Review not published.'), child: const Text('Do not publish')),
                        ],
                        if (m.status == ModerationStatus.underReview) ...[
                          FilledButton(onPressed: () => runAdmin(context, ref, () => ref.read(adminApiProvider).moderate(m.id, ModerationStatus.published), success: 'Review restored.'), child: const Text('Keep published')),
                          OutlinedButton(
                            onPressed: () async {
                              final ok = await confirmAdmin(context, title: 'Remove this review?', body: 'It disappears from the profile and the rating is recalculated.', confirm: 'Remove', destructive: true);
                              if (ok && context.mounted) await runAdmin(context, ref, () => ref.read(adminApiProvider).moderate(m.id, ModerationStatus.removed), success: 'Review removed.');
                            },
                            child: const Text('Remove'),
                          ),
                        ],
                      ])
                    else
                      Text('Your role is read-only here.', style: adminText(context, size: 12, soft: true)),
                  ],
                ),
            ]);
          },
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- ads

class AdsScreen extends ConsumerStatefulWidget {
  const AdsScreen({super.key});
  @override
  ConsumerState<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends ConsumerState<AdsScreen> {
  final _title = TextEditingController();
  final _advertiser = TextEditingController();
  final _link = TextEditingController(text: 'https://');
  AdPlacement _placement = AdPlacement.homeTop;
  DateTimeRange? _range;

  @override
  void dispose() {
    _title.dispose();
    _advertiser.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(adminAuthProvider);
    if (!auth.can(Permission.manageAds)) return const AdminPage(title: 'Ad banners', children: [AdminForbiddenPanel(what: 'ad banner management')]);
    final async = ref.watch(adsProvider);
    Tone tone(AdStatus s) => switch (s) {
          AdStatus.inReview => Tone.pending,
          AdStatus.scheduled || AdStatus.live => Tone.success,
          AdStatus.paused => Tone.warning,
          AdStatus.rejected => Tone.danger,
          AdStatus.ended => Tone.neutral,
        };
    return AdminPage(
      title: 'Ad banners',
      subtitle: 'Direct-sold sponsored banners only. Every banner passes the verification queue before it can serve and is always labelled "Sponsored". Billing is offline.',
      children: [
        AdminCard(title: 'New banner', children: [
          Wrap(spacing: AdminSpace.x3, runSpacing: AdminSpace.x3, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 260, child: TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title'))),
            SizedBox(width: 260, child: TextField(controller: _advertiser, decoration: const InputDecoration(labelText: 'Advertiser'))),
            SizedBox(width: 260, child: TextField(controller: _link, decoration: const InputDecoration(labelText: 'Target link'))),
            DropdownButton<AdPlacement>(value: _placement, items: const [DropdownMenuItem(value: AdPlacement.homeTop, child: Text('Home top')), DropdownMenuItem(value: AdPlacement.resultsInFeed, child: Text('In-feed on results'))], onChanged: (v) => setState(() => _placement = v ?? _placement)),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final r = await showDateRangePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)));
                if (r != null) setState(() => _range = r);
              },
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(_range == null ? 'Choose dates' : '${fmtTime(_range!.start).split(',').first} – ${fmtTime(_range!.end).split(',').first}'),
            ),
            FilledButton(
              onPressed: _range == null
                  ? null
                  : () async {
                      final r = await runAdmin(context, ref, () => ref.read(adminApiProvider).createAd(title: _title.text, advertiser: _advertiser.text, link: _link.text, placement: _placement, starts: _range!.start, ends: _range!.end), success: 'Banner sent to the verification queue.');
                      if (r != null) {
                        _title.clear();
                        _advertiser.clear();
                        setState(() => _range = null);
                      }
                    },
              child: const Text('Submit for review'),
            ),
          ]),
          const SizedBox(height: AdminSpace.x2),
          Text('Creative upload needs the media API; this demo records the banner details only. Signup, verification, document, account and admin screens never show ads.', style: adminText(context, size: 12, soft: true)),
        ]),
        AdminAsync<List<AdBanner>>(
          value: async,
          what: 'ad banners',
          onRetry: () => ref.invalidate(adsProvider),
          data: (list) => list.isEmpty
              ? const AdminEmpty(title: 'No banners yet', body: 'Create a banner above.')
              : AdminCard(children: [
                  for (final a in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(a.title),
                      subtitle: Text('${a.advertiser} · ${a.placement == AdPlacement.homeTop ? 'Home top' : 'In-feed'} · ${fmtTime(a.starts)} – ${fmtTime(a.ends)}'),
                      trailing: Wrap(spacing: AdminSpace.x2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        AdminChip(a.status.name, tone: tone(a.status)),
                        if (a.status == AdStatus.scheduled || a.status == AdStatus.live) OutlinedButton(onPressed: () => runAdmin(context, ref, () => ref.read(adminApiProvider).setAdPaused(a.id, true), success: 'Banner paused.'), child: const Text('Pause')),
                        if (a.status == AdStatus.paused) OutlinedButton(onPressed: () => runAdmin(context, ref, () => ref.read(adminApiProvider).setAdPaused(a.id, false), success: 'Banner resumed.'), child: const Text('Resume')),
                      ]),
                    ),
                ]),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- audit

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});
  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(adminAuthProvider);
    if (!auth.can(Permission.viewAudit)) return const AdminPage(title: 'Audit log', children: [AdminForbiddenPanel(what: 'the audit log')]);
    final async = ref.watch(auditProvider);
    return AdminPage(
      title: 'Audit log',
      subtitle: 'Append-only. Nobody can edit or delete entries, including Super Admins. Admin events keep the IP; values never include sensitive data.',
      actions: [OutlinedButton.icon(onPressed: () => ref.invalidate(auditProvider), icon: const Icon(Icons.refresh, size: 18), label: const Text('Refresh'))],
      children: [
        SizedBox(width: 340, child: TextField(decoration: const InputDecoration(labelText: 'Filter by action, actor or record', prefixIcon: Icon(Icons.filter_list)), onChanged: (v) => setState(() => _q = v.trim().toLowerCase()))),
        const SizedBox(height: AdminSpace.x4),
        AdminAsync<List<AuditEvent>>(
          value: async,
          what: 'the audit log',
          onRetry: () => ref.invalidate(auditProvider),
          data: (list) {
            final shown = list.where((e) => _q.isEmpty || '${e.action} ${e.actorLabel} ${e.entity} ${e.entityId}'.toLowerCase().contains(_q)).toList();
            if (shown.isEmpty) return const AdminEmpty(title: 'No entries match', body: 'Change the filter.');
            return AdminCard(children: [
              for (final e in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: AdminSpace.x3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 60, child: Text('#${e.id}', style: adminText(context, size: 12, soft: true))),
                    SizedBox(width: 160, child: Text(fmtTime(e.at), style: adminText(context, size: 12, soft: true))),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.action, style: adminText(context, weight: FontWeight.w700)),
                        Text('${e.actorLabel} (${e.actorType}) · ${e.entity}/${e.entityId}${e.before != null ? ' · ${e.before} → ${e.after}' : ''}${e.reason != null ? ' · ${e.reason}' : ''}${e.ip != null ? ' · ${e.ip}' : ''}', style: adminText(context, size: 12, soft: true)),
                      ]),
                    ),
                  ]),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- admin users

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  AdminRole _role = AdminRole.reviewer;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(adminAuthProvider);
    if (!auth.can(Permission.manageAdmins)) return const AdminPage(title: 'Admin users', children: [AdminForbiddenPanel(what: 'admin user management')]);
    final async = ref.watch(adminsProvider);
    return AdminPage(
      title: 'Admin users',
      subtitle: 'Staff accounts are separate from customer accounts and always use TOTP. Remove access the same day someone leaves; past decisions stay attributable.',
      children: [
        AdminCard(title: 'Add an admin', children: [
          Wrap(spacing: AdminSpace.x3, runSpacing: AdminSpace.x3, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 240, child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name'))),
            SizedBox(width: 260, child: TextField(controller: _email, decoration: const InputDecoration(labelText: 'Staff email'))),
            DropdownButton<AdminRole>(value: _role, items: [for (final r in AdminRole.values) DropdownMenuItem(value: r, child: Text(roleLabel(r)))], onChanged: (v) => setState(() => _role = v ?? _role)),
            FilledButton(
              onPressed: () async {
                final r = await runAdmin(context, ref, () => ref.read(adminApiProvider).createAdmin(_name.text, _email.text, _role), success: 'Admin created (demo: TOTP enrolment happens at first sign-in).');
                if (r != null) {
                  _name.clear();
                  _email.clear();
                }
              },
              child: const Text('Create'),
            ),
          ]),
        ]),
        AdminAsync<List<AdminUser>>(
          value: async,
          what: 'admin users',
          onRetry: () => ref.invalidate(adminsProvider),
          data: (list) => AdminCard(children: [
            for (final a in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(a.name),
                subtitle: Text(a.email),
                trailing: Wrap(spacing: AdminSpace.x2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  DropdownButton<AdminRole>(
                    value: a.role,
                    items: [for (final r in AdminRole.values) DropdownMenuItem(value: r, child: Text(roleLabel(r)))],
                    onChanged: a.id == auth.user?.id ? null : (r) => r == null ? null : runAdmin(context, ref, () => ref.read(adminApiProvider).updateAdmin(a.id, role: r), success: 'Role changed.'),
                  ),
                  AdminChip(a.active ? 'Active' : 'Disabled', tone: a.active ? Tone.success : Tone.neutral),
                  if (a.id != auth.user?.id)
                    OutlinedButton(
                      onPressed: () async {
                        final ok = await confirmAdmin(context, title: a.active ? 'Disable ${a.name}?' : 'Enable ${a.name}?', body: a.active ? 'They lose console access immediately. Their past decisions remain in the audit log.' : 'They can sign in again with their password and authenticator.', confirm: a.active ? 'Disable' : 'Enable', destructive: a.active);
                        if (ok && context.mounted) await runAdmin(context, ref, () => ref.read(adminApiProvider).updateAdmin(a.id, active: !a.active), success: a.active ? 'Admin disabled.' : 'Admin enabled.');
                      },
                      child: Text(a.active ? 'Disable' : 'Enable'),
                    ),
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- roles & configuration

class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AdminColors.of(context);
    String perm(Permission p) => switch (p) {
          Permission.viewQueue => 'View queue and submissions',
          Permission.openDocuments => 'Open documents (streamed)',
          Permission.decide => 'Approve / reject / request resubmission',
          Permission.secondApproval => 'Final (second) approval for developers',
          Permission.overrideDecision => 'Override or reopen a decision',
          Permission.suspend => 'Suspend / reinstate',
          Permission.invite => 'Invite maintenance providers',
          Permission.createBrokerGrant => 'Create Aqarati Broker grants',
          Permission.manageAdmins => 'Create and manage admin users',
          Permission.viewAudit => 'View audit log',
          Permission.moderateReviews => 'Moderate reviews (DERIVED)',
          Permission.manageAds => 'Manage ad banners (DERIVED)',
          Permission.viewConfig => 'Configuration: reason codes, templates, checklists',
        };
    return AdminPage(
      title: 'Roles & permissions',
      subtitle: 'The admin RBAC matrix (architecture section 47). Every permission is enforced by the API; this console only reflects it.',
      children: [
        AdminCard(children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [const DataColumn(label: Text('Permission')), for (final r in AdminRole.values) DataColumn(label: Text(roleLabel(r)))],
              rows: [
                for (final p in Permission.values)
                  DataRow(cells: [
                    DataCell(Text(perm(p))),
                    for (final r in AdminRole.values) DataCell(Icon(can(r, p) ? Icons.check_circle : Icons.remove, size: 18, color: can(r, p) ? c.success : c.inkFaint, semanticLabel: can(r, p) ? 'Allowed' : 'Not allowed')),
                  ]),
              ],
            ),
          ),
        ]),
        AdminCard(title: 'Reason codes (closed list of 12)', children: [
          Wrap(spacing: AdminSpace.x2, runSpacing: AdminSpace.x2, children: [for (final r in ReasonCode.values) AdminChip(r.api)]),
          const SizedBox(height: AdminSpace.x2),
          Text('Each code maps to one Arabic and one English message for the applicant. Editing codes and templates needs the configuration API (Super Admin); it is read-only here.', style: adminText(context, size: 12, soft: true)),
        ]),
        AdminCard(title: 'Reviewer checklists', children: [
          for (final e in checklists.entries) ...[
            Text(entityLabel(e.key), style: adminText(context, weight: FontWeight.w700)),
            Padding(padding: const EdgeInsets.only(bottom: AdminSpace.x3), child: Text(e.value.join(' · '), style: adminText(context, size: 13, soft: true))),
          ],
        ]),
      ],
    );
  }
}
