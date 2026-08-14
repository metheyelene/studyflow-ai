/// Premium / founding-member models and constants.
///
/// All counts and the offer state come from the backend
/// (GET /api/billing/founding-status) — the app never hard-codes the
/// remaining slot count or decides entitlement locally.
library;

/// Play subscription product configured in Play Console (product id).
const String kFoundingProductId = 'founding_member_monthly';

/// Android application id (must match the Play listing + Gradle).
const String kPlayPackageName = 'ai.studyflow.studyflow_mobile';

/// The founding offer as reported by the backend.
class FoundingStatus {
  const FoundingStatus({
    required this.offerActive,
    required this.claimed,
    required this.cap,
    required this.available,
    this.remaining,
  });

  factory FoundingStatus.fromJson(Map<String, dynamic> json) {
    final offer = json['offer'] is Map
        ? json['offer'] as Map
        : const <String, dynamic>{};
    final status = json['status'] is Map
        ? json['status'] as Map
        : const <String, dynamic>{};
    final available = status['available'] as bool? ?? false;
    return FoundingStatus(
      offerActive: offer['active'] as bool? ?? false,
      claimed: (status['claimed'] as num?)?.toInt() ?? 0,
      cap: (status['cap'] as num?)?.toInt() ?? 35,
      available: available,
      // Only present when the backend could actually read the counter.
      remaining: available ? (offer['remaining'] as num?)?.toInt() : null,
    );
  }

  /// True when the user may still claim the founding offer.
  final bool offerActive;

  final int claimed;
  final int cap;

  /// False when the counter could not be read (DB outage) — the UI must
  /// not display a count it cannot source from the backend.
  final bool available;

  final int? remaining;
}

/// Result of a purchase attempt. The granted plan is ONLY ever set from
/// the backend verification response — never from the local purchase
/// callback.
class PurchaseResult {
  const PurchaseResult({required this.ok, this.plan, this.message});

  final bool ok;
  final String? plan;
  final String? message;
}

/// Thrown when the user cancels or the purchase fails before completing.
class PurchaseFlowException implements Exception {
  const PurchaseFlowException(this.message);
  final String message;
}
