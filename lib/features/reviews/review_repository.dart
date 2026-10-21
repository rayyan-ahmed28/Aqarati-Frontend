import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/backend_mode.dart';
import '../../data/api/account_api.dart'
    show ApiErrorCode, ApiException, meProvider;
import '../engagement/engagement_models.dart';
import '../engagement/engagement_repository.dart';
import '../maintenance/maintenance_models.dart';
import '../maintenance/maintenance_repository.dart';
import '../viewing/data/viewing_repository.dart';
import '../viewing/domain/viewing_models.dart';
import 'review_models.dart';

/// Frontend contract for reviews. The service enforces eligibility, uniqueness and moderation; the
/// app only reflects what it says. Submitting never makes a review public.
abstract class ReviewRepository {
  Future<MyReview> submit({
    required ReviewTarget target,
    required int rating,
    required String comment,
  });
  Future<MyReview> edit({
    required String id,
    required int rating,
    required String comment,
  });
  Future<List<MyReview>> mine();
  Future<MyReview?> forTarget(ReviewTarget target);
  /// POST /reviews/:id/reports.
  Future<void> report({required String reviewId, required String reason});
}

class UnavailableReviewRepository implements ReviewRepository {
  const UnavailableReviewRepository();
  Never _no() => throw const ApiException(ApiErrorCode.network);
  @override
  Future<MyReview> submit({
    required ReviewTarget target,
    required int rating,
    required String comment,
  }) async => _no();
  @override
  Future<MyReview> edit({
    required String id,
    required int rating,
    required String comment,
  }) async => _no();
  @override
  Future<List<MyReview>> mine() async => _no();
  @override
  Future<MyReview?> forTarget(ReviewTarget target) async => _no();
  @override
  Future<void> report({required String reviewId, required String reason}) async => _no();
}

