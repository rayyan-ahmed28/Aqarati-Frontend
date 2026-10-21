import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_kit.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';

/// One plain-language guide. Copy lives in help_strings.dart as `help.<id>.t|s|b1..b3`.
class HelpTopic {
  final String id;
  final String icon;
  final int paragraphs;
  final List<String> related;
  final String group;
  const HelpTopic(this.id, {required this.icon, required this.paragraphs, this.related = const [], required this.group});
}

const helpTopics = <HelpTopic>[
  HelpTopic('realEstate', icon: 'home', paragraphs: 2, related: ['markets', 'buyRentInvest', 'badge'], group: 'basics'),
  HelpTopic('markets', icon: 'area', paragraphs: 3, related: ['buyRentInvest', 'size'], group: 'basics'),
  HelpTopic('buyRentInvest', icon: 'explore', paragraphs: 3, related: ['markets', 'brokers', 'loan'], group: 'basics'),
  HelpTopic('size', icon: 'area', paragraphs: 1, related: ['markets'], group: 'basics'),
  HelpTopic('badge', icon: 'verified', paragraphs: 3, related: ['brokers', 'listingReview'], group: 'basics'),
  HelpTopic('viewing', icon: 'calendar', paragraphs: 3, related: ['reviews', 'badge'], group: 'using'),
  HelpTopic('devBuild', icon: 'development', paragraphs: 2, related: ['engagement', 'reviews'], group: 'using'),
  HelpTopic('maintenance', icon: 'construction', paragraphs: 3, related: ['reviews'], group: 'using'),
  HelpTopic('engagement', icon: 'user', paragraphs: 2, related: ['reviews', 'devBuild'], group: 'using'),
  HelpTopic('reviews', icon: 'star', paragraphs: 2, related: ['engagement', 'viewing', 'maintenance'], group: 'using'),
  HelpTopic('loan', icon: 'calendar-check', paragraphs: 2, related: ['buyRentInvest'], group: 'using'),
  HelpTopic('brokers', icon: 'agent', paragraphs: 3, related: ['badge', 'listingReview'], group: 'selling'),
  HelpTopic('listingReview', icon: 'shield', paragraphs: 2, related: ['brokers', 'badge'], group: 'selling'),
];

HelpTopic? helpTopic(String id) => helpTopics.where((t) => t.id == id).firstOrNull;

/// Opens the short explanation for [topicId] above the current screen. Closing it returns to exactly
/// where the person was; "Learn more" opens the full guide on top, and Back comes back here.
Future<void> showAQHelp(BuildContext context, String topicId) {
  final topic = helpTopic(topicId);
  if (topic == null) return Future.value();
  return showAQSheet<void>(
    context,
    useRootNavigator: true,
    builder: (ctx) {
      final f = FlowStrings.of(ctx);
      final c = AQColors.of(ctx);
      return Padding(
        padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x2),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.14), shape: BoxShape.circle), child: Center(child: AQIcon(topic.icon, size: AQIconSize.medium, color: c.accentDeep))),
            const SizedBox(width: AQSpacing.x3),
            Expanded(child: Semantics(header: true, child: Text(f.t('help.${topic.id}.t'), style: AQTypography.of(ctx, AQText.titleLarge)))),
            AQIconButton(icon: 'close', semanticsLabel: f.t('common.close'), directional: false, onPressed: () => Navigator.of(ctx).pop()),
          ]),
          const SizedBox(height: AQSpacing.x3),
          Text(f.t('help.${topic.id}.s'), style: AQTypography.of(ctx, AQText.bodyLarge)),
          const SizedBox(height: AQSpacing.x5),
          AQPrimaryButton(
            label: f.t('help.learnMore'),
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(ctx).pop();
              router.push('/help/${topic.id}');
            },
          ),
        ]),
      );
    },
  );
}

/// The small "?" affordance placed next to an unfamiliar term or section title.
class AQHelpButton extends StatelessWidget {
  final String topic;
  final double size;
  const AQHelpButton(this.topic, {super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final t = helpTopic(topic);
    return Semantics(
      button: true,
      label: t == null ? f.t('help.button') : '${f.t('help.button')} ${f.t('help.$topic.t')}',
      excludeSemantics: true,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          showAQHelp(context, topic);
        },
        pressedScale: 0.9,
        child: SizedBox(
          width: AQControl.tap,
          height: AQControl.tap,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.accent, width: 1.4), color: c.accent.withValues(alpha: 0.08)),
              child: Center(child: Text('?', style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep).copyWith(fontSize: size * 0.58, height: 1))),
            ),
          ),
        ),
      ),
    );
  }
}

/// A section title with a help affordance after it.
class AQTitleWithHelp extends StatelessWidget {
  final String title;
  final String topic;
  final AQText style;
  const AQTitleWithHelp(this.title, this.topic, {super.key, this.style = AQText.headlineSmall});

  @override
  Widget build(BuildContext context) => Row(children: [
        Flexible(child: Semantics(header: true, child: Text(title, style: AQTypography.of(context, style)))),
        AQHelpButton(topic),
      ]);
}

void _back(BuildContext context) => aqBack(context, '/app/account');

/// Help & guides: every topic, grouped.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    List<Widget> group(String g) => [
          for (final t in helpTopics.where((t) => t.group == g)) AQListRow(icon: t.icon, title: f.t('help.${t.id}.t'), subtitle: f.t('help.${t.id}.s'), onTap: () => context.push('/help/${t.id}')),
        ];
    return AQPlainPage(
      title: f.t('help.center.title'),
      subtitle: f.t('help.center.sub'),
      onBack: () => _back(context),
      children: [
        AQRowGroup(title: f.t('help.center.basics'), rows: group('basics')),
        AQRowGroup(title: f.t('help.center.using'), rows: group('using')),
        AQRowGroup(title: f.t('help.center.selling'), rows: group('selling')),
        AQInfoCard(icon: 'info', title: f.t('help.support.t'), body: f.t('help.support.b')),
      ],
    );
  }
}

/// One full guide with related topics. Back returns to the exact screen that opened it.
class HelpArticleScreen extends StatelessWidget {
  final String id;
  const HelpArticleScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final t = helpTopic(id);
    if (t == null) {
      return AQPlainPage(
        title: f.t('help.notFound.t'),
        subtitle: f.t('help.notFound.b'),
        onBack: () => aqBack(context, '/help'),
        children: [AQPrimaryButton(label: f.t('help.openCenter'), onPressed: () => context.go('/help'))],
      );
    }
    return AQPlainPage(
      eyebrow: f.t('help.center.title').toUpperCase(),
      title: f.t('help.${t.id}.t'),
      onBack: () => aqBack(context, '/help'),
      children: [
        Container(
          padding: const EdgeInsets.all(AQSpacing.x4),
          decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(AQRadius.medium)),
          child: Text(f.t('help.${t.id}.s'), style: AQTypography.of(context, AQText.titleMedium)),
        ),
        const SizedBox(height: AQSpacing.x4),
        for (var i = 1; i <= t.paragraphs; i++)
          Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x4), child: Text(f.t('help.${t.id}.b$i'), style: AQTypography.of(context, AQText.bodyLarge))),
        if (t.related.isNotEmpty) ...[
          const SizedBox(height: AQSpacing.x2),
          AQRowGroup(title: f.t('help.related'), rows: [
            for (final r in t.related.map(helpTopic).whereType<HelpTopic>()) AQListRow(icon: r.icon, title: f.t('help.${r.id}.t'), onTap: () => context.push('/help/${r.id}')),
          ]),
        ],
      ],
    );
  }
}
