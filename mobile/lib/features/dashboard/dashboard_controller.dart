import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_repository.dart';

/// Everything the dashboard's live widgets need: the AI-usage meter and
/// the upcoming exams. Loaded in parallel; failures surface as a friendly
/// retry state per widget (the static sections always render).
class DashboardController extends AsyncNotifier<DashboardSnapshot> {
  @override
  Future<DashboardSnapshot> build() async {
    final repo = ref.watch(dashboardRepositoryProvider);
    final results = await Future.wait<Object>([repo.usage(), repo.exams()]);
    return DashboardSnapshot(
      usage: results[0] as AiUsage,
      exams: results[1] as List<UpcomingExam>,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
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
