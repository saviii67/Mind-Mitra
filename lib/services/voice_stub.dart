import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformVoice {
  static void speak(
    String text,
    String langCode,
    String geminiKey, {
    VoidCallback? onDone,
  }) {
    if (onDone != null) {
      Future.delayed(const Duration(seconds: 2), onDone);
    }
  }

  static void stop() {}

  static void finishListening() {}

  static void listen({
    required String langCode,
    required void Function(String interim) onInterim,
    required void Function(String text) onResult,
    required void Function(String err) onError,
  }) {
    onError('Voice input requires browser or mobile speech plugin');
  }

  static Future<String?> askAI(String messagesJson, String geminiKey) async {
    try {
      final List<dynamic> messages = jsonDecode(messagesJson);
      final String apiKey = geminiKey.trim();

      // 1. If Google Gemini API key is present, call Google Gemini API directly on Android/Mobile!
      if (apiKey.length > 5) {
        String systemText = '';
        final List<Map<String, dynamic>> geminiContents = [];

        for (final raw in messages) {
          final role = (raw['role'] ?? 'user').toString();
          final content = (raw['content'] ?? '').toString();
          if (role == 'system') {
            systemText += (systemText.isEmpty ? '' : '\n') + content;
          } else {
            final gRole = (role == 'assistant' || role == 'model') ? 'model' : 'user';
            if (geminiContents.isEmpty && gRole == 'model') continue;
            if (geminiContents.isNotEmpty && geminiContents.last['role'] == gRole) {
              final parts = geminiContents.last['parts'] as List<Map<String, String>>;
              parts[0]['text'] = '${parts[0]['text']}\n$content';
            } else {
              geminiContents.add({
                'role': gRole,
                'parts': [
                  {'text': content}
                ],
              });
            }
          }
        }

        if (geminiContents.isEmpty) {
          geminiContents.add({
            'role': 'user',
            'parts': [
              {'text': 'Hello'}
            ],
          });
        }

        final Map<String, dynamic> payload = {
          'contents': geminiContents,
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 300,
          },
        };
        if (systemText.isNotEmpty) {
          payload['systemInstruction'] = {
            'parts': [
              {'text': systemText}
            ],
          };
        }

        final models = ['gemini-flash-lite-latest', 'gemini-3.6-flash', 'gemini-flash-latest'];
        for (final model in models) {
          try {
            final client = HttpClient();
            client.connectionTimeout = const Duration(seconds: 10);
            final uri = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${Uri.encodeComponent(apiKey)}',
            );
            final request = await client.postUrl(uri);
            request.headers.set('Content-Type', 'application/json; charset=utf-8');
            request.add(utf8.encode(jsonEncode(payload)));
            final response = await request.close();
            final body = await response.transform(utf8.decoder).join();
            if (response.statusCode == 200) {
              final decoded = jsonDecode(body);
              final candidates = decoded['candidates'] as List?;
              if (candidates != null && candidates.isNotEmpty) {
                final parts = candidates[0]['content']?['parts'] as List?;
                if (parts != null && parts.isNotEmpty && parts[0]['text'] != null) {
                  return parts[0]['text'].toString().trim();
                }
              }
            }
          } catch (_) {}
        }
      }

      // 2. Free OpenAI-compatible fallback
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(Uri.parse('https://text.pollinations.ai/openai'));
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      final payload = jsonEncode({
        'messages': messages,
        'model': 'openai',
      });
      request.add(utf8.encode(payload));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        try {
          final parsed = jsonDecode(body);
          final choices = parsed['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            return choices[0]['message']?['content']?.toString().trim();
          }
        } catch (_) {}
        return body.trim();
      }
    } catch (_) {}
    return null;
  }
}
