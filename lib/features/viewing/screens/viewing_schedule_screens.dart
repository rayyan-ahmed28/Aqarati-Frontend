import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../help/help.dart';
import '../../../core/aq/aq_forms.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_scene.dart';
import '../../../core/aq/aq_tokens.dart';
import '../../../core/aq/aq_typography.dart';
import '../../../core/config/backend_mode.dart';
import '../../../core/localization/viewing_strings.dart';
import '../../../data/models/property.dart';
import '../data/viewing_repository.dart';
import '../domain/viewing_models.dart';
import '../domain/viewing_presentation.dart';
import '../widgets/viewing_components.dart';
import '../widgets/viewing_datetime.dart';
import '../widgets/viewing_format.dart';
import '../widgets/viewing_scaffold.dart';
import 'viewing_kit.dart';

String _flow(String id, [String leaf = '']) => '/property/$id/viewing${leaf.isEmpty ? '' : '/$leaf'}';

/// Summary row inside the pinned bar: what the Continue action commits.
class _SelectionSummary extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  const _SelectionSummary({required this.label, required this.value, required this.hint});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final large = aqDenseBar(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$label. ${value ?? hint}',
      child: ExcludeSemantics(
        child: large
            ? Text(value ?? hint, style: AQTypography.of(context, value == null ? AQText.bodyMedium : AQText.titleSmall, color: value == null ? c.inkFaint : null))
            : Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(AQRadius.small + 2)), child: Center(child: AQIcon('calendar', size: AQIconSize.medium, color: c.accent))),
          const SizedBox(width: AQSpacing.x3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              AnimatedSwitcher(
                duration: AQMotion.scaled(context, AQMotion.fast),
                child: Text(value ?? hint, key: ValueKey(value ?? hint), style: AQTypography.of(context, value == null ? AQText.bodyMedium : AQText.titleSmall, color: value == null ? c.inkFaint : null)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

DateTime? _effectiveDay(ViewingAvailability a, ViewingDraft d) => d.day ?? a.firstBookable?.date;

/// Screen 39: discover availability. Property context, a date rail, times by part of day.
class ViewingAvailabilityScreen extends ConsumerStatefulWidget {
  final String propertyId;
  const ViewingAvailabilityScreen({super.key, required this.propertyId});
  @override
  ConsumerState<ViewingAvailabilityScreen> createState() => _ViewingAvailabilityScreenState();
}

class _ViewingAvailabilityScreenState extends ConsumerState<ViewingAvailabilityScreen> {
  bool _conflicted = false;

  void _checkStale(ViewingAvailability a, ViewingDraft d) {
    final stale = staleSlot(a, d);
    if (stale == null || _conflicted) return;
    _conflicted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(viewingDraftProvider(widget.propertyId).notifier).markTaken(stale);
      context.pushReplacement(_flow(widget.propertyId, 'conflict'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.propertyId;
    final v = ViewingStrings.of(context);
    final c = AQColors.of(context);
    final property = ref.watch(viewingPropertyProvider(id));
    final avail = ref.watch(viewingAvailabilityProvider(id));
    final draft = ref.watch(viewingDraftProvider(id));
    final notifier = ref.read(viewingDraftProvider(id).notifier);
    final data = avail.valueOrNull;
    if (data != null) _checkStale(data, draft);
    final day = data == null ? null : _effectiveDay(data, draft);
    final dayInfo = day == null ? null : data!.dayOf(day);
    final slot = draft.slot;

    final summaryValue = slot == null ? null : '${VFmt.shortDate(context, slot.start)} · ${VFmt.time(context, slot.start)}';

    return AQViewingScaffold(
      trailing: const AQHelpButton('viewing'),
      title: v.t('vw.schedule.title'),
      subtitle: property.valueOrNull == null ? null : '${VFmt.iso(property.valueOrNull!.title)} · ${VFmt.iso(property.valueOrNull!.locationLabel.split(',').first.trim())}',
      backLabel: v.t('vw.back'),
      onBack: () => aqBack(context, '/property/$id'),
      bottom: AQBottomActionBar(
        summary: _SelectionSummary(label: v.t('vw.selected'), value: summaryValue, hint: day == null ? v.t('vw.pick') : v.t('vw.pickTime')),
        primary: AQPrimaryButton(label: v.t('vw.continue'), onPressed: slot == null ? null : () => context.push(_flow(id, 'slot'))),
        footnote: v.t('vw.hostConfirms'),
      ),
      children: [
        property.when(
          loading: () => const AQViewingSkeleton(height: 96),
          error: (_, _) => const SizedBox.shrink(),
          data: (p) => p == null ? const SizedBox.shrink() : AQViewingPropertySummary(property: p, density: AQViewingDensity.compact),
        ),
        AQViewingSectionTitle(v.t('vw.chooseDate')),
        Text(v.t('vw.chooseDate.sub'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
        const SizedBox(height: AQSpacing.x3),
        avail.when(
          loading: () => const AQViewingSkeleton(height: 118),
          error: (_, _) => AQErrorBanner(text: v.t('vw.availError'), action: AQTextButton(label: v.t('vw.retry'), color: c.accent, onPressed: () => ref.invalidate(viewingAvailabilityProvider(id)))),
          data: (a) => a.firstBookable == null
              ? AQNoticeCard(icon: 'calendar', title: v.t('vw.noDays'), body: '')
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AQViewingDatePicker(days: a.days, selected: day, onSelect: notifier.selectDay),
                  const SizedBox(height: AQSpacing.x3),
                  const AQViewingAvailabilityLegend(),
                ]),
        ),
        AQViewingSectionTitle(v.t('vw.times'), icon: 'clock'),
        if (data != null) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x3), child: Text(v.t('vw.zone', {'city': data.zoneCity, 'zone': data.zoneLabel}), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
        if (avail.isLoading) const AQViewingSkeleton(height: 160),
        if (dayInfo != null && !dayInfo.bookable) ...[
          AQNoticeCard(icon: 'calendar', title: v.t('vw.noTimes'), body: ''),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AQTextButton(
              label: v.t('vw.noTimes.action'),
              color: c.accent,
              trailingIcon: 'chevron-right',
              onPressed: () {
                final next = data!.days.where((d) => d.bookable && d.date.isAfter(dayInfo.date)).firstOrNull ?? data.firstBookable;
                if (next != null) notifier.selectDay(next.date);
              },
            ),
          ),
        ],
        if (dayInfo != null && dayInfo.bookable)
          for (final p in ViewingPeriod.values)
            if (dayInfo.inPeriod(p).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                child: AQSurface(
                  padding: const EdgeInsets.all(AQSpacing.x3),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      AQIcon(periodIcon(p), size: AQIconSize.medium, color: c.accent),
                      const SizedBox(width: AQSpacing.x2),
                      Text(v.t(periodKey(p)), style: AQTypography.of(context, AQText.titleSmall)),
                      const SizedBox(width: AQSpacing.x2),
                      Expanded(child: Text(periodRange(context, dayInfo.inPeriod(p)), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
                    ]),
                    const SizedBox(height: AQSpacing.x3),
                    AQViewingSlotGrid(slots: dayInfo.inPeriod(p), selected: slot, onSelect: notifier.selectSlot),
                  ]),
                ),
              ),
      ],
    );
  }
}

/// Screen 40: commit to a moment. Focused two-step picker with counts and a per-period view.
class ViewingSlotScreen extends ConsumerStatefulWidget {
  final String propertyId;
  const ViewingSlotScreen({super.key, required this.propertyId});
  @override
  ConsumerState<ViewingSlotScreen> createState() => _ViewingSlotScreenState();
}

class _ViewingSlotScreenState extends ConsumerState<ViewingSlotScreen> {
  ViewingPeriod? _period;
  bool _conflicted = false;

  @override
  Widget build(BuildContext context) {
    final id = widget.propertyId;
    final v = ViewingStrings.of(context);
    final c = AQColors.of(context);
    final property = ref.watch(viewingPropertyProvider(id));
    final avail = ref.watch(viewingAvailabilityProvider(id));
    final draft = ref.watch(viewingDraftProvider(id));
    final notifier = ref.read(viewingDraftProvider(id).notifier);
    final data = avail.valueOrNull;
    if (data != null && !_conflicted) {
      final stale = staleSlot(data, draft);
      if (stale != null) {
        _conflicted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          notifier.markTaken(stale);
          context.pushReplacement(_flow(id, 'conflict'));
        });
      }
    }
    final day = data == null ? null : _effectiveDay(data, draft);
    final dayInfo = day == null ? null : data!.dayOf(day);
    final slot = draft.slot;
    ViewingPeriod? period;
    if (dayInfo != null) {
      bool free(ViewingPeriod p) => dayInfo.inPeriod(p).any((s) => s.bookable);
      period = _period != null && dayInfo.inPeriod(_period!).isNotEmpty ? _period : (slot != null && slot.day == dayInfo.date ? slot.period : ViewingPeriod.values.where(free).firstOrNull ?? ViewingPeriod.morning);
    }

    return AQViewingScaffold(
      title: v.t('vw.slot.title'),
      subtitle: v.t('vw.slot.sub'),
      backLabel: v.t('vw.back'),
      onBack: () => aqBack(context, _flow(id)),
      bottom: AQBottomActionBar(
        summary: _SelectionSummary(label: v.t('vw.selectedSlot'), value: slot == null ? null : '${VFmt.fullDate(context, slot.start)} · ${VFmt.range(context, slot)}', hint: day == null ? v.t('vw.pick') : v.t('vw.pickTime')),
        primary: AQPrimaryButton(label: v.t('vw.continue'), onPressed: slot == null ? null : () => context.push(_flow(id, 'review'))),
        footnote: v.t('vw.reviewFirst'),
      ),
      children: [
        property.when(
          loading: () => const AQViewingSkeleton(height: 56),
          error: (_, _) => const SizedBox.shrink(),
          data: (p) => p == null ? const SizedBox.shrink() : _MiniProperty(property: p),
        ),
        AQViewingSectionTitle(v.t('vw.step1')),
        avail.when(
          loading: () => const AQViewingSkeleton(height: 132),
          error: (_, _) => AQErrorBanner(text: v.t('vw.availError'), action: AQTextButton(label: v.t('vw.retry'), color: c.accent, onPressed: () => ref.invalidate(viewingAvailabilityProvider(id)))),
          data: (a) => a.firstBookable == null
              ? AQNoticeCard(icon: 'calendar', title: v.t('vw.noDays'), body: '')
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AQViewingDatePicker(days: a.days, selected: day, onSelect: notifier.selectDay, showCount: true, showNav: true),
                  const SizedBox(height: AQSpacing.x3),
                  const AQViewingAvailabilityLegend(),
                ]),
        ),
        AQViewingSectionTitle(v.t('vw.step2')),
        if (data != null) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x3), child: Text(v.t('vw.zone', {'city': data.zoneCity, 'zone': data.zoneLabel}), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
        if (avail.isLoading) const AQViewingSkeleton(height: 180),
        if (dayInfo != null && !dayInfo.bookable)
          AQNoticeCard(icon: 'calendar', title: v.t('vw.noTimes'), body: v.t('vw.noTimes.action'))
        else if (dayInfo != null && period != null) ...[
          _PeriodTabs(
            day: dayInfo,
            current: period,
            onChanged: (p) {
              AQHaptics.selection();
              setState(() => _period = p);
            },
          ),
          const SizedBox(height: AQSpacing.x3),
          AnimatedSwitcher(
            duration: AQMotion.scaled(context, AQMotion.standard),
            child: KeyedSubtree(key: ValueKey('${dayInfo.date}-$period'), child: AQViewingSlotGrid(slots: dayInfo.inPeriod(period), selected: slot, onSelect: notifier.selectSlot, detailed: true)),
          ),
        ],
      ],
    );
  }
}

