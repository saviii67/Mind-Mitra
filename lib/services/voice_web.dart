import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('mindMitraSpeak')
external void _jsSpeak(
  JSString text,
  JSString lang,
  JSString geminiKey,
  JSFunction onDone,
);

@JS('mindMitraStopSpeak')
external void _jsStopSpeak();

@JS('mindMitraFinishListen')
external void _jsFinishListen();

@JS('mindMitraListen')
external void _jsListen(
  JSString lang,
  JSFunction onInterim,
  JSFunction onFinal,
  JSFunction onError,
);

@JS('mindMitraAskAI')
external void _jsAskAI(
  JSString messagesJson,
  JSString geminiKey,
  JSFunction onSuccess,
  JSFunction onError,
);

class PlatformVoice {
  static String _toBcp47(String langCode) {
    switch (langCode) {
      case 'ta':
        return 'ta-IN';
      case 'hi':
        return 'hi-IN';
      case 'ml':
        return 'ml-IN';
      case 'te':
        return 'te-IN';
      case 'kn':
        return 'kn-IN';
      case 'bn':
        return 'bn-IN';
      case 'as':
        return 'as-IN';
      case 'mr':
        return 'mr-IN';
      case 'gu':
        return 'gu-IN';
      case 'pa':
        return 'pa-IN';
      case 'or':
        return 'or-IN';
      case 'ur':
        return 'ur-IN';
      case 'en':
      default:
        return 'en-IN';
    }
  }

  static void speak(
    String text,
    String langCode,
    String geminiKey, {
    VoidCallback? onDone,
  }) {
    try {
      final String bcp47 = _toBcp47(langCode);

      _jsSpeak(
        text.toJS,
        bcp47.toJS,
        geminiKey.toJS,
        (() {
          if (onDone != null) onDone();
        }).toJS,
      );
    } catch (_) {
      if (onDone != null) onDone();
    }
  }

  static void stop() {
    try {
      _jsStopSpeak();
    } catch (_) {}
  }

  static void finishListening() {
    try {
      _jsFinishListen();
    } catch (_) {}
  }

  static void listen({
    required String langCode,
    required void Function(String interim) onInterim,
    required void Function(String text) onResult,
    required void Function(String err) onError,
  }) {
    try {
      final String bcp47 = _toBcp47(langCode);

      _jsListen(
        bcp47.toJS,
        ((JSString interim) {
          onInterim(interim.toDart);
        }).toJS,
        ((JSString transcript) {
          onResult(transcript.toDart);
        }).toJS,
        ((JSString errorMsg) {
          onError(errorMsg.toDart);
        }).toJS,
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  static Future<String?> askAI(String messagesJson, String geminiKey) async {
    final completer = Completer<String?>();
    try {
      _jsAskAI(
        messagesJson.toJS,
        geminiKey.toJS,
        ((JSString reply) {
          if (!completer.isCompleted) {
            completer.complete(reply.toDart);
          }
        }).toJS,
        ((JSString err) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }).toJS,
      );
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );
  }
}
