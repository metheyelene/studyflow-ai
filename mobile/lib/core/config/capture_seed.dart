/// Seed data + in-memory repositories for CAPTURE_MODE builds. The app
/// boots signed in with obvious sample content (deliberately "Sample:"
/// prefixed, per the Play Store listing guide — a reviewer must never
/// mistake marketing screenshots for a real user's data).
///
/// The signed-in flag is kept in localStorage so it survives full page
/// reloads between screenshots (the driver navigates with page.goto, which
/// reloads the app).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'capture_storage.dart';
import '../../features/authentication/auth_models.dart';
import '../../features/authentication/auth_repository.dart';
import '../../features/notebooks/notebook.dart';
import '../../features/notebooks/notebook_chat.dart';
import '../../features/notebooks/notebooks_repository.dart';
import '../../features/onboarding/onboarding_models.dart';
import '../../features/onboarding/onboarding_repository.dart';

final captureUser = AuthUser(
  id: 'capture-user',
  name: 'Aarav Sharma',
  email: 'aarav@example.com',
);

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

/// Capture builds are signed in but must not gate on onboarding — the
/// backend isn't reachable and the screenshots target the app shell.
class _CaptureOnboardingRepository implements OnboardingRepository {
  @override
  Future<bool> isCompleted() async => true;

  @override
  Future<void> submit(OnboardingPayload payload) async {}
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

  @override
  Future<ChatReply> chat(
    String notebookId, {
    required String question,
    String mode = 'sources',
    List<ChatMessage> history = const [],
  }) async {
    return ChatReply(
      answer: 'Sample answer: based on your sources, this is the key idea. '
          'It is stated in your lecture notes.',
      citations: const [
        ChatCitation(
          marker: 1,
          sourceId: 'src-1',
          sourceTitle: 'Sample: Cell Biology — Unit 2',
          page: 4,
          excerpt: 'Photosynthesis converts light energy into chemical energy.',
        ),
      ],
    );
  }
}

/// Riverpod overrides that make a capture build fully self-contained.
final captureOverrides = <Override>[
  authRepositoryProvider.overrideWithValue(_CaptureAuthRepository()),
  onboardingRepositoryProvider.overrideWithValue(_CaptureOnboardingRepository()),
  notebooksRepositoryProvider.overrideWithValue(CaptureNotebooksRepository()),
];
