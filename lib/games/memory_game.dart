import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_session.dart';
import '../services/storage_service.dart';
import '../services/ai_engine.dart';
import '../services/voice_service.dart';
import '../services/localization_service.dart';
import 'games_screen.dart';

/// Memory Match Game with AI Adaptive & Manual Level Selection
/// Guaranteed responsive layout: all cards (4, 6, or 8) fit on a single screen
/// without scrolling, and every tap responds immediately.
class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key});

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  // Distinct, high-contrast symbols (none of them conflict with the '?' card back)
  final List<String> _allSymbols = const ['🌸', '🐶', '🍎', '🌻', '☕', '🐱'];
  List<String> _activeBaseSymbols = ['🌸', '🐶'];
  List<String> _cards = [];
  List<bool> _flipped = [];
  List<bool> _matched = [];

  List<int> _currentlyFlippedIndexes = [];
  Timer? _mismatchTimer;
  Timer? _finishTimer;
  int _matchedPairs = 0;
  bool _showResults = false;
  int _adaptiveLevel = 1;

  // Tracking
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _tickTimer;
  String _elapsedDisplay = '00:00';
  int _moves = 0;
  int _mistakes = 0;
  int? _finishedSeconds;
  List<GameSession> _history = [];
  String _helperHint = 'Tap any green card (?) to flip it open!';

  @override
  void initState() {
    super.initState();
    _setupBoardSync(1);
    _initGameWithAI();
  }

  Future<void> _initGameWithAI() async {
    final aiLevel = await AIEngine.getAdaptiveDifficulty('memory');
    if (!mounted) return;
    _setupBoardSync(aiLevel);
    await _loadHistory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final voicePrompt = VoiceService.getGameVoiceInstruction('memory');
      VoiceService.speak(voicePrompt);
      _startTimer();
    });
  }

  @override
  void dispose() {
    _mismatchTimer?.cancel();
    _finishTimer?.cancel();
    _tickTimer?.cancel();
    VoiceService.stop();
    super.dispose();
  }

  void _setupBoardSync(int level) {
    _mismatchTimer?.cancel();
    _finishTimer?.cancel();
    _tickTimer?.cancel();

    _adaptiveLevel = level;
    // Level 1 = 2 pairs (4 cards)
    // Level 2 = 3 pairs (6 cards)
    // Level 3 = 4 pairs (8 cards)
    final int pairCount = _adaptiveLevel == 1 ? 2 : (_adaptiveLevel == 2 ? 3 : 4);
    _activeBaseSymbols = _allSymbols.sublist(0, pairCount);

    final symbols = [..._activeBaseSymbols, ..._activeBaseSymbols];
    symbols.shuffle(Random());

    setState(() {
      _cards = symbols;
      _flipped = List.filled(_cards.length, false);
      _matched = List.filled(_cards.length, false);
      _currentlyFlippedIndexes = [];
      _matchedPairs = 0;
      _showResults = false;
      _moves = 0;
      _mistakes = 0;
      _finishedSeconds = null;
      _elapsedDisplay = '00:00';
      _helperHint = 'Tap any green card (❓) to find matching pairs!';
    });

    _stopwatch.reset();
  }

  void _startTimer() {
    _tickTimer?.cancel();
    _stopwatch.start();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedDisplay = _formatSeconds(_stopwatch.elapsed.inSeconds);
      });
    });
  }

  String _formatSeconds(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _loadHistory() async {
    final allSessions = await StorageService.getGameSessions();
    final memorySessions = allSessions.where((s) => s.gameType == 'memory').toList();
    if (mounted) {
      setState(() {
        _history = memorySessions;
      });
    }
  }

  void _onCardTap(int index) {
    if (!_stopwatch.isRunning) {
      _startTimer();
    }

    // Ignore tap if this card is already matched
    if (_matched[index]) {
      setState(() {
        _helperHint = 'This pair (${_cards[index]}) is already matched! ✅ Tap a green ❓ card.';
      });
      return;
    }

    // If 2 mismatched cards are currently open waiting to close, close them immediately
    // so the user's new tap responds right away without feeling stuck!
    if (_currentlyFlippedIndexes.length == 2) {
      _mismatchTimer?.cancel();
      final prevFirst = _currentlyFlippedIndexes[0];
      final prevSecond = _currentlyFlippedIndexes[1];
      _flipped[prevFirst] = false;
      _flipped[prevSecond] = false;
      _currentlyFlippedIndexes = [];
    }

    // If user taps the exact same card that is already open as the 1st card
    if (_flipped[index]) {
      setState(() {
        _helperHint = 'Now tap a DIFFERENT green ❓ card to match ${_cards[index]}!';
      });
      return;
    }

    setState(() {
      _flipped[index] = true;
      _currentlyFlippedIndexes.add(index);
      if (_currentlyFlippedIndexes.length == 1) {
        _helperHint = 'Great! Now tap a second green ❓ card to match ${_cards[index]}';
      }
    });

    if (_currentlyFlippedIndexes.length == 2) {
      _moves++;
      final first = _currentlyFlippedIndexes[0];
      final second = _currentlyFlippedIndexes[1];

      if (_cards[first] == _cards[second]) {
        // Matched!
        setState(() {
          _matched[first] = true;
          _matched[second] = true;
          _matchedPairs++;
          _currentlyFlippedIndexes = [];
          _helperHint = 'Match found! ${_cards[first]} ✅ ($_matchedPairs of ${_activeBaseSymbols.length} pairs)';
        });

        if (_matchedPairs == _activeBaseSymbols.length) {
          _stopwatch.stop();
          _tickTimer?.cancel();
          final seconds = max(1, _stopwatch.elapsed.inSeconds);
          _finishedSeconds = seconds;

          final score = (100 - (_mistakes * 6) - (seconds > 40 ? (seconds - 40) * 0.5 : 0))
              .clamp(55, 100)
              .toInt();

          final session = GameSession(
            id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
            gameType: 'memory',
            gameName: 'Memory Match',
            timestamp: DateTime.now(),
            durationSeconds: seconds,
            score: score,
            mistakes: _mistakes,
            totalAttempts: _moves,
            difficultyLevel: _adaptiveLevel,
          );

          StorageService.saveGameSession(session).then((_) {
            AIEngine.recomputeCognitiveScore();
            _loadHistory();
          });

          VoiceService.speak(LocalizationService.get('well_done'));

          _finishTimer = Timer(const Duration(milliseconds: 550), () {
            if (mounted) setState(() => _showResults = true);
          });
        }
      } else {
        // Did not match
        _mistakes++;
        setState(() {
          _helperHint = 'Not a match (${_cards[first]} & ${_cards[second]}) — Try again!';
        });
        _mismatchTimer = Timer(const Duration(milliseconds: 750), () {
          if (!mounted) return;
          setState(() {
            if (_currentlyFlippedIndexes.length == 2) {
              _flipped[first] = false;
              _flipped[second] = false;
              _currentlyFlippedIndexes = [];
            }
          });
        });
      }
    }
  }

  void _changeLevelManually(int newLevel) {
    _setupBoardSync(newLevel);
    _startTimer();
  }

  void _restart() {
    _setupBoardSync(_adaptiveLevel);
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    // Columns per level so there are ALWAYS 2 clean rows that fit on any screen!
    // L1 (4 cards) -> 2 cols x 2 rows
    // L2 (6 cards) -> 3 cols x 2 rows
    // L3 (8 cards) -> 4 cols x 2 rows
    final int columns = _cards.length <= 4 ? 2 : (_cards.length <= 6 ? 3 : 4);
    const int rows = 2;

    return Scaffold(
      backgroundColor: kMindMitraBackground,
      appBar: AppBar(
        backgroundColor: kMindMitraGreen,
        title: Text('${LocalizationService.get('memory_game')} • L$_adaptiveLevel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 26),
            tooltip: 'Restart Game',
            onPressed: _restart,
          ),
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, size: 28),
            tooltip: 'Read instructions aloud',
            onPressed: () {
              VoiceService.speak(VoiceService.getGameVoiceInstruction('memory'));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Manual Level Bar
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
                _MemLevelChip(
                  label: 'L1 (4 Cards)',
                  selected: _adaptiveLevel == 1,
                  onTap: () => _changeLevelManually(1),
                ),
                _MemLevelChip(
                  label: 'L2 (6 Cards)',
                  selected: _adaptiveLevel == 2,
                  onTap: () => _changeLevelManually(2),
                ),
                _MemLevelChip(
                  label: 'L3 (8 Cards)',
                  selected: _adaptiveLevel == 3,
                  onTap: () => _changeLevelManually(3),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _showResults
                ? _MemoryResultsView(
                    seconds: _finishedSeconds ?? 0,
                    moves: _moves,
                    mistakes: _mistakes,
                    level: _adaptiveLevel,
                    history: _history,
                    formatSeconds: _formatSeconds,
                    onPlayAgain: _restart,
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 780),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                        child: Column(
                          children: [
                            // Status & Timer Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Pairs: $_matchedPairs / ${_activeBaseSymbols.length}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      _helperHint,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2F4F44),
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 22, color: Color(0xFF2F4F44)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _elapsedDisplay,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Responsive Grid that ALWAYS fits all cards on screen without scrolling
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  const double spacing = 14.0;
                                  final double availW = max(100, constraints.maxWidth - (spacing * (columns - 1)));
                                  final double availH = max(100, constraints.maxHeight - (spacing * (rows - 1)));
                                  final double cardW = availW / columns;
                                  final double cardH = availH / rows;
                                  final double aspectRatio = (cardW / cardH).clamp(0.65, 2.2);

                                  return GridView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: spacing,
                                      crossAxisSpacing: spacing,
                                      childAspectRatio: aspectRatio,
                                    ),
                                    itemCount: _cards.length,
                                    itemBuilder: (context, index) {
                                      final isMatched = _matched[index];
                                      final isFlipped = _flipped[index];
                                      final isOpen = isFlipped || isMatched;

                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(18),
                                          onTap: () => _onCardTap(index),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            decoration: BoxDecoration(
                                              color: isMatched
                                                  ? const Color(0xFFE8F5E9)
                                                  : (isFlipped ? Colors.white : kMindMitraGreen),
                                              borderRadius: BorderRadius.circular(18),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.08),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                              border: Border.all(
                                                color: isMatched
                                                    ? const Color(0xFF2E7D32)
                                                    : (isFlipped ? const Color(0xFFF59E0B) : const Color(0xFF3A665A)),
                                                width: isOpen ? 3.5 : 2,
                                              ),
                                            ),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                if (isMatched)
                                                  const Positioned(
                                                    top: 8,
                                                    right: 10,
                                                    child: Text('✅', style: TextStyle(fontSize: 18)),
                                                  ),
                                                Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      isOpen ? _cards[index] : '❓',
                                                      style: TextStyle(
                                                        fontSize: isOpen ? 48 : 38,
                                                        color: isOpen ? Colors.black : Colors.white,
                                                      ),
                                                    ),
                                                    if (!isOpen) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Card ${index + 1}',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
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

class _MemLevelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MemLevelChip({
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

class _MemoryResultsView extends StatelessWidget {
  final int seconds;
  final int moves;
  final int mistakes;
  final int level;
  final List<GameSession> history;
  final String Function(int) formatSeconds;
  final VoidCallback onPlayAgain;

  const _MemoryResultsView({
    required this.seconds,
    required this.moves,
    required this.mistakes,
    required this.level,
    required this.history,
    required this.formatSeconds,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text(
            LocalizationService.get('well_done'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Time: ${formatSeconds(seconds)}   •   Moves: $moves   •   Mistakes: $mistakes',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Level $level Completed • Session Saved',
              style: const TextStyle(fontSize: 15, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMindMitraGreen,
              minimumSize: const Size(240, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onPlayAgain,
            child: Text(LocalizationService.get('play_again'), style: const TextStyle(fontSize: 19, color: Colors.white)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(240, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(LocalizationService.get('back_to_menu'), style: const TextStyle(fontSize: 19)),
          ),
        ],
      ),
    );
  }
}