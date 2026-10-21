import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../ui/admin_kit.dart';

/// Dashboard (RECOMMENDED, section 89): pending by type, oldest item, turnaround, decisions.
/// Every number is computed from the queue the service returns.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(adminAuthProvider);
    final stats = ref.watch(dashboardProvider);
    final c = AdminColors.of(context);
    return AdminPage(
      title: 'Good to see you, ${auth.user?.name ?? ''}',
      subtitle: 'Queue health at a glance. Review SLA: 24 business hours (early warning at 18).',
      actions: [FilledButton.icon(onPressed: () => context.go('/queue'), icon: const Icon(Icons.fact_check_outlined, size: 18), label: const Text('Open queue'))],
      children: [
        AdminAsync<DashboardStats>(
          value: stats,
          what: 'the dashboard',
          onRetry: () => ref.invalidate(dashboardProvider),
          data: (s) {
            final total = s.pendingByType.values.fold<int>(0, (a, b) => a + b);
            Widget tile(String label, String value, IconData icon, {Color? tone}) => Container(
                  width: 250,
                  padding: const EdgeInsets.all(AdminSpace.x5),
                  decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AdminSpace.radius), border: Border.all(color: c.hairline)),
                  child: Row(children: [
                    Icon(icon, color: tone ?? c.accent),
                    const SizedBox(width: AdminSpace.x3),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: adminDisplay(context, size: 26)), Text(label, style: adminText(context, size: 12, soft: true))])),
                  ]),
                );
            final oldestHours = s.oldestAge?.inHours ?? 0;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: AdminSpace.x4, runSpacing: AdminSpace.x4, children: [
                tile('Open items', '$total', Icons.inbox_outlined),
                tile('Oldest open item', s.oldestAge == null ? '—' : fmtAge(s.oldestAge!), Icons.hourglass_bottom, tone: oldestHours >= 24 ? c.danger : (oldestHours >= 18 ? c.warning : null)),
                tile('Awaiting second approval', '${s.awaitingSecond}', Icons.people_outline),
                tile('Average turnaround', s.averageTurnaround == null ? 'No decisions yet' : fmtAge(s.averageTurnaround!), Icons.timelapse),
              ]),
              const SizedBox(height: AdminSpace.x5),
              AdminCard(title: 'Open items by type', children: [
                if (s.pendingByType.isEmpty) Text('The queue is empty.', style: adminText(context, soft: true)),
                for (final e in (s.pendingByType.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AdminSpace.x2),
                    child: Row(children: [
                      SizedBox(width: 220, child: Text(entityLabel(e.key), style: adminText(context))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: total == 0 ? 0 : e.value / total, minHeight: 10, backgroundColor: c.hairline, color: c.accent),
                        ),
                      ),
                      SizedBox(width: 40, child: Text('${e.value}', textAlign: TextAlign.end, style: adminText(context, weight: FontWeight.w700))),
                    ]),
                  ),
              ]),
              AdminCard(title: 'Decisions so far', children: [
                Wrap(spacing: AdminSpace.x3, runSpacing: AdminSpace.x2, children: [
                  AdminChip('Approved · ${s.approved}', tone: Tone.success),
                  AdminChip('Resubmission requested · ${s.resubmissions}', tone: Tone.warning),
                  AdminChip('Rejected · ${s.rejected}', tone: Tone.danger),
                ]),
              ]),
            ]);
          },
        ),
      ],
    );
  }
}

enum _ClaimFilter { all, unclaimed, mine }