class _MiniProperty extends StatelessWidget {
  final Property property;
  const _MiniProperty({required this.property});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AQRadius.small),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Hero(
            tag: 'vw-img-${property.id}',
            child: property.imageUrls.isEmpty ? ColoredBox(color: c.surfaceSelected) : Image.asset(property.imageUrls.first, fit: BoxFit.cover, cacheWidth: 200, errorBuilder: (_, _, _) => ColoredBox(color: c.surfaceSelected)),
          ),
        ),
      ),
      const SizedBox(width: AQSpacing.x3),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(VFmt.iso(property.title), style: AQTypography.of(context, AQText.titleSmall)),
          Text(VFmt.iso(property.locationLabel.split(',').first.trim()), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
        ]),
      ),
    ]);
  }
}

class _PeriodTabs extends StatelessWidget {
  final AvailabilityDay day;
  final ViewingPeriod current;
  final ValueChanged<ViewingPeriod> onChanged;
  const _PeriodTabs({required this.day, required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final v = ViewingStrings.of(context);
    final periods = ViewingPeriod.values.where((p) => day.inPeriod(p).isNotEmpty).toList();
    final stack = aqLargeText(context);
    Widget tab(ViewingPeriod p) {
      final sel = p == current;
      return Semantics(
        button: true,
        selected: sel,
        label: '${v.t(periodKey(p))}, ${periodRange(context, day.inPeriod(p))}',
        excludeSemantics: true,
        child: AQPressable(
          onTap: () => onChanged(p),
          child: AnimatedContainer(
            duration: AQMotion.scaled(context, AQMotion.fast),
            constraints: const BoxConstraints(minHeight: AQControl.tap + 8),
            padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x2, vertical: AQSpacing.x2),
            decoration: BoxDecoration(color: sel ? c.surfaceSelected : c.surface, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: sel ? c.accent : Colors.transparent, width: 1.5)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                AQIcon(periodIcon(p), size: 18, color: sel ? c.accentDeep : c.accent),
                const SizedBox(width: 6),
                Flexible(child: Text(v.t(periodKey(p)), style: AQTypography.of(context, AQText.labelMedium, color: sel ? c.ink : c.inkSoft))),
              ]),
              const SizedBox(height: 2),
              Text(periodRange(context, day.inPeriod(p)), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodySmall, color: c.inkFaint).copyWith(fontSize: 11)),
            ]),
          ),
        ),
      );
    }

    if (stack) return Column(children: [for (final p in periods) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x2), child: SizedBox(width: double.infinity, child: tab(p)))]);
    return Row(children: [
      for (var i = 0; i < periods.length; i++) ...[if (i > 0) const SizedBox(width: AQSpacing.x2), Expanded(child: tab(periods[i]))],
    ]);
  }
}

