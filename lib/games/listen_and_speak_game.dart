import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_session.dart';
import '../services/storage_service.dart';
import '../services/ai_engine.dart';
import '../services/voice_service.dart';
import '../services/localization_service.dart';
import 'games_screen.dart';

class _ListenSpeakChallenge {
  final String spokenPrompt;
  final List<String> targetWords;
  final List<String> emojis;
  final Map<String, List<String>> acceptedSynonyms;

  const _ListenSpeakChallenge({
    required this.spokenPrompt,
    required this.targetWords,
    required this.emojis,
    this.acceptedSynonyms = const {},
  });
}

/// Game 5: AI Listen & Speak Game (Auditory Memory & Verbal Recall)
/// MindMitra speaks a sequence of warm, familiar words or phrases aloud.
/// The player listens carefully and speaks them back into the microphone.
/// Real-time AI phonetic & multilingual matching lights up each word as spoken!
class ListenAndSpeakGame extends StatefulWidget {
  const ListenAndSpeakGame({super.key});

  @override
  State<ListenAndSpeakGame> createState() => _ListenAndSpeakGameState();
}

class _ListenAndSpeakGameState extends State<ListenAndSpeakGame> {
  int _difficulty = 1; // 1 = 3 words, 2 = 4 words, 3 = 5 words
  int _round = 0;
  final int _totalRounds = 3;

  int _mistakes = 0;
  int _totalAttempts = 0;
  bool _isCompleted = false;
  bool _isSpeakingPrompt = false;
  bool _isListening = false;
  bool _showVisualHints = false;
  String _liveTranscript = '';
  String _feedbackText = '';
  DateTime _startTime = DateTime.now();

  late List<_ListenSpeakChallenge> _roundChallenges;
  final Set<int> _matchedWordIndices = {};

