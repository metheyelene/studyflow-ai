import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyflow_mobile/features/notebooks/notebook.dart';

import 'helpers.dart';

/// In-memory file-picker platform: returns the given files when the app
/// opens the native picker, so the real Add Source flow (which calls
/// `FilePicker.pickFiles`) can be driven without the platform plugin.
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
  }) async =>
      files;
}

/// A picked file with in-memory bytes.
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
  await tester.tap(find.text('Notebooks'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cell Biology'));
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

  testWidgets('Sources tab shows a real empty state with a Paste text action', (
    tester,
  ) async {
    await pumpWithNotebook(tester);
    await openNotebookSourcesTab(tester);

    expect(find.text('No sources yet'), findsOneWidget);
    expect(find.text('Paste text'), findsOneWidget);
  });

  testWidgets('pasting a source adds it to the list for real', (tester) async {
    final fake = await pumpWithNotebook(tester);
    await openNotebookSourcesTab(tester);

    await tester.tap(find.text('Paste text'));
    await tester.pumpAndSettle();

    // Sheet: title + text.
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
    // The empty-state pane behind the modal also has an "Add source"
    // action, so scope the submit tap to the sheet itself.
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Add source'),
      ),
    );
    await tester.pumpAndSettle();

    expect(fake.sources, hasLength(1));
    expect(fake.sources.first.title, 'Lecture 4 — Photosynthesis');
    expect(find.text('Lecture 4 — Photosynthesis'), findsOneWidget);
    // Processing state label is honest about indexing.
    expect(find.text('Indexing'), findsOneWidget);
  });

  testWidgets('empty paste shows a validation error instead of submitting', (
    tester,
  ) async {
    await pumpWithNotebook(tester);
    await openNotebookSourcesTab(tester);

    await tester.tap(find.text('Paste text'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Add source'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Add a title and the text you want to study.'),
      findsOneWidget,
    );
  });

  testWidgets('removing a source confirms, deletes, and refreshes the list', (
    tester,
  ) async {
    final fake = await pumpWithNotebook(tester);
    await openNotebookSourcesTab(tester);

    // Add a real source first.
    await tester.tap(find.text('Paste text'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Lecture 4 — Photosynthesis');
    await tester.enterText(fields.at(1), 'Light energy is converted.');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Add source'),
      ),
    );
    await tester.pumpAndSettle();
    expect(fake.sources, hasLength(1));

    // Remove it — confirmation explains the indexed content leaves.
    await tester.tap(find.byTooltip('Remove source'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('and its indexed content will be removed'),
      findsOneWidget,
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(fake.sources, isEmpty);
    expect(find.text('No sources yet'), findsOneWidget);
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

    // Empty state → Add source → the sheet offers Upload files.
    expect(find.text('No sources yet'), findsOneWidget);
    await tester.tap(find.text('Add source'));
    await tester.pumpAndSettle();
    expect(find.text('Upload files'), findsOneWidget);

    // Picking a file runs the real picker abstraction and shows a tile.
    await tester.tap(find.text('Upload files'));
    await tester.pumpAndSettle();
    expect(find.text('VLSI_Unit_3.pdf'), findsOneWidget);
    expect(find.text('4.0 KB'), findsOneWidget);
    expect(find.text('Add 1 source'), findsOneWidget);

    // Uploading goes through the repository: the fake repo now owns the
    // source, and the pane reloads with the honest processing state.
    await tester.tap(find.text('Add 1 source'));
    await tester.pumpAndSettle();

    expect(fake.sources, hasLength(1));
    expect(fake.sources.first.title, 'VLSI_Unit_3.pdf');
    expect(fake.sources.first.kind, 'uploaded');
    expect(find.text('VLSI_Unit_3.pdf'), findsOneWidget);
    expect(find.text('Indexing'), findsOneWidget);
  });
}
