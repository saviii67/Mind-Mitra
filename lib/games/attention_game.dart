import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_session.dart';
import '../services/storage_service.dart';
import '../services/ai_engine.dart';
import '../services/voice_service.dart';
import '../services/localization_service.dart';
import 'games_screen.dart';

/// Attention & Vigilance Game
/// Each round flashes 1-2 decoy symbols first, followed by the target star ⭐.
/// Thus in N rounds, N stars are guaranteed to appear (no more confusing random counts!).
/// Includes Manual Level & Speed selector (L1 Slow, L2 Normal, L3 Fast).
class AttentionGame extends StatefulWidget {
  const AttentionGame({super.key});

  @override
  State<AttentionGame> createState() => _AttentionGameState();
}

class _AttentionGameState extends State<AttentionGame> {
  int _selectedLevel = 1; // 1 = Slow, 2 = Normal, 3 = Fast
  int _maxRounds = 5; // Every round has 1 star -> 5 stars total!
  int _starWindowMs = 3000; // How long the star stays visible
  int _decoyWindowMs = 1200; // How long each decoy flashes

  final List<String> _decoySymbols = const ['🔵', '🟩', '🟨', '🟥', '🟣', '🌸', '🍂'];

  int _round = 0;
  int _starsSpotted = 0;
  int _mistakes = 0; // Tapping on a decoy or missing a star

