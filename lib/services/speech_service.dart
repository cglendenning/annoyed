import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  /// Initialize speech recognition and request permissions
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // Initialize speech recognition (this will trigger iOS permission prompts)
    _isInitialized = await _speech.initialize(
      onError: (error) => debugPrint('Speech error: ${error.errorMsg}'),
      onStatus: (status) => debugPrint('Speech status: $status'),
    );

    return _isInitialized;
  }

  /// Start listening and return transcript via callback
  Future<void> startListening({
    required Function(String) onResult,
    required Function() onComplete,
    int maxRetries = 2,
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        throw Exception('Speech recognition not available. Please grant microphone permission in Settings.');
      }
    }

    // Just call listen - it starts immediately and callbacks handle the results
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          // Don't auto-complete on final result - let user tap to stop
        } else {
          onResult(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 30), // Don't auto-pause
      // onDevice deprecated, using default settings
      onSoundLevelChange: (level) {
        // Optional: could use this to show audio level indicator
      },
    );
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Cancel listening
  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized;

  /// Check if microphone permission is granted
  static Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  static Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
}






