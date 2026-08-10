import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/networking/api_client.dart';
import 'notebook.dart';

class NotebooksException implements Exception {
  const NotebooksException(this.message);
  final String message;
}

abstract class NotebooksRepository {
  Future<List<Notebook>> list();
  Future<Notebook> create({required String title, String? description});
  Future<void> delete(String id);
}

/// Backend-backed implementation. The source of truth is the StudyFlow
/// API — no AI keys, no server logic in the app.
class ApiNotebooksRepository implements NotebooksRepository {
  ApiNotebooksRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Notebook>> list() async {
    final res = await _client.get<dynamic>('/api/notebooks');
    final data = res.data;
    final list = data is Map ? data['notebooks'] : null;
    if (list is! List) throw const NotebooksException('Could not load notebooks.');
    return [
      for (final n in list)
        if (n is Map) Notebook.fromJson(Map<String, dynamic>.from(n)),
    ];
  }

  @override
  Future<Notebook> create({required String title, String? description}) async {
    final res = await _client.post<dynamic>(
      '/api/notebooks',
      data: {'title': title, 'description': description},
    );
    final data = res.data;
    final nb = data is Map ? data['notebook'] : null;
    if (nb is! Map) throw const NotebooksException('Could not create the notebook.');
    return Notebook.fromJson(Map<String, dynamic>.from(nb));
  }

  @override
  Future<void> delete(String id) async {
    await _client.delete('/api/notebooks/$id');
  }
}

final notebooksRepositoryProvider = Provider<NotebooksRepository>(
  (ref) => ApiNotebooksRepository(ref.watch(apiClientProvider)),
);
