import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyflow_mobile/core/routing/app_router.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/features/notebooks/notebooks_controller.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, GoRouter router) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildAppTheme(Brightness.light),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openNotebooksTab(WidgetTester tester) async {
    await tester.tap(find.text('Notebooks'));
    await tester.pumpAndSettle();
  }

  Future<void> createNotebook(WidgetTester tester, String name) async {
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)),
      name,
    );
    await tester.tap(find.text('Create notebook'));
    await tester.pumpAndSettle();
  }

  testWidgets('empty state → create notebook → card appears with search',
      (tester) async {
    final router = buildAppRouter();
    await pumpApp(tester, router);
    await openNotebooksTab(tester);

    expect(find.text('No notebooks yet'), findsOneWidget);

    await createNotebook(tester, 'Cell Biology — Unit 3');
    expect(find.text('Cell Biology — Unit 3'), findsOneWidget);
    expect(find.text('0 sources · updated just now'), findsOneWidget);

    // Search filters the local list.
    await tester.enterText(find.byType(TextField), 'Physics');
    await tester.pumpAndSettle();
    expect(find.text('No matching notebooks'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'cell');
    await tester.pumpAndSettle();
    expect(find.text('Cell Biology — Unit 3'), findsOneWidget);
  });

  testWidgets('opening a notebook on phone shows the detail and back returns',
      (tester) async {
    final router = buildAppRouter();
    await pumpApp(tester, router);
    await openNotebooksTab(tester);
    await createNotebook(tester, 'VLSI Design');

    await tester.tap(find.text('VLSI Design'));
    await tester.pumpAndSettle();

    // Detail workspace: tabs + honest empty states.
    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('Ask AI'), findsOneWidget);
    expect(find.text('Study tools'), findsOneWidget);
    expect(find.text('No sources yet'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('No notebooks yet'), findsNothing);
    expect(find.text('VLSI Design'), findsOneWidget);
  });

  testWidgets('tablet/desktop shows master-detail: list + detail panes',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = buildAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildAppTheme(Brightness.light),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await openNotebooksTab(tester);
    expect(find.text('Select a notebook'), findsOneWidget);

    await createNotebook(tester, 'Thermodynamics');
    expect(find.text('Select a notebook'), findsOneWidget); // still nothing selected

    await tester.tap(find.text('Thermodynamics'));
    await tester.pumpAndSettle();

    expect(find.text('Select a notebook'), findsNothing);
    expect(find.text('No sources yet'), findsOneWidget);
    // Both panes are visible at once on wide screens.
    expect(find.text('Thermodynamics'), findsNWidgets(2)); // list card + detail header
  });

  test('notebooks controller creates, renames, and deletes locally', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(notebooksProvider.notifier);

    notifier.create('  Cell Biology  ');
    var list = container.read(notebooksProvider);
    expect(list.single.title, 'Cell Biology');

    final id = list.single.id;
    notifier.rename(id, 'Biology II');
    expect(container.read(notebooksProvider).single.title, 'Biology II');

    notifier.delete(id);
    expect(container.read(notebooksProvider), isEmpty);
  });
}
