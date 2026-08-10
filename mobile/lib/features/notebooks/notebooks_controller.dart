import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notebook.dart';

/// Device-local notebook state for Phase 3. Deliberately in-memory: the
/// source of truth is the StudyFlow backend, which this list will sync
/// against once the API client lands (Phases 4–8). Until then the UI is
/// honest about it ("stored on this device").
class NotebooksNotifier extends Notifier<List<LocalNotebook>> {
  int _counter = 0;

  @override
  List<LocalNotebook> build() => const [];

  String _nextId() {
    _counter++;
    return 'local-${DateTime.now().microsecondsSinceEpoch}-$_counter';
  }

  void create(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return;
    final now = DateTime.now();
    state = [
      LocalNotebook(id: _nextId(), title: clean, createdAt: now, updatedAt: now),
      ...state,
    ];
  }

  void rename(String id, String title) {
    final clean = title.trim();
    if (clean.isEmpty) return;
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(title: clean, updatedAt: DateTime.now()) else n,
    ];
  }

  void delete(String id) {
    state = [for (final n in state) if (n.id != id) n];
  }
}

final notebooksProvider =
    NotifierProvider<NotebooksNotifier, List<LocalNotebook>>(NotebooksNotifier.new);
