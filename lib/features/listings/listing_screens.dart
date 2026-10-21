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
import '../devbuild/db_widgets.dart' show DbPillRow;
import '../help/help.dart';
import '../viewing/widgets/viewing_components.dart' show AQConfirmationState;
import '../viewing/domain/viewing_presentation.dart' show AQTone;
import '../viewing/widgets/viewing_scaffold.dart';
import 'listing_models.dart';
import 'listing_repository.dart';
import 'listing_widgets.dart';

enum _Filter { all, live, review, action, drafts, closed }

bool _matches(_Filter f, ListingState s) => switch (f) {
      _Filter.all => true,
      _Filter.live => s == ListingState.approvedActive,
      _Filter.review => s == ListingState.pending,
      _Filter.action => s == ListingState.resubmissionRequired || s == ListingState.expired,
      _Filter.drafts => false,
      _Filter.closed => s == ListingState.rejected || s == ListingState.hidden || s == ListingState.sold || s == ListingState.rented || s == ListingState.withdrawn,
    };

/// My listings: every listing the person submitted (agent or Aqary e-Broker), with its real state.
class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});
  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final me = ref.watch(meProvider);
    final m = me.valueOrNull;
    void back() => aqBack(context, '/app/account');
    if (me.isLoading && m == null) return AQPlainPage(title: f.t('lst.my.title'), onBack: back, children: const [AQSkeletonRows(count: 3, height: 100)]);
    if (m == null) {
      return AQPlainPage(title: f.t('lst.my.title'), onBack: back, children: [
        AQEmptyState(
          icon: 'lock',
          title: f.t('lst.my.signedOut.t'),
          body: f.t('lst.my.signedOut.b'),
          action: AQPrimaryButton(label: f.t('guest.login'), onPressed: () => context.push('/login')),
        ),
      ]);
    }
    final agent = canUseChannel(m, ListingChannel.agent);
    final listings = ref.watch(myListingsProvider);
    final drafts = ref.watch(myListingDraftsProvider);
    return AQPlainPage(
      title: f.t('lst.my.title'),
      subtitle: f.t('lst.my.sub'),
      onBack: back,
      trailing: const AQHelpButton('listingReview'),
      children: [
        if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
        if (agent) ...[
          AQPrimaryButton(label: f.t('lst.my.new'), leadingIcon: 'plus', trailingChevron: false, onPressed: () => context.push('/listings/new?channel=agent')),
          const SizedBox(height: AQSpacing.x2),
          AQSecondaryButton(label: f.t('lst.my.sell'), trailingChevron: false, onPressed: () => context.push('/sell')),
        ] else
          AQPrimaryButton(label: f.t('lst.my.sell'), leadingIcon: 'plus', trailingChevron: false, onPressed: () => context.push('/sell')),
        const SizedBox(height: AQSpacing.x5),
        DbPillRow(scroll: true, pills: [for (final x in _Filter.values) (f.t('lst.my.f.${x.name}'), _filter == x, () => setState(() => _filter = x))]),
        const SizedBox(height: AQSpacing.x4),
        ...switch ((listings, drafts)) {
          (AsyncValue(hasError: true), _) || (_, AsyncValue(hasError: true)) => [
              AQRetryPanel(onRetry: () {
                ref.invalidate(myListingsProvider);
                ref.invalidate(myListingDraftsProvider);
              }),
            ],
          (AsyncData(value: final ls), AsyncData(value: final ds)) => _rows(f, ls, ds),
          _ => [const AQSkeletonRows(count: 3, height: 100)],
        },
      ],
    );
  }

  List<Widget> _rows(FlowStrings f, List<Listing> ls, List<ListingDraft> ds) {
    final shownDrafts = _filter == _Filter.all || _filter == _Filter.drafts ? ds : const <ListingDraft>[];
    final shown = ls.where((l) => _matches(_filter, l.state)).toList();
    if (ls.isEmpty && ds.isEmpty) {
      return [AQEmptyState(icon: 'home', title: f.t('lst.my.empty.t'), body: f.t('lst.my.empty.b'))];
    }
    if (shown.isEmpty && shownDrafts.isEmpty) {
      return [Padding(padding: const EdgeInsets.symmetric(vertical: AQSpacing.x6), child: Text(f.t('lst.my.emptyFilter'), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodyMedium, soft: true)))];
    }
    return [
      for (final d in shownDrafts)
        ListingRow(
          title: d.title.trim().isEmpty ? f.t('lst.my.untitled') : d.title.trim(),
          subtitle: [if (d.subType != null && d.action != null) listingKind(f, d.subType!, d.action!, channel: d.channel), f.t('lst.ch.${d.channel.name}')].join(' · '),
          photo: d.photos.firstOrNull,
          status: AQStatusPill(f.t('lst.my.draftRow'), icon: 'edit'),
          onTap: () => context.push('/listings/new?channel=${d.channel == ListingChannel.eBroker ? 'ebroker' : 'agent'}&draft=${d.id}'),
        ),
      for (final l in shown)
        ListingRow(
          title: l.title,
          subtitle: '${listingKind(f, l.subType, l.action, channel: l.channel)} · ${listingPlace(f, l.governorate, l.wilayat)}',
          price: omr(context, l.price),
          photo: l.photos.firstOrNull,
          status: ListingStatePill(l.state),
          note: l.changeSet?.status == 'pending' ? f.t('lst.my.changes') : null,
          onTap: () => context.push('/listings/${l.id}'),
        ),
    ];
  }
}

