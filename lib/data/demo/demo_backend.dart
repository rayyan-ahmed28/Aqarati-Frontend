import 'dart:async';
import '../../core/auth/auth_repository.dart';
import '../../core/domain/account_models.dart';
import '../../features/entry/models/signup_purpose.dart';
import '../api/account_api.dart';

/// DEMO ONLY (see lib/core/config/backend_mode.dart). Simulates the documented
/// contract in memory so screens can be reviewed. Not a backend.
/// Demo OTP code: 123456. A file whose name contains "fail" fails to upload.
const kDemoOtpCode = '123456';

class DemoBackendState {
  String? email;
  String? password;
  String? phone;
  SignupPurpose? purpose;
  AccountState account = AccountState.otpPending;
  GrantState? grant;
  ReviewStage? stage;
  DateTime? submittedAt;
  final Map<DocumentKind, DocumentStatus> docs = {};
  DateTime? otpExpiresAt;
  DateTime? lastOtpAt;
  final List<DateTime> otpSends = [];
  int wrongAttempts = 0;
  bool signedIn = false;
  DateTime? emailVerifySentAt;
  bool emailVerified = false;
  String? reason;
  String? businessName;
  InteriorExteriorServiceType? serviceType;
  String? reference;
  DateTime? decidedAt;
  String? firstName;
  String? lastName;
  GrantState? providerGrant;
  /// Failure injection for QA and tests: the next profile save fails.
  bool failNextProfileSave = false;

  /// DEMO: forgets the simulated account (used by the simulated account deletion).
  void wipe() {
    email = null;
    password = null;
    phone = null;
    purpose = null;
    account = AccountState.otpPending;
    grant = null;
    stage = null;
    submittedAt = null;
    docs.clear();
    otpExpiresAt = null;
    lastOtpAt = null;
    otpSends.clear();
    wrongAttempts = 0;
    signedIn = false;
    emailVerifySentAt = null;
    emailVerified = false;
    reason = null;
    businessName = null;
    serviceType = null;
    reference = null;
    decidedAt = null;
    firstName = null;
    lastName = null;
    providerGrant = null;
  }
}

class DemoAuthRepository implements AuthRepository {
  final DemoBackendState s;
  DemoAuthRepository(this.s);

  @override
  Future<AuthResult> signInWithProvider(AuthProviderKind kind) async => const AuthUnavailable();

  @override
  Future<void> signInWithEmail(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    // Generic failure: never reveal whether the account exists.
    if (s.email == null || s.email!.toLowerCase() != email.trim().toLowerCase() || s.password != password) {
      throw const AuthException(AuthError.invalidCredentials);
    }
    s.signedIn = true;
  }

  @override
  Future<void> createUserWithEmail(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // An email that already belongs to an active account is a conflict (recovery UI), not a silent overwrite.
    if (s.email != null && s.email!.toLowerCase() == email.trim().toLowerCase() && s.account == AccountState.active) throw const AuthException(AuthError.unknown);
    s.email = email.trim();
    s.password = password;
    s.signedIn = true;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async => Future<void>.delayed(const Duration(milliseconds: 600));

  @override
  Future<void> confirmPasswordReset(String oobCode, String newPassword) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (oobCode == 'expired') throw const AuthException(AuthError.expiredCode);
    s.password = newPassword;
  }

  @override
  Future<void> signOut() async => s.signedIn = false;

  @override
  Future<String?> currentIdToken() async => s.signedIn ? 'demo-id-token' : null;

  @override
  Future<void> sendEmailVerification() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    s.emailVerifySentAt = DateTime.now();
  }

  /// Demo: the link counts as opened a few seconds after it was "sent".
  @override
  Future<bool> isEmailVerified() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final sent = s.emailVerifySentAt;
    if (sent != null && DateTime.now().difference(sent).inSeconds >= 6) s.emailVerified = true;
    return s.emailVerified;
  }

  @override
  Future<String?> currentEmail() async => s.email;

  @override
  Future<void> updateEmail(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    s.email = email.trim();
    s.emailVerified = false;
    s.emailVerifySentAt = DateTime.now();
  }
}

