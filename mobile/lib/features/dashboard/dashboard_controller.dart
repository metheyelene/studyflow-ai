import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_repository.dart';

// ── Independent providers ─────────────────────────────────────
// Usage and exams are fetched independently so a failure in one
// never takes down the other.

/// AI usage meter (GET /api/usage).
final usageProvider = FutureProvider<AiUsage>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.usage();
});

/// Upcoming exams (GET /api/onboarding).
final examsProvider = FutureProvider<List<UpcomingExam>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.exams();
});

/// Legacy combined snapshot for any code that still needs it.
/// Each consumer should prefer [usageProvider] or [examsProvider] directly.
class DashboardController extends AsyncNotifier<DashboardSnapshot> {
  @override
  Future<DashboardSnapshot> build() async {
    // Use .then to avoid one failure killing both:
    final usageFuture = ref
        .watch(usageProvider.future)
        .then<AiUsage>(
          (u) => u,
          onError: (_) => const AiUsage(
            used: 0,
            limit: 0,
            remaining: 0,
            percent: 0,
            resetsAt: '',
            plan: 'free',
          ),
        );
    final examsFuture = ref
        .watch(examsProvider.future)
        .then<List<UpcomingExam>>((e) => e, onError: (_) => <UpcomingExam>[]);

    final results = await Future.wait<Object>([usageFuture, examsFuture]);
    return DashboardSnapshot(
      usage: results[0] as AiUsage,
      exams: results[1] as List<UpcomingExam>,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    // Invalidate both sub-providers so they refetch.
    ref.invalidate(usageProvider);
    ref.invalidate(examsProvider);
    state = await AsyncValue.guard(() => build());
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({required this.usage, required this.exams});

  final AiUsage usage;
  final List<UpcomingExam> exams;
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardSnapshot>(
      DashboardController.new,
    );
