import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_session.dart';
import '../services/storage_service.dart';
import '../services/ai_engine.dart';
import '../services/voice_service.dart';
import '../services/localization_service.dart';
import 'games_screen.dart';

/// Pattern Completion Game with AI Adaptive & Manual Level Selection
class PatternGame extends StatefulWidget {
  const PatternGame({super.key});

  @override
  State<PatternGame> createState() => _PatternGameState();
}

class _PatternGameState extends State<PatternGame> {
  final List<String> _allShapes = const ['🔺', '🔵', '🟩', '⭐', '🔶'];
  List<String> _baseShapes = const ['🔺', '🔵'];

  int _maxRounds = 3;
  int _sequenceLength = 4;
  int _adaptiveLevel = 1; // 1 = Easy, 2 = Medium, 3 = Hard

  int _round = 0;
  int _score = 0;
  int _mistakes = 0;
  List<String> _shownSequence = [];
  List<String> _options = [];
  String _correctAnswer = '';
  String? _selected;
  bool _answered = false;
  bool _showResults = false;
  DateTime _startTime = DateTime.now();
  Timer? _roundTimer;

  @override
  void initState() {
    super.initState();
    _applyLevelConfig(1);
    _startGame();
    _initGameWithAI();
  }

  Future<void> _initGameWithAI() async {
    final aiLevel = await AIEngine.getAdaptiveDifficulty('pattern');
    if (!mounted) return;
    _applyLevelConfig(aiLevel);
    _startGame();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prompt = VoiceService.getGameVoiceInstruction('pattern');
      VoiceService.speak(prompt);
    });
  }

  void _applyLevelConfig(int level) {
    _adaptiveLevel = level;
    if (level == 1) {
      _maxRounds = 3;
      _sequenceLength = 4;
      _baseShapes = _allShapes.sublist(0, 2); // 2 shapes: A B A B ?
    } else if (level == 2) {
      _maxRounds = 4;
      _sequenceLength = 5;
      _baseShapes = _allShapes.sublist(0, 3); // 3 shapes: A B C A B ?
    } else {
      _maxRounds = 5;
      _sequenceLength = 6;
      _baseShapes = _allShapes.sublist(0, 4); // 4 shapes: A B C D A B ?
    }
  }

  void _changeLevelManually(int newLevel) {
    _roundTimer?.cancel();
    setState(() {
      _applyLevelConfig(newLevel);
    });
    _startGame();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    VoiceService.stop();
    super.dispose();
  }

  void _startGame() {
    _roundTimer?.cancel();
    _round = 0;
    _score = 0;
    _mistakes = 0;
    _showResults = false;
    _startTime = DateTime.now();
    _nextRound();
  }

  void _nextRound() {
    _roundTimer?.cancel();
    _round++;
    if (_round > _maxRounds) {
      _completeGame();
      return;
    }

    final shuffledBase = [..._baseShapes]..shuffle();
    final sequence = List.generate(
      _sequenceLength,
      (i) => shuffledBase[i % shuffledBase.length],
    );
    final answer = shuffledBase[_sequenceLength % shuffledBase.length];
    final options = [..._baseShapes]..shuffle();

    if (mounted) {
      setState(() {
        _shownSequence = sequence;
        _correctAnswer = answer;
        _options = options;
        _selected = null;
        _answered = false;
      });
    }
  }

  void _onOptionTap(String shape) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selected = shape;
      if (shape == _correctAnswer) {
        _score++;
      } else {
        _mistakes++;
      }
    });
    _roundTimer = Timer(const Duration(milliseconds: 900), _nextRound);
  }

  Future<void> _completeGame() async {
    final durationSeconds = max(5, DateTime.now().difference(_startTime).inSeconds);
    final score = ((_score / _maxRounds) * 100).round().clamp(50, 100);

    final session = GameSession(
      id: 'pat_${DateTime.now().millisecondsSinceEpoch}',
      gameType: 'pattern',
      gameName: 'Pattern Game',
      timestamp: DateTime.now(),
      durationSeconds: durationSeconds,
      score: score,
      mistakes: _mistakes,
      totalAttempts: _maxRounds,
      difficultyLevel: _adaptiveLevel,
    );

    await StorageService.saveGameSession(session);
    await AIEngine.recomputeCognitiveScore();

    VoiceService.speak(LocalizationService.get('well_done'));

    if (mounted) {
      setState(() => _showResults = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMindMitraBackground,
      appBar: AppBar(
        backgroundColor: kMindMitraGreen,
        title: Text('${LocalizationService.get('pattern_game')} • L$_adaptiveLevel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 26),
            tooltip: 'Restart Game',
            onPressed: _startGame,
          ),
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, size: 28),
            onPressed: () => VoiceService.speak(VoiceService.getGameVoiceInstruction('pattern')),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                const Text(
                  'Level:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                ),
                _PatLevelChip(
                  label: 'L1 Easy',
                  selected: _adaptiveLevel == 1,
                  onTap: () => _changeLevelManually(1),
                ),
                _PatLevelChip(
                  label: 'L2 Medium',
                  selected: _adaptiveLevel == 2,
                  onTap: () => _changeLevelManually(2),
                ),
                _PatLevelChip(
                  label: 'L3 Hard',
                  selected: _adaptiveLevel == 3,
                  onTap: () => _changeLevelManually(3),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _showResults
                ? ResultsView(
                    message:
                        'Pattern Game complete! You deduced the correct shape $_score out of $_maxRounds times.\n'
                        'Level $_adaptiveLevel • Mistakes: $_mistakes',
                    onPlayAgain: _startGame,
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFDDE5E2)),
                              ),
                              child: Text(
                                'Round $_round of $_maxRounds — What comes next?',
                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  ..._shownSequence.map(
                                    (s) => Text(s, style: const TextStyle(fontSize: 42)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF9C4),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFBC02D), width: 2),
                                    ),
                                    child: const Text('❓', style: TextStyle(fontSize: 38)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            Text(
                              _answered
                                  ? (_selected == _correctAnswer
                                      ? 'Correct! ✅ (${_correctAnswer})'
                                      : 'The correct answer was $_correctAnswer')
                                  : 'Tap the shape that completes the pattern:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _answered
                                    ? (_selected == _correctAnswer ? const Color(0xFF2E7D32) : const Color(0xFFC92A2A))
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              alignment: WrapAlignment.center,
                              children: _options.map((shape) {
                                Color borderColor = kMindMitraGreen;
                                Color bgColor = Colors.white;
                                if (_answered) {
                                  if (shape == _correctAnswer) {
                                    bgColor = const Color(0xFFCAFFBF);
                                    borderColor = const Color(0xFF2F9E44);
                                  } else if (shape == _selected) {
                                    bgColor = const Color(0xFFFFC9C9);
                                    borderColor = const Color(0xFFC92A2A);
                                  }
                                }
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => _onOptionTap(shape),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        border: Border.all(color: borderColor, width: 3.5),
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.06),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(shape, style: const TextStyle(fontSize: 44)),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PatLevelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PatLevelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kMindMitraGreen : const Color(0xFFF0F4F3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kMindMitraGreen, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : const Color(0xFF2F4F44),
          ),
        ),
      ),
    );
  }
}