class DemoAccountApi implements AccountApi {
  final DemoBackendState s;
  DemoAccountApi(this.s);

  static const _cooldown = 30;

  MeSession _me() => MeSession(
        account: s.account,
        purpose: s.purpose,
        grant: s.grant,
        stage: s.stage,
        phoneLast4: s.phone == null || s.phone!.length < 4 ? null : s.phone!.substring(s.phone!.length - 4),
        firstName: s.firstName,
        lastName: s.lastName,
        email: s.email,
        businessName: s.businessName,
        providerGrant: s.providerGrant,
      );

  @override
  Future<MeSession> signUp(SignupPurpose purpose, SignupFormValues values) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    s.purpose = purpose;
    s.phone = values.phone;
    s.firstName = values.firstName.trim();
    s.lastName = values.lastName.trim();
    s.businessName = values.businessName.isNotEmpty ? values.businessName : (values.agencyName.isNotEmpty ? values.agencyName : '${values.firstName} ${values.lastName}'.trim());
    s.serviceType = values.serviceType;
    s.account = AccountState.otpPending;
    s.grant = null;
    return _me();
  }

  @override
  Future<OtpIssued> startPhoneVerification() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final now = DateTime.now();
    final last = s.lastOtpAt;
    if (last != null && now.difference(last).inSeconds < _cooldown) {
      throw ApiException(ApiErrorCode.rateLimited, retryAfterSeconds: _cooldown - now.difference(last).inSeconds);
    }
    s.otpSends.removeWhere((t) => now.difference(t).inMinutes >= 15);
    if (s.otpSends.length >= 3) throw const ApiException(ApiErrorCode.otpLimitReached, retryAfterSeconds: 300);
    s.otpSends.add(now);
    s.lastOtpAt = now;
    s.wrongAttempts = 0;
    s.otpExpiresAt = now.add(const Duration(minutes: 15));
    return OtpIssued(cooldownSeconds: _cooldown, expiresAt: s.otpExpiresAt!);
  }

  @override
  Future<OtpVerifyResult> verifyPhone(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (s.otpExpiresAt == null || DateTime.now().isAfter(s.otpExpiresAt!)) return OtpVerifyResult.expired;
    if (s.wrongAttempts >= 5) return OtpVerifyResult.rateLimited; // 5 wrong attempts invalidate the code
    if (code != kDemoOtpCode) {
      s.wrongAttempts++;
      return OtpVerifyResult.invalid;
    }
    s.account = AccountState.active;
    final cfg = roleConfigs[s.purpose];
    if (cfg != null && cfg.needsDocuments) s.grant = GrantState.draft;
    return OtpVerifyResult.verified;
  }

  @override
  Future<void> changePhone(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    s.phone = phone;
    s.lastOtpAt = null; // the new number may be sent a code immediately (send counts still apply)
    s.wrongAttempts = 0;
  }

  @override
  Future<MeSession> getMe() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!s.signedIn) throw const ApiException(ApiErrorCode.network);
    return _me();
  }

  @override
  Future<void> uploadDocument(DocumentKind kind, PickedDocument file, DateTime? expiry, void Function(double) onProgress) async {
    for (var i = 1; i <= 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      onProgress(i / 5);
      if (file.name.toLowerCase().contains('fail') && i == 3) throw const ApiException(ApiErrorCode.network);
    }
    await Future<void>.delayed(const Duration(milliseconds: 500)); // scanning
    s.docs[kind] = DocumentStatus(kind: kind, outcome: DocumentOutcome.pendingReview, expiry: expiry, fileName: file.name, sizeBytes: file.sizeBytes, uploadedAt: DateTime.now());
  }

  @override
  Future<VerificationInfo> getVerification() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final cfg = roleConfigs[s.purpose]!;
    return VerificationInfo(
      purpose: cfg.purpose,
      grant: s.grant ?? GrantState.draft,
      stage: s.stage,
      submittedAt: s.submittedAt,
      reasonCode: s.reason,
      reference: s.reference,
      businessName: s.businessName,
      decidedAt: s.decidedAt,
      documents: [for (final k in cfg.documents) s.docs[k] ?? DocumentStatus(kind: k, outcome: DocumentOutcome.notSubmitted)],
    );
  }

  @override
  Future<void> submitVerification() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    s.grant = GrantState.pendingVerification;
    s.stage = ReviewStage.underReview;
    s.submittedAt = DateTime.now();
    s.reference ??= 'AQ-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().substring(3)}';
  }

  @override
  Future<void> deleteAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    s.wipe();
  }

  @override
  Future<MeSession> updateProfile({required String firstName, required String lastName}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!s.signedIn) throw const ApiException(ApiErrorCode.network);
    if (s.failNextProfileSave) {
      s.failNextProfileSave = false;
      throw const ApiException(ApiErrorCode.server);
    }
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) throw const ApiException(ApiErrorCode.validationFailed);
    s.firstName = firstName.trim();
    s.lastName = lastName.trim();
    return _me();
  }

  /// Demo: there is only this device, so revoking every session signs this one out.
  @override
  Future<void> signOutEverywhere() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    s.signedIn = false;
  }

  @override
  Future<void> resubmit() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    s.grant = GrantState.pendingVerification;
    s.stage = ReviewStage.underReview;
    s.reason = null;
    s.submittedAt = DateTime.now();
    for (final e in s.docs.entries.toList()) {
      if (e.value.outcome == DocumentOutcome.rejected) s.docs[e.key] = DocumentStatus(kind: e.key, outcome: DocumentOutcome.pendingReview, expiry: e.value.expiry, fileName: e.value.fileName, sizeBytes: e.value.sizeBytes, uploadedAt: DateTime.now());
    }
  }

  /// Demo-only reviewer simulation so every status screen can be reviewed.
  void demoSimulate(GrantState next) {
    s.grant = next;
    final cfg = roleConfigs[s.purpose];
    s.stage = next == GrantState.pendingVerification ? ReviewStage.underReview : null;
    s.reason = null;
    if (next == GrantState.resubmissionRequired && cfg != null) {
      final first = cfg.documents.first;
      final old = s.docs[first];
      s.docs[first] = DocumentStatus(kind: first, outcome: DocumentOutcome.rejected, expiry: old?.expiry, rejectionReasonCode: 'DOC_UNREADABLE', fileName: old?.fileName, sizeBytes: old?.sizeBytes, uploadedAt: old?.uploadedAt);
      s.reason = 'DOC_UNREADABLE';
    }
    if (next == GrantState.rejected) s.reason = 'DOC_MISMATCH';
    if (next == GrantState.approved) {
      s.decidedAt = DateTime.now();
      for (final k in s.docs.keys.toList()) {
        s.docs[k] = DocumentStatus(kind: k, outcome: DocumentOutcome.accepted, expiry: s.docs[k]?.expiry, fileName: s.docs[k]?.fileName, sizeBytes: s.docs[k]?.sizeBytes, uploadedAt: s.docs[k]?.uploadedAt);
      }
    }
  }

  /// Demo-only shortcut (web file picker cannot be scripted): mark every required document as received.
  void demoAttachAll() {
    final cfg = roleConfigs[s.purpose];
    if (cfg == null) return;
    for (final k in cfg.documents) {
      s.docs[k] = DocumentStatus(kind: k, outcome: DocumentOutcome.pendingReview, expiry: k.tracksExpiry ? DateTime.now().add(const Duration(days: 400)) : null, fileName: '${k.name}.pdf', sizeBytes: 184320, uploadedAt: DateTime.now());
    }
  }

  void demoAwaitSecondApproval() {
    s.grant = GrantState.pendingVerification;
    s.stage = ReviewStage.awaitingSecondApproval;
  }
}
