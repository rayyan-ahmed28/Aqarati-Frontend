import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
import '../../core/domain/account_models.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show meProvider;
import '../help/help.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import 'listing_models.dart';
import 'listing_repository.dart';
import 'listing_widgets.dart';

/// Aqary e-Broker entry: what it is, who can use it, the steps, and the fee position. The fee
/// model is a pending decision (#26), so no amount is shown.
class SellIntroScreen extends ConsumerWidget {
  const SellIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final me = ref.watch(meProvider);
    final signedIn = me.valueOrNull?.account == AccountState.active;
    final idState = signedIn ? ref.watch(sellerIdProvider).valueOrNull : null;
    final steps = [for (var i = 1; i <= 5; i++) (f.t('eb.h$i.t'), f.t('eb.h$i.b'))];
    return AQViewingScaffold(
      washImage: 'assets/properties/p4/02_Contemporary_villa_at_sunset.jpg',
      onBack: () => aqBack(context, '/app/home'),
      backLabel: f.t('common.back'),
      trailing: const AQHelpButton('brokers'),
      title: f.t('eb.title'),
      subtitle: f.t('eb.sub'),
      bottom: AQBottomActionBar(
        stack: true,
        primary: signedIn
            ? AQPrimaryButton(label: f.t('eb.start'), loading: idState == null && ref.watch(sellerIdProvider).isLoading, onPressed: () => context.push(idState == SellerIdState.none || idState == SellerIdState.rejected ? '/sell/identity' : '/listings/new?channel=ebroker'))
            : AQPrimaryButton(label: f.t('guest.login'), onPressed: () => context.push('/login')),
        secondary: signedIn ? AQBarSecondaryButton(label: f.t('eb.mine'), onPressed: () => context.push('/listings')) : AQBarSecondaryButton(label: f.t('guest.create'), onPressed: () => context.push('/onboarding/purpose')),
      ),
      children: [
        if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
        if (!signedIn && !me.isLoading) AQInfoCard(icon: 'lock', title: f.t('eb.signIn.t'), body: f.t('eb.signIn.b')),
        AQInfoCard(title: f.t('eb.how'), children: [
          AQStateTimeline(current: -1, steps: steps),
        ]),
        AQInfoCard(icon: 'user', title: f.t('eb.who'), body: f.t('eb.who.b')),
        AQInfoCard(icon: 'info', title: f.t('eb.fee.t'), body: f.t('eb.fee.pending'), accent: c.warning, children: [Text(f.t('eb.noMoney'), style: AQTypography.of(context, AQText.bodySmall, soft: true))]),
        Row(children: [Expanded(child: Text(f.t('help.brokers.t'), style: AQTypography.of(context, AQText.titleSmall))), const AQHelpButton('brokers')]),
      ],
    );
  }
}

/// The seller's photo ID, uploaded once and checked with the first Aqary e-Broker listing.
class SellerIdentityScreen extends ConsumerStatefulWidget {
  const SellerIdentityScreen({super.key});
  @override
  ConsumerState<SellerIdentityScreen> createState() => _SellerIdentityScreenState();
}

class _SellerIdentityScreenState extends ConsumerState<SellerIdentityScreen> {
  bool _busy = false;
  String? _error;
  String? _fileName;

  Future<void> _upload({bool sample = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      ListingFile? file;
      if (sample) {
        file = const ListingFile(name: 'photo-id-sample.jpg', sizeBytes: 120000, asset: 'sample');
      } else {
        file = await ref.read(listingFilePickerProvider).pickDocument();
        if (file == null) return;
        if (!listingFileAcceptable(file, photo: false)) {
          setState(() => _error = 'lst.w.docs.bad');
          return;
        }
      }
      await ref.read(listingRepositoryProvider).uploadSellerId(ListingFile(name: file.name, sizeBytes: file.sizeBytes));
      _fileName = file.name;
      ref.invalidate(sellerIdProvider);
      // The status card itself now says "Uploaded" (and is announced), so no snackbar covers the CTA.
      if (mounted) SemanticsService.sendAnnouncement(View.of(context), FlowStrings.of(context).t('eb.id.done'), Directionality.of(context));
    } catch (_) {
      if (mounted) setState(() => _error = 'common.networkError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final state = ref.watch(sellerIdProvider);
    final s = state.valueOrNull;
    final uploaded = s == SellerIdState.pendingReview || s == SellerIdState.accepted;
    return AQPlainPage(
      eyebrow: f.t('eb.eyebrow'),
      title: f.t('eb.id.title'),
      subtitle: f.t('eb.id.sub'),
      onBack: () => aqBack(context, '/sell'),
      bottom: AQBottomActionBar(primary: AQPrimaryButton(label: f.t('eb.continue'), onPressed: uploaded ? () => context.pushReplacement('/listings/new?channel=ebroker') : null)),
      children: [
        if (state.hasError) AQRetryPanel(onRetry: () => ref.invalidate(sellerIdProvider)),
        if (state.isLoading && s == null) const AQSkeletonRows(count: 1, height: 96),
        if (s != null)
          AQInfoCard(
            icon: uploaded ? 'check' : 'user',
            accent: uploaded ? c.success : null,
            title: f.t('eb.id.${s.name}'),
            body: _fileName,
            children: [
              if (_error != null) AQErrorBanner(text: f.t(_error!)),
              if (!uploaded) ...[
                AQSecondaryButton(label: f.t('eb.id.upload'), leadingIcon: 'plus', trailingChevron: false, loading: _busy, onPressed: () => _upload()),
                if (kShowReviewTools) AQTextButton(label: f.t('lst.w.docs.sample'), onPressed: _busy ? null : () => _upload(sample: true)),
              ],
            ],
          ),
        Text(f.t('lst.w.docs.rules'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
      ],
    );
  }
}