  String _currentSymbol = '';
  String _message = 'Choose your speed above or tap Start!';
  bool _targetIsShowing = false;
  bool _roundActive = false;
  bool _showResults = false;
  Timer? _stepTimer;
  DateTime _startTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initGameWithAI();
  }

  Future<void> _initGameWithAI() async {
    final aiLevel = await AIEngine.getAdaptiveDifficulty('attention');
    _applyLevelConfig(aiLevel);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prompt = VoiceService.getGameVoiceInstruction('attention');
      VoiceService.speak(prompt);
      _startGame();
    });
  }

  void _applyLevelConfig(int level) {
    setState(() {
      _selectedLevel = level;
      if (level == 1) {
        // Level 1: Slow & Gentle (3.0s to tap star, 5 stars total)
        _maxRounds = 5;
        _starWindowMs = 3000;
        _decoyWindowMs = 1300;
      } else if (level == 2) {
        // Level 2: Normal Speed (1.8s to tap star, 5 stars total)
        _maxRounds = 5;
        _starWindowMs = 1800;
        _decoyWindowMs = 1000;
      } else {
        // Level 3: Fast Speed (1.0s to tap star, 6 stars total)
        _maxRounds = 6;
        _starWindowMs = 1000;
        _decoyWindowMs = 700;
      }
    });
  }

  void _changeLevelManually(int newLevel) {
    _stepTimer?.cancel();
    _applyLevelConfig(newLevel);
    VoiceService.speak('Level $newLevel selected. Starting game.');
    _startGame();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    VoiceService.stop();
    super.dispose();
  }

  void _startGame() {
    _stepTimer?.cancel();
    setState(() {
      _round = 0;
      _starsSpotted = 0;
      _mistakes = 0;
      _showResults = false;
      _startTime = DateTime.now();
    });
    _nextRound();
  }

  void _nextRound() {
    _stepTimer?.cancel();
    _round++;
    if (_round > _maxRounds) {
      _completeGame();
      return;
    }

    setState(() {
      _message = 'Round $_round of $_maxRounds — Wait for ⭐...';
      _currentSymbol = '';
      _targetIsShowing = false;
      _roundActive = true;
    });

    // Each round shows 1 or 2 decoys first, then GUARANTEES showing the Star ⭐!
    final int numDecoysThisRound = 1 + Random().nextInt(2); // 1 or 2 decoys
    _playDecoySequence(numDecoysThisRound);
  }

  void _playDecoySequence(int remainingDecoys) {
    if (!mounted || !_roundActive) return;

    if (remainingDecoys <= 0) {
      // Now show the guaranteed STAR ⭐ for this round!
      _showStarNow();
      return;
    }

    _stepTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || !_roundActive) return;
      final decoy = _decoySymbols[Random().nextInt(_decoySymbols.length)];
      setState(() {
        _targetIsShowing = false;
        _currentSymbol = decoy;
        _message = 'Wait for ⭐ (Do not tap decoy)';
      });

      _stepTimer = Timer(Duration(milliseconds: _decoyWindowMs), () {
        if (!mounted || !_roundActive) return;
        setState(() {
          _currentSymbol = '';
        });
        _playDecoySequence(remainingDecoys - 1);
      });
    });
  }

  void _showStarNow() {
    if (!mounted || !_roundActive) return;

    _stepTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || !_roundActive) return;
      setState(() {
        _targetIsShowing = true;
        _currentSymbol = '⭐';
        _message = 'TAP THE STAR NOW! ⭐';
      });

      _stepTimer = Timer(Duration(milliseconds: _starWindowMs), () {
        if (!mounted || !_roundActive) return;
        // Player didn't tap the star in time
        setState(() {
          _roundActive = false;
          _targetIsShowing = false;
          _currentSymbol = '';
          _mistakes++;
          _message = 'Missed the star ⭐ — Next round coming!';
        });
        _stepTimer = Timer(const Duration(milliseconds: 1000), _nextRound);
      });
    });
  }

  void _onBoxTap() {
    if (!_roundActive || _currentSymbol.isEmpty) return;

    if (_targetIsShowing) {
      // Player tapped the STAR!
      _stepTimer?.cancel();
      setState(() {
        _roundActive = false;
        _targetIsShowing = false;
        _currentSymbol = '';
        _starsSpotted++;
        _message = 'Awesome! Spotted Star $_starsSpotted / $_maxRounds ✅';
      });
      _stepTimer = Timer(const Duration(milliseconds: 900), _nextRound);
    } else {
      // Player tapped a decoy!
      setState(() {
        _mistakes++;
        _message = 'Oops! That was a decoy ($_currentSymbol). Wait for ⭐!';
      });
    }
  }

  Future<void> _completeGame() async {
    final durationSeconds = max(5, DateTime.now().difference(_startTime).inSeconds);
    final baseAccuracy = ((_starsSpotted / _maxRounds) * 100).round();
    final score = (baseAccuracy - (_mistakes * 3)).clamp(50, 100);

    final session = GameSession(
      id: 'att_${DateTime.now().millisecondsSinceEpoch}',
      gameType: 'attention',
      gameName: 'Attention Game',
      timestamp: DateTime.now(),
      durationSeconds: durationSeconds,
      score: score,
      mistakes: _mistakes,
      totalAttempts: _maxRounds,
      difficultyLevel: _selectedLevel,
    );

    await StorageService.saveGameSession(session);
    await AIEngine.recomputeCognitiveScore();

    VoiceService.speak(
      'Well done! You spotted $_starsSpotted out of $_maxRounds stars.',
    );

    if (mounted) {
      setState(() => _showResults = true);
    }
  }

  String _getSpeedLabel(int level) {
    if (level == 1) return 'Slow (3.0s window)';
    if (level == 2) return 'Normal (1.8s window)';
    return 'Fast (1.0s window)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMindMitraBackground,
      appBar: AppBar(
        backgroundColor: kMindMitraGreen,
        title: Text('${LocalizationService.get('attention_game')} • L$_selectedLevel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, size: 28),
            tooltip: 'Speak Instructions',
            onPressed: () => VoiceService.speak(VoiceService.getGameVoiceInstruction('attention')),
          ),
        ],
      ),
      body: Column(
        children: [
          // Manual Speed & Level Selector Bar (Always visible at top)
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                const Text(
                  'Choose Speed / Level:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                ),
                _SpeedLevelChip(
                  label: '🐢 L1 Slow (3s)',
                  selected: _selectedLevel == 1,
                  onTap: () => _changeLevelManually(1),
                ),
                _SpeedLevelChip(
                  label: '🚶 L2 Normal (1.8s)',
                  selected: _selectedLevel == 2,
                  onTap: () => _changeLevelManually(2),
                ),
                _SpeedLevelChip(
                  label: '⚡ L3 Fast (1s)',
                  selected: _selectedLevel == 3,
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
                        'You spotted $_starsSpotted out of $_maxRounds stars ⭐!\n\n'
                        'Speed Level: L$_selectedLevel (${_getSpeedLabel(_selectedLevel)})\n'
                        'False Taps / Mistakes: $_mistakes',
                    onPlayAgain: _startGame,
                  )
                : SingleChildScrollView(
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
                          child: Column(
                            children: [
                              const Text(
                                'Tap the big box ONLY when the star ⭐ appears!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Current Speed: ${_getSpeedLabel(_selectedLevel)}',
                                style: const TextStyle(fontSize: 15, color: Colors.black54, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Big Interactive Target Box
                        GestureDetector(
                          onTap: _onBoxTap,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 240,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _targetIsShowing ? const Color(0xFFFFF9C4) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: _targetIsShowing ? const Color(0xFFFBC02D) : kMindMitraGreen,
                                width: _targetIsShowing ? 6 : 3,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_currentSymbol.isNotEmpty)
                                  Text(_currentSymbol, style: const TextStyle(fontSize: 92))
                                else
                                  const Icon(Icons.visibility_rounded, size: 54, color: Colors.black26),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    _message,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 19,
                                      color: _targetIsShowing ? const Color(0xFFD84315) : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Live Scoreboard Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kMindMitraGreen, width: 2),
                          ),
                          child: Text(
                            'Round: $_round / $_maxRounds   •   ⭐ Spotted: $_starsSpotted / $_maxRounds',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SpeedLevelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpeedLevelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kMindMitraGreen : const Color(0xFFF0F4F3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kMindMitraGreen, width: 2),
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