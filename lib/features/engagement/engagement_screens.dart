import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_demo.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_kit.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/config/backend_mode.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show ApiException, ApiErrorCode, meProvider;
import '../devbuild/db_models.dart';
import '../devbuild/db_repository.dart' show dbProfessionalProvider;
import '../devbuild/db_widgets.dart' show DbPillRow;
import '../help/help.dart';
import '../listings/listing_widgets.dart' show listingDate;
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import 'engagement_models.dart';
import 'engagement_repository.dart';

AQPillTone engagementTone(EngagementPhase p) => switch (p) {
      EngagementPhase.confirmed => AQPillTone.success,
      EngagementPhase.awaitingProfessional => AQPillTone.pending,
      EngagementPhase.awaitingMe => AQPillTone.warning,
      EngagementPhase.expired || EngagementPhase.cancelled => AQPillTone.neutral,
      EngagementPhase.declined => AQPillTone.danger,
    };

String _reviewPath(ClientEngagement e) => '/reviews/write?kind=professional&id=${Uri.encodeQueryComponent(e.professionalId)}&name=${Uri.encodeQueryComponent(e.professionalName)}';

/// The card a company profile shows to signed-in people: the only way into an engagement.
class EngagementProfileCard extends ConsumerWidget {
  final DbProfessional pro;
  const EngagementProfileCard({super.key, required this.pro});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    return AQInfoCard(
      icon: 'user',
      title: f.t('eng.profile.t', {'name': VFmt.iso(pro.name)}),
      body: f.t('eng.profile.b'),
      children: [
        Row(children: [
          Expanded(child: AQSecondaryButton(label: f.t('eng.profile.cta'), trailingChevron: false, onPressed: () => context.push('/engagements/new?pro=${Uri.encodeQueryComponent(pro.id)}'))),
          const AQHelpButton('engagement'),
        ]),
        const SizedBox(height: AQSpacing.x1),
        AQTextButton(label: f.t('eng.d.review'), color: c.accentDeep, trailingIcon: 'chevron-right', onPressed: () => context.push('/reviews/write?kind=professional&id=${Uri.encodeQueryComponent(pro.id)}&name=${Uri.encodeQueryComponent(pro.name)}')),
      ],
    );
  }
}

/// Explains what an engagement is and sends the request. Separate from viewings and maintenance.
class EngagementRequestScreen extends ConsumerStatefulWidget {
  final String professionalId;
  const EngagementRequestScreen({super.key, required this.professionalId});
  @override
  ConsumerState<EngagementRequestScreen> createState() => _EngagementRequestScreenState();
}

class _EngagementRequestScreenState extends ConsumerState<EngagementRequestScreen> {
  bool _busy = false;
  String? _error;
  String? _existingId;

