import 'dart:typed_data';

/// Property listings (architecture v2.4 sections 31.3, 48.7, 81). One model serves the agent
/// workspace and Aqary e-Broker; the channel decides which documents are needed.

enum ListingMarket { residential, commercial, agriculture, industrial }

/// The listing type. An owner selling through Aqary e-Broker creates a `buy` listing (buyers buy it).
enum ListingAction { buy, rent, invest }

enum ListingSubType { villa, apartment, land, office, shops, building, storage, farmHouse }

/// Who lists: an approved agent, an Aqarati Broker (both with deed or owner authorisation), or an
/// owner through Aqary e-Broker (photo ID once, title deed per listing).
enum ListingChannel { agent, aqaratiBroker, eBroker }

/// Verification and lifecycle states (section 81.5). `approvedActive` is the only live state.
enum ListingState { draft, pending, approvedActive, resubmissionRequired, rejected, hidden, sold, rented, withdrawn, expired }

/// Market -> listing type -> sub-types (section 81.1, CONFIRMED). Lease is not a listing type.
const listingTaxonomy = <ListingMarket, Map<ListingAction, List<ListingSubType>>>{
  ListingMarket.residential: {
    ListingAction.buy: [ListingSubType.villa, ListingSubType.apartment, ListingSubType.land],
    ListingAction.rent: [ListingSubType.villa, ListingSubType.apartment],
  },
  ListingMarket.commercial: {
    ListingAction.buy: [ListingSubType.office, ListingSubType.shops, ListingSubType.building, ListingSubType.storage, ListingSubType.land],
    ListingAction.rent: [ListingSubType.office, ListingSubType.shops, ListingSubType.building],
  },
  ListingMarket.agriculture: {
    ListingAction.buy: [ListingSubType.land, ListingSubType.farmHouse],
    ListingAction.rent: [ListingSubType.farmHouse],
  },
  ListingMarket.industrial: {
    ListingAction.buy: [ListingSubType.land],
    ListingAction.invest: [ListingSubType.land],
  },
};

/// Aqary e-Broker sits under Residential in the taxonomy ("Buy · Rent · Sell (Aqary e-Broker)"), so an
/// owner's sale listing is a Residential `buy` listing. See FRONTEND_GAPS_AND_API_BLOCKERS.md.
const eBrokerMarkets = [ListingMarket.residential];

List<ListingAction> actionsFor(ListingMarket m, ListingChannel ch) =>
    ch == ListingChannel.eBroker ? const [ListingAction.buy] : listingTaxonomy[m]!.keys.toList();

List<ListingSubType> subTypesFor(ListingMarket m, ListingAction a) => listingTaxonomy[m]?[a] ?? const [];

/// Which size / room fields apply to a sub-type. DERIVED from the filter applicability matrix
/// (section 16.2); rooms are villa / apartment only (section 81.2).
class ListingAttributes {
  final bool beds, baths, land, build;
  const ListingAttributes({this.beds = false, this.baths = false, this.land = false, this.build = false});
}

ListingAttributes attributesOf(ListingSubType t) => switch (t) {
      ListingSubType.villa => const ListingAttributes(beds: true, baths: true, land: true, build: true),
      ListingSubType.apartment => const ListingAttributes(beds: true, baths: true, build: true),
      ListingSubType.land => const ListingAttributes(land: true),
      ListingSubType.office || ListingSubType.shops || ListingSubType.storage => const ListingAttributes(build: true),
      ListingSubType.building || ListingSubType.farmHouse => const ListingAttributes(land: true, build: true),
    };

/// A file chosen for a listing: metadata only once uploaded. [bytes] is a transient preview buffer
/// for photos and is never written to storage by the app.
class ListingFile {
  final String name;
  final int sizeBytes;
  final Uint8List? bytes;
  /// Bundled image used by the QA "sample photos" shortcut.
  final String? asset;
  const ListingFile({required this.name, required this.sizeBytes, this.bytes, this.asset});
}

/// Everything the form collects. Values survive Back and validation errors; the deed number is
/// held only until submission (the service keeps a keyed hash, section 31.3).
class ListingDraft {
  final String? id;
  final ListingChannel channel;
  final ListingMarket? market;
  final ListingAction? action;
  final ListingSubType? subType;
  final String governorate, wilayat, areaName;
  final String price, title, description;
  final int? beds, baths;
  final String landSqm, buildSqm;
  final List<ListingFile> photos;
  final String deedNumber, unitRef;
  final ListingFile? deedFile, authorisationFile;
  final bool feeAccepted, declaration;
  const ListingDraft({
    this.id,
    required this.channel,
    this.market,
    this.action,
    this.subType,
    this.governorate = '',
    this.wilayat = '',
    this.areaName = '',
    this.price = '',
    this.title = '',
    this.description = '',
    this.beds,
    this.baths,
    this.landSqm = '',
    this.buildSqm = '',
    this.photos = const [],
    this.deedNumber = '',
    this.unitRef = '',
    this.deedFile,
    this.authorisationFile,
    this.feeAccepted = false,
    this.declaration = false,
  });

  static const _keep = Object();

