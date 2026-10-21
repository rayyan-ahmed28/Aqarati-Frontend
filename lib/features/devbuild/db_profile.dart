import 'package:flutter/material.dart';
import '../engagement/engagement_screens.dart' show EngagementProfileCard;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/domain/account_models.dart' show InteriorExteriorServiceType;
import '../../core/localization/flow_strings.dart';
import '../../core/widgets/aqarati_map_view.dart';
import '../property/property_detail_screen.dart' show aqRequireSession;
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_home.dart' show aqImg;
import 'db_models.dart';
import 'db_repository.dart';
import 'db_widgets.dart';

/// Not-found / unavailable frame shared by the detail screens.
Widget dbMissingFrame(
  BuildContext context, {
  required String title,
  required String body,
  required VoidCallback onBack,
}) {
  final f = FlowStrings.of(context);
  return AQViewingScaffold(
    title: title,
    backLabel: f.t('common.back'),
    onBack: onBack,
    children: [DbNotice(body, icon: 'info')],
  );
}

/// Contact options exactly as the profile provides them. Direct dial and WhatsApp deep links need
/// a platform plugin this build does not include, so numbers are shown and can be copied; nothing
/// claims a call was placed.
Future<void> showDbContactSheet(
  BuildContext context,
  WidgetRef ref,
  DbProfessional pro,
) {
  final repo = ref.read(devBuildRepositoryProvider);
  return showAQSheet<void>(
    context,
    useRootNavigator: true,
    builder: (s) {
      final f = FlowStrings.of(s);
      final c = AQColors.of(s);
      Widget row(ContactChannel ch, String number) => Padding(
        padding: const EdgeInsets.only(bottom: AQSpacing.x3),
        child: Container(
          padding: const EdgeInsets.all(AQSpacing.x3),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            border: Border.all(color: c.hairline),
          ),
          child: Row(
            children: [
              DbIcon(
                ch == ContactChannel.call ? 'phone' : 'whatsapp',
                size: 22,
                color: c.accent,
              ),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.t(
                        ch == ContactChannel.call
                            ? 'db.contact.call'
                            : 'db.contact.whatsapp',
                      ),
                      style: AQTypography.of(s, AQText.labelMedium),
                    ),
                    // A phone number reads as one unit; shrink it rather than wrap it onto three lines.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        VFmt.iso(number),
                        maxLines: 1,
                        style: AQTypography.of(s, AQText.bodyLarge),
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: '${f.t('db.contact.copy')} $number',
                excludeSemantics: true,
                child: AQPressable(
                  onTap: () async {
                    var copied = true;
                    try {
                      await Clipboard.setData(ClipboardData(text: number));
                    } catch (_) {
                      copied = false;
                    }
                    if (copied && repo.caps.leadEvents) {
                      try {
                        await repo.logContactEvent(pro.id, ch);
                      } catch (_) {}
                    }
                    if (!s.mounted) return;
                    Navigator.of(s).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            f.t(
                              copied
                                  ? 'db.contact.copied'
                                  : 'db.contact.copyFailed',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: AQControl.tap,
                      minWidth: AQControl.tap,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AQSpacing.x3,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DbIcon('copy', size: 18, color: c.accentDeep),
                        const SizedBox(width: 6),
                        Text(
                          f.t('db.contact.copy'),
                          style: AQTypography.of(
                            s,
                            AQText.labelMedium,
                            color: c.accentDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AQSpacing.gutter,
          AQSpacing.x3,
          AQSpacing.gutter,
          AQSpacing.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                f.t('db.contact.title', {'n': pro.name}),
                style: AQTypography.of(s, AQText.headlineSmall),
              ),
            ),
            const SizedBox(height: AQSpacing.x2),
            Text(
              f.t('db.contact.note'),
              style: AQTypography.of(s, AQText.bodyMedium, soft: true),
            ),
            const SizedBox(height: AQSpacing.x4),
            if (pro.phone != null) row(ContactChannel.call, pro.phone!),
            if (pro.whatsapp != null)
              row(ContactChannel.whatsapp, pro.whatsapp!),
            AQSecondaryButton(
              label: f.t('common.close'),
              trailingChevron: false,
              onPressed: () => Navigator.of(s).pop(),
            ),
          ],
        ),
      );
    },
  );
}

bool dbHasContact(DbProfessional p) =>
    (p.phone ?? '').isNotEmpty || (p.whatsapp ?? '').isNotEmpty;

class DbStars extends StatelessWidget {
  final int rating;
  final double size;
  const DbStars(this.rating, {super.key, this.size = 16});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: AQIcon(
                  i <= rating ? 'star-fill' : 'star',
                  size: size,
                  color: i <= rating ? c.warning : c.inkFaint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DbReviewCard extends StatelessWidget {
  final DbReview review;
  /// Name of the reviewed company; when set the card offers "Report".
  final String? about;
  const DbReviewCard(this.review, {super.key, this.about});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    return Semantics(
      label:
          '${f.t('db.rev.rated', {'n': VFmt.n(context, review.rating)})}. ${review.body}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AQSpacing.x3),
        padding: const EdgeInsets.all(AQSpacing.x4),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(AQRadius.large),
          border: Border.all(color: c.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AQSpacing.x2,
              children: [
                DbStars(review.rating),
                Text(
                  VFmt.monthYear(context, review.at),
                  style: AQTypography.of(context, AQText.bodySmall, soft: true),
                ),
              ],
            ),
            const SizedBox(height: AQSpacing.x2),
            Text(
              review.body,
              style: AQTypography.of(context, AQText.bodyMedium),
            ),
            const SizedBox(height: AQSpacing.x2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    f.t('db.rev.by', {'a': review.author}),
                    style: AQTypography.of(context, AQText.labelSmall, soft: true),
                  ),
                ),
                // Published reviews can be reported (POST /reviews/:id/reports); a moderator decides.
                if (about != null)
                  AQTextButton(
                    label: f.t('rp.action'),
                    onPressed: () => context.push('/reviews/report?id=${Uri.encodeQueryComponent(review.id)}&about=${Uri.encodeQueryComponent(about!)}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- #63 profile

class DbProfileScreen extends ConsumerStatefulWidget {
  final String id;
  const DbProfileScreen({super.key, required this.id});
  @override
  ConsumerState<DbProfileScreen> createState() => _DbProfileScreenState();
}

class _DbProfileScreenState extends ConsumerState<DbProfileScreen> {
  int _tab = 0;
  int _photo = 0;
  bool _more = false;

  void _back() => aqBack(context, '/app/explore/build');

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(dbProfessionalProvider(widget.id));
    return async.when(
      loading: () => AQViewingScaffold(
        backLabel: f.t('common.back'),
        onBack: _back,
        children: const [
          DbSkeleton(height: 220),
          SizedBox(height: AQSpacing.x4),
          DbSkeleton(height: 90),
          SizedBox(height: AQSpacing.x4),
          DbSkeleton(height: 160),
        ],
      ),
      error: (e, _) => AQViewingScaffold(
        backLabel: f.t('common.back'),
        onBack: _back,
        children: [
          DbErrorCard(
            error: e,
            onRetry: () => ref.invalidate(dbProfessionalProvider(widget.id)),
          ),
        ],
      ),
      data: (p) {
        if (p == null)
          return dbMissingFrame(
            context,
            title: f.t('db.notFound.t'),
            body: f.t('db.notFound.pro'),
            onBack: _back,
          );
        final projects = p.type.hasProjects
            ? ref.watch(dbApprovedProjectsProvider(p.id))
            : null;
        final large = aqLargeText(context);
        final photos = p.mediaUrls;
        final tabs = [
          (f.t('db.tab.overview'), 0),
          if (p.type.hasProjects) (f.t('db.tab.projects'), 1),
          (f.t('db.tab.reviews'), 2),
        ];
        return Scaffold(
          backgroundColor: c.background,
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            children: [
                              SizedBox(
                                height: large ? 200 : 260,
                                child: photos.isEmpty
                                    ? ColoredBox(
                                        color: c.surfaceSelected,
                                        child: Center(
                                          child: AQIcon(
                                            p.type.icon,
                                            size: 48,
                                            color: c.accent,
                                          ),
                                        ),
                                      )
                                    : PageView.builder(
                                        itemCount: photos.length,
                                        onPageChanged: (i) =>
                                            setState(() => _photo = i),
                                        itemBuilder: (_, i) => Semantics(
                                          image: true,
                                          label: f.t('db.photoOf', {
                                            'a': VFmt.n(context, i + 1),
                                            'b': VFmt.n(context, photos.length),
                                          }),
                                          child: aqImg(
                                            photos[i],
                                            cacheWidth: 900,
                                          ),
                                        ),
                                      ),
                              ),
                              PositionedDirectional(
                                top: MediaQuery.paddingOf(context).top + 6,
                                start: AQSpacing.x3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: c.surfaceRaised.withValues(
                                      alpha: 0.9,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: AQIconButton(
                                    icon: 'chevron-left',
                                    semanticsLabel: f.t('common.back'),
                                    onPressed: _back,
                                  ),
                                ),
                              ),
                              if (photos.length > 1)
                                PositionedDirectional(
                                  end: AQSpacing.x3,
                                  bottom: AQSpacing.x3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      '${VFmt.n(context, _photo + 1)}/${VFmt.n(context, photos.length)}',
                                      style: AQTypography.of(
                                        context,
                                        AQText.labelSmall,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AQSpacing.gutter,
                              AQSpacing.x4,
                              AQSpacing.gutter,
                              0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Semantics(
                                        header: true,
                                        child: Text(
                                          VFmt.iso(p.name),
                                          style: AQTypography.of(
                                            context,
                                            AQText.displaySmall,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (p.verified) ...[
                                      const SizedBox(width: 8),
                                      Semantics(
                                        label: f.t('disc.verified'),
                                        child: AQIcon(
                                          'verified',
                                          size: 24,
                                          color: c.accent,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dbProLabel(f, p),
                                  style: AQTypography.of(
                                    context,
                                    AQText.bodyMedium,
                                    soft: true,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    AQIcon('pin', size: 16, color: c.accent),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        VFmt.iso(p.locationLabel),
                                        style: AQTypography.of(
                                          context,
                                          AQText.bodyMedium,
                                          soft: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AQSpacing.x4),
                                _stats(
                                  context,
                                  f,
                                  c,
                                  p,
                                  projects?.valueOrNull?.length,
                                ),
                                const SizedBox(height: AQSpacing.x4),
                                DbPillRow(
                                  pills: [
                                    for (final t in tabs)
                                      (
                                        t.$1,
                                        _tab == t.$2,
                                        () => setState(() => _tab = t.$2),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AQSpacing.x4),
                                AnimatedSwitcher(
                                  duration: AQMotion.scaled(
                                    context,
                                    AQMotion.fast,
                                  ),
                                  child: KeyedSubtree(
                                    key: ValueKey(_tab),
                                    child: switch (_tab) {
                                      1 => _projectsTab(context, f, p),
                                      2 => _reviewsTab(context, f, c, p),
                                      _ => _overviewTab(context, f, c, p),
                                    },
                                  ),
                                ),
                                const SizedBox(height: AQSpacing.x6),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AQBottomActionBar(
                footnote: dbHasContact(p) ? null : f.t('db.contact.none'),
                primary: AQPrimaryButton(
                  label: f.t('db.contact'),
                  trailingChevron: false,
                  leadingIcon: 'phone',
                  onPressed: dbHasContact(p)
                      ? () => aqRequireSession(
                          context,
                          ref,
                          actionKey: 'db.a.contact',
                          go: () => showDbContactSheet(context, ref, p),
                        )
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stats(
    BuildContext context,
    FlowStrings f,
    AQColors c,
    DbProfessional p,
    int? projectCount,
  ) {
    final cells = <(String icon, String value, String label)>[
      if (p.rating != null)
        (
          'star-fill',
          VFmt.dec(context, p.rating!, digits: 1),
          f.t('pro.reviews', {'n': VFmt.n(context, p.reviewCount ?? 0)}),
        ),
      if (projectCount != null && projectCount > 0)
        ('development', VFmt.n(context, projectCount), f.t('db.tab.projects')),
      if (p.verified)
        ('shield', f.t('disc.verified'), f.t('db.approvedBusiness')),
    ];
    if (cells.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AQRadius.medium),
        border: Border.all(color: c.hairline),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        runSpacing: AQSpacing.x3,
        children: [
          for (final x in cells)
            SizedBox(
              width: 104,
              child: Semantics(
                label: '${x.$2}, ${x.$3}',
                excludeSemantics: true,
                child: Column(
                  children: [
                    AQIcon(
                      x.$1,
                      size: 20,
                      color: x.$1 == 'star-fill' ? c.warning : c.accent,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      x.$2,
                      style: AQTypography.of(context, AQText.titleMedium),
                    ),
                    Text(
                      x.$3,
                      textAlign: TextAlign.center,
                      style: AQTypography.of(
                        context,
                        AQText.labelSmall,
                        soft: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _overviewTab(
    BuildContext context,
    FlowStrings f,
    AQColors c,
    DbProfessional p,
  ) {
    final long = p.bio.length > 180;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          f.t('db.about', {'n': VFmt.iso(p.name)}),
          style: AQTypography.of(context, AQText.headlineSmall),
        ),
        const SizedBox(height: AQSpacing.x2),
        if (p.bio.isEmpty)
          DbNotice(f.t('db.noBio'))
        else
          AQAnimatedSize(
            duration: AQMotion.scaled(context, AQMotion.fast),
            alignment: Alignment.topLeft,
            child: Text(
              p.bio,
              maxLines: _more || !long ? null : 4,
              overflow: _more || !long ? null : TextOverflow.ellipsis,
              style: AQTypography.of(context, AQText.bodyMedium, soft: true),
            ),
          ),
        if (long)
          AQTextButton(
            label: f.t(_more ? 'db.readLess' : 'db.readMore'),
            color: c.accentDeep,
            trailingIcon: _more ? null : 'chevron-down',
            onPressed: () => setState(() => _more = !_more),
          ),
        if (p.serviceType != null) ...[
          const SizedBox(height: AQSpacing.x4),
          Text(
            f.t('db.services'),
            style: AQTypography.of(context, AQText.headlineSmall),
          ),
          const SizedBox(height: AQSpacing.x2),
          DbTagRow(
            tags: [
              if (p.serviceType == InteriorExteriorServiceType.interior ||
                  p.serviceType == InteriorExteriorServiceType.both)
                f.t('service.interior'),
              if (p.serviceType == InteriorExteriorServiceType.exterior ||
                  p.serviceType == InteriorExteriorServiceType.both)
                f.t('service.exterior'),
            ],
          ),
        ],
        const SizedBox(height: AQSpacing.x4),
        Text(
          f.t(p.type.hasProjects ? 'db.location.dev' : 'db.location.office'),
          style: AQTypography.of(context, AQText.headlineSmall),
        ),
        const SizedBox(height: AQSpacing.x2),
        if (p.latitude != null && p.longitude != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AQRadius.large),
            child: SizedBox(
              height: aqLargeText(context) ? 300 : 180,
              child: AqaratiMapView(
                initialCenter: LatLng(p.latitude!, p.longitude!),
                initialZoom: 13,
                interactive: false,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
        const SizedBox(height: AQSpacing.x2),
        Text(
          VFmt.iso(p.locationLabel),
          style: AQTypography.of(context, AQText.bodySmall, soft: true),
        ),
      ],
    );
  }

  Widget _projectsTab(BuildContext context, FlowStrings f, DbProfessional p) {
    final async = ref.watch(dbApprovedProjectsProvider(p.id));
    return async.when(
      loading: () => const DbSkeletonList(count: 2, height: 96),
      error: (e, _) => DbErrorCard(
        error: e,
        onRetry: () => ref.invalidate(dbApprovedProjectsProvider(p.id)),
      ),
      data: (list) => list.isEmpty
          ? DbNotice(f.t('db.noProjects'), icon: 'development')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final x in list.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                    child: DbProjectCard(
                      project: x,
                      onTap: () => context.push('/build/project/${x.id}'),
                    ),
                  ),
                if (list.length > 4)
                  AQSecondaryButton(
                    label: f.t('pt.viewAll'),
                    trailingChevron: false,
                    onPressed: () =>
                        context.push('/build/pro/${p.id}/projects'),
                  ),
              ],
            ),
    );
  }

  Widget _reviewsTab(
    BuildContext context,
    FlowStrings f,
    AQColors c,
    DbProfessional p,
  ) {
    final async = ref.watch(dbReviewsProvider(p.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.rating != null)
          Row(
            children: [
              Text(
                VFmt.dec(context, p.rating!, digits: 1),
                style: AQTypography.of(context, AQText.displaySmall),
              ),
              const SizedBox(width: AQSpacing.x3),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DbStars(p.rating!.round(), size: 18),
                    Text(
                      f.t('pro.reviews', {
                        'n': VFmt.n(context, p.reviewCount ?? 0),
                      }),
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        soft: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          DbNotice(f.t('db.rev.none')),
        const SizedBox(height: AQSpacing.x3),
        async.when(
          loading: () => const DbSkeleton(height: 100),
          error: (e, _) => DbErrorCard(
            error: e,
            onRetry: () => ref.invalidate(dbReviewsProvider(p.id)),
          ),
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  children: [for (final r in list.take(2)) DbReviewCard(r, about: p.name)],
                ),
        ),
        AQSecondaryButton(
          label: f.t('db.rev.all'),
          trailingChevron: false,
          onPressed: () => context.push('/build/pro/${p.id}/reviews'),
        ),
        const SizedBox(height: AQSpacing.x4),
        // Reviews need an engagement both sides confirm (a call or WhatsApp tap is not one).
        EngagementProfileCard(pro: p),
      ],
    );
  }
}

// ---------------------------------------------------------- #64 reviews list

class DbReviewsScreen extends ConsumerStatefulWidget {
  final String id;
  const DbReviewsScreen({super.key, required this.id});
  @override
  ConsumerState<DbReviewsScreen> createState() => _DbReviewsScreenState();
}

class _DbReviewsScreenState extends ConsumerState<DbReviewsScreen> {
  int? _stars;

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final pro = ref.watch(dbProfessionalProvider(widget.id));
    final revs = ref.watch(dbReviewsProvider(widget.id));
    return AQViewingScaffold(
      title: f.t('db.rev.title'),
      subtitle: pro.valueOrNull?.name,
      backLabel: f.t('common.back'),
      onBack: () => aqBack(context, '/build/pro/${widget.id}'),
      children: [
        if (pro.valueOrNull?.rating case final r?) ...[
          Row(
            children: [
              Text(
                VFmt.dec(context, r, digits: 1),
                style: AQTypography.of(context, AQText.displayMedium),
              ),
              const SizedBox(width: AQSpacing.x3),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DbStars(r.round(), size: 20),
                    Text(
                      f.t('pro.reviews', {
                        'n': VFmt.n(context, pro.valueOrNull?.reviewCount ?? 0),
                      }),
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        soft: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AQSpacing.x2),
          Text(
            f.t('db.rev.serverNote'),
            style: AQTypography.of(context, AQText.bodySmall, soft: true),
          ),
          const SizedBox(height: AQSpacing.x4),
        ],
        revs.when(
          loading: () => const DbSkeletonList(count: 3, height: 110),
          error: (e, _) => DbErrorCard(
            error: e,
            onRetry: () => ref.invalidate(dbReviewsProvider(widget.id)),
          ),
          data: (list) {
            if (list.isEmpty)
              return DbNotice(
                f.t(
                  (pro.valueOrNull?.reviewCount ?? 0) > 0
                      ? 'db.rev.textSoon'
                      : 'db.rev.none',
                ),
                icon: 'star',
              );
            final shown = [
              for (final r in list)
                if (_stars == null || r.rating == _stars) r,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DbPillRow(
                  pills: [
                    (
                      f.t('flt.all'),
                      _stars == null,
                      () => setState(() => _stars = null),
                    ),
                    for (final s in [5, 4, 3])
                      (
                        f.t('db.rev.stars', {'n': VFmt.n(context, s)}),
                        _stars == s,
                        () => setState(() => _stars = _stars == s ? null : s),
                      ),
                  ],
                ),
                const SizedBox(height: AQSpacing.x3),
                if (shown.isEmpty)
                  DbNotice(f.t('db.rev.filterEmpty'))
                else
                  for (final r in shown) DbReviewCard(r, about: pro.valueOrNull?.name),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ----------------------------------------------- #65 developer projects list

class DbProjectsScreen extends ConsumerStatefulWidget {
  final String id;
  const DbProjectsScreen({super.key, required this.id});
  @override
  ConsumerState<DbProjectsScreen> createState() => _DbProjectsScreenState();
}

class _DbProjectsScreenState extends ConsumerState<DbProjectsScreen> {
  String? _type;

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final pro = ref.watch(dbProfessionalProvider(widget.id));
    final list = ref.watch(dbApprovedProjectsProvider(widget.id));
    return AQViewingScaffold(
      title: f.t('db.projects.title'),
      subtitle: pro.valueOrNull?.name,
      backLabel: f.t('common.back'),
      onBack: () => aqBack(context, '/build/pro/${widget.id}'),
      children: [
        list.when(
          loading: () => const DbSkeletonList(count: 3, height: 96),
          error: (e, _) => DbErrorCard(
            error: e,
            onRetry: () =>
                ref.invalidate(dbApprovedProjectsProvider(widget.id)),
          ),
          data: (all) {
            if (all.isEmpty)
              return DbNotice(f.t('db.noProjects'), icon: 'development');
            final types = {for (final x in all) x.propertyType};
            final shown = [
              for (final x in all)
                if (_type == null || x.propertyType.name == _type) x,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (types.length > 1) ...[
                  DbPillRow(
                    pills: [
                      (
                        f.t('flt.all'),
                        _type == null,
                        () => setState(() => _type = null),
                      ),
                      for (final t in types)
                        (
                          dbTypeLabel(f, t),
                          _type == t.name,
                          () => setState(
                            () => _type = _type == t.name ? null : t.name,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AQSpacing.x3),
                ],
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                    child: Text(
                      dbProjectsCount(context, f, shown.length),
                      style: AQTypography.of(context, AQText.titleSmall),
                    ),
                  ),
                ),
                for (final x in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                    child: DbProjectCard(
                      project: x,
                      onTap: () => context.push('/build/project/${x.id}'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ------------------------------------------------------- #66 project detail

class DbProjectDetailScreen extends ConsumerWidget {
  final String id;
  const DbProjectDetailScreen({super.key, required this.id});

  Widget _fact(
    BuildContext context,
    AQColors c,
    String icon,
    String value,
    String label,
  ) => Container(
    width: 104,
    padding: const EdgeInsets.all(AQSpacing.x3),
    decoration: BoxDecoration(
      color: c.surfaceRaised,
      borderRadius: BorderRadius.circular(AQRadius.medium),
      border: Border.all(color: c.hairline),
    ),
    child: Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        children: [
          DbIcon(icon, size: 20, color: c.accent),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: AQTypography.of(context, AQText.titleSmall),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AQTypography.of(context, AQText.labelSmall, soft: true),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(dbPublicProjectProvider(id));
    void back() => aqBack(context, '/app/explore/build');
    return async.when(
      loading: () => AQViewingScaffold(
        backLabel: f.t('common.back'),
        onBack: back,
        children: const [
          DbSkeleton(height: 120),
          SizedBox(height: AQSpacing.x4),
          DbSkeleton(height: 160),
        ],
      ),
      error: (e, _) => AQViewingScaffold(
        backLabel: f.t('common.back'),
        onBack: back,
        children: [
          DbErrorCard(
            error: e,
            onRetry: () => ref.invalidate(dbPublicProjectProvider(id)),
          ),
        ],
      ),
      data: (p) {
        if (p == null)
          return dbMissingFrame(
            context,
            title: f.t('db.notFound.t'),
            body: f.t('db.notFound.project'),
            onBack: back,
          );
        final dev = ref.watch(dbProfessionalProvider(p.orgId)).valueOrNull;
        final facts = <Widget>[
          _fact(
            context,
            c,
            'home',
            dbTypeLabel(f, p.propertyType),
            f.t('db.fact.type'),
          ),
          if (p.bedrooms != null)
            _fact(
              context,
              c,
              'bed',
              VFmt.n(context, p.bedrooms!),
              f.t('db.f.beds'),
            ),
          if (p.bathrooms != null)
            _fact(
              context,
              c,
              'bath',
              VFmt.n(context, p.bathrooms!),
              f.t('db.f.baths'),
            ),
          if (p.areaSqm != null)
            _fact(
              context,
              c,
              'area',
              '${VFmt.n(context, p.areaSqm!.round())} m²',
              f.t('db.fact.built'),
            ),
          if (p.landSqm != null)
            _fact(
              context,
              c,
              'area',
              '${VFmt.n(context, p.landSqm!.round())} m²',
              f.t('db.fact.land'),
            ),
        ];
        return AQViewingScaffold(
          title: VFmt.iso(p.name),
          subtitle: p.locationLabel,
          backLabel: f.t('common.back'),
          onBack: () => aqBack(context, '/build/pro/${p.orgId}'),
          bottom: AQBottomActionBar(
            footnote: dev != null && !dbHasContact(dev)
                ? f.t('db.contact.none')
                : null,
            primary: AQPrimaryButton(
              label: f.t('db.contactDev'),
              trailingChevron: false,
              leadingIcon: 'phone',
              onPressed: dev != null && dbHasContact(dev)
                  ? () => aqRequireSession(
                      context,
                      ref,
                      actionKey: 'db.a.contact',
                      go: () => showDbContactSheet(context, ref, dev),
                    )
                  : null,
            ),
          ),
          children: [
            if (dev != null)
              Semantics(
                button: true,
                label: '${f.t('db.developedBy')} ${dev.name}',
                excludeSemantics: true,
                child: AQPressable(
                  onTap: () => context.push('/build/pro/${dev.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(AQSpacing.x3),
                    decoration: BoxDecoration(
                      color: c.surfaceRaised,
                      borderRadius: BorderRadius.circular(AQRadius.medium),
                      border: Border.all(color: c.hairline),
                    ),
                    child: Row(
                      children: [
                        AQIcon('development', size: 22, color: c.accent),
                        const SizedBox(width: AQSpacing.x3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.t('db.developedBy'),
                                style: AQTypography.of(
                                  context,
                                  AQText.labelSmall,
                                  soft: true,
                                ),
                              ),
                              Text(
                                VFmt.iso(dev.name),
                                style: AQTypography.of(
                                  context,
                                  AQText.titleSmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (dev.verified)
                          AQIcon('verified', size: 18, color: c.accent),
                        const SizedBox(width: 4),
                        AQIcon(
                          'chevron-right',
                          size: 18,
                          color: c.inkSoft,
                          directional: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AQSpacing.x4),
            Wrap(
              spacing: AQSpacing.x2,
              runSpacing: AQSpacing.x2,
              children: facts,
            ),
            if (p.mediaUrls.isNotEmpty) ...[
              DbSectionTitle(
                f.t('db.gallery'),
                action: f.t('pt.viewAll'),
                onAction: () => context.push('/build/project/${p.id}/gallery'),
              ),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: p.mediaUrls.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AQSpacing.x2),
                  itemBuilder: (_, i) => Semantics(
                    button: true,
                    label: f.t('db.photoOf', {
                      'a': VFmt.n(context, i + 1),
                      'b': VFmt.n(context, p.mediaUrls.length),
                    }),
                    excludeSemantics: true,
                    child: AQPressable(
                      onTap: () =>
                          context.push('/build/project/${p.id}/gallery?i=$i'),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AQRadius.medium),
                        child: SizedBox(
                          width: 150,
                          child: aqImg(p.mediaUrls[i], cacheWidth: 400),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: AQSpacing.x4),
              DbNotice(f.t('db.gallery.none'), icon: 'info'),
            ],
            DbSectionTitle(f.t('db.location')),
            if (p.latitude != null && p.longitude != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AQRadius.large),
                child: SizedBox(
                  height: aqLargeText(context) ? 300 : 190,
                  child: AqaratiMapView(
                    initialCenter: LatLng(p.latitude!, p.longitude!),
                    initialZoom: 14,
                    interactive: false,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              )
            else
              DbNotice(f.t('db.map.noneProject'), icon: 'pin'),
            const SizedBox(height: AQSpacing.x2),
            Text(
              VFmt.iso(p.locationLabel),
              style: AQTypography.of(context, AQText.bodySmall, soft: true),
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------ #67 gallery

class DbGalleryScreen extends ConsumerStatefulWidget {
  final String id;
  final int initial;
  const DbGalleryScreen({super.key, required this.id, this.initial = 0});
  @override
  ConsumerState<DbGalleryScreen> createState() => _DbGalleryScreenState();
}

class _DbGalleryScreenState extends ConsumerState<DbGalleryScreen> {
  late final _ctl = PageController(initialPage: widget.initial);
  late int _i = widget.initial;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final async = ref.watch(dbPublicProjectProvider(widget.id));
    void back() => aqBack(context, '/build/project/${widget.id}');
    return async.when(
      loading: () => AQViewingScaffold(
        backLabel: f.t('common.back'),
        onBack: back,
        children: const [DbSkeleton(height: 320)],
      ),
      error: (e, _) => AQViewingScaffold(
        backLabel: f.t('common.back'),
        onBack: back,
        children: [
          DbErrorCard(
            error: e,
            onRetry: () => ref.invalidate(dbPublicProjectProvider(widget.id)),
          ),
        ],
      ),
      data: (p) {
        if (p == null)
          return dbMissingFrame(
            context,
            title: f.t('db.notFound.t'),
            body: f.t('db.notFound.project'),
            onBack: back,
          );
        if (p.mediaUrls.isEmpty)
          return dbMissingFrame(
            context,
            title: p.name,
            body: f.t('db.gallery.none'),
            onBack: back,
          );
        final n = p.mediaUrls.length;
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _ctl,
                  itemCount: n,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (_, i) => Semantics(
                    image: true,
                    label: f.t('db.photoOf', {
                      'a': VFmt.n(context, i + 1),
                      'b': VFmt.n(context, n),
                    }),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.asset(
                        p.mediaUrls[i],
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Center(
                          child: Text(
                            f.t('db.gallery.error'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 4,
                  start: 4,
                  child: AQIconButton(
                    icon: 'close',
                    semanticsLabel: f.t('common.close'),
                    directional: false,
                    color: Colors.white,
                    onPressed: back,
                  ),
                ),
                PositionedDirectional(
                  top: 14,
                  end: 16,
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${VFmt.n(context, _i + 1)}/${VFmt.n(context, n)}',
                      style: AQTypography.of(
                        context,
                        AQText.labelMedium,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
