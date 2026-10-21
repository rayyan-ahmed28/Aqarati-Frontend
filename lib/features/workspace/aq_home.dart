import 'package:flutter/material.dart';
import '../help/help.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/enums.dart';
import '../../data/models/property.dart';
import '../../data/repositories/app_state_providers.dart'
    show savedPropertyIdsProvider;
import '../../data/repositories/providers.dart';
import '../entry/widgets/entry_common.dart' show MasterLogo;
import '../search/aq_filter_sheet.dart';
import '../search/aq_filters.dart';
import '../search/aq_map.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';

export '../search/aq_filters.dart' show PropCategory, PropCategoryX;

// ---------------------------------------------------------------- state

/// null = all of Oman.
final homeAreaProvider = StateProvider<String?>((ref) => null);
final homeTxProvider = StateProvider<TransactionType>(
  (ref) => TransactionType.buy,
);
final savedPropertiesProvider = savedPropertyIdsProvider;
final aqAllPropertiesProvider = FutureProvider.autoDispose<List<Property>>(
  (ref) => ref.watch(propertyRepositoryProvider).search(),
);

// ---------------------------------------------------------------- shared pieces

Widget aqImg(
  String asset, {
  int cacheWidth = 500,
  Alignment alignment = Alignment.center,
}) => Image.asset(
  asset,
  fit: BoxFit.cover,
  alignment: alignment,
  cacheWidth: cacheWidth,
  filterQuality: FilterQuality.medium,
  errorBuilder: (_, _, _) => const ColoredBox(color: Color(0x22000000)),
);

/// Top of Home / Explore: a photograph that fades into the page, brand row, title, search.
class AQHero extends StatelessWidget {
  final String image;
  final String? eyebrow;
  final String title;
  final String sub;
  final VoidCallback? onBack;

  /// The property-area chip is a Home/Explore preference; pages it does not filter hide it.
  final bool showLocation;
  const AQHero({
    super.key,
    required this.image,
    this.eyebrow,
    required this.title,
    required this.sub,
    this.onBack,
    this.showLocation = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final bg = c.background;
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: c.isDark ? 0.75 : 1,
                  child: aqImg(
                    image,
                    cacheWidth: 1000,
                    alignment: Alignment.topCenter,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        bg.withValues(alpha: 0.94),
                        bg.withValues(alpha: 0.6),
                        bg.withValues(alpha: 0.05),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bg.withValues(alpha: 0),
                        bg.withValues(alpha: 0),
                        bg,
                      ],
                      stops: const [0, 0.62, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AQSpacing.gutter,
              AQSpacing.x2,
              AQSpacing.gutter,
              AQSpacing.x6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onBack != null)
                      AQIconButton(
                        icon: 'chevron-left',
                        semanticsLabel: f.t('common.back'),
                        onPressed: onBack,
                      )
                    else
                      SizedBox(
                        height: 46,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: MasterLogo(width: 80),
                        ),
                      ),
                    const Spacer(),
                    if (showLocation) ...[
                      const _LocationPill(),
                      const SizedBox(width: AQSpacing.x2),
                    ],
                    Semantics(
                      button: true,
                      label: f.t('nav.account'),
                      excludeSemantics: true,
                      child: AQPressable(
                        onTap: () => context.go('/app/account'),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: c.surfaceRaised,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.hairline),
                          ),
                          child: Center(
                            child: AQIcon(
                              'user',
                              size: 22,
                              color: c.accentDeep,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AQSpacing.x5),
                if (eyebrow != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AQSpacing.x1),
                    child: Text(
                      eyebrow!,
                      style: AQTypography.of(
                        context,
                        AQText.labelSmall,
                        color: c.accentDeep,
                      ),
                    ),
                  ),
                Semantics(
                  header: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 330),
                    child: Text(
                      title,
                      style: AQTypography.of(context, AQText.displaySmall),
                    ),
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: AQSpacing.x2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      sub,
                      style: AQTypography.of(context, AQText.bodyMedium),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationPill extends ConsumerWidget {
  const _LocationPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final area = ref.watch(homeAreaProvider);
    final label = area ?? f.t('home.loc.all');
    return Semantics(
      button: true,
      label: '${f.t('home.loc.title')}: $label',
      excludeSemantics: true,
      child: AQPressable(
        onTap: () => _pickArea(context, ref),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, maxWidth: 170),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AQIcon('pin', size: 16, color: c.accent),
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
}

Future<void> _pickArea(BuildContext context, WidgetRef ref) async {
  final f = FlowStrings.of(context);
  final all = await ref.read(propertyRepositoryProvider).search();
  final areas = {for (final p in all) p.area}.toList()..sort();
  if (!context.mounted) return;
  await showAQSheet<void>(
    context,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AQSpacing.gutter,
            AQSpacing.x2,
            AQSpacing.gutter,
            AQSpacing.x2,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              f.t('home.loc.title'),
              style: AQTypography.of(sheet, AQText.headlineSmall),
            ),
          ),
        ),
        AQSheetRow(
          title: f.t('home.loc.all'),
          selected: ref.read(homeAreaProvider) == null,
          onTap: () {
            ref.read(homeAreaProvider.notifier).state = null;
            Navigator.of(sheet).pop();
          },
        ),
        for (final a in areas)
          AQSheetRow(
            title: a,
            selected: ref.read(homeAreaProvider) == a,
            onTap: () {
              ref.read(homeAreaProvider.notifier).state = a;
              Navigator.of(sheet).pop();
            },
          ),
      ],
    ),
  );
}

