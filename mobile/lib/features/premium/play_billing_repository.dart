import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/networking/api_client.dart';
import 'premium_models.dart';

/// Gateway to the subscription backend.
///
/// Security contract (mirrors src/lib/playBilling.ts on the server):
///  - Prices come from Play's product details (the store's source of
///    truth); the backend never trusts a client price.
///  - A purchase is NEVER unlocked locally. [purchaseFounding] sends the
///    Play purchase token to POST /api/billing/play/verify and only the
///    backend's response (the granted plan) updates entitlement.
///  - No provider or payment secrets exist in the app.
abstract class PlayBillingRepository {
  /// True when Google Play Billing is the payment path on this platform
  /// (Android only — iOS uses StoreKit later, web uses Stripe checkout).
  bool get playBillingSupported;

  /// GET /api/billing/founding-status — offer state + remaining slots,
  /// always backend-derived.
  Future<FoundingStatus> foundingStatus();

  /// GET /api/usage — the user's current plan ("free" | "premium" |
  /// "founding_member"). The backend is the source of truth.
  Future<String> currentPlan();

  /// The founding product's price from Play's product details, or null
  /// when unavailable (non-Android, store not reachable, or the product
  /// is not published yet).
  Future<String?> foundingPriceLabel();

  /// Full Android purchase flow: buy the founding subscription, then
  /// verify the purchase token against the backend. The returned plan is
  /// the backend's, never the local callback's.
  Future<PurchaseResult> purchaseFounding();

  /// Re-verify previously purchased/restored tokens against the backend.
  /// Returns the granted plans for purchases this backend attributed.
  Future<List<String>> restorePurchases();

  /// Web: starts the Stripe checkout and returns the hosted URL.
  Future<String> webCheckoutUrl();
}