  Future<void> _send(DbProfessional p) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _existingId = null;
    });
    try {
      final e = await ref.read(engagementRepositoryProvider).request(professionalId: p.id, professionalName: p.name, professionalType: p.type.name);
      ref.invalidate(engagementsProvider);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(FlowStrings.of(context).t('eng.done.sent'))));
      context.pushReplacement('/engagements/${e.id}');
    } on DuplicateEngagementException catch (e) {
      setState(() {
        _error = 'eng.err.duplicate';
        _existingId = e.existingId;
      });
    } on EngagementIneligibleException catch (e) {
      setState(() => _error = 'eng.err.${e.reason.name}');
    } on ApiException catch (e) {
      setState(() => _error = e.code == ApiErrorCode.network ? 'common.networkError' : 'common.genericError');
    } catch (_) {
      setState(() => _error = 'common.genericError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final pro = ref.watch(dbProfessionalProvider(widget.professionalId));
    final me = ref.watch(meProvider);
    void back() => aqBack(context, '/build/pro/${widget.professionalId}');
    return pro.when(
      loading: () => AQPlainPage(title: ' ', onBack: back, children: const [AQSkeletonRows(count: 3)]),
      error: (_, _) => AQPlainPage(title: f.t('eng.d.title'), onBack: back, children: [AQRetryPanel(onRetry: () => ref.invalidate(dbProfessionalProvider(widget.professionalId)))]),
      data: (p) {
        if (p == null) return AQPlainPage(title: f.t('eng.new.notFound'), onBack: back, children: const []);
        final signedIn = me.hasValue;
        final name = VFmt.iso(p.name);
        return AQPlainPage(
          eyebrow: f.t('eng.eyebrow'),
          title: f.t('eng.new.title', {'name': name}),
          subtitle: f.t('eng.new.sub'),
          onBack: back,
          trailing: const AQHelpButton('engagement'),
          bottom: AQBottomActionBar(
            primary: signedIn
                ? AQPrimaryButton(label: f.t('eng.new.send'), loading: _busy, trailingChevron: false, onPressed: () => _send(p))
                : AQPrimaryButton(label: f.t('guest.login'), onPressed: () => context.push('/login')),
          ),
          children: [
            if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
            if (_error != null)
              AQErrorBanner(
                text: f.t(_error!),
                action: _existingId == null ? null : AQTextButton(label: f.t('eng.err.openExisting'), color: c.accent, onPressed: () => context.pushReplacement('/engagements/$_existingId')),
              ),
            AQInfoCard(title: f.t('help.engagement.t'), children: [
              for (final k in ['eng.new.r1', 'eng.new.r2', 'eng.new.r3', 'eng.new.r4'])
                Padding(
                  padding: const EdgeInsets.only(bottom: AQSpacing.x2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 3), child: AQIcon('check', size: 16, color: c.accentDeep)),
                    const SizedBox(width: AQSpacing.x2),
                    Expanded(child: Text(f.t(k, {'name': name}), style: AQTypography.of(context, AQText.bodyMedium, soft: true))),
                  ]),
                ),
            ]),
          ],
        );
      },
    );
  }
}

enum _EngFilter { all, waiting, confirmed, closed }

/// My engagements with filter; each row opens its detail.
class MyEngagementsScreen extends ConsumerStatefulWidget {
  const MyEngagementsScreen({super.key});
  @override
  ConsumerState<MyEngagementsScreen> createState() => _MyEngagementsScreenState();
}

class _MyEngagementsScreenState extends ConsumerState<MyEngagementsScreen> {
  _EngFilter _filter = _EngFilter.all;

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final async = ref.watch(engagementsProvider);
    final now = DateTime.now();
    bool keep(ClientEngagement e) {
      final p = e.phaseAt(now);
      return switch (_filter) {
        _EngFilter.all => true,
        _EngFilter.waiting => p == EngagementPhase.awaitingMe || p == EngagementPhase.awaitingProfessional,
        _EngFilter.confirmed => p == EngagementPhase.confirmed,
        _EngFilter.closed => p == EngagementPhase.expired || p == EngagementPhase.declined || p == EngagementPhase.cancelled,
      };
    }

    return AQPlainPage(
      title: f.t('eng.my.title'),
      subtitle: f.t('eng.my.sub'),
      onBack: () => aqBack(context, '/app/account'),
      trailing: const AQHelpButton('engagement'),
      children: [
        if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
        DbPillRow(scroll: true, pills: [for (final x in _EngFilter.values) (f.t('eng.my.f.${x.name}'), _filter == x, () => setState(() => _filter = x))]),
        const SizedBox(height: AQSpacing.x4),
        ...async.when(
          loading: () => [const AQSkeletonRows(count: 3, height: 84)],
          error: (_, _) => [AQRetryPanel(onRetry: () => ref.invalidate(engagementsProvider))],
          data: (list) {
            if (list.isEmpty) {
              return [AQEmptyState(icon: 'user', title: f.t('eng.my.empty.t'), body: f.t('eng.my.empty.b'), action: AQPrimaryButton(label: f.t('eng.my.browse'), onPressed: () => context.go('/app/explore/build')))];
            }
            final shown = list.where(keep).toList();
            if (shown.isEmpty) return [Padding(padding: const EdgeInsets.all(AQSpacing.x6), child: Text(f.t('lst.my.emptyFilter'), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodyMedium, soft: true)))];
            return [
              AQRowGroup(rows: [
                for (final e in shown)
                  AQListRow(
                    icon: 'user',
                    title: VFmt.iso(e.professionalName),
                    subtitle: '${f.t('eng.ph.${e.phaseAt(now).name}')} · ${listingDate(context, e.requestedAt)}',
                    onTap: () => context.push('/engagements/${e.id}'),
                  ),
              ]),
            ];
          },
        ),
      ],
    );
  }
}

