import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_session.dart';
import '../services/storage_service.dart';
import '../services/ai_engine.dart';
import '../services/voice_service.dart';
import '../services/voice_stub.dart' if (dart.library.js_interop) '../services/voice_web.dart';
import 'games_screen.dart';

class _VoiceRiddleItem {
  final String spokenRiddle;
  final String primaryAnswer;
  final String emoji;
  final List<String> acceptedKeywords;
  final List<String> choices;

  const _VoiceRiddleItem({
    required this.spokenRiddle,
    required this.primaryAnswer,
    required this.emoji,
    required this.acceptedKeywords,
    required this.choices,
  });
}

/// Game 6: Voice Riddle & Talk (AI Listening Comprehension & Expressive Speech Game)
/// MindMitra speaks an auditory riddle or short story question aloud.
/// The player listens and answers by speaking naturally into the microphone.
/// Powered by Real-Time Phonetic + Multilingual + Gemini AI Semantic Evaluation!
class VoiceRiddleGame extends StatefulWidget {
  const VoiceRiddleGame({super.key});

  @override
  State<VoiceRiddleGame> createState() => _VoiceRiddleGameState();
}

class _VoiceRiddleGameState extends State<VoiceRiddleGame> {
  int _difficulty = 1;
  int _round = 0;
  final int _totalRounds = 3;

  int _mistakes = 0;
  int _totalAttempts = 0;
  bool _isCompleted = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _isCheckingAI = false;
  bool _showEmojiHint = false;
  bool _roundSolved = false;
  String _liveTranscript = '';
  String _feedbackText = '';
  DateTime _startTime = DateTime.now();

  late List<_VoiceRiddleItem> _rounds;