class AQSearchEntry extends StatelessWidget {
  final String hint;
  const AQSearchEntry({super.key, required this.hint});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      label: hint,
      excludeSemantics: true,
      child: AQPressable(
        onTap: () => context.push('/search/start'),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AQElevation.floating,
            border: Border.all(color: c.hairline),
          ),
          child: Row(
            children: [
              AQIcon('search', size: 22, color: c.ink),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AQTypography.of(
                    context,
                    AQText.bodyMedium,
                    color: c.inkFaint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AQSectionHeader extends StatelessWidget {
  final String title;
  final String? sub;
  final String? action;
  final VoidCallback? onAction;
  /// Optional contextual help topic: a "?" after the title opens its short explanation.
  final String? help;
  const AQSectionHeader(this.title, {this.sub, this.action, this.onAction, this.help});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: AQTypography.of(context, AQText.headlineMedium),
                ),
              ),
            ),
            if (help != null) AQHelpButton(help!),
          ],
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              sub!,
              style: AQTypography.of(context, AQText.bodySmall, soft: true),
            ),
          ),
      ],
    );
    final button = action == null
        ? null
        : AQTextButton(
            label: action!,
            color: c.accentDeep,
            trailingIcon: 'chevron-right',
            onPressed: onAction,
          );
    // At very large text the action moves under the heading instead of squeezing it.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x6, bottom: AQSpacing.x3),
      child: stacked && button != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, Align(alignment: AlignmentDirectional.centerEnd, child: button)],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: heading), ?button],
            ),
    );
  }
}

/// Square-ish photo tile with a label under it. Four per row; two at large text.
class _TileRow extends StatelessWidget {
  final List<(String image, String label, VoidCallback onTap)> tiles;
  const _TileRow(this.tiles);

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final cols = aqLargeText(context) ? 2 : 4;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = AQSpacing.x2;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in tiles)
              SizedBox(
                width: w,
                child: Semantics(
                  button: true,
                  label: t.$2,
                  excludeSemantics: true,
                  child: AQPressable(
                    onTap: () {
                      AQHaptics.selection();
                      t.$3();
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
                              aspectRatio: 1.1,
                              child: ExcludeSemantics(
                                child: aqImg(t.$1, cacheWidth: 360),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: AQSpacing.x2,
                              ),
                              child: aqLargeText(context)
                                  ? Text(
                                      t.$2,
                                      textAlign: TextAlign.center,
                                      style: AQTypography.of(
                                        context,
                                        AQText.labelMedium,
                                      ),
                                    )
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        t.$2,
                                        maxLines: 1,
                                        style: AQTypography.of(
                                          context,
                                          AQText.labelMedium,
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
              ),
          ],
        );
      },
    );
  }
}

