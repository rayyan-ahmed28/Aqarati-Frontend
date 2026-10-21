import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/enums.dart';
import '../viewing/widgets/viewing_format.dart';
import '../workspace/aq_home.dart';
import 'aq_filters.dart';

String _catIcon(PropCategory k) => switch (k) {
  PropCategory.residential => 'home',
  PropCategory.commercial => 'development',
  PropCategory.agriculture => 'globe',
  PropCategory.industrial => 'construction',
};

/// Sub-types shown once a category is picked: (type, photo).
List<(PropertyType, String)> _subTypes(PropCategory k) => switch (k) {
  PropCategory.residential => const [
    (
      PropertyType.villa,
      'assets/properties/p1/08_Contemporary_villa_front_facade_.jpg',
    ),
    (
      PropertyType.apartment,
      'assets/properties/p5/03_Contemporary_apartment_property_.jpg',
    ),
    (
      PropertyType.residentialLand,
      'assets/properties/p3/05_Vacant_plot_facing_distant_hills.jpg',
    ),
  ],
  PropCategory.commercial => const [
    (
      PropertyType.office,
      'assets/properties/p6/04_Modern_commercial_building_exterior.jpg',
    ),
    (
      PropertyType.shop,
      'assets/properties/p6/05_Rear_utility_area_of_shop.jpg',
    ),
    (
      PropertyType.showroom,
      'assets/properties/p6/04_Modern_commercial_building_exterior.jpg',
    ),
  ],
  PropCategory.agriculture => const [
    (
      PropertyType.agriculturalLand,
      'assets/properties/p3/05_Vacant_plot_facing_distant_hills.jpg',
    ),
    (
      PropertyType.farm,
      'assets/location/05_Desert_landscape_with_rugged_mou.jpg',
    ),
  ],
  PropCategory.industrial => const [
    (
      PropertyType.warehouse,
      'assets/properties/p6/05_Rear_utility_area_of_shop.jpg',
    ),
    (
      PropertyType.industrial,
      'assets/properties/p6/05_Rear_utility_area_of_shop.jpg',
    ),
  ],
};

/// First step of browsing properties: what kind, then what for.
class AQPropertyTypesScreen extends StatefulWidget {
  const AQPropertyTypesScreen({super.key});
  @override
  State<AQPropertyTypesScreen> createState() => _AQPropertyTypesScreenState();
}

class _AQPropertyTypesScreenState extends State<AQPropertyTypesScreen> {
  PropCategory _sel = PropCategory.residential;

  String _typeLabel(FlowStrings f, PropertyType t) =>
      FlowStrings.keys.contains('ptype.${t.name}')
      ? f.t('ptype.${t.name}')
      : t.label;