  static const Map<int, List<_ListenSpeakChallenge>> _levelChallenges = {
    1: [
      _ListenSpeakChallenge(
        spokenPrompt: 'Please listen carefully and say these three words: Mango, Temple, Morning.',
        targetWords: ['Mango', 'Temple', 'Morning'],
        emojis: ['🥭', '🛕', '🌅'],
        acceptedSynonyms: {
          'Mango': ['mango', 'mangoes', 'aam', 'आम', 'மாம்பழம்', 'mampazham'],
          'Temple': ['temple', 'mandir', 'मंदिर', 'கோவில்', 'kovil'],
          'Morning': ['morning', 'subah', 'सुबह', 'காலை', 'kaalai'],
        },
      ),
      _ListenSpeakChallenge(
        spokenPrompt: 'Please listen carefully and say these three words: Lotus, River, Music.',
        targetWords: ['Lotus', 'River', 'Music'],
        emojis: ['🪷', '🏞️', '🎵'],
        acceptedSynonyms: {
          'Lotus': ['lotus', 'kamal', 'कमल', 'தாமரை', 'thamarai'],
          'River': ['river', 'nadi', 'नदी', 'ஆறு', 'aaru'],
          'Music': ['music', 'song', 'संगीत', 'இசை', 'isai'],
        },
      ),
      _ListenSpeakChallenge(
        spokenPrompt: 'Please listen carefully and say these three words: Garden, Sunshine, Family.',
        targetWords: ['Garden', 'Sunshine', 'Family'],
        emojis: ['🌻', '☀️', '👨‍👩‍👧'],
        acceptedSynonyms: {
          'Garden': ['garden', 'bagicha', 'बगीचा', 'தோட்டம்', 'thottam'],
          'Sunshine': ['sunshine', 'sun', 'धूप', 'सूरज', 'வெயில்', 'சூரியன்'],
          'Family': ['family', 'parivar', 'परिवार', 'குடும்பம்', 'kudumbam'],
        },
      ),
    ],
    2: [
      _ListenSpeakChallenge(
        spokenPrompt: 'Listen and repeat these four words: Warm, Tea, Green, Hills.',
        targetWords: ['Warm', 'Tea', 'Green', 'Hills'],
        emojis: ['☕', '🍵', '🌿', '⛰️'],
        acceptedSynonyms: {
          'Warm': ['warm', 'hot', 'garam', 'गर्म', 'சூடான'],
          'Tea': ['tea', 'chai', 'चाय', 'தேநீர்', 'டீ'],
          'Green': ['green', 'hara', 'हरा', 'பச்சை'],
          'Hills': ['hills', 'hill', 'mountain', 'पहाड़', 'மலை'],
        },
      ),
      _ListenSpeakChallenge(
        spokenPrompt: 'Listen and repeat these four words: Sweet, Coconut, Peaceful, Home.',
        targetWords: ['Sweet', 'Coconut', 'Peaceful', 'Home'],
        emojis: ['🍯', '🥥', '🕊️', '🏡'],
        acceptedSynonyms: {
          'Sweet': ['sweet', 'meetha', 'मीठा', 'இனிப்பு'],
          'Coconut': ['coconut', 'nariyal', 'नारियल', 'தேங்காய்'],
          'Peaceful': ['peaceful', 'peace', 'calm', 'शांत', 'அமைதி'],
          'Home': ['home', 'house', 'ghar', 'घर', 'வீடு'],
        },
      ),
      _ListenSpeakChallenge(
        spokenPrompt: 'Listen and repeat these four words: Blue, Sky, Singing, Birds.',
        targetWords: ['Blue', 'Sky', 'Singing', 'Birds'],
        emojis: ['💙', '☁️', '🎶', '🐦'],
        acceptedSynonyms: {
          'Blue': ['blue', 'neela', 'नीला', 'நீலம்'],
          'Sky': ['sky', 'aasman', 'आसमान', 'வானம்'],
          'Singing': ['singing', 'sing', 'song', 'गाना', 'பாடும்'],
          'Birds': ['birds', 'bird', 'panchi', 'पक्षी', 'பறவைகள்'],
        },
      ),
    ],
    3: [
      _ListenSpeakChallenge(
        spokenPrompt: 'Listen and repeat these five words: Golden, Lamp, Jasmine, Flower, Evening.',
        targetWords: ['Golden', 'Lamp', 'Jasmine', 'Flower', 'Evening'],
        emojis: ['✨', '🪔', '🌼', '🌸', '🌇'],
        acceptedSynonyms: {
          'Golden': ['golden', 'gold', 'सुनहरा', 'தங்கம்'],
          'Lamp': ['lamp', 'diya', 'दीया', 'விளக்கு'],
          'Jasmine': ['jasmine', 'mogra', 'चमेली', 'மல்லிகை'],
          'Flower': ['flower', 'phool', 'फूल', 'பூ'],
          'Evening': ['evening', 'shaam', 'शाम', 'மாலை'],
        },
      ),
      _ListenSpeakChallenge(
        spokenPrompt: 'Listen and repeat these five words: Fresh, Rain, Cool, Breeze, Village.',
        targetWords: ['Fresh', 'Rain', 'Cool', 'Breeze', 'Village'],
        emojis: ['🌱', '🌧️', '❄️', '🍃', '🏘️'],
        acceptedSynonyms: {
          'Fresh': ['fresh', 'taaza', 'ताज़ा', 'புதிய'],
          'Rain': ['rain', 'baarish', 'बारिश', 'மழை'],
          'Cool': ['cool', 'cold', 'ठंडा', 'குளிர்ந்த'],
          'Breeze': ['breeze', 'wind', 'hawa', 'हवा', 'காற்று'],
          'Village': ['village', 'gaon', 'गांव', 'கிராமம்'],
        },
      ),
      _ListenSpeakChallenge(
        spokenPrompt: 'Listen and repeat these five words: Happy, Children, Playing, Under, Tree.',
        targetWords: ['Happy', 'Children', 'Playing', 'Under', 'Tree'],
        emojis: ['😊', '👧', '⚽', '⬇️', '🌳'],
        acceptedSynonyms: {
          'Happy': ['happy', 'khush', 'खुश', 'மகிழ்ச்சி'],
          'Children': ['children', 'kids', 'child', 'बच्चे', 'குழந்தைகள்'],
          'Playing': ['playing', 'play', 'खेल', 'விளையாடும்'],
          'Under': ['under', 'below', 'नीचे', 'கீழே'],
          'Tree': ['tree', 'trees', 'ped', 'पेड़', 'மரம்'],
        },
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
    final level = await AIEngine.getAdaptiveDifficulty('listen_speak');
    if (!mounted) return;
    _setupGame(level);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showInstructionsDialog(
        context,
        title: '🎧 Listen & Speak Game',
        message:
            '1. Listen carefully as MindMitra speaks $_difficulty_wordCountLabel aloud.\n'
            '2. Tap the Microphone and repeat the words clearly.\n'
            '3. Each word will light up green as our AI hears you say it!',
        onStart: _speakCurrentRoundPrompt,
      );
    });
  }

  String get _difficulty_wordCountLabel {
    if (_difficulty == 1) return '3 everyday words';
    if (_difficulty == 2) return '4 gentle words';
    return '5 story words';
  }

  void _setupGame(int level) {
    VoiceService.stop();
    final list = List<_ListenSpeakChallenge>.from(_levelChallenges[level] ?? _levelChallenges[1]!);
    list.shuffle(Random());
    setState(() {
      _difficulty = level;
      _round = 0;
      _mistakes = 0;
      _totalAttempts = 0;
      _isCompleted = false;
      _isSpeakingPrompt = false;
      _isListening = false;
      _showVisualHints = false;
      _liveTranscript = '';
      _feedbackText = 'Tap "Listen to Words" to hear the phrase.';
      _roundChallenges = list.take(_totalRounds).toList();
      _matchedWordIndices.clear();
      _startTime = DateTime.now();
    });
  }