/// Screen 41: the final check before anything is sent.
class ViewingReviewScreen extends ConsumerStatefulWidget {
  final String propertyId;
  const ViewingReviewScreen({super.key, required this.propertyId});
  @override
  ConsumerState<ViewingReviewScreen> createState() => _ViewingReviewScreenState();
}

class _ViewingReviewScreenState extends ConsumerState<ViewingReviewScreen> {
  bool _sending = false;
  bool _failed = false;
  /// Set once the request succeeded: clearing the draft must not trigger the empty-draft redirect.
  bool _leaving = false;

  Future<void> _send(ViewingSlot slot) async {
    if (_sending) return;
    final id = widget.propertyId;
    setState(() {
      _sending = true;
      _failed = false;
    });
    final repo = ref.read(viewingRepositoryProvider);
    try {
      final viewing = await repo.request(propertyId: id, slot: slot);
      ref.invalidate(viewingsProvider);
      ref.invalidate(viewingAvailabilityProvider(id));
      if (!mounted) return;
      _leaving = true;
      AQHaptics.success();
      context.go('/viewings/${viewing.id}/requested');
      ref.read(viewingDraftProvider(id).notifier).clear();
    } on SlotTakenException {
      ref.read(viewingDraftProvider(id).notifier).markTaken(slot);
      ref.invalidate(viewingAvailabilityProvider(id));
      if (!mounted) return;
      context.pushReplacement(_flow(id, 'conflict'));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.propertyId;
    final v = ViewingStrings.of(context);
    final property = ref.watch(viewingPropertyProvider(id));
    final host = ref.watch(viewingHostProvider(id));
    final draft = ref.watch(viewingDraftProvider(id));
    final slot = draft.slot;
    if (slot == null) {
      // A slot cleared by a conflict is handled by the conflict route, not by this guard.
      if (draft.takenSlot == null && !_leaving) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(_flow(id));
        });
      }
      return viewingLoadingFrame(context, title: v.t('vw.review.title'), onBack: () => aqBack(context, _flow(id, 'slot')));
    }
    final p = property.valueOrNull;
    return AQViewingScaffold(
      title: v.t('vw.review.title'),
      subtitle: v.t('vw.review.sub'),
      backLabel: v.t('vw.back'),
      onBack: _sending ? () {} : () => aqBack(context, _flow(id, 'slot')),
      bottom: AQBottomActionBar(
            stack: true,
        primary: AQPrimaryButton(label: v.t('vw.send'), leadingIcon: 'send', trailingChevron: false, loading: _sending, onPressed: () => _send(slot)),
        secondary: AQBarSecondaryButton(label: v.t('vw.changeTime'), onPressed: _sending ? null : () => aqBack(context, _flow(id, 'slot'))),
        footnote: v.t('vw.hostConfirms'),
      ),
      children: [
        if (_failed) AQErrorBanner(text: v.t('vw.sendError')),
        property.when(
          loading: () => const AQViewingSkeleton(height: 150),
          error: (_, _) => const SizedBox.shrink(),
          data: (x) => x == null ? const SizedBox.shrink() : AQViewingPropertySummary(property: x),
        ),
        AQViewingSectionTitle(v.t('vw.yourViewing'), icon: 'calendar-check'),
        AQViewingDetailCard(slot: slot, tone: AQTone.pending),
        AQViewingSectionTitle(v.t('vw.meeting'), icon: 'pin'),
        AQViewingLocationCard(place: p?.locationLabel.split(',').take(2).join(',').trim() ?? '', note: v.t('vw.meeting.pending')),
        AQViewingSectionTitle(v.t('vw.host'), icon: 'user'),
        host.when(
          loading: () => const AQViewingSkeleton(height: 84),
          error: (_, _) => const SizedBox.shrink(),
          data: (h) => AQViewingHostCard(host: h, showContactNote: true),
        ),
        if (kShowReviewTools) _DemoConflictSwitch(),
      ],
    );
  }
}

