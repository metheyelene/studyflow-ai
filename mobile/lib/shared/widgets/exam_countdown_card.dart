import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/dashboard/dashboard_repository.dart';
import 'glass/glass_card.dart';

/// Exam countdown card, shared by the dashboard (UPCOMING) and the Study
/// tab. Communicates urgency through hierarchy, not alarms.
class ExamCountdownCard extends StatelessWidget {
  const ExamCountdownCard({super.key, required this.exam});

  final UpcomingExam exam;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final days = exam.daysUntil(DateTime.now());
    final countdown = days < 0
        ? 'Date set'
        : days == 0
        ? 'Today'
        : '$days days';
    final soon = days >= 0 && days <= 7;

    return GlassCard(
      tone: soon ? GlassTone.floating : GlassTone.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: soon ? g.amber.withValues(alpha: 0.18) : g.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.event_outlined,
                size: 22,
                color: soon ? g.amber : g.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: g.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    exam.displayDate,
                    style: TextStyle(color: g.textMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              countdown,
              style: TextStyle(
                color: soon ? g.amber : g.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
