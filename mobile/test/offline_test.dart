import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/features/notebooks/notebook.dart';

import 'helpers.dart';

void main() {
  Future<void> openNotebooksTab(WidgetTester tester) async {
    await tester.tap(find.text('Notebooks'));
    await tester.pumpAndSettle();
  }

  FakeNotebooksRepository seededNotebooks() {
    final notebooks = FakeNotebooksRepository();
    notebooks.notebooks.add(
      Notebook(
        id: 'nb-1',
        title: 'VLSI Design',
        description: 'Electromagnetics and device physics',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    return notebooks;
  }

  /// The chat empty state anchors on the StudyFlow orb, which breathes
  /// forever while idle, so pumpAndSettle can't settle it. Tests that open
  /// the Ask AI tab run under the app's own reduced-motion contract —
  /// exactly how notebook_chat_test and ai_orb_test freeze the orb.
  void freezeOrbMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  group('offline banner', () {
    testWidgets(
      'appears on the shell when the network drops and clears on return',
      (tester) async {
        final connectivity = StreamController<List<ConnectivityResult>>();
        addTearDown(connectivity.close);
        await pumpApp(tester, connectivity: connectivity);

        // Optimistic: online on launch — no banner flash.
        expect(find.textContaining("You're offline"), findsNothing);

        connectivity.add([ConnectivityResult.none]);
        await tester.pumpAndSettle();
        expect(
          find.textContaining("You're offline — AI is paused"),
          findsOneWidget,
        );

        connectivity.add([ConnectivityResult.wifi]);
        await tester.pumpAndSettle();
        expect(find.textContaining("You're offline"), findsNothing);
      },
    );

    testWidgets('covers pushed routes, not just shell tabs', (tester) async {
      final connectivity = StreamController<List<ConnectivityResult>>();
      addTearDown(connectivity.close);
      await pumpApp(
        tester,
        notebooks: seededNotebooks(),
        connectivity: connectivity,
      );
      await openNotebooksTab(tester);
      await tester.tap(find.text('VLSI Design'));
      await tester.pumpAndSettle();

      // The notebook detail is a pushed route over the shell — the banner
      // must still show there (AppChrome wraps the whole Navigator).
      expect(find.textContaining("You're offline"), findsNothing);
      connectivity.add([ConnectivityResult.none]);
      await tester.pumpAndSettle();
      expect(
        find.textContaining("You're offline — AI is paused"),
        findsOneWidget,
      );
    });
  });

  group('offline AI gating', () {
    testWidgets(
      'workspace AI surfaces disable with honest copy while sources stay',
      (tester) async {
        final connectivity = StreamController<List<ConnectivityResult>>();
        addTearDown(connectivity.close);
        await pumpApp(
          tester,
          notebooks: seededNotebooks(),
          connectivity: connectivity,
        );
        await openNotebooksTab(tester);
        await tester.tap(find.text('VLSI Design'));
        await tester.pumpAndSettle();

        // Online: the hero CTA is live.
        expect(find.text('Ask StudyFlow'), findsOneWidget);

        connectivity.add([ConnectivityResult.none]);
        await tester.pumpAndSettle();

        // The CTA flips to the paused copy and is no longer tappable.
        expect(find.text('AI paused — offline'), findsOneWidget);
        expect(find.text('Ask StudyFlow'), findsNothing);

        // The chat tab explains the pause instead of pretending to work.
        freezeOrbMotion(tester);
        await tester.tap(find.text('Ask AI'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining("reconnect to ask StudyFlow"),
          findsOneWidget,
        );
      },
    );
  });
}