/// The owner's view of one listing: state, reviewer feedback, details and the actions the state allows.
class ListingDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ListingDetailScreen({super.key, required this.id});
  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  String? _busy;
  String? _error;

  Future<void> _act(String key, Future<Listing> Function() op, String doneKey) async {
    if (_busy != null) return;
    setState(() {
      _busy = key;
      _error = null;
    });
    try {
      await op();
      ref.invalidate(listingProvider(widget.id));
      ref.invalidate(myListingsProvider);
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(FlowStrings.of(context).t(doneKey))));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.code == ApiErrorCode.conflict ? 'lst.err.conflict' : 'common.networkError');
    } catch (_) {
      if (mounted) setState(() => _error = 'common.genericError');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _lifecycle(Listing l, ListingState to) async {
    final f = FlowStrings.of(context);
    final ok = await aqConfirm(context, title: f.t('lst.d.confirm.${to.name}.t'), body: f.t('lst.d.confirm.b'), confirmLabel: f.t('lst.d.${to == ListingState.withdrawn ? 'withdraw' : to.name}'), destructive: to == ListingState.withdrawn);
    if (!ok || !mounted) return;
    await _act(to.name, () => ref.read(listingRepositoryProvider).setLifecycle(l.id, to), 'lst.d.done.${to.name}');
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(listingProvider(widget.id));
    void back() => aqBack(context, '/listings');
    return async.when(
      loading: () => AQPlainPage(title: f.t('lst.my.title'), onBack: back, children: const [AQSkeletonRows(count: 4, height: 90)]),
      error: (_, _) => AQPlainPage(title: f.t('lst.my.title'), onBack: back, children: [AQRetryPanel(onRetry: () => ref.invalidate(listingProvider(widget.id)))]),
      data: (l) {
        if (l == null) {
          return AQPlainPage(title: f.t('lst.my.title'), onBack: back, children: [AQEmptyState(icon: 'alert', title: f.t('lst.w.notFound'), body: '', action: AQPrimaryButton(label: f.t('lst.sub.all'), onPressed: () => context.go('/listings')))]);
        }
        final failed = l.state == ListingState.rejected ? 2 : null;
        final current = switch (l.state) {
          ListingState.pending => 1,
          ListingState.resubmissionRequired || ListingState.rejected => 2,
          ListingState.draft => 0,
          _ => 3,
        };
        final cs = l.changeSet;
        String fields(Set<String> s) => s.map((x) => f.t('lst.field.$x')).join(', ');
        final reasonKey = l.reasonCode == null ? null : (FlowStrings.keys.contains('reason.${l.reasonCode}') ? 'reason.${l.reasonCode}' : 'reason.unknown');
        final channelArg = l.channel == ListingChannel.eBroker ? 'ebroker' : 'agent';
        final actions = <Widget>[
          if (l.canResubmit) AQPrimaryButton(label: f.t('lst.d.fix'), onPressed: () => context.push('/listings/${l.id}/fix')),
          if (l.canRenew) AQPrimaryButton(label: f.t('lst.d.renew'), loading: _busy == 'renew', trailingChevron: false, onPressed: () => _act('renew', () => ref.read(listingRepositoryProvider).renew(l.id), 'lst.d.done.renewed')),
          if (l.canEdit) AQPrimaryButton(label: f.t('lst.d.edit'), leadingIcon: 'edit', trailingChevron: false, onPressed: () => context.push('/listings/${l.id}/edit')),
          if (l.canMarkSold) AQSecondaryButton(label: f.t('lst.d.sold'), loading: _busy == 'sold', trailingChevron: false, onPressed: () => _lifecycle(l, ListingState.sold)),
          if (l.canMarkRented) AQSecondaryButton(label: f.t('lst.d.rented'), loading: _busy == 'rented', trailingChevron: false, onPressed: () => _lifecycle(l, ListingState.rented)),
          if (l.canWithdraw) AQSecondaryButton(label: f.t('lst.d.withdraw'), loading: _busy == 'withdrawn', trailingChevron: false, foreground: c.danger, onPressed: () => _lifecycle(l, ListingState.withdrawn)),
          if (l.state == ListingState.rejected) AQSecondaryButton(label: f.t('lst.d.newListing'), trailingChevron: false, onPressed: () => context.push(l.channel == ListingChannel.eBroker ? '/sell' : '/listings/new?channel=$channelArg')),
        ];
        return AQPlainPage(
          eyebrow: f.t('lst.ch.${l.channel.name}').toUpperCase(),
          title: l.title,
          subtitle: '${listingKind(f, l.subType, l.action, channel: l.channel)} · ${listingPlace(f, l.governorate, l.wilayat, l.areaName)}',
          onBack: back,
          trailing: const AQHelpButton('listingReview'),
          children: [
            if (l.photos.isNotEmpty) ...[ListingPhoto(l.photos.first, height: 180, width: double.infinity, radius: AQRadius.large), const SizedBox(height: AQSpacing.x4)],
            AQInfoCard(
              title: f.t('lst.st.${l.state.name}'),
              body: f.t('lst.st.${l.state.name}.b'),
              children: [
                Align(alignment: AlignmentDirectional.centerStart, child: ListingStatePill(l.state)),
                if (l.isLive && l.expiresAt != null) Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Text(f.t('lst.d.liveUntil', {'date': listingDate(context, l.expiresAt!)}), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
              ],
            ),
            if (_error != null) AQErrorBanner(text: f.t(_error!)),
            if (reasonKey != null && (l.state == ListingState.resubmissionRequired || l.state == ListingState.rejected)) AQInfoCard(icon: 'alert', accent: c.warning, title: f.t('lst.d.feedback'), body: f.t(reasonKey)),
            if (cs != null)
              AQInfoCard(
                icon: cs.status == 'pending' ? 'clock' : (cs.status == 'approved' ? 'check' : 'alert'),
                title: f.t('lst.d.changeSet.t'),
                body: f.t(cs.status == 'pending' ? 'lst.d.changeSet.b' : (cs.status == 'approved' ? 'lst.d.changeSet.ok' : 'lst.d.changeSet.no'), {'fields': fields(cs.fields)}),
              ),
            if (l.duplicateSuspected) AQInfoCard(icon: 'info', title: f.t('lst.d.dup')),
            if (l.state != ListingState.sold && l.state != ListingState.rented && l.state != ListingState.withdrawn && l.state != ListingState.hidden)
              AQInfoCard(
                title: f.t('lst.d.timeline'),
                children: [
                  AQStateTimeline(current: current, failedAt: failed, steps: [
                    (f.t('lst.d.t.submitted'), l.submittedAt == null ? null : listingDate(context, l.submittedAt!)),
                    (f.t('lst.d.t.review'), null),
                    (f.t('lst.d.t.decision'), l.decidedAt == null ? null : listingDate(context, l.decidedAt!)),
                    (f.t('lst.d.t.live'), l.expiresAt == null ? null : f.t('lst.d.liveUntil', {'date': listingDate(context, l.expiresAt!)})),
                  ]),
                ],
              ),
            AQInfoCard(title: f.t('lst.d.actions'), children: [
              if (actions.isEmpty) Text(f.t('lst.d.noActions'), style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
              for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x2), child: a),
            ]),
            AQInfoCard(title: f.t('lst.d.details'), children: [
              _kv(f.t('lst.w.price'), omr(context, l.price)),
              _kv(f.t('lst.w.market'), f.t('lst.mkt.${l.market.name}')),
              if (l.beds != null) _kv(f.t('lst.w.beds'), '${l.beds}'),
              if (l.baths != null) _kv(f.t('lst.w.baths'), '${l.baths}'),
              if (l.landSqm != null) _kv(f.t('lst.w.land'), '${l.landSqm}'),
              if (l.buildSqm != null) _kv(f.t('lst.w.build'), '${l.buildSqm}'),
              _kv(f.t('lst.w.rv.photos'), '${l.photos.length}'),
              if (l.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Text(l.description, style: AQTypography.of(context, AQText.bodyMedium, soft: true))),
            ]),
            AQInfoCard(title: f.t('lst.d.docs'), body: f.t('lst.d.docsNote'), children: [
              _kv(f.t('lst.w.deed'), f.t('lst.w.rv.deedEnding', {'x': l.deedHint})),
              if (l.deedFileName != null) _kv(f.t('lst.w.deedFile'), l.deedFileName!),
              if (l.authorisationFileName != null) _kv(f.t('lst.w.authFile'), l.authorisationFileName!),
            ]),
            if (kShowReviewTools) _QaTools(listing: l),
          ],
        );
      },
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: AQSpacing.x2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(k, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
          const SizedBox(width: AQSpacing.x3),
          Flexible(child: Text(v, textAlign: TextAlign.end, style: AQTypography.of(context, AQText.titleSmall))),
        ]),
      );
}

