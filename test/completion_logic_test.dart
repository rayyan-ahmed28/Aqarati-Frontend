import 'package:aqarati_app/core/config/app_version.dart';
import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/data/demo/demo_backend.dart';
import 'package:aqarati_app/features/broker/broker_data.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/listings/listing_models.dart';
import 'package:aqarati_app/features/listings/listing_repository.dart';
import 'package:aqarati_app/features/maintenance/maintenance_models.dart';
import 'package:aqarati_app/features/provider/provider_data.dart';
import 'package:aqarati_app/features/reviews/review_models.dart';
import 'package:aqarati_app/features/reviews/review_repository.dart';
import 'package:aqarati_app/data/repositories/property_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const buyer = MeSession(account: AccountState.active);
const agent = MeSession(account: AccountState.active, purpose: SignupPurpose.realEstateAgent, grant: GrantState.approved);
const pendingAgent = MeSession(account: AccountState.active, purpose: SignupPurpose.realEstateAgent, grant: GrantState.pendingVerification);

ListingDraft complete(ListingChannel ch, {String deed = '12345'}) => ListingDraft(
      channel: ch,
      market: ListingMarket.residential,
      action: ListingAction.buy,
      subType: ListingSubType.villa,
      governorate: 'Muscat',
      wilayat: 'Bawshar',
      price: '185000',
      title: 'Family villa near the beach',
      beds: 4,
      baths: 3,
      landSqm: '600',
      buildSqm: '420',
      photos: const [ListingFile(name: 'a.jpg', sizeBytes: 1, asset: 'x')],
      deedNumber: deed,
      deedFile: const ListingFile(name: 'deed.pdf', sizeBytes: 1),
      feeAccepted: true,
      declaration: true,
    );

DemoListingRepository repo(MeSession? me) => DemoListingRepository(session: () async => me, latency: Duration.zero);

