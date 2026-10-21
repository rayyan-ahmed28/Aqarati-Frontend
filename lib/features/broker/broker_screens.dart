import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../devbuild/db_models.dart' show omanGovernorates;
import '../devbuild/db_widgets.dart' show DbPillRow, dbGovLabel;
import '../help/help.dart';
import '../listings/listing_widgets.dart' show listingDate;
import '../property/property_detail_screen.dart' show aqRequireSession;
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_home.dart' show AQResultCard;
import 'broker_data.dart';

/// The badge itself: icon + text, never colour alone.
class AqaratiBrokerBadge extends StatelessWidget {
  final bool compact;
  const AqaratiBrokerBadge({super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    return Semantics(
      label: f.t('abk.badge'),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? AQSpacing.x2 : AQSpacing.x3, vertical: compact ? 3 : 5),
        decoration: BoxDecoration(color: c.accentDeep, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AQIcon('shield', size: compact ? 12 : 14, color: c.onAccent),
          const SizedBox(width: 5),
          Flexible(child: Text(f.t('abk.badge'), style: AQTypography.of(context, AQText.labelMedium, color: c.onAccent).copyWith(fontSize: compact ? 11 : null))),
        ]),
      ),
    );
  }
}

/// Programme entry: what the programme is, what the badge means, and what is not decided yet.
class BrokerProgrammeScreen extends StatelessWidget {
  const BrokerProgrammeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    return AQViewingScaffold(
      washImage: 'assets/properties/p1/08_Contemporary_villa_front_facade_.jpg',
      backLabel: f.t('common.back'),
      onBack: () => aqBack(context, '/app/home'),
      trailing: const AQHelpButton('brokers'),
      title: f.t('abk.title'),
      subtitle: f.t('abk.sub'),
      bottom: AQBottomActionBar(
        stack: true,
        primary: AQPrimaryButton(label: f.t('abk.browse'), onPressed: () => context.push('/brokers/all')),
        secondary: AQBarSecondaryButton(label: f.t('abk.sell'), onPressed: () => context.push('/sell')),
      ),
      children: [
        const Align(alignment: AlignmentDirectional.centerStart, child: AqaratiBrokerBadge()),
        const SizedBox(height: AQSpacing.x4),
        AQInfoCard(icon: 'verified', title: f.t('abk.badge.t'), children: [
          for (var i = 1; i <= 3; i++) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x2), child: Text(f.t('abk.badge.b$i'), style: AQTypography.of(context, AQText.bodyMedium, soft: true))),
        ]),
        AQInfoCard(icon: 'clock', accent: c.warning, title: f.t('abk.terms.t'), body: f.t('abk.terms.b')),
        AQInfoCard(icon: 'info', title: f.t('abk.different.t'), body: f.t('abk.different.b'), children: [Align(alignment: AlignmentDirectional.centerStart, child: AQTextButton(label: f.t('help.learnMore'), trailingIcon: 'chevron-right', color: c.accentDeep, onPressed: () => context.push('/help/brokers')))]),
      ],
    );
  }
}

/// Directory of badged brokers with governorate filter and search. Filters survive opening a profile.
class BrokerDirectoryScreen extends ConsumerStatefulWidget {
  const BrokerDirectoryScreen({super.key});
  @override
  ConsumerState<BrokerDirectoryScreen> createState() => _BrokerDirectoryScreenState();
}