/// DEMO ONLY: in memory. Moderation outcomes are simulated through [debugSet] (QA tools only).
class DemoReviewRepository implements ReviewRepository {
  DemoReviewRepository({
    this.latency = const Duration(milliseconds: 350),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final Duration latency;
  final DateTime Function() _clock;
  final List<MyReview> _items = [];
  final Set<String> _reported = {};
  int _seq = 0;

  Future<void> _lag() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<MyReview> submit({
    required ReviewTarget target,
    required int rating,
    required String comment,
  }) async {
    await _lag();
    if (_items.any((r) => r.target == target)) {
      throw const ReviewAlreadyExistsException();
    }
    if (rating < 1 || rating > 5 || reviewCommentError(comment) != null) {
      throw const ApiException(ApiErrorCode.validationFailed);
    }
    final r = MyReview(
      id: 'r${++_seq}',
      target: target,
      rating: rating,
      comment: comment.trim(),
      status: ReviewStatus.pendingModeration,
      createdAt: _clock(),
    );
    _items.add(r);
    return r;
  }

  @override
  Future<MyReview> edit({
    required String id,
    required int rating,
    required String comment,
  }) async {
    await _lag();
    final i = _items.indexWhere((r) => r.id == id);
    if (i < 0) throw const ApiException(ApiErrorCode.server);
    if (!_items[i].canEdit) throw const ReviewNotEditableException();
    if (rating < 1 || rating > 5 || reviewCommentError(comment) != null) {
      throw const ApiException(ApiErrorCode.validationFailed);
    }
    // An edit goes back through moderation.
    return _items[i] = _items[i].copyWith(
      rating: rating,
      comment: comment.trim(),
      status: ReviewStatus.pendingModeration,
      canEdit: false,
    );
  }

  @override
  Future<List<MyReview>> mine() async {
    await _lag();
    return List.unmodifiable(_items.reversed);
  }

  @override
  Future<MyReview?> forTarget(ReviewTarget target) async {
    await _lag();
    return _items.where((r) => r.target == target).firstOrNull;
  }

  @override
  Future<void> report({required String reviewId, required String reason}) async {
    await _lag();
    if (reportReasonError(reason) != null) throw const ApiException(ApiErrorCode.validationFailed);
    if (!_reported.add(reviewId)) throw const ReviewAlreadyReportedException();
  }

  bool debugReported(String reviewId) => _reported.contains(reviewId);

  /// QA only: simulates moderation and the "later interaction" that unlocks editing.
  void debugSet(String id, {ReviewStatus? status, bool? canEdit}) {
    final i = _items.indexWhere((r) => r.id == id);
    if (i >= 0) {
      _items[i] = _items[i].copyWith(status: status, canEdit: canEdit);
    }
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => kUseDemoBackend
      ? DemoReviewRepository()
      : const UnavailableReviewRepository(),
);
final myReviewsProvider = FutureProvider.autoDispose<List<MyReview>>(
  (ref) => ref.watch(reviewRepositoryProvider).mine(),
);

/// Works out whether the person can review [target] from what the app already knows. The service has
/// the final say (422 REVIEW_NOT_ELIGIBLE); this only decides which screen to show first.
final reviewEligibilityProvider = FutureProvider.autoDispose
    .family<ReviewEligibility, ReviewTarget>((ref, target) async {
      try {
        await ref.watch(meProvider.future);
      } catch (_) {
        return const ReviewEligibility(ReviewEligibilityKind.signedOut);
      }
      final existing = await ref
          .watch(reviewRepositoryProvider)
          .forTarget(target);
      if (existing != null) {
        return ReviewEligibility(
          ReviewEligibilityKind.alreadyReviewed,
          existing: existing,
        );
      }
      final now = DateTime.now();
      switch (target.kind) {
        case ReviewTargetKind.professional:
          final list = (await ref.watch(engagementRepositoryProvider).list())
              .where((e) => e.professionalId == target.id)
              .toList();
          final confirmed = list
              .where((e) => e.phase == EngagementPhase.confirmed)
              .toList();
          if (confirmed.isNotEmpty) {
            confirmed.sort((a, b) => b.confirmedAt!.compareTo(a.confirmedAt!));
            final latest = confirmed.first;
            return latest.reviewOpenAt(now)
                ? ReviewEligibility(
                    ReviewEligibilityKind.eligible,
                    windowEndsAt: latest.reviewBy,
                  )
                : ReviewEligibility(
                    ReviewEligibilityKind.windowExpired,
                    windowEndsAt: latest.reviewBy,
                  );
          }
          if (list.any(
            (e) => e.phaseAt(now) != EngagementPhase.expired && e.isWaiting,
          )) {
            return const ReviewEligibility(
              ReviewEligibilityKind.notYetEligible,
            );
          }
          return const ReviewEligibility(ReviewEligibilityKind.notEligible);
        case ReviewTargetKind.provider:
          final list = (await ref.watch(maintenanceRepositoryProvider).list())
              .where((b) => b.providerId == target.id)
              .toList();
          if (list.any((b) => b.status == MaintenanceStatus.completed)) {
            return const ReviewEligibility(ReviewEligibilityKind.eligible);
          }
          if (list.any((b) => b.isOpen)) {
            return const ReviewEligibility(
              ReviewEligibilityKind.notYetEligible,
            );
          }
          return const ReviewEligibility(ReviewEligibilityKind.notEligible);
        case ReviewTargetKind.seller:
          final list = (await ref.watch(viewingRepositoryProvider).list()).where((v) => v.host.id == target.id).toList();
          if (list.any((v) => v.status == ViewingStatus.completed)) {
            return const ReviewEligibility(ReviewEligibilityKind.eligible);
          }
          if (list.any((v) => v.isActive)) {
            return const ReviewEligibility(ReviewEligibilityKind.notYetEligible);
          }
          return const ReviewEligibility(ReviewEligibilityKind.notEligible);
      }
    });
