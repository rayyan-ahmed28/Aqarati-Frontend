import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/backend_mode.dart';
import '../../data/api/account_api.dart' show ApiErrorCode, ApiException;
import '../../data/models/property.dart';
import '../../data/repositories/providers.dart' show propertyRepositoryProvider;

/// An Aqarati Broker: a seller grant with sub-type aqarati_broker, created by a Super Admin and
/// approved by a Senior Reviewer (architecture section 83). Only approved brokers are public.
class AqaratiBroker {
  final String id;
  final String name;
  final String governorate;
  final String wilayat;
  /// Year the badge was granted (from the approval date). Not an experience claim.
  final DateTime badgeSince;
  /// Approved listings linked to this broker (`listed_via = aqarati_broker`).
  final List<String> propertyIds;
  /// Returned to signed-in callers only (section 31.1).
  final String? phone;
  final String? whatsapp;
  const AqaratiBroker({required this.id, required this.name, required this.governorate, required this.wilayat, required this.badgeSince, this.propertyIds = const [], this.phone, this.whatsapp});
}

class BrokerQuery {
  final String text;
  final String? governorate;
  const BrokerQuery({this.text = '', this.governorate});
  @override
  bool operator ==(Object other) => other is BrokerQuery && other.text == text && other.governorate == governorate;
  @override
  int get hashCode => Object.hash(text, governorate);
}

/// GET /professionals?type=aqarati_broker style directory plus GET /properties?broker= (section 17).
abstract class BrokerRepository {
  Future<List<AqaratiBroker>> search(BrokerQuery q);
  Future<AqaratiBroker?> get(String id);
  Future<List<Property>> listings(String id);
}

class UnavailableBrokerRepository implements BrokerRepository {
  const UnavailableBrokerRepository();
  Never _no() => throw const ApiException(ApiErrorCode.network);
  @override
  Future<List<AqaratiBroker>> search(BrokerQuery q) async => _no();
  @override
  Future<AqaratiBroker?> get(String id) async => _no();
  @override
  Future<List<Property>> listings(String id) async => _no();
}

/// DEMO ONLY: fictional brokers linked to the existing demo properties. No ratings, review counts,
/// commissions or performance numbers are invented; a broker's rating comes only from published reviews.
class DemoBrokerRepository implements BrokerRepository {
  DemoBrokerRepository(this._properties, {this.latency = const Duration(milliseconds: 300)});
  final Future<List<Property>> Function() _properties;
  final Duration latency;

  static final roster = [
    AqaratiBroker(id: 'ab1', name: 'Demo Broker · Muscat', governorate: 'Muscat', wilayat: 'Bawshar', badgeSince: DateTime(2026, 9), propertyIds: const ['p1', 'p2'], phone: '+968 9000 0001', whatsapp: '+968 9000 0001'),
    AqaratiBroker(id: 'ab2', name: 'Demo Broker · Dhofar', governorate: 'Dhofar', wilayat: 'Salalah', badgeSince: DateTime(2026, 9), propertyIds: const ['p4'], phone: '+968 9000 0002', whatsapp: '+968 9000 0002'),
    AqaratiBroker(id: 'ab3', name: 'Demo Broker · Seeb', governorate: 'Muscat', wilayat: 'Seeb', badgeSince: DateTime(2026, 10), propertyIds: const ['p3', 'p5'], phone: '+968 9000 0003'),
  ];

  Future<void> _lag() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<List<AqaratiBroker>> search(BrokerQuery q) async {
    await _lag();
    final t = q.text.trim().toLowerCase();
    return roster.where((b) => (q.governorate == null || b.governorate == q.governorate) && (t.isEmpty || b.name.toLowerCase().contains(t) || b.wilayat.toLowerCase().contains(t) || b.governorate.toLowerCase().contains(t))).toList();
  }

  @override
  Future<AqaratiBroker?> get(String id) async {
    await _lag();
    return roster.where((b) => b.id == id).firstOrNull;
  }

  @override
  Future<List<Property>> listings(String id) async {
    await _lag();
    final b = roster.where((b) => b.id == id).firstOrNull;
    if (b == null) return const [];
    final all = await _properties();
    return [for (final p in all) if (b.propertyIds.contains(p.id) && p.verification.isVerified) p];
  }
}

final brokerRepositoryProvider = Provider<BrokerRepository>((ref) => kUseDemoBackend ? DemoBrokerRepository(() => ref.read(propertyRepositoryProvider).search()) : const UnavailableBrokerRepository());
final brokersProvider = FutureProvider.autoDispose.family<List<AqaratiBroker>, BrokerQuery>((ref, q) => ref.watch(brokerRepositoryProvider).search(q));
final brokerProvider = FutureProvider.autoDispose.family<AqaratiBroker?, String>((ref, id) => ref.watch(brokerRepositoryProvider).get(id));
final brokerListingsProvider = FutureProvider.autoDispose.family<List<Property>, String>((ref, id) => ref.watch(brokerRepositoryProvider).listings(id));

/// The broker whose programme listing this property is, if any (badge on the property page).
AqaratiBroker? brokerForProperty(String propertyId) => kUseDemoBackend ? DemoBrokerRepository.roster.where((b) => b.propertyIds.contains(propertyId)).firstOrNull : null;
