import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../devbuild/db_widgets.dart' show DbNotice;
import '../listings/listing_models.dart' show ListingState;
import '../listings/listing_repository.dart' show myListingsProvider;
import 'role_home_model.dart';
import 'role_home_widgets.dart';

/// Real Estate Agent: a compact operations console. No photography, dense rows, the
/// Buyer / Agent switch first. Listings, viewings and contact activity only show what the
/// connected services can really provide. Listings come from the listing repository (demo until the
/// API is wired); contact activity has no service yet, so that area
/// says so instead of inventing rows or counts.
class AgentHome extends ConsumerWidget {
  const AgentHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final accent = roleAccent(context, HomeRole.agent);
    return RoleHomePage(children: [
      const RoleReveal(child: RoleHeader()),
      RoleReveal(
        index: 1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: RoleEyebrow(f.t('rh.agent.eyebrow'), color: accent)),
            const SizedBox(width: AQSpacing.x2),
            Flexible(child: RoleChip(f.t('rh.verifiedRole'), icon: 'verified', color: c.success)),
          ]),
          const SizedBox(height: AQSpacing.x1),
          Semantics(header: true, child: Text(f.t('rh.agent.title'), style: AQTypography.of(context, AQText.displaySmall))),
        ]),
      ),
      const SizedBox(height: AQSpacing.x4),
      RoleReveal(
        index: 2,
        child: Semantics(
          button: true,
          label: '${f.t('rh.agent.profile')}. ${f.t('rh.agent.profile.sub')}',
          excludeSemantics: true,
          child: AQPressable(
            onTap: () => context.push('/verification/details'),
            child: Container(
              padding: const EdgeInsets.all(AQSpacing.x4),
              decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Center(child: AQIcon('agent', size: 24, color: accent)),
                ),
                const SizedBox(width: AQSpacing.x3),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.t('rh.agent.profile'), style: AQTypography.of(context, AQText.titleMedium)),
                    Text(f.t('rh.agent.profile.sub'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                  ]),
                ),
                AQIcon('chevron-right', size: 18, color: c.inkSoft, directional: true),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: AQSpacing.x3),
      RoleReveal(
        index: 3,
        child: RoleWorkspaceSwitcher(
          selected: HomeWorkspace.agent,
          onChanged: (w) => ref.read(homeWorkspaceProvider.notifier).state = w,
        ),
      ),
      RoleReveal(index: 3, child: RoleSection(f.t('rh.agent.tools'))),
      RoleReveal(
        index: 4,
        child: _Grid(children: [
          RoleTile(icon: 'list', label: f.t('rh.agent.listings'), sub: f.t('rh.agent.listings.sub'), onTap: () => context.push('/listings'), accent: accent),
          RoleTile(icon: 'calendar', label: f.t('rh.agent.viewings'), sub: f.t('rh.agent.viewings.sub'), onTap: () => context.go('/app/activity'), accent: accent),
          RoleTile(icon: 'phone', label: f.t('rh.contact'), sub: f.t('rh.contact.sub'), unavailable: true, note: f.t('rh.agent.contact.note'), accent: accent),
          RoleTile(icon: 'user', label: f.t('rh.agent.profileTile'), sub: f.t('rh.agent.profileTile.sub'), onTap: () => context.push('/verification/details'), accent: accent),
        ]),
      ),
      RoleSection(f.t('rh.agent.status')),
      Container(
        padding: const EdgeInsets.all(AQSpacing.x4),
        decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.t('rh.agent.status.t'), style: AQTypography.of(context, AQText.titleSmall)),
          const SizedBox(height: 2),
          Text(f.t('rh.agent.status.b'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
          const SizedBox(height: AQSpacing.x3),
          // Real counts from the listing repository; nothing is estimated.
          ref.watch(myListingsProvider).when(
                loading: () => const SizedBox(height: 40, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))),
                error: (_, _) => Text(f.t('common.networkError'), style: AQTypography.of(context, AQText.bodySmall, color: c.danger)),
                data: (ls) => ls.isEmpty
                    ? Text(f.t('rh.agent.status.empty'), style: AQTypography.of(context, AQText.bodySmall, soft: true))
                    : Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
                        for (final st in [ListingState.approvedActive, ListingState.pending, ListingState.resubmissionRequired, ListingState.expired])
                          if (ls.any((l) => l.state == st)) RoleChip('${f.t('lst.st.${st.name}')} · ${ls.where((l) => l.state == st).length}', color: accent),
                      ]),
              ),
          const SizedBox(height: AQSpacing.x3),
          Row(children: [
            Expanded(child: AQSecondaryButton(label: f.t('rh.agent.listings'), compact: true, trailingChevron: false, onPressed: () => context.push('/listings'))),
            const SizedBox(width: AQSpacing.x2),
            Expanded(child: AQPrimaryButton(label: f.t('rh.agent.new'), compact: true, trailingChevron: false, onPressed: () => context.push('/listings/new?channel=agent'))),
          ]),
        ]),
      ),
      RoleSection(f.t('rh.agent.recent')),
      DbNotice(f.t('rh.agent.contact.note'), icon: 'info'),
    ]);
  }
}

class _Grid extends StatelessWidget {
  final List<Widget> children;
  const _Grid({required this.children});

  @override
  Widget build(BuildContext context) {
    // Two columns normally; one column on narrow screens or large text, so words never break
    // mid-word. A tile may grow when its explanation opens, so rows do not stretch.
    final narrow = MediaQuery.sizeOf(context).width < 380 || MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final rows = <Widget>[];
    if (narrow) {
      for (var i = 0; i < children.length; i++) {
        rows.add(children[i]);
        if (i + 1 < children.length) rows.add(const SizedBox(height: AQSpacing.x3));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    }
    for (var i = 0; i < children.length; i += 2) {
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: children[i]),
        const SizedBox(width: AQSpacing.x3),
        Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
      ]));
      if (i + 2 < children.length) rows.add(const SizedBox(height: AQSpacing.x3));
    }
    return Column(children: rows);
  }
}
