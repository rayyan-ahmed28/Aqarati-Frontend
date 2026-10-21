import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../help/help.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/config/maps_config.dart';
import '../../core/domain/account_models.dart';
import '../../core/localization/flow_strings.dart';
import '../../core/widgets/aqarati_map_view.dart';
import '../search/aq_map.dart' show AQViewToggle;
import '../search/aq_search.dart' show AQQueryField;
import '../viewing/widgets/viewing_format.dart';
import '../workspace/aq_home.dart' show AQBanner, AQHero, aqImg, aqPage;
import 'db_models.dart';
import 'db_repository.dart';
import 'db_widgets.dart';

const _heroImage =
    'assets/businesses/b1/05_Contemporary_architectural_facad.jpg';

String dbResultsPath({
  ProType? type,
  String? q,
  String? gov,
  InteriorExteriorServiceType? svc,
  bool map = false,
}) {
  final p = <String, String>{
    if (type != null) 'cat': type.name,
    if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    if (gov != null) 'gov': gov,
    if (svc != null) 'svc': svc.name,
    if (map) 'view': 'map',
  };
  return Uri(
    path: '/app/explore/build/results',
    queryParameters: p.isEmpty ? null : p,
  ).toString();
}

// ------------------------------------------------------------------ #59 home

class DbHomeScreen extends ConsumerStatefulWidget {
  const DbHomeScreen({super.key});
  @override
  ConsumerState<DbHomeScreen> createState() => _DbHomeScreenState();
}

