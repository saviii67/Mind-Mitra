import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_session.dart';
import '../services/storage_service.dart';
import '../services/ai_engine.dart';
import '../services/voice_service.dart';
import '../services/localization_service.dart';
import 'games_screen.dart';

/// Simon-Says style Sequence Game with AI Adaptive & Manual Level/Speed selection
/// Responsive layout: all 4 color pads + Replay button fit on screen without scrolling.
class SequenceGame extends StatefulWidget {
  const SequenceGame({super.key});

  @override
  State<SequenceGame> createState() => _SequenceGameState();
}

class _SequenceGameState extends State<SequenceGame> {
  final List<Color> _colors = const [
    Color(0xFFFF8A8A), // Coral Red
    Color(0xFFFFCA7A), // Warm Amber
    Color(0xFF8CE99A), // Mint Green
    Color(0xFF74C0FC), // Sky Blue
  ];

  final List<String> _colorNames = const [
    'Coral',
    'Amber',
    'Green',
    'Blue',
  ];

  final List<int> _sequence = [];
  int _playerStep = 0;
  int _round = 1;
  int _maxRounds = 3;
  int _adaptiveLevel = 1; // 1 = Slow, 2 = Normal, 3 = Fast
  bool _watching = false;
  int? _litIndex;
  String _statusText = 'Get ready to watch the sequence...';
  bool _showResults = false;
  int _mistakes = 0;
  DateTime _startTime = DateTime.now();
  int _sessionGen = 0; // Cancels stale async loops when level changes

  @override
  void initState() {
    super.initState();
    _initGameWithAI();
  }