class _DemoConflictSwitch extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DemoConflictSwitch> createState() => _DemoConflictSwitchState();
}

class _DemoConflictSwitchState extends ConsumerState<_DemoConflictSwitch> {
  @override
  Widget build(BuildContext context) {
    final v = ViewingStrings.of(context);
    final repo = ref.watch(viewingRepositoryProvider);
    if (repo is! DemoViewingRepository) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x5),
      child: AQSecondaryButton(
        label: repo.conflictArmed ? v.t('vw.demo.armed') : v.t('vw.demo.conflict'),
        trailingChevron: false,
        leadingIcon: 'alert',
        onPressed: () => setState(repo.armConflict),
      ),
    );
  }
}

/// Screen 49: a real, recoverable conflict. Replacement slots come from fresh availability.
class ViewingConflictScreen extends ConsumerWidget {
  final String propertyId;
  const ViewingConflictScreen({super.key, required this.propertyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = propertyId;
    final v = ViewingStrings.of(context);
    final c = AQColors.of(context);
    final property = ref.watch(viewingPropertyProvider(id));
    final avail = ref.watch(viewingAvailabilityProvider(id));
    final draft = ref.watch(viewingDraftProvider(id));
    final notifier = ref.read(viewingDraftProvider(id).notifier);
    final data = avail.valueOrNull;
    final prev = draft.takenSlot;
    final day = data == null ? null : (draft.day != null && (data.dayOf(draft.day!)?.bookable ?? false) ? draft.day : data.firstBookable?.date);
    final dayInfo = day == null ? null : data!.dayOf(day);
    final options = dayInfo?.slots.where((s) => s.bookable).take(9).toList() ?? const <SlotInfo>[];
    final slot = draft.slot;
    final p = property.valueOrNull;
    return AQViewingScaffold(
      emotional: true,
      washImage: p?.imageUrls.firstOrNull,
      hero: const AQConfirmationState(icon: 'calendar-x', tone: AQTone.warning, haptic: false),
      title: v.t('vw.conflict.title'),
      subtitle: v.t('vw.conflict.sub'),
      backLabel: v.t('vw.back'),
      onBack: () => aqBack(context, _flow(id, 'slot')),
      bottom: AQBottomActionBar(
            stack: true,
        primary: slot == null
            ? AQPrimaryButton(label: v.t('vw.selectNew'), leadingIcon: 'calendar', trailingChevron: false, onPressed: () => context.push(_flow(id, 'slot')))
            : AQPrimaryButton(label: '${v.t('vw.continue')} · ${VFmt.time(context, slot.start)}', onPressed: () => context.push(_flow(id, 'review'))),
        secondary: AQBarSecondaryButton(label: v.t('vw.browseSimilar'), leadingIcon: 'search', onPressed: () => aqBrowseSimilar(context, p)),
      ),
      children: [
        property.when(loading: () => const AQViewingSkeleton(height: 150), error: (_, _) => const SizedBox.shrink(), data: (x) => x == null ? const SizedBox.shrink() : AQViewingPropertySummary(property: x)),
        const SizedBox(height: AQSpacing.x4),
        if (prev != null) AQViewingConflictCard(previous: prev),
        AQViewingSectionTitle(v.t('vw.conflict.alt'), icon: 'calendar'),
        avail.when(
          loading: () => const AQViewingSkeleton(height: 160),
          error: (_, _) => AQErrorBanner(text: v.t('vw.availError'), action: AQTextButton(label: v.t('vw.retry'), color: c.accent, onPressed: () => ref.invalidate(viewingAvailabilityProvider(id)))),
          data: (a) => a.firstBookable == null
              ? AQNoticeCard(icon: 'calendar', title: v.t('vw.conflict.none'), body: '')
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AQViewingDatePicker(days: a.days, selected: day, onSelect: notifier.selectDay),
                  const SizedBox(height: AQSpacing.x3),
                  if (options.isEmpty) AQNoticeCard(icon: 'calendar', title: v.t('vw.conflict.none'), body: '') else AQViewingSlotGrid(slots: options, selected: slot, onSelect: notifier.selectSlot),
                ]),
        ),
      ],
    );
  }
}
