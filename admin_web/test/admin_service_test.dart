import 'package:aqarati_admin_web/data/admin_api.dart';
import 'package:aqarati_admin_web/data/admin_models.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DemoAdminApi> signedIn(String email, {DemoAdminApi? api, bool stepUp = true}) async {
  final a = api ?? DemoAdminApi(latency: Duration.zero);
  await a.signOut();
  await a.signIn(email, DemoAdminApi.demoPassword);
  await a.verifyTotp(DemoAdminApi.demoTotp);
  if (stepUp) await a.stepUp(DemoAdminApi.demoTotp);
  return a;
}

Map<String, bool> allPass(EntityType t) => {for (final k in checklists[t]!) k: true};

void main() {
  group('authentication', () {
    test('wrong password and wrong TOTP are refused and audited', () async {
      final a = DemoAdminApi(latency: Duration.zero);
      await expectLater(a.signIn('reviewer@aqarati.test', 'nope'), throwsA(isA<InvalidCredentials>()));
      await a.signIn('reviewer@aqarati.test', DemoAdminApi.demoPassword);
      await expectLater(a.verifyTotp('000000'), throwsA(isA<InvalidCredentials>()));
      expect(a.session, isNull, reason: 'no session before TOTP');
      await a.verifyTotp(DemoAdminApi.demoTotp);
      expect(a.session?.user.role, AdminRole.reviewer);
      final s = await signedIn('super@aqarati.test', api: a);
      final actions = (await s.audit()).map((e) => e.action).toList();
      expect(actions, containsAll(['admin.login_failed', 'admin.totp_failed', 'admin.login']));
    });

    test('an expired session is refused', () async {
      final a = await signedIn('reviewer@aqarati.test');
      a.debugExpireSession();
      await expectLater(a.queue(), throwsA(isA<SessionExpired>()));
    });
  });

  group('RBAC is enforced by the service, not the UI', () {
    test('an auditor can read the queue and audit log but cannot decide, open documents or suspend', () async {
      final a = await signedIn('auditor@aqarati.test');
      expect(await a.queue(), isNotEmpty);
      expect(await a.audit(), isNotEmpty);
      await expectLater(a.claim('Q-1001'), throwsA(isA<AdminForbidden>()));
      await expectLater(a.openDocument('Q-1001', 'd1'), throwsA(isA<AdminForbidden>()));
      await expectLater(a.suspend('acct-1', 'Licence expired'), throwsA(isA<AdminForbidden>()));
    });

    test('a reviewer cannot suspend, invite, manage admins or read the audit log', () async {
      final a = await signedIn('reviewer@aqarati.test');
      await expectLater(a.suspend('acct-1', 'Licence expired'), throwsA(isA<AdminForbidden>()));
      await expectLater(a.invite('Pools', 'p@example.test'), throwsA(isA<AdminForbidden>()));
      await expectLater(a.admins(), throwsA(isA<AdminForbidden>()));
      await expectLater(a.audit(), throwsA(isA<AdminForbidden>()));
    });

    test('a senior reviewer cannot invite providers or manage admins (Super Admin only)', () async {
      final a = await signedIn('senior@aqarati.test');
      await expectLater(a.invite('Pools', 'p@example.test'), throwsA(isA<AdminForbidden>()));
      await expectLater(a.createAdmin('X', 'x@example.test', AdminRole.reviewer), throwsA(isA<AdminForbidden>()));
    });
  });

  group('verification decisions', () {
    test('approve needs a claim, every checklist item, and a fresh step-up', () async {
      final a = await signedIn('reviewer@aqarati.test', stepUp: false);
      var item = (await a.item('Q-1001'))!;
      await expectLater(a.decide('Q-1001', version: item.version, outcome: DecisionOutcome.approve, checklist: allPass(item.type)), throwsA(isA<StepUpRequired>()));
      await a.stepUp(DemoAdminApi.demoTotp);
      await expectLater(a.decide('Q-1001', version: item.version, outcome: DecisionOutcome.approve, checklist: allPass(item.type)), throwsA(predicate((e) => e is AdminConflict && e.code == 'ITEM_CLAIMED')));
      item = await a.claim('Q-1001');
      await expectLater(a.decide('Q-1001', version: item.version, outcome: DecisionOutcome.approve, checklist: {checklists[item.type]!.first: true}), throwsA(predicate((e) => e is AdminConflict && e.code == 'CHECKLIST_INCOMPLETE')));
      final done = await a.decide('Q-1001', version: item.version, outcome: DecisionOutcome.approve, checklist: allPass(item.type));
      expect(done.status, QueueStatus.approved);
      expect(done.claimedBy, isNull);
    });

    test('reject needs a reason code; OTHER needs a note; notes with ID numbers are refused', () async {
      final a = await signedIn('reviewer@aqarati.test');
      var item = await a.claim('Q-1004');
      await expectLater(a.decide(item.id, version: item.version, outcome: DecisionOutcome.reject, checklist: const {}), throwsA(predicate((e) => e is AdminConflict && e.code == 'REASON_REQUIRED')));
      await expectLater(a.decide(item.id, version: item.version, outcome: DecisionOutcome.reject, checklist: const {}, reason: ReasonCode.other), throwsA(predicate((e) => e is AdminConflict && e.code == 'REASON_REQUIRED')));
      await expectLater(a.decide(item.id, version: item.version, outcome: DecisionOutcome.reject, checklist: const {}, reason: ReasonCode.nameMismatch, note: 'ID 12345678 does not match'), throwsA(predicate((e) => e is AdminConflict && e.code == 'NOTE_REJECTED')));
      item = (await a.item(item.id))!;
      final r = await a.decide(item.id, version: item.version, outcome: DecisionOutcome.requestResubmission, checklist: const {}, reason: ReasonCode.docUnreadable);
      expect(r.status, QueueStatus.resubmissionRequested);
      expect(r.history.last.reason, ReasonCode.docUnreadable);
    });

    test('a stale version is refused (optimistic lock)', () async {
      final a = await signedIn('reviewer@aqarati.test');
      final item = await a.claim('Q-1006');
      await expectLater(a.decide(item.id, version: item.version - 1, outcome: DecisionOutcome.approve, checklist: allPass(item.type)), throwsA(predicate((e) => e is AdminConflict && e.code == 'VERSION_MISMATCH')));
    });

    test('a reviewer cannot act on their own or a related account', () async {
      final a = await signedIn('reviewer@aqarati.test');
      await expectLater(a.claim('Q-1007'), throwsA(predicate((e) => e is AdminConflict && e.code == 'SELF_REVIEW')));
    });

    test('another admin cannot claim an item that is already claimed', () async {
      final api = await signedIn('reviewer@aqarati.test');
      await api.claim('Q-1003');
      await signedIn('senior@aqarati.test', api: api);
      await expectLater(api.claim('Q-1003'), throwsA(predicate((e) => e is AdminConflict && e.code == 'ITEM_CLAIMED')));
    });

    test('developers need four eyes: a reviewer records the first approval, a different senior finishes it', () async {
      final api = await signedIn('reviewer@aqarati.test');
      var item = await api.claim('Q-1002');
      item = await api.decide(item.id, version: item.version, outcome: DecisionOutcome.approve, checklist: allPass(item.type));
      expect(item.status, QueueStatus.awaitingSecondApproval, reason: 'first approval never publishes');

      // The same reviewer cannot finish it (and lacks the second-approval permission).
      item = await api.claim(item.id);
      await expectLater(api.decide(item.id, version: item.version, outcome: DecisionOutcome.approve, checklist: allPass(item.type)), throwsA(isA<AdminForbidden>()));
      await api.release(item.id);

      await signedIn('senior@aqarati.test', api: api);
      item = await api.claim(item.id);
      item = await api.decide(item.id, version: item.version, outcome: DecisionOutcome.approve, checklist: allPass(item.type));
      expect(item.status, QueueStatus.approved);
    });

    test('a senior who gave the first approval cannot give the second one', () async {
      final api = await signedIn('senior@aqarati.test');
      var item = await api.claim('Q-1002');
      item = await api.decide(item.id, version: item.version, outcome: DecisionOutcome.approve, checklist: allPass(item.type));
      item = await api.claim(item.id);
      await expectLater(api.decide(item.id, version: item.version, outcome: DecisionOutcome.approve, checklist: allPass(item.type)), throwsA(predicate((e) => e is AdminConflict && e.code == 'SAME_APPROVER')));
      await api.release(item.id);
      await signedIn('senior2@aqarati.test', api: api);
      item = await api.claim(item.id);
      expect((await api.decide(item.id, version: item.version, outcome: DecisionOutcome.approve, checklist: allPass(item.type))).status, QueueStatus.approved);
    });

    test('every decision and every document view is written to the append-only audit log', () async {
      final api = await signedIn('reviewer@aqarati.test');
      await api.openDocument('Q-1005', 'd1');
      final item = await api.claim('Q-1005');
      await api.decide(item.id, version: item.version, outcome: DecisionOutcome.reject, checklist: const {}, reason: ReasonCode.duplicateListing);
      await signedIn('super@aqarati.test', api: api);
      final log = await api.audit();
      expect(log.map((e) => e.action), containsAll(['document.viewed', 'queue.claimed', 'verification.decision']));
      final ids = log.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'monotonic ids, nothing overwritten');
    });
  });

  group('operations', () {
    test('suspend and reinstate need step-up and a reason, and are audited', () async {
      final api = await signedIn('senior@aqarati.test', stepUp: false);
      await expectLater(api.suspend('acct-1', 'Licence expired'), throwsA(isA<StepUpRequired>()));
      await api.stepUp(DemoAdminApi.demoTotp);
      await expectLater(api.suspend('acct-1', 'x'), throwsA(predicate((e) => e is AdminConflict && e.code == 'REASON_REQUIRED')));
      expect((await api.suspend('acct-1', 'Licence expired')).status, AccountStatus.suspended);
      expect((await api.reinstate('acct-1')).status, AccountStatus.active);
      expect((await api.audit()).map((e) => e.action), containsAll(['grant.suspended', 'grant.reinstated']));
    });

    test('provider invitations: Super Admin creates and revokes; duplicates are refused', () async {
      final api = await signedIn('super@aqarati.test');
      final inv = await api.invite('Demo AC (fictional)', 'ac@example.test');
      expect(inv.status, InvitationStatus.sent);
      await expectLater(api.invite('Again', 'ac@example.test'), throwsA(predicate((e) => e is AdminConflict && e.code == 'DUPLICATE_INVITE')));
      expect((await api.revokeInvitation(inv.id)).status, InvitationStatus.revoked);
    });

    test('moderation transitions follow the review state machine', () async {
      final api = await signedIn('reviewer@aqarati.test');
      expect((await api.moderate('M-1', ModerationStatus.published)).status, ModerationStatus.published);
      await expectLater(api.moderate('M-1', ModerationStatus.removed), throwsA(predicate((e) => e is AdminConflict && e.code == 'ILLEGAL_TRANSITION')));
      expect((await api.moderate('M-3', ModerationStatus.removed)).status, ModerationStatus.removed);
    });

    test('a new banner goes to the verification queue and is scheduled only after approval', () async {
      final api = await signedIn('senior@aqarati.test');
      final now = DateTime.now();
      final ad = await api.createAd(title: 'Open day', advertiser: 'Demo', link: 'https://example.test', placement: AdPlacement.homeTop, starts: now, ends: now.add(const Duration(days: 7)));
      expect(ad.status, AdStatus.inReview);
      final q = (await api.queue()).firstWhere((i) => i.subjectAccountId == ad.id);
      final claimed = await api.claim(q.id);
      await api.decide(q.id, version: claimed.version, outcome: DecisionOutcome.approve, checklist: allPass(EntityType.adBanner));
      expect((await api.ads()).firstWhere((a) => a.id == ad.id).status, AdStatus.scheduled);
    });

    test('a Super Admin cannot change or disable their own account', () async {
      final api = await signedIn('super@aqarati.test');
      await expectLater(api.updateAdmin('a3', active: false), throwsA(predicate((e) => e is AdminConflict && e.code == 'SELF_REVIEW')));
      expect((await api.updateAdmin('a1', active: false)).active, isFalse);
    });

    test('the queue is ordered: resubmissions first, then businesses, then listings, oldest first', () async {
      final api = await signedIn('reviewer@aqarati.test');
      final q = await api.queue();
      expect(q.first.resubmissions, greaterThan(0));
      final firstListing = q.indexWhere((i) => i.type == EntityType.listing);
      final lastBusiness = q.lastIndexWhere((i) => i.type == EntityType.agent || i.type == EntityType.development);
      expect(lastBusiness, lessThan(firstListing));
    });

    test('notes are checked for ID-number patterns', () {
      expect(noteLooksSafe('Please upload a clearer copy'), isTrue);
      expect(noteLooksSafe('ID 1234-5678-90'), isFalse);
    });
  });
}
