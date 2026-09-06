/// Thin wrapper around the platform text-to-speech engine used by the
/// Reader's "Listen" feature. Keeps the plugin isolated so the rest of
/// the app (and tests) never touch the native side directly.
library;

import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  FlutterTts? _tts;
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    _tts ??= FlutterTts();
    await _tts!.setLanguage('en-US');
    await _tts!.setSpeechRate(0.48);
    await _tts!.setPitch(1.0);
    await _tts!.setVolume(1.0);
    await _tts!.awaitSpeakCompletion(true);
    _ready = true;
  }

  /// Speaks [text] and completes when playback finishes (or throws when
  /// no engine is available).
  Future<void> speak(String text) async {
    await _ensure();
    final result = await _tts!.speak(text);
    if (result != 1) {
      throw StateError('Text-to-speech unavailable on this device.');
    }
  }

  Future<void> stop() async {
    if (_tts != null) {
      try {
        await _tts!.stop();
      } catch (_) {
        // Stopping is best-effort.
      }
    }
  }

  /// Whether a platform engine is present (probed once).
  Future<bool> available() async {
    try {
      await _ensure();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    await stop();
    _tts = null;
    _ready = false;
  }
}
