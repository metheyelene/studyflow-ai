/// A source in a notebook — matches the backend's client-facing shape
/// (`GET /api/notebooks/[id]/sources`).
library;



enum SourceStatus { processing, ready, failed, unknown }

/// A source (pasted text today; uploads land in a later phase).
class NotebookSource {
  const NotebookSource({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
    this.wordCount,
    this.pageCount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String kind; // "pasted" | "uploaded"
  final SourceStatus status;
  final int? wordCount;
  final int? pageCount;
  final DateTime createdAt;

  factory NotebookSource.fromJson(Map<String, dynamic> json) {
    return NotebookSource(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled source',
      kind: json['kind'] as String? ?? 'pasted',
      status: switch (json['status']) {
        'processing' => SourceStatus.processing,
        'ready' => SourceStatus.ready,
        'failed' => SourceStatus.failed,
        _ => SourceStatus.unknown,
      },
      wordCount: (json['wordCount'] as num?)?.toInt(),
      pageCount: (json['pageCount'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get sizeLabel {
    if (pageCount != null) return '$pageCount pages';
    if (wordCount != null) return '$wordCount words';
    return '—';
  }
}