  _ListenSpeakChallenge get _currentChallenge => _roundChallenges[_round];

  void _speakCurrentRoundPrompt() {
    if (!mounted || _isCompleted) return;
    VoiceService.stop();
    setState(() {
      _isSpeakingPrompt = true;
      _isListening = false;
      _feedbackText = '🔊 Listening to MindMitra... Remember the words!';
    });

    VoiceService.speak(
      _currentChallenge.spokenPrompt,
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isSpeakingPrompt = false;
          _feedbackText = '🎤 Now tap the Microphone and say the words aloud!';
        });
      },
    );
  }

  void _toggleMicrophone() {
    if (_isSpeakingPrompt) {
      VoiceService.stop();
      setState(() => _isSpeakingPrompt = false);
    }
    if (_isListening) {
      VoiceService.finishListening();
      return;
    }

    setState(() {
      _isListening = true;
      _liveTranscript = '';
      _feedbackText = '🔴 Listening... Speak the words clearly at your own pace!';
    });

    VoiceService.listenToUserVoice(
      onInterim: (interim) {
        if (!mounted || _isCompleted) return;
        setState(() {
          _liveTranscript = interim;
        });
        _checkSpokenWordsRealtime(interim, isFinal: false);
      },
      onResult: (finalText) {
        if (!mounted || _isCompleted) return;
        setState(() {
          _isListening = false;
          _liveTranscript = finalText;
        });
        _checkSpokenWordsRealtime(finalText, isFinal: true);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _feedbackText = 'Could not hear clearly ($err). Tap the Microphone to try speaking again, or tap the word cards below!';
        });
      },
    );
  }

  /// Accurate AI Phonetic & Synonym Matcher:
  /// Checks spoken words in real time against target words, multilingual synonyms,
  /// and phonetic Levenshtein similarity so regional accents are accurately recognized.
  void _checkSpokenWordsRealtime(String transcript, {required bool isFinal}) {
    final cleanSpoken = transcript.toLowerCase().replaceAll(RegExp(r'[^\w\s\u0900-\u0DFF]'), ' ');
    final spokenTokens = cleanSpoken.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    final targets = _currentChallenge.targetWords;
    bool newlyMatched = false;

    for (int i = 0; i < targets.length; i++) {
      if (_matchedWordIndices.contains(i)) continue;
      final word = targets[i];
      final synonyms = _currentChallenge.acceptedSynonyms[word] ?? [word.toLowerCase()];

      bool matched = false;
      for (final syn in synonyms) {
        final synLower = syn.toLowerCase();
        if (cleanSpoken.contains(synLower)) {
          matched = true;
          break;
        }
        for (final token in spokenTokens) {
          if (_isPhoneticMatch(token, synLower)) {
            matched = true;
            break;
          }
        }
        if (matched) break;
      }

      if (matched) {
        _matchedWordIndices.add(i);
        newlyMatched = true;
      }
    }

    if (newlyMatched) {
      setState(() {});
    }

    // If all words in this round are matched!
    if (_matchedWordIndices.length == targets.length) {
      VoiceService.stop();
      _totalAttempts++;
      _advanceAfterRoundSuccess();
      return;
    }

    if (isFinal) {
      _totalAttempts++;
      final remaining = targets.length - _matchedWordIndices.length;
      if (_matchedWordIndices.isNotEmpty) {
        setState(() {
          _feedbackText =
              'Great job! You got ${_matchedWordIndices.length} of ${targets.length} words. Tap the Mic to say the remaining $remaining word(s)!';
        });
      } else {
        _mistakes++;
        setState(() {
          _showVisualHints = true;
          _feedbackText =
              'Let\'s try together! I have shown the word hints below. Tap "🔊 Hear Again" or speak the words into the Mic.';
        });
      }
    }
  }

  /// Fuzzy phonetic similarity check (allows 1-2 character differences for Indian accents)
  bool _isPhoneticMatch(String spoken, String target) {
    if (spoken == target) return true;
    if (spoken.length < 3 || target.length < 3) return spoken == target;
    if (spoken.startsWith(target.substring(0, min(4, target.length))) &&
        (spoken.length - target.length).abs() <= 2) {
      return true;
    }
    final dist = _levenshtein(spoken, target);
    final maxAllowed = target.length >= 6 ? 2 : 1;
    return dist <= maxAllowed;
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

  void _onWordCardTapped(int index) {
    if (_matchedWordIndices.contains(index)) return;
    final word = _currentChallenge.targetWords[index];
    VoiceService.speak(word);
    setState(() {
      _matchedWordIndices.add(index);
    });
    if (_matchedWordIndices.length == _currentChallenge.targetWords.length) {
      _totalAttempts++;
      _advanceAfterRoundSuccess();
    }
  }

  void _advanceAfterRoundSuccess() {
    setState(() {
      _isListening = false;
      _feedbackText = '🎉 Wonderful! You recalled all ${_currentChallenge.targetWords.length} words!';
    });

    if (_round + 1 < _totalRounds) {
      VoiceService.speak(
        'Wonderful recall! Get ready for the next set of words.',
        onDone: () {
          if (!mounted) return;
          setState(() {
            _round++;
            _matchedWordIndices.clear();
            _liveTranscript = '';
            _showVisualHints = false;
          });
          _speakCurrentRoundPrompt();
        },
      );
    } else {
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    final duration = DateTime.now().difference(_startTime).inSeconds;
    final score = max(55, 100 - (_mistakes * 10));

    final session = GameSession(
      id: 'listen_speak_${DateTime.now().millisecondsSinceEpoch}',
      gameType: 'listen_speak',
      gameName: 'Listen & Speak',
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
      VoiceService.speak('Fantastic job! You completed the Listen and Speak game with a score of $score percent!');
      setState(() => _isCompleted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _currentChallenge;

    return Scaffold(
      backgroundColor: kMindMitraBackground,
      appBar: AppBar(
        backgroundColor: kMindMitraGreen,
        title: Text('Listen & Speak (L$_difficulty)'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Select Difficulty',
            onSelected: (lvl) {
              _setupGame(lvl);
              _speakCurrentRoundPrompt();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 1, child: Text('Level 1: Easy (3 Words)')),
              PopupMenuItem(value: 2, child: Text('Level 2: Medium (4 Words)')),
              PopupMenuItem(value: 3, child: Text('Level 3: Advanced (5 Words)')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _isCompleted
            ? ResultsView(
                message:
                    'Auditory Recall Score: ${max(55, 100 - (_mistakes * 10))}%\n'
                    'Rounds Completed: $_totalRounds / $_totalRounds\n'
                    'Mistakes: $_mistakes',
                onPlayAgain: () {
                  _setupGame(_difficulty);
                  _speakCurrentRoundPrompt();
                },
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Round Progress Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Round ${_round + 1} of $_totalRounds',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _showVisualHints = !_showVisualHints),
                          icon: Icon(_showVisualHints ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                          label: Text(_showVisualHints ? 'Hide Hints' : 'Show Word Hints'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Step 1 Card: Listen to MindMitra
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            const Text(
                              'Step 1: Listen Carefully 👂',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSpeakingPrompt ? const Color(0xFF0288D1) : kMindMitraGreen,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 54),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _speakCurrentRoundPrompt,
                              icon: Icon(_isSpeakingPrompt ? Icons.volume_up_rounded : Icons.replay_rounded, size: 26),
                              label: Text(
                                _isSpeakingPrompt ? 'Speaking Words Now...' : '🔊 Hear Words Again',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Target Words Cards (Light up Green as AI hears them!)
                    const Text(
                      'Words to Recall (Lights up ✅ as you speak):',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: List.generate(challenge.targetWords.length, (idx) {
                        final isMatched = _matchedWordIndices.contains(idx);
                        final word = challenge.targetWords[idx];
                        final emoji = challenge.emojis[idx];
                        return GestureDetector(
                          onTap: () => _onWordCardTapped(idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 145,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isMatched ? const Color(0xFFE8F5E9) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isMatched ? const Color(0xFF2E7D32) : kMindMitraGreen,
                                width: isMatched ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isMatched || _showVisualHints ? emoji : '🎧',
                                  style: const TextStyle(fontSize: 36),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isMatched
                                      ? '✅ $word'
                                      : (_showVisualHints ? word : 'Word ${idx + 1}'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isMatched ? const Color(0xFF2E7D32) : const Color(0xFF2F4F44),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),

                    // Step 2 Card: Microphone Orb for Accurate AI Listening
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text(
                              'Step 2: Speak the Words Aloud 🎤',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: _toggleMicrophone,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: _isListening ? 96 : 84,
                                height: _isListening ? 96 : 84,
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
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isListening
                                  ? '🔴 AI Listening... Speak now (or tap when done)'
                                  : 'Tap Microphone to Speak',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isListening ? const Color(0xFFE53935) : const Color(0xFF2F4F44),
                              ),
                            ),
                            if (_liveTranscript.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F7F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'You said: "$_liveTranscript"',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black87),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              _feedbackText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, color: Colors.black54),
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