  Future<void> _initGameWithAI() async {
    final aiLevel = await AIEngine.getAdaptiveDifficulty('sequence');
    if (!mounted) return;
    _applyLevelConfig(aiLevel);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prompt = VoiceService.getGameVoiceInstruction('sequence');
      VoiceService.speak(prompt);
      _startGame();
    });
  }

  void _applyLevelConfig(int level) {
    setState(() {
      _adaptiveLevel = level;
      _maxRounds = level == 1 ? 3 : (level == 2 ? 4 : 5);
    });
  }

  void _changeLevelManually(int newLevel) {
    _sessionGen++;
    _applyLevelConfig(newLevel);
    _startGame();
  }

  @override
  void dispose() {
    _sessionGen++;
    VoiceService.stop();
    super.dispose();
  }

  void _startGame() {
    _sessionGen++;
    final int myGen = _sessionGen;
    setState(() {
      _sequence.clear();
      _round = 1;
      _mistakes = 0;
      _showResults = false;
      _litIndex = null;
      _watching = false;
      _startTime = DateTime.now();
    });
    _nextRound(myGen);
  }

  void _nextRound(int gen) {
    if (!mounted || gen != _sessionGen) return;
    _sequence.add(Random().nextInt(_colors.length));
    _playerStep = 0;
    setState(() {
      _watching = true;
      _statusText = 'Round $_round of $_maxRounds — Watch the colors light up 👀';
    });
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted && gen == _sessionGen) {
        _playSequence(gen);
      }
    });
  }

  Future<void> _playSequence(int gen) async {
    if (!mounted || gen != _sessionGen) return;
    setState(() {
      _watching = true;
      _litIndex = null;
      _playerStep = 0;
      _statusText = 'Round $_round of $_maxRounds — Watch carefully 👀';
    });

    final flashMs = _adaptiveLevel == 1 ? 750 : (_adaptiveLevel == 2 ? 500 : 320);
    final pauseMs = _adaptiveLevel == 1 ? 350 : (_adaptiveLevel == 2 ? 250 : 170);

    await Future.delayed(const Duration(milliseconds: 300));

    for (final colorIndex in _sequence) {
      if (!mounted || gen != _sessionGen) return;
      setState(() => _litIndex = colorIndex);
      await Future.delayed(Duration(milliseconds: flashMs));
      if (!mounted || gen != _sessionGen) return;
      setState(() => _litIndex = null);
      await Future.delayed(Duration(milliseconds: pauseMs));
    }

    if (!mounted || gen != _sessionGen) return;
    setState(() {
      _watching = false;
      _statusText = 'Your Turn! Tap ${_sequence.length} color(s) in the same order 👇';
    });
  }

  void _onButtonTap(int colorIndex) {
    if (_watching || _showResults || _sequence.isEmpty) return;

    final int myGen = _sessionGen;
    setState(() => _litIndex = colorIndex);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted && myGen == _sessionGen && !_watching) {
        setState(() => _litIndex = null);
      }
    });

    if (colorIndex == _sequence[_playerStep]) {
      _playerStep++;
      if (_playerStep == _sequence.length) {
        setState(() {
          _watching = true;
          _statusText = 'Great job! ✅ Round $_round complete!';
        });
        if (_round >= _maxRounds) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && myGen == _sessionGen) _completeGame();
          });
        } else {
          _round++;
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted && myGen == _sessionGen) _nextRound(myGen);
          });
        }
      } else {
        setState(() {
          _statusText = 'Good! Step $_playerStep of ${_sequence.length} ✅ Keep going!';
        });
      }
    } else {
      _mistakes++;
      setState(() {
        _watching = true;
        _playerStep = 0;
        _statusText = "Oops! Let's watch the sequence again 🌸";
      });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted && myGen == _sessionGen) _playSequence(myGen);
      });
    }
  }

  Future<void> _completeGame() async {
    final durationSeconds = max(5, DateTime.now().difference(_startTime).inSeconds);
    final score = (100 - (_mistakes * 8)).clamp(50, 100);

    final session = GameSession(
      id: 'seq_${DateTime.now().millisecondsSinceEpoch}',
      gameType: 'sequence',
      gameName: 'Sequence Game',
      timestamp: DateTime.now(),
      durationSeconds: durationSeconds,
      score: score,
      mistakes: _mistakes,
      totalAttempts: _maxRounds + _mistakes,
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
        title: Text('${LocalizationService.get('sequence_game')} • L$_adaptiveLevel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 26),
            tooltip: 'Restart Game',
            onPressed: _startGame,
          ),
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, size: 28),
            onPressed: () => VoiceService.speak(VoiceService.getGameVoiceInstruction('sequence')),
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
                  'Speed:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                ),
                _SeqLevelChip(
                  label: '🐢 L1 Slow',
                  selected: _adaptiveLevel == 1,
                  onTap: () => _changeLevelManually(1),
                ),
                _SeqLevelChip(
                  label: '🚶 L2 Normal',
                  selected: _adaptiveLevel == 2,
                  onTap: () => _changeLevelManually(2),
                ),
                _SeqLevelChip(
                  label: '⚡ L3 Fast',
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
                        'You completed all $_maxRounds rounds of the Sequence Game!\n'
                        'Speed: ${_adaptiveLevel == 1 ? "Slow" : (_adaptiveLevel == 2 ? "Normal" : "Fast")} • Mistakes: $_mistakes.',
                    onPlayAgain: _startGame,
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFDDE5E2)),
                              ),
                              child: Text(
                                _statusText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  const double spacing = 16.0;
                                  final double availW = max(100, constraints.maxWidth - spacing);
                                  final double availH = max(100, constraints.maxHeight - spacing);
                                  final double aspectRatio = ((availW / 2) / (availH / 2)).clamp(0.8, 2.4);

                                  return GridView.count(
                                    physics: const NeverScrollableScrollPhysics(),
                                    crossAxisCount: 2,
                                    mainAxisSpacing: spacing,
                                    crossAxisSpacing: spacing,
                                    childAspectRatio: aspectRatio,
                                    children: List.generate(_colors.length, (index) {
                                      final isLit = _litIndex == index;
                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(22),
                                          onTap: () => _onButtonTap(index),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 160),
                                            decoration: BoxDecoration(
                                              color: isLit ? _colors[index] : _colors[index].withOpacity(0.45),
                                              borderRadius: BorderRadius.circular(22),
                                              boxShadow: isLit
                                                  ? [
                                                      BoxShadow(
                                                        color: _colors[index].withOpacity(0.9),
                                                        blurRadius: 20,
                                                        spreadRadius: 4,
                                                      )
                                                    ]
                                                  : [
                                                      BoxShadow(
                                                        color: Colors.black.withOpacity(0.05),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      )
                                                    ],
                                              border: Border.all(
                                                color: isLit ? const Color(0xFF1B3B32) : Colors.black26,
                                                width: isLit ? 5 : 2,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isLit ? Icons.lightbulb_rounded : Icons.touch_app_rounded,
                                                  size: isLit ? 46 : 36,
                                                  color: isLit ? const Color(0xFF1B3B32) : Colors.black45,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  _colorNames[index],
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                    color: isLit ? const Color(0xFF1B3B32) : Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kMindMitraGreen,
                                minimumSize: const Size(240, 52),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _watching
                                  ? null
                                  : () {
                                      _sessionGen++;
                                      _playSequence(_sessionGen);
                                    },
                              icon: const Icon(Icons.replay_rounded, color: Colors.white),
                              label: const Text(
                                'Replay Sequence',
                                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
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

class _SeqLevelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SeqLevelChip({
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