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
import '../../data/api/account_api.dart' show ApiException, ApiErrorCode;
import '../help/help.dart';
import '../listings/listing_widgets.dart' show listingDate;
import '../viewing/data/viewing_repository.dart' show viewingProvider;
import '../viewing/domain/viewing_presentation.dart' show AQTone;
import '../viewing/widgets/viewing_components.dart' show AQConfirmationState;
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import 'review_models.dart';
import 'review_repository.dart';

AQPillTone reviewTone(ReviewStatus s) => switch (s) {
      ReviewStatus.published => AQPillTone.success,
      ReviewStatus.pendingModeration => AQPillTone.pending,
      ReviewStatus.underReview => AQPillTone.warning,
      ReviewStatus.removed || ReviewStatus.rejected => AQPillTone.danger,
    };

ReviewTargetKind? reviewKindOf(String? s) => ReviewTargetKind.values.where((k) => k.name == s).firstOrNull;

/// Five large tappable stars; announces the value.
class AQStarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const AQStarPicker({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    return Row(children: [
      for (var i = 1; i <= 5; i++)
        Semantics(
          button: true,
          selected: i <= value,
          label: f.t('rv.star', {'n': '$i'}),
          excludeSemantics: true,
          child: AQPressable(
            pressedScale: 0.88,
            onTap: () {
              AQHaptics.selection();
              onChanged(i);
            },
            child: SizedBox(
              width: AQControl.tap,
              height: AQControl.tap,
              child: Center(
                child: AnimatedScale(
                  scale: i <= value ? 1 : 0.9,
                  duration: AQMotion.scaled(context, AQMotion.icon),
                  child: AQIcon(i <= value ? 'star-fill' : 'star', size: 32, color: i <= value ? c.accent : c.inkFaint),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Eligibility gate -> composer -> preview -> "submitted for moderation". Editing uses the same
/// screen with [editId]. Nothing here ever says "published".
class ReviewComposerScreen extends ConsumerStatefulWidget {
  final ReviewTarget target;
  final int? initialRating;
  final String? editId;
  const ReviewComposerScreen({super.key, required this.target, this.initialRating, this.editId});
  @override
  ConsumerState<ReviewComposerScreen> createState() => _ReviewComposerScreenState();
}

enum _Stage { compose, preview, done }

class _ReviewComposerScreenState extends ConsumerState<ReviewComposerScreen> {
  late int _rating = widget.initialRating ?? 0;
  final _comment = TextEditingController();
  _Stage _stage = _Stage.compose;
  bool _tried = false;
  bool _busy = false;
  String? _error;
  bool _prefilled = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  String get _name => VFmt.iso(widget.target.name);
  bool get _valid => _rating >= 1 && _rating <= 5 && reviewCommentError(_comment.text) == null;

  void _toPreview() {
    setState(() => _tried = true);
    if (_valid) setState(() => _stage = _Stage.preview);
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(reviewRepositoryProvider);
    try {
      if (widget.editId != null) {
        await repo.edit(id: widget.editId!, rating: _rating, comment: _comment.text);
      } else {
        await repo.submit(target: widget.target, rating: _rating, comment: _comment.text);
      }
      ref.invalidate(myReviewsProvider);
      ref.invalidate(reviewEligibilityProvider(widget.target));
      if (mounted) setState(() => _stage = _Stage.done);
    } on ReviewNotEligibleException {
      _fail('rv.err.notEligible');
    } on ReviewAlreadyExistsException {
      _fail('rv.err.already');
    } on ReviewNotEditableException {
      _fail('rv.err.notEditable');
    } on ApiException catch (e) {
      _fail(e.code == ApiErrorCode.network ? 'common.networkError' : 'common.genericError');
    } catch (_) {
      _fail('common.genericError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String k) {
    if (mounted) {
      setState(() {
        _error = k;
        _stage = _Stage.compose;
      });
    }
  }

  void _back() {
    if (_stage == _Stage.preview) {
      setState(() => _stage = _Stage.compose);
      return;
    }
    aqBack(context, '/reviews/mine');
  }

  Widget _gate(FlowStrings f, String icon, String title, String body, {Widget? action}) => AQPlainPage(
        eyebrow: f.t('rv.eyebrow'),
        title: f.t('rv.title', {'name': _name}),
        onBack: _back,
        trailing: const AQHelpButton('reviews'),
        children: [AQEmptyState(icon: icon, title: title, body: body, action: action)],
      );

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final t = widget.target;
    if (_stage == _Stage.done) {
      return AQViewingScaffold(
        emotional: true,
        showBack: false,
        hero: const AQConfirmationState(icon: 'clock', tone: AQTone.pending),
        title: f.t('rv.done.t'),
        subtitle: f.t('rv.done.b'),
        bottom: AQBottomActionBar(
          stack: true,
          primary: AQPrimaryButton(label: f.t('rv.done.mine'), onPressed: () => context.pushReplacement('/reviews/mine')),
          secondary: AQBarSecondaryButton(label: f.t('rv.done.close'), onPressed: () => aqBack(context, '/app/activity')),
        ),
        children: [if (kUseDemoBackend) AQErrorBanner(text: f.t('rv.demo'), tone: AQBannerTone.info)],
      );
    }
    if (widget.editId == null) {
      final elig = ref.watch(reviewEligibilityProvider(t));
      if (elig.isLoading && !elig.hasValue) return AQPlainPage(title: f.t('rv.title', {'name': _name}), onBack: _back, children: const [AQSkeletonRows(count: 3)]);
      if (elig.hasError) return AQPlainPage(title: f.t('rv.title', {'name': _name}), onBack: _back, children: [AQRetryPanel(onRetry: () => ref.invalidate(reviewEligibilityProvider(t)))]);
      final e = elig.value!;
      switch (e.kind) {
        case ReviewEligibilityKind.signedOut:
          return _gate(f, 'lock', f.t('rv.g.signedOut.t'), f.t('rv.g.signedOut.b'), action: AQPrimaryButton(label: f.t('guest.login'), onPressed: () => context.push('/login')));
        case ReviewEligibilityKind.notEligible:
          return _gate(f, 'info', f.t('rv.g.notEligible.t'), f.t('rv.g.notEligible.${t.kind.name}'),
              action: t.kind == ReviewTargetKind.professional ? AQPrimaryButton(label: f.t('rv.g.startEngagement'), onPressed: () => context.pushReplacement('/engagements/new?pro=${Uri.encodeQueryComponent(t.id)}')) : null);
        case ReviewEligibilityKind.notYetEligible:
          return _gate(f, 'clock', f.t('rv.g.notYet.t'), f.t('rv.g.notYet.b'));
        case ReviewEligibilityKind.windowExpired:
          return _gate(f, 'calendar-x', f.t('rv.g.window.t'), f.t('rv.g.window.b', {'date': e.windowEndsAt == null ? '' : listingDate(context, e.windowEndsAt!)}));
        case ReviewEligibilityKind.alreadyReviewed:
          final ex = e.existing!;
          return _gate(f, 'star', f.t('rv.g.already.t'), f.t('rv.g.already.b'),
              action: ex.canEdit ? AQPrimaryButton(label: f.t('rv.g.edit'), onPressed: () => context.pushReplacement(reviewEditPath(ex))) : AQSecondaryButton(label: f.t('rv.done.mine'), trailingChevron: false, onPressed: () => context.pushReplacement('/reviews/mine')));
        case ReviewEligibilityKind.eligible:
          break;
      }
    } else if (!_prefilled) {
      final mine = ref.watch(myReviewsProvider).valueOrNull?.where((r) => r.id == widget.editId).firstOrNull;
      if (mine != null) {
        _prefilled = true;
        _rating = widget.initialRating ?? mine.rating;
        _comment.text = mine.comment;
      }
    }
    final commentErr = _tried ? reviewCommentError(_comment.text) : null;
    final editing = widget.editId != null;
    return PopScope(
      canPop: _stage == _Stage.compose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _stage = _Stage.compose);
      },
      child: AQPlainPage(
        eyebrow: f.t('rv.eyebrow'),
        title: f.t(editing ? 'rv.edit.title' : 'rv.title', {'name': _name}),
        subtitle: f.t('rv.sub.${t.kind.name}'),
        onBack: _back,
        trailing: const AQHelpButton('reviews'),
        bottom: AQBottomActionBar(
          secondary: _stage == _Stage.preview ? AQBarSecondaryButton(label: f.t('rv.back'), onPressed: _busy ? null : () => setState(() => _stage = _Stage.compose)) : null,
          primary: _stage == _Stage.compose
              ? AQPrimaryButton(label: f.t('rv.preview'), onPressed: _toPreview)
              : AQPrimaryButton(label: f.t(editing ? 'rv.saveEdit' : 'rv.submit'), loading: _busy, trailingChevron: false, onPressed: _submit),
        ),
        children: [
          if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
          if (_error != null) AQErrorBanner(text: f.t(_error!)),
          AQStepSwitcher(
            stepKey: _stage,
            forward: _stage == _Stage.preview,
            child: _stage == _Stage.compose
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(f.t('rv.stars'), style: AQTypography.of(context, AQText.titleMedium)),
                    AQStarPicker(value: _rating, onChanged: (v) => setState(() => _rating = v)),
                    if (_tried && _rating == 0) Text(f.t('rv.err.stars'), style: AQTypography.of(context, AQText.bodySmall, color: c.danger)),
                    const SizedBox(height: AQSpacing.x4),
                    AQTextField(label: f.t('rv.comment'), hint: f.t('rv.comment.hint'), controller: _comment, minLines: 4, maxLines: 8, action: TextInputAction.newline, error: commentErr == null ? null : f.t(commentErr), onChanged: (_) => setState(() {})),
                    AQCharCount(count: _comment.text.trim().length, min: kReviewMinChars, max: kReviewMaxChars),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    AQInfoCard(title: f.t('rv.preview.t'), body: f.t('rv.preview.b')),
                    Container(
                      padding: const EdgeInsets.all(AQSpacing.x4),
                      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.large), border: Border.all(color: c.hairline)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Semantics(label: f.t('rv.star', {'n': '$_rating'}), excludeSemantics: true, child: Row(children: [for (var i = 1; i <= 5; i++) AQIcon(i <= _rating ? 'star-fill' : 'star', size: 18, color: c.accent)])),
                        const SizedBox(height: AQSpacing.x2),
                        Text(_comment.text.trim(), style: AQTypography.of(context, AQText.bodyMedium)),
                        const SizedBox(height: AQSpacing.x2),
                        Text(f.t('rv.byYou'), style: AQTypography.of(context, AQText.labelSmall, soft: true)),
                      ]),
                    ),
                  ]),
          ),
        ],
      ),
    );
  }
}

String reviewWritePath(ReviewTarget t, {int? rating}) => '/reviews/write?kind=${t.kind.name}&id=${Uri.encodeQueryComponent(t.id)}&name=${Uri.encodeQueryComponent(t.name)}${rating == null ? '' : '&rating=$rating'}';
String reviewEditPath(MyReview r) => '/reviews/${r.id}/edit?kind=${r.target.kind.name}&id=${Uri.encodeQueryComponent(r.target.id)}&name=${Uri.encodeQueryComponent(r.target.name)}';

/// Reviews the person wrote, with their moderation status and edit when the service allows it.
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(myReviewsProvider);
    return AQPlainPage(
      title: f.t('rv.my.title'),
      subtitle: f.t('rv.my.sub'),
      onBack: () => aqBack(context, '/app/account'),
      trailing: const AQHelpButton('reviews'),
      children: [
        if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
        ...async.when(
          loading: () => [const AQSkeletonRows(count: 3, height: 110)],
          error: (_, _) => [AQRetryPanel(onRetry: () => ref.invalidate(myReviewsProvider))],
          data: (list) => list.isEmpty
              ? [AQEmptyState(icon: 'star', title: f.t('rv.my.empty.t'), body: f.t('rv.my.empty.b'), action: AQSecondaryButton(label: f.t('nav.activity'), trailingChevron: false, onPressed: () => context.go('/app/activity')))]
              : [
                  for (final r in list)
                    AQInfoCard(
                      title: VFmt.iso(r.target.name),
                      children: [
                        Semantics(label: f.t('rv.star', {'n': '${r.rating}'}), excludeSemantics: true, child: Row(children: [for (var i = 1; i <= 5; i++) AQIcon(i <= r.rating ? 'star-fill' : 'star', size: 16, color: c.accent)])),
                        const SizedBox(height: AQSpacing.x2),
                        Text(r.comment, style: AQTypography.of(context, AQText.bodyMedium)),
                        const SizedBox(height: AQSpacing.x3),
                        Wrap(spacing: AQSpacing.x3, runSpacing: AQSpacing.x1, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          AQStatusPill(f.t('rv.st.${r.status.name}'), tone: reviewTone(r.status)),
                          Text(listingDate(context, r.createdAt), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                        ]),
                        const SizedBox(height: AQSpacing.x2),
                        Text(f.t('rv.st.${r.status.name}.b'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                        if (r.canEdit) Align(alignment: AlignmentDirectional.centerEnd, child: AQTextButton(label: f.t('rv.my.edit'), trailingIcon: 'chevron-right', color: c.accentDeep, onPressed: () => context.push(reviewEditPath(r))))
                        else if (r.status == ReviewStatus.published) Padding(padding: const EdgeInsets.only(top: AQSpacing.x1), child: Text(f.t('rv.my.editLocked'), style: AQTypography.of(context, AQText.bodySmall, color: c.inkFaint))),
                        if (kShowReviewTools) _ReviewQa(review: r),
                      ],
                    ),
                ],
        ),
      ],
    );
  }
}

class _ReviewQa extends ConsumerWidget {
  final MyReview review;
  const _ReviewQa({required this.review});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final repo = ref.read(reviewRepositoryProvider);
    if (repo is! DemoReviewRepository) return const SizedBox.shrink();
    void set({ReviewStatus? status, bool? canEdit}) {
      repo.debugSet(review.id, status: status, canEdit: canEdit);
      ref.invalidate(myReviewsProvider);
    }

    return Wrap(spacing: AQSpacing.x1, children: [
      AQTextButton(label: f.t('rv.qa.publish'), onPressed: () => set(status: ReviewStatus.published)),
      AQTextButton(label: f.t('rv.qa.reject'), onPressed: () => set(status: ReviewStatus.rejected)),
      AQTextButton(label: f.t('rv.qa.report'), onPressed: () => set(status: ReviewStatus.underReview)),
      AQTextButton(label: f.t('rv.qa.remove'), onPressed: () => set(status: ReviewStatus.removed)),
      AQTextButton(label: f.t('rv.qa.unlock'), onPressed: () => set(canEdit: true)),
    ]);
  }
}

/// Report a published review: a reason in the reporter's own words, confirmation, then a receipt.
class ReportReviewScreen extends ConsumerStatefulWidget {
  final String reviewId;
  final String about;
  const ReportReviewScreen({super.key, required this.reviewId, required this.about});
  @override
  ConsumerState<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends ConsumerState<ReportReviewScreen> {
  final _reason = TextEditingController();
  bool _tried = false, _busy = false, _done = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final f = FlowStrings.of(context);
    setState(() => _tried = true);
    if (reportReasonError(_reason.text) != null || _busy) return;
    final ok = await aqConfirm(context, title: f.t('rp.confirm.t'), body: f.t('rp.confirm.b'), confirmLabel: f.t('rp.send'));
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(reviewRepositoryProvider).report(reviewId: widget.reviewId, reason: _reason.text.trim());
      if (mounted) setState(() => _done = true);
    } on ReviewAlreadyReportedException {
      if (mounted) setState(() => _error = 'rp.already');
    } catch (_) {
      if (mounted) setState(() => _error = 'common.networkError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    void back() => aqBack(context, '/app/explore/build');
    if (_done) {
      return AQViewingScaffold(
        emotional: true,
        showBack: false,
        hero: const AQConfirmationState(icon: 'check', tone: AQTone.success),
        title: f.t('rp.done.t'),
        subtitle: f.t('rp.done.b'),
        bottom: AQBottomActionBar(primary: AQPrimaryButton(label: f.t('rv.done.close'), trailingChevron: false, onPressed: back)),
        children: [if (kUseDemoBackend) AQErrorBanner(text: f.t('rv.demo'), tone: AQBannerTone.info)],
      );
    }
    final err = _tried ? reportReasonError(_reason.text) : null;
    return AQPlainPage(
      title: f.t('rp.title'),
      subtitle: f.t('rp.sub'),
      eyebrow: VFmt.iso(widget.about).toUpperCase(),
      onBack: back,
      bottom: AQBottomActionBar(primary: AQPrimaryButton(label: f.t('rp.send'), loading: _busy, trailingChevron: false, onPressed: _send)),
      children: [
        if (_error != null) AQErrorBanner(text: f.t(_error!)),
        AQTextField(label: f.t('rp.reason'), hint: f.t('rp.reason.hint'), controller: _reason, minLines: 3, maxLines: 6, action: TextInputAction.newline, error: err == null ? null : f.t(err), onChanged: (_) => setState(() {})),
        AQCharCount(count: _reason.text.trim().length, min: kReviewMinChars, max: kReviewMaxChars),
        Text(f.t('rp.note'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
      ],
    );
  }
}

/// A completed viewing's "Write a review" opens the composer for the host who ran it.
class ViewingReviewBridge extends ConsumerWidget {
  final String viewingId;
  final int? rating;
  const ViewingReviewBridge({super.key, required this.viewingId, this.rating});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final v = ref.watch(viewingProvider(viewingId));
    void back() => aqBack(context, '/viewings/$viewingId');
    return v.when(
      loading: () => AQPlainPage(title: ' ', onBack: back, children: const [AQSkeletonRows(count: 3)]),
      error: (_, _) => AQPlainPage(title: f.t('rv.my.title'), onBack: back, children: [AQRetryPanel(onRetry: () => ref.invalidate(viewingProvider(viewingId)))]),
      data: (x) => x == null
          ? AQPlainPage(title: f.t('rv.my.title'), onBack: back, children: [AQEmptyState(icon: 'alert', title: f.t('rv.g.notEligible.t'), body: f.t('rv.g.notEligible.seller'))])
          : ReviewComposerScreen(target: ReviewTarget(kind: ReviewTargetKind.seller, id: x.host.id, name: x.host.name), initialRating: rating),
    );
  }
}
