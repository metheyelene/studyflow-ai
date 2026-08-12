/// Notebook AI chat models. The citation trailer format mirrors the
/// backend (`POST /api/notebooks/[id]/chat`): the answer text stream is
/// followed by a `\n\n__SF_CITATIONS__{json}` line carrying the grounded
/// citations found in the response.
library;

import 'dart:convert';

/// A grounded citation attached to an AI answer.
class ChatCitation {
  const ChatCitation({
    required this.marker,
    required this.sourceId,
    required this.sourceTitle,
    this.page,
    required this.excerpt,
  });

  /// The number the answer text refers to (e.g. "[1]").
  final int marker;
  final String sourceId;
  final String sourceTitle;
  final int? page;
  final String excerpt;

  factory ChatCitation.fromJson(Map<String, dynamic> json) {
    return ChatCitation(
      marker: (json['marker'] as num?)?.toInt() ?? 0,
      sourceId: json['sourceId'] as String? ?? '',
      sourceTitle: json['sourceTitle'] as String? ?? 'Source',
      page: (json['page'] as num?)?.toInt(),
      excerpt: json['excerpt'] as String? ?? '',
    );
  }

  String get label {
    final withPage = page != null ? ' · p. $page' : '';
    return '$sourceTitle$withPage';
  }
}

enum ChatRole { user, assistant }

/// One message in the conversation. Assistant messages carry [citations]
/// that the answer text references.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.citations = const [],
  });

  final ChatRole role;
  final String content;
  final List<ChatCitation> citations;

  bool get isUser => role == ChatRole.user;
}

/// The parsed result of one chat turn.
class ChatReply {
  const ChatReply({required this.answer, required this.citations});

  final String answer;
  final List<ChatCitation> citations;
}

const _trailerMarker = '__SF_CITATIONS__';

/// Split the streamed response body into the answer text and the citation
/// trailer. When the trailer is missing or malformed, citations are empty
/// and the whole body is treated as the answer — never lose the text.
ChatReply parseChatReply(String body) {
  final markerAt = body.lastIndexOf(_trailerMarker);
  if (markerAt < 0) {
    return ChatReply(answer: body.trim(), citations: const []);
  }
  final answer = body.substring(0, markerAt).trim();
  final trailerJson = body.substring(markerAt + _trailerMarker.length).trim();
  try {
    final decoded = trailerJson.isEmpty
        ? null
        : (jsonDecode(trailerJson) as Map);
    final rawCitations = decoded?['citations'];
    if (rawCitations is List) {
      return ChatReply(
        answer: answer,
        citations: [
          for (final c in rawCitations)
            if (c is Map) ChatCitation.fromJson(Map<String, dynamic>.from(c)),
        ],
      );
    }
    return ChatReply(answer: answer, citations: const []);
  } catch (_) {
    return ChatReply(answer: answer, citations: const []);
  }
}