/// QA builds only: simulate the reviewer and system jobs so every state can be walked.
class _QaTools extends ConsumerWidget {
  final Listing listing;
  const _QaTools({required this.listing});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final repo = ref.read(listingRepositoryProvider);
    if (repo is! DemoListingRepository) return const SizedBox.shrink();
    void run(void Function() op) {
      op();
      ref.invalidate(listingProvider(listing.id));
      ref.invalidate(myListingsProvider);
    }

    return AQInfoCard(icon: 'shield', title: f.t('lst.qa.title'), children: [
      Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
        if (listing.state == ListingState.pending) ...[
          AQTextButton(label: f.t('lst.qa.approve'), onPressed: () => run(() => repo.debugDecide(listing.id, ListingState.approvedActive))),
          AQTextButton(label: f.t('lst.qa.changes'), onPressed: () => run(() => repo.debugDecide(listing.id, ListingState.resubmissionRequired, reason: 'PHOTOS_MISMATCH'))),
          AQTextButton(label: f.t('lst.qa.reject'), onPressed: () => run(() => repo.debugDecide(listing.id, ListingState.rejected, reason: 'OWNER_MISMATCH'))),
        ],
        if (listing.isLive) ...[
          AQTextButton(label: f.t('lst.qa.expire'), onPressed: () => run(() => repo.debugExpire(listing.id))),
          AQTextButton(label: f.t('lst.qa.hide'), onPressed: () => run(() => repo.debugDecide(listing.id, ListingState.hidden))),
        ],
        if (listing.changeSet?.status == 'pending') ...[
          AQTextButton(label: f.t('lst.qa.csOk'), onPressed: () => run(() => repo.debugChangeSet(listing.id, approve: true))),
          AQTextButton(label: f.t('lst.qa.csNo'), onPressed: () => run(() => repo.debugChangeSet(listing.id, approve: false))),
        ],
      ]),
    ]);
  }
}

