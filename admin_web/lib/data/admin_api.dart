import 'admin_models.dart';

/// Frontend contract for /api/v1/admin/* (sections 34, 35). Every permission is checked here, the way
/// the API checks it; the console also hides what a role cannot use, but hiding is never the control.
abstract class AdminApi {
  AdminSession? get session;

  /// Separate admin credentials (never the customer sign-in). Completes when a TOTP code is needed.
  Future<void> signIn(String email, String password);
  Future<AdminSession> verifyTotp(String code);
  Future<void> signOut();
  /// Step-up re-authentication before approve, reject or suspend; valid for 15 minutes.
  Future<void> stepUp(String code);

  Future<DashboardStats> dashboard();
  Future<List<QueueItem>> queue();
  Future<QueueItem?> item(String id);
  Future<QueueItem> claim(String id);
  Future<QueueItem> release(String id);
  /// Streams one document for viewing: watermarked with the viewer and audited per view.
  Future<String> openDocument(String itemId, String docId);
  Future<QueueItem> decide(String id, {required int version, required DecisionOutcome outcome, required Map<String, bool> checklist, ReasonCode? reason, String note = ''});
  Future<QueueItem> escalate(String id);

  Future<List<CustomerAccount>> accounts();
  Future<CustomerAccount> suspend(String id, String reason);
  Future<CustomerAccount> reinstate(String id);

  Future<List<ProviderInvite>> invitations();
  Future<ProviderInvite> invite(String companyName, String email);
  Future<ProviderInvite> revokeInvitation(String id);

  Future<List<ModerationItem>> moderation();
  Future<ModerationItem> moderate(String id, ModerationStatus to);

  Future<List<AdBanner>> ads();
  Future<AdBanner> createAd({required String title, required String advertiser, required String link, required AdPlacement placement, required DateTime starts, required DateTime ends});
  Future<AdBanner> setAdPaused(String id, bool paused);

  Future<List<AuditEvent>> audit();
  Future<List<AdminUser>> admins();
  Future<AdminUser> createAdmin(String name, String email, AdminRole role);
  Future<AdminUser> updateAdmin(String id, {AdminRole? role, bool? active});
}

/// A note shown to the user must not carry identity numbers (section 34.2: "validated to reject
/// ID-number patterns"). Seven or more digits in a row are treated as an ID number.
bool noteLooksSafe(String note) => !RegExp(r'\d{7,}').hasMatch(note.replaceAll(RegExp(r'[\s-]'), ''));

/// DEMO ONLY: an in-memory console backend so every screen can be reviewed. Accounts:
/// reviewer@aqarati.test, senior@aqarati.test, senior2@aqarati.test, super@aqarati.test,
/// auditor@aqarati.test; password `Demo-Admin-2026`; TOTP code `123456`. Never connect it to real data.
class DemoAdminApi implements AdminApi {
  DemoAdminApi({DateTime Function()? clock, this.latency = const Duration(milliseconds: 250)}) : _clock = clock ?? DateTime.now {
    _seed();
  }
  final DateTime Function() _clock;
  final Duration latency;
  static const demoPassword = 'Demo-Admin-2026';
  static const demoTotp = '123456';
  static const sessionLength = Duration(minutes: 30);
  static const stepUpWindow = Duration(minutes: 15);
  static const claimLength = Duration(minutes: 30);

  final List<AdminUser> _admins = [
    const AdminUser(id: 'a1', email: 'reviewer@aqarati.test', name: 'Reviewer (demo)', role: AdminRole.reviewer),
    const AdminUser(id: 'a2', email: 'senior@aqarati.test', name: 'Senior Reviewer (demo)', role: AdminRole.seniorReviewer),
    const AdminUser(id: 'a5', email: 'senior2@aqarati.test', name: 'Second Senior (demo)', role: AdminRole.seniorReviewer),
    const AdminUser(id: 'a3', email: 'super@aqarati.test', name: 'Super Admin (demo)', role: AdminRole.superAdmin),
    const AdminUser(id: 'a4', email: 'auditor@aqarati.test', name: 'Auditor (demo)', role: AdminRole.auditor),
  ];
  final Map<String, QueueItem> _queue = {};
  final List<AuditEvent> _audit = [];
  final List<ModerationItem> _moderation = [];
  final List<ProviderInvite> _invites = [];
  final List<AdBanner> _ads = [];
  final List<CustomerAccount> _accounts = [];
  AdminUser? _pending;
  AdminSession? _session;
  int _seq = 100;
  /// QA: make the next call fail like a network error.
  bool failNext = false;