  static const Map<int, List<_VoiceRiddleItem>> _riddleBank = {
    1: [
      _VoiceRiddleItem(
        spokenRiddle:
            'Listen to this riddle: I am a sweet yellow fruit that everyone loves in summer. What is my name?',
        primaryAnswer: 'Mango',
        emoji: '🥭',
        acceptedKeywords: [
          'mango',
          'mangoes',
          'aam',
          'आम',
          'மாம்பழம்',
          'mampazham',
          'maambazham',
          'മാമ്പഴം',
          'మామిడి',
          'ಮಾವು',
          'আম',
        ],
        choices: ['Mango', 'Chair', 'Umbrella'],
      ),
      _VoiceRiddleItem(
        spokenRiddle:
            'Listen carefully: I shine brightly in the sky during the day and give warm light to the earth. What am I?',
        primaryAnswer: 'Sun',
        emoji: '☀️',
        acceptedKeywords: [
          'sun',
          'sunshine',
          'sunlight',
          'suraj',
          'surya',
          'सूरज',
          'सूर्य',
          'சூரியன்',
          'sooriyan',
          'സൂര്യൻ',
          'సూర్యుడు',
          'ಸೂರ್ಯ',
          'সূর্য',
        ],
        choices: ['Sun', 'Shoe', 'Pencil'],
      ),
      _VoiceRiddleItem(
        spokenRiddle:
            'Listen carefully: People open me and hold me above their head when it rains outside. What am I?',
        primaryAnswer: 'Umbrella',
        emoji: '☂️',
        acceptedKeywords: [
          'umbrella',
          'chhata',
          'chata',
          'छाता',
          'குடை',
          'kudai',
          'കുട',
          'గొడుగు',
          'ಛತ್ರಿ',
          'ছাতা',
        ],
        choices: ['Umbrella', 'Banana', 'Clock'],
      ),
      _VoiceRiddleItem(
        spokenRiddle:
            'Listen carefully: I have hands on my face and I tell you the time every hour of the day. What am I?',
        primaryAnswer: 'Clock',
        emoji: '🕰️',
        acceptedKeywords: [
          'clock',
          'watch',
          'time',
          'ghadi',
          'घड़ी',
          'கடிகாரம்',
          'kadigaram',
          'ഘടികാരം',
          'గడియారం',
          'ಗಡಿಯಾರ',
          'ঘড়ি',
        ],
        choices: ['Clock', 'Apple', 'Boat'],
      ),
    ],
    2: [
      _VoiceRiddleItem(
        spokenRiddle:
            'Listen carefully: I am India\'s national bird, famous for my beautiful blue and green feathers when I dance in the rain. Who am I?',
        primaryAnswer: 'Peacock',
        emoji: '🦚',
        acceptedKeywords: [
          'peacock',
          'mor',
          'मोर',
          'மயில்',
          'mayil',
          'മയിൽ',
          'నెమలి',
          'ನವಿಲು',
          'ময়ূর',
        ],
        choices: ['Peacock', 'Sparrow', 'Cat'],
      ),
      _VoiceRiddleItem(
        spokenRiddle:
            'Listen carefully: I am a hot, refreshing drink made from green leaves grown in Assam and Nilgiris, often enjoyed with milk every morning. What am I?',
        primaryAnswer: 'Tea',
        emoji: '☕',
        acceptedKeywords: [
          'tea',
          'chai',
          'चाय',
          'தேநீர்',
          'டீ',
          'theeneer',
          'ചായ',
          'టీ',
          'ಚಹಾ',
          'চা',
        ],
        choices: ['Tea', 'Watermelon', 'Book'],
      ),
      _VoiceRiddleItem(
        spokenRiddle:
            'Listen carefully: I am a beautiful pink flower that grows in water and is the national flower of India. What is my name?',
        primaryAnswer: 'Lotus',
        emoji: '🪷',
        acceptedKeywords: [
          'lotus',
          'kamal',
          'कमल',
          'தாமரை',
          'thamarai',
          'താമര',
          'తామర',
          'ಕಮಲ',
          'পদ্ম',
        ],
        choices: ['Lotus', 'Table', 'Train'],
      ),
    ],
    3: [
      _VoiceRiddleItem(
        spokenRiddle:
            'Listen to this short story: Meena went to the temple on Friday morning and bought fresh white jasmine flowers. Which flowers did Meena buy?',
        primaryAnswer: 'Jasmine',
        emoji: '🌼',
        acceptedKeywords: [
          'jasmine',
          'malligai',
          'மல்லிகை',
          'chameli',
          'mogra',
          'चमेली',
          'मोगरा',
          'മുല്ല',
          'మల్లె',
          'ಮಲ್ಲಿಗೆ',
          'জুঁই',
          'white flower',
          'flowers',
        ],
        choices: ['Jasmine', 'Marigold', 'Sunflower'],
      ),
      _VoiceRiddleItem(
        spokenRiddle:
            'Listen to this short story: Ravi travelled by train to visit his grandmother in Coimbatore and brought sweet bananas. How did Ravi travel?',
        primaryAnswer: 'Train',
        emoji: '🚆',
        acceptedKeywords: [
          'train',
          'railway',
          'rail',
          'रेल',
          'रेलगाड़ी',
          'ரயில்',
          'rayil',
          'ട്രെയിൻ',
          'రైలు',
          'ರೈಲು',
          'ট্রেন',
        ],
        choices: ['Train', 'Bicycle', 'Boat'],
      ),
      _VoiceRiddleItem(
        spokenRiddle:
            'Listen to this short story: Every evening, Grandfather sits in the garden and plays the flute while birds listen. Which musical instrument does Grandfather play?',
        primaryAnswer: 'Flute',
        emoji: '🪈',
        acceptedKeywords: [
          'flute',
          'bansuri',
          'बांसुरी',
          'புல்லாங்குழல்',
          'pullanguzhal',
          'ഓടക്കുഴൽ',
          'वेणुవు',
          'ಕೊಳಲು',
          'বাঁশি',
        ],
        choices: ['Flute', 'Drum', 'Bell'],
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _initAdaptiveGame();
  }

  @override
  void dispose() {
    VoiceService.stop();
    super.dispose();
  }

  Future<void> _initAdaptiveGame() async {
    final level = await AIEngine.getAdaptiveDifficulty('voice_talk');
    if (!mounted) return;
    _setupGame(level);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showInstructionsDialog(
        context,
        title: '🗣️ Voice Riddle & Talk',
        message:
            '1. Listen carefully as MindMitra speaks a gentle riddle or short story.\n'
            '2. Tap the Microphone and speak your answer aloud in English or any Indian language!\n'
            '3. Our AI Listener will verify your spoken answer.',
        onStart: _speakCurrentRiddle,
      );
    });
  }

  void _setupGame(int level) {
    VoiceService.stop();
    final bank = List<_VoiceRiddleItem>.from(_riddleBank[level] ?? _riddleBank[1]!);
    bank.shuffle(Random());
    setState(() {
      _difficulty = level;
      _round = 0;
      _mistakes = 0;
      _totalAttempts = 0;
      _isCompleted = false;
      _isSpeaking = false;
      _isListening = false;
      _isCheckingAI = false;
      _roundSolved = false;
      _showEmojiHint = (level == 1);
      _liveTranscript = '';
      _feedbackText = 'Listen to the question and speak your answer into the microphone!';
      _rounds = bank.take(_totalRounds).toList();
      _startTime = DateTime.now();
    });
  }

