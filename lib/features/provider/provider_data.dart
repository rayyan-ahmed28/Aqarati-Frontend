import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/backend_mode.dart';
import '../../core/domain/account_models.dart';
import '../../data/api/account_api.dart' show ApiErrorCode, ApiException;
import '../../data/demo/demo_backend.dart';
import '../../data/demo/demo_providers.dart' show demoBackendStateProvider;
import '../maintenance/maintenance_models.dart';

/// Maintenance providers are onboarded by admin invitation, never by public sign-up
/// (architecture section 19.9): one-time link -> credentials -> company details -> CR + municipal
/// licence -> the same verification queue -> approved provider workspace.

enum InvitationState { valid, expired, used, notFound }

class ProviderInvitation {
  final String token;
  final InvitationState state;
  /// As entered by the inviting admin; the business confirms or corrects it.
  final String companyName;
  final String email;
  final DateTime? expiresAt;
  const ProviderInvitation({required this.token, required this.state, this.companyName = '', this.email = '', this.expiresAt});
}

/// Provider documents (CONFIRMED): CR certificate and municipal licence (Baladiya).
enum ProviderDocument { crCertificate, municipalLicence }

class ProviderApplication {
  final String companyName, contactFirst, contactLast, phone, email, address, governorate;
  final Set<MaintenanceService> services;
  final Set<String> wilayats;
  const ProviderApplication({this.companyName = '', this.contactFirst = '', this.contactLast = '', this.phone = '', this.email = '', this.address = '', this.governorate = '', this.services = const {}, this.wilayats = const {}});

  ProviderApplication copyWith({String? companyName, String? contactFirst, String? contactLast, String? phone, String? email, String? address, String? governorate, Set<MaintenanceService>? services, Set<String>? wilayats}) => ProviderApplication(
        companyName: companyName ?? this.companyName,
        contactFirst: contactFirst ?? this.contactFirst,
        contactLast: contactLast ?? this.contactLast,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        governorate: governorate ?? this.governorate,
        services: services ?? this.services,
        wilayats: wilayats ?? this.wilayats,
      );

  /// FlowStrings keys per field; empty when the details are complete.
  Map<String, String> validate() => {
        if (companyName.trim().length < 2) 'company': 'prv.err.company',
        if (contactFirst.trim().isEmpty) 'first': 'common.required',
        if (contactLast.trim().isEmpty) 'last': 'common.required',
        if (!RegExp(r'^\d{8}$').hasMatch(phone)) 'phone': 'err.phone',
        if (address.trim().length < 5) 'address': 'prv.err.address',
        if (services.isEmpty) 'services': 'prv.err.services',
        if (governorate.isEmpty) 'governorate': 'lst.err.governorate',
        if (wilayats.isEmpty) 'wilayats': 'prv.err.area',
      };
}

/// One booking request as the provider sees it. The requester is shown by a label and a contact
/// number for agreeing the exact time (no in-app chat, no calendar sync).
class ProviderRequest {
  final String id;
  final MaintenanceService service;
  final DateTime date;
  final MaintenanceWindow window;
  final String wilayat;
  final String notes;
  final String requesterLabel;
  final String requesterPhone;
  final MaintenanceStatus status;
  final DateTime createdAt;
  const ProviderRequest({required this.id, required this.service, required this.date, required this.window, required this.wilayat, this.notes = '', required this.requesterLabel, required this.requesterPhone, required this.status, required this.createdAt});
  ProviderRequest copyWith(MaintenanceStatus status) => ProviderRequest(id: id, service: service, date: date, window: window, wilayat: wilayat, notes: notes, requesterLabel: requesterLabel, requesterPhone: requesterPhone, status: status, createdAt: createdAt);

  bool canComplete(DateTime now) => status == MaintenanceStatus.confirmed && !DateTime(date.year, date.month, date.day).isAfter(DateTime(now.year, now.month, now.day));
}