class _BrokerDirectoryScreenState extends ConsumerState<BrokerDirectoryScreen> {
  final _search = TextEditingController();
  BrokerQuery _q = const BrokerQuery();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final async = ref.watch(brokersProvider(_q));
    final govs = DemoBrokerRepository.roster.map((b) => b.governorate).toSet().toList()..sort();
    return AQPlainPage(
      eyebrow: f.t('abk.eyebrow'),
      title: f.t('abk.dir.title'),
      subtitle: f.t('abk.dir.sub'),
      onBack: () => aqBack(context, '/brokers'),
      trailing: const AQHelpButton('badge'),
      children: [
        if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
        AQTextField(
          label: f.t('abk.dir.search'),
          controller: _search,
          action: TextInputAction.search,
          prefix: Padding(padding: const EdgeInsetsDirectional.only(top: AQSpacing.x3), child: AQIcon('search', size: 18, color: AQColors.of(context).inkSoft)),
          onChanged: (v) => setState(() => _q = BrokerQuery(text: v, governorate: _q.governorate)),
        ),
        DbPillRow(scroll: true, pills: [
          (f.t('abk.dir.allGov'), _q.governorate == null, () => setState(() => _q = BrokerQuery(text: _q.text))),
          for (final g in govs.where(omanGovernorates.containsKey)) (dbGovLabel(f, g), _q.governorate == g, () => setState(() => _q = BrokerQuery(text: _q.text, governorate: g))),
        ]),
        const SizedBox(height: AQSpacing.x4),
        ...async.when(
          loading: () => [const AQSkeletonRows(count: 3, height: 96)],
          error: (_, _) => [AQRetryPanel(onRetry: () => ref.invalidate(brokersProvider(_q)))],
          data: (list) => list.isEmpty
              ? [
                  AQEmptyState(
                    icon: 'search',
                    title: f.t('abk.dir.empty.t'),
                    body: f.t('abk.dir.empty.b'),
                    action: AQSecondaryButton(
                      label: f.t('abk.dir.clear'),
                      trailingChevron: false,
                      onPressed: () {
                        _search.clear();
                        setState(() => _q = const BrokerQuery());
                      },
                    ),
                  ),
                ]
              : [
                  Semantics(liveRegion: true, child: Text(list.length == 1 ? f.t('abk.dir.count1') : f.t('abk.dir.count', {'n': '${list.length}'}), style: AQTypography.of(context, AQText.labelMedium, soft: true))),
                  const SizedBox(height: AQSpacing.x3),
                  for (final b in list) _BrokerRow(broker: b),
                ],
        ),
      ],
    );
  }
}