class _DbHomeScreenState extends ConsumerState<DbHomeScreen> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _search(String v) => context.push(dbResultsPath(q: v));

  Widget _tiles(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final cols = aqLargeText(context) ? 2 : 4;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = AQSpacing.x2;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in ProType.values)
              SizedBox(
                width: w,
                child: Semantics(
                  button: true,
                  label: f.t('${t.key}.long'),
                  excludeSemantics: true,
                  child: AQPressable(
                    onTap: () {
                      AQHaptics.selection();
                      context.push(dbResultsPath(type: t));
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.surfaceRaised,
                        borderRadius: BorderRadius.circular(AQRadius.medium),
                        border: Border.all(color: c.hairline),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AQRadius.medium),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AspectRatio(
                              aspectRatio: 1.05,
                              child: ExcludeSemantics(
                                child: aqImg(dbTypeImage(t), cacheWidth: 360),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AQSpacing.x2),
                              child: Column(
                                children: [
                                  AQIcon(t.icon, size: 20, color: c.accent),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      f.t('${t.key}.tile'),
                                      textAlign: TextAlign.center,
                                      style:
                                          AQTypography.of(
                                            context,
                                            AQText.bodySmall,
                                          ).copyWith(
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  AQIcon(
                                    'chevron-right',
                                    size: 16,
                                    color: c.inkSoft,
                                    directional: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final featured = ref.watch(dbFeaturedProvider);
    final pros = ref.watch(dbProfessionalsProvider((const DbQuery(), 6)));
    return aqPage(
      context,
      hero: AQHero(
        showLocation: false,
        image: _heroImage,
        eyebrow: f.t('db.eyebrow'),
        title: f.t('db.home.title'),
        sub: f.t('db.home.sub'),
        onBack: () => aqBack(context, '/app/explore'),
      ),
      children: [
        Row(children: [Expanded(child: Text(f.t('help.devBuild.s'), style: AQTypography.of(context, AQText.bodySmall, soft: true))), const AQHelpButton('devBuild')]),
        AQQueryField(
          controller: _ctl,
          hint: f.t('db.search.hint'),
          onChanged: (_) => setState(() {}),
          onSubmitted: _search,
        ),
        const SizedBox(height: AQSpacing.x4),
        _tiles(context),
        // Featured development: only from approved project data. Hidden when there is none.
        if (featured.valueOrNull case final fe?) ...[
          const SizedBox(height: AQSpacing.x6),
          AQBanner(
            image: fe.$1.cover ?? _heroImage,
            eyebrow: f.t('db.featured'),
            title: fe.$2.name,
            body: '${fe.$1.name} · ${fe.$2.locationLabel}',
            cta: f.t('db.exploreProject'),
            onTap: () => context.push('/build/project/${fe.$2.id}'),
          ),
        ],
        DbSectionTitle(
          f.t('db.verifiedPros'),
          action: f.t('pt.viewAll'),
          onAction: () => context.push(dbResultsPath()),
        ),
        Text(
          f.t('db.verifiedPros.sub'),
          style: AQTypography.of(context, AQText.bodyMedium, soft: true),
        ),
        const SizedBox(height: AQSpacing.x3),
        pros.when(
          loading: () => const DbSkeleton(height: 190),
          error: (e, _) => DbErrorCard(
            error: e,
            onRetry: () => ref.invalidate(dbProfessionalsProvider),
          ),
          data: (page) => page.items.isEmpty
              ? DbNotice(f.t('db.noneYet'), icon: 'info')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final p in page.items) ...[
                          _MiniProCard(pro: p),
                          const SizedBox(width: AQSpacing.x3),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: AQSpacing.x6),
        AQBanner(
          image: 'assets/businesses/b1/02_Architectural_lattice_screen_cas.jpg',
          title: f.t('db.band.t'),
          body: f.t('db.band.b'),
          cta: f.t('db.band.cta'),
          onTap: () => context.push('/app/explore/build/categories'),
        ),
      ],
    );
  }
}

class _MiniProCard extends StatelessWidget {
  final DbProfessional pro;
  const _MiniProCard({required this.pro});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    return Semantics(
      button: true,
      label: '${pro.name}, ${dbProLabel(f, pro)}, ${pro.locationLabel}',
      excludeSemantics: true,
      child: AQPressable(
        onTap: () => context.push('/build/pro/${pro.id}'),
        child: Container(
          width: 232,
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQRadius.large),
            border: Border.all(color: c.hairline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AQRadius.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 96,
                  child: ExcludeSemantics(
                    child: pro.cover == null
                        ? ColoredBox(color: c.surfaceSelected)
                        : aqImg(pro.cover!, cacheWidth: 520),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AQSpacing.x3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              VFmt.iso(pro.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AQTypography.of(
                                context,
                                AQText.titleSmall,
                              ),
                            ),
                          ),
                          if (pro.verified) ...[
                            const SizedBox(width: 4),
                            AQIcon('verified', size: 15, color: c.accent),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      DbRating(rating: pro.rating, count: pro.reviewCount),
                      const SizedBox(height: 2),
                      Text(
                        dbProLabel(f, pro),
                        style: AQTypography.of(
                          context,
                          AQText.bodySmall,
                          soft: true,
                        ),
                      ),
                      Text(
                        VFmt.iso(pro.locationLabel),
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
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ #60 categories

class DbCategoriesScreen extends StatelessWidget {
  const DbCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final large = aqLargeText(context);
    return aqPage(
      context,
      hero: AQHero(
        showLocation: false,
        image: _heroImage,
        eyebrow: f.t('db.eyebrow'),
        title: f.t('db.cat.title'),
        sub: f.t('db.cat.sub'),
        onBack: () => aqBack(context, '/app/explore/build'),
      ),
      children: [
        for (final t in ProType.values) ...[
          Semantics(
            button: true,
            label: '${f.t('${t.key}.long')}. ${f.t('${t.key}.desc')}',
            excludeSemantics: true,
            child: AQPressable(
              onTap: () => context.push(dbResultsPath(type: t)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AQRadius.large),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    border: Border.all(color: c.hairline),
                    borderRadius: BorderRadius.circular(AQRadius.large),
                  ),
                  child: Stack(
                    children: [
                      PositionedDirectional(
                        end: 0,
                        top: 0,
                        bottom: 0,
                        width: large ? 90 : 150,
                        child: ExcludeSemantics(
                          child: aqImg(dbTypeImage(t), cacheWidth: 500),
                        ),
                      ),
                      PositionedDirectional(
                        end: large ? 90 : 150,
                        top: 0,
                        bottom: 0,
                        width: 70,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: AlignmentDirectional.centerEnd,
                              end: AlignmentDirectional.centerStart,
                              colors: [
                                c.surfaceRaised.withValues(alpha: 0),
                                c.surfaceRaised,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          AQSpacing.x4,
                          AQSpacing.x4,
                          large ? 100 : 160,
                          AQSpacing.x4,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 108),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AQIcon(t.icon, size: 30, color: c.accentDeep),
                              const SizedBox(width: AQSpacing.x3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.t('${t.key}.long'),
                                      style: AQTypography.of(
                                        context,
                                        AQText.headlineSmall,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      f.t('${t.key}.desc'),
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
                        ),
                      ),
                      PositionedDirectional(
                        end: AQSpacing.x3,
                        bottom: AQSpacing.x3,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c.surfaceRaised.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: AQIcon(
                              'chevron-right',
                              size: 18,
                              color: c.ink,
                              directional: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (t == ProType.interiorExterior)
            Padding(
              padding: const EdgeInsets.only(top: AQSpacing.x3),
              child: DbPillRow(
                pills: [
                  for (final s in InteriorExteriorServiceType.values)
                    (
                      f.t('service.${s.name}'),
                      false,
                      () => context.push(
                        dbResultsPath(type: ProType.interiorExterior, svc: s),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AQSpacing.x3),
        ],
        DbNotice(f.t('db.cat.verified'), icon: 'shield'),
      ],
    );
  }
}

// ------------------------------------------------------- #61 / #62 results

class DbResultsScreen extends ConsumerStatefulWidget {
  final DbQuery initial;
  final bool map;
  const DbResultsScreen({super.key, required this.initial, this.map = false});
  @override
  ConsumerState<DbResultsScreen> createState() => _DbResultsScreenState();
}

class _DbResultsScreenState extends ConsumerState<DbResultsScreen> {
  late DbQuery _q = widget.initial;
  late bool _map = widget.map;
  late final _ctl = TextEditingController(text: widget.initial.text);
  int _limit = 10;
  DbPage<DbProfessional>? _last;
  String? _selected;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _set(DbQuery q) => setState(() {
    _q = q;
    _limit = 10;
    _last = null;
    _selected = null;
  });

  Future<void> _pickGov(FlowStrings f) async {
    final all = '__all';
    final r = await showDbChoiceSheet<String>(
      context,
      title: f.t('db.location'),
      selected: _q.governorate ?? all,
      options: [
        (all, f.t('db.allOman')),
        for (final g in omanGovernorates.keys) (g, dbGovLabel(f, g)),
      ],
    );
    if (r == null || !mounted) return;
    _set(r == all ? _q.copyWith(clearGov: true) : _q.copyWith(governorate: r));
  }

  Future<void> _pickSort(FlowStrings f) async {
    final r = await showDbChoiceSheet<DbSort>(
      context,
      title: f.t('db.sort'),
      selected: _q.sort,
      options: [for (final s in DbSort.values) (s, f.t('db.sort.${s.name}'))],
    );
    if (r != null && mounted) _set(_q.copyWith(sort: r));
  }

  Future<void> _pickService(FlowStrings f) async {
    const all = '__all';
    final r = await showDbChoiceSheet<String>(
      context,
      title: f.t('db.filters'),
      selected: _q.serviceType?.name ?? all,
      options: [
        (all, f.t('flt.all')),
        for (final s in InteriorExteriorServiceType.values)
          (s.name, f.t('service.${s.name}')),
      ],
    );
    if (r == null || !mounted) return;
    _set(
      r == all
          ? _q.copyWith(clearService: true)
          : _q.copyWith(
              serviceType: InteriorExteriorServiceType.values.firstWhere(
                (s) => s.name == r,
              ),
            ),
    );
  }

  Widget _control(
    BuildContext context, {
    required String icon,
    required String label,
    int badge = 0,
    required VoidCallback onTap,
  }) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      label: badge > 0 ? '$label, $badge' : label,
      excludeSemantics: true,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: badge > 0 ? c.accent : c.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DbIcon(icon, size: 18, color: c.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AQTypography.of(context, AQText.labelMedium),
                ),
              ),
              const SizedBox(width: 4),
              AQIcon('chevron-down', size: 16, color: c.inkSoft),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final async = ref.watch(dbProfessionalsProvider((_q, _limit)));
    final page = async.valueOrNull ?? _last;
    if (async.hasValue) _last = async.value;
    final type = _q.type;
    final govLabel = _q.governorate == null
        ? f.t('db.allOman')
        : dbGovLabel(f, _q.governorate!);
    final title = type == null
        ? f.t('db.results.all')
        : f.t('${type.key}.long');
    return aqPage(
      context,
      hero: AQHero(
        showLocation: false,
        image: _heroImage,
        eyebrow: f.t('db.eyebrow'),
        title: title,
        sub: type == null ? f.t('db.results.sub') : f.t('${type.key}.tag'),
        onBack: () => aqBack(context, '/app/explore/build/categories'),
      ),
      children: [
        DbPillRow(
          scroll: true,
          pills: [
            (
              f.t('flt.all'),
              type == null,
              () => _set(_q.copyWith(clearType: true, clearService: true)),
            ),
            for (final t in ProType.values)
              (
                f.t('${t.key}.tile'),
                type == t,
                () => _set(
                  _q.copyWith(
                    type: t,
                    clearService: t != ProType.interiorExterior,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AQSpacing.x3),
        AQQueryField(
          controller: _ctl,
          hint: f.t('db.search.hint'),
          onChanged: (_) {},
          onSubmitted: (v) => _set(_q.copyWith(text: v.trim())),
        ),
        const SizedBox(height: AQSpacing.x3),
        Wrap(
          spacing: AQSpacing.x2,
          runSpacing: AQSpacing.x2,
          children: [
            _control(
              context,
              icon: 'pin',
              label: govLabel,
              badge: _q.governorate == null ? 0 : 1,
              onTap: () => _pickGov(f),
            ),
            if (type == ProType.interiorExterior)
              _control(
                context,
                icon: 'filter',
                label: _q.serviceType == null
                    ? f.t('db.filters')
                    : f.t('service.${_q.serviceType!.name}'),
                badge: _q.serviceType == null ? 0 : 1,
                onTap: () => _pickService(f),
              ),
            _control(
              context,
              icon: 'sort',
              label: f.t('db.sort.${_q.sort.name}'),
              onTap: () => _pickSort(f),
            ),
          ],
        ),
        const SizedBox(height: AQSpacing.x3),
        Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  page == null
                      ? ''
                      : f.t(_q.governorate == null ? 'db.count' : 'db.countIn', {
                          'n':
                              '${VFmt.n(context, page.items.length)}${page.hasMore ? '+' : ''}',
                          'g': govLabel,
                        }),
                  style: AQTypography.of(context, AQText.titleSmall),
                ),
              ),
            ),
            AQViewToggle(
              map: _map,
              onList: () => setState(() => _map = false),
              onMap: () => setState(() => _map = true),
            ),
          ],
        ),
        const SizedBox(height: AQSpacing.x3),
        if (page == null && async.isLoading) const DbSkeletonList(),
        if (page == null && async.hasError)
          DbErrorCard(
            error: async.error,
            onRetry: () => ref.invalidate(dbProfessionalsProvider),
          ),
        if (page != null && page.items.isEmpty)
          Column(
            children: [
              DbNotice(f.t('db.empty'), icon: 'search'),
              if (_q.activeFilters > 0 ||
                  _q.text.isNotEmpty ||
                  type != null) ...[
                const SizedBox(height: AQSpacing.x3),
                AQSecondaryButton(
                  label: f.t('flt.clear'),
                  trailingChevron: false,
                  onPressed: () {
                    _ctl.clear();
                    _set(const DbQuery());
                  },
                ),
              ],
            ],
          ),
        if (page != null && page.items.isNotEmpty) ...[
          if (_map)
            _ResultsMap(
              query: _q,
              items: page.items,
              selected: _selected,
              onSelect: (id) => setState(() => _selected = id),
            ),
          for (final p in page.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AQSpacing.x3),
              child: DbProCard(
                pro: p,
                selected: _map && _selected == p.id,
                onTap: _map && _selected != p.id
                    ? () => setState(() => _selected = p.id)
                    : null,
              ),
            ),
          if (page.hasMore)
            AQSecondaryButton(
              label: f.t('db.loadMore'),
              trailingChevron: false,
              loading: async.isLoading,
              onPressed: async.isLoading
                  ? null
                  : () => setState(() => _limit += 10),
            ),
          if (async.hasError)
            Padding(
              padding: const EdgeInsets.only(top: AQSpacing.x3),
              child: DbErrorCard(
                error: async.error,
                onRetry: () => ref.invalidate(dbProfessionalsProvider),
              ),
            ),
        ],
      ],
    );
  }
}

class _ResultsMap extends ConsumerWidget {
  final DbQuery query;
  final List<DbProfessional> items;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _ResultsMap({
    required this.query,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final data = ref.watch(dbMapDataProvider(query));
    final large = aqLargeText(context);
    return data.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: AQSpacing.x3),
        child: DbSkeleton(height: 280),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(bottom: AQSpacing.x3),
        child: DbErrorCard(
          error: e,
          onRetry: () => ref.invalidate(dbMapDataProvider),
        ),
      ),
      data: (d) {
        if (d.points.isEmpty)
          return Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
            child: DbNotice(f.t('db.map.none'), icon: 'pin'),
          );
        final sel =
            d.points.where((p) => p.pro.id == selected).firstOrNull ??
            d.points.first;
        final markers = <Marker>{
          for (final p in d.points)
            Marker(
              markerId: MarkerId('${p.pro.id}:${p.label}'),
              position: LatLng(p.latitude, p.longitude),
              infoWindow: InfoWindow(title: p.label),
              onTap: () => onSelect(p.pro.id),
            ),
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: AQSpacing.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AQRadius.large),
                child: SizedBox(
                  height: large ? 220 : 300,
                  child: Semantics(
                    label: f.t('db.map.label', {
                      'n': VFmt.n(context, d.points.length),
                    }),
                    child: AqaratiMapView(
                      key: kIsWeb
                          ? ValueKey('${sel.pro.id}:${sel.label}')
                          : null,
                      initialCenter: LatLng(sel.latitude, sel.longitude),
                      initialZoom: kIsWeb ? 12 : 10,
                      markers: markers,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              ),
              if (kIsWeb || !kGoogleMapsConfigured)
                Padding(
                  padding: const EdgeInsets.only(top: AQSpacing.x2),
                  child: Text(
                    f.t('db.map.pinsNote'),
                    style: AQTypography.of(
                      context,
                      AQText.bodySmall,
                      soft: true,
                    ),
                  ),
                ),
              if (d.withoutLocation > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AQSpacing.x2),
                  child: Row(
                    children: [
                      AQIcon('info', size: 16, color: c.inkSoft),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          f.t('db.map.missing', {
                            'n': VFmt.n(context, d.withoutLocation),
                          }),
                          style: AQTypography.of(
                            context,
                            AQText.bodySmall,
                            soft: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
