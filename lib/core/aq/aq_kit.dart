import 'package:flutter/material.dart';

import '../localization/flow_strings.dart';
import 'aq_forms.dart';
import 'aq_primitives.dart';
import 'aq_scene.dart';
import 'aq_tokens.dart';
import 'aq_typography.dart';

/// Shared building blocks for the account, listing, broker, engagement, review and provider
/// screens. Everything reads the AQ tokens; nothing here introduces a new colour or motion value.

/// Semantic tone for a status pill. Status is always icon + text, never colour alone.
enum AQPillTone { neutral, pending, success, warning, danger }

class AQStatusPill extends StatelessWidget {
  final String label;
  final AQPillTone tone;
  final String? icon;
  const AQStatusPill(this.label, {super.key, this.tone = AQPillTone.neutral, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final (fg, defaultIcon) = switch (tone) {
      AQPillTone.neutral => (c.inkSoft, 'info'),
      AQPillTone.pending => (c.accentDeep, 'clock'),
      AQPillTone.success => (c.success, 'check'),
      AQPillTone.warning => (c.warning, 'alert'),
      AQPillTone.danger => (c.danger, 'close'),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3, vertical: 5),
        decoration: BoxDecoration(color: fg.withValues(alpha: c.isDark ? 0.18 : 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AQIcon(icon ?? defaultIcon, size: 14, color: fg),
          const SizedBox(width: 5),
          Flexible(child: Text(label, style: AQTypography.of(context, AQText.labelMedium, color: fg))),
        ]),
      ),
    );
  }
}

/// A tappable settings / navigation row: icon, title, optional subtitle and trailing text.
/// A row without [onTap] is shown as information, never as a dead control.
class AQListRow extends StatelessWidget {
  final String icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final Color? color;
  final bool showChevron;
  const AQListRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.color, this.showChevron = true});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final fg = color ?? c.ink;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4, vertical: AQSpacing.x3),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: (color ?? c.accent).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AQRadius.small)),
            child: Center(child: AQIcon(icon, size: AQIconSize.small, color: color ?? c.accentDeep)),
          ),
          const SizedBox(width: AQSpacing.x3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AQTypography.of(context, AQText.titleSmall, color: fg)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              ],
            ]),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AQSpacing.x2),
            // Shares the row at large text instead of pushing past the edge.
            Flexible(child: Text(trailing!, textAlign: TextAlign.end, style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep))),
          ],
          if (onTap != null && showChevron) ...[
            const SizedBox(width: AQSpacing.x1),
            AQIcon('chevron-right', size: AQIconSize.small, color: c.inkFaint, directional: true),
          ],
        ]),
      ),
    );
    if (onTap == null) return Semantics(container: true, child: row);
    return Semantics(
      button: true,
      label: [title, ?subtitle, ?trailing].join('. '),
      excludeSemantics: true,
      child: AQPressable(onTap: onTap, pressedScale: 0.99, child: row),
    );
  }
}

/// A grouped block of [AQListRow]s on one tonal surface with hairline separators.
class AQRowGroup extends StatelessWidget {
  final String? title;
  final List<Widget> rows;
  const AQRowGroup({super.key, this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i < rows.length - 1) children.add(Padding(padding: const EdgeInsetsDirectional.only(start: 64), child: Divider(height: 1, thickness: 1, color: c.hairline)));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AQSpacing.x1, bottom: AQSpacing.x2),
            child: Semantics(header: true, child: Text(title!.toUpperCase(), style: AQTypography.of(context, AQText.labelSmall, soft: true))),
          ),
        Container(
          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ]),
    );
  }
}

/// Empty state: why there is nothing, and one valid next step.
class AQEmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  final Widget? action;
  const AQEmptyState({super.key, required this.icon, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AQSpacing.x6),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(AQRadius.large), border: Border.all(color: c.hairline)),
      child: Column(children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), shape: BoxShape.circle), child: Center(child: AQIcon(icon, size: AQIconSize.large, color: c.accentDeep))),
        const SizedBox(height: AQSpacing.x3),
        Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.titleMedium))),
        const SizedBox(height: AQSpacing.x2),
        Text(body, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
        if (action != null) ...[const SizedBox(height: AQSpacing.x4), action!],
      ]),
    );
  }
}

/// Inline failure with a real retry (the callback must re-run the operation).
class AQRetryPanel extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  const AQRetryPanel({super.key, this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    return AQErrorBanner(text: message ?? f.t('common.networkError'), action: AQTextButton(label: f.t('common.retry'), color: c.accent, onPressed: onRetry));
  }
}

/// Geometry-matched skeleton rows so content does not jump when it arrives.
class AQSkeletonRows extends StatelessWidget {
  final int count;
  final double height;
  const AQSkeletonRows({super.key, this.count = 3, this.height = 72});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      label: FlowStrings.of(context).t('common.loading'),
      child: Column(children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
            child: ExcludeSemantics(child: Container(height: height, decoration: BoxDecoration(color: c.ink.withValues(alpha: c.isDark ? 0.08 : 0.05), borderRadius: BorderRadius.circular(AQRadius.medium)))),
          ),
      ]),
    );
  }
}

