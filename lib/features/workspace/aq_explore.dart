import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../search/aq_filters.dart';
import '../viewing/widgets/viewing_format.dart';
import 'aq_home.dart';

/// Explore is a directory of what AQARATI offers: each area has its own banner and
/// a row of shortcuts, in contrast to Home's featured listings.
class AQExploreScreen extends StatelessWidget {
  const AQExploreScreen({super.key});

  Widget _iconTiles(BuildContext context, List<(String image, String icon, String label, VoidCallback onTap)> tiles) {
    final c = AQColors.of(context);
    final cols = aqLargeText(context) ? 2 : 4;
    return LayoutBuilder(builder: (context, box) {
      const gap = AQSpacing.x2;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final t in tiles)
          SizedBox(
            width: w,
            child: Semantics(
              button: true,
              label: t.$3,
              excludeSemantics: true,
              child: AQPressable(
                onTap: () {
                  AQHaptics.selection();
                  t.$4();
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AQRadius.medium),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      AspectRatio(aspectRatio: 1.15, child: ExcludeSemantics(child: aqImg(t.$1, cacheWidth: 360))),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AQSpacing.x2, AQSpacing.x2, AQSpacing.x2, AQSpacing.x2),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            AQIcon(t.$2, size: 16, color: c.accent),
                            const SizedBox(width: 4),
                            Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(t.$3, maxLines: 1, style: AQTypography.of(context, AQText.labelMedium)))),
                          ]),
                          const SizedBox(height: 2),
                          Align(alignment: AlignmentDirectional.centerEnd, child: AQIcon('chevron-right', size: 16, color: c.inkSoft, directional: true)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    void go(String path) => context.push(path);
    return aqPage(
      context,
      hero: AQHero(
        image: 'assets/location/13_Old_Muscat_architectural_view.jpg',
        eyebrow: f.t('explore.eyebrow'),
        title: f.t('explore.hero'),
        sub: f.t('explore.hero.sub'),
      ),
      children: [
        AQSearchEntry(hint: f.t('home.search.hint')),
        const SizedBox(height: AQSpacing.x5),
        AQBanner(
          image: 'assets/properties/p1/08_Contemporary_villa_front_facade_.jpg',
          eyebrow: f.t('ex.props.eyebrow'),
          title: f.t('ex.props.t'),
          body: f.t('ex.props.b'),
          cta: f.t('ex.props.cta'),
          onTap: () => go('/properties'),
        ),
        const SizedBox(height: AQSpacing.x3),
        _iconTiles(context, [
          (PropCategory.residential.image, 'home', f.t('cat.residential'), () => go('/properties?cat=residential')),
          (PropCategory.commercial.image, 'development', f.t('cat.commercial'), () => go('/properties?cat=commercial')),
          (PropCategory.agriculture.image, 'globe', f.t('cat.agriculture'), () => go('/properties?cat=agriculture')),
          (PropCategory.industrial.image, 'construction', f.t('cat.industrial'), () => go('/properties?cat=industrial')),
        ]),
        const SizedBox(height: AQSpacing.x6),
        AQBanner(
          image: 'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg',
          eyebrow: f.t('ex.dev.eyebrow'),
          title: f.t('ex.dev.t'),
          body: f.t('ex.dev.b'),
          cta: f.t('ex.dev.cta'),
          onTap: () => go('/app/explore/build'),
        ),
        const SizedBox(height: AQSpacing.x3),
        _iconTiles(context, [
          ('assets/businesses/b1/05_Contemporary_architectural_facad.jpg', 'development', f.t('pro.developers'), () => go('/app/explore/build/results?cat=developer')),
          ('assets/businesses/b2/05_Construction_site_with_tower_crane.jpg', 'construction', f.t('pro.construction'), () => go('/app/explore/build/results?cat=construction')),
          ('assets/businesses/b1/08_Doubleheight_atrium_architectur.jpg', 'architecture', f.t('pro.architecture'), () => go('/app/explore/build/results?cat=architecture')),
          ('assets/businesses/b3/06_Styled_bedroom_interior_photography.jpg', 'interior', f.t('pro.interior'), () => go('/app/explore/build/results?cat=interiorExterior')),
        ]),
        const SizedBox(height: AQSpacing.x6),
        AQBanner(
          image: 'assets/location/10_Muscat_corniche_at_warm_evening.jpg',
          eyebrow: f.t('ex.broker.eyebrow'),
          title: f.t('ex.broker.t'),
          body: f.t('ex.broker.b'),
          cta: f.t('ex.broker.cta'),
          onTap: () => go('/brokers'),
        ),
        AQSectionHeader(f.t('home.maint'), sub: f.t('ex.maint.sub'), action: f.t('explore.exploreAll'), onAction: () => go('/professionals?cat=maintenance'), help: 'maintenance'),
        _iconTiles(context, [
          ('assets/businesses/b4/03_Plumbing_maintenance_under_sink.jpg', 'construction', f.t('maint.plumber'), () => go('/professionals?cat=maintenance')),
          ('assets/properties/p1/02_Infinity_pool_overlooking_marina.jpg', 'sunrise', f.t('maint.pool'), () => go('/professionals?cat=maintenance')),
          ('assets/businesses/b4/05_Technician_servicing_air_conditi.jpg', 'sun', f.t('maint.ac'), () => go('/professionals?cat=maintenance')),
          ('assets/properties/p1/16_Contemporary_kitchen_interior_ar.jpg', 'home', f.t('maint.kitchen'), () => go('/professionals?cat=maintenance')),
        ]),
        const SizedBox(height: AQSpacing.x6),
        AQBanner(
          image: 'assets/properties/p5/03_Contemporary_apartment_property_.jpg',
          eyebrow: f.t('ex.loan.eyebrow'),
          title: f.t('ex.loan.t'),
          body: f.t('ex.loan.b'),
          cta: f.t('ex.loan.cta'),
          onTap: () => go('/calculators'),
        ),
      ],
    );
  }
}
