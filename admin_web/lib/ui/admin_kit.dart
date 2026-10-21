import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';

String fmtTime(DateTime d) => DateFormat('d MMM y, HH:mm').format(d.toLocal());

String fmtAge(Duration d) {
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m';
}

String entityLabel(EntityType t) => switch (t) {
      EntityType.agent => 'Real estate agent',
      EntityType.construction => 'Construction company',
      EntityType.development => 'Property development',
      EntityType.architecture => 'Building architecture',
      EntityType.interiorExterior => 'Interior & exterior design',
      EntityType.provider => 'Maintenance provider',
      EntityType.aqaratiBroker => 'Aqarati Broker',
      EntityType.listing => 'Property listing',
      EntityType.changeSet => 'Edit to approved item',
      EntityType.adBanner => 'Ad banner',
    };

String roleLabel(AdminRole r) => switch (r) {
      AdminRole.reviewer => 'Reviewer',
      AdminRole.seniorReviewer => 'Senior Reviewer',
      AdminRole.superAdmin => 'Super Admin',
      AdminRole.auditor => 'Auditor',
    };

String queueStatusLabel(QueueStatus s) => switch (s) {
      QueueStatus.pending => 'Pending',
      QueueStatus.awaitingSecondApproval => 'Awaiting second approval',
      QueueStatus.escalated => 'Escalated to Senior',
      QueueStatus.approved => 'Approved',
      QueueStatus.resubmissionRequested => 'Resubmission requested',
      QueueStatus.rejected => 'Rejected',
    };

enum Tone { neutral, pending, success, warning, danger }

/// Status chip: icon + text, never colour alone.
class AdminChip extends StatelessWidget {
  final String label;
  final Tone tone;
  final IconData? icon;
  const AdminChip(this.label, {super.key, this.tone = Tone.neutral, this.icon});
  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final (fg, ic) = switch (tone) {
      Tone.neutral => (c.inkSoft, Icons.info_outline),
      Tone.pending => (c.accentDeep, Icons.schedule),
      Tone.success => (c.success, Icons.check_circle_outline),
      Tone.warning => (c.warning, Icons.error_outline),
      Tone.danger => (c.danger, Icons.block),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: fg.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon ?? ic, size: 14, color: fg), const SizedBox(width: 5), Flexible(child: Text(label, style: adminText(context, size: 12, weight: FontWeight.w600, color: fg)))]),
      ),
    );
  }
}

Tone queueTone(QueueStatus s) => switch (s) {
      QueueStatus.pending => Tone.pending,
      QueueStatus.awaitingSecondApproval || QueueStatus.escalated => Tone.warning,
      QueueStatus.approved => Tone.success,
      QueueStatus.resubmissionRequested => Tone.warning,
      QueueStatus.rejected => Tone.danger,
    };

class AdminCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  const AdminCard({super.key, this.title, this.trailing, required this.children, this.padding = const EdgeInsets.all(AdminSpace.x5)});
  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AdminSpace.x4),
      padding: padding,
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AdminSpace.radius), border: Border.all(color: c.hairline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AdminSpace.x3),
            child: Row(children: [Expanded(child: Semantics(header: true, child: Text(title!, style: adminText(context, size: 16, weight: FontWeight.w700)))), ?trailing]),
          ),
        ...children,
      ]),
    );
  }
}

class AdminPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  const AdminPage({super.key, required this.title, this.subtitle, this.actions = const [], required this.children});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AdminSpace.x6, AdminSpace.x6, AdminSpace.x6, AdminSpace.x8),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: AdminSpace.x3, runSpacing: AdminSpace.x3, crossAxisAlignment: WrapCrossAlignment.end, alignment: WrapAlignment.spaceBetween, children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(header: true, child: Text(title, style: adminDisplay(context, size: 30))),
                  if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!, style: adminText(context, soft: true))),
                ]),
              ),
              if (actions.isNotEmpty) Wrap(spacing: AdminSpace.x2, children: actions),
            ]),
            const SizedBox(height: AdminSpace.x5),
            if (kAdminDemo) const _DemoBar(),
            ...children,
          ]),
        ),
      ),
    );
  }
}

class _DemoBar extends StatelessWidget {
  const _DemoBar();
  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AdminSpace.x4),
      padding: const EdgeInsets.symmetric(horizontal: AdminSpace.x4, vertical: AdminSpace.x2),
      decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(AdminSpace.radiusSmall), border: Border.all(color: c.hairline)),
      child: Row(children: [
        Icon(Icons.science_outlined, size: 16, color: c.accentDeep),
        const SizedBox(width: AdminSpace.x2),
        Expanded(child: Text('DEMO DATA · This console runs on an in-memory demo service. No real applicant, document or decision is involved, and nothing is sent anywhere.', style: adminText(context, size: 12, color: c.inkSoft))),
      ]),
    );
  }
}

class AdminEmpty extends StatelessWidget {
  final String title, body;
  final IconData icon;
  const AdminEmpty({super.key, required this.title, required this.body, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return AdminCard(children: [
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AdminSpace.x6),
          child: Column(children: [
            Icon(icon, size: 36, color: c.accent),
            const SizedBox(height: AdminSpace.x3),
            Text(title, style: adminText(context, size: 16, weight: FontWeight.w700)),
            const SizedBox(height: AdminSpace.x1),
            Text(body, textAlign: TextAlign.center, style: adminText(context, soft: true)),
          ]),
        ),
      ),
    ]);
  }
}

class AdminSkeleton extends StatelessWidget {
  final int rows;
  const AdminSkeleton({super.key, this.rows = 4});
  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Semantics(
      label: 'Loading',
      child: Column(children: [
        for (var i = 0; i < rows; i++) Container(height: 56, margin: const EdgeInsets.only(bottom: AdminSpace.x2), decoration: BoxDecoration(color: c.ink.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AdminSpace.radiusSmall))),
      ]),
    );
  }
}

/// The page a role sees when it lacks the permission for a section. Hiding is not the control; the
/// service refuses the same action.
class AdminForbiddenPanel extends StatelessWidget {
  final String what;
  const AdminForbiddenPanel({super.key, required this.what});
  @override
  Widget build(BuildContext context) => AdminEmpty(icon: Icons.lock_outline, title: 'Not available for your role', body: 'Your admin role does not include $what. Ask a Super Admin if you need it.');
}

/// Loading / error / data for admin reads, with the right handling for each failure.
class AdminAsync<T> extends ConsumerWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final String what;
  const AdminAsync({super.key, required this.value, required this.data, required this.onRetry, required this.what});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      loading: () => const AdminSkeleton(),
      data: data,
      error: (e, _) {
        if (e is SessionExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(adminAuthProvider).expired();
            if (context.mounted) context.go('/session-expired');
          });
          return const AdminSkeleton(rows: 1);
        }
        if (e is AdminForbidden) return AdminForbiddenPanel(what: what);
        final c = AdminColors.of(context);
        return AdminCard(children: [
          Row(children: [
            Icon(Icons.cloud_off_outlined, color: c.danger),
            const SizedBox(width: AdminSpace.x3),
            Expanded(child: Text('Could not load $what from the admin service.', style: adminText(context))),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ]),
        ]);
      },
    );
  }
}

class KeyValueRow extends StatelessWidget {
  final String k, v;
  const KeyValueRow(this.k, this.v, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AdminSpace.x2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 180, child: Text(k, style: adminText(context, size: 13, soft: true))),
          Expanded(child: SelectableText(v, style: adminText(context, size: 14, weight: FontWeight.w600))),
        ]),
      );
}
