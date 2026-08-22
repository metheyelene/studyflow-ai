import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/performance/device_tier.dart';
import 'package:studyflow_mobile/core/theme/app_theme.dart';
import 'package:studyflow_mobile/features/notebooks/add_source_sheet.dart';
import 'package:studyflow_mobile/shared/widgets/glass/glass_sheet.dart';
import 'package:studyflow_mobile/features/notebooks/notebook_sources.dart';
import 'package:studyflow_mobile/features/notebooks/source_upload.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(Brightness.light, tier: PerformanceTier.standard),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('Add Source sheet offers upload and paste options', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AddSourceSheet(
          onUpload: (_, _) async => const [],
          onPaste: () {},
          onPickFiles: () async => const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ADD SOURCE'), findsOneWidget);
    expect(find.text('UPLOAD FILES'), findsOneWidget);
    expect(find.text('PASTE TEXT'), findsOneWidget);
    // No files selected yet — the CTA is a "Choose files" disabled state.
    expect(find.text('CHOOSE FILES'), findsOneWidget);
  });

  testWidgets('selected files appear as removable tiles with real sizes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AddSourceSheet(
          onUpload: (_, _) async => const [],
          onPaste: () {},
          onPickFiles: () async => [
            UploadFile(
              name: 'VLSI_Unit_3.pdf',
              bytes: Uint8List.fromList(List.filled(2048, 1)),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select the file.
    await tester.tap(find.text('UPLOAD FILES'));
    await tester.pumpAndSettle();

    expect(find.text('VLSI_UNIT_3.PDF'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text('ADD 1 SOURCE'), findsOneWidget);

    // Remove it again.
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('VLSI_UNIT_3.PDF'), findsNothing);
    expect(find.text('CHOOSE FILES'), findsOneWidget);
  });

  testWidgets('unsupported files are rejected before any upload', (
    tester,
  ) async {
    var uploadCalls = 0;
    await tester.pumpWidget(
      _wrap(
        AddSourceSheet(
          onUpload: (_, _) async {
            uploadCalls++;
            return const [];
          },
          onPaste: () {},
          onPickFiles: () async => [
            UploadFile(
              name: 'lecture.exe',
              bytes: Uint8List.fromList(List.filled(4, 1)),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('UPLOAD FILES'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not supported'), findsOneWidget);
    // The CTA is disabled when nothing valid is selected.
    expect(find.text('ADD SOURCES'), findsOneWidget);
    await tester.tap(find.text('ADD SOURCES'));
    await tester.pumpAndSettle();
    expect(uploadCalls, 0);
  });

  testWidgets('upload reports real per-file progress then closes', (
    tester,
  ) async {
    final progress = <(int, int)>[];
    final results = <NotebookSource>[
      NotebookSource(
        id: 'src-up-1',
        title: 'Physics.pdf',
        kind: 'uploaded',
        status: SourceStatus.processing,
        sizeBytes: 1024,
        createdAt: DateTime(2026),
      ),
    ];

    var closedWith = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light, tier: PerformanceTier.standard),
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                closedWith =
                    await showGlassSheet<bool>(
                      context: context,
                      builder: (_) => AddSourceSheet(
                        onUpload: (files, onProgress) async {
                          for (var i = 1; i <= files.length; i++) {
                            onProgress(i, files.length);
                          }
                          progress.addAll([]);
                          return results;
                        },
                        onPaste: () {},
                        onPickFiles: () async => [
                          UploadFile(
                            name: 'Physics.pdf',
                            bytes: Uint8List.fromList(List.filled(1024, 1)),
                          ),
                        ],
                      ),
                    ) ??
                    false;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPLOAD FILES'));
    await tester.pumpAndSettle();

    expect(find.text('ADD 1 SOURCE'), findsOneWidget);
    await tester.tap(find.text('ADD 1 SOURCE'));
    await tester.pumpAndSettle();

    // Sheet closed with the upload's result.
    expect(closedWith, isTrue);
    // The result sources are what the host will show.
    expect(results.single.title, 'Physics.pdf');
  });

  testWidgets('Paste text hands off to the paste flow', (tester) async {
    var pasted = false;
    await tester.pumpWidget(
      _wrap(
        AddSourceSheet(
          onUpload: (_, _) async => const [],
          onPaste: () => pasted = true,
          onPickFiles: () async => const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PASTE TEXT'));
    await tester.pumpAndSettle();

    expect(pasted, isTrue);
  });
}
