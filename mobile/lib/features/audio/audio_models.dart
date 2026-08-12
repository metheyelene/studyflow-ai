/// A transcript section from the generated podcast script, with an
/// estimated start time so the player can jump to it and highlight it
/// while the audio plays.
class TranscriptSection {
  const TranscriptSection({
    required this.heading,
    required this.text,
    required this.startSec,
    this.sources = const [],
  });

  final String heading;
  final String text;
  final int startSec;
  final List<String> sources;

  factory TranscriptSection.fromJson(Map<String, dynamic> json) {
    final src = json['sources'];
    return TranscriptSection(
      heading: json['heading'] as String? ?? '',
      text: json['text'] as String? ?? '',
      startSec: (json['startSec'] as num?)?.toInt() ?? 0,
      sources: src is List ? src.map((s) => s.toString()).toList() : const [],
    );
  }
}

/// A Study Podcast episode (from `GET /api/audio`). The audio itself
/// streams/downloads from [audioUrl]; the JSON payload never carries it.
class AudioEpisode {
  const AudioEpisode({
    required this.id,
    required this.title,
    required this.style,
    required this.length,
    required this.status,
    required this.pipelineStage,
    required this.audioUrl,
    required this.createdAt,
    this.notebookId,
    this.notebookTitle,
    this.errorMessage,
    this.durationSec,
    this.wordCount,
    this.playbackPositionSec = 0,
    this.transcript = const [],
    this.script,
  });

  final String id;
  final String title;
  final String style; // focused | friendly | quick | deep | podcast
  final String length; // quick | standard | deep
  final String status; // processing | ready | failed
  final String pipelineStage; // queued | organizing | writing | generating audio | ready | failed
  final String audioUrl;
  final DateTime createdAt;
  final String? notebookId;
  final String? notebookTitle;
  final String? errorMessage;
  final int? durationSec;
  final int? wordCount;
  final int playbackPositionSec;
  final List<TranscriptSection> transcript;
  final String? script;

  bool get isReady => status == 'ready';
  bool get isProcessing => status == 'processing';
  bool get isFailed => status == 'failed';

  factory AudioEpisode.fromJson(Map<String, dynamic> json) {
    final transcript = json['transcript'];
    return AudioEpisode(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Study Podcast',
      style: json['style'] as String? ?? 'focused',
      length: json['length'] as String? ?? 'standard',
      status: json['status'] as String? ?? 'processing',
      pipelineStage: json['pipelineStage'] as String? ?? 'queued',
      audioUrl: json['audioUrl'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      notebookId: json['notebookId'] as String?,
      notebookTitle: json['notebookTitle'] as String?,
      errorMessage: json['errorMessage'] as String?,
      durationSec: (json['durationSec'] as num?)?.toInt(),
      wordCount: (json['wordCount'] as num?)?.toInt(),
      playbackPositionSec: (json['playbackPositionSec'] as num?)?.toInt() ?? 0,
      transcript: transcript is List
          ? [
              for (final s in transcript)
                if (s is Map) TranscriptSection.fromJson(Map<String, dynamic>.from(s)),
            ]
          : const [],
      script: json['script'] as String?,
    );
  }

  AudioEpisode copyWith({
    String? status,
    String? pipelineStage,
    String? errorMessage,
    int? durationSec,
    int? wordCount,
    int? playbackPositionSec,
    List<TranscriptSection>? transcript,
    String? script,
  }) {
    return AudioEpisode(
      id: id,
      title: title,
      style: style,
      length: length,
      status: status ?? this.status,
      pipelineStage: pipelineStage ?? this.pipelineStage,
      audioUrl: audioUrl,
      createdAt: createdAt,
      notebookId: notebookId,
      notebookTitle: notebookTitle,
      errorMessage: errorMessage ?? this.errorMessage,
      durationSec: durationSec ?? this.durationSec,
      wordCount: wordCount ?? this.wordCount,
      playbackPositionSec: playbackPositionSec ?? this.playbackPositionSec,
      transcript: transcript ?? this.transcript,
      script: script ?? this.script,
    );
  }
}

/// Display labels for podcast styles/lengths (kept in the model so the
/// UI and any future prefs stay in sync).
const kPodcastStyleLabels = <String, String>{
  'focused': 'Focused',
  'friendly': 'Friendly Tutor',
  'quick': 'Quick Revision',
  'deep': 'Deep Dive',
  'podcast': 'Podcast',
};

const kPodcastLengthLabels = <String, String>{
  'quick': 'Quick · 5–10 min',
  'standard': 'Standard · 10–20 min',
  'deep': 'Deep Dive · 20–40 min',
};

/// The real pipeline stages, in order, with the text the UI shows while
/// polling. Only stages the backend actually reports are ever displayed.
const kPipelineStageLabels = <String, String>{
  'queued': 'Queued…',
  'organizing': 'Organizing your notes…',
  'writing': 'Writing the study script…',
  'generating audio': 'Generating audio…',
  'ready': 'Ready to listen',
  'failed': 'Generation failed',
};
