import '../../features/entry/models/signup_purpose.dart';

/// Customer account state (distinct from business role-grant verification).
enum AccountState { otpPending, active }

/// Role-grant lifecycle. `approved` IS the active approved state; there is no
/// separate "active business" state.
enum GrantState { draft, pendingVerification, approved, resubmissionRequired, rejected, suspended }

/// Developer approval is four-eyes: first approval leads to a distinct
/// "awaiting second approval" state; do not collapse it into generic pending.
enum ReviewStage { underReview, awaitingSecondApproval }

enum DocumentKind {
  photoId,
  agentLicence,
  supportingDocument,
  crCertificate,
  municipalLicence,
  officialCorporateRegistration,
  activityLicences,
  developerLicence;

  /// Expiry is tracked for these (source: agent licence; CR; developer licence).
  bool get tracksExpiry => this == agentLicence || this == crCertificate || this == developerLicence || this == officialCorporateRegistration;
}

enum InteriorExteriorServiceType { interior, exterior, both }

/// Typed description of one public sign-up path: which business fields it
/// collects and which documents it later requires. One config, one form.
class RoleFormConfig {
  final SignupPurpose purpose;
  final bool hasBusinessName;
  final bool hasAgencyName;
  final bool hasServiceType;
  /// Company paths collect a company email (the account username, distinct from the
  /// contact person's email) and a physical address. Source: architecture §19.5-19.8.
  final bool hasCompanyContact;
  /// The address is marked required for architecture and interior/exterior only; for the
  /// other company paths the source lists the field without marking it required.
  final bool companyAddressRequired;
  final List<DocumentKind> documents;
  final bool fourEyes;
  const RoleFormConfig({
    required this.purpose,
    this.hasBusinessName = false,
    this.hasAgencyName = false,
    this.hasServiceType = false,
    this.hasCompanyContact = false,
    this.companyAddressRequired = false,
    this.documents = const [],
    this.fourEyes = false,
  });

  bool get needsDocuments => documents.isNotEmpty;
  bool get hasBusinessStep => hasBusinessName || hasAgencyName || hasServiceType || hasCompanyContact;
}

const roleConfigs = <SignupPurpose, RoleFormConfig>{
  SignupPurpose.userToShop: RoleFormConfig(purpose: SignupPurpose.userToShop),
  SignupPurpose.realEstateAgent: RoleFormConfig(
    purpose: SignupPurpose.realEstateAgent,
    hasAgencyName: true,
    documents: [DocumentKind.photoId, DocumentKind.agentLicence, DocumentKind.supportingDocument],
  ),
  // The CR activity list is checked during verification; a separate Activity
  // Licence is a pending product decision, so it is deliberately NOT required.
  SignupPurpose.constructionCompany: RoleFormConfig(
    purpose: SignupPurpose.constructionCompany,
    hasBusinessName: true,
    hasCompanyContact: true,
    documents: [DocumentKind.crCertificate, DocumentKind.municipalLicence],
  ),
  SignupPurpose.propertyDevelopmentCompany: RoleFormConfig(
    purpose: SignupPurpose.propertyDevelopmentCompany,
    hasBusinessName: true,
    hasCompanyContact: true,
    fourEyes: true,
    documents: [DocumentKind.officialCorporateRegistration, DocumentKind.crCertificate, DocumentKind.activityLicences, DocumentKind.developerLicence],
  ),
  SignupPurpose.buildingArchitecture: RoleFormConfig(
    purpose: SignupPurpose.buildingArchitecture,
    hasBusinessName: true,
    hasCompanyContact: true,
    companyAddressRequired: true,
    documents: [DocumentKind.crCertificate, DocumentKind.municipalLicence],
  ),
  SignupPurpose.interiorExteriorDesign: RoleFormConfig(
    purpose: SignupPurpose.interiorExteriorDesign,
    hasBusinessName: true,
    hasCompanyContact: true,
    companyAddressRequired: true,
    hasServiceType: true,
    documents: [DocumentKind.crCertificate, DocumentKind.municipalLicence],
  ),
};

/// Public form values. Passwords and documents are NEVER part of this object.
class SignupFormValues {
  final String firstName, lastName, phone, email, businessName, agencyName, companyEmail, companyAddress;
  final InteriorExteriorServiceType? serviceType;
  final bool consent;
  const SignupFormValues({this.firstName = '', this.lastName = '', this.phone = '', this.email = '', this.businessName = '', this.agencyName = '', this.companyEmail = '', this.companyAddress = '', this.serviceType, this.consent = false});

  SignupFormValues copyWith({String? firstName, String? lastName, String? phone, String? email, String? businessName, String? agencyName, String? companyEmail, String? companyAddress, InteriorExteriorServiceType? serviceType, bool? consent}) => SignupFormValues(
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        businessName: businessName ?? this.businessName,
        agencyName: agencyName ?? this.agencyName,
        companyEmail: companyEmail ?? this.companyEmail,
        companyAddress: companyAddress ?? this.companyAddress,
        serviceType: serviceType ?? this.serviceType,
        consent: consent ?? this.consent,
      );

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'email': email,
        'businessName': businessName,
        'agencyName': agencyName,
        'companyEmail': companyEmail,
        'companyAddress': companyAddress,
        'serviceType': serviceType?.name,
        'consent': consent,
      };

  factory SignupFormValues.fromJson(Map<String, dynamic> j) => SignupFormValues(
        firstName: j['firstName'] as String? ?? '',
        lastName: j['lastName'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        email: j['email'] as String? ?? '',
        businessName: j['businessName'] as String? ?? '',
        agencyName: j['agencyName'] as String? ?? '',
        companyEmail: j['companyEmail'] as String? ?? '',
        companyAddress: j['companyAddress'] as String? ?? '',
        serviceType: InteriorExteriorServiceType.values.where((e) => e.name == j['serviceType']).firstOrNull,
        consent: j['consent'] as bool? ?? false,
      );
}

