import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/backend_mode.dart';
import '../../core/domain/account_models.dart';
import '../../data/api/account_api.dart' show ApiErrorCode, ApiException, accountApiProvider;
import '../entry/models/signup_purpose.dart';
import 'listing_models.dart';

/// Frontend contract for POST /properties, PATCH /properties/:id, POST /properties/:id/status and
/// /renew (sections 31.3, 35). The service re-checks role, ownership, duplicates and transitions on
/// every call; this interface only reflects what it answers. Submitting never makes a listing live.
abstract class ListingRepository {
  Future<List<Listing>> mine();
  Future<Listing?> get(String id);
  Future<List<ListingDraft>> drafts();
  Future<ListingDraft?> draft(String id);
  /// Saves the form so it survives leaving the flow. Returns the draft id.
  Future<String> saveDraft(ListingDraft d);
  Future<void> deleteDraft(String id);
  /// Submits for review. The same [idempotencyKey] never creates a second listing.
  Future<Listing> submit(ListingDraft d, {required String idempotencyKey});
  /// Corrections after "changes requested": back to pending.
  Future<Listing> resubmit(String id, ListingDraft d);
  /// Owner lifecycle: sold, rented or withdrawn (from approved_active only).
  Future<Listing> setLifecycle(String id, ListingState to);
  Future<Listing> renew(String id);
  /// Edit after approval: non-material fields apply at once, material fields open a change set.
  Future<({Listing listing, Set<String> appliedNow, Set<String> underReview})> edit(String id, ListingDraft d);
  Future<SellerIdState> sellerId();
  Future<void> uploadSellerId(ListingFile f);
}

class UnavailableListingRepository implements ListingRepository {
  const UnavailableListingRepository();
  Never _no() => throw const ApiException(ApiErrorCode.network);
  @override
  Future<List<Listing>> mine() async => _no();
  @override
  Future<Listing?> get(String id) async => _no();
  @override
  Future<List<ListingDraft>> drafts() async => _no();
  @override
  Future<ListingDraft?> draft(String id) async => _no();
  @override
  Future<String> saveDraft(ListingDraft d) async => _no();
  @override
  Future<void> deleteDraft(String id) async => _no();
  @override
  Future<Listing> submit(ListingDraft d, {required String idempotencyKey}) async => _no();
  @override
  Future<Listing> resubmit(String id, ListingDraft d) async => _no();
  @override
  Future<Listing> setLifecycle(String id, ListingState to) async => _no();
  @override
  Future<Listing> renew(String id) async => _no();
  @override
  Future<({Listing listing, Set<String> appliedNow, Set<String> underReview})> edit(String id, ListingDraft d) async => _no();
  @override
  Future<SellerIdState> sellerId() async => _no();
  @override
  Future<void> uploadSellerId(ListingFile f) async => _no();
}

/// Who may submit through a channel, from the signed-in session. The service has the final say.
bool canUseChannel(MeSession? me, ListingChannel ch) {
  if (me == null || me.account != AccountState.active) return false;
  return switch (ch) {
    ListingChannel.eBroker => true,
    ListingChannel.agent => me.purpose == SignupPurpose.realEstateAgent && me.grant == GrantState.approved,
    // Aqarati Broker grants are created by a Super Admin; no session in this build holds one.
    ListingChannel.aqaratiBroker => false,
  };
}

