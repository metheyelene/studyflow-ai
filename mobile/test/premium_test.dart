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
  testWidgets('renders the founding offer with backend count and Play price', (
    tester,
  ) async {
    await pumpPremium(tester);

    expect(find.text('STUDYFLOW PREMIUM'), findsOneWidget);
    expect(find.text('\$2'), findsOneWidget);
    expect(find.text('/ month'), findsOneWidget);
    // The remaining count comes from the backend, never hard-coded.
    expect(find.text('23 of 35 left'), findsOneWidget);
    expect(find.text('Advanced AI Study Tutor'), findsOneWidget);
    expect(find.text('Restore Purchases'), findsOneWidget);
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

    expect(find.text('THE FOUNDING OFFER IS COMPLETE'), findsOneWidget);
    expect(find.text('23 of 35 left'), findsNothing);
  });

  testWidgets('a failed backend verification never unlocks premium', (
    tester,
  ) async {
    final fake = FakePlayBillingRepository(
      purchaseResult: const PurchaseResult(
        ok: false,
        message: 'We could not verify this purchase. Please try again.',
      ),
    );
    await pumpPremium(tester, premium: fake);

    // Start free.
    expect(find.text('YOUR PLAN'), findsOneWidget);
    expect(find.text('Free'), findsWidgets);

    await tester.ensureVisible(find.text('Subscribe — Founding Member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subscribe — Founding Member'));
    await tester.pumpAndSettle();

    // Failure surfaced, plan untouched.
    expect(
      find.text('We could not verify this purchase. Please try again.'),
      findsOneWidget,
    );
    expect(fake.purchaseCalls, 1);
    expect(find.text('Free'), findsWidgets);
    // No entitlement granted: the offer badge is static UI, but there is no
    // 'Active' entitlement badge and the plan stays Free.
    expect(find.text('Active'), findsNothing);
  });

  testWidgets('entitlement appears only after the backend grants it', (
    tester,
  ) async {
    final fake = FakePlayBillingRepository(
      purchaseResult: const PurchaseResult(
        ok: true,
        plan: 'founding_member',
        message: 'Welcome to StudyFlow Premium.',
      ),
    );
    await pumpPremium(tester, premium: fake);

    await tester.ensureVisible(find.text('Subscribe — Founding Member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subscribe — Founding Member'));
    await tester.pumpAndSettle();

    expect(fake.purchaseCalls, 1);
    expect(find.text('Welcome to StudyFlow Premium.'), findsOneWidget);
    // The plan now reflects the backend-granted entitlement.
    expect(find.text('Founding Member'), findsWidgets);
  });

  testWidgets('restore reports backend-attributed plans', (tester) async {
    final fake = FakePlayBillingRepository(
      restoredPlans: const ['founding_member'],
    );
    await pumpPremium(tester, premium: fake);

    await tester.ensureVisible(find.text('Restore Purchases'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore Purchases'));
    await tester.pumpAndSettle();

    expect(fake.restoreCalls, 1);
    expect(find.text('Restored: Founding Member.'), findsOneWidget);
  });

  testWidgets('profile plan card reflects the backend plan and opens premium', (
    tester,
  ) async {
    final fake = FakePlayBillingRepository(plan: 'premium');
    await pumpApp(tester, premium: fake);

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();

    // Real plan from the backend, not a placeholder.
    expect(find.text('PREMIUM'), findsWidgets);

    await tester.tap(find.text('STUDYFLOW PREMIUM'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR PLAN'), findsOneWidget);
  });
}
