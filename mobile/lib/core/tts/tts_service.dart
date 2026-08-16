import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech seam. Production uses [SystemTtsService] (flutter_tts);
/// widget tests override [ttsServiceProvider] with a recorder so the
/// Listen action never touches platform channels.
abstract class TtsService {
  /// Whether speech is currently playing. Flips true when [speak] starts
  /// and false when it finishes, is cancelled, or [stop] is called.
  ValueListenable<bool> get speaking;

  Future<void> speak(String text);

  Future<void> stop();
}

/// Platform TTS via flutter_tts. The completion/cancel/error handlers
/// keep [speaking] honest so the toolbar's Stop state mirrors reality.
class SystemTtsService implements TtsService {
  SystemTtsService() {
    _tts.setCompletionHandler(() => _speaking.value = false);
    _tts.setCancelHandler(() => _speaking.value = false);
    _tts.setErrorHandler((_) => _speaking.value = false);
  }

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> _speaking = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  Future<void> speak(String text) async {
    await _tts.stop();
    _speaking.value = true;
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    _speaking.value = false;
    await _tts.stop();
  }
}

/// Default TTS for the app. Override in tests.
final ttsServiceProvider = Provider<TtsService>((ref) => SystemTtsService());
