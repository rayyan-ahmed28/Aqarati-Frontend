import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_demo.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/config/backend_mode.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show ApiException;
import '../../data/models/enums.dart';
import '../business/aq_business_profile.dart' show aqBusinessProvider;
import '../reviews/review_models.dart';
import '../reviews/review_screens.dart' show reviewWritePath;
import '../viewing/domain/viewing_presentation.dart' show AQTone;
import '../viewing/screens/viewing_kit.dart' show AQViewingSectionTitle, AQViewingSkeleton;
import '../viewing/widgets/viewing_components.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import 'maintenance_models.dart';
import 'maintenance_repository.dart';

String _service(FlowStrings f, MaintenanceService s) => f.t('mnt.svc.${s.name}');
String _window(FlowStrings f, MaintenanceWindow w) => f.t('mnt.win.${w.name}');

AQTone _tone(MaintenanceStatus s) => switch (s) {
      MaintenanceStatus.requested => AQTone.pending,
      MaintenanceStatus.confirmed || MaintenanceStatus.completed => AQTone.success,
      MaintenanceStatus.declined => AQTone.warning,
      MaintenanceStatus.cancelled => AQTone.neutral,
    };

/// A selectable chip with an animated surface and proper selected semantics.
class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Choice({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: AQMotion.scaled(context, AQMotion.fast),
          constraints: const BoxConstraints(minHeight: AQControl.tap, minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
          decoration: BoxDecoration(
            color: selected ? c.accent.withValues(alpha: 0.14) : c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            border: Border.all(color: selected ? c.accent : c.hairline, width: selected ? 1.5 : 1),
          ),
          // Sized to its label (not stretched), so options sit side by side and wrap.
          child: Center(widthFactor: 1, heightFactor: 1, child: Text(label, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.labelLarge, color: selected ? c.accentDeep : c.ink))),
        ),
      ),
    );
  }
}

/// Request form, then a review step, then send. The result is always "requested": the provider
/// answers later, and nothing is shown as booked before that.
class MaintenanceBookScreen extends ConsumerStatefulWidget {
  final String providerId;
  const MaintenanceBookScreen({super.key, required this.providerId});
  @override
  ConsumerState<MaintenanceBookScreen> createState() => _MaintenanceBookScreenState();
}

class _MaintenanceBookScreenState extends ConsumerState<MaintenanceBookScreen> {
  MaintenanceService? _service0;
  DateTime? _date;
  MaintenanceWindow? _window0;
  final _notes = TextEditingController();
  bool _review = false, _tried = false, _sending = false;
  String? _errorKey;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  bool get _valid => _service0 != null && _date != null && _window0 != null;

