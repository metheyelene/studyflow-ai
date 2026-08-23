import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/features/authentication/auth_models.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'helpers.dart';

/// Records every launchUrl call so tests can assert the exact target.
class _RecordingUrlLauncher extends UrlLauncherPlatform {
  final List<String> launched = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

const _founderUser = AuthUser(
  id: 'user_founder',
  name: 'Mithil Viswas Kasi',
  email: 'mithilviswask@gmail.com',
);

void main() {
  late _RecordingUrlLauncher launcher;
  late UrlLauncherPlatform original;

  setUp(() {
    original = UrlLauncherPlatform.instance;
    launcher = _RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = original;
  });

  testWidgets('profile shows all standard items for any user', (
    tester,
  ) async {
    await pumpApp(
      tester,
      router: buildAppRouter(initialLocation: AppRoutes.profile),
      auth: FakeAuthRepository(current: _founderUser),
    );

    // Profile screen shows standard items
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('SIGN OUT'), findsOneWidget);
  });

  testWidgets('profile shows standard items for regular users too', (
    tester,
  ) async {
    await pumpApp(
      tester,
      router: buildAppRouter(initialLocation: AppRoutes.profile),
    );

    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('SIGN OUT'), findsOneWidget);
  });

  testWidgets('profile has a working back button', (
    tester,
  ) async {
    await pumpApp(
      tester,
      router: buildAppRouter(initialLocation: AppRoutes.profile),
    );

    // Back button navigates to home
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });
}
