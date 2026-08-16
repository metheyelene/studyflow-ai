/// The note editor's contextual AI transforms. Mirrors ASSIST_MODES on
/// the backend (`POST /api/notebooks/[id]/assist`).
enum NoteAssistMode { explain, summarize, simplify, quiz }

extension NoteAssistModeLabel on NoteAssistMode {
  String get label => switch (this) {
    NoteAssistMode.explain => 'Explain',
    NoteAssistMode.summarize => 'Summarize',
    NoteAssistMode.simplify => 'Simplify',
    NoteAssistMode.quiz => 'Quiz',
  };
}
