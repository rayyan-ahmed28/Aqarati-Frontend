import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/business.dart';
import '../../data/models/enums.dart' show BusinessCategory;
import '../../data/repositories/providers.dart';
import '../reviews/review_models.dart';
import '../reviews/review_screens.dart' show reviewWritePath;
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_home.dart' show aqImg, aqAllPropertiesProvider, AQResultCard, AQSkeletonBox;

final aqBusinessProvider = FutureProvider.autoDispose.family<Business?, String>((ref, id) => ref.watch(businessRepositoryProvider).getById(id));

class AQBusinessProfileScreen extends ConsumerWidget {
  final String businessId;
  const AQBusinessProfileScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(aqBusinessProvider(businessId));
    void back() => aqBack(context, '/professionals');
    return async.when(
      loading: () => AQViewingScaffold(backLabel: f.t('common.back'), onBack: back, children: const [AQSkeletonBox(height: 220), SizedBox(height: AQSpacing.x4), AQSkeletonBox(height: 120)]),
      error: (_, _) => AQViewingScaffold(
        backLabel: f.t('common.back'),
        onBack: back,
        children: [AQErrorBanner(text: f.t('bp.loadError'), action: AQTextButton(label: f.t('common.retry'), color: c.accent, onPressed: () => ref.invalidate(aqBusinessProvider(businessId))))],
      ),
      data: (b) => b == null
          ? AQViewingScaffold(title: f.t('bp.notFound'), backLabel: f.t('common.back'), onBack: back, children: [AQSecondaryButton(label: f.t('bp.browse'), trailingChevron: false, onPressed: () => context.go('/professionals'))])
          : _Profile(business: b, onBack: back),
    );
  }
}

class _Profile extends ConsumerWidget {
  final Business business;
  final VoidCallback onBack;
  const _Profile({required this.business, required this.onBack});

