import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notebook.dart';
import 'notebook_chat.dart';
import 'notebooks_repository.dart';

/// Backend-backed notebook state: loads on first watch, and create/delete
/// update the list from the server's response. Loading and error states
/// are first-class (the list UI renders skeletons / a retry card).
class NotebooksController extends AsyncNotifier<List<Notebook>> {
  @override
  Future<List<Notebook>> build() {
    return ref.watch(notebooksRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(notebooksRepositoryProvider).list(),
    );
  }

  /// Returns a friendly error string, or null on success.
  Future<String?> create(String title, {String? description}) async {
    try {
      final created = await ref
          .read(notebooksRepositoryProvider)
          .create(title: title, description: description);
      state = AsyncData([created, ...(state.valueOrNull ?? const [])]);
      return null;
    } catch (_) {
      return 'Could not create the notebook. Please try again.';
    }
  }

  /// Returns a friendly error string, or null on success.
  Future<String?> delete(String id) async {
    try {
      await ref.read(notebooksRepositoryProvider).delete(id);
      state = AsyncData([
        for (final n in state.valueOrNull ?? const <Notebook>[])
          if (n.id != id) n,
      ]);
      return null;
    } catch (_) {
      return 'Could not delete the notebook. Please try again.';
    }
  }
}

final notebooksControllerProvider =
    AsyncNotifierProvider<NotebooksController, List<Notebook>>(
      NotebooksController.new,
    );

/// State of one notebook's AI conversation.
class NotebookChatState {
  const NotebookChatState({
    this.messages = const [],
    this.busy = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool busy;
  final String? error;

  NotebookChatState copyWith({
    List<ChatMessage>? messages,
    bool? busy,
    String? error,
  }) {
    return NotebookChatState(
      messages: messages ?? this.messages,
      busy: busy ?? this.busy,
      error: error ?? this.error,
    );
  }
}

/// Per-notebook grounded chat. [send] appends the user's question, calls
/// the backend streaming route, and appends the cited answer (or a
/// friendly error). History is sent along so follow-ups are contextual.
class NotebookChatController extends FamilyNotifier<NotebookChatState, String> {
  @override
  NotebookChatState build(String arg) => const NotebookChatState();

  Future<void> send(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.busy) return;

    // History sent to the backend = the conversation BEFORE this question.
    final prior = state.messages;
    final history = [...prior, ChatMessage(role: ChatRole.user, content: text)];
    state = state.copyWith(messages: history, busy: true, error: null);

    try {
      final reply = await ref
          .read(notebooksRepositoryProvider)
          .chat(arg, question: text, history: prior);
      if (reply.answer.isEmpty && reply.citations.isEmpty) {
        throw const NotebooksException(
          'The AI returned an empty answer. Please try again.',
        );
      }
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            role: ChatRole.assistant,
            content: reply.answer,
            citations: reply.citations,
          ),
        ],
        busy: false,
      );
    } on NotebooksException catch (e) {
      state = state.copyWith(messages: history, busy: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        messages: history,
        busy: false,
        error: 'Something went wrong. Please try again.',
      );
    }
  }
}

final notebookChatControllerProvider =
    NotifierProvider.family<NotebookChatController, NotebookChatState, String>(
      NotebookChatController.new,
    );