  @override
  AdminSession? get session => _session;

  Future<void> _lag() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (failNext) {
      failNext = false;
      throw StateError('network');
    }
  }

  AdminUser _me() {
    final s = _session;
    if (s == null) throw const SessionExpired();
    if (_clock().isAfter(s.expiresAt)) {
      _log(s.user, 'admin.session_expired', 'admin_session', s.user.id);
      _session = null;
      throw const SessionExpired();
    }
    // Activity extends the short session.
    _session = AdminSession(user: s.user, expiresAt: _clock().add(sessionLength), steppedUpAt: s.steppedUpAt);
    return s.user;
  }

  AdminUser _require(Permission p) {
    final u = _me();
    if (!can(u.role, p)) {
      _log(u, 'admin.permission_denied', 'permission', p.name);
      throw AdminForbidden(p.name);
    }
    return u;
  }

  void _requireStepUp() {
    final at = _session?.steppedUpAt;
    if (at == null || _clock().difference(at) > stepUpWindow) throw const StepUpRequired();
  }

  void _log(AdminUser? u, String action, String entity, String id, {String? before, String? after, String? reason}) => _audit.add(AuditEvent(
        id: _audit.length + 1,
        at: _clock(),
        actorType: u == null ? 'system' : 'admin',
        actorId: u?.id ?? 'system',
        actorLabel: u?.name ?? 'System',
        action: action,
        entity: entity,
        entityId: id,
        before: before,
        after: after,
        reason: reason,
        ip: u == null ? null : '203.0.113.10 (demo)',
      ));

  void _seed() {
    final now = _clock();
    QueueItem q(String id, EntityType t, String subject, int hoursAgo, Map<String, String> fields, List<DocRef> docs, {int resub = 0, Set<String> related = const {}, bool dup = false}) =>
        QueueItem(id: id.startsWith('AD-') ? 'Q-1009' : id, type: t, subject: subject, subjectAccountId: id.startsWith('AD-') ? id : 'acct-$id', submittedAt: now.subtract(Duration(hours: hoursAgo)), resubmissions: resub, fields: fields, documents: docs, relatedAdminIds: related, duplicateSuspected: dup);
    for (final i in [
      q('Q-1001', EntityType.agent, 'Agent applicant A (demo)', 5, {'Agency': 'Demo Realty (fictional)', 'Phone': '+968 •••• 0011', 'Licence expiry': 'Entered by applicant'}, const [DocRef('d1', 'Photo ID', 'photo-id.jpg'), DocRef('d2', 'Agent licence', 'licence.pdf'), DocRef('d3', 'Supporting document', 'support.pdf')]),
      q('Q-1002', EntityType.development, 'Developer applicant B (demo)', 20, {'Company': 'Demo Developments (fictional)', 'Company email': 'owner@example.test', 'Address': 'Muscat (demo)'}, const [DocRef('d1', 'Official corporate registration', 'registration.pdf'), DocRef('d2', 'CR certificate', 'cr.pdf'), DocRef('d3', 'Activity licences', 'activity.pdf'), DocRef('d4', 'Developer licence', 'developer-licence.pdf')]),
      q('Q-1003', EntityType.construction, 'Construction applicant C (demo)', 30, {'Company': 'Demo Contracting (fictional)', 'Address': 'Sohar (demo)'}, const [DocRef('d1', 'CR certificate', 'cr.pdf'), DocRef('d2', 'Municipal licence', 'municipal.pdf')], resub: 1),
      q('Q-1004', EntityType.interiorExterior, 'Design applicant D (demo)', 3, {'Company': 'Demo Interiors (fictional)', 'Service type': 'Both'}, const [DocRef('d1', 'CR certificate', 'cr.pdf'), DocRef('d2', 'Municipal licence', 'municipal.pdf')]),
      q('Q-1005', EntityType.listing, 'Listing L-0001 · Villa for sale (demo)', 8, {'Channel': 'Aqary e-Broker', 'Price': 'OMR (demo value)', 'Deed number': 'ends 271', 'Location': 'Bawshar, Muscat'}, const [DocRef('d1', 'Title deed', 'deed.pdf'), DocRef('d2', 'Seller photo ID', 'photo-id.jpg')], dup: true),
      q('Q-1006', EntityType.provider, 'Maintenance provider E (demo)', 12, {'Company': 'Demo Maintenance Co. (fictional)', 'Services': 'AC, Plumber', 'Area': 'Seeb, Bawshar'}, const [DocRef('d1', 'CR certificate', 'cr.pdf'), DocRef('d2', 'Municipal licence', 'municipal.pdf')]),
      q('Q-1007', EntityType.architecture, 'Architecture applicant F (demo)', 40, {'Company': 'Demo Studio (fictional)', 'Address': 'Nizwa (demo)'}, const [DocRef('d1', 'CR certificate', 'cr.pdf'), DocRef('d2', 'Municipal licence', 'municipal.pdf')], related: {'a1'}),
      q('Q-1008', EntityType.changeSet, 'Change set on listing L-0002 (demo)', 2, {'Changed fields': 'Photos, bedrooms', 'Live version': 'Stays live during review'}, const [DocRef('d1', 'New photos', 'photos.zip')]),
      q('AD-1', EntityType.adBanner, 'Banner: "Spring open house" (demo)', 6, {'Advertiser': 'Demo Advertiser (fictional)', 'Placement': 'Home top', 'Schedule': 'Two weeks'}, const [DocRef('d1', 'Creative', 'banner.png')]),
    ]) {
      _queue[i.id] = i;
    }
    _moderation.addAll([
      ModerationItem(id: 'M-1', kind: ModerationKind.newReview, targetName: 'Demo Contracting (fictional)', targetType: 'Professional', stars: 4, comment: 'Demo review text: clear communication and the work finished as agreed.', status: ModerationStatus.pendingModeration, submittedAt: now.subtract(const Duration(hours: 4))),
      ModerationItem(id: 'M-2', kind: ModerationKind.editedReview, targetName: 'Demo Maintenance Co. (fictional)', targetType: 'Provider', stars: 2, comment: 'Demo edited review: the technician arrived later than agreed.', status: ModerationStatus.pendingModeration, submittedAt: now.subtract(const Duration(hours: 9))),
      ModerationItem(id: 'M-3', kind: ModerationKind.reported, targetName: 'Demo Broker · Muscat', targetType: 'Seller', stars: 1, comment: 'Demo published review that was reported.', reportReason: 'Reporter says it is about a different agent (demo).', status: ModerationStatus.underReview, submittedAt: now.subtract(const Duration(days: 1))),
    ]);
    _invites.add(ProviderInvite(id: 'I-1', companyName: 'Demo Pools (fictional)', email: 'pools@example.test', createdBy: 'Super Admin (demo)', status: InvitationStatus.sent, createdAt: now.subtract(const Duration(days: 2)), expiresAt: now.add(const Duration(days: 5))));
    _ads.add(AdBanner(id: 'AD-1', title: 'Spring open house (demo)', advertiser: 'Demo Advertiser (fictional)', link: 'https://example.test', placement: AdPlacement.homeTop, starts: now.add(const Duration(days: 1)), ends: now.add(const Duration(days: 15)), status: AdStatus.inReview));
    _accounts.addAll(const [
      CustomerAccount(id: 'acct-1', name: 'Demo Contracting (fictional)', kind: 'Construction company'),
      CustomerAccount(id: 'acct-2', name: 'Agent applicant A (demo)', kind: 'Real estate agent'),
      CustomerAccount(id: 'acct-3', name: 'Demo Maintenance Co. (fictional)', kind: 'Maintenance provider'),
      CustomerAccount(id: 'acct-4', name: 'Demo Studio (fictional)', kind: 'Building architecture', status: AccountStatus.suspended, suspensionReason: 'Licence expired (demo)'),
    ]);
    _log(null, 'system.seeded_demo_data', 'console', 'demo');
  }

  // ------------------------------------------------------------------ auth

  @override
  Future<void> signIn(String email, String password) async {
    await _lag();
    final u = _admins.where((a) => a.email.toLowerCase() == email.trim().toLowerCase() && a.active).firstOrNull;
    if (u == null || password != demoPassword) {
      _log(null, 'admin.login_failed', 'admin_session', email.trim().toLowerCase());
      throw const InvalidCredentials();
    }
    _pending = u;
  }

  @override
  Future<AdminSession> verifyTotp(String code) async {
    await _lag();
    final u = _pending;
    if (u == null) throw const SessionExpired();
    if (code != demoTotp) {
      _log(u, 'admin.totp_failed', 'admin_session', u.id);
      throw const InvalidCredentials();
    }
    _pending = null;
    _session = AdminSession(user: u, expiresAt: _clock().add(sessionLength));
    _log(u, 'admin.login', 'admin_session', u.id);
    return _session!;
  }

  @override
  Future<void> signOut() async {
    final u = _session?.user;
    if (u != null) _log(u, 'admin.logout', 'admin_session', u.id);
    _session = null;
    _pending = null;
  }

  @override
  Future<void> stepUp(String code) async {
    await _lag();
    final u = _me();
    if (code != demoTotp) {
      _log(u, 'admin.step_up_failed', 'admin_session', u.id);
      throw const InvalidCredentials();
    }
    _session = AdminSession(user: u, expiresAt: _session!.expiresAt, steppedUpAt: _clock());
    _log(u, 'admin.step_up', 'admin_session', u.id);
  }

  /// QA: expire the session now so the expiry screen can be reviewed.
  void debugExpireSession() {
    final s = _session;
    if (s != null) _session = AdminSession(user: s.user, expiresAt: _clock().subtract(const Duration(seconds: 1)));
  }

  // ------------------------------------------------------------------ queue

  @override
  Future<DashboardStats> dashboard() async {
    await _lag();
    _require(Permission.viewQueue);
    final open = _queue.values.where((i) => i.open).toList();
    final byType = <EntityType, int>{};
    for (final i in open) {
      byType[i.type] = (byType[i.type] ?? 0) + 1;
    }
    final oldest = open.isEmpty ? null : open.map((i) => i.submittedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final decided = _queue.values.where((i) => !i.open && i.history.isNotEmpty).toList();
    Duration? avg;
    if (decided.isNotEmpty) {
      final total = decided.fold<int>(0, (s, i) => s + i.history.last.at.difference(i.submittedAt).inMinutes);
      avg = Duration(minutes: total ~/ decided.length);
    }
    return DashboardStats(
      pendingByType: byType,
      oldestAge: oldest == null ? null : _clock().difference(oldest),
      approved: _queue.values.where((i) => i.status == QueueStatus.approved).length,
      rejected: _queue.values.where((i) => i.status == QueueStatus.rejected).length,
      resubmissions: _queue.values.where((i) => i.status == QueueStatus.resubmissionRequested).length,
      awaitingSecond: _queue.values.where((i) => i.status == QueueStatus.awaitingSecondApproval).length,
      averageTurnaround: avg,
    );
  }

  QueueItem _expireClaim(QueueItem i) => i.claimExpiresAt != null && _clock().isAfter(i.claimExpiresAt!) ? (_queue[i.id] = i.copyWith(claimedBy: null, claimedByName: null, claimExpiresAt: null)) : i;

  @override
  Future<List<QueueItem>> queue() async {
    await _lag();
    _require(Permission.viewQueue);
    // Queue views are not audited individually; opening an item is (section 34.1).
    return (_queue.values.map(_expireClaim).toList()..sort(queueOrder));
  }

  @override
  Future<QueueItem?> item(String id) async {
    await _lag();
    final u = _require(Permission.viewQueue);
    final i = _queue[id];
    if (i != null) _log(u, 'queue.item_opened', 'verification_queue', id);
    return i == null ? null : _expireClaim(i);
  }

  @override
  Future<QueueItem> claim(String id) async {
    await _lag();
    final u = _require(Permission.decide);
    final i = _expireClaim(_queue[id] ?? (throw const AdminConflict('NOT_FOUND')));
    if (!i.open) throw const AdminConflict('ILLEGAL_TRANSITION');
    if (i.relatedAdminIds.contains(u.id)) throw const AdminConflict('SELF_REVIEW');
    if (i.claimedBy != null && i.claimedBy != u.id) throw const AdminConflict('ITEM_CLAIMED');
    _log(u, 'queue.claimed', 'verification_queue', id);
    return _queue[id] = i.copyWith(claimedBy: u.id, claimedByName: u.name, claimExpiresAt: _clock().add(claimLength));
  }

  @override
  Future<QueueItem> release(String id) async {
    await _lag();
    final u = _require(Permission.decide);
    final i = _queue[id] ?? (throw const AdminConflict('NOT_FOUND'));
    if (i.claimedBy != u.id) throw const AdminConflict('ITEM_CLAIMED');
    _log(u, 'queue.released', 'verification_queue', id);
    return _queue[id] = i.copyWith(claimedBy: null, claimedByName: null, claimExpiresAt: null);
  }

  @override
  Future<String> openDocument(String itemId, String docId) async {
    await _lag();
    final u = _require(Permission.openDocuments);
    final i = _queue[itemId] ?? (throw const AdminConflict('NOT_FOUND'));
    if (i.relatedAdminIds.contains(u.id)) throw const AdminConflict('SELF_REVIEW');
    final d = i.documents.firstWhere((d) => d.id == docId, orElse: () => throw const AdminConflict('NOT_FOUND'));
    _log(u, 'document.viewed', 'verification_documents', '$itemId/${d.id}');
    return 'Viewed by ${u.name} · ${_clock().toUtc().toIso8601String().substring(0, 16)} UTC';
  }

  @override
  Future<QueueItem> decide(String id, {required int version, required DecisionOutcome outcome, required Map<String, bool> checklist, ReasonCode? reason, String note = ''}) async {
    await _lag();
    final u = _require(Permission.decide);
    _requireStepUp();
    final i = _expireClaim(_queue[id] ?? (throw const AdminConflict('NOT_FOUND')));
    if (i.version != version) throw const AdminConflict('VERSION_MISMATCH');
    if (!i.open) throw const AdminConflict('ILLEGAL_TRANSITION');
    if (i.relatedAdminIds.contains(u.id)) throw const AdminConflict('SELF_REVIEW');
    if (i.claimedBy != u.id) throw const AdminConflict('ITEM_CLAIMED');
    final items = checklists[i.type]!;
    if (outcome == DecisionOutcome.approve) {
      if (items.any((k) => checklist[k] == null)) throw const AdminConflict('CHECKLIST_INCOMPLETE');
      if (items.any((k) => checklist[k] == false)) throw const AdminConflict('CHECKLIST_FAILED');
    } else {
      if (reason == null) throw const AdminConflict('REASON_REQUIRED');
      if (reason == ReasonCode.other && note.trim().isEmpty) throw const AdminConflict('REASON_REQUIRED');
    }
    if (!noteLooksSafe(note)) throw const AdminConflict('NOTE_REJECTED');
    final rec = DecisionRecord(outcome: outcome, adminId: u.id, adminName: u.name, at: _clock(), reason: reason, note: note.trim());
    late QueueStatus next;
    var firstOfTwo = false;
    if (outcome == DecisionOutcome.approve && needsFourEyes(i.type)) {
      if (i.status == QueueStatus.awaitingSecondApproval) {
        if (!can(u.role, Permission.secondApproval)) throw const AdminForbidden('secondApproval');
        if (i.firstApproval?.adminId == u.id) throw const AdminConflict('SAME_APPROVER');
        next = QueueStatus.approved;
      } else {
        next = QueueStatus.awaitingSecondApproval;
        firstOfTwo = true;
      }
    } else {
      next = switch (outcome) {
        DecisionOutcome.approve => QueueStatus.approved,
        DecisionOutcome.requestResubmission => QueueStatus.resubmissionRequested,
        DecisionOutcome.reject => QueueStatus.rejected,
      };
    }
    final record = firstOfTwo ? DecisionRecord(outcome: rec.outcome, adminId: rec.adminId, adminName: rec.adminName, at: rec.at, reason: rec.reason, note: rec.note, firstOfTwo: true) : rec;
    // The item and its history change in one step, with the audit row (section 34.2).
    final updated = i.copyWith(status: next, history: [...i.history, record], claimedBy: null, claimedByName: null, claimExpiresAt: null);
    _queue[id] = updated;
    // A banner decision updates the banner itself: approved banners are scheduled, never live early.
    if (i.type == EntityType.adBanner && (next == QueueStatus.approved || next == QueueStatus.rejected)) {
      final a = _ads.indexWhere((x) => x.id == i.subjectAccountId);
      if (a >= 0) _ads[a] = _ads[a].copyWith(next == QueueStatus.approved ? AdStatus.scheduled : AdStatus.rejected);
    }
    _log(u, 'verification.decision', 'verification_queue', id, before: i.status.name, after: next.name, reason: reason?.api);
    return updated;
  }

  @override
  Future<QueueItem> escalate(String id) async {
    await _lag();
    final u = _require(Permission.decide);
    final i = _queue[id] ?? (throw const AdminConflict('NOT_FOUND'));
    if (i.claimedBy != u.id) throw const AdminConflict('ITEM_CLAIMED');
    _log(u, 'verification.escalated', 'verification_queue', id, before: i.status.name, after: QueueStatus.escalated.name);
    return _queue[id] = i.copyWith(status: QueueStatus.escalated, claimedBy: null, claimedByName: null, claimExpiresAt: null);
  }

  // ------------------------------------------------------------------ accounts

  @override
  Future<List<CustomerAccount>> accounts() async {
    await _lag();
    _require(Permission.viewQueue);
    return List.unmodifiable(_accounts);
  }

  @override
  Future<CustomerAccount> suspend(String id, String reason) async {
    await _lag();
    final u = _require(Permission.suspend);
    _requireStepUp();
    if (reason.trim().length < 5 || !noteLooksSafe(reason)) throw const AdminConflict('REASON_REQUIRED');
    final i = _accounts.indexWhere((a) => a.id == id);
    if (i < 0) throw const AdminConflict('NOT_FOUND');
    if (_accounts[i].status == AccountStatus.suspended) throw const AdminConflict('ILLEGAL_TRANSITION');
    _log(u, 'grant.suspended', 'role_grants', id, before: 'active', after: 'suspended', reason: reason.trim());
    return _accounts[i] = _accounts[i].copyWith(AccountStatus.suspended, reason.trim());
  }

  @override
  Future<CustomerAccount> reinstate(String id) async {
    await _lag();
    final u = _require(Permission.suspend);
    _requireStepUp();
    final i = _accounts.indexWhere((a) => a.id == id);
    if (i < 0) throw const AdminConflict('NOT_FOUND');
    if (_accounts[i].status != AccountStatus.suspended) throw const AdminConflict('ILLEGAL_TRANSITION');
    _log(u, 'grant.reinstated', 'role_grants', id, before: 'suspended', after: 'active');
    return _accounts[i] = _accounts[i].copyWith(AccountStatus.active, null);
  }

  // ------------------------------------------------------------------ invitations

  @override
  Future<List<ProviderInvite>> invitations() async {
    await _lag();
    _require(Permission.invite);
    final now = _clock();
    for (var i = 0; i < _invites.length; i++) {
      if (_invites[i].status == InvitationStatus.sent && now.isAfter(_invites[i].expiresAt)) _invites[i] = _invites[i].copyWith(InvitationStatus.expired);
    }
    return List.unmodifiable(_invites.reversed);
  }

  @override
  Future<ProviderInvite> invite(String companyName, String email) async {
    await _lag();
    final u = _require(Permission.invite);
    if (companyName.trim().length < 2 || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) throw const AdminConflict('VALIDATION_FAILED');
    if (_invites.any((i) => i.email.toLowerCase() == email.trim().toLowerCase() && i.status == InvitationStatus.sent)) throw const AdminConflict('DUPLICATE_INVITE');
    final now = _clock();
    final inv = ProviderInvite(id: 'I-${++_seq}', companyName: companyName.trim(), email: email.trim(), createdBy: u.name, status: InvitationStatus.sent, createdAt: now, expiresAt: now.add(const Duration(days: 7)));
    _invites.add(inv);
    _log(u, 'admin.invitation_created', 'invitations', inv.id);
    return inv;
  }

  @override
  Future<ProviderInvite> revokeInvitation(String id) async {
    await _lag();
    final u = _require(Permission.invite);
    final i = _invites.indexWhere((x) => x.id == id);
    if (i < 0 || _invites[i].status != InvitationStatus.sent) throw const AdminConflict('ILLEGAL_TRANSITION');
    _log(u, 'admin.invitation_revoked', 'invitations', id);
    return _invites[i] = _invites[i].copyWith(InvitationStatus.revoked);
  }

  // ------------------------------------------------------------------ moderation

  @override
  Future<List<ModerationItem>> moderation() async {
    await _lag();
    _require(Permission.viewQueue);
    return List.unmodifiable(_moderation);
  }

  @override
  Future<ModerationItem> moderate(String id, ModerationStatus to) async {
    await _lag();
    final u = _require(Permission.moderateReviews);
    final i = _moderation.indexWhere((m) => m.id == id);
    if (i < 0) throw const AdminConflict('NOT_FOUND');
    final m = _moderation[i];
    final ok = switch (m.status) {
      ModerationStatus.pendingModeration => to == ModerationStatus.published || to == ModerationStatus.rejected,
      ModerationStatus.underReview => to == ModerationStatus.published || to == ModerationStatus.removed,
      _ => false,
    };
    if (!ok) throw const AdminConflict('ILLEGAL_TRANSITION');
    _log(u, 'review.moderated', 'reviews', id, before: m.status.name, after: to.name);
    return _moderation[i] = m.copyWith(to, u.name);
  }

  // ------------------------------------------------------------------ ads

  @override
  Future<List<AdBanner>> ads() async {
    await _lag();
    _require(Permission.manageAds);
    return List.unmodifiable(_ads.reversed);
  }

  @override
  Future<AdBanner> createAd({required String title, required String advertiser, required String link, required AdPlacement placement, required DateTime starts, required DateTime ends}) async {
    await _lag();
    final u = _require(Permission.manageAds);
    if (title.trim().isEmpty || advertiser.trim().isEmpty || !ends.isAfter(starts) || !(Uri.tryParse(link.trim())?.hasScheme ?? false)) throw const AdminConflict('VALIDATION_FAILED');
    final ad = AdBanner(id: 'AD-${++_seq}', title: title.trim(), advertiser: advertiser.trim(), link: link.trim(), placement: placement, starts: starts, ends: ends, status: AdStatus.inReview);
    _ads.add(ad);
    // Every banner passes the verification queue before it can serve (section 84).
    final q = QueueItem(id: 'Q-${++_seq}', type: EntityType.adBanner, subject: 'Banner: "${ad.title}"', subjectAccountId: ad.id, submittedAt: _clock(), fields: {'Advertiser': ad.advertiser, 'Placement': ad.placement.name, 'Link': ad.link}, documents: const [DocRef('d1', 'Creative', 'creative.png')]);
    _queue[q.id] = q;
    _log(u, 'ad.created', 'ads', ad.id);
    return ad;
  }

  @override
  Future<AdBanner> setAdPaused(String id, bool paused) async {
    await _lag();
    final u = _require(Permission.manageAds);
    final i = _ads.indexWhere((a) => a.id == id);
    if (i < 0) throw const AdminConflict('NOT_FOUND');
    final a = _ads[i];
    final allowed = paused ? (a.status == AdStatus.live || a.status == AdStatus.scheduled) : a.status == AdStatus.paused;
    if (!allowed) throw const AdminConflict('ILLEGAL_TRANSITION');
    _log(u, paused ? 'ad.paused' : 'ad.resumed', 'ads', id);
    return _ads[i] = a.copyWith(paused ? AdStatus.paused : AdStatus.scheduled);
  }

  // ------------------------------------------------------------------ audit + admins

  @override
  Future<List<AuditEvent>> audit() async {
    await _lag();
    _require(Permission.viewAudit);
    return List.unmodifiable(_audit.reversed);
  }

  @override
  Future<List<AdminUser>> admins() async {
    await _lag();
    _require(Permission.manageAdmins);
    return List.unmodifiable(_admins);
  }

  @override
  Future<AdminUser> createAdmin(String name, String email, AdminRole role) async {
    await _lag();
    final u = _require(Permission.manageAdmins);
    if (name.trim().isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) throw const AdminConflict('VALIDATION_FAILED');
    if (_admins.any((a) => a.email.toLowerCase() == email.trim().toLowerCase())) throw const AdminConflict('DUPLICATE_ADMIN');
    final a = AdminUser(id: 'a${++_seq}', email: email.trim(), name: name.trim(), role: role);
    _admins.add(a);
    _log(u, 'admin.user_created', 'admin_users', a.id, after: role.name);
    return a;
  }

  @override
  Future<AdminUser> updateAdmin(String id, {AdminRole? role, bool? active}) async {
    await _lag();
    final u = _require(Permission.manageAdmins);
    if (id == u.id) throw const AdminConflict('SELF_REVIEW');
    final i = _admins.indexWhere((a) => a.id == id);
    if (i < 0) throw const AdminConflict('NOT_FOUND');
    final before = _admins[i];
    _admins[i] = before.copyWith(role: role, active: active);
    _log(u, active == null ? 'admin.role_changed' : (active ? 'admin.user_enabled' : 'admin.user_disabled'), 'admin_users', id, before: '${before.role.name}/${before.active}', after: '${_admins[i].role.name}/${_admins[i].active}');
    return _admins[i];
  }
}
