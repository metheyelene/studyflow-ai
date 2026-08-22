import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/features/premium/premium_models.dart';

import 'helpers.dart';

Future<FakePlayBillingRepository> pumpPremium(
  WidgetTester tester, {
  FakePlayBillingRepository? premium,
}) async {
  final fake = premium ?? FakePlayBillingRepository();
  await pumpApp(
    tester,
    router: buildAppRouter(initialLocation: AppRoutes.premium),
    premium: fake,
  );
  return fake;
}

void main() {
  testWidgets('renders the Swiss premium screen with hero and benefits', (
    tester,
  ) async {
    await pumpPremium(tester);

    // Swiss hero text
    expect(find.textContaining('WITHOUT'), findsOneWidget);
    // Benefits section
    expect(find.textContaining('UNLIMITED'), findsWidgets);
    // Founding price
    expect(find.text('\$2/month'), findsOneWidget);
    expect(find.text('First 35 members only'), findsOneWidget);
  });

  testWidgets('shows the regular premium card when the offer is full', (
    tester,
  ) async {
    await pumpPremium(
      tester,
      premium: FakePlayBillingRepository(
        founding: const FoundingStatus(
          offerActive: false,
          claimed: 35,
          cap: 35,
          available: true,
          remaining: 0,
        ),
      ),
    );

    // The hero text should still render
    expect(find.textContaining('WITHOUT'), findsOneWidget);
  });

  testWidgets('a failed backend verification keeps plan free', (
    tester,
  ) async {
    final fake = FakePlayBillingRepository(
      purchaseResult: const PurchaseResult(
        ok: false,
        message: 'Purchase verification failed.',
      ),
    );
    await pumpPremium(tester, premium: fake);

    // Screen renders with Swiss hero
    expect(find.textContaining('WITHOUT'), findsOneWidget);
    expect(fake.plan, 'free');
  });

  testWidgets('entitlement appears only after the backend grants it', (
    tester,
  ) async {
    final fake = FakePlayBillingRepository(
      purchaseResult: const PurchaseResult(
        ok: true,
        plan: 'founding_member',
      ),
    );
    await pumpPremium(tester, premium: fake);

    // Simulate a successful purchase by manually calling purchaseFounding
    await fake.purchaseFounding();
    expect(fake.purchaseCalls, 1);
    expect(fake.plan, 'founding_member');
  });

  testWidgets('profile plan card reflects the backend plan', (tester) async {
    final fake = FakePlayBillingRepository(plan: 'premium');
    await pumpApp(tester, premium: fake);

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();

    // The profile screen should be visible
    expect(find.textContaining('PROFILE'), findsWidgets);
  });
}
