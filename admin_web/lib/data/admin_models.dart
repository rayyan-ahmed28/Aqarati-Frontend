/// Admin domain model. Roles, permissions, reason codes, checklists and queue rules come from the
/// architecture v2.4 sections 5.2, 47, 48, 50, 51, 84 and 89. Anything not defined there is marked
/// DERIVED in the console docs.
library;

enum AdminRole { reviewer, seniorReviewer, superAdmin, auditor }

enum Permission {
  viewQueue,
  openDocuments,
  decide,
  secondApproval,
  overrideDecision,
  suspend,
  invite,
  createBrokerGrant,
  manageAdmins,
  viewAudit,
  moderateReviews,
  manageAds,
  viewConfig,
}

/// Section 47 matrix (CONFIRMED) plus two DERIVED rows: review moderation (Reviewer and above) and
/// ad management (Senior and Super Admin), which the matrix does not list.
const rolePermissions = <AdminRole, Set<Permission>>{
  AdminRole.reviewer: {Permission.viewQueue, Permission.openDocuments, Permission.decide, Permission.moderateReviews},
  AdminRole.seniorReviewer: {Permission.viewQueue, Permission.openDocuments, Permission.decide, Permission.secondApproval, Permission.overrideDecision, Permission.suspend, Permission.viewAudit, Permission.moderateReviews, Permission.manageAds},
  AdminRole.superAdmin: {...Permission.values},
  AdminRole.auditor: {Permission.viewQueue, Permission.viewAudit},
};

bool can(AdminRole r, Permission p) => rolePermissions[r]!.contains(p);

class AdminUser {
  final String id, email, name;
  final AdminRole role;
  final bool active;
  const AdminUser({required this.id, required this.email, required this.name, required this.role, this.active = true});
  AdminUser copyWith({AdminRole? role, bool? active}) => AdminUser(id: id, email: email, name: name, role: role ?? this.role, active: active ?? this.active);
}

class AdminSession {
  final AdminUser user;
  final DateTime expiresAt;
  final DateTime? steppedUpAt;
  const AdminSession({required this.user, required this.expiresAt, this.steppedUpAt});
}

/// What a queue item is about (section 50.1 checklist entities).
enum EntityType { agent, construction, development, architecture, interiorExterior, provider, aqaratiBroker, listing, changeSet, adBanner }

enum QueueStatus { pending, awaitingSecondApproval, escalated, approved, resubmissionRequested, rejected }

enum DecisionOutcome { approve, requestResubmission, reject }

/// The closed list of 12 reason codes (section 50.2, CONFIRMED). OTHER needs a note.
enum ReasonCode { docUnreadable, docWrongType, nameMismatch, expired, notOnRegistry, licenceCategoryMismatch, ownerMismatch, duplicateListing, photosMismatch, callFailed, incompleteSubmission, other }

extension ReasonCodeApi on ReasonCode {
  String get api => switch (this) {
        ReasonCode.docUnreadable => 'DOC_UNREADABLE',
        ReasonCode.docWrongType => 'DOC_WRONG_TYPE',
        ReasonCode.nameMismatch => 'NAME_MISMATCH',
        ReasonCode.expired => 'EXPIRED',
        ReasonCode.notOnRegistry => 'NOT_ON_REGISTRY',
        ReasonCode.licenceCategoryMismatch => 'LICENCE_CATEGORY_MISMATCH',
        ReasonCode.ownerMismatch => 'OWNER_MISMATCH',
        ReasonCode.duplicateListing => 'DUPLICATE_LISTING',
        ReasonCode.photosMismatch => 'PHOTOS_MISMATCH',
        ReasonCode.callFailed => 'CALL_FAILED',
        ReasonCode.incompleteSubmission => 'INCOMPLETE_SUBMISSION',
        ReasonCode.other => 'OTHER',
      };
}