/// Wide photographic banner with a title, line of copy and one pill action.
class AQBanner extends StatelessWidget {
  final String image;
  final String eyebrow, title, body, cta;
  final VoidCallback onTap;
  const AQBanner({
    super.key,
    required this.image,
    this.eyebrow = '',
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AQRadius.large),
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  aqImg(image, cacheWidth: 900),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [
                          c.background.withValues(alpha: 0.95),
                          c.background.withValues(alpha: 0.7),
                          c.background.withValues(alpha: 0.0),
                        ],
                        stops: const [0, 0.5, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AQSpacing.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow.isNotEmpty)
                  Text(
                    eyebrow,
                    style: AQTypography.of(
                      context,
                      AQText.labelSmall,
                      color: c.accentDeep,
                    ),
                  ),
                Text(
                  title,
                  style: AQTypography.of(context, AQText.headlineMedium),
                ),
                const SizedBox(height: AQSpacing.x1),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 210),
                  child: Text(
                    body,
                    style: AQTypography.of(context, AQText.bodySmall),
                  ),
                ),
                const SizedBox(height: AQSpacing.x4),
                Semantics(
                  button: true,
                  label: cta,
                  excludeSemantics: true,
                  child: AQPressable(
                    onTap: onTap,
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AQControl.tap - 4,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AQSpacing.x4,
                      ),
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(AQControl.tap),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              cta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AQTypography.of(
                                context,
                                AQText.labelMedium,
                                color: c.onAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AQIcon(
                            'chevron-right',
                            size: 16,
                            color: c.onAccent,
                            directional: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count, index;
  const _Dots({required this.count, required this.index});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AQMotion.scaled(context, AQMotion.fast),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? c.accent : c.hairline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class AQSlideSwitch extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const AQSlideSwitch({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AQControl.tap),
        border: Border.all(color: c.hairline),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: AQMotion.scaled(context, AQMotion.standard),
              curve: AQMotion.spring,
              alignment: AlignmentDirectional(
                labels.length == 1 ? 0 : -1 + 2 * index / (labels.length - 1),
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / labels.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(AQControl.tap),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: labels[i],
                    excludeSemantics: true,
                    child: AQPressable(
                      onTap: () {
                        AQHaptics.selection();
                        onChanged(i);
                      },
                      pressedScale: 0.97,
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: AQControl.tap - 4,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          labels[i],
                          style: AQTypography.of(
                            context,
                            AQText.labelMedium,
                            color: i == index ? c.onAccent : c.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- featured carousel

class _Featured extends ConsumerStatefulWidget {
  final List<Property> items;
  const _Featured({required this.items});
  @override
  ConsumerState<_Featured> createState() => _FeaturedState();
}

class _FeaturedState extends ConsumerState<_Featured> {
  final _ctl = PageController(viewportFraction: 0.94);
  int _i = 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final saved = ref.watch(savedPropertiesProvider);
    final h = aqLargeText(context) ? 400.0 : 320.0;
    return Column(
      children: [
        SizedBox(
          height: h,
          child: PageView.builder(
            controller: _ctl,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (context, i) {
              final p = widget.items[i];
              final isSaved = saved.contains(p.id);
              final facts = [
                if (p.bedrooms != null)
                  '${VFmt.n(context, p.bedrooms!)} ${f.t('disc.beds')}',
                if (p.bathrooms != null)
                  '${VFmt.n(context, p.bathrooms!)} ${f.t('home.baths')}',
                '${VFmt.n(context, p.areaSqm.round())} m²',
              ];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        button: true,
                        label:
                            '${p.title}, ${p.locationLabel}, ${p.priceLabel}',
                        excludeSemantics: true,
                        child: AQPressable(
                          onTap: () => context.push('/property/${p.id}'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AQRadius.large),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                p.imageUrls.isEmpty
                                    ? const ColoredBox(color: Color(0x33000000))
                                    : aqImg(
                                        p.imageUrls.first,
                                        cacheWidth: 1000,
                                      ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x00000000),
                                        Color(0x00000000),
                                        Color(0xCC1A1613),
                                      ],
                                      stops: [0, 0.4, 1],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: AQSpacing.x4,
                                  top: AQSpacing.x4,
                                  child: _Badge(f.t('home.featuredBadge')),
                                ),
                                Positioned(
                                  left: AQSpacing.x4,
                                  right: AQSpacing.x4,
                                  bottom: AQSpacing.x4,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              VFmt.iso(p.title),
                                              style: AQTypography.of(
                                                context,
                                                AQText.headlineMedium,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const AQIcon(
                                                  'pin',
                                                  size: 14,
                                                  color: Color(0xFFEBDDCB),
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    VFmt.iso(
                                                      p.locationLabel
                                                          .split(',')
                                                          .take(2)
                                                          .join(',')
                                                          .trim(),
                                                    ),
                                                    style: AQTypography.of(
                                                      context,
                                                      AQText.bodySmall,
                                                      color: const Color(
                                                        0xFFEBDDCB,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(
                                              height: AQSpacing.x1,
                                            ),
                                            Text(
                                              p.priceLabel,
                                              style: AQTypography.of(
                                                context,
                                                AQText.titleLarge,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              facts.join('  ·  '),
                                              style: AQTypography.of(
                                                context,
                                                AQText.bodySmall,
                                                color: const Color(0xFFEBDDCB),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AQSpacing.x3),
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AQColors.light.accent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: AQIcon(
                                            'chevron-right',
                                            size: 22,
                                            color: Colors.white,
                                            directional: true,
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
                    PositionedDirectional(
                      end: AQSpacing.x3,
                      top: AQSpacing.x3,
                      child: Semantics(
                        button: true,
                        selected: isSaved,
                        label: isSaved ? f.t('home.unsave') : f.t('home.save'),
                        excludeSemantics: true,
                        child: AQPressable(
                          onTap: () {
                            AQHaptics.confirm();
                            final next = {...saved};
                            isSaved ? next.remove(p.id) : next.add(p.id);
                            ref.read(savedPropertiesProvider.notifier).state =
                                next;
                          },
                          pressedScale: 0.9,
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0x66000000),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: AQHeart(
                                  saved: isSaved,
                                  savedColor: const Color(0xFFE08A78),
                                  idleColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AQSpacing.x3),
        if (widget.items.length > 1)
          _Dots(count: widget.items.length, index: _i),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xAA2D2823),
      borderRadius: BorderRadius.circular(AQRadius.small),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AQSpacing.x3,
        vertical: 6,
      ),
      child: Text(
        text,
        style: AQTypography.of(
          context,
          AQText.labelSmall,
          color: const Color(0xFFF1E8DB),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- reusable sections

List<Widget> _developmentSection(BuildContext context) {
  final f = FlowStrings.of(context);
  void go() => context.push('/app/explore/build');
  return [
    AQSectionHeader(
      f.t('home.dev'),
      sub: f.t('home.dev.sub'),
      action: f.t('explore.exploreAll'),
      onAction: go,
      help: 'devBuild',
    ),
    _TileRow([
      (
        'assets/businesses/b1/05_Contemporary_architectural_facad.jpg',
        f.t('pro.developers'),
        () => context.push('/app/explore/build/results?cat=developer'),
      ),
      (
        'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg',
        f.t('pro.construction'),
        () => context.push('/app/explore/build/results?cat=construction'),
      ),
      (
        'assets/businesses/b1/08_Doubleheight_atrium_architectur.jpg',
        f.t('pro.architecture'),
        () => context.push('/app/explore/build/results?cat=architecture'),
      ),
      (
        'assets/businesses/b3/06_Styled_bedroom_interior_photography.jpg',
        f.t('pro.interior'),
        () => context.push('/app/explore/build/results?cat=interiorExterior'),
      ),
    ]),
  ];
}

List<Widget> _maintenanceSection(BuildContext context) {
  final f = FlowStrings.of(context);
  void go() => context.push('/professionals');
  return [
    AQSectionHeader(
      f.t('home.maint'),
      sub: f.t('home.maint.sub'),
      action: f.t('explore.exploreAll'),
      onAction: go,
      help: 'maintenance',
    ),
    _TileRow([
      (
        'assets/businesses/b4/03_Plumbing_maintenance_under_sink.jpg',
        f.t('maint.plumber'),
        () => context.push('/professionals?cat=maintenance'),
      ),
      (
        'assets/properties/p1/02_Infinity_pool_overlooking_marina.jpg',
        f.t('maint.pool'),
        () => context.push('/professionals?cat=maintenance'),
      ),
      (
        'assets/businesses/b4/05_Technician_servicing_air_conditi.jpg',
        f.t('maint.ac'),
        () => context.push('/professionals?cat=maintenance'),
      ),
      (
        'assets/properties/p1/16_Contemporary_kitchen_interior_ar.jpg',
        f.t('maint.kitchen'),
        () => context.push('/professionals?cat=maintenance'),
      ),
    ]),
  ];
}

Widget _brokerLoan(BuildContext context) {
  final f = FlowStrings.of(context);
  final c = AQColors.of(context);
  Widget card(String image, String title, String body, VoidCallback onTap) =>
      Semantics(
        button: true,
        label: '$title. $body',
        excludeSemantics: true,
        child: AQPressable(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AQRadius.medium),
            child: Container(
              constraints: const BoxConstraints(minHeight: 130),
              decoration: BoxDecoration(
                color: c.surfaceRaised,
                border: Border.all(color: c.hairline),
                borderRadius: BorderRadius.circular(AQRadius.medium),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Opacity(
                            opacity: c.isDark ? 0.5 : 0.8,
                            child: aqImg(image, cacheWidth: 500),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: AlignmentDirectional.centerStart,
                                end: AlignmentDirectional.centerEnd,
                                colors: [
                                  c.surfaceRaised,
                                  c.surfaceRaised.withValues(alpha: 0.7),
                                  c.surfaceRaised.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AQSpacing.x3 + 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AQTypography.of(context, AQText.titleMedium),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: AQTypography.of(
                            context,
                            AQText.bodySmall,
                            soft: true,
                          ),
                        ),
                        const SizedBox(height: AQSpacing.x3),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: AQIcon(
                              'chevron-right',
                              size: 18,
                              color: c.onAccent,
                              directional: true,
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
      );
  final broker = card(
    'assets/location/10_Muscat_corniche_at_warm_evening.jpg',
    f.t('home.broker'),
    f.t('home.broker.sub'),
    () => context.push('/brokers'),
  );
  final loan = card(
    'assets/properties/p5/03_Contemporary_apartment_property_.jpg',
    f.t('home.loan'),
    f.t('home.loan.sub'),
    () => context.push('/calculators'),
  );
  return Padding(
    padding: const EdgeInsets.only(top: AQSpacing.x6),
    child: aqLargeText(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              broker,
              const SizedBox(height: AQSpacing.x3),
              loan,
            ],
          )
        : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: broker),
                const SizedBox(width: AQSpacing.x3),
                Expanded(child: loan),
              ],
            ),
          ),
  );
}

Widget aqPage(
  BuildContext context, {
  required Widget hero,
  required List<Widget> children,
}) {
  return SingleChildScrollView(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AQSpacing.gutter,
                0,
                AQSpacing.gutter,
                128,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- Home

class AQHomeScreen extends ConsumerWidget {
  /// Optional first block under the hero: the Buyer / Agent switcher for an approved agent, or
  /// the status banner for an application that is not approved yet.
  final Widget? topSlot;
  const AQHomeScreen({super.key, this.topSlot});

  String _greeting(FlowStrings f) {
    final h = DateTime.now().hour;
    return f.t(
      h < 12
          ? 'home.greet.morning'
          : (h < 18 ? 'home.greet.afternoon' : 'home.greet.evening'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final tx = ref.watch(homeTxProvider);
    final area = ref.watch(homeAreaProvider);
    final async = ref.watch(aqAllPropertiesProvider);
    return aqPage(
      context,
      hero: AQHero(
        image: 'assets/location/11_Muscat_skyline_and_mountains.jpg',
        eyebrow: _greeting(f),
        title: f.t('home.lead'),
        sub: '',
      ),
      children: [
        ?topSlot,
        AQSearchEntry(hint: f.t('home.search.hint')),
        AQSectionHeader(
          f.t('home.browse'),
          action: f.t('home.seeAll'),
          onAction: () => context.push('/properties'),
          help: 'markets',
        ),
        _TileRow([
          for (final k in PropCategory.values)
            (
              k.image,
              f.t(k.key),
              () => context.push('/properties?cat=${k.name}'),
            ),
        ]),
        const SizedBox(height: AQSpacing.x5),
        AQSlideSwitch(
          labels: [f.t('home.buy'), f.t('home.rent')],
          index: tx == TransactionType.buy ? 0 : 1,
          onChanged: (i) => ref.read(homeTxProvider.notifier).state = i == 0
              ? TransactionType.buy
              : TransactionType.rent,
        ),
        const SizedBox(height: AQSpacing.x4),
        async.when(
          loading: () => const AQSkeletonBox(height: 320),
          error: (_, _) => AQErrorBanner(
            text: f.t('disc.loadError'),
            action: AQTextButton(
              label: f.t('common.retry'),
              color: c.accent,
              onPressed: () => ref.invalidate(aqAllPropertiesProvider),
            ),
          ),
          data: (all) {
            final items = all
                .where(
                  (p) =>
                      p.transactionType == tx &&
                      (area == null || p.area == area) &&
                      p.verification.isVerified,
                )
                .toList();
            if (items.isEmpty) return AQNoticeLine(text: f.t('disc.none'));
            return AnimatedSwitcher(
              duration: AQMotion.scaled(context, AQMotion.standard),
              child: KeyedSubtree(
                key: ValueKey('$tx$area'),
                child: _Featured(items: items),
              ),
            );
          },
        ),
        ..._developmentSection(context),
        ..._maintenanceSection(context),
        _brokerLoan(context),
      ],
    );
  }
}

class AQSkeletonBox extends StatelessWidget {
  final double height;
  const AQSkeletonBox({super.key, required this.height});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: c.ink.withValues(alpha: c.isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(AQRadius.large),
        ),
      ),
    );
  }
}

class AQNoticeLine extends StatelessWidget {
  final String text;
  const AQNoticeLine({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AQSpacing.x6),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AQTypography.of(context, AQText.bodyMedium, soft: true),
    ),
  );
}

// ---------------------------------------------------------------- Explore

class _Action extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3),
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(AQRadius.medium),
          ),
          child: Row(
            children: [
              AQIcon(icon, size: 20, color: c.onAccent),
              const SizedBox(width: AQSpacing.x2),
              Expanded(
                child: Text(
                  label,
                  style: AQTypography.of(
                    context,
                    AQText.labelMedium,
                    color: c.onAccent,
                  ),
                ),
              ),
              AQIcon(
                'chevron-right',
                size: 16,
                color: c.onAccent,
                directional: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Properties browse

class AQPropertiesScreen extends ConsumerStatefulWidget {
  final String? category;
  final String? tx;
  final String? types;
  const AQPropertiesScreen({super.key, this.category, this.tx, this.types});
  @override
  ConsumerState<AQPropertiesScreen> createState() => _AQPropertiesScreenState();
}

class _AQPropertiesScreenState extends ConsumerState<AQPropertiesScreen> {
  late final AQFilters _f = AQFilters(
    category: PropCategory.values
        .where((c) => c.name == widget.category)
        .firstOrNull,
    types: {for (final n in (widget.types ?? '').split(',')) ...PropertyType.values.where((t) => t.name == n)},
    tx: switch (widget.tx) {
      'buy' => TransactionType.buy,
      'rent' => TransactionType.rent,
      _ => null,
    },
  );

  @override
  void initState() {
    super.initState();
    final area = ref.read(homeAreaProvider);
    if (area != null) _f.areas.add(area);
  }

  Future<void> _openFilters(List<Property> all) async {
    final next = await showAQFilterSheet(context, all: all, initial: _f);
    if (next == null || !mounted) return;
    setState(() {
      _f.tx = next.tx;
      _f.category = next.category;
      _f.types
        ..clear()
        ..addAll(next.types);
      _f.areas
        ..clear()
        ..addAll(next.areas);
      _f.amenities
        ..clear()
        ..addAll(next.amenities);
      _f.minPrice = next.minPrice;
      _f.maxPrice = next.maxPrice;
      _f.beds = next.beds;
      _f.baths = next.baths;
      _f.minArea = next.minArea;
      _f.verifiedOnly = next.verifiedOnly;
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    // The location pill in the corner drives the same area filter.
    ref.listen<String?>(
      homeAreaProvider,
      (_, area) => setState(() {
        _f.areas.clear();
        if (area != null) _f.areas.add(area);
      }),
    );
    final async = ref.watch(aqAllPropertiesProvider);
    final txIndex = _f.tx == null ? 0 : (_f.tx == TransactionType.buy ? 1 : 2);
    return AQViewingScaffold(
      title: f.t('props.title'),
      subtitle: f.t('props.sub'),
      backLabel: f.t('common.back'),
      onBack: () => aqBack(context, '/app/explore'),
      trailing: AQViewToggle(
        map: false,
        onList: () {},
        onMap: () =>
            context.push('/map${_f.tx == null ? '' : '?tx=${_f.tx!.name}'}'),
      ),
      children: [
        AQSearchEntry(hint: f.t('props.search')),
        const SizedBox(height: AQSpacing.x4),
        Wrap(
          spacing: AQSpacing.x2,
          runSpacing: AQSpacing.x2,
          children: [
            AQChoicePill(
              label: f.t('disc.all'),
              selected: _f.category == null,
              onTap: () => setState(() => _f.category = null),
            ),
            for (final k in PropCategory.values)
              AQChoicePill(
                label: f.t(k.key),
                selected: _f.category == k,
                onTap: () => setState(() => _f.category = k),
              ),
          ],
        ),
        const SizedBox(height: AQSpacing.x3),
        AQSlideSwitch(
          labels: [f.t('disc.all'), f.t('home.buy'), f.t('home.rent')],
          index: txIndex,
          onChanged: (i) => setState(
            () => _f.tx = i == 0
                ? null
                : (i == 1 ? TransactionType.buy : TransactionType.rent),
          ),
        ),
        const SizedBox(height: AQSpacing.x4),
        async.when(
          loading: () => const Column(
            children: [
              AQSkeletonBox(height: 150),
              SizedBox(height: AQSpacing.x3),
              AQSkeletonBox(height: 150),
            ],
          ),
          error: (_, _) => AQErrorBanner(
            text: f.t('disc.loadError'),
            action: AQTextButton(
              label: f.t('common.retry'),
              color: c.accent,
              onPressed: () => ref.invalidate(aqAllPropertiesProvider),
            ),
          ),
          data: (all) {
            final shown = _f.apply(all);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                  child: AQResultsBar(
                    count: shown.length,
                    activeFilters: _f.activeCount,
                    onFilters: () => _openFilters(all),
                    onSort: () =>
                        showAQSortSheet(context, _f, () => setState(() {})),
                  ),
                ),
                if (shown.isEmpty)
                  Column(
                    children: [
                      AQNoticeLine(text: f.t('props.empty')),
                      if (_f.activeCount > 0 || _f.tx != null)
                        AQSecondaryButton(
                          label: f.t('flt.clear'),
                          trailingChevron: false,
                          onPressed: () => setState(_f.reset),
                        ),
                    ],
                  )
                else
                  for (final p in shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                      child: AQResultCard(property: p),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class AQResultCard extends ConsumerWidget {
  final Property property;
  /// Extra room at the trailing edge when something is overlaid there (e.g. a compare mark).
  final double trailingInset;
  const AQResultCard({super.key, required this.property, this.trailingInset = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final p = property;
    final saved = ref.watch(savedPropertiesProvider).contains(p.id);
    final tx = p.transactionType == TransactionType.buy
        ? f.t('disc.sale')
        : f.t('disc.rent');
    final facts = [
      if (p.bedrooms != null)
        '${VFmt.n(context, p.bedrooms!)} ${f.t('disc.beds')}',
      if (p.bathrooms != null)
        '${VFmt.n(context, p.bathrooms!)} ${f.t('home.baths')}',
      '${VFmt.n(context, p.areaSqm.round())} m²',
    ].join(' · ');
    final card = Semantics(
      button: true,
      label: '${p.title}, ${p.locationLabel}, $tx, $facts, ${p.priceLabel}',
      excludeSemantics: true,
      child: AQPressable(
        onTap: () => context.push('/property/${p.id}'),
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
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: aqLargeText(context) ? 100 : 132,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 132),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(AQSpacing.x3, AQSpacing.x3, AQSpacing.x3 + trailingInset, AQSpacing.x3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tx,
                            style: AQTypography.of(
                              context,
                              AQText.labelSmall,
                              color: c.accentDeep,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            VFmt.iso(p.title),
                            style: AQTypography.of(
                              context,
                              AQText.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: AQSpacing.x1),
                          Row(
                            children: [
                              AQIcon('pin', size: 14, color: c.accent),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  VFmt.iso(
                                    p.locationLabel
                                        .split(',')
                                        .take(2)
                                        .join(',')
                                        .trim(),
                                  ),
                                  style: AQTypography.of(
                                    context,
                                    AQText.bodySmall,
                                    soft: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            facts,
                            style: AQTypography.of(
                              context,
                              AQText.bodySmall,
                              soft: true,
                            ),
                          ),
                          const SizedBox(height: AQSpacing.x1),
                          Text(
                            p.priceLabel,
                            style: AQTypography.of(
                              context,
                              AQText.titleMedium,
                              color: c.accentDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: aqLargeText(context) ? 100 : 132,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      p.imageUrls.isEmpty
                          ? ColoredBox(color: c.surfaceSelected)
                          : aqImg(p.imageUrls.first, cacheWidth: 400),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Stack(
      children: [
        card,
        PositionedDirectional(
          start: 0,
          top: 0,
          child: Semantics(
            button: true,
            selected: saved,
            label: saved ? f.t('home.unsave') : f.t('home.save'),
            excludeSemantics: true,
            child: AQPressable(
              onTap: () {
                AQHaptics.confirm();
                final cur = ref.read(savedPropertiesProvider);
                ref.read(savedPropertiesProvider.notifier).state = saved
                    ? ({...cur}..remove(p.id))
                    : {...cur, p.id};
              },
              pressedScale: 0.9,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0x66000000),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      saved ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: saved ? const Color(0xFFE08A78) : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
