import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> enterEmailPassword(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextField).at(0), email);
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unauthenticated boot lands on the login screen', (tester) async {
    await pumpApp(tester, signedIn: false);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('successful login reaches the dashboard', (tester) async {
    final auth = await pumpApp(tester, signedIn: false);

    await enterEmailPassword(tester, 'student@example.com', 'password123');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(auth.signInCalls, 1);
    expect(auth.lastSignInEmail, 'student@example.com');
    expect(find.text('Ready to study?'), findsOneWidget);
  });

  testWidgets('failed login shows a friendly error and stays on login', (tester) async {
    await pumpApp(tester, signedIn: false);

    await enterEmailPassword(tester, 'fail@example.com', 'wrong');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('login links to signup; signing up reaches the dashboard', (tester) async {
    final auth = await pumpApp(tester, signedIn: false);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'New Student');
    await tester.enterText(find.byType(TextField).at(1), 'new@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(auth.signUpCalls, 1);
    expect(find.text('Ready to study?'), findsOneWidget);
  });

  testWidgets('signing out from the profile returns to login', (tester) async {
    final auth = await pumpApp(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