  void _toReview() {
    setState(() => _tried = true);
    if (!_valid) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _review = true;
      _errorKey = null;
    });
  }

  Future<void> _send(String providerName) async {
    if (_sending || !_valid) return;
    setState(() {
      _sending = true;
      _errorKey = null;
    });
    try {
      final b = await ref.read(maintenanceRepositoryProvider).request(
            providerId: widget.providerId,
            providerName: providerName,
            service: _service0!,
            date: _date!,
            window: _window0!,
            notes: _notes.text,
          );
      ref.invalidate(maintenanceBookingsProvider);
      AQHaptics.success();
      if (mounted) context.go('/bookings/${b.id}');
    } on DuplicateBookingException {
      if (mounted) setState(() => _errorKey = 'mnt.rev.duplicate');
    } on ApiException {
      if (mounted) setState(() => _errorKey = 'mnt.rev.error');
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'mnt.rev.error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final provider = ref.watch(aqBusinessProvider(widget.providerId));
    void back() => _review ? setState(() => _review = false) : aqBack(context, '/business/${widget.providerId}');

    return provider.when(
      loading: () => AQViewingScaffold(title: f.t('mnt.book.title'), backLabel: f.t('common.back'), onBack: back, children: const [AQViewingSkeleton(height: 120), AQViewingSkeleton(height: 120)]),
      error: (_, _) => AQViewingScaffold(
        title: f.t('mnt.book.title'),
        backLabel: f.t('common.back'),
        onBack: back,
        children: [AQErrorBanner(text: f.t('bp.loadError'), action: AQTextButton(label: f.t('common.retry'), color: c.accent, onPressed: () => ref.invalidate(aqBusinessProvider(widget.providerId))))],
      ),
      data: (b) {
        if (b == null || !b.categories.contains(BusinessCategory.maintenance)) {
          return AQViewingScaffold(title: f.t('mnt.book.title'), backLabel: f.t('common.back'), onBack: back, children: [AQNoticeCard(icon: 'info', title: f.t('mnt.book.notProvider'), body: '')]);
        }
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final days = [for (var i = 0; i <= kMaintenanceHorizonDays; i++) today.add(Duration(days: i))];

        Widget section(String title, Widget child, {String? errorKey}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AQViewingSectionTitle(title),
              child,
              AQAnimatedSize(
                duration: AQMotion.fast,
                child: (_tried && errorKey != null) ? Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Semantics(liveRegion: true, child: Text(f.t(errorKey), style: AQTypography.of(context, AQText.bodySmall, color: c.danger)))) : const SizedBox(width: double.infinity),
              ),
            ]);

        final form = Column(key: const ValueKey('form'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          section(f.t('mnt.book.service'), Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [for (final s in MaintenanceService.values) _Choice(label: _service(f, s), selected: _service0 == s, onTap: () => setState(() => _service0 = s))]), errorKey: _service0 == null ? 'mnt.book.err.service' : null),
          section(
            f.t('mnt.book.date'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final d in days)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: AQSpacing.x2),
                    child: _Choice(label: '${VFmt.weekdayShort(context, d)}\n${VFmt.dayNum(context, d)} ${VFmt.monthShort(context, d)}', selected: _date == d, onTap: () => setState(() => _date = d)),
                  ),
              ]),
            ),
            errorKey: _date == null ? 'mnt.book.err.date' : null,
          ),
          section(f.t('mnt.book.window'), Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [for (final w in MaintenanceWindow.values) _Choice(label: _window(f, w), selected: _window0 == w, onTap: () => setState(() => _window0 = w))]), errorKey: _window0 == null ? 'mnt.book.err.window' : null),
          const SizedBox(height: AQSpacing.x4),
          AQTextField(label: f.t('mnt.book.notes'), hint: f.t('mnt.book.notes.hint'), controller: _notes, minLines: 3, maxLines: 5, keyboardType: TextInputType.multiline, action: TextInputAction.newline, formatters: [LengthLimitingTextInputFormatter(300)]),
        ]);

        final review = Column(key: const ValueKey('review'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AQSurface(
            padding: const EdgeInsets.all(AQSpacing.x4),
            child: Column(children: [
              _kv(context, f.t('mnt.rev.provider'), VFmt.iso(b.name)),
              _kv(context, f.t('mnt.rev.service'), _service0 == null ? '' : _service(f, _service0!)),
              _kv(context, f.t('mnt.rev.day'), _date == null ? '' : VFmt.fullDate(context, _date!)),
              _kv(context, f.t('mnt.rev.time'), _window0 == null ? '' : _window(f, _window0!)),
              if (_notes.text.trim().isNotEmpty) _kv(context, f.t('mnt.rev.notes'), _notes.text.trim()),
            ]),
          ),
          const SizedBox(height: AQSpacing.x3),
          Align(alignment: AlignmentDirectional.centerStart, child: AQTextButton(label: f.t('mnt.rev.edit'), color: c.accent, onPressed: () => setState(() => _review = false))),
          if (_errorKey != null) Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: AQErrorBanner(text: f.t(_errorKey!))),
          const SizedBox(height: AQSpacing.x3),
          const AQDemoNotice(),
        ]);

        return AQViewingScaffold(
          title: _review ? f.t('mnt.rev.title') : f.t('mnt.book.title'),
          subtitle: _review ? f.t('mnt.rev.sub') : f.t('mnt.book.sub'),
          backLabel: f.t('common.back'),
          onBack: back,
          bottom: AQBottomActionBar(
            primary: AQPrimaryButton(
              label: _review ? f.t('mnt.rev.submit') : f.t('mnt.book.review'),
              loading: _sending,
              onPressed: _review ? () => _send(b.name) : _toReview,
            ),
          ),
          children: [AQStepSwitcher(stepKey: _review ? 'review' : 'form', forward: _review, child: _review ? review : form)],
        );
      },
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AQSpacing.x1),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
          Expanded(child: Text(v, style: AQTypography.of(context, AQText.bodyMedium))),
        ]),
      );
}

