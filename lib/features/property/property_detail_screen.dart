import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../core/widgets/aqarati_map_view.dart';
import '../../data/api/account_api.dart';
import '../../data/models/business.dart';
import '../../data/models/enums.dart';
import '../../data/models/property.dart';
import '../../data/repositories/app_state_providers.dart';
import '../../data/repositories/providers.dart';
import '../entry/widgets/entry_common.dart' show MasterLogo;
import '../enquiry/enquiry_screen.dart';
import '../enquiry/make_offer_screen.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_home.dart' show aqImg, AQSkeletonBox;
import 'property_gallery_screen.dart';
import '../broker/broker_data.dart' show brokerForProperty;
import '../broker/broker_screens.dart' show AqaratiBrokerBadge;

final aqPropertyProvider = FutureProvider.autoDispose.family<Property?, String>((ref, id) => ref.watch(propertyRepositoryProvider).getById(id));
final aqListerProvider = FutureProvider.autoDispose.family<Business?, String>((ref, id) => ref.watch(businessRepositoryProvider).getById(id));

/// Runs [go] for a signed-in person. Guests get a sheet that sends them to log in or sign up
/// instead of a fake sign-in step.
Future<void> aqRequireSession(BuildContext context, WidgetRef ref, {required String actionKey, required VoidCallback go}) async {
  var signedIn = false;
  try {
    await ref.read(meProvider.future);
    signedIn = true;
  } catch (_) {}
  if (!context.mounted) return;
  if (signedIn) {
    go();
    return;
  }
  final f = FlowStrings.of(context);
  await showAQSheet<void>(
    context,
    builder: (s) => Padding(
      padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x3, AQSpacing.gutter, AQSpacing.x2),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(f.t('pd.gate.t'), style: AQTypography.of(s, AQText.headlineSmall)),
        const SizedBox(height: AQSpacing.x2),
        Text(f.t('pd.gate.b', {'a': f.t(actionKey)}), style: AQTypography.of(s, AQText.bodyMedium, soft: true)),
        const SizedBox(height: AQSpacing.x4),
        AQPrimaryButton(
          label: f.t('guest.login'),
          trailingChevron: false,
          onPressed: () {
            Navigator.of(s).pop();
            context.push('/login');
          },
        ),
        const SizedBox(height: AQSpacing.x2),
        AQSecondaryButton(
          label: f.t('guest.create'),
          trailingChevron: false,
          onPressed: () {
            Navigator.of(s).pop();
            context.push('/onboarding/purpose');
          },
        ),
      ]),
    ),
  );
}

