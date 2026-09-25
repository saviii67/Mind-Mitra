import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/ai_engine.dart';
import 'memory_game.dart';
import 'sequence_game.dart';
import 'attention_game.dart';
import 'pattern_game.dart';
import 'listen_and_speak_game.dart';
import 'voice_riddle_game.dart';

const Color kMindMitraGreen = Color(0xFF4A7C6F);
const Color kMindMitraBackground = Color(0xFFF4F7F6);

/// Cognitive Games Menu with AI Adaptive Level Badges
class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  int _memLevel = 1;
  int _seqLevel = 1;
  int _attLevel = 1;
  int _patLevel = 1;
  int _listenLevel = 1;
  int _voiceTalkLevel = 1;

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    final m = await AIEngine.getAdaptiveDifficulty('memory');
    final s = await AIEngine.getAdaptiveDifficulty('sequence');
    final a = await AIEngine.getAdaptiveDifficulty('attention');
    final p = await AIEngine.getAdaptiveDifficulty('pattern');
    final l = await AIEngine.getAdaptiveDifficulty('listen_speak');
    final v = await AIEngine.getAdaptiveDifficulty('voice_talk');
    if (mounted) {
      setState(() {
        _memLevel = m;
        _seqLevel = s;
        _attLevel = a;
        _patLevel = p;
        _listenLevel = l;
        _voiceTalkLevel = v;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.currentLanguage,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: kMindMitraBackground,
          appBar: AppBar(
            backgroundColor: kMindMitraGreen,
            title: Text(LocalizationService.get('choose_game')),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    LocalizationService.get('choose_game'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LocalizationService.get('games_subtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.08,
                      children: [
                        _GameMenuButton(
                          emoji: '🃏',
                          label: LocalizationService.get('memory_game'),
                          level: _memLevel,
                          onTap: () => _openGame(context, const MemoryGame()),
                        ),
                        _GameMenuButton(
                          emoji: '🔢',
                          label: LocalizationService.get('sequence_game'),
                          level: _seqLevel,
                          onTap: () => _openGame(context, const SequenceGame()),
                        ),
                        _GameMenuButton(
                          emoji: '👀',
                          label: LocalizationService.get('attention_game'),
                          level: _attLevel,
                          onTap: () => _openGame(context, const AttentionGame()),
                        ),
                        _GameMenuButton(
                          emoji: '🔷',
                          label: LocalizationService.get('pattern_game'),
                          level: _patLevel,
                          onTap: () => _openGame(context, const PatternGame()),
                        ),
                        _GameMenuButton(
                          emoji: '🎧',
                          label: LocalizationService.get('listen_speak_game'),
                          level: _listenLevel,
                          onTap: () => _openGame(context, const ListenAndSpeakGame()),
                        ),
                        _GameMenuButton(
                          emoji: '🗣️',
                          label: LocalizationService.get('voice_talk_game'),
                          level: _voiceTalkLevel,
                          onTap: () => _openGame(context, const VoiceRiddleGame()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openGame(BuildContext context, Widget gameScreen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => gameScreen),
    ).then((_) => _loadLevels());
  }
}

class _GameMenuButton extends StatelessWidget {
  final String emoji;
  final String label;
  final int level;
  final VoidCallback onTap;

  const _GameMenuButton({
    required this.emoji,
    required this.label,
    required this.level,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kMindMitraGreen, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2F4F44),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'AI Level $level',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showInstructionsDialog(
  BuildContext context, {
  required String title,
  required String message,
  required VoidCallback onStart,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      content: Text(message, style: const TextStyle(fontSize: 18, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onStart();
          },
          child: Text(
            LocalizationService.get('start_game'),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: kMindMitraGreen),
          ),
        ),
      ],
    ),
  );
}

class ResultsView extends StatelessWidget {
  final String message;
  final VoidCallback onPlayAgain;

  const ResultsView({
    super.key,
    required this.message,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              LocalizationService.get('well_done'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, height: 1.4, color: Colors.black87),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kMindMitraGreen,
                minimumSize: const Size(240, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: onPlayAgain,
              child: Text(
                LocalizationService.get('play_again'),
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(240, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                LocalizationService.get('back_to_menu'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}