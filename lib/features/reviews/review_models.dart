/// Review rules (architecture v2.6 sections 27.10, 33): stars 1 to 5, comment 10 to 500 characters,
/// one review per reviewer per target, every new or edited review enters moderation and is public
/// only after an admin approves it. A later interaction lets the reviewer edit, not add.
const kReviewMinChars = 10;
const kReviewMaxChars = 500;

/// What a review is about: a professional company (confirmed engagement), a maintenance provider
/// (completed booking) or a seller who hosted a viewing (agent / Aqarati Broker).
enum ReviewTargetKind { professional, provider, seller }

class ReviewTarget {
  final ReviewTargetKind kind;
  final String id;
  final String name;
  const ReviewTarget({
    required this.kind,
    required this.id,
    required this.name,
  });

  @override
  bool operator ==(Object other) =>
      other is ReviewTarget && other.kind == kind && other.id == id;
  @override
  int get hashCode => Object.hash(kind, id);
}

/// pendingModeration -> published | rejected; published -> underReview (reported) -> published | removed.
enum ReviewStatus {
  pendingModeration,
  published,
  underReview,
  removed,
  rejected,
}

class MyReview {
  final String id;
  final ReviewTarget target;
  final int rating;
  final String comment;
  final ReviewStatus status;
  final DateTime createdAt;

  /// Whether the service lets the author edit this review (a later interaction exists).
  final bool canEdit;
  const MyReview({
    required this.id,
    required this.target,
    required this.rating,
    required this.comment,
    required this.status,
    required this.createdAt,
    this.canEdit = false,
  });

  MyReview copyWith({
    int? rating,
    String? comment,
    ReviewStatus? status,
    bool? canEdit,
  }) => MyReview(
    id: id,
    target: target,
    rating: rating ?? this.rating,
    comment: comment ?? this.comment,
    status: status ?? this.status,
    createdAt: createdAt,
    canEdit: canEdit ?? this.canEdit,
  );
}

enum ReviewEligibilityKind {
  eligible,
  alreadyReviewed,
  notYetEligible,
  windowExpired,
  notEligible,
  signedOut,
}

class ReviewEligibility {
  final ReviewEligibilityKind kind;
  final MyReview? existing;

  /// Last day a review can be written, when the rule has a window.
  final DateTime? windowEndsAt;
  const ReviewEligibility(this.kind, {this.existing, this.windowEndsAt});
}

/// Report reasons: the service has not published a closed list of report codes, so the reporter
/// explains in their own words (10-500 characters, the same bounds as a review comment).
String? reportReasonError(String text) => reviewCommentError(text);

/// 422 REVIEW_NOT_ELIGIBLE: no completed interaction.
class ReviewNotEligibleException implements Exception {
  const ReviewNotEligibleException();
}

/// One review per reviewer per target.
class ReviewAlreadyExistsException implements Exception {
  const ReviewAlreadyExistsException();
}

class ReviewNotEditableException implements Exception {
  const ReviewNotEditableException();
}

class ReviewAlreadyReportedException implements Exception {
  const ReviewAlreadyReportedException();
}

String? reviewCommentError(String text) {
  final n = text.trim().length;
  if (n < kReviewMinChars) return 'rv.err.short';
  if (n > kReviewMaxChars) return 'rv.err.long';
  return null;
}