/// Reviewer checklist per entity type (section 50.1). Approve is enabled only when every item has
/// a result; approving needs every item to pass.
const checklists = <EntityType, List<String>>{
  EntityType.agent: ['ID photo readable', 'Name on ID = name on licence', 'Licence found on the issuing register', 'Licence not expired', 'Supporting document valid'],
  EntityType.aqaratiBroker: ['ID photo readable', 'Name on ID = name on licence', 'Licence found on the issuing register', 'Licence not expired', 'Supporting document valid', 'Programme eligibility confirmed'],
  EntityType.construction: ['CR found on registry', 'Company name matches', 'Municipal licence valid and not expired', 'Representation call done'],
  EntityType.architecture: ['CR found on registry', 'Company name matches', 'Municipal licence valid and not expired', 'Representation call done'],
  EntityType.interiorExterior: ['CR found on registry', 'Company name matches', 'Municipal licence valid and not expired', 'Representation call done'],
  EntityType.development: ['All four documents present', 'CR and developer licence on registry', 'Expiry dates entered', 'Representation call done'],
  EntityType.provider: ['CR on registry', 'Name match', 'Licence valid and covers the service category', 'Representation call done'],
  EntityType.listing: ['Title deed readable', 'Deed owner name = lister\'s ID, or agent holds owner authorisation', 'No duplicate', 'Photos match the property type', 'Price plausible'],
  EntityType.changeSet: ['Changed fields compared with the approved version', 'Only what changed was re-checked'],
  EntityType.adBanner: ['Creative is lawful and accurate', 'Advertiser identified', '"Sponsored" label present', 'Placement and dates valid'],
};

/// Entities whose approval needs a second, different Senior approver (four-eyes).
bool needsFourEyes(EntityType t) => t == EntityType.development || t == EntityType.aqaratiBroker;

class DocRef {
  final String id, label, fileName;
  const DocRef(this.id, this.label, this.fileName);
}

class DecisionRecord {
  final DecisionOutcome outcome;
  final String adminId, adminName;
  final DateTime at;
  final ReasonCode? reason;
  final String note;
  final bool firstOfTwo;
  const DecisionRecord({required this.outcome, required this.adminId, required this.adminName, required this.at, this.reason, this.note = '', this.firstOfTwo = false});
}

class QueueItem {
  final String id;
  final EntityType type;
  final String subject;
  final String subjectAccountId;
  final DateTime submittedAt;
  final int resubmissions;
  final QueueStatus status;
  final String? claimedBy, claimedByName;
  final DateTime? claimExpiresAt;
  final Map<String, String> fields;
  final List<DocRef> documents;
  final List<DecisionRecord> history;
  /// Admin ids that are related to this account (self / related-account conflict).
  final Set<String> relatedAdminIds;
  final bool duplicateSuspected;
  final int version;
  const QueueItem({
    required this.id,
    required this.type,
    required this.subject,
    required this.subjectAccountId,
    required this.submittedAt,
    this.resubmissions = 0,
    this.status = QueueStatus.pending,
    this.claimedBy,
    this.claimedByName,
    this.claimExpiresAt,
    this.fields = const {},
    this.documents = const [],
    this.history = const [],
    this.relatedAdminIds = const {},
    this.duplicateSuspected = false,
    this.version = 1,
  });

  static const _keep = Object();
  QueueItem copyWith({QueueStatus? status, Object? claimedBy = _keep, Object? claimedByName = _keep, Object? claimExpiresAt = _keep, List<DecisionRecord>? history}) => QueueItem(
        id: id,
        type: type,
        subject: subject,
        subjectAccountId: subjectAccountId,
        submittedAt: submittedAt,
        resubmissions: resubmissions,
        status: status ?? this.status,
        claimedBy: identical(claimedBy, _keep) ? this.claimedBy : claimedBy as String?,
        claimedByName: identical(claimedByName, _keep) ? this.claimedByName : claimedByName as String?,
        claimExpiresAt: identical(claimExpiresAt, _keep) ? this.claimExpiresAt : claimExpiresAt as DateTime?,
        fields: fields,
        documents: documents,
        history: history ?? this.history,
        relatedAdminIds: relatedAdminIds,
        duplicateSuspected: duplicateSuspected,
        version: version + 1,
      );

  bool get open => status == QueueStatus.pending || status == QueueStatus.awaitingSecondApproval || status == QueueStatus.escalated;
  DecisionRecord? get firstApproval => history.where((h) => h.firstOfTwo).lastOrNull;
}

