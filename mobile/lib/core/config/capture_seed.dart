/// Seed data + in-memory repositories for CAPTURE_MODE builds. The app
/// boots signed in with obvious sample content (deliberately "Sample:"
/// prefixed, per the Play Store listing guide — a reviewer must never
/// mistake marketing screenshots for a real user's data).
///
/// The signed-in flag is kept in localStorage so it survives full page
/// reloads between screenshots (the driver navigates with page.goto, which
/// reloads the app).
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../features/authentication/auth_models.dart';
import '../../features/authentication/auth_repository.dart';
import '../../features/notebooks/notebook.dart';
import '../../features/notebooks/notebooks_repository.dart';

final captureUser = AuthUser(
  id: 'capture-user',
  name: 'Aarav Sharma',
  email: 'aarav@example.com',
);

const _signedInKey = 'studyflow.capture_signed_in';

bool captureSignedIn() {
  if (!kIsWeb) return false;
  try {
    return web.window.localStorage.getItem(_signedInKey) == '1';
  } catch (_) {
    return false;
  }
}

void captureSetSignedIn(bool value) {
  if (!kIsWeb) return;
  try {
    web.window.localStorage.setItem(_signedInKey, value ? '1' : '0');
  } catch (_) {}
}

class _CaptureAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> getSession() async =>
      captureSignedIn() ? captureUser : null;

  @override
  Future<AuthUser> signIn({required String email, required String password}) async {
    captureSetSignedIn(true);
    return captureUser;
  }

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async =>
      captureUser;

  @override
  Future<void> signOut() async {}
}

class CaptureNotebooksRepository implements NotebooksRepository {
  CaptureNotebooksRepository({List<Notebook>? seed})
      : _notebooks = seed ?? _sampleNotebooks();

  final List<Notebook> _notebooks;
  int _counter = 100;

  static List<Notebook> _sampleNotebooks() {
    final now = DateTime.now();
    Notebook nb(String id, String title, String desc, int sources, int daysAgo) =>
        Notebook(
          id: id,
          title: title,
          description: desc,
          createdAt: now.subtract(Duration(days: daysAgo + 7)),
          updatedAt: now.subtract(Duration(days: daysAgo)),
          sourceCount: sources,
        );
    return [
      nb('nb-cell-bio', 'Sample: Cell Biology — Unit 2', 'Photosynthesis & respiration notes', 3, 0),
      nb('nb-vlsi', 'Sample: VLSI Unit 3', 'CMOS design lecture notes', 5, 2),
      nb('nb-chem', 'Sample: Organic Chemistry', 'Reaction mechanisms + named reactions', 2, 5),
    ];
  }

  @override
  Future<List<Notebook>> list() async => List.of(_notebooks);

  @override
  Future<Notebook> create({required String title, String? description}) async {
    final n = Notebook(
      id: 'nb-${_counter++}',
      title: title,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _notebooks.insert(0, n);
    return n;
  }

  @override
  Future<void> delete(String id) async {
    _notebooks.removeWhere((n) => n.id == id);
  }
}

/// Riverpod overrides that make a capture build fully self-contained.
final captureOverrides = <Override>[
  authRepositoryProvider.overrideWithValue(_CaptureAuthRepository()),
  notebooksRepositoryProvider.overrideWithValue(CaptureNotebooksRepository()),
];