/// Receipt after a submission or resubmission. It says "in review", never "published".
class ListingSubmittedScreen extends ConsumerWidget {
  final String id;
  final bool resubmitted;
  const ListingSubmittedScreen({super.key, required this.id, this.resubmitted = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final l = ref.watch(listingProvider(id)).valueOrNull;
    return AQViewingScaffold(
      emotional: true,
      showBack: false,
      hero: const AQConfirmationState(icon: 'clock', tone: AQTone.pending),
      title: f.t(resubmitted ? 'lst.resub.title' : 'lst.sub.title'),
      subtitle: f.t('lst.sub.b'),
      bottom: AQBottomActionBar(
        stack: true,
        primary: AQPrimaryButton(label: f.t('lst.sub.view'), onPressed: () => context.pushReplacement('/listings/$id')),
        secondary: AQBarSecondaryButton(label: f.t('lst.sub.all'), onPressed: () => context.go('/listings')),
      ),
      children: [
        if (kUseDemoBackend) AQErrorBanner(text: f.t('lst.sub.demo'), tone: AQBannerTone.info),
        AQInfoCard(title: l?.title ?? id, children: [
          Row(children: [Expanded(child: Text(f.t('lst.sub.ref'), style: AQTypography.of(context, AQText.bodySmall, soft: true))), Text(id, style: AQTypography.of(context, AQText.titleSmall))]),
          if (l?.submittedAt != null) Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Row(children: [Expanded(child: Text(f.t('lst.sub.at'), style: AQTypography.of(context, AQText.bodySmall, soft: true))), Text(listingDate(context, l!.submittedAt!), style: AQTypography.of(context, AQText.titleSmall))])),
          const SizedBox(height: AQSpacing.x3),
          if (l != null) Align(alignment: AlignmentDirectional.centerStart, child: ListingStatePill(l.state)),
        ]),
        AQInfoCard(title: f.t('lst.sub.next'), children: [
          AQStateTimeline(current: 0, steps: [(f.t('lst.sub.n1'), null), (f.t('lst.sub.n2'), null), (f.t('lst.sub.n3'), null)]),
        ]),
      ],
    );
  }
}