/// Section 50.3: resubmissions first, then oldest first; developers and agents ahead of listings.
int queueOrder(QueueItem a, QueueItem b) {
  int rank(QueueItem i) => i.resubmissions > 0 ? 0 : (i.type == EntityType.listing || i.type == EntityType.changeSet || i.type == EntityType.adBanner ? 2 : 1);
  final r = rank(a).compareTo(rank(b));
  return r != 0 ? r : a.submittedAt.compareTo(b.submittedAt);
}

class AuditEvent {
  final int id;
  final DateTime at;
  final String actorType, actorId, actorLabel, action, entity, entityId;
  final String? before, after, reason, ip;
  const AuditEvent({required this.id, required this.at, required this.actorType, required this.actorId, required this.actorLabel, required this.action, required this.entity, required this.entityId, this.before, this.after, this.reason, this.ip});
}

enum ModerationKind { newReview, editedReview, reported }

enum ModerationStatus { pendingModeration, underReview, published, removed, rejected }

class ModerationItem {
  final String id;
  final ModerationKind kind;
  final String targetName, targetType;
  final int stars;
  final String comment;
  final String? reportReason;
  final ModerationStatus status;
  final DateTime submittedAt;
  final String? decidedBy;
  const ModerationItem({required this.id, required this.kind, required this.targetName, required this.targetType, required this.stars, required this.comment, this.reportReason, required this.status, required this.submittedAt, this.decidedBy});
  ModerationItem copyWith(ModerationStatus s, String by) => ModerationItem(id: id, kind: kind, targetName: targetName, targetType: targetType, stars: stars, comment: comment, reportReason: reportReason, status: s, submittedAt: submittedAt, decidedBy: by);
}

enum InvitationStatus { sent, accepted, expired, revoked }

class ProviderInvite {
  final String id, companyName, email, createdBy;
  final InvitationStatus status;
  final DateTime createdAt, expiresAt;
  const ProviderInvite({required this.id, required this.companyName, required this.email, required this.createdBy, required this.status, required this.createdAt, required this.expiresAt});
  ProviderInvite copyWith(InvitationStatus s) => ProviderInvite(id: id, companyName: companyName, email: email, createdBy: createdBy, status: s, createdAt: createdAt, expiresAt: expiresAt);
}

enum AdPlacement { homeTop, resultsInFeed }

enum AdStatus { inReview, scheduled, live, paused, rejected, ended }

class AdBanner {
  final String id, title, advertiser, link;
  final AdPlacement placement;
  final DateTime starts, ends;
  final AdStatus status;
  const AdBanner({required this.id, required this.title, required this.advertiser, required this.link, required this.placement, required this.starts, required this.ends, required this.status});
  AdBanner copyWith(AdStatus s) => AdBanner(id: id, title: title, advertiser: advertiser, link: link, placement: placement, starts: starts, ends: ends, status: s);
}

enum AccountStatus { active, suspended }

class CustomerAccount {
  final String id, name, kind;
  final AccountStatus status;
  final String? suspensionReason;
  const CustomerAccount({required this.id, required this.name, required this.kind, this.status = AccountStatus.active, this.suspensionReason});
  CustomerAccount copyWith(AccountStatus s, String? reason) => CustomerAccount(id: id, name: name, kind: kind, status: s, suspensionReason: reason);
}

class DashboardStats {
  final Map<EntityType, int> pendingByType;
  final Duration? oldestAge;
  final int approved, rejected, resubmissions, awaitingSecond;
  final Duration? averageTurnaround;
  const DashboardStats({required this.pendingByType, this.oldestAge, required this.approved, required this.rejected, required this.resubmissions, required this.awaitingSecond, this.averageTurnaround});
}

// ---------------------------------------------------------------- errors

class AdminForbidden implements Exception {
  final String reason;
  const AdminForbidden(this.reason);
}

class AdminConflict implements Exception {
  /// ITEM_CLAIMED, VERSION_MISMATCH, SELF_REVIEW, SAME_APPROVER, ILLEGAL_TRANSITION, CHECKLIST_INCOMPLETE, REASON_REQUIRED, NOTE_REJECTED
  final String code;
  const AdminConflict(this.code);
}

class StepUpRequired implements Exception {
  const StepUpRequired();
}

class SessionExpired implements Exception {
  const SessionExpired();
}

class InvalidCredentials implements Exception {
  const InvalidCredentials();
}