  Widget _card(BuildContext context, FlowStrings f, PropCategory k, double w) {
    final c = AQColors.of(context);
    final large = aqLargeText(context);
    final on = k == _sel;
    return SizedBox(
      width: w,
      child: Semantics(
        button: true,
        selected: on,
        label: '${f.t(k.key)}. ${f.t('pt.c.${k.name}')}',
        excludeSemantics: true,
        child: AQPressable(
          onTap: () {
            AQHaptics.selection();
            setState(() => _sel = k);
          },
          child: AnimatedContainer(
            duration: AQMotion.scaled(context, AQMotion.fast),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: BorderRadius.circular(AQRadius.medium),
              border: Border.all(
                color: on ? c.accent : c.hairline,
                width: on ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AQRadius.medium - 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1.45,
                    child: ExcludeSemantics(
                      child: aqImg(k.image, cacheWidth: 380),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AQSpacing.x3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AQIcon(_catIcon(k), size: 22, color: c.accent),
                        const SizedBox(height: AQSpacing.x1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            f.t(k.key),
                            maxLines: 1,
                            style: AQTypography.of(context, AQText.titleSmall),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(minHeight: large ? 0 : 54),
                          child: Text(
                            f.t('pt.c.${k.name}'),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: AQTypography.of(
                              context,
                              AQText.bodySmall,
                              soft: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: AQSpacing.x2),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: on ? c.accent : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: on ? c.accent : c.hairline,
                              ),
                            ),
                            child: Center(
                              child: AQIcon(
                                'chevron-right',
                                size: 16,
                                color: on ? c.onAccent : c.inkSoft,
                                directional: true,
                              ),
                            ),
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
      ),
    );
  }

  Widget _goal(
    BuildContext context,
    FlowStrings f,
    String icon,
    String label,
    String sub,
    String path,
  ) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      label: '$label. $sub',
      excludeSemantics: true,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          context.push(path);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(AQSpacing.x3),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            border: Border.all(color: c.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AQIcon(icon, size: 24, color: c.accent),
                  const Spacer(),
                  AQIcon(
                    'chevron-right',
                    size: 16,
                    color: c.inkSoft,
                    directional: true,
                  ),
                ],
              ),
              const SizedBox(height: AQSpacing.x2),
              Text(label, style: AQTypography.of(context, AQText.titleSmall)),
              Text(
                sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AQTypography.of(context, AQText.labelSmall, soft: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final large = aqLargeText(context);
    final subs = _subTypes(_sel);
    return Scaffold(
      backgroundColor: c.background,
      body: aqPage(
        context,
        hero: AQHero(
          image: 'assets/properties/p1/08_Contemporary_villa_front_facade_.jpg',
          eyebrow: f.t('pt.eyebrow'),
          title: f.t('pt.title'),
          sub: f.t('pt.sub'),
          onBack: () => aqBack(context, '/app/explore'),
        ),
        children: [
          AQSearchEntry(hint: f.t('props.search')),
          const SizedBox(height: AQSpacing.x4),
          LayoutBuilder(
            builder: (context, box) {
              const gap = AQSpacing.x2;
              // Four cards in one row leave ~80 px each; two by two gives every description room to read.
              const cols = 2;
              final w = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final k in PropCategory.values) _card(context, f, k, w),
                ],
              );
            },
          ),
          const SizedBox(height: AQSpacing.x5),
          AnimatedSwitcher(
            duration: AQMotion.scaled(context, AQMotion.standard),
            child: Container(
              key: ValueKey(_sel),
              padding: const EdgeInsets.all(AQSpacing.x3),
              decoration: BoxDecoration(
                color: c.surfaceRaised,
                borderRadius: BorderRadius.circular(AQRadius.large),
                border: Border.all(color: c.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c.surfaceSelected,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: AQIcon(
                            _catIcon(_sel),
                            size: 22,
                            color: c.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: AQSpacing.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                f.t('pt.section', {'c': f.t(_sel.key)}),
                                style: AQTypography.of(
                                  context,
                                  AQText.titleLarge,
                                ),
                              ),
                            ),
                            Text(
                              f.t('pt.sec.${_sel.name}'),
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
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AQTextButton(
                      label: f.t('pt.viewAll'),
                      color: c.accentDeep,
                      trailingIcon: 'chevron-right',
                      onPressed: () =>
                          context.push('/properties/all?cat=${_sel.name}'),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, box) {
                      const gap = AQSpacing.x2;
                      final cols = large ? 2 : 3;
                      final w = (box.maxWidth - gap * (cols - 1)) / cols;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final s in subs)
                            SizedBox(
                              width: w,
                              child: Semantics(
                                button: true,
                                label: _typeLabel(f, s.$1),
                                excludeSemantics: true,
                                child: AQPressable(
                                  onTap: () {
                                    AQHaptics.selection();
                                    context.push(
                                      '/properties/all?types=${s.$1.name}',
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AQRadius.medium,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: c.surface,
                                        border: Border.all(color: c.hairline),
                                        borderRadius: BorderRadius.circular(
                                          AQRadius.medium,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          AspectRatio(
                                            aspectRatio: 1.25,
                                            child: ExcludeSemantics(
                                              child: aqImg(
                                                s.$2,
                                                cacheWidth: 320,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AQSpacing.x2,
                                              vertical: AQSpacing.x2,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        AlignmentDirectional
                                                            .centerStart,
                                                    child: Text(
                                                      _typeLabel(f, s.$1),
                                                      maxLines: 1,
                                                      style: AQTypography.of(
                                                        context,
                                                        AQText.labelMedium,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                AQIcon(
                                                  'chevron-right',
                                                  size: 14,
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
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AQSpacing.x5),
          Semantics(
            header: true,
            child: Text(
              f.t('explore.todo'),
              style: AQTypography.of(context, AQText.headlineMedium),
            ),
          ),
          Text(
            f.t('pt.todo.sub'),
            style: AQTypography.of(context, AQText.bodySmall, soft: true),
          ),
          const SizedBox(height: AQSpacing.x3),
          large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _goal(
                      context,
                      f,
                      'home',
                      f.t('home.buy'),
                      f.t('pt.buy.s'),
                      '/properties/all?tx=buy',
                    ),
                    const SizedBox(height: AQSpacing.x2),
                    _goal(
                      context,
                      f,
                      'calendar',
                      f.t('home.rent'),
                      f.t('pt.rent.s'),
                      '/properties/all?tx=rent',
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _goal(
                        context,
                        f,
                        'home',
                        f.t('home.buy'),
                        f.t('pt.buy.s'),
                        '/properties/all?tx=buy',
                      ),
                    ),
                    const SizedBox(width: AQSpacing.x2),
                    Expanded(
                      child: _goal(
                        context,
                        f,
                        'calendar',
                        f.t('home.rent'),
                        f.t('pt.rent.s'),
                        '/properties/all?tx=rent',
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: AQSpacing.x5),
          AQBanner(
            image: 'assets/location/09_Modern_villa_exterior_in_Seeb.jpg',
            title: f.t('pt.sell.t'),
            body: f.t('pt.sell.b'),
            cta: f.t('pt.sell.cta'),
            onTap: () => context.push('/sell'),
          ),
        ],
      ),
    );
  }
}