String _typeLabel(FlowStrings f, PropertyType t) => FlowStrings.keys.contains('ptype.${t.name}') ? f.t('ptype.${t.name}') : t.label;

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;
  const PropertyDetailScreen({super.key, required this.propertyId});
  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  final _pages = PageController();
  int _i = 0;
  bool _more = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int to, int count) {
    if (to < 0 || to >= count) return;
    _pages.animateToPage(to, duration: AQMotion.scaled(context, AQMotion.standard), curve: AQMotion.standardCurve);
  }

  Widget _circle(BuildContext context, {required Widget child, required String label, required VoidCallback onTap, double size = 44}) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AQPressable(
        onTap: onTap,
        pressedScale: 0.92,
        child: Container(width: size, height: size, decoration: BoxDecoration(color: c.surfaceRaised.withValues(alpha: 0.92), shape: BoxShape.circle, border: Border.all(color: c.hairline)), child: Center(child: child)),
      ),
    );
  }

  Widget _heart(BuildContext context, Property p, {double size = 44}) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final saved = ref.watch(savedPropertyIdsProvider).contains(p.id);
    return Semantics(
      button: true,
      selected: saved,
      label: saved ? f.t('home.unsave') : f.t('home.save'),
      excludeSemantics: true,
      child: AQPressable(
        onTap: () {
          AQHaptics.confirm();
          final cur = ref.read(savedPropertyIdsProvider);
          ref.read(savedPropertyIdsProvider.notifier).state = saved ? ({...cur}..remove(p.id)) : {...cur, p.id};
        },
        pressedScale: 0.9,
        child: Container(width: size, height: size, decoration: BoxDecoration(color: c.surfaceRaised.withValues(alpha: 0.92), shape: BoxShape.circle, border: Border.all(color: c.hairline)), child: Center(child: AQHeart(saved: saved, savedColor: const Color(0xFFD9705C), idleColor: c.ink))),
      ),
    );
  }

  Widget _head(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: AQSpacing.x6, bottom: AQSpacing.x3),
        child: Semantics(header: true, child: Text(text, style: AQTypography.of(context, AQText.headlineMedium))),
      );

  Widget _fact(BuildContext context, Widget icon, String value, String label, double w) {
    final c = AQColors.of(context);
    return Container(
      width: w,
      padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3, horizontal: AQSpacing.x2),
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
      child: Column(children: [
        icon,
        const SizedBox(height: 6),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, maxLines: 1, style: AQTypography.of(context, AQText.titleMedium))),
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, textAlign: TextAlign.center, maxLines: 1, style: AQTypography.of(context, AQText.labelSmall, soft: true))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(aqPropertyProvider(widget.propertyId));
    return async.when(
      loading: () => AQViewingScaffold(backLabel: f.t('common.back'), onBack: () => aqBack(context, '/app/explore'), children: const [AQSkeletonBox(height: 240), SizedBox(height: AQSpacing.x4), AQSkeletonBox(height: 120)]),
      error: (_, _) => AQViewingScaffold(backLabel: f.t('common.back'), onBack: () => aqBack(context, '/app/explore'), children: [AQErrorBanner(text: f.t('pd.loadError'), action: AQTextButton(label: f.t('common.retry'), color: c.accent, onPressed: () => ref.invalidate(aqPropertyProvider(widget.propertyId))))]),
      data: (p) => p == null
          ? AQViewingScaffold(title: f.t('pd.notFound'), backLabel: f.t('common.back'), onBack: () => aqBack(context, '/app/explore'), children: [AQSecondaryButton(label: f.t('props.title'), trailingChevron: false, onPressed: () => context.go('/properties'))])
          : _body(context, f, c, p),
    );
  }

  Widget _body(BuildContext context, FlowStrings f, AQColors c, Property p) {
    final images = p.imageUrls;
    final large = aqLargeText(context);
    final tx = p.transactionType == TransactionType.buy ? f.t('disc.sale') : f.t('disc.rent');
    final lister = ref.watch(aqListerProvider(p.listedByBusinessId)).valueOrNull;
    final desc = p.description.isEmpty ? f.t('bp.noDesc') : p.description;
    final facts = <(Widget, String, String)>[
      if (p.bedrooms != null) (AQIcon('bed', size: 22, color: c.accent), VFmt.n(context, p.bedrooms!), f.t('flt.beds')),
      if (p.bathrooms != null) (Icon(Icons.bathtub_outlined, size: 22, color: c.accent), VFmt.n(context, p.bathrooms!), f.t('flt.baths')),
      (AQIcon('area', size: 22, color: c.accent), '${VFmt.n(context, p.areaSqm.round())} m²', f.t('pd.builtUp')),
      if (p.parkingSpaces != null) (Icon(Icons.local_parking_outlined, size: 22, color: c.accent), VFmt.n(context, p.parkingSpaces!), f.t('pd.parking')),
    ];
    final loc = p.locationLabel.split(',').take(2).join(',').trim();

    Widget gallery() => ClipRRect(
          borderRadius: BorderRadius.circular(AQRadius.large),
          child: AspectRatio(
            aspectRatio: large ? 4 / 3 : 16 / 11,
            child: Stack(fit: StackFit.expand, children: [
              if (images.isEmpty)
                ColoredBox(color: c.surfaceSelected, child: Center(child: AQIcon('home', size: 48, color: c.inkFaint)))
              else
                PageView.builder(
                  controller: _pages,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (context, i) => Semantics(
                    button: true,
                    label: f.t('pd.photo', {'i': VFmt.n(context, i + 1), 'n': VFmt.n(context, images.length)}),
                    excludeSemantics: true,
                    child: GestureDetector(onTap: () => Navigator.of(context).push(AQRoute.route<void>(PropertyGalleryScreen(property: p))), child: aqImg(images[i], cacheWidth: 1000)),
                  ),
                ),
              PositionedDirectional(
                start: AQSpacing.x3,
                top: AQSpacing.x3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xB32D2823), borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: p.transactionType == TransactionType.buy ? const Color(0xFF58B47A) : const Color(0xFFE2B866), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(tx, style: AQTypography.of(context, AQText.labelMedium, color: Colors.white)),
                  ]),
                ),
              ),
              if (images.length > 1)
                PositionedDirectional(
                  end: AQSpacing.x3,
                  top: AQSpacing.x3,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3, vertical: 6), decoration: BoxDecoration(color: const Color(0xB32D2823), borderRadius: BorderRadius.circular(16)), child: Text('${VFmt.n(context, _i + 1)}/${VFmt.n(context, images.length)}', style: AQTypography.of(context, AQText.labelMedium, color: Colors.white))),
                ),
              if (images.length > 1) ...[
                PositionedDirectional(start: AQSpacing.x2, top: 0, bottom: 0, child: Center(child: _circle(context, label: f.t('pd.prev'), size: 40, onTap: () => _go(_i - 1, images.length), child: AQIcon('chevron-left', size: 20, color: c.ink, directional: true)))),
                PositionedDirectional(end: AQSpacing.x2, top: 0, bottom: 0, child: Center(child: _circle(context, label: f.t('pd.next'), size: 40, onTap: () => _go(_i + 1, images.length), child: AQIcon('chevron-right', size: 20, color: c.ink, directional: true)))),
              ],
            ]),
          ),
        );

    final thumbs = images.length > 1
        ? SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length.clamp(0, 8),
              separatorBuilder: (_, _) => const SizedBox(width: AQSpacing.x2),
              itemBuilder: (context, i) => Semantics(
                button: true,
                selected: i == _i,
                label: f.t('pd.photo', {'i': VFmt.n(context, i + 1), 'n': VFmt.n(context, images.length)}),
                excludeSemantics: true,
                child: AQPressable(
                  onTap: () => _go(i, images.length),
                  child: AnimatedContainer(
                    duration: AQMotion.scaled(context, AQMotion.fast),
                    width: 84,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: i == _i ? c.accent : Colors.transparent, width: 2)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(AQRadius.medium - 2), child: aqImg(images[i], cacheWidth: 260)),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Semantics(header: true, child: Text(VFmt.iso(p.title), style: AQTypography.of(context, large ? AQText.headlineLarge : AQText.displaySmall)))),
        const SizedBox(width: AQSpacing.x2),
        _heart(context, p),
      ]),
      const SizedBox(height: AQSpacing.x2),
      Text(p.priceLabel, style: AQTypography.of(context, AQText.headlineLarge, color: c.accentDeep)),
      const SizedBox(height: AQSpacing.x2),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: AQSpacing.x3, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [AQIcon('pin', size: 16, color: c.accent), const SizedBox(width: 4), Flexible(child: Text(VFmt.iso(loc), style: AQTypography.of(context, AQText.bodyMedium, soft: true)))]),
        AQTextButton(label: f.t('pd.viewMap'), color: c.accentDeep, trailingIcon: 'chevron-right', onPressed: () => context.push('/map?tx=${p.transactionType == TransactionType.rent ? 'rent' : 'buy'}')),
      ]),
      if (p.verification.isVerified)
        Padding(padding: const EdgeInsets.only(top: AQSpacing.x1), child: Row(mainAxisSize: MainAxisSize.min, children: [AQIcon('verified', size: 18, color: c.accent), const SizedBox(width: 6), Flexible(child: Text(f.t('pd.verifiedListing'), style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep)))])),
    ]);

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(fit: StackFit.expand, children: [
        const AQBackdrop(asset: 'assets/entry/oman_terrace_2k.jpg', quiet: true),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
                  child: SizedBox(
                    height: AQControl.tap + 4,
                    child: Row(children: [
                      AQIconButton(icon: 'chevron-left', semanticsLabel: f.t('common.back'), onPressed: () => aqBack(context, '/app/explore')),
                      const SizedBox(width: AQSpacing.x1),
                      SizedBox(height: 46, child: FittedBox(fit: BoxFit.contain, child: MasterLogo(width: 80))),
                    ]),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      gallery(),
                      if (images.length > 1) ...[const SizedBox(height: AQSpacing.x3), thumbs],
                      const SizedBox(height: AQSpacing.x4),
                      titleBlock,
                      const SizedBox(height: AQSpacing.x4),
                      LayoutBuilder(builder: (context, box) {
                        const gap = AQSpacing.x2;
                        final cols = large ? 2 : (facts.length >= 4 ? 4 : facts.length.clamp(1, 4));
                        final w = (box.maxWidth - gap * (cols - 1)) / cols;
                        return Wrap(spacing: gap, runSpacing: gap, children: [for (final x in facts) _fact(context, x.$1, x.$2, x.$3, w)]);
                      }),
                      if (p.amenities.isNotEmpty) ...[
                        const SizedBox(height: AQSpacing.x3),
                        Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
                          for (final a in p.amenities)
                            Container(
                              constraints: const BoxConstraints(minHeight: 40),
                              padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3),
                              decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [AQIcon('check', size: 16, color: c.accent), const SizedBox(width: 6), Flexible(child: Text(a, style: AQTypography.of(context, AQText.labelMedium, color: c.inkSoft)))]),
                            ),
                        ]),
                      ],
                      _head(context, f.t('pd.description')),
                      Text(desc, maxLines: _more ? null : 3, overflow: _more ? null : TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodyMedium)),
                      if (desc.length > 110) Align(alignment: AlignmentDirectional.centerStart, child: AQTextButton(label: _more ? f.t('flt.less') : f.t('pd.readMore'), color: c.accentDeep, trailingIcon: 'chevron-down', onPressed: () => setState(() => _more = !_more))),
                      _head(context, f.t('pd.details')),
                      Container(
                        padding: const EdgeInsets.all(AQSpacing.x4),
                        decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.large), border: Border.all(color: c.hairline)),
                        child: Column(children: [
                          _kv(context, f.t('flt.type'), _typeLabel(f, p.type)),
                          _kv(context, f.t('flt.purpose'), tx),
                          _kv(context, f.t('pd.builtUp'), '${VFmt.n(context, p.areaSqm.round())} m²'),
                        ]),
                      ),
                      if (p.transactionType == TransactionType.buy) ...[
                        const SizedBox(height: AQSpacing.x3),
                        AQSecondaryButton(label: f.t('pd.offer'), trailingChevron: false, leadingIcon: 'send', onPressed: () => aqRequireSession(context, ref, actionKey: 'pd.a.offer', go: () => Navigator.of(context).push(AQRoute.route<void>(MakeOfferScreen(property: p))))),
                      ],
                      _head(context, f.t('pd.listedBy')),
                      // Programme listings carry the Aqarati Broker badge and lead to the broker's profile.
                      if (brokerForProperty(p.id) case final broker?) ...[
                        AQPressable(
                          onTap: () => context.push('/brokers/${broker.id}'),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: AQSpacing.x3),
                            padding: const EdgeInsets.all(AQSpacing.x3),
                            decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(AQRadius.medium)),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const AqaratiBrokerBadge(),
                                  const SizedBox(height: AQSpacing.x1),
                                  Text('${f.t('abk.onListing')} · ${VFmt.iso(broker.name)}', style: AQTypography.of(context, AQText.bodySmall)),
                                ]),
                              ),
                              AQIcon('chevron-right', size: 16, color: c.inkSoft, directional: true),
                            ]),
                          ),
                        ),
                      ],
                      _lister(context, f, c, p, lister),
                      if (p.latitude != null && p.longitude != null) ...[
                        _head(context, f.t('pd.location')),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AQRadius.large),
                          child: SizedBox(
                            height: large ? 300 : 190,
                            child: AqaratiMapView(initialCenter: LatLng(p.latitude!, p.longitude!), initialZoom: 14, interactive: false, borderRadius: BorderRadius.zero),
                          ),
                        ),
                        const SizedBox(height: AQSpacing.x2),
                        Text(VFmt.iso(p.locationLabel), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                      ],
                      const SizedBox(height: AQSpacing.x4),
                    ]),
                  ),
                ),
                AQBottomActionBar(
                  secondary: AQBarSecondaryButton(
                    label: f.t('pd.enquire'),
                    onPressed: () => aqRequireSession(context, ref, actionKey: 'pd.a.enquire', go: () => Navigator.of(context).push(AQRoute.route<void>(EnquiryScreen(property: p)))),
                  ),
                  primary: AQPrimaryButton(
                    label: f.t('pd.book'),
                    trailingChevron: false,
                    onPressed: () => aqRequireSession(context, ref, actionKey: 'pd.a.book', go: () => context.push('/property/${p.id}/viewing')),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(k, style: AQTypography.of(context, AQText.bodyMedium, soft: true))),
          const SizedBox(width: AQSpacing.x3),
          Flexible(child: Text(v, textAlign: TextAlign.end, style: AQTypography.of(context, AQText.titleSmall))),
        ]),
      );

  Widget _lister(BuildContext context, FlowStrings f, AQColors c, Property p, Business? b) {
    final name = b?.name ?? f.t('pd.unknownLister');
    final initials = name.trim().isEmpty ? '?' : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      padding: const EdgeInsets.all(AQSpacing.x4),
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.large), border: Border.all(color: c.hairline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle), child: Center(child: Text(initials, style: AQTypography.of(context, AQText.titleMedium, color: c.accentDeep)))),
          const SizedBox(width: AQSpacing.x3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(VFmt.iso(name), style: AQTypography.of(context, AQText.titleMedium)),
              if (b?.verification.isVerified == true) Row(mainAxisSize: MainAxisSize.min, children: [AQIcon('verified', size: 14, color: c.accent), const SizedBox(width: 4), Flexible(child: Text(f.t('bp.verifiedBusiness'), style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep)))]),
              if (b?.rating != null) Row(mainAxisSize: MainAxisSize.min, children: [AQIcon('star-fill', size: 14, color: c.warning), const SizedBox(width: 4), Flexible(child: Text('${b!.rating!.toStringAsFixed(1)} · ${f.t('pro.reviews', {'n': VFmt.n(context, b.reviewCount ?? 0)})}', style: AQTypography.of(context, AQText.bodySmall, soft: true)))]),
            ]),
          ),
        ]),
        const SizedBox(height: AQSpacing.x3),
        Row(children: [
          Expanded(child: AQSecondaryButton(label: f.t('pd.viewProfile'), compact: true, trailingChevron: false, onPressed: b == null ? null : () => context.push('/business/${b.id}'))),
          const SizedBox(width: AQSpacing.x2),
          Expanded(
            child: AQPrimaryButton(
              label: f.t('pd.contact'),
              compact: true,
              trailingChevron: false,
              onPressed: () => aqRequireSession(context, ref, actionKey: 'pd.a.enquire', go: () => Navigator.of(context).push(AQRoute.route<void>(EnquiryScreen(property: p)))),
            ),
          ),
        ]),
      ]),
    );
  }
}