/// One request: status, what was asked, and what happens next. Cancel is available while open.
class MaintenanceDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const MaintenanceDetailScreen({super.key, required this.id});
  @override
  ConsumerState<MaintenanceDetailScreen> createState() => _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends ConsumerState<MaintenanceDetailScreen> {
  bool _busy = false;
  String? _errorKey;

  Future<void> _cancel() async {
    final f = FlowStrings.of(context);
    final yes = await showAQSheet<bool>(
      context,
      useRootNavigator: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x4),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(header: true, child: Text(f.t('mnt.det.cancel.t'), style: AQTypography.of(sheet, AQText.headlineSmall))),
          const SizedBox(height: AQSpacing.x2),
          Text(f.t('mnt.det.cancel.b'), style: AQTypography.of(sheet, AQText.bodyMedium, soft: true)),
          const SizedBox(height: AQSpacing.x4),
          AQPrimaryButton(label: f.t('mnt.det.cancel.keep'), trailingChevron: false, onPressed: () => Navigator.of(sheet).pop(false)),
          const SizedBox(height: AQSpacing.x2),
          AQSecondaryButton(label: f.t('mnt.det.cancel.yes'), trailingChevron: false, onPressed: () => Navigator.of(sheet).pop(true)),
        ]),
      ),
    );
    if (yes != true || _busy) return;
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      await ref.read(maintenanceRepositoryProvider).cancel(widget.id);
      ref.invalidate(maintenanceBookingProvider(widget.id));
      ref.invalidate(maintenanceBookingsProvider);
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'mnt.det.cancel.err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(maintenanceBookingProvider(widget.id));
    void back() => aqBack(context, '/app/activity');
    return async.when(
      loading: () => AQViewingScaffold(title: f.t('mnt.det.title'), backLabel: f.t('common.back'), onBack: back, children: const [AQViewingSkeleton(height: 120), AQViewingSkeleton(height: 160)]),
      error: (_, _) => AQViewingScaffold(
        title: f.t('mnt.det.title'),
        backLabel: f.t('common.back'),
        onBack: back,
        children: [AQErrorBanner(text: f.t('mnt.det.error'), action: AQTextButton(label: f.t('common.retry'), color: c.accent, onPressed: () => ref.invalidate(maintenanceBookingProvider(widget.id))))],
      ),
      data: (b) {
        if (b == null) {
          return AQViewingScaffold(title: f.t('mnt.det.title'), backLabel: f.t('common.back'), onBack: back, children: [AQNoticeCard(icon: 'info', title: f.t('mnt.det.notFound'), body: '')]);
        }
        final key = b.status.name;
        Widget? primary, secondary;
        switch (b.status) {
          case MaintenanceStatus.requested:
          case MaintenanceStatus.confirmed:
            primary = AQSecondaryButton(label: f.t('mnt.det.cancel'), trailingChevron: false, loading: _busy, onPressed: _busy ? null : _cancel);
          case MaintenanceStatus.declined:
          case MaintenanceStatus.cancelled:
            primary = AQPrimaryButton(label: f.t('mnt.det.again'), trailingChevron: false, onPressed: () => context.push('/business/${b.providerId}/book'));
          case MaintenanceStatus.completed:
            primary = AQPrimaryButton(label: f.t('mnt.det.review'), trailingChevron: false, onPressed: () => context.push(reviewWritePath(ReviewTarget(kind: ReviewTargetKind.provider, id: b.providerId, name: b.providerName))));
        }
        return AQViewingScaffold(
          title: f.t('mnt.det.title'),
          subtitle: VFmt.iso(b.providerName),
          backLabel: f.t('common.back'),
          onBack: back,
          bottom: AQBottomActionBar(primary: primary, secondary: secondary),
          children: [
            AQNoticeCard(icon: b.status == MaintenanceStatus.declined ? 'alert' : 'info', title: f.t('mnt.det.$key.t'), body: f.t('mnt.det.$key.b'), tone: _tone(b.status)),
            const SizedBox(height: AQSpacing.x3),
            AQSurface(
              padding: const EdgeInsets.all(AQSpacing.x4),
              child: Column(children: [
                _row(context, f.t('mnt.rev.service'), _service(f, b.service)),
                _row(context, f.t('mnt.rev.day'), VFmt.fullDate(context, b.date)),
                _row(context, f.t('mnt.rev.time'), _window(f, b.window)),
                _row(context, f.t('mnt.st.requested'), f.t('mnt.st.${b.status.name}')),
                if (b.notes.isNotEmpty) _row(context, f.t('mnt.rev.notes'), b.notes),
              ]),
            ),
            if (_errorKey != null) Padding(padding: const EdgeInsets.only(top: AQSpacing.x3), child: AQErrorBanner(text: f.t(_errorKey!))),
            const SizedBox(height: AQSpacing.x3),
            const AQDemoNotice(),
            if (kShowReviewTools) _QaProviderControls(booking: b),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AQSpacing.x1),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
          Expanded(child: Text(v, style: AQTypography.of(context, AQText.bodyMedium))),
        ]),
      );
}