void main() {
  group('listing taxonomy and validation (architecture §81.1, §16.2)', () {
    test('markets and listing types follow the confirmed taxonomy; Lease is not a type', () {
      expect(actionsFor(ListingMarket.industrial, ListingChannel.agent), [ListingAction.buy, ListingAction.invest]);
      expect(subTypesFor(ListingMarket.agriculture, ListingAction.rent), [ListingSubType.farmHouse]);
      expect(subTypesFor(ListingMarket.commercial, ListingAction.rent), isNot(contains(ListingSubType.storage)));
      expect(ListingAction.values.map((a) => a.name), isNot(contains('lease')));
    });

    test('Aqary e-Broker is an owner sale (Residential, buy listing)', () {
      expect(eBrokerMarkets, [ListingMarket.residential]);
      expect(actionsFor(ListingMarket.residential, ListingChannel.eBroker), [ListingAction.buy]);
    });

    test('only the size and room fields that apply to the sub-type are required', () {
      final land = validateListingStep(const ListingDraft(channel: ListingChannel.agent, market: ListingMarket.residential, action: ListingAction.buy, subType: ListingSubType.land, price: '5000', title: 'Plot in Al Khoudh'), ListingStep.facts);
      expect(land.keys, ['land']);
      final flat = validateListingStep(const ListingDraft(channel: ListingChannel.agent, subType: ListingSubType.apartment, price: '450', title: 'Sea-view apartment'), ListingStep.facts);
      expect(flat.keys.toSet(), {'beds', 'baths', 'build'});
    });

    test('price is OMR with at most three decimals', () {
      expect(parseOmr('185,000.500'), 185000.5);
      expect(parseOmr('1.2345'), isNull);
      expect(parseOmr('0'), isNull);
    });

    test('e-Broker needs the deed document and the fee notice; agents need deed or authorisation', () {
      final eb = complete(ListingChannel.eBroker).copyWith(deedFile: null, feeAccepted: false);
      expect(validateListingStep(eb, ListingStep.documents).keys, ['deedFile']);
      expect(validateListingStep(eb, ListingStep.review).keys, ['fee']);
      final ag = complete(ListingChannel.agent).copyWith(deedFile: null, authorisationFile: const ListingFile(name: 'auth.pdf', sizeBytes: 1));
      expect(validateListingStep(ag, ListingStep.documents), isEmpty);
    });
  });

  group('listing lifecycle (demo repository mirrors the API contract)', () {
    test('only an approved agent can submit agent listings', () async {
      await expectLater(repo(pendingAgent).submit(complete(ListingChannel.agent), idempotencyKey: 'k'), throwsA(isA<ListingNotAllowedException>()));
      final l = await repo(agent).submit(complete(ListingChannel.agent), idempotencyKey: 'k');
      expect(l.state, ListingState.pending, reason: 'a submission is never live');
    });

    test('e-Broker needs the seller photo ID first, then any active account can submit', () async {
      final r = repo(buyer);
      await expectLater(r.submit(complete(ListingChannel.eBroker), idempotencyKey: 'k'), throwsA(isA<ListingNotAllowedException>()));
      await r.uploadSellerId(const ListingFile(name: 'id.jpg', sizeBytes: 1));
      expect(await r.sellerId(), SellerIdState.pendingReview);
      expect((await r.submit(complete(ListingChannel.eBroker), idempotencyKey: 'k')).state, ListingState.pending);
    });

    test('the same idempotency key never creates a second listing; a used deed is a duplicate', () async {
      final r = repo(agent);
      final a = await r.submit(complete(ListingChannel.agent), idempotencyKey: 'same');
      final b = await r.submit(complete(ListingChannel.agent), idempotencyKey: 'same');
      expect(b.id, a.id);
      expect(await r.mine(), hasLength(1));
      await expectLater(r.submit(complete(ListingChannel.agent), idempotencyKey: 'other'), throwsA(isA<DuplicateListingException>()));
      await expectLater(r.submit(complete(ListingChannel.agent, deed: '0000'), idempotencyKey: 'x'), throwsA(isA<DuplicateListingException>()));
    });

    test('the deed number is not kept: only its last characters', () async {
      final l = await repo(agent).submit(complete(ListingChannel.agent, deed: '998877'), idempotencyKey: 'k');
      expect(l.deedHint, '877');
    });

    test('owner lifecycle actions follow the state machine', () async {
      final r = repo(agent);
      final l = await r.submit(complete(ListingChannel.agent), idempotencyKey: 'k');
      await expectLater(r.setLifecycle(l.id, ListingState.sold), throwsA(isA<ApiException>()), reason: 'pending cannot be sold');
      r.debugDecide(l.id, ListingState.approvedActive);
      await expectLater(r.setLifecycle(l.id, ListingState.rented), throwsA(isA<ApiException>()), reason: 'a sale listing cannot be rented');
      expect((await r.setLifecycle(l.id, ListingState.sold)).state, ListingState.sold);
    });

    test('expired listings renew for another 90 days', () async {
      final r = repo(agent);
      final l = await r.submit(complete(ListingChannel.agent), idempotencyKey: 'k');
      r.debugDecide(l.id, ListingState.approvedActive);
      r.debugExpire(l.id);
      final renewed = await r.renew(l.id);
      expect(renewed.state, ListingState.approvedActive);
      expect(renewed.expiresAt!.difference(DateTime.now()).inDays, closeTo(kListingLiveDays, 1));
    });

    test('edits after approval: price applies now, photos open one change set at a time', () async {
      final r = repo(agent);
      final l = await r.submit(complete(ListingChannel.agent), idempotencyKey: 'k');
      r.debugDecide(l.id, ListingState.approvedActive);
      final live = (await r.get(l.id))!;
      final res = await r.edit(l.id, live.toDraft().copyWith(price: '190000', photos: [...live.photos, const ListingFile(name: 'b.jpg', sizeBytes: 1)]));
      expect(res.appliedNow, {'price'});
      expect(res.underReview, {'photos'});
      expect(res.listing.price, 190000);
      expect(res.listing.state, ListingState.approvedActive, reason: 'the approved version stays live');
      await expectLater(r.edit(l.id, live.toDraft()), throwsA(isA<ChangeSetOpenException>()));
    });

    test('resubmission is only possible after "changes requested" and returns to pending', () async {
      final r = repo(agent);
      final l = await r.submit(complete(ListingChannel.agent), idempotencyKey: 'k');
      await expectLater(r.resubmit(l.id, l.toDraft()), throwsA(isA<ApiException>()));
      r.debugDecide(l.id, ListingState.resubmissionRequired, reason: 'PHOTOS_MISMATCH');
      final fixed = (await r.get(l.id))!.toDraft().copyWith(declaration: true);
      expect((await r.resubmit(l.id, fixed)).state, ListingState.pending);
    });

    test('drafts are saved without the deed number', () async {
      final r = repo(agent);
      final id = await r.saveDraft(complete(ListingChannel.agent));
      expect((await r.draft(id))!.deedNumber, isEmpty);
    });
  });

  group('AqaratiBroker programme', () {
    test('directory filters by governorate and text; listings are approved programme properties only', () async {
      final r = DemoBrokerRepository(() => MockPropertyRepository().search(), latency: Duration.zero);
      expect((await r.search(const BrokerQuery(governorate: 'Dhofar'))).map((b) => b.id), ['ab2']);
      expect((await r.search(const BrokerQuery(text: 'seeb'))).map((b) => b.id), ['ab3']);
      final ls = await r.listings('ab1');
      expect(ls.map((p) => p.id).toSet().difference({'p1', 'p2'}), isEmpty);
      expect(ls.every((p) => p.verification.isVerified), isTrue);
      expect(await r.get('nope'), isNull);
    });
  });

  group('reviews', () {
    test('reports need a reason in the reporter\'s own words and can be sent once', () async {
      final r = DemoReviewRepository(latency: Duration.zero);
      await expectLater(r.report(reviewId: 'x', reason: 'bad'), throwsA(isA<ApiException>()));
      await r.report(reviewId: 'x', reason: 'This review is about a different company.');
      await expectLater(r.report(reviewId: 'x', reason: 'This review is about a different company.'), throwsA(isA<ReviewAlreadyReportedException>()));
    });

    test('a submitted review always waits for moderation', () async {
      final r = DemoReviewRepository(latency: Duration.zero);
      final mine = await r.submit(target: const ReviewTarget(kind: ReviewTargetKind.seller, id: 'h1', name: 'Host'), rating: 5, comment: 'Clear and on time for the visit.');
      expect(mine.status, ReviewStatus.pendingModeration);
    });
  });

  group('maintenance provider (admin-invited)', () {
    DemoProviderRepository providerRepo(DemoBackendState s) => DemoProviderRepository(() => s, latency: Duration.zero);
    const app = ProviderApplication(companyName: 'Demo AC', contactFirst: 'A', contactLast: 'B', phone: '90000000', email: 'p@example.test', address: 'Seeb, Muscat', governorate: 'Muscat', services: {MaintenanceService.ac}, wilayats: {'Seeb'});

    test('invitation states: valid, expired, used and unknown', () async {
      final r = providerRepo(DemoBackendState());
      expect((await r.invitation('demo-invite')).state, InvitationState.valid);
      expect((await r.invitation('expired')).state, InvitationState.expired);
      expect((await r.invitation('used')).state, InvitationState.used);
      expect((await r.invitation('abc')).state, InvitationState.notFound);
    });

    test('accepting creates a provider account in draft; submit needs both documents', () async {
      final s = DemoBackendState();
      final r = providerRepo(s);
      await r.accept('demo-invite', app, 'Strong-Pass1');
      expect(s.providerGrant, GrantState.draft);
      expect(s.purpose, isNull, reason: 'not a seventh public sign-up path');
      expect((await r.invitation('demo-invite')).state, InvitationState.used);
      await r.upload(ProviderDocument.crCertificate, 'cr.pdf');
      await expectLater(r.submit(), throwsA(isA<ApiException>()));
      await r.upload(ProviderDocument.municipalLicence, 'licence.pdf');
      await r.submit();
      expect(s.providerGrant, GrantState.pendingVerification);
      await expectLater(r.requests(), throwsA(isA<ProviderNotApprovedException>()), reason: 'no workspace before approval');
    });

    test('approved providers decide requests through the booking state machine', () async {
      final s = DemoBackendState()..providerGrant = GrantState.approved;
      final r = providerRepo(s);
      final list = await r.requests();
      final incoming = list.firstWhere((x) => x.status == MaintenanceStatus.requested);
      await expectLater(r.decide(incoming.id, MaintenanceStatus.completed), throwsA(isA<ApiException>()), reason: 'cannot complete before confirming');
      expect((await r.decide(incoming.id, MaintenanceStatus.confirmed)).status, MaintenanceStatus.confirmed);
      await expectLater(r.decide(incoming.id, MaintenanceStatus.completed), throwsA(isA<ApiException>()), reason: 'cannot complete before the preferred day');
      final today = list.firstWhere((x) => x.status == MaintenanceStatus.confirmed);
      expect((await r.decide(today.id, MaintenanceStatus.completed)).status, MaintenanceStatus.completed);
    });

    test('application validation covers every required field', () {
      expect(const ProviderApplication().validate().keys.toSet(), {'company', 'first', 'last', 'phone', 'address', 'services', 'governorate', 'wilayats'});
      expect(app.validate(), isEmpty);
    });
  });

  group('version gate', () {
    test('compares dotted versions numerically', () {
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.9.0', '1.10.0'), -1);
      expect(compareVersions('2.0', '1.99.99'), 1);
      expect(compareVersions('1.0.0+5', '1.0.0'), 0);
    });
  });

  group('account profile (PATCH /me demo)', () {
    test('profile updates need both names and a signed-in session; demo failure leaves data unchanged', () async {
      final s = DemoBackendState()
        ..signedIn = true
        ..account = AccountState.active
        ..firstName = 'Old'
        ..lastName = 'Name';
      final api = DemoAccountApi(s);
      await expectLater(api.updateProfile(firstName: ' ', lastName: 'X'), throwsA(isA<ApiException>()));
      s.failNextProfileSave = true;
      await expectLater(api.updateProfile(firstName: 'New', lastName: 'Name'), throwsA(isA<ApiException>()));
      expect(s.firstName, 'Old');
      final me = await api.updateProfile(firstName: 'New', lastName: 'Name');
      expect(me.displayName, 'New Name');
    });

    test('signing out everywhere ends this session too', () async {
      final s = DemoBackendState()..signedIn = true;
      await DemoAccountApi(s).signOutEverywhere();
      expect(s.signedIn, isFalse);
    });
  });
}