/// Resolved account/session (GET /me).
class MeSession {
  final AccountState account;
  final SignupPurpose? purpose;
  final GrantState? grant;
  final ReviewStage? stage;
  final String? phoneLast4;
  /// Profile fields from GET /me (editable through PATCH /me). Null when the service does not send them.
  final String? firstName, lastName, email;
  /// Business or agency name recorded at sign-up (company and agent paths).
  final String? businessName;
  /// Maintenance provider grant (admin-invited, not a public sign-up path). Null when the account has none.
  final GrantState? providerGrant;
  const MeSession({required this.account, this.purpose, this.grant, this.stage, this.phoneLast4, this.firstName, this.lastName, this.email, this.businessName, this.providerGrant});

  String get displayName => [firstName, lastName].whereType<String>().where((x) => x.trim().isNotEmpty).join(' ');
}

enum DocumentOutcome { notSubmitted, pendingReview, accepted, rejected }

class DocumentStatus {
  final DocumentKind kind;
  final DocumentOutcome outcome;
  final DateTime? expiry;
  final String? rejectionReasonCode;
  /// Metadata only (never content): shown in review and details.
  final String? fileName;
  final int? sizeBytes;
  final DateTime? uploadedAt;
  const DocumentStatus({required this.kind, required this.outcome, this.expiry, this.rejectionReasonCode, this.fileName, this.sizeBytes, this.uploadedAt});
}

/// GET /me/verification.
class VerificationInfo {
  final SignupPurpose purpose;
  final GrantState grant;
  final ReviewStage? stage;
  final DateTime? submittedAt;
  final List<DocumentStatus> documents;
  final String? reasonCode;
  /// Application reference and company name: derived/demo until the API contract defines them.
  final String? reference;
  final String? businessName;
  final DateTime? decidedAt;
  const VerificationInfo({required this.purpose, required this.grant, this.stage, this.submittedAt, this.documents = const [], this.reasonCode, this.reference, this.businessName, this.decidedAt});
}

/// Expiry-aware status for CR / licence documents.
enum ExpiryStatus { none, valid, expiringSoon, expired }

ExpiryStatus expiryStatusOf(DateTime? expiry, {DateTime? now}) {
  if (expiry == null) return ExpiryStatus.none;
  final n = now ?? DateTime.now();
  if (expiry.isBefore(n)) return ExpiryStatus.expired;
  if (expiry.difference(n).inDays <= 30) return ExpiryStatus.expiringSoon;
  return ExpiryStatus.valid;
}

/// What the person must do about one document. Derived only from the model's own state.
enum DocAction { none, fix, replaceExpired, uploadMissing }

DocAction docActionOf(DocumentStatus d, {DateTime? now}) {
  if (d.outcome == DocumentOutcome.rejected) return DocAction.fix;
  if (d.outcome == DocumentOutcome.notSubmitted) return DocAction.uploadMissing;
  if (expiryStatusOf(d.expiry, now: now) == ExpiryStatus.expired) return DocAction.replaceExpired;
  return DocAction.none;
}

/// One calm display vocabulary for a document, used by tiles, rows and the preview sheet.
enum DocDisplay { empty, uploading, processing, underReview, verified, needsUpdate, expired, missing, failed }

DocDisplay docDisplayOfStatus(DocumentStatus d, {DateTime? now}) => switch (docActionOf(d, now: now)) {
      DocAction.fix => DocDisplay.needsUpdate,
      DocAction.uploadMissing => DocDisplay.missing,
      DocAction.replaceExpired => DocDisplay.expired,
      DocAction.none => d.outcome == DocumentOutcome.accepted ? DocDisplay.verified : DocDisplay.underReview,
    };

/// Documents the person must act on, straight from the model: rejected, expired or missing.
Set<DocumentKind> resubmissionTargetsOf(Iterable<DocumentStatus> docs, {DateTime? now}) => {for (final d in docs) if (docActionOf(d, now: now) != DocAction.none) d.kind};

/// How "Review changes" groups documents. Only what the model reports as accepted is "approved".
({List<DocumentStatus> updated, List<DocumentStatus> approved, List<DocumentStatus> pending, List<DocumentStatus> stillNeeds}) groupForReview(Iterable<DocumentStatus> docs, Set<DocumentKind> targets, {DateTime? now}) => (
      updated: [for (final d in docs) if (targets.contains(d.kind)) d],
      approved: [for (final d in docs) if (!targets.contains(d.kind) && d.outcome == DocumentOutcome.accepted && docActionOf(d, now: now) == DocAction.none) d],
      pending: [for (final d in docs) if (!targets.contains(d.kind) && d.outcome == DocumentOutcome.pendingReview && docActionOf(d, now: now) == DocAction.none) d],
      stillNeeds: [for (final d in docs) if (!targets.contains(d.kind) && docActionOf(d, now: now) != DocAction.none) d],
    );
