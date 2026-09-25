import 'dart:convert';
import 'package:flutter/material.dart';
import 'localization_service.dart';
import 'storage_service.dart';
import 'voice_stub.dart' if (dart.library.js_interop) 'voice_web.dart';

class VoiceCommandResult {
  final String recognizedText;
  final String responseMessage;
  final String? targetGame; // 'memory', 'sequence', 'attention', 'pattern'
  final int? targetTabIndex; // 0 = Home, 1 = Games, 2 = Progress, 3 = Help
  final bool shouldCallCaregiver;

  VoiceCommandResult({
    required this.recognizedText,
    required this.responseMessage,
    this.targetGame,
    this.targetTabIndex,
    this.shouldCallCaregiver = false,
  });
}

/// Conversational AI & Voice Assistant Service for MindMitra
/// Combines real OpenAI LLM conversational intelligence with Web Speech TTS/STT
/// and an offline empathetic fallback brain for rural NER connectivity.
class VoiceService {
  VoiceService._();

  static final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String> speechSubtitleNotifier = ValueNotifier<String>('');

  /// Speak any message aloud with natural human voice and completion callback
  static void speak(String message, {VoidCallback? onDone}) {
    isSpeakingNotifier.value = true;
    speechSubtitleNotifier.value = message;

    final lang = LocalizationService.currentLanguage.value;
    final geminiKey = StorageService.geminiApiKeyNotifier.value;
    PlatformVoice.speak(
      message,
      lang,
      geminiKey,
      onDone: () {
        isSpeakingNotifier.value = false;
        if (onDone != null) onDone();
      },
    );
  }

  /// Stop active speech or listening
  static void stop() {
    isSpeakingNotifier.value = false;
    speechSubtitleNotifier.value = '';
    PlatformVoice.stop();
  }

  /// Finish active voice listening and submit any spoken sentences immediately
  static void finishListening() {
    PlatformVoice.finishListening();
  }

  /// Listen to the user's real voice from microphone with live word-by-word transcription
  static void listenToUserVoice({
    required void Function(String interim) onInterim,
    required void Function(String text) onResult,
    required void Function(String err) onError,
  }) {
    final lang = LocalizationService.currentLanguage.value;
    PlatformVoice.listen(
      langCode: lang,
      onInterim: onInterim,
      onResult: onResult,
      onError: onError,
    );
  }

  /// Get spoken voice instruction for game start in the active regional language
  static String getGameVoiceInstruction(String gameType) {
    final lang = LocalizationService.currentLanguage.value;
    switch (gameType) {
      case 'memory':
        if (lang == 'hi') return 'दो कार्ड छुएं और जोड़े खोजें। कोई जल्दी नहीं है।';
        if (lang == 'as') return 'দুখন কাৰ্ড স্পৰ্শ কৰক আৰু যোৰ মিলাওক। কোনো লৰালৰি নাই।';
        if (lang == 'bn') return 'দুটি কার্ড স্পর্শ করুন এবং জোড়া মেলান। কোনো তাড়া নেই।';
        return 'Tap two cards to find matching pairs. Take your time, there is no hurry.';

      case 'sequence':
        if (lang == 'hi') return 'रंगों को जलते हुए देखें, और फिर उसी क्रम में दबाएं।';
        if (lang == 'as') return 'ৰংবোৰ জ্বলা চাওক, আৰু সেই ক্ৰমতে টিপক।';
        if (lang == 'bn') return 'রংগুলো জ্বলতে দেখুন এবং একই ক্রমে চাপুন।';
        return 'Watch the colors light up, then tap them in the same order.';

      case 'attention':
        if (lang == 'hi') return 'तारे के दिखने पर ही बक्से को दबाएं।';
        if (lang == 'as') return 'কেৱল তৰা দেখা পালেহে বাকচটোত টিপক।';
        if (lang == 'bn') return 'শুধুমাত্র তারা দেখতে পেলে বাক্সে চাপুন।';
        return 'Tap the box only when you see the star. Stay relaxed and focused.';

      case 'pattern':
        if (lang == 'hi') return 'पैटर्न को देखें और बताएं कि आगे कौन सा आकार आएगा।';
        if (lang == 'as') return 'নকশাটো চাওক আৰু পিছৰ আকৃতিটো বাছক।';
        if (lang == 'bn') return 'প্যাটার্নটি দেখুন এবং পরের আকৃতিটি বেছে নিন।';
        return 'Look at the sequence and tap the shape that completes the pattern.';

      default:
        return 'Welcome to your daily mind activity.';
    }
  }