class ApiPlayBillingRepository implements PlayBillingRepository {
  ApiPlayBillingRepository(this._client, {InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  final ApiClient _client;
  final InAppPurchase _store;

  @override
  bool get playBillingSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<FoundingStatus> foundingStatus() async {
    final res = await _client.get<dynamic>('/api/billing/founding-status');
    final data = res.data;
    if (data is! Map) {
      throw const BillingException('Could not load the founding offer.');
    }
    return FoundingStatus.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<String> currentPlan() async {
    final res = await _client.get<dynamic>('/api/usage');
    final data = res.data;
    if (data is! Map) return 'free';
    return data['plan'] as String? ?? 'free';
  }

  @override
  Future<String?> foundingPriceLabel() async {
    if (!playBillingSupported) return null;
    try {
      final details = await _store.queryProductDetails(
        const {kFoundingProductId},
      );
      for (final p in details.productDetails) {
        if (p.id == kFoundingProductId && p.price.isNotEmpty) return p.price;
      }
    } catch (_) {
      // Store not reachable / not published — the UI shows an honest
      // state instead of a fabricated price.
    }
    return null;
  }

  @override
  Future<PurchaseResult> purchaseFounding() async {
    if (!playBillingSupported) {
      return const PurchaseResult(
        ok: false,
        message: 'Subscriptions are available in the Android app.',
      );
    }
    try {
      final price = await foundingPriceLabel();
      final details = await _store.queryProductDetails(
        const {kFoundingProductId},
      );
      final product = details.productDetails
          .where((p) => p.id == kFoundingProductId)
          .firstOrNull;
      if (product == null) {
        return const PurchaseResult(
          ok: false,
          message: 'The founding subscription is not available yet.',
        );
      }

      // Subscribe to the purchase stream BEFORE starting the purchase so
      // the completion event cannot be missed.
      final completion = _awaitPurchaseOutcome();
      await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      final purchase = await completion;

      final token = purchase.verificationData.serverVerificationData;
      if (token.isEmpty) {
        return const PurchaseResult(ok: false, message: 'Purchase token missing.');
      }
      return await _verifyToken(token, price: price);
    } on PurchaseFlowException catch (e) {
      return PurchaseResult(ok: false, message: e.message);
    } catch (_) {
      return const PurchaseResult(
        ok: false,
        message: "StudyFlow couldn't complete that purchase.",
      );
    }
  }

  @override
  Future<List<String>> restorePurchases() async {
    if (!playBillingSupported) return const [];
    try {
      final restored = await _awaitRestoreOutcome();
      final granted = <String>[];
      for (final purchase in restored) {
        final token = purchase.verificationData.serverVerificationData;
        if (token.isEmpty) continue;
        final result = await _verifyToken(token);
        if (result.ok && result.plan != null) granted.add(result.plan!);
      }
      return granted;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<String> webCheckoutUrl() async {
    final res = await _client.post<dynamic>('/api/billing/checkout');
    final data = res.data;
    if (data is! Map || data['url'] is! String) {
      throw const BillingException('Checkout is not available right now.');
    }
    return data['url'] as String;
  }

  /// Sends the token to the backend for verification. This is the ONLY
  /// place entitlement is granted — the response's plan is authoritative.
  Future<PurchaseResult> _verifyToken(String token, {String? price}) async {
    try {
      final res = await _client.post<dynamic>('/api/billing/play/verify', data: {
        'packageName': kPlayPackageName,
        'productId': kFoundingProductId,
        'purchaseToken': token,
      });
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : const <String, dynamic>{};
      if (res.statusCode == 200 && data['ok'] == true) {
        return PurchaseResult(
          ok: true,
          plan: data['plan'] as String? ?? 'premium',
          message: price != null ? 'Welcome to StudyFlow Premium — $price/mo.' : null,
        );
      }
      final message = switch (res.statusCode) {
        409 => 'The founding offer is full — you can subscribe to Premium instead.',
        503 => 'Billing is being set up — please try again later.',
        _ => 'We could not verify this purchase. Please try again.',
      };
      return PurchaseResult(ok: false, message: message);
    } on BillingException {
      return const PurchaseResult(ok: false, message: 'Please check your connection and try again.');
    }
  }

  /// Completes with the first purchased/restored details for the founding
  /// product, or fails fast on cancel/error. The stream delivers batches
  /// (`Stream<List<PurchaseDetails>>`), so each event is unpacked.
  Future<PurchaseDetails> _awaitPurchaseOutcome() {
    final completer = Completer<PurchaseDetails>();
    late final StreamSubscription<List<PurchaseDetails>> sub;
    sub = _store.purchaseStream.listen((batch) {
      for (final details in batch) {
        if (details.productID != kFoundingProductId) continue;
        switch (details.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            if (!completer.isCompleted) {
              completer.complete(details);
              sub.cancel();
            }
          case PurchaseStatus.canceled:
          case PurchaseStatus.error:
            if (!completer.isCompleted) {
              completer.completeError(
                const PurchaseFlowException('Purchase cancelled.'),
              );
              sub.cancel();
            }
          case PurchaseStatus.pending:
            break; // Wait for the terminal state.
        }
      }
    });
    return completer.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => throw const PurchaseFlowException(
        'The purchase took too long. Please try again.',
      ),
    );
  }

  /// Completes after restorePurchases() with all matching restored
  /// details (restore events are also delivered on purchaseStream).
  Future<List<PurchaseDetails>> _awaitRestoreOutcome() {
    final completer = Completer<List<PurchaseDetails>>();
    final collected = <PurchaseDetails>[];
    late final StreamSubscription<List<PurchaseDetails>> sub;
    sub = _store.purchaseStream.listen((batch) {
      for (final details in batch) {
        if (details.productID != kFoundingProductId) continue;
        if (details.status == PurchaseStatus.restored ||
            details.status == PurchaseStatus.purchased) {
          collected.add(details);
        }
      }
    });
    return _store.restorePurchases().then((_) async {
      // Give the platform a moment to deliver restore events.
      await Future<void>.delayed(const Duration(seconds: 1));
      await sub.cancel();
      completer.complete(collected);
      return completer.future;
    }).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw const PurchaseFlowException('Restore timed out.'),
    );
  }
}

class BillingException implements Exception {
  const BillingException(this.message);
  final String message;
}

final playBillingRepositoryProvider = Provider<PlayBillingRepository>(
  (ref) => ApiPlayBillingRepository(ref.watch(apiClientProvider)),
);
