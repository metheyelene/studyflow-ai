import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/networking/api_client.dart';
import 'notebook.dart';
import 'notebook_chat.dart';
import 'notebook_sources.dart';

class NotebooksException implements Exception {
  const NotebooksException(this.message);
  final String message;
}

abstract class NotebooksRepository {
  Future<List<Notebook>> list();
  Future<Notebook> create({required String title, String? description});
  Future<void> delete(String id);

  /// Ask the notebook's grounded AI. [history] is the prior conversation
  /// as (role, content) pairs, oldest first.
  Future<ChatReply> chat(
    String notebookId, {
    required String question,
    String mode = 'sources',
    List<ChatMessage> history = const [],
  });

  /// The notebook's sources, oldest first.
  Future<List<NotebookSource>> listSources(String notebookId);

  /// Add a pasted-text source; the backend indexes it for grounding.
  Future<NotebookSource> addPastedSource(
    String notebookId, {
    required String title,
    required String text,
  });
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

  @override
  Future<List<NotebookSource>> listSources(String notebookId) async {
    try {
      final res = await _client.get<dynamic>('/api/notebooks/$notebookId/sources');
      final data = res.data;
      final list = data is Map ? data['sources'] : null;
      if (list is! List) throw const NotebooksException('Could not load sources.');
      return [
        for (final s in list)
          if (s is Map) NotebookSource.fromJson(Map<String, dynamic>.from(s)),
      ];
    } on DioException {
      throw const NotebooksException('Could not load sources. Check your connection and try again.');
    }
  }

  @override
  Future<NotebookSource> addPastedSource(
    String notebookId, {
    required String title,
    required String text,
  }) async {
    try {
      final res = await _client.post<dynamic>(
        '/api/notebooks/$notebookId/sources',
        data: {'title': title, 'text': text},
      );
      final data = res.data;
      final source = data is Map ? data['source'] : null;
      if (source is! Map) {
        throw const NotebooksException('Could not add the source. Please try again.');
      }
      return NotebookSource.fromJson(Map<String, dynamic>.from(source));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final message = e.response?.data is Map
          ? (e.response!.data as Map)['error']
          : null;
      throw NotebooksException(switch (status) {
        400 || 422 => (message is String && message.isNotEmpty)
            ? message
            : 'Check the source text and try again.',
        403 => (message is String && message.isNotEmpty)
            ? message
            : "You've reached the source limit for your plan.",
        401 => 'Your session expired. Please log in again.',
        null => 'Could not reach the server. Check your connection and try again.',
        _ => 'Something went wrong. Please try again.',
      });
    }
  }

  @override
  Future<ChatReply> chat(
    String notebookId, {
    required String question,
    String mode = 'sources',
    List<ChatMessage> history = const [],
  }) async {
    try {
      final res = await _client.postPlain(
        '/api/notebooks/$notebookId/chat',
        data: {
          'question': question,
          'mode': mode,
          'history': [
            for (final m in history) {'role': m.isUser ? 'user' : 'assistant', 'content': m.content},
          ],
        },
      );
      final body = res.data;
      if (body is! String || body.isEmpty) {
        throw const NotebooksException('The AI returned an empty answer. Please try again.');
      }
      return parseChatReply(body);
    } on DioException catch (e) {
      throw NotebooksException(_friendlyChatError(e));
    }
  }

  String _friendlyChatError(DioException e) {
    final status = e.response?.statusCode;
    final message = e.response?.data is Map
        ? (e.response!.data as Map)['error']
        : null;
    return switch (status) {
      400 || 422 => (message is String && message.isNotEmpty)
          ? message
          : 'The AI could not answer that. Try rephrasing the question.',
      429 => (message is String && message.isNotEmpty)
          ? message
          : "You've used this month's free AI allowance. Upgrade for a higher limit.",
      401 => 'Your session expired. Please log in again.',
      null => 'Could not reach the server. Check your connection and try again.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}

final notebooksRepositoryProvider = Provider<NotebooksRepository>(
  (ref) => ApiNotebooksRepository(ref.watch(apiClientProvider)),
);