/// DEMO ONLY: in memory. Reviewer decisions are simulated through the `debug*` hooks (QA tools).
/// Demo rule: a deed number of "0000" is treated as already used by another active listing.
class DemoListingRepository implements ListingRepository {
  DemoListingRepository({required this.session, this.latency = const Duration(milliseconds: 450), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final Future<MeSession?> Function() session;
  final Duration latency;
  final DateTime Function() _clock;
  final Map<String, Listing> _items = {};
  final Map<String, ListingDraft> _drafts = {};
  final Map<String, String> _byKey = {};
  /// deed + unit + listing type of active listings (the service keeps a keyed hash, not the number).
  final Map<String, String> _deedIndex = {};
  SellerIdState _sellerId = SellerIdState.none;
  int _seq = 0;
  Object? debugNextError;

  Future<void> _lag() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  void _maybeFail() {
    final e = debugNextError;
    if (e != null) {
      debugNextError = null;
      throw e;
    }
  }

  @override
  Future<List<Listing>> mine() async {
    await _lag();
    _maybeFail();
    final now = _clock();
    // Expiry is applied by a server job; reading it here keeps the demo honest about dates.
    for (final e in _items.entries.toList()) {
      final l = e.value;
      if (l.state == ListingState.approvedActive && l.expiresAt != null && now.isAfter(l.expiresAt!)) _items[e.key] = l.copyWith(state: ListingState.expired);
    }
    final list = _items.values.toList()..sort((a, b) => (b.submittedAt ?? b.createdAt).compareTo(a.submittedAt ?? a.createdAt));
    return List.unmodifiable(list);
  }

  @override
  Future<Listing?> get(String id) async {
    await _lag();
    return _items[id];
  }

  @override
  Future<List<ListingDraft>> drafts() async {
    await _lag();
    return List.unmodifiable(_drafts.values.toList().reversed);
  }

  @override
  Future<ListingDraft?> draft(String id) async {
    await _lag();
    return _drafts[id];
  }

  @override
  Future<String> saveDraft(ListingDraft d) async {
    await _lag();
    final id = d.id ?? 'd${++_seq}';
    // A draft id never collides with a submitted listing id.
    if (_items.containsKey(id)) return id;
    _drafts[id] = d.copyWith(id: id, deedNumber: '');
    return id;
  }

  @override
  Future<void> deleteDraft(String id) async {
    await _lag();
    _drafts.remove(id);
  }

  Future<void> _checkAllowed(ListingChannel ch) async {
    final me = await session();
    if (!canUseChannel(me, ch)) throw ListingNotAllowedException(ch == ListingChannel.agent ? 'agent' : 'account');
    if (ch == ListingChannel.eBroker && _sellerId == SellerIdState.none) throw const ListingNotAllowedException('sellerId');
  }

  String _deedKey(ListingDraft d) => '${d.deedNumber.trim()}|${d.unitRef.trim()}|${d.action?.name}';

  @override
  Future<Listing> submit(ListingDraft d, {required String idempotencyKey}) async {
    await _lag();
    final existing = _byKey[idempotencyKey];
    if (existing != null) return _items[existing]!;
    _maybeFail();
    await _checkAllowed(d.channel);
    for (final s in ListingStep.values) {
      if (validateListingStep(d, s).isNotEmpty) throw const ApiException(ApiErrorCode.validationFailed);
    }
    final key = _deedKey(d);
    if (d.deedNumber.trim() == '0000' || _deedIndex.containsKey(key)) throw const DuplicateListingException();
    final now = _clock();
    final id = 'L${(++_seq).toString().padLeft(4, '0')}';
    final deed = d.deedNumber.trim();
    final l = Listing(
      id: id,
      channel: d.channel,
      market: d.market!,
      action: d.action!,
      subType: d.subType!,
      title: d.title.trim(),
      description: d.description.trim(),
      governorate: d.governorate,
      wilayat: d.wilayat,
      areaName: d.areaName.trim(),
      price: parseOmr(d.price)!,
      beds: d.attributes.beds ? d.beds : null,
      baths: d.attributes.baths ? d.baths : null,
      landSqm: d.attributes.land ? parseSqm(d.landSqm) : null,
      buildSqm: d.attributes.build ? parseSqm(d.buildSqm) : null,
      photos: d.photos,
      deedHint: deed.length <= 3 ? deed : deed.substring(deed.length - 3),
      unitRef: d.unitRef.trim(),
      deedFileName: d.deedFile?.name,
      authorisationFileName: d.authorisationFile?.name,
      state: ListingState.pending,
      createdAt: now,
      submittedAt: now,
    );
    _items[id] = l;
    _byKey[idempotencyKey] = id;
    _deedIndex[key] = id;
    if (d.id != null) _drafts.remove(d.id);
    return l;
  }

  @override
  Future<Listing> resubmit(String id, ListingDraft d) async {
    await _lag();
    _maybeFail();
    final l = _items[id];
    if (l == null) throw const ApiException(ApiErrorCode.server);
    if (l.state != ListingState.resubmissionRequired) throw const ApiException(ApiErrorCode.conflict);
    for (final s in ListingStep.values) {
      if (validateListingStep(d, s, deedOnFile: true).isNotEmpty) throw const ApiException(ApiErrorCode.validationFailed);
    }
    final next = Listing(
      id: id,
      channel: l.channel,
      market: d.market ?? l.market,
      action: d.action ?? l.action,
      subType: d.subType ?? l.subType,
      title: d.title.trim(),
      description: d.description.trim(),
      governorate: d.governorate,
      wilayat: d.wilayat,
      areaName: d.areaName.trim(),
      price: parseOmr(d.price) ?? l.price,
      beds: d.attributes.beds ? d.beds : null,
      baths: d.attributes.baths ? d.baths : null,
      landSqm: d.attributes.land ? parseSqm(d.landSqm) : null,
      buildSqm: d.attributes.build ? parseSqm(d.buildSqm) : null,
      photos: d.photos,
      deedHint: l.deedHint,
      unitRef: d.unitRef.trim(),
      deedFileName: d.deedFile?.name ?? l.deedFileName,
      authorisationFileName: d.authorisationFile?.name ?? l.authorisationFileName,
      state: ListingState.pending,
      createdAt: l.createdAt,
      submittedAt: _clock(),
    );
    return _items[id] = next;
  }

  @override
  Future<Listing> setLifecycle(String id, ListingState to) async {
    await _lag();
    _maybeFail();
    final l = _items[id];
    if (l == null) throw const ApiException(ApiErrorCode.server);
    final ok = switch (to) {
      ListingState.sold => l.canMarkSold,
      ListingState.rented => l.canMarkRented,
      ListingState.withdrawn => l.canWithdraw,
      _ => false,
    };
    if (!ok) throw const ApiException(ApiErrorCode.conflict);
    _deedIndex.removeWhere((_, v) => v == id);
    return _items[id] = l.copyWith(state: to);
  }

  @override
  Future<Listing> renew(String id) async {
    await _lag();
    _maybeFail();
    final l = _items[id];
    if (l == null || !l.canRenew) throw const ApiException(ApiErrorCode.conflict);
    return _items[id] = l.copyWith(state: ListingState.approvedActive, expiresAt: _clock().add(const Duration(days: kListingLiveDays)));
  }

  @override
  Future<({Listing listing, Set<String> appliedNow, Set<String> underReview})> edit(String id, ListingDraft d) async {
    await _lag();
    _maybeFail();
    final l = _items[id];
    if (l == null || !l.isLive) throw const ApiException(ApiErrorCode.conflict);
    if (l.changeSet?.status == 'pending') throw const ChangeSetOpenException();
    final changed = changedFields(l, d);
    final material = changed.intersection(kMaterialFields);
    final now = changed.difference(kMaterialFields);
    var next = l.copyWith(price: now.contains('price') ? parseOmr(d.price) : null, description: now.contains('description') ? d.description.trim() : null);
    if (material.isNotEmpty) next = next.copyWith(changeSet: ChangeSet(fields: material, submittedAt: _clock()));
    _items[id] = next;
    return (listing: next, appliedNow: now, underReview: material);
  }

  @override
  Future<SellerIdState> sellerId() async {
    await _lag();
    return _sellerId;
  }

  @override
  Future<void> uploadSellerId(ListingFile f) async {
    await _lag();
    _maybeFail();
    _sellerId = SellerIdState.pendingReview;
  }

  // ---- QA hooks (reviewer and system simulation) ----
  void debugDecide(String id, ListingState to, {String? reason}) {
    final l = _items[id];
    if (l == null) return;
    final now = _clock();
    _items[id] = l.copyWith(state: to, reasonCode: reason, decidedAt: now, expiresAt: to == ListingState.approvedActive ? now.add(const Duration(days: kListingLiveDays)) : null);
    if (to == ListingState.approvedActive && l.channel == ListingChannel.eBroker) _sellerId = SellerIdState.accepted;
    if (to == ListingState.rejected) _deedIndex.removeWhere((_, v) => v == id);
  }

  void debugExpire(String id) {
    final l = _items[id];
    if (l != null) _items[id] = l.copyWith(state: ListingState.expired, expiresAt: _clock().subtract(const Duration(days: 1)));
  }

  void debugChangeSet(String id, {required bool approve}) {
    final l = _items[id];
    final cs = l?.changeSet;
    if (l == null || cs == null) return;
    _items[id] = l.copyWith(changeSet: ChangeSet(fields: cs.fields, submittedAt: cs.submittedAt, status: approve ? 'approved' : 'rejected', reasonCode: approve ? null : 'PHOTOS_MISMATCH'));
  }

  void debugSellerId(SellerIdState s) => _sellerId = s;
}

/// Which fields an edit touches, in the material / non-material vocabulary of section 48.7.
Set<String> changedFields(Listing l, ListingDraft d) {
  final out = <String>{};
  if (parseOmr(d.price) != null && parseOmr(d.price) != l.price) out.add('price');
  if (d.description.trim() != l.description) out.add('description');
  if (d.title.trim() != l.title) out.add('title');
  if (d.governorate != l.governorate || d.wilayat != l.wilayat || d.areaName.trim() != l.areaName) out.add('location');
  if ((d.attributes.land && parseSqm(d.landSqm) != l.landSqm) || (d.attributes.build && parseSqm(d.buildSqm) != l.buildSqm)) out.add('size');
  if (d.beds != l.beds || d.baths != l.baths) out.add('rooms');
  if (d.photos.length != l.photos.length || [for (var i = 0; i < d.photos.length; i++) d.photos[i].name != l.photos[i].name].any((x) => x)) out.add('photos');
  return out;
}

final listingRepositoryProvider = Provider<ListingRepository>((ref) {
  if (!kUseDemoBackend) return const UnavailableListingRepository();
  return DemoListingRepository(session: () async {
    try {
      return await ref.read(accountApiProvider).getMe();
    } catch (_) {
      return null;
    }
  });
});

final myListingsProvider = FutureProvider.autoDispose<List<Listing>>((ref) => ref.watch(listingRepositoryProvider).mine());
final myListingDraftsProvider = FutureProvider.autoDispose<List<ListingDraft>>((ref) => ref.watch(listingRepositoryProvider).drafts());
final listingProvider = FutureProvider.autoDispose.family<Listing?, String>((ref, id) => ref.watch(listingRepositoryProvider).get(id));
final sellerIdProvider = FutureProvider.autoDispose<SellerIdState>((ref) => ref.watch(listingRepositoryProvider).sellerId());