/// QA only (`--dart-define=REVIEW_TOOLS=true`): simulates the provider's answer.
class _QaProviderControls extends ConsumerWidget {
  final MaintenanceBooking booking;
  const _QaProviderControls({required this.booking});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(maintenanceRepositoryProvider);
    if (repo is! DemoMaintenanceRepository) return const SizedBox.shrink();
    void set(MaintenanceStatus s) {
      repo.debugSet(booking.id, s);
      ref.invalidate(maintenanceBookingProvider(booking.id));
      ref.invalidate(maintenanceBookingsProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x4),
      child: Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
        AQTextButton(label: 'DEMO: provider confirms', onPressed: () => set(MaintenanceStatus.confirmed)),
        AQTextButton(label: 'DEMO: provider declines', onPressed: () => set(MaintenanceStatus.declined)),
        AQTextButton(label: 'DEMO: job completed', onPressed: () => set(MaintenanceStatus.completed)),
      ]),
    );
  }
}

/// The Maintenance tab of Activity.
class MaintenanceBookingsView extends ConsumerWidget {
  const MaintenanceBookingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(maintenanceBookingsProvider);
    final Widget body = async.when(
      loading: () => const Column(children: [AQViewingSkeleton(height: 96), AQViewingSkeleton(height: 96)]),
      error: (_, _) => AQErrorBanner(text: f.t('mnt.my.error'), action: AQTextButton(label: f.t('common.retry'), color: c.accent, onPressed: () => ref.invalidate(maintenanceBookingsProvider))),
      data: (all) {
        if (all.isEmpty) {
          return AQEmptyViewingState(
            title: f.t('mnt.my.empty.t'),
            body: f.t('mnt.my.empty.b'),
            action: AQPrimaryButton(label: f.t('mnt.my.browse'), leadingIcon: 'search', trailingChevron: false, onPressed: () => context.push('/professionals?cat=maintenance')),
          );
        }
        return Column(children: [for (final b in all) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x3), child: _BookingRow(booking: b))]);
      },
    );
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x4, AQSpacing.gutter, 128),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(header: true, child: Text(f.t('mnt.my.title'), style: AQTypography.of(context, AQText.displaySmall))),
              const SizedBox(height: AQSpacing.x4),
              AnimatedSwitcher(duration: AQMotion.scaled(context, AQMotion.standard), child: KeyedSubtree(key: ValueKey('${async.isLoading}-${async.hasError}-${async.valueOrNull?.length}'), child: body)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final MaintenanceBooking booking;
  const _BookingRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final b = booking;
    return Semantics(
      button: true,
      label: '${_service(f, b.service)}, ${b.providerName}, ${f.t('mnt.st.${b.status.name}')}',
      excludeSemantics: true,
      child: AQPressable(
        onTap: () => context.push('/bookings/${b.id}'),
        child: Container(
          padding: const EdgeInsets.all(AQSpacing.x4),
          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(VFmt.iso(b.providerName), style: AQTypography.of(context, AQText.titleSmall)),
                const SizedBox(height: 2),
                Text('${_service(f, b.service)} · ${VFmt.shortDate(context, b.date)} · ${_window(f, b.window)}', style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                const SizedBox(height: AQSpacing.x2),
                Text(f.t('mnt.st.${b.status.name}'), style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep)),
              ]),
            ),
            AQIcon('chevron-right', size: 18, color: c.inkSoft, directional: true),
          ]),
        ),
      ),
    );
  }
}