/// One engagement: where it stands, the windows that apply, and the one or two valid next steps.
class EngagementDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const EngagementDetailScreen({super.key, required this.id});
  @override
  ConsumerState<EngagementDetailScreen> createState() => _EngagementDetailScreenState();
}

class _EngagementDetailScreenState extends ConsumerState<EngagementDetailScreen> {
  String? _busy;
  String? _error;

  Future<void> _run(String key, Future<ClientEngagement> Function() op, String done) async {
    if (_busy != null) return;
    setState(() {
      _busy = key;
      _error = null;
    });
    try {
      await op();
      ref.invalidate(engagementProvider(widget.id));
      ref.invalidate(engagementsProvider);
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(FlowStrings.of(context).t(done))));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.code == ApiErrorCode.conflict ? 'eng.err.conflict' : 'common.networkError');
    } catch (_) {
      if (mounted) setState(() => _error = 'common.genericError');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(engagementProvider(widget.id));
    void back() => aqBack(context, '/engagements');
    return async.when(
      loading: () => AQPlainPage(title: f.t('eng.d.title'), onBack: back, children: const [AQSkeletonRows(count: 3, height: 90)]),
      error: (_, _) => AQPlainPage(title: f.t('eng.d.title'), onBack: back, children: [AQRetryPanel(onRetry: () => ref.invalidate(engagementProvider(widget.id)))]),
      data: (e) {
        if (e == null) return AQPlainPage(title: f.t('eng.d.title'), onBack: back, children: [AQEmptyState(icon: 'alert', title: f.t('eng.d.notFound'), body: '', action: AQPrimaryButton(label: f.t('eng.my.title'), onPressed: () => context.go('/engagements')))]);
        final now = DateTime.now();
        final phase = e.phaseAt(now);
        final name = VFmt.iso(e.professionalName);
        final reviewOpen = e.reviewOpenAt(now);
        final body = switch (phase) {
          EngagementPhase.awaitingProfessional => f.t('eng.ph.awaitingProfessional.b', {'name': name, 'date': listingDate(context, e.confirmBy)}),
          EngagementPhase.awaitingMe => f.t('eng.ph.awaitingMe.b', {'name': name, 'date': listingDate(context, e.confirmBy)}),
          EngagementPhase.confirmed => reviewOpen ? f.t('eng.ph.confirmed.b', {'date': listingDate(context, e.reviewBy!)}) : f.t('eng.ph.confirmedClosed.b', {'date': listingDate(context, e.reviewBy!)}),
          EngagementPhase.expired => f.t('eng.ph.expired.b'),
          EngagementPhase.declined => f.t('eng.ph.declined.b', {'name': name}),
          EngagementPhase.cancelled => f.t('eng.ph.cancelled.b'),
        };
        final step = switch (phase) {
          EngagementPhase.awaitingProfessional || EngagementPhase.awaitingMe => 1,
          EngagementPhase.confirmed => reviewOpen ? 2 : 3,
          _ => 1,
        };
        final failed = phase == EngagementPhase.declined || phase == EngagementPhase.expired || phase == EngagementPhase.cancelled ? 1 : null;
        return AQPlainPage(
          eyebrow: f.t('eng.eyebrow'),
          title: name,
          onBack: back,
          trailing: const AQHelpButton('engagement'),
          children: [
            if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
            AQInfoCard(title: f.t('eng.ph.${phase.name}'), body: body, children: [Align(alignment: AlignmentDirectional.centerStart, child: AQStatusPill(f.t('eng.ph.${phase.name}'), tone: engagementTone(phase)))]),
            if (_error != null) AQErrorBanner(text: f.t(_error!)),
            AQInfoCard(title: f.t('lst.d.timeline'), children: [
              AQStateTimeline(current: step, failedAt: failed, steps: [
                (f.t('eng.d.requested'), listingDate(context, e.requestedAt)),
                (f.t(e.phase == EngagementPhase.awaitingMe ? 'eng.d.youConfirm' : 'eng.d.companyConfirm'), e.confirmedAt == null ? null : listingDate(context, e.confirmedAt!)),
                (f.t('eng.d.reviewOpen'), e.reviewBy == null ? null : listingDate(context, e.reviewBy!)),
              ]),
            ]),
            if (phase == EngagementPhase.awaitingMe) AQPrimaryButton(label: f.t('eng.d.confirm'), loading: _busy == 'confirm', trailingChevron: false, onPressed: () => _run('confirm', () => ref.read(engagementRepositoryProvider).confirm(e.id), 'eng.done.confirmed')),
            if (phase == EngagementPhase.confirmed && reviewOpen) AQPrimaryButton(label: f.t('eng.d.review'), leadingIcon: 'star', trailingChevron: false, onPressed: () => context.push(_reviewPath(e))),
            if (phase == EngagementPhase.expired || phase == EngagementPhase.declined || phase == EngagementPhase.cancelled) AQPrimaryButton(label: f.t('eng.d.again'), onPressed: () => context.push('/engagements/new?pro=${Uri.encodeQueryComponent(e.professionalId)}')),
            if (e.isWaiting && phase != EngagementPhase.expired) ...[
              const SizedBox(height: AQSpacing.x2),
              AQSecondaryButton(
                label: f.t('eng.d.cancel'),
                loading: _busy == 'cancel',
                trailingChevron: false,
                foreground: c.danger,
                onPressed: () async {
                  final ok = await aqConfirm(context, title: f.t('eng.d.cancel.t'), body: f.t('eng.d.cancel.b'), confirmLabel: f.t('eng.d.cancel'), destructive: true);
                  if (ok) _run('cancel', () => ref.read(engagementRepositoryProvider).cancel(e.id), 'eng.done.cancelled');
                },
              ),
            ],
            const SizedBox(height: AQSpacing.x2),
            AQTextButton(label: f.t('eng.d.profile'), trailingIcon: 'chevron-right', color: c.accentDeep, onPressed: () => context.push('/build/pro/${e.professionalId}')),
            if (kShowReviewTools) _EngagementQa(e: e),
          ],
        );
      },
    );
  }
}