class ProviderNotApprovedException implements Exception {
  const ProviderNotApprovedException();
}

abstract class ProviderRepository {
  Future<ProviderInvitation> invitation(String token);
  /// POST /invitations/:token/accept: creates the provider's credentials and organisation.
  Future<void> accept(String token, ProviderApplication app, String password);
  Future<void> upload(ProviderDocument kind, String fileName);
  Future<Set<ProviderDocument>> uploaded();
  Future<void> submit();
  Future<List<ProviderRequest>> requests();
  Future<ProviderRequest?> request(String id);
  Future<ProviderRequest> decide(String id, MaintenanceStatus to);
}

class UnavailableProviderRepository implements ProviderRepository {
  const UnavailableProviderRepository();
  Never _no() => throw const ApiException(ApiErrorCode.network);
  @override
  Future<ProviderInvitation> invitation(String token) async => _no();
  @override
  Future<void> accept(String token, ProviderApplication app, String password) async => _no();
  @override
  Future<void> upload(ProviderDocument kind, String fileName) async => _no();
  @override
  Future<Set<ProviderDocument>> uploaded() async => _no();
  @override
  Future<void> submit() async => _no();
  @override
  Future<List<ProviderRequest>> requests() async => _no();
  @override
  Future<ProviderRequest?> request(String id) async => _no();
  @override
  Future<ProviderRequest> decide(String id, MaintenanceStatus to) async => _no();
}

