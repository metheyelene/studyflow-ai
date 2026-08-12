import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/networking/api_client.dart';

/// One daily plan task (yyy-MM-dd UTC date — the backend's calendar).
class StudyPlanTask {
  const StudyPlanTask({
    required this.id,
    required this.date,
    required this.title,
    required this.detail,
    required this.durationMin,
    required this.status,
  });

  final String id;
  final String date;
  final String title;
  final String detail;
  final int durationMin;
  final String status; // pending | done | skipped

  bool get isDone => status == 'done';
  bool get isSkipped => status == 'skipped';
  bool get isPending => status == 'pending';

  factory StudyPlanTask.fromJson(Map<String, dynamic> json) {
    return StudyPlanTask(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      title: json['title'] as String? ?? 'Study task',
      detail: json['detail'] as String? ?? '',
      durationMin: (json['durationMin'] as num?)?.toInt() ?? 30,
      status: json['status'] as String? ?? 'pending',
    );
  }

  StudyPlanTask copyWith({String? status}) {
    return StudyPlanTask(
      id: id,
      date: date,
      title: title,
      detail: detail,
      durationMin: durationMin,
      status: status ?? this.status,
    );
  }
}

/// A generated plan for one exam.
class StudyPlan {
  const StudyPlan({
    required this.id,
    required this.examId,
    required this.examTitle,
    required this.version,
    required this.generatedForDate,
    required this.tasks,
    this.examDate,
  });

  final String id;
  final String examId;
  final String examTitle;
  final int version;
  final String generatedForDate;
  final List<StudyPlanTask> tasks;
  final String? examDate;

  int get doneCount => tasks.where((t) => t.isDone).length;

  int get progressPercent =>
      tasks.isEmpty ? 0 : (doneCount / tasks.length * 100).round();

  List<StudyPlanTask> tasksOn(String date) =>
      tasks.where((t) => t.date == date).toList();

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    final tasks = json['tasks'];
    return StudyPlan(
      id: json['id'] as String? ?? '',
      examId: json['examId'] as String? ?? '',
      examTitle: json['examTitle'] as String? ?? 'Exam',
      version: (json['version'] as num?)?.toInt() ?? 1,
      generatedForDate: json['generatedForDate'] as String? ?? '',
      examDate: json['examDate'] as String?,
      tasks: tasks is List
          ? [
              for (final t in tasks)
                if (t is Map)
                  StudyPlanTask.fromJson(Map<String, dynamic>.from(t)),
            ]
          : const [],
    );
  }
}

abstract class StudyPlannerRepository {
  Future<List<StudyPlan>> list();
  Future<StudyPlan> generate(String examId);
  Future<StudyPlan> updateTask(
    String planId, {
    required String taskId,
    required String status,
  });
}

class ApiStudyPlannerRepository implements StudyPlannerRepository {
  ApiStudyPlannerRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<StudyPlan>> list() async {
    final res = await _client.get<dynamic>('/api/study-plans');
    final data = res.data;
    final list = data is Map ? data['plans'] : null;
    if (list is! List) {
      throw const StudyPlannerException('Could not load your study plans.');
    }
    return [
      for (final p in list)
        if (p is Map) StudyPlan.fromJson(Map<String, dynamic>.from(p)),
    ];
  }

  @override
  Future<StudyPlan> generate(String examId) async {
    final res = await _client.post<dynamic>(
      '/api/study-plans',
      data: {'examId': examId},
    );
    final data = res.data;
    if (data is! Map) {
      throw const StudyPlannerException('Could not build that plan.');
    }
    final plan = data['plan'];
    if (plan is! Map) {
      throw const StudyPlannerException('Could not build that plan.');
    }
    return StudyPlan.fromJson(Map<String, dynamic>.from(plan));
  }

  @override
  Future<StudyPlan> updateTask(
    String planId, {
    required String taskId,
    required String status,
  }) async {
    final res = await _client.patch<dynamic>(
      '/api/study-plans/$planId',
      data: {'taskId': taskId, 'status': status},
    );
    final data = res.data;
    if (data is! Map) {
      throw const StudyPlannerException('Could not update that task.');
    }
    final plan = data['plan'];
    if (plan is! Map) {
      throw const StudyPlannerException('Could not update that task.');
    }
    return StudyPlan.fromJson(Map<String, dynamic>.from(plan));
  }
}

class StudyPlannerException implements Exception {
  const StudyPlannerException(this.message);
  final String message;
}

class StudyPlannerController extends AsyncNotifier<List<StudyPlan>> {
  @override
  Future<List<StudyPlan>> build() async {
    return ref.read(studyPlannerRepositoryProvider).list();
  }

  StudyPlannerRepository get _repo => ref.read(studyPlannerRepositoryProvider);

  /// Generates (or regenerates) the plan for an exam and refreshes the
  /// list. Returns the plan so the caller can navigate/display it.
  Future<StudyPlan> generate(String examId) async {
    final plan = await _repo.generate(examId);
    final plans = await _repo.list();
    state = AsyncData([plan, ...plans.where((p) => p.id != plan.id)]);
    return plan;
  }

  Future<void> updateTask(
    StudyPlan plan,
    StudyPlanTask task,
    String status,
  ) async {
    final updated = await _repo.updateTask(
      plan.id,
      taskId: task.id,
      status: status,
    );
    final current = await future;
    state = AsyncData([
      for (final p in current)
        if (p.id == updated.id) updated else p,
    ]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _repo.list());
  }

  /// Background refresh used when the Study tab becomes visible: re-fetch
  /// the plans without flipping to a loading skeleton, and keep showing
  /// the last good data if the fetch fails (explicit Retry still exists
  /// for real errors). The backend lazily regenerates stale plans on GET,
  /// so this is what keeps today's tasks current on every visit.
  Future<void> refreshSilently() async {
    try {
      final plans = await _repo.list();
      state = AsyncData(plans);
    } catch (_) {
      // Keep current data — a failed background refresh must not blank
      // the plan the user is looking at.
    }
  }
}

final studyPlannerRepositoryProvider = Provider<StudyPlannerRepository>(
  (ref) => ApiStudyPlannerRepository(ref.watch(apiClientProvider)),
);

final studyPlannerControllerProvider =
    AsyncNotifierProvider<StudyPlannerController, List<StudyPlan>>(
      StudyPlannerController.new,
    );
