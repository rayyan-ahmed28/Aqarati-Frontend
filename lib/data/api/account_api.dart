import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/domain/account_models.dart';
import '../../features/entry/models/signup_purpose.dart';

/// Error codes from the documented API error mapping.
enum ApiErrorCode { validationFailed, conflict, rateLimited, otpLimitReached, network, server }

class ApiException implements Exception {
  final ApiErrorCode code;
  final int? retryAfterSeconds;
  const ApiException(this.code, {this.retryAfterSeconds});
}

class OtpIssued {
  /// Cooldown before another code may be requested. Comes from the server.
  final int cooldownSeconds;
  /// 6-digit code validity (15 minutes in the current requirements).
  final DateTime expiresAt;
  const OtpIssued({required this.cooldownSeconds, required this.expiresAt});
}

enum OtpVerifyResult { verified, invalid, expired, rateLimited, serverError }

/// A file chosen for upload. Bytes are a TRANSIENT buffer: never cached,
/// never logged, never put in drafts or app state.
class PickedDocument {
  final String name;
  final int sizeBytes;
  final Uint8List bytes;
  const PickedDocument({required this.name, required this.sizeBytes, required this.bytes});
}

/// Aqarati customer API contract (frontend view only; see blueprint pp. 82-83).
abstract class AccountApi {
  /// POST /auth/sign-up (after the Firebase user exists) -> otp_pending.
  Future<MeSession> signUp(SignupPurpose purpose, SignupFormValues values);

  /// POST /auth/verify-phone/start
  Future<OtpIssued> startPhoneVerification();

  /// POST /auth/verify-phone
  Future<OtpVerifyResult> verifyPhone(String code);

  /// Replace the number a pending OTP was sent to. CONTRACT ASSUMPTION: the frontend needs this for the
  /// "wrong number" path; confirm the matching endpoint with the API owners before wiring.
  Future<void> changePhone(String phone);

  /// GET /me
  Future<MeSession> getMe();

  /// POST /documents (multipart, one document per call). Throws [ApiException].
  /// Completes when the file has been accepted for review (after scanning).
  Future<void> uploadDocument(DocumentKind kind, PickedDocument file, DateTime? expiry, void Function(double progress) onProgress);

  /// GET /me/documents + GET /me/verification (metadata and status only).
  Future<VerificationInfo> getVerification();

  /// Submit the initial package (grant draft -> pending_verification).
  Future<void> submitVerification();

  /// POST /me/verification/resubmit (grant -> pending_verification).
  Future<void> resubmit();

  /// PATCH /me: the person's own name. Email changes go through Firebase (verify-before-update) and
  /// the phone number is changed only through OTP, so neither is part of this call.
  Future<MeSession> updateProfile({required String firstName, required String lastName});

  /// POST /auth/log-out-all: revokes every session of this account, on every device.
  Future<void> signOutEverywhere();

  /// Asks AQARATI to delete the signed-in account. The endpoint is not confirmed; callers must treat a
  /// thrown [ApiException] as "nothing was deleted".
  Future<void> deleteAccount();
}

class UnavailableAccountApi implements AccountApi {
  const UnavailableAccountApi();
  Never _no() => throw const ApiException(ApiErrorCode.network);
  @override
  Future<MeSession> signUp(SignupPurpose purpose, SignupFormValues values) async => _no();
  @override
  Future<OtpIssued> startPhoneVerification() async => _no();
  @override
  Future<OtpVerifyResult> verifyPhone(String code) async => _no();
  @override
  Future<void> changePhone(String phone) async => _no();
  @override
  Future<MeSession> getMe() async => _no();
  @override
  Future<void> uploadDocument(DocumentKind kind, PickedDocument file, DateTime? expiry, void Function(double) onProgress) async => _no();
  @override
  Future<VerificationInfo> getVerification() async => _no();
  @override
  Future<void> submitVerification() async => _no();
  @override
  Future<void> resubmit() async => _no();
  @override
  Future<void> deleteAccount() async => _no();
  @override
  Future<MeSession> updateProfile({required String firstName, required String lastName}) async => _no();
  @override
  Future<void> signOutEverywhere() async => _no();
}

final accountApiProvider = Provider<AccountApi>((ref) => const UnavailableAccountApi());

/// Session hydrated from GET /me. Invalidate after sign-in, OTP, submit.
final meProvider = FutureProvider.autoDispose<MeSession>((ref) => ref.read(accountApiProvider).getMe());
final verificationProvider = FutureProvider.autoDispose<VerificationInfo>((ref) => ref.read(accountApiProvider).getVerification());
