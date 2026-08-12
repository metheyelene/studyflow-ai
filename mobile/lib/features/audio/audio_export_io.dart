import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Native export: hands the MP3 bytes to the system share sheet so the
/// user can save it to Files, send it, or open it in another app. The
/// file is named meaningfully (e.g. Physics_Electromagnetics_Study_Podcast.mp3).
Future<void> exportAudio(Uint8List bytes, String fileName) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'audio/mpeg', name: fileName)],
    ),
  );
}
