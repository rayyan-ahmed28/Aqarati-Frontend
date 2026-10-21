import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/config/backend_mode.dart';
import '../../core/domain/account_models.dart';
import '../../features/entry/models/signup_purpose.dart';

import '../../core/auth/auth_repository.dart';
import '../api/account_api.dart';
import 'demo_backend.dart';

/// The simulated backend state, shared with other demo-only repositories. Null outside demo mode.
final demoBackendStateProvider = Provider<DemoBackendState?>((ref) => null);

/// DEMO ONLY wiring (see lib/core/config/backend_mode.dart).
List<Override> demoOverrides() {
  final state = DemoBackendState();
  _seedReviewSession(state);
  return [
    demoBackendStateProvider.overrideWithValue(state),
    authRepositoryProvider.overrideWithValue(DemoAuthRepository(state)),
    accountApiProvider.overrideWithValue(DemoAccountApi(state)),
  ];
}

/// DEMO ONLY: replaces the simulated account with a signed-in one for [purpose], so a presenter can
/// open that role's home page without going through sign-up and verification. A buyer has no
/// business grant; every other role is shown as an approved business. Never used with a real backend.
void demoEnterAs(DemoBackendState s, SignupPurpose purpose) {
  s.wipe();
  final business = purpose != SignupPurpose.userToShop;
  s
    ..email = 'demo@example.test'
    ..phone = '90000000'
    ..purpose = purpose
    ..account = AccountState.active
    ..grant = business ? GrantState.approved : null
    ..stage = null
    ..businessName = business ? 'Demo business' : null
    ..firstName = 'Demo'
    ..lastName = 'Account'
    ..serviceType = purpose == SignupPurpose.interiorExteriorDesign ? InteriorExteriorServiceType.both : null
    ..signedIn = true
    ..emailVerified = true;
}

/// REVIEW TOOLS ONLY (`--dart-define=REVIEW_TOOLS=true --dart-define=REVIEW_SESSION=<name>`): starts the
/// demo already signed in as an approved business, so reviewers can open the workspace without
/// clicking through sign-up and verification. Does nothing in a normal build.
const _reviewSession = String.fromEnvironment('REVIEW_SESSION');

void _seedReviewSession(DemoBackendState s) {
  if (!kShowReviewTools) return;
  // QA builds can also pick the session at run time: `/?session=agent#/app/home`.
  final name = _reviewSession.isNotEmpty ? _reviewSession : (kIsWeb ? (Uri.base.queryParameters['session'] ?? '') : '');
  if (name.isEmpty) return;
  final (purpose, grant, stage) = switch (name) {
    'agent' => (
      SignupPurpose.realEstateAgent,
      GrantState.approved,
      null,
    ),
    'agent-pending' => (
      SignupPurpose.realEstateAgent,
      GrantState.pendingVerification,
      ReviewStage.underReview,
    ),
    'suspended' => (
      SignupPurpose.constructionCompany,
      GrantState.suspended,
      null,
    ),
    'resubmission' => (
      SignupPurpose.buildingArchitecture,
      GrantState.resubmissionRequired,
      null,
    ),
    'buyer' => (
      SignupPurpose.userToShop,
      null,
      null,
    ),
    'developer' => (
      SignupPurpose.propertyDevelopmentCompany,
      GrantState.approved,
      null,
    ),
    'construction' => (
      SignupPurpose.constructionCompany,
      GrantState.approved,
      null,
    ),
    'architecture' => (
      SignupPurpose.buildingArchitecture,
      GrantState.approved,
      null,
    ),
    'interior' => (
      SignupPurpose.interiorExteriorDesign,
      GrantState.approved,
      null,
    ),
    'pending' => (
      SignupPurpose.propertyDevelopmentCompany,
      GrantState.pendingVerification,
      ReviewStage.underReview,
    ),
    'second' => (
      SignupPurpose.propertyDevelopmentCompany,
      GrantState.pendingVerification,
      ReviewStage.awaitingSecondApproval,
    ),
    'rejected' => (
      SignupPurpose.constructionCompany,
      GrantState.rejected,
      null,
    ),
    _ => (null, null, null),
  };
  if (purpose == null) return;
  s
    ..email = 'review@example.test'
    ..phone = '90000000'
    ..purpose = purpose
    ..account = AccountState.active
    ..grant = grant
    ..stage = stage
    ..businessName = 'Review Business'
    ..firstName = 'Review'
    ..lastName = 'Account'
    ..serviceType = name == 'interior' ? InteriorExteriorServiceType.both : null
    ..signedIn = true
    ..emailVerified = true;
}