  ListingDraft copyWith({
    Object? id = _keep,
    ListingMarket? market,
    Object? action = _keep,
    Object? subType = _keep,
    String? governorate,
    String? wilayat,
    String? areaName,
    String? price,
    String? title,
    String? description,
    Object? beds = _keep,
    Object? baths = _keep,
    String? landSqm,
    String? buildSqm,
    List<ListingFile>? photos,
    String? deedNumber,
    String? unitRef,
    Object? deedFile = _keep,
    Object? authorisationFile = _keep,
    bool? feeAccepted,
    bool? declaration,
  }) =>
      ListingDraft(
        id: identical(id, _keep) ? this.id : id as String?,
        channel: channel,
        market: market ?? this.market,
        action: identical(action, _keep) ? this.action : action as ListingAction?,
        subType: identical(subType, _keep) ? this.subType : subType as ListingSubType?,
        governorate: governorate ?? this.governorate,
        wilayat: wilayat ?? this.wilayat,
        areaName: areaName ?? this.areaName,
        price: price ?? this.price,
        title: title ?? this.title,
        description: description ?? this.description,
        beds: identical(beds, _keep) ? this.beds : beds as int?,
        baths: identical(baths, _keep) ? this.baths : baths as int?,
        landSqm: landSqm ?? this.landSqm,
        buildSqm: buildSqm ?? this.buildSqm,
        photos: photos ?? this.photos,
        deedNumber: deedNumber ?? this.deedNumber,
        unitRef: unitRef ?? this.unitRef,
        deedFile: identical(deedFile, _keep) ? this.deedFile : deedFile as ListingFile?,
        authorisationFile: identical(authorisationFile, _keep) ? this.authorisationFile : authorisationFile as ListingFile?,
        feeAccepted: feeAccepted ?? this.feeAccepted,
        declaration: declaration ?? this.declaration,
      );

  ListingAttributes get attributes => subType == null ? const ListingAttributes() : attributesOf(subType!);
}

/// Wizard steps, in order (blueprint p.43: classification, location, price + facts, media,
/// deed / authorisation, review).
enum ListingStep { classification, location, facts, photos, documents, review }

const kListingMaxPhotos = 20;
const kListingTitleMax = 80;
const kListingDescriptionMax = 2000;
/// Days a listing stays live before it must be renewed (decision #34).
const kListingLiveDays = 90;

double? parseOmr(String s) {
  final t = s.trim().replaceAll(',', '');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || v <= 0) return null;
  // OMR has three decimals.
  final parts = t.split('.');
  if (parts.length == 2 && parts[1].length > 3) return null;
  return v;
}

double? parseSqm(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', ''));
  return v == null || v <= 0 ? null : v;
}

/// Field-level validation per step. Keys are FlowStrings keys; empty map means the step is valid.
/// [deedOnFile] is true when correcting a submitted listing: the deed number was already sent once.
Map<String, String> validateListingStep(ListingDraft d, ListingStep step, {bool deedOnFile = false}) {
  final e = <String, String>{};
  switch (step) {
    case ListingStep.classification:
      if (d.market == null) e['market'] = 'lst.err.market';
      if (d.action == null) e['action'] = 'lst.err.action';
      if (d.subType == null) e['subType'] = 'lst.err.subType';
    case ListingStep.location:
      if (d.governorate.isEmpty) e['governorate'] = 'lst.err.governorate';
      if (d.wilayat.isEmpty) e['wilayat'] = 'lst.err.wilayat';
    case ListingStep.facts:
      if (parseOmr(d.price) == null) e['price'] = 'lst.err.price';
      final t = d.title.trim();
      if (t.length < 6) e['title'] = 'lst.err.title';
      if (t.length > kListingTitleMax) e['title'] = 'lst.err.titleLong';
      if (d.description.trim().length > kListingDescriptionMax) e['description'] = 'lst.err.descLong';
      final a = d.attributes;
      if (a.beds && d.beds == null) e['beds'] = 'lst.err.beds';
      if (a.baths && d.baths == null) e['baths'] = 'lst.err.baths';
      if (a.land && parseSqm(d.landSqm) == null) e['land'] = 'lst.err.land';
      if (a.build && parseSqm(d.buildSqm) == null) e['build'] = 'lst.err.build';
    case ListingStep.photos:
      if (d.photos.isEmpty) e['photos'] = 'lst.err.photos';
    case ListingStep.documents:
      if (!deedOnFile && d.deedNumber.trim().length < 3) e['deedNumber'] = 'lst.err.deed';
      if (d.channel == ListingChannel.eBroker) {
        if (d.deedFile == null) e['deedFile'] = 'lst.err.deedFile';
      } else if (d.deedFile == null && d.authorisationFile == null) {
        e['deedFile'] = 'lst.err.agentDocs';
      }
    case ListingStep.review:
      if (!d.declaration) e['declaration'] = 'lst.err.declaration';
      if (d.channel == ListingChannel.eBroker && !d.feeAccepted) e['fee'] = 'lst.err.fee';
  }
  return e;
}