/// Verification queue: priority order (resubmissions, then oldest; businesses ahead of listings),
/// filters, age and claim holder. Opening an item is audited; viewing the list is not.
class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});
  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  EntityType? _type;
  bool _openOnly = true;
  _ClaimFilter _claim = _ClaimFilter.all;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(queueProvider);
    final me = ref.watch(adminAuthProvider).user;
    final c = AdminColors.of(context);
    return AdminPage(
      title: 'Verification queue',
      subtitle: 'Resubmissions first, then oldest first. Claim an item to review it; claims last 30 minutes.',
      children: [
        AdminCard(children: [
          Wrap(spacing: AdminSpace.x3, runSpacing: AdminSpace.x3, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 260, child: TextField(decoration: const InputDecoration(labelText: 'Search subject or reference', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _q = v.trim().toLowerCase()))),
            DropdownButton<EntityType?>(
              value: _type,
              hint: const Text('All types'),
              items: [const DropdownMenuItem(value: null, child: Text('All types')), for (final t in EntityType.values) DropdownMenuItem(value: t, child: Text(entityLabel(t)))],
              onChanged: (v) => setState(() => _type = v),
            ),
            SegmentedButton<_ClaimFilter>(
              segments: const [ButtonSegment(value: _ClaimFilter.all, label: Text('All')), ButtonSegment(value: _ClaimFilter.unclaimed, label: Text('Unclaimed')), ButtonSegment(value: _ClaimFilter.mine, label: Text('Claimed by me'))],
              selected: {_claim},
              onSelectionChanged: (s) => setState(() => _claim = s.first),
            ),
            FilterChip(label: const Text('Open only'), selected: _openOnly, onSelected: (v) => setState(() => _openOnly = v)),
          ]),
        ]),
        AdminAsync<List<QueueItem>>(
          value: async,
          what: 'the verification queue',
          onRetry: () => ref.invalidate(queueProvider),
          data: (items) {
            final shown = items.where((i) {
              if (_openOnly && !i.open) return false;
              if (_type != null && i.type != _type) return false;
              if (_claim == _ClaimFilter.unclaimed && i.claimedBy != null) return false;
              if (_claim == _ClaimFilter.mine && i.claimedBy != me?.id) return false;
              if (_q.isNotEmpty && !i.subject.toLowerCase().contains(_q) && !i.id.toLowerCase().contains(_q)) return false;
              return true;
            }).toList();
            if (shown.isEmpty) return const AdminEmpty(title: 'Nothing matches', body: 'Change the filters to see more items.');
            final now = DateTime.now();
            return AdminCard(
              padding: EdgeInsets.zero,
              children: [
                for (final i in shown) ...[
                  InkWell(
                    onTap: () => context.go('/queue/${i.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AdminSpace.x5, vertical: AdminSpace.x4),
                      child: Row(children: [
                        Expanded(
                          flex: 5,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(i.subject, style: adminText(context, weight: FontWeight.w700)),
                            Text('${i.id} · ${entityLabel(i.type)}${i.resubmissions > 0 ? ' · resubmission ${i.resubmissions}' : ''}${needsFourEyes(i.type) ? ' · four-eyes' : ''}', style: adminText(context, size: 12, soft: true)),
                          ]),
                        ),
                        Expanded(flex: 2, child: Text(fmtAge(now.difference(i.submittedAt)), style: adminText(context, color: now.difference(i.submittedAt).inHours >= 24 ? c.danger : (now.difference(i.submittedAt).inHours >= 18 ? c.warning : null)))),
                        Expanded(flex: 3, child: Text(i.claimedByName == null ? 'Unclaimed' : 'Claimed by ${i.claimedByName}', style: adminText(context, size: 12, soft: true))),
                        AdminChip(queueStatusLabel(i.status), tone: queueTone(i.status)),
                        const SizedBox(width: AdminSpace.x2),
                        Icon(Icons.chevron_right, color: c.inkFaint),
                      ]),
                    ),
                  ),
                  const Divider(),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One review item: submitted fields beside streamed documents, the checklist for its type, the
/// decision panel (reason codes, note), claim / release / escalate, four-eyes and history.
class QueueItemScreen extends ConsumerStatefulWidget {
  final String id;
  const QueueItemScreen({super.key, required this.id});
  @override
  ConsumerState<QueueItemScreen> createState() => _QueueItemScreenState();
}

class _QueueItemScreenState extends ConsumerState<QueueItemScreen> {
  final Map<String, bool> _checks = {};
  DecisionOutcome _outcome = DecisionOutcome.approve;
  ReasonCode? _reason;
  final _note = TextEditingController();
  String? _openDocId;
  String? _watermark;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _openDoc(DocRef d) async {
    final w = await runAdmin(context, ref, () => ref.read(adminApiProvider).openDocument(widget.id, d.id));
    if (w != null && mounted) {
      setState(() {
        _openDocId = d.id;
        _watermark = w;
      });
    }
  }

  Future<void> _decide(QueueItem i) async {
    final label = switch (_outcome) {
      DecisionOutcome.approve => needsFourEyes(i.type) && i.status != QueueStatus.awaitingSecondApproval ? 'Record first approval' : 'Approve',
      DecisionOutcome.requestResubmission => 'Request resubmission',
      DecisionOutcome.reject => 'Reject',
    };
    final ok = await confirmAdmin(
      context,
      title: '$label?',
      body: _outcome == DecisionOutcome.approve
          ? (needsFourEyes(i.type) && i.status != QueueStatus.awaitingSecondApproval ? 'This records the first approval. A different Senior Reviewer must give the final approval before anything goes live.' : 'The applicant is told the outcome and the record becomes visible where the rules allow.')
          : 'The applicant sees the reason-code message${_note.text.trim().isEmpty ? '' : ' and your note'}. The decision is written to the audit log.',
      confirm: label,
      destructive: _outcome == DecisionOutcome.reject,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await runAdmin(context, ref, () => ref.read(adminApiProvider).decide(i.id, version: i.version, outcome: _outcome, checklist: Map.of(_checks), reason: _outcome == DecisionOutcome.approve ? null : _reason, note: _note.text), success: 'Decision recorded.');
    if (mounted) {
      setState(() => _busy = false);
      if (r != null) {
        _checks.clear();
        _note.clear();
        _reason = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(queueItemProvider(widget.id));
    final auth = ref.watch(adminAuthProvider);
    final me = auth.user;
    final c = AdminColors.of(context);
    return AdminAsync<QueueItem?>(
      value: async,
      what: 'this item',
      onRetry: () => ref.invalidate(queueItemProvider(widget.id)),
      data: (i) {
        if (i == null) return const AdminPage(title: 'Item not found', children: [AdminEmpty(title: 'This queue item no longer exists', body: 'It may have been decided and archived. Go back to the queue.')]);
        final mine = i.claimedBy == me?.id;
        final conflict = me != null && i.relatedAdminIds.contains(me.id);
        final canDecide = auth.can(Permission.decide);
        final second = i.status == QueueStatus.awaitingSecondApproval;
        final items = checklists[i.type]!;
        final allAnswered = items.every((k) => _checks[k] != null);
        final allPass = items.every((k) => _checks[k] == true);
        final firstApprover = i.firstApproval;
        final blockSecond = second && (!auth.can(Permission.secondApproval) || firstApprover?.adminId == me?.id);
        final canSubmit = mine && !conflict && i.open && !_busy && (_outcome == DecisionOutcome.approve ? allAnswered && allPass && !blockSecond : _reason != null && (_reason != ReasonCode.other || _note.text.trim().isNotEmpty));
        final wide = MediaQuery.sizeOf(context).width >= 1200;

        final fieldsCard = AdminCard(title: 'Submitted details', children: [
          KeyValueRow('Reference', i.id),
          KeyValueRow('Type', entityLabel(i.type)),
          KeyValueRow('Submitted', fmtTime(i.submittedAt)),
          for (final e in i.fields.entries) KeyValueRow(e.key, e.value),
          if (i.duplicateSuspected) Padding(padding: const EdgeInsets.only(top: AdminSpace.x2), child: AdminChip('Possible duplicate: same deed or location, type and similar area', tone: Tone.warning)),
        ]);
        final docsCard = AdminCard(title: 'Documents', trailing: Text('Streamed · watermarked · audited per view', style: adminText(context, size: 11, soft: true)), children: [
          if (!auth.can(Permission.openDocuments)) Text('Your role cannot open documents.', style: adminText(context, soft: true)),
          if (auth.can(Permission.openDocuments))
            for (final d in i.documents)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.description_outlined, color: c.accent),
                title: Text(d.label),
                subtitle: Text(d.fileName),
                trailing: OutlinedButton(onPressed: conflict ? null : () => _openDoc(d), child: Text(_openDocId == d.id ? 'Viewing' : 'Open')),
              ),
          if (_openDocId != null && _watermark != null)
            Container(
              height: 260,
              margin: const EdgeInsets.only(top: AdminSpace.x3),
              decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.hairline), borderRadius: BorderRadius.circular(AdminSpace.radiusSmall)),
              child: Stack(children: [
                Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.picture_as_pdf_outlined, size: 48, color: c.inkFaint), const SizedBox(height: 8), Text('Demo document preview: no real document exists in this build.', style: adminText(context, soft: true))])),
                Positioned.fill(child: IgnorePointer(child: Center(child: Transform.rotate(angle: -0.35, child: Text(_watermark!, style: adminText(context, size: 15, weight: FontWeight.w700, color: c.accent.withValues(alpha: 0.35))))))),
              ]),
            ),
        ]);
        final decisionCard = AdminCard(title: 'Checklist and decision', children: [
          if (conflict) Padding(padding: const EdgeInsets.only(bottom: AdminSpace.x3), child: AdminChip('You cannot review your own or a related account', tone: Tone.danger, icon: Icons.block)),
          if (second) Padding(padding: const EdgeInsets.only(bottom: AdminSpace.x3), child: AdminChip(blockSecond ? (firstApprover?.adminId == me?.id ? 'You gave the first approval: a different Senior Reviewer must finish it' : 'Final approval needs a Senior Reviewer') : 'Second approval (four-eyes)', tone: Tone.warning, icon: Icons.people_outline)),
          for (final k in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AdminSpace.x2),
              child: Row(children: [
                Expanded(child: Text(k, style: adminText(context))),
                SegmentedButton<bool>(
                  emptySelectionAllowed: true,
                  segments: const [ButtonSegment(value: true, label: Text('Pass')), ButtonSegment(value: false, label: Text('Fail'))],
                  selected: _checks[k] == null ? const <bool>{} : {_checks[k]!},
                  onSelectionChanged: !mine || conflict ? null : (s) => setState(() => s.isEmpty ? _checks.remove(k) : _checks[k] = s.first),
                ),
              ]),
            ),
          const Divider(height: AdminSpace.x6),
          SegmentedButton<DecisionOutcome>(
            segments: const [ButtonSegment(value: DecisionOutcome.approve, label: Text('Approve')), ButtonSegment(value: DecisionOutcome.requestResubmission, label: Text('Request resubmission')), ButtonSegment(value: DecisionOutcome.reject, label: Text('Reject'))],
            selected: {_outcome},
            onSelectionChanged: !mine || conflict ? null : (s) => setState(() => _outcome = s.first),
          ),
          const SizedBox(height: AdminSpace.x3),
          if (_outcome != DecisionOutcome.approve) ...[
            DropdownButtonFormField<ReasonCode>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Reason code (shown to the applicant)'),
              items: [for (final r in ReasonCode.values) DropdownMenuItem(value: r, child: Text(r.api))],
              onChanged: !mine ? null : (v) => setState(() => _reason = v),
            ),
            const SizedBox(height: AdminSpace.x3),
          ],
          TextField(controller: _note, enabled: mine && !conflict, maxLines: 3, maxLength: 500, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: _reason == ReasonCode.other ? 'Note (required for Other)' : 'Note (optional)', helperText: 'Visible to the applicant. Never include ID or document numbers.', helperMaxLines: 2)),
          if (_outcome == DecisionOutcome.approve && !allAnswered) Text('Give every checklist item a result to enable Approve.', style: adminText(context, size: 12, soft: true)),
          if (_outcome == DecisionOutcome.approve && allAnswered && !allPass) Text('A failed item cannot be approved. Choose resubmission or reject.', style: adminText(context, size: 12, color: c.danger)),
          const SizedBox(height: AdminSpace.x3),
          Wrap(spacing: AdminSpace.x2, runSpacing: AdminSpace.x2, children: [
            if (canDecide && i.open && !mine) FilledButton.icon(onPressed: conflict ? null : () => runAdmin(context, ref, () => ref.read(adminApiProvider).claim(i.id), success: 'Item claimed for 30 minutes.'), icon: const Icon(Icons.lock_outline, size: 18), label: Text(i.claimedBy == null ? 'Claim item' : 'Claimed by ${i.claimedByName}')),
            if (mine) FilledButton(onPressed: canSubmit ? () => _decide(i) : null, child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit decision')),
            if (mine) OutlinedButton(onPressed: () => runAdmin(context, ref, () => ref.read(adminApiProvider).release(i.id), success: 'Claim released.'), child: const Text('Release claim')),
            if (mine && i.status != QueueStatus.escalated) OutlinedButton(onPressed: () => runAdmin(context, ref, () => ref.read(adminApiProvider).escalate(i.id), success: 'Escalated to a Senior Reviewer.'), child: const Text('Escalate to Senior')),
          ]),
          if (!canDecide) Padding(padding: const EdgeInsets.only(top: AdminSpace.x2), child: Text('Your role is read-only for decisions.', style: adminText(context, size: 12, soft: true))),
        ]);
        final historyCard = AdminCard(title: 'Decision history', children: [
          if (i.history.isEmpty) Text('No decisions yet.', style: adminText(context, soft: true)),
          for (final h in i.history.reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(h.outcome == DecisionOutcome.approve ? Icons.check_circle_outline : Icons.error_outline, color: h.outcome == DecisionOutcome.approve ? c.success : c.warning),
              title: Text('${h.firstOfTwo ? 'First approval' : h.outcome.name} by ${h.adminName}'),
              subtitle: Text([fmtTime(h.at), if (h.reason != null) h.reason!.api, if (h.note.isNotEmpty) h.note].join(' · ')),
            ),
        ]);
        return AdminPage(
          title: i.subject,
          subtitle: '${entityLabel(i.type)} · ${queueStatusLabel(i.status)}',
          actions: [OutlinedButton.icon(onPressed: () => context.go('/queue'), icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Queue'))],
          children: [
            Wrap(spacing: AdminSpace.x2, children: [AdminChip(queueStatusLabel(i.status), tone: queueTone(i.status)), if (i.claimedByName != null) AdminChip('Claimed by ${i.claimedByName}', icon: Icons.lock_outline)]),
            const SizedBox(height: AdminSpace.x4),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [fieldsCard, docsCard])),
                const SizedBox(width: AdminSpace.x4),
                Expanded(child: Column(children: [decisionCard, historyCard])),
              ])
            else ...[fieldsCard, docsCard, decisionCard, historyCard],
          ],
        );
      },
    );
  }
}