  _VoiceRiddleItem get _currentItem => _rounds[_round];

  void _speakCurrentRiddle() {
    if (!mounted || _isCompleted) return;
    VoiceService.stop();
    setState(() {
      _isSpeaking = true;
      _isListening = false;
      _feedbackText = '🔊 Listening to MindMitra...';
    });

    VoiceService.speak(
      _currentItem.spokenRiddle,
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _feedbackText = '🎤 Tap the Microphone and speak your answer aloud!';
        });
      },
    );
  }

  void _toggleMic() {
    if (_roundSolved || _isCheckingAI) return;
    if (_isSpeaking) {
      VoiceService.stop();
      setState(() => _isSpeaking = false);
    }
    if (_isListening) {
      VoiceService.finishListening();
      return;
    }

    setState(() {
      _isListening = true;
      _liveTranscript = '';
      _feedbackText = '🔴 AI Listening... Speak your answer naturally!';
    });

    VoiceService.listenToUserVoice(
      onInterim: (interim) {
        if (!mounted || _roundSolved) return;
        setState(() => _liveTranscript = interim);
        // Instant realtime match if the spoken phrase clearly contains the answer!
        if (_matchesLocally(interim)) {
          VoiceService.stop();
          _handleCorrectAnswer(interim);
        }
      },
      onResult: (finalText) {
        if (!mounted || _roundSolved) return;
        setState(() {
          _isListening = false;
          _liveTranscript = finalText;
        });
        _evaluateSpokenAnswer(finalText);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _feedbackText = 'Could not hear clearly ($err). Tap the Mic to try again or tap one of the answer buttons below!';
        });
      },
    );
  }

  bool _matchesLocally(String spokenText) {
    final clean = spokenText.toLowerCase().trim();
    if (clean.isEmpty) return false;
    final tokens = clean.split(RegExp(r'\s+'));

    for (final kw in _currentItem.acceptedKeywords) {
      final kwLower = kw.toLowerCase();
      if (clean.contains(kwLower)) return true;
      for (final token in tokens) {
        final stripped = token.replaceAll(RegExp(r'[^\w\u0900-\u0DFF]'), '');
        if (stripped.length >= 3 && kwLower.length >= 3) {
          if (_levenshtein(stripped, kwLower) <= 1) return true;
        }
      }
    }
    return false;
  }

  int _levenshtein(String a, String b) {
    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }
    return dp[m][n];
  }

  Future<void> _evaluateSpokenAnswer(String spokenText) async {
    if (_roundSolved) return;
    _totalAttempts++;

    if (_matchesLocally(spokenText)) {
      _handleCorrectAnswer(spokenText);
      return;
    }

    // Use Google Gemini AI Semantic Judge for multilingual / conversational answers!
    if (StorageService.isOnlineNotifier.value && spokenText.trim().isNotEmpty) {
      setState(() {
        _isCheckingAI = true;
        _feedbackText = '✨ AI is checking your answer "$spokenText"...';
      });

      final prompt = [
        {
          'role': 'system',
          'content':
              'You are an empathetic judge for a cognitive riddle game for elderly Indian users. '
              'Question: "${_currentItem.spokenRiddle}". Expected answer: "${_currentItem.primaryAnswer}" (or its translation/synonym in any Indian language like Tamil, Hindi, Malayalam, Telugu, Kannada, Bengali, Assamese). '
              'Reply ONLY with the single word YES if the user\'s spoken response means "${_currentItem.primaryAnswer}" or is phonetically close to it, otherwise reply NO.'
        },
        {'role': 'user', 'content': spokenText},
      ];

      final aiVerdict = await PlatformVoice.askAI(
        jsonEncode(prompt),
        StorageService.geminiApiKeyNotifier.value,
      );

      if (!mounted) return;
      setState(() => _isCheckingAI = false);

      if (aiVerdict != null && aiVerdict.toUpperCase().contains('YES')) {
        _handleCorrectAnswer(spokenText);
        return;
      }
    }

    // If not matched yet, show visual hint and encourage gently
    _mistakes++;
    setState(() {
      _showEmojiHint = true;
      _feedbackText =
          'Good try! Look at the picture clue (${_currentItem.emoji}) or tap the Microphone to say "${_currentItem.primaryAnswer}".';
    });
    VoiceService.speak('Good try! Here is a picture hint to help you. Try saying ${_currentItem.primaryAnswer}.');
  }

  void _handleCorrectAnswer(String spokenText) {
    if (_roundSolved) return;
    setState(() {
      _roundSolved = true;
      _isListening = false;
      _showEmojiHint = true;
      _feedbackText = '🎉 Correct! The answer is ${_currentItem.primaryAnswer} ${_currentItem.emoji}!';
    });

    if (_round + 1 < _totalRounds) {
      VoiceService.speak(
        'Wonderful! ${_currentItem.primaryAnswer} is completely right! Let us listen to the next one.',
        onDone: () {
          if (!mounted) return;
          setState(() {
            _round++;
            _roundSolved = false;
            _liveTranscript = '';
            _showEmojiHint = (_difficulty == 1);
          });
          _speakCurrentRiddle();
        },
      );
    } else {
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    final duration = DateTime.now().difference(_startTime).inSeconds;
    final score = max(60, 100 - (_mistakes * 10));

    final session = GameSession(
      id: 'voice_talk_${DateTime.now().millisecondsSinceEpoch}',
      gameType: 'voice_talk',
      gameName: 'Voice Riddle & Talk',
      timestamp: DateTime.now(),
      durationSeconds: max(1, duration),
      score: score,
      mistakes: _mistakes,
      totalAttempts: max(1, _totalAttempts),
      difficultyLevel: _difficulty,
    );

    await StorageService.saveGameSession(session);
    await AIEngine.recomputeCognitiveScore();

    if (mounted) {
      VoiceService.speak('Bravo! You finished all the Voice Riddles with a score of $score percent!');
      setState(() => _isCompleted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _currentItem;

    return Scaffold(
      backgroundColor: kMindMitraBackground,
      appBar: AppBar(
        backgroundColor: kMindMitraGreen,
        title: Text('Voice Riddle & Talk (L$_difficulty)'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Select Difficulty',
            onSelected: (lvl) {
              _setupGame(lvl);
              _speakCurrentRiddle();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 1, child: Text('Level 1: Easy (With Picture Clue)')),
              PopupMenuItem(value: 2, child: Text('Level 2: Medium (Listen First)')),
              PopupMenuItem(value: 3, child: Text('Level 3: Story Comprehension')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _isCompleted
            ? ResultsView(
                message:
                    'Listening & Naming Score: ${max(60, 100 - (_mistakes * 10))}%\n'
                    'Riddles Solved: $_totalRounds / $_totalRounds\n'
                    'Mistakes: $_mistakes',
                onPlayAgain: () {
                  _setupGame(_difficulty);
                  _speakCurrentRiddle();
                },
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${_round + 1} of $_totalRounds',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _showEmojiHint = !_showEmojiHint),
                          icon: const Icon(Icons.lightbulb_outline_rounded),
                          label: Text(_showEmojiHint ? 'Hide Clue' : 'Show Picture Clue'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Riddle / Story Audio Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              _showEmojiHint ? item.emoji : '🎧❓',
                              style: const TextStyle(fontSize: 60),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.spokenRiddle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                                color: Color(0xFF2F4F44),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSpeaking ? const Color(0xFF0288D1) : kMindMitraGreen,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 52),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _speakCurrentRiddle,
                              icon: Icon(_isSpeaking ? Icons.volume_up_rounded : Icons.replay_rounded),
                              label: Text(
                                _isSpeaking ? 'Speaking Question...' : '🔊 Listen to Question Again',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Microphone Answer Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text(
                              'Speak Your Answer (Any Indian Language or English)',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: _toggleMic,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: _isListening ? 94 : 82,
                                height: _isListening ? 94 : 82,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isListening ? const Color(0xFFE53935) : kMindMitraGreen,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isListening ? Colors.red : kMindMitraGreen).withOpacity(0.35),
                                      blurRadius: _isListening ? 22 : 12,
                                      spreadRadius: _isListening ? 6 : 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                  size: 42,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _isListening
                                  ? '🔴 Listening... Say the answer aloud!'
                                  : (_isCheckingAI ? '✨ AI Checking...' : 'Tap Microphone to Answer by Voice'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isListening ? const Color(0xFFE53935) : const Color(0xFF2F4F44),
                              ),
                            ),
                            if (_liveTranscript.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Heard: "$_liveTranscript"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black87),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              _feedbackText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, color: Colors.black54),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text(
                              'Or tap an option below:',
                              style: TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: item.choices.map((choice) {
                                return OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: kMindMitraGreen, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  ),
                                  onPressed: () {
                                    if (choice == item.primaryAnswer) {
                                      _totalAttempts++;
                                      _handleCorrectAnswer(choice);
                                    } else {
                                      _totalAttempts++;
                                      _mistakes++;
                                      setState(() {
                                        _showEmojiHint = true;
                                        _feedbackText = 'Not quite "$choice". Try speaking or tapping the right answer!';
                                      });
                                    }
                                  },
                                  child: Text(
                                    choice,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