class _EngagementQa extends ConsumerWidget {
  final ClientEngagement e;
  const _EngagementQa({required this.e});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final repo = ref.read(engagementRepositoryProvider);
    if (repo is! DemoEngagementRepository) return const SizedBox.shrink();
    void set(EngagementPhase p, {DateTime? requestedAt}) {
      repo.debugSet(e.id, p, requestedAt: requestedAt);
      ref.invalidate(engagementProvider(e.id));
      ref.invalidate(engagementsProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x4),
      child: AQInfoCard(icon: 'shield', title: f.t('eng.qa.title'), children: [
        Wrap(spacing: AQSpacing.x2, children: [
          AQTextButton(label: f.t('eng.qa.confirm'), onPressed: () => set(EngagementPhase.confirmed)),
          AQTextButton(label: f.t('eng.qa.decline'), onPressed: () => set(EngagementPhase.declined)),
          AQTextButton(label: f.t('eng.qa.askMe'), onPressed: () => set(EngagementPhase.awaitingMe, requestedAt: DateTime.now())),
          AQTextButton(label: f.t('eng.qa.expire'), onPressed: () => set(e.phase, requestedAt: DateTime.now().subtract(const Duration(days: kEngagementConfirmDays + 1)))),
        ]),
      ]),
    );
  }
}