  /// Full ChatGPT-style Conversational AI response + Intent detection
  /// Uses the logged-in user's profile (Name, Age, Gender, City, Caregiver) dynamically!
  static Future<VoiceCommandResult> askConversationalAI(
    String userInput,
    List<Map<String, String>> chatHistory,
  ) async {
    final profile = StorageService.profileNotifier.value;
    final actionCheck = _detectAppAction(userInput);
    final lang = LocalizationService.currentLanguage.value;
    final langName = LocalizationService.supportedLanguages[lang] ?? 'English';

    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = weekdays[now.weekday - 1];
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // If online, query Google Gemini / LLM for natural human conversation in ANY Indian language
    if (StorageService.isOnlineNotifier.value) {
      final systemPrompt =
          'You are MindMitra (also called MindMitra Saathi), a warm, loving, patient, and human-like AI companion '
          'designed for ${profile.name} (age ${profile.age}, gender: ${profile.gender}) living in ${profile.city}. '
          'Key facts about ${profile.name}:\n'
          '- Primary caregiver is ${profile.caregiverName} (Phone: ${profile.caregiverPhone}).\n'
          '- Family neurologist is ${profile.doctorName}.\n'
          '- Today is $dayName, and the current time is $timeStr.\n'
          '- Inside the MindMitra app, ${profile.name} can play 4 gentle brain games: Memory Match, Sequence Game, Attention Game, and Pattern Game.\n'
          'CRITICAL LANGUAGE & VOICE RULES:\n'
          '1. You are 100% fluent in ALL Indian languages: Tamil (தமிழ்), Hindi (हिन्दी), Malayalam (മലയാളം), Telugu (తెలుగు), Kannada (ಕನ್ನಡ), Assamese (অসমীয়া), Bengali (বাংলা), Marathi (मराठी), Gujarati (ગુજરાતી), Punjabi (ਪੰਜਾਬੀ), Odia (ଓଡ଼ିଆ), Urdu (اردو), Manipuri, Mizo, and English!\n'
          '2. NEVER say you can only speak English! Whenever the user asks you to speak in Tamil, Hindi, Malayalam, Telugu, Kannada, Bengali, Assamese, or ANY Indian language (even if they type in English/Tanglish/Hinglish like "talk in tamil" or "epdi irukinga"), IMMEDIATELY switch to and reply in that Indian language using its native script (e.g., தமிழ் for Tamil) so the speech synthesizer pronounces it naturally!\n'
          '3. If the user is already chatting in an Indian language in the recent conversation history, continue replying in that same Indian language unless they ask to switch.\n'
          '4. If no other language was requested in the chat, default to $langName.\n'
          '5. Address ${profile.name} affectionately, keep your reply concise (2 to 3 sentences) for natural spoken voice, and comfort or chat with them about anything.';

      final List<Map<String, String>> apiMessages = [
        {'role': 'system', 'content': systemPrompt},
        ...chatHistory.take(8),
        {'role': 'user', 'content': userInput},
      ];

      final geminiKey = StorageService.geminiApiKeyNotifier.value;
      final aiReply = await PlatformVoice.askAI(jsonEncode(apiMessages), geminiKey);
      if (aiReply != null && aiReply.isNotEmpty) {
        return VoiceCommandResult(
          recognizedText: userInput,
          responseMessage: aiReply,
          targetGame: actionCheck.targetGame,
          targetTabIndex: actionCheck.targetTabIndex,
          shouldCallCaregiver: actionCheck.shouldCallCaregiver,
        );
      }
    }

    // Offline conversational fallback (when offline or no internet in remote NER)
    return _offlineConversationalFallback(userInput, actionCheck);
  }

  /// Detects if the user explicitly asked to open a game, tab, or call someone
  static VoiceCommandResult _detectAppAction(String input) {
    final lower = input.toLowerCase().trim();
    final caregiverFirst = StorageService.profileNotifier.value.caregiverName.split(' ').first.toLowerCase();

    final wantsToPlay = lower.contains('start') ||
        lower.contains('play') ||
        lower.contains('open') ||
        lower.contains('शुरू') ||
        lower.contains('खेल') ||
        lower.contains('খেল') ||
        lower.contains('আৰম্ভ');

    if (wantsToPlay && (lower.contains('listen') || lower.contains('speak') || lower.contains('सुनो') || lower.contains('শুনক'))) {
      return VoiceCommandResult(recognizedText: input, responseMessage: '', targetGame: 'listen_speak');
    }
    if (wantsToPlay && (lower.contains('riddle') || lower.contains('voice') || lower.contains('talk') || lower.contains('पहेली'))) {
      return VoiceCommandResult(recognizedText: input, responseMessage: '', targetGame: 'voice_talk');
    }
    if (wantsToPlay && (lower.contains('memory') || lower.contains('card') || lower.contains('match') || lower.contains('स्मृति') || lower.contains('স্মৃতি'))) {
      return VoiceCommandResult(recognizedText: input, responseMessage: '', targetGame: 'memory');
    }
    if (wantsToPlay && (lower.contains('sequence') || lower.contains('color') || lower.contains('क्रम') || lower.contains('ক্ৰমিক'))) {
      return VoiceCommandResult(recognizedText: input, responseMessage: '', targetGame: 'sequence');
    }
    if (wantsToPlay && (lower.contains('attention') || lower.contains('star') || lower.contains('ध्यान') || lower.contains('মনোযোগ'))) {
      return VoiceCommandResult(recognizedText: input, responseMessage: '', targetGame: 'attention');
    }
    if (wantsToPlay && (lower.contains('pattern') || lower.contains('shape') || lower.contains('पैटर्न') || lower.contains('নকশা'))) {
      return VoiceCommandResult(recognizedText: input, responseMessage: '', targetGame: 'pattern');
    }
    if (lower.contains('show progress') || lower.contains('open progress') || lower.contains('my score')) {
      return VoiceCommandResult(recognizedText: input, responseMessage: '', targetTabIndex: 2);
    }
    if (lower.contains('call caregiver') ||
        lower.contains('call $caregiverFirst') ||
        lower.contains('call my son') ||
        lower.contains('call family') ||
        lower.contains('कॉल')) {
      return VoiceCommandResult(recognizedText: input, responseMessage: '', shouldCallCaregiver: true);
    }

    return VoiceCommandResult(recognizedText: input, responseMessage: '');
  }

