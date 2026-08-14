import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'play_billing_repository.dart';
import 'premium_models.dart';

/// Snapshot of everything the Premium screen needs. `plan` and the
/// founding counts are backend-derived; `purchase` describes the last
/// purchase/restore attempt (the granted plan comes from the backend
/// verification response, never from the local store callback).
class PremiumSnapshot {
  const PremiumSnapshot({
    required this.plan,
    required this.founding,
    required this.priceLabel,
    required this.playSupported,
  });

  final String plan; // "free" | "premium" | "founding_member"
  final FoundingStatus founding;
  final String? priceLabel;
  final bool playSupported;

  bool get isPremium => plan != 'free';

  PremiumSnapshot copyWith({
    String? plan,
    FoundingStatus? founding,
    String? priceLabel,
    bool? playSupported,
  }) {
    return PremiumSnapshot(
      plan: plan ?? this.plan,
      founding: founding ?? this.founding,
      priceLabel: priceLabel ?? this.priceLabel,
      playSupported: playSupported ?? this.playSupported,
    );
  }
}

class PremiumController extends AsyncNotifier<PremiumSnapshot> {
  @override
  Future<PremiumSnapshot> build() async {
    final repo = ref.watch(playBillingRepositoryProvider);
    final results = await Future.wait<Object?>([
      repo.currentPlan(),
      repo.foundingStatus(),
      repo.foundingPriceLabel(),
    ]);
    return PremiumSnapshot(
      plan: results[0] as String,
      founding: results[1] as FoundingStatus,
      priceLabel: results[2] as String?,
      playSupported: repo.playBillingSupported,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  /// The purchase flow. Entitlement only changes when the backend
  /// verification returns a granted plan — the local purchase callback
  /// alone can never unlock anything. The resulting plan is reflected in
  /// [PremiumSnapshot.plan] only after verification succeeded.
  Future<PurchaseResult> purchaseFounding() async {
    final repo = ref.read(playBillingRepositoryProvider);
    final result = await repo.purchaseFounding();
    if (result.ok) {
      await refresh();
    }
    return result;
  }

  /// Restore purchases. Only backend-attributed plans are re-granted.
  Future<List<String>> restorePurchases() async {
    final repo = ref.read(playBillingRepositoryProvider);
    final granted = await repo.restorePurchases();
    if (granted.isNotEmpty) {
      await refresh();
    }
    return granted;
  }

  /// Web: start the Stripe checkout and return the hosted URL.
  Future<String> webCheckoutUrl() async {
    return ref.read(playBillingRepositoryProvider).webCheckoutUrl();
  }
}

final premiumControllerProvider =
    AsyncNotifierProvider<PremiumController, PremiumSnapshot>(
      PremiumController.new,
    );
