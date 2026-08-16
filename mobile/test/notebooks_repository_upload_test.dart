import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/core/networking/api_client.dart';
import 'package:studyflow_mobile/features/notebooks/notebook_sources.dart';
import 'package:studyflow_mobile/features/notebooks/notebooks_repository.dart';
import 'package:studyflow_mobile/features/notebooks/source_upload.dart';

/// Records every request and answers with the given per-request responses.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._responder);

  final ResponseBody Function(int index) _responder;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _responder(requests.length - 1);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  late _RecordingAdapter adapter;
  late ApiNotebooksRepository repo;

  setUp(() {
    adapter = _RecordingAdapter(
      (i) => _json({
        'source': {
          'id': 'src-$i',
          'title': 'Physics.pdf',
          'kind': 'uploaded',
          'status': 'processing',
          'wordCount': 12,
          'createdAt': '2026-08-15T00:00:00.000Z',
        },
      }),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    repo = ApiNotebooksRepository(ApiClient.test(dio));
  });

  UploadFile file(String name, int size) => UploadFile(
        name: name,
        bytes: Uint8List.fromList(List.filled(size, 1)),
      );

  test('uploads each file as its own multipart request with the file field',
      () async {
    final result = await repo.uploadFiles('nb-1', files: [
      file('Physics.pdf', 2048),
      file('Notes.md', 512),
    ]);

    expect(adapter.requests, hasLength(2));
    expect(result, hasLength(2));

    for (var i = 0; i < 2; i++) {
      final req = adapter.requests[i];
      expect(req.method, 'POST');
      expect(req.path, '/api/notebooks/nb-1/sources');

      final form = req.data as FormData;
      expect(form.files, hasLength(1));
      expect(form.files.single.key, 'file');
      expect(
        form.files.single.value.filename,
        i == 0 ? 'Physics.pdf' : 'Notes.md',
      );
    }

    // The parsed sources come from the server's { source } shape.
    expect(result.first.id, 'src-0');
    expect(result.first.title, 'Physics.pdf');
    expect(result.first.status, SourceStatus.processing);
  });

  test('onProgress advances only after each server-confirmed upload', () async {
    final progress = <(int, int)>[];
    await repo.uploadFiles(
      'nb-1',
      files: [file('A.pdf', 4), file('B.txt', 4), file('C.md', 4)],
      onProgress: (done, total) => progress.add((done, total)),
    );

    expect(progress, [(1, 3), (2, 3), (3, 3)]);
  });

  test('maps the backend error message for a rejected file', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = _RecordingAdapter(
        (_) => _json({'error': 'File is 30.0 MB — the limit is 25 MB.'},
            status: 422),
      );
    repo = ApiNotebooksRepository(ApiClient.test(dio));

    await expectLater(
      repo.uploadFiles('nb-1', files: [file('Big.pdf', 4)]),
      throwsA(
        isA<NotebooksException>().having(
          (e) => e.message,
          'message',
          contains('25 MB'),
        ),
      ),
    );
  });
}