  Widget _head(BuildContext context, String text, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(top: AQSpacing.x6, bottom: AQSpacing.x3),
        child: LayoutBuilder(
          builder: (context, box) => Row(children: [
            Expanded(child: Semantics(header: true, child: Text(text, style: AQTypography.of(context, AQText.headlineMedium)))),
            // A long trailing action scales down instead of pushing the heading out of the row.
            if (trailing != null) ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth * 0.5), child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerEnd, child: trailing)),
          ]),
        ),
      );

  Widget _info(BuildContext context, String icon, String text) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x1),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: AQIcon(icon, size: 16, color: c.accent)),
        const SizedBox(width: AQSpacing.x2),
        Expanded(child: Text(VFmt.iso(text), style: AQTypography.of(context, AQText.bodyMedium, soft: true))),
      ]),
    );
  }

  void _photo(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xDD000000),
      animationStyle: AnimationStyle(duration: AQMotion.dialog, reverseDuration: AQMotion.fast, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
      builder: (d) => Stack(children: [
        Positioned.fill(child: GestureDetector(onTap: () => Navigator.of(d).pop(), child: Center(child: InteractiveViewer(child: Image.asset(url, fit: BoxFit.contain))))),
        SafeArea(child: Align(alignment: AlignmentDirectional.topEnd, child: AQIconButton(icon: 'close', directional: false, color: Colors.white, semanticsLabel: FlowStrings.of(context).t('flt.close'), onPressed: () => Navigator.of(d).pop()))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final b = business;
    final cats = b.categories.map((k) => f.t('bcat.${k.name}')).toList();
    final cover = b.galleryUrls.isNotEmpty ? b.galleryUrls.first : null;
    final props = ref.watch(aqAllPropertiesProvider).valueOrNull?.where((p) => p.listedByBusinessId == b.id).toList() ?? const [];
    final cols = aqLargeText(context) ? 2 : 3;
    return AQViewingScaffold(
      backLabel: f.t('common.back'),
      onBack: onBack,
      children: [
        if (cover != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AQRadius.large),
            child: AspectRatio(aspectRatio: 16 / 10, child: ExcludeSemantics(child: aqImg(cover, cacheWidth: 900))),
          ),
        const SizedBox(height: AQSpacing.x4),
        Semantics(header: true, child: Text(VFmt.iso(b.name), style: AQTypography.of(context, AQText.displaySmall))),
        const SizedBox(height: AQSpacing.x1),
        Text(cats.join(' · '), style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
        const SizedBox(height: AQSpacing.x3),
        Wrap(spacing: AQSpacing.x4, runSpacing: AQSpacing.x2, children: [
          if (b.verification.isVerified)
            Row(mainAxisSize: MainAxisSize.min, children: [AQIcon('verified', size: 18, color: c.accent), const SizedBox(width: 6), Flexible(child: Text(f.t('bp.verifiedBusiness'), style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep)))]),
          if (b.rating != null)
            Row(mainAxisSize: MainAxisSize.min, children: [AQIcon('star-fill', size: 16, color: c.warning), const SizedBox(width: 6), Flexible(child: Text('${b.rating!.toStringAsFixed(1)} · ${f.t('pro.reviews', {'n': VFmt.n(context, b.reviewCount ?? 0)})}', style: AQTypography.of(context, AQText.labelMedium)))]),
        ]),
        const SizedBox(height: AQSpacing.x4),
        _info(context, 'pin', b.locationLabel),
        if (b.serviceArea.isNotEmpty) _info(context, 'globe', f.t('bp.serves', {'area': b.serviceArea})),
        if (b.categories.contains(BusinessCategory.maintenance)) ...[
          const SizedBox(height: AQSpacing.x3),
          AQPrimaryButton(label: f.t('mnt.book.cta'), leadingIcon: 'calendar', trailingChevron: false, onPressed: () => context.push('/business/${b.id}/book')),
        ],
        _head(context, f.t('bp.about')),
        Text(b.description.isEmpty ? f.t('bp.noDesc') : b.description, style: AQTypography.of(context, AQText.bodyMedium)),
        _head(context, f.t('bp.services')),
        Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
          for (final k in cats) Container(constraints: const BoxConstraints(minHeight: 40), padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.hairline)), child: Center(widthFactor: 1, child: Text(k, style: AQTypography.of(context, AQText.labelMedium, color: c.inkSoft)))),
        ]),
        _head(context, f.t('bp.portfolio')),
        if (b.galleryUrls.isEmpty)
          Text(f.t('bp.noPortfolio'), style: AQTypography.of(context, AQText.bodyMedium, soft: true))
        else
          LayoutBuilder(builder: (context, box) {
            const gap = AQSpacing.x2;
            final w = (box.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (var i = 0; i < b.galleryUrls.length; i++)
                SizedBox(
                  width: w,
                  height: w,
                  child: Semantics(
                    button: true,
                    label: f.t('bp.photo', {'i': VFmt.n(context, i + 1), 'n': VFmt.n(context, b.galleryUrls.length)}),
                    excludeSemantics: true,
                    child: AQPressable(onTap: () => _photo(context, b.galleryUrls[i]), child: ClipRRect(borderRadius: BorderRadius.circular(AQRadius.medium), child: aqImg(b.galleryUrls[i], cacheWidth: 360))),
                  ),
                ),
            ]);
          }),
        if (props.isNotEmpty) ...[
          _head(context, f.t('bp.listings')),
          for (final p in props) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x3), child: AQResultCard(property: p)),
        ],
        _head(context, f.t('bp.reviews'), trailing: AQTextButton(label: f.t('bp.write'), color: c.accentDeep, onPressed: () => context.push(reviewWritePath(ReviewTarget(kind: b.categories.contains(BusinessCategory.maintenance) ? ReviewTargetKind.provider : ReviewTargetKind.professional, id: b.id, name: b.name))))),
        Text(b.rating == null ? f.t('bp.noReviews') : f.t('bp.ratedBy', {'r': b.rating!.toStringAsFixed(1), 'n': VFmt.n(context, b.reviewCount ?? 0)}), style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
        const SizedBox(height: AQSpacing.x4),
      ],
    );
  }
}