class _BrokerRow extends StatelessWidget {
  final AqaratiBroker broker;
  const _BrokerRow({required this.broker});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final n = broker.propertyIds.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x3),
      child: Semantics(
        button: true,
        label: '${broker.name}. ${f.t('abk.badge')}. ${broker.wilayat}, ${dbGovLabel(f, broker.governorate)}',
        excludeSemantics: true,
        child: AQPressable(
          onTap: () => context.push('/brokers/${broker.id}'),
          child: Container(
            padding: const EdgeInsets.all(AQSpacing.x4),
            decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
            child: Row(children: [
              CircleAvatar(radius: 26, backgroundColor: c.accent.withValues(alpha: 0.14), child: AQIcon('agent', size: 24, color: c.accentDeep)),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(VFmt.iso(broker.name), style: AQTypography.of(context, AQText.titleMedium)),
                  const SizedBox(height: 2),
                  Text('${broker.wilayat}, ${dbGovLabel(f, broker.governorate)}', style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                  const SizedBox(height: AQSpacing.x2),
                  Wrap(spacing: AQSpacing.x2, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    const AqaratiBrokerBadge(compact: true),
                    Text(n == 1 ? f.t('abk.listings1') : f.t('abk.listingsN', {'n': '$n'}), style: AQTypography.of(context, AQText.labelMedium, soft: true)),
                  ]),
                ]),
              ),
              AQIcon('chevron-right', size: 18, color: c.inkFaint, directional: true),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A broker's public profile: badge, location, approved listings, published reviews, contact.
class BrokerProfileScreen extends ConsumerWidget {
  final String id;
  const BrokerProfileScreen({super.key, required this.id});

  Future<void> _contact(BuildContext context, WidgetRef ref, AqaratiBroker b) => aqRequireSession(context, ref, actionKey: 'abk.p.contactAction', go: () => _sheet(context, b));

  Future<void> _sheet(BuildContext context, AqaratiBroker b) => showAQSheet<void>(
        context,
        useRootNavigator: true,
        builder: (s) {
          final f = FlowStrings.of(s);
          final c = AQColors.of(s);
          Widget row(String icon, String label, String? number) => Padding(
                padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                child: AQListRow(
                  icon: icon,
                  title: label,
                  subtitle: number == null ? f.t('abk.p.noWhatsapp') : VFmt.iso(number),
                  trailing: number == null ? null : f.t('db.contact.copy'),
                  onTap: number == null
                      ? null
                      : () async {
                          var ok = true;
                          try {
                            await Clipboard.setData(ClipboardData(text: number));
                          } catch (_) {
                            ok = false;
                          }
                          if (!s.mounted) return;
                          Navigator.of(s).pop();
                          if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(f.t(ok ? 'abk.p.copied' : 'abk.p.copyFailed'))));
                        },
                ),
              );
          return Padding(
            padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x2),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(header: true, child: Text(VFmt.iso(b.name), style: AQTypography.of(s, AQText.headlineSmall))),
              const SizedBox(height: AQSpacing.x4),
              row('phone', f.t('abk.p.call'), b.phone),
              row('send', f.t('abk.p.whatsapp'), b.whatsapp),
              Text(f.t('abk.p.contactNote'), style: AQTypography.of(s, AQText.bodySmall, soft: true)),
              const SizedBox(height: AQSpacing.x2),
              Text(f.t('abk.p.leadNote'), style: AQTypography.of(s, AQText.bodySmall, color: c.inkFaint)),
            ]),
          );
        },
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final async = ref.watch(brokerProvider(id));
    void back() => aqBack(context, '/brokers/all');
    return async.when(
      loading: () => AQPlainPage(title: ' ', onBack: back, children: const [AQSkeletonRows(count: 4, height: 96)]),
      error: (_, _) => AQPlainPage(title: f.t('abk.dir.title'), onBack: back, children: [AQRetryPanel(onRetry: () => ref.invalidate(brokerProvider(id)))]),
      data: (b) {
        if (b == null) {
          return AQPlainPage(title: f.t('abk.notFound.t'), subtitle: f.t('abk.notFound.b'), onBack: back, children: [AQPrimaryButton(label: f.t('abk.browse'), onPressed: () => context.go('/brokers/all'))]);
        }
        final listings = ref.watch(brokerListingsProvider(id));
        return AQPlainPage(
          eyebrow: f.t('abk.eyebrow'),
          title: VFmt.iso(b.name),
          subtitle: f.t('abk.p.location', {'place': '${b.wilayat}, ${dbGovLabel(f, b.governorate)}'}),
          onBack: back,
          bottom: AQBottomActionBar(primary: AQPrimaryButton(label: f.t('abk.p.contact'), leadingIcon: 'phone', trailingChevron: false, onPressed: () => _contact(context, ref, b))),
          children: [
            if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: AQSpacing.x1, children: [
              const AqaratiBrokerBadge(),
              const AQHelpButton('badge'),
              Text(f.t('abk.since', {'date': listingDate(context, b.badgeSince)}), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
            ]),
            const SizedBox(height: AQSpacing.x4),
            Semantics(header: true, child: Text(f.t('abk.p.listings'), style: AQTypography.of(context, AQText.headlineSmall))),
            const SizedBox(height: AQSpacing.x3),
            ...listings.when(
              loading: () => [const AQSkeletonRows(count: 2, height: 220)],
              error: (_, _) => [AQRetryPanel(onRetry: () => ref.invalidate(brokerListingsProvider(id)))],
              data: (ps) => ps.isEmpty
                  ? [Text(f.t('abk.p.noListings'), style: AQTypography.of(context, AQText.bodyMedium, soft: true))]
                  : [for (final p in ps) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x4), child: AQResultCard(property: p))],
            ),
            const SizedBox(height: AQSpacing.x3),
            Row(children: [Expanded(child: Semantics(header: true, child: Text(f.t('abk.p.reviews'), style: AQTypography.of(context, AQText.headlineSmall)))), const AQHelpButton('reviews')]),
            const SizedBox(height: AQSpacing.x2),
            AQEmptyState(icon: 'star', title: f.t('abk.p.reviews'), body: f.t('abk.p.noReviews')),
          ],
        );
      },
    );
  }
}
