import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/networking/api_client.dart';

/// AI-usage state from GET /api/usage. Limits are resolved server-side
/// (free vs premium) — the client never hardcodes a limit.
class AiUsage {
  const AiUsage({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.percent,
    required this.resetsAt,
    required this.plan,
  });

  final int used;
  final int limit;
  final int remaining;
  final double percent; // 0–100
  final String resetsAt; // ISO timestamp of the next period start
  final String plan; // "free" | "premium" | "founding_member"

  factory AiUsage.fromJson(Map<String, dynamic> json) {
    final usage = json['usage'] is Map ? json['usage'] as Map : const <String, dynamic>{};
    return AiUsage(
      used: (usage['used'] as num?)?.toInt() ?? 0,
      limit: (usage['limit'] as num?)?.toInt() ?? 0,
      remaining: (usage['remaining'] as num?)?.toInt() ?? 0,
      percent: (usage['percent'] as num?)?.toDouble() ?? 0,
      resetsAt: usage['resetsAt'] as String? ?? '',
      plan: json['plan'] as String? ?? 'free',
    );
  }
}

/// An upcoming exam from the user's study setup (GET /api/onboarding).
class UpcomingExam {
  const UpcomingExam({required this.id, required this.title, required this.date});

  final String id;
  final String title;

  /// yyyy-MM-dd.
  final String date;

  factory UpcomingExam.fromJson(Map<String, dynamic> json) {
    return UpcomingExam(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Exam',
      date: json['date'] as String? ?? '',
    );
  }

  int daysUntil(DateTime now) {
    final d = DateTime.tryParse(date);
    if (d == null) return -1;
    return d.difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

abstract class DashboardRepository {
  Future<AiUsage> usage();
  Future<List<UpcomingExam>> exams();
}

class ApiDashboardRepository implements DashboardRepository {
  ApiDashboardRepository(this._client);

  final ApiClient _client;

  @override
  Future<AiUsage> usage() async {
    final res = await _client.get<dynamic>('/api/usage');
    final data = res.data;
    if (data is! Map) throw const DashboardException('Could not load your usage.');
    return AiUsage.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<List<UpcomingExam>> exams() async {
    final res = await _client.get<dynamic>('/api/onboarding');
    final data = res.data;
    final list = data is Map ? data['exams'] : null;
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) UpcomingExam.fromJson(Map<String, dynamic>.from(e)),
    ];
  }
}

class DashboardException implements Exception {
  const DashboardException(this.message);
  final String message;
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => ApiDashboardRepository(ref.watch(apiClientProvider)),
);
