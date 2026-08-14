import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/config/app_config.dart';
import 'package:studyflow_mobile/core/constants/app_info.dart';
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

  testWidgets('shows the Founder Dashboard card only to the founder email',
      (tester) async {
    await pumpApp(
      tester,
      router: buildAppRouter(initialLocation: AppRoutes.profile),
      auth: FakeAuthRepository(current: _founderUser),
    );

    expect(find.text('Founder Dashboard'), findsOneWidget);
    expect(find.text('Users, subscriptions, revenue'), findsOneWidget);
  });

  testWidgets('hides the Founder Dashboard card from other signed-in users',
      (tester) async {
    await pumpApp(
      tester,
      router: buildAppRouter(initialLocation: AppRoutes.profile),
    );

    expect(find.text('Founder Dashboard'), findsNothing);
  });

  testWidgets('tapping the card opens the web /admin dashboard',
      (tester) async {
    await pumpApp(
      tester,
      router: buildAppRouter(initialLocation: AppRoutes.profile),
      auth: FakeAuthRepository(current: _founderUser),
    );

    await tester.tap(find.text('Founder Dashboard'));
    await tester.pump();

    expect(launcher.launched, [Uri.parse('${AppConfig.webAppUrl}/admin').toString()]);
    // The founder identity constant matches the backend ADMIN_EMAILS gate.
    expect(AppInfo.founderEmail, 'mithilviswask@gmail.com');
  });
}