/// Material fields need a change set (section 48.7); everything else applies immediately.
const kMaterialFields = {'title', 'photos', 'location', 'size', 'rooms', 'type', 'deed'};

class ChangeSet {
  final Set<String> fields;
  final DateTime submittedAt;
  /// pending | approved | rejected
  final String status;
  final String? reasonCode;
  const ChangeSet({required this.fields, required this.submittedAt, this.status = 'pending', this.reasonCode});
}

/// A listing as the owner sees it (owner scope: includes pending / rejected with their state).
class Listing {
  final String id;
  final ListingChannel channel;
  final ListingMarket market;
  final ListingAction action;
  final ListingSubType subType;
  final String title, description;
  final String governorate, wilayat, areaName;
  final double price;
  final int? beds, baths;
  final double? landSqm, buildSqm;
  final List<ListingFile> photos;
  /// Last characters of the deed number only; the full number is never kept by the app.
  final String deedHint;
  final String unitRef;
  final String? deedFileName, authorisationFileName;
  final ListingState state;
  final String? reasonCode;
  final DateTime createdAt;
  final DateTime? submittedAt, decidedAt, expiresAt;
  final ChangeSet? changeSet;
  /// The service flagged a possible duplicate (section 81.6); the reviewer decides.
  final bool duplicateSuspected;
  const Listing({
    required this.id,
    required this.channel,
    required this.market,
    required this.action,
    required this.subType,
    required this.title,
    this.description = '',
    required this.governorate,
    required this.wilayat,
    this.areaName = '',
    required this.price,
    this.beds,
    this.baths,
    this.landSqm,
    this.buildSqm,
    this.photos = const [],
    this.deedHint = '',
    this.unitRef = '',
    this.deedFileName,
    this.authorisationFileName,
    required this.state,
    this.reasonCode,
    required this.createdAt,
    this.submittedAt,
    this.decidedAt,
    this.expiresAt,
    this.changeSet,
    this.duplicateSuspected = false,
  });

  Listing copyWith({ListingState? state, Object? reasonCode = ListingDraft._keep, DateTime? decidedAt, DateTime? expiresAt, Object? changeSet = ListingDraft._keep, double? price, String? description, DateTime? submittedAt}) => Listing(
        id: id,
        channel: channel,
        market: market,
        action: action,
        subType: subType,
        title: title,
        description: description ?? this.description,
        governorate: governorate,
        wilayat: wilayat,
        areaName: areaName,
        price: price ?? this.price,
        beds: beds,
        baths: baths,
        landSqm: landSqm,
        buildSqm: buildSqm,
        photos: photos,
        deedHint: deedHint,
        unitRef: unitRef,
        deedFileName: deedFileName,
        authorisationFileName: authorisationFileName,
        state: state ?? this.state,
        reasonCode: identical(reasonCode, ListingDraft._keep) ? this.reasonCode : reasonCode as String?,
        createdAt: createdAt,
        submittedAt: submittedAt ?? this.submittedAt,
        decidedAt: decidedAt ?? this.decidedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        changeSet: identical(changeSet, ListingDraft._keep) ? this.changeSet : changeSet as ChangeSet?,
        duplicateSuspected: duplicateSuspected,
      );

  bool get isLive => state == ListingState.approvedActive;
  bool get canMarkSold => isLive && (action == ListingAction.buy || action == ListingAction.invest);
  bool get canMarkRented => isLive && action == ListingAction.rent;
  bool get canWithdraw => isLive;
  bool get canRenew => state == ListingState.expired;
  bool get canResubmit => state == ListingState.resubmissionRequired;
  bool get canEdit => isLive && changeSet?.status != 'pending';

  /// Back into the form for corrections (resubmission keeps entered values).
  ListingDraft toDraft() => ListingDraft(
        id: id,
        channel: channel,
        market: market,
        action: action,
        subType: subType,
        governorate: governorate,
        wilayat: wilayat,
        areaName: areaName,
        price: _trimNum(price),
        title: title,
        description: description,
        beds: beds,
        baths: baths,
        landSqm: landSqm == null ? '' : _trimNum(landSqm!),
        buildSqm: buildSqm == null ? '' : _trimNum(buildSqm!),
        photos: photos,
        unitRef: unitRef,
        deedFile: deedFileName == null ? null : ListingFile(name: deedFileName!, sizeBytes: 0),
        authorisationFile: authorisationFileName == null ? null : ListingFile(name: authorisationFileName!, sizeBytes: 0),
      );
}

String _trimNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// 409 DUPLICATE_LISTING: an active listing already uses this deed, unit and listing type.
class DuplicateListingException implements Exception {
  const DuplicateListingException();
}

/// 403 ROLE_NOT_APPROVED (agent grant not approved, or e-Broker photo ID missing).
class ListingNotAllowedException implements Exception {
  final String reason;
  const ListingNotAllowedException(this.reason);
}

/// Only one open change set per listing (blueprint p.44).
class ChangeSetOpenException implements Exception {
  const ChangeSetOpenException();
}

/// The Aqary e-Broker seller's photo ID, checked once on the seller grant.
enum SellerIdState { none, pendingReview, accepted, rejected }
