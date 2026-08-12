import 'dart:typed_data';

import 'audio_export_io.dart'
    if (dart.library.js_interop) 'audio_export_web.dart'
    as impl;

/// Export the generated MP3: native shares it through the system share
/// sheet; web downloads the file via an anchor.
Future<void> exportAudio(Uint8List bytes, String fileName) =>
    impl.exportAudio(bytes, fileName);