/// Plain text block with a heading: used by detail, help and status pages.
class AQInfoCard extends StatelessWidget {
  final String? icon;
  final String title;
  final String? body;
  final List<Widget> children;
  final Color? accent;
  const AQInfoCard({super.key, this.icon, required this.title, this.body, this.children = const [], this.accent});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AQSpacing.x3),
      padding: const EdgeInsets.all(AQSpacing.x4),
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) ...[Padding(padding: const EdgeInsets.only(top: 1), child: AQIcon(icon!, size: AQIconSize.medium, color: accent ?? c.accentDeep)), const SizedBox(width: AQSpacing.x3)],
          Expanded(child: Semantics(header: true, child: Text(title, style: AQTypography.of(context, AQText.titleMedium)))),
        ]),
        if (body != null && body!.isNotEmpty) ...[const SizedBox(height: AQSpacing.x2), Text(body!, style: AQTypography.of(context, AQText.bodyMedium, soft: true))],
        if (children.isNotEmpty) ...[const SizedBox(height: AQSpacing.x3), ...children],
      ]),
    );
  }
}

/// A short labelled timeline of states. [current] is the index of the active step; steps after it
/// are shown as still to come. [failedAt] marks a step that ended the journey (declined, rejected).
class AQStateTimeline extends StatelessWidget {
  final List<(String, String?)> steps;
  final int current;
  final int? failedAt;
  const AQStateTimeline({super.key, required this.steps, required this.current, this.failedAt});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            AnimatedContainer(
              duration: AQMotion.scaled(context, AQMotion.state),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: failedAt == i ? c.danger : (i <= current ? c.accent : Colors.transparent),
                shape: BoxShape.circle,
                border: Border.all(color: failedAt == i ? c.danger : (i <= current ? c.accent : c.hairline), width: 1.5),
              ),
              child: Center(child: i < current || failedAt == i ? AQIcon(failedAt == i ? 'close' : 'check', size: 13, color: c.onAccent) : (i == current ? Container(width: 7, height: 7, decoration: BoxDecoration(color: c.onAccent, shape: BoxShape.circle)) : null)),
            ),
            if (i < steps.length - 1) Container(width: 1.5, height: 30, color: i < current ? c.accent : c.hairline),
          ]),
          const SizedBox(width: AQSpacing.x3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1, bottom: AQSpacing.x2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(steps[i].$1, style: AQTypography.of(context, AQText.titleSmall, color: i <= current ? c.ink : c.inkFaint)),
                if (steps[i].$2 != null) Text(steps[i].$2!, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              ]),
            ),
          ),
        ]),
    ]);
  }
}

/// Explicit confirmation before an irreversible or outward-facing action. Resolves to true only
/// when the person taps the confirm button; backdrop, drag and Cancel all resolve to false.
Future<bool> aqConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  bool useRootNavigator = true,
}) async {
  final f = FlowStrings.of(context);
  final result = await showAQSheet<bool>(
    context,
    useRootNavigator: useRootNavigator,
    builder: (ctx) {
      final c = AQColors.of(ctx);
      return Padding(
        padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x2),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (destructive) Align(alignment: AlignmentDirectional.centerStart, child: AQIcon('alert', size: AQIconSize.large, color: c.danger)),
          if (destructive) const SizedBox(height: AQSpacing.x2),
          Semantics(header: true, child: Text(title, style: AQTypography.of(ctx, AQText.headlineSmall))),
          const SizedBox(height: AQSpacing.x2),
          Text(body, style: AQTypography.of(ctx, AQText.bodyMedium, soft: true)),
          const SizedBox(height: AQSpacing.x5),
          AQPrimaryButton(label: confirmLabel, trailingChevron: false, background: destructive ? c.danger : null, foreground: destructive ? c.onAccent : null, onPressed: () => Navigator.of(ctx).pop(true)),
          const SizedBox(height: AQSpacing.x2),
          AQSecondaryButton(label: cancelLabel ?? f.t('common.cancel'), trailingChevron: false, onPressed: () => Navigator.of(ctx).pop(false)),
        ]),
      );
    },
  );
  return result ?? false;
}

/// Live character counter for bounded text (review comments, reasons).
class AQCharCount extends StatelessWidget {
  final int count, min, max;
  const AQCharCount({super.key, required this.count, required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final ok = count >= min && count <= max;
    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: AQSpacing.x3),
      child: Row(children: [
        Expanded(child: Text(f.t('kit.chars.rule', {'min': '$min', 'max': '$max'}), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
        Text('$count / $max', style: AQTypography.of(context, AQText.labelMedium, color: ok ? c.success : (count > max ? c.danger : c.inkSoft))),
      ]),
    );
  }
}

/// Wraps a page body for the standalone (non-shell) routes, mirroring the viewing scaffold's
/// spacing, so new screens do not invent a different frame.
class AQPlainPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final VoidCallback onBack;
  final List<Widget> children;
  final Widget? bottom;
  final Widget? trailing;
  const AQPlainPage({super.key, required this.title, this.subtitle, this.eyebrow, required this.onBack, required this.children, this.bottom, this.trailing});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
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
                    height: AQControl.tap,
                    child: Row(children: [AQIconButton(icon: 'chevron-left', semanticsLabel: f.t('common.back'), onPressed: onBack), const Spacer(), ?trailing]),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (eyebrow != null) Text(eyebrow!, style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep)),
                      if (eyebrow != null) const SizedBox(height: AQSpacing.x1),
                      Semantics(header: true, child: Text(title, style: AQTypography.of(context, AQText.displaySmall))),
                      if (subtitle != null) ...[const SizedBox(height: AQSpacing.x2), Text(subtitle!, style: AQTypography.of(context, AQText.bodyMedium, soft: true))],
                      const SizedBox(height: AQSpacing.x5),
                      ...children,
                    ]),
                  ),
                ),
                ?bottom,
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
