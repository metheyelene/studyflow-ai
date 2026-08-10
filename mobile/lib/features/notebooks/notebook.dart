/// A study notebook. This local model backs the Phase 3 UI; once the
/// backend client lands (Phases 4–8) the list is fetched from the API and
/// these become plain cached copies of the server record.
class LocalNotebook {
  const LocalNotebook({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.sourceCount = 0,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sourceCount;

  LocalNotebook copyWith({String? title, DateTime? updatedAt, int? sourceCount}) {
    return LocalNotebook(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceCount: sourceCount ?? this.sourceCount,
    );
  }
}