  /// Rich offline human-like fallback when internet is disconnected
  static VoiceCommandResult _offlineConversationalFallback(String input, VoiceCommandResult actionCheck) {
    final profile = StorageService.profileNotifier.value;
    final lower = input.toLowerCase().trim();
    final lang = LocalizationService.currentLanguage.value;

    if (actionCheck.targetGame != null) {
      return VoiceCommandResult(
        recognizedText: input,
        responseMessage: 'Of course, ${profile.name} ji! Opening the ${actionCheck.targetGame} game for you right now. Take your time and enjoy!',
        targetGame: actionCheck.targetGame,
      );
    }

    if (actionCheck.shouldCallCaregiver) {
      return VoiceCommandResult(
        recognizedText: input,
        responseMessage: 'I am connecting a call to your caregiver ${profile.caregiverName} right now, ${profile.name} ji.',
        shouldCallCaregiver: true,
      );
    }

    if (lower.contains('hello') || lower.contains('hi') || lower.contains('good morning') || lower.contains('namaste') || lower.contains('नमस्ते')) {
      final msg = lang == 'hi'
          ? 'नमस्ते ${profile.name} जी! आज आप कैसे हैं? आपसे बात करके मुझे बहुत खुशी हो रही है।'
          : 'Namaskar ${profile.name} ji! It is so wonderful to hear your voice today in ${profile.city}. How are you feeling right now?';
      return VoiceCommandResult(recognizedText: input, responseMessage: msg);
    }

    if (lower.contains('lonely') || lower.contains('sad') || lower.contains('anxious') || lower.contains('scared') || lower.contains('confused')) {
      return VoiceCommandResult(
        recognizedText: input,
        responseMessage:
            'Take a slow, gentle breath with me, ${profile.name} ji. You are completely safe at home in ${profile.city}, ${profile.caregiverName} cares for you dearly, and I am right here with you.',
      );
    }

    if (lower.contains('who am i') ||
        lower.contains('my name') ||
        lower.contains('my age') ||
        lower.contains('where am i') ||
        lower.contains('city') ||
        lower.contains('family') ||
        lower.contains('caregiver')) {
      return VoiceCommandResult(
        recognizedText: input,
        responseMessage:
            'You are ${profile.name} (${profile.age} years old, ${profile.gender}), living in ${profile.city}. Your caring family member is ${profile.caregiverName} (${profile.caregiverPhone}).',
      );
    }

    if (lower.contains('day') || lower.contains('time') || lower.contains('date')) {
      final now = DateTime.now();
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return VoiceCommandResult(
        recognizedText: input,
        responseMessage:
            'Today is ${weekdays[now.weekday - 1]}, and the time in ${profile.city} is ${now.hour}:${now.minute.toString().padLeft(2, '0')}. It is a calm and peaceful day.',
      );
    }

    if (lower.contains('story') || lower.contains('joke') || lower.contains('song') || lower.contains('assam') || lower.contains('tea')) {
      return VoiceCommandResult(
        recognizedText: input,
        responseMessage:
            'Imagine the gentle morning breeze in ${profile.city} and the green tea gardens of the North East, with birds singing softly in the trees. Would you like to hear another story or play a relaxing game together, ${profile.name} ji?',
      );
    }

    return VoiceCommandResult(
      recognizedText: input,
      responseMessage:
          'I am listening and right here with you, ${profile.name} ji in ${profile.city}. We can chat about your day, your family (${profile.caregiverName}), or play a gentle memory game whenever you like!',
      targetGame: actionCheck.targetGame,
      targetTabIndex: actionCheck.targetTabIndex,
    );
  }

  /// Legacy synchronous command parser for unit tests
  static VoiceCommandResult parseCommand(String input) {
    final actionCheck = _detectAppAction(input);
    return _offlineConversationalFallback(input, actionCheck);
  }
}