/// DEMO ONLY. Invitation tokens: `demo-invite` (valid), `expired`, `used`; anything else is unknown.
/// Incoming requests are fictional and appear only once the simulated provider grant is approved.
class DemoProviderRepository implements ProviderRepository {
  DemoProviderRepository(this._state, {this.latency = const Duration(milliseconds: 400), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final DemoBackendState? Function() _state;
  final Duration latency;
  final DateTime Function() _clock;
  final Set<ProviderDocument> _docs = {};
  final Set<String> _accepted = {};
  List<ProviderRequest>? _requests;

  Future<void> _lag() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  DemoBackendState get _s => _state() ?? (throw const ApiException(ApiErrorCode.network));

  @override
  Future<ProviderInvitation> invitation(String token) async {
    await _lag();
    final now = _clock();
    return switch (token) {
      'demo-invite' when !_accepted.contains(token) => ProviderInvitation(token: token, state: InvitationState.valid, companyName: 'Demo Maintenance Co.', email: 'provider@example.test', expiresAt: now.add(const Duration(days: 6))),
      'demo-invite' || 'used' => ProviderInvitation(token: token, state: InvitationState.used),
      'expired' => ProviderInvitation(token: token, state: InvitationState.expired, expiresAt: now.subtract(const Duration(days: 1))),
      _ => ProviderInvitation(token: token, state: InvitationState.notFound),
    };
  }

  @override
  Future<void> accept(String token, ProviderApplication app, String password) async {
    await _lag();
    final inv = await invitation(token);
    if (inv.state != InvitationState.valid) throw const ApiException(ApiErrorCode.conflict);
    if (app.validate().isNotEmpty || password.length < 8) throw const ApiException(ApiErrorCode.validationFailed);
    final s = _s;
    s.wipe();
    s
      ..email = app.email
      ..password = password
      ..phone = app.phone
      ..firstName = app.contactFirst.trim()
      ..lastName = app.contactLast.trim()
      ..businessName = app.companyName.trim()
      ..account = AccountState.active
      ..providerGrant = GrantState.draft
      ..signedIn = true;
    _accepted.add(token);
    _docs.clear();
  }

  @override
  Future<void> upload(ProviderDocument kind, String fileName) async {
    await _lag();
    if (fileName.toLowerCase().contains('fail')) throw const ApiException(ApiErrorCode.network);
    _docs.add(kind);
  }

  @override
  Future<Set<ProviderDocument>> uploaded() async {
    await _lag();
    return Set.unmodifiable(_docs);
  }

  @override
  Future<void> submit() async {
    await _lag();
    if (_docs.length < ProviderDocument.values.length) throw const ApiException(ApiErrorCode.validationFailed);
    final s = _s;
    s.providerGrant = GrantState.pendingVerification;
    s.submittedAt = _clock();
  }

  void _ensureApproved() {
    if (_s.providerGrant != GrantState.approved) throw const ProviderNotApprovedException();
  }

  List<ProviderRequest> _seed() {
    final now = _clock();
    DateTime day(int d) => DateTime(now.year, now.month, now.day).add(Duration(days: d));
    return [
      ProviderRequest(id: 'pr1', service: MaintenanceService.ac, date: day(2), window: MaintenanceWindow.morning, wilayat: 'Bawshar', notes: 'Demo request: the unit is not cooling.', requesterLabel: 'Customer (demo)', requesterPhone: '+968 9000 0101', status: MaintenanceStatus.requested, createdAt: now.subtract(const Duration(hours: 3))),
      ProviderRequest(id: 'pr2', service: MaintenanceService.plumber, date: day(0), window: MaintenanceWindow.afternoon, wilayat: 'Seeb', requesterLabel: 'Customer (demo)', requesterPhone: '+968 9000 0102', status: MaintenanceStatus.confirmed, createdAt: now.subtract(const Duration(days: 1))),
      ProviderRequest(id: 'pr3', service: MaintenanceService.pool, date: day(-5), window: MaintenanceWindow.evening, wilayat: 'Muttrah', requesterLabel: 'Customer (demo)', requesterPhone: '+968 9000 0103', status: MaintenanceStatus.completed, createdAt: now.subtract(const Duration(days: 8))),
    ];
  }

  @override
  Future<List<ProviderRequest>> requests() async {
    await _lag();
    _ensureApproved();
    return List.unmodifiable(_requests ??= _seed());
  }

  @override
  Future<ProviderRequest?> request(String id) async {
    await _lag();
    _ensureApproved();
    return (_requests ??= _seed()).where((r) => r.id == id).firstOrNull;
  }

  @override
  Future<ProviderRequest> decide(String id, MaintenanceStatus to) async {
    await _lag();
    _ensureApproved();
    final list = _requests ??= _seed();
    final i = list.indexWhere((r) => r.id == id);
    if (i < 0) throw const ApiException(ApiErrorCode.server);
    final r = list[i];
    final ok = switch (to) {
      MaintenanceStatus.confirmed || MaintenanceStatus.declined => r.status == MaintenanceStatus.requested,
      MaintenanceStatus.cancelled => r.status == MaintenanceStatus.confirmed,
      MaintenanceStatus.completed => r.canComplete(_clock()),
      MaintenanceStatus.requested => false,
    };
    if (!ok) throw const ApiException(ApiErrorCode.conflict);
    return list[i] = r.copyWith(to);
  }

  /// QA: simulate the reviewer's decision on the provider grant.
  void debugDecide(GrantState g) => _s.providerGrant = g;
}

final providerRepositoryProvider = Provider<ProviderRepository>((ref) => kUseDemoBackend ? DemoProviderRepository(() => ref.read(demoBackendStateProvider)) : const UnavailableProviderRepository());
final providerInvitationProvider = FutureProvider.autoDispose.family<ProviderInvitation, String>((ref, t) => ref.watch(providerRepositoryProvider).invitation(t));
final providerDocsProvider = FutureProvider.autoDispose<Set<ProviderDocument>>((ref) => ref.watch(providerRepositoryProvider).uploaded());
final providerRequestsProvider = FutureProvider.autoDispose<List<ProviderRequest>>((ref) => ref.watch(providerRepositoryProvider).requests());
final providerRequestProvider = FutureProvider.autoDispose.family<ProviderRequest?, String>((ref, id) => ref.watch(providerRepositoryProvider).request(id));
