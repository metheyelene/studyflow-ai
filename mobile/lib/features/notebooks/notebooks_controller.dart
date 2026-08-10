import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notebook.dart';
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
