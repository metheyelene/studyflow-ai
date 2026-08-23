import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/features/notebooks/notebook.dart';
import 'package:studyflow_mobile/shared/widgets/swiss/swiss_components.dart';

import 'helpers.dart';

class FakeFilePickerPlatform extends FilePickerPlatform {
  FakeFilePickerPlatform(this.files);
  final List<PlatformFile> files;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => files;
}

final class FakePlatformFile extends PlatformFile {
  FakePlatformFile(this.fileName, this.data);
  final String fileName;
  final Uint8List data;

  @override
  String get name => fileName;
  @override
  Uri get uri => Uri.dataFromBytes(data);
  @override
  XFile get xFile => XFile.fromData(data, name: fileName);
  @override
  Future<int> length() async => data.length;
  @override
  Future<Uint8List> readAsBytes() async => data;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(data);
}

Future<void> openNotebookSourcesTab(WidgetTester tester) async {
  await tester.tap(find.text('NOTEBOOKS'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CELL BIOLOGY'));
  await tester.pumpAndSettle();
}

/// Opens the AddSourceSheet and taps PASTE TEXT, returning to the paste sheet.
Future<void> openPasteSheet(WidgetTester tester) async {
  await tester.ensureVisible(find.text('ADD SOURCE'));
  await tester.tap(find.text('ADD SOURCE'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('PASTE TEXT'));
  await tester.tap(find.text('PASTE TEXT'));
  await tester.pumpAndSettle();
}

/// Taps the submit button in the paste sheet.
/// Directly invokes onPressed since bottom sheet overlay layers absorb taps.
Future<void> submitPasteSheet(WidgetTester tester) async {
  // Find the SwissButton whose label starts with 'Add source' in the bottom sheet
  final sheetBtn = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byWidgetPredicate(
      (w) =>
          w is SwissButton &&
          w.label.contains('Add source') &&
          w.onPressed != null,
    ),
  );
  expect(sheetBtn, findsOneWidget);
  final btn = tester.widget<SwissButton>(sheetBtn);
  btn.onPressed!();
  await tester.pumpAndSettle();
}

void main() {
  Future<FakeNotebooksRepository> pumpWithNotebook(WidgetTester tester) async {
    final fake = FakeNotebooksRepository();
    fake.notebooks.add(
      Notebook(
        id: 'nb-1',
        title: 'Cell Biology',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await pumpApp(tester, notebooks: fake);
    return fake;
  }

  testWidgets(
    'Sources tab shows a real empty state with an Add source action',
    (tester) async {
      await pumpWithNotebook(tester);
      await openNotebookSourcesTab(tester);

      expect(find.text('NO SOURCES YET'), findsOneWidget);
      expect(find.text('ADD SOURCE'), findsOneWidget);
    },
  );

  testWidgets('pasting a source adds it to the list for real', (tester) async {
    final fake = await pumpWithNotebook(tester);
    await openNotebookSourcesTab(tester);

    await openPasteSheet(tester);

    final fields = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Lecture 4 — Photosynthesis');
    await tester.enterText(
      fields.at(1),
      'Photosynthesis converts light energy into chemical energy.',
    );
    await tester.pumpAndSettle();

    await submitPasteSheet(tester);

    expect(fake.sources, hasLength(1));
    expect(fake.sources.first.title, 'Lecture 4 — Photosynthesis');
    expect(find.text('LECTURE 4 — PHOTOSYNTHESIS'), findsOneWidget);
  });

  testWidgets('empty paste shows a validation error instead of submitting', (
    tester,
  ) async {
    await pumpWithNotebook(tester);
    await openNotebookSourcesTab(tester);

    await openPasteSheet(tester);
    await submitPasteSheet(tester);

    expect(find.textContaining('ADD A TITLE AND THE TEXT'), findsOneWidget);
  });

  testWidgets('removing a source confirms, deletes, and refreshes the list', (
    tester,
  ) async {
    final fake = await pumpWithNotebook(tester);
    await openNotebookSourcesTab(tester);

    // Add a source
    await openPasteSheet(tester);
    final fields = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Lecture 4 — Photosynthesis');
    await tester.enterText(fields.at(1), 'Light energy is converted.');
    await tester.pumpAndSettle();
    await submitPasteSheet(tester);
    expect(fake.sources, hasLength(1));

    // Remove it
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('and its indexed content will be removed'),
      findsOneWidget,
    );
    await tester.tap(find.text('REMOVE'));
    await tester.pumpAndSettle();

    expect(fake.sources, isEmpty);
    expect(find.text('NO SOURCES YET'), findsOneWidget);
  });

  testWidgets('Add Source sheet uploads through the repository for real', (
    tester,
  ) async {
    final fake = FakeNotebooksRepository();
    fake.notebooks.add(
      Notebook(
        id: 'nb-1',
        title: 'Cell Biology',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    final original = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = original);
    FilePickerPlatform.instance = FakeFilePickerPlatform([
      FakePlatformFile(
        'VLSI_Unit_3.pdf',
        Uint8List.fromList(List.filled(4096, 1)),
      ),
    ]);

    await pumpApp(tester, notebooks: fake);
    await openNotebookSourcesTab(tester);

    expect(find.text('NO SOURCES YET'), findsOneWidget);
    await tester.ensureVisible(find.text('ADD SOURCE'));
    await tester.tap(find.text('ADD SOURCE'));
    await tester.pumpAndSettle();
    expect(find.text('UPLOAD FILES'), findsOneWidget);

    await tester.ensureVisible(find.text('UPLOAD FILES'));
    await tester.tap(find.text('UPLOAD FILES'));
    await tester.pumpAndSettle();
    expect(find.text('VLSI_UNIT_3.PDF'), findsOneWidget);
    expect(find.text('4.0 KB'), findsOneWidget);

    // Tap the add sources button directly via onPressed
    final addBtn = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byWidgetPredicate(
        (w) =>
            w is SwissButton && w.label.contains('Add') && w.onPressed != null,
      ),
    );
    expect(addBtn, findsOneWidget);
    final btn = tester.widget<SwissButton>(addBtn);
    btn.onPressed!();
    await tester.pumpAndSettle();

    expect(fake.sources, hasLength(1));
    expect(fake.sources.first.title, 'VLSI_Unit_3.pdf');
    expect(fake.sources.first.kind, 'uploaded');
    expect(find.text('VLSI_UNIT_3.PDF'), findsOneWidget);
  });
}
