import 'dart:math';
import '../models/game_session.dart';
import '../models/cognitive_score.dart';
import 'storage_service.dart';

/// AI & ML Engine for MindMitra
/// Implements Member 3 (AI/ML Developer) requirements:
/// - Analyzes user gameplay metrics (reaction time, mistakes, attempts, accuracy)
/// - Computes cognitive domain indices and overall score
/// - Implements adaptive difficulty (Level 1 Easy -> Level 2 Medium -> Level 3 Advanced)
/// - Recommends daily optimal cognitive stimulation activity
class AIEngine {
  AIEngine._();

  /// Determine the recommended adaptive difficulty (1, 2, or 3) for a specific game
  /// based on recent performance sessions.
  static Future<int> getAdaptiveDifficulty(String gameType) async {
    final sessions = await StorageService.getGameSessions();
    final gameSessions = sessions.where((s) => s.gameType == gameType).take(3).toList();

    if (gameSessions.isEmpty) {
      return 1; // Start with gentle Level 1 for elderly dementia patients
    }

    // Calculate recent success rate
    double avgScore = 0;
    double avgMistakes = 0;
    for (var s in gameSessions) {
      avgScore += s.score;
      avgMistakes += s.mistakes;
    }
    avgScore /= gameSessions.length;
    avgMistakes /= gameSessions.length;

    // Adaptive policy:
    // If scoring consistently above 90% with low mistakes -> step up difficulty
    // If struggling (avgScore < 70% or mistakes > 3) -> step down to maintain comfort
    int lastLevel = gameSessions.first.difficultyLevel;
    if (avgScore >= 90 && avgMistakes <= 1) {
      return min(3, lastLevel + 1);
    } else if (avgScore < 70 || avgMistakes >= 3) {
      return max(1, lastLevel - 1);
    }
    return lastLevel;
  }

  /// Recalculates Cognitive Indices and Overall Cognitive Health Score
  /// based on all historical and recent game sessions.
  static Future<CognitiveScore> recomputeCognitiveScore() async {
    final sessions = await StorageService.getGameSessions();
    if (sessions.isEmpty) {
      final fresh = CognitiveScore.initial();
      await StorageService.saveCognitiveScore(fresh);
      return fresh;
    }

    // Partition by game type (including AI Listening & Talking games)
    final memorySessions = sessions
        .where((s) => s.gameType == 'memory' || s.gameType == 'listen_speak')
        .toList();
    final attentionSessions = sessions
        .where((s) => s.gameType == 'attention' || s.gameType == 'voice_talk')
        .toList();
    final sequenceSessions = sessions.where((s) => s.gameType == 'sequence').toList();
    final patternSessions = sessions.where((s) => s.gameType == 'pattern').toList();

    double memoryIndex = _calculateDomainScore(memorySessions, defaultScore: 0.0);
    double attentionIndex = _calculateDomainScore(attentionSessions, defaultScore: 0.0);
    double sequenceIndex = _calculateDomainScore(sequenceSessions, defaultScore: 0.0);
    double patternIndex = _calculateDomainScore(patternSessions, defaultScore: 0.0);

    // Speed index: based on average completion time across all sessions
    double avgDuration = sessions.map((s) => s.durationSeconds).reduce((a, b) => a + b) / sessions.length;
    // Normalized speed score (30s = 90, 60s = 75, >90s = 60)
    double speedIndex = (100 - (avgDuration * 0.4)).clamp(55.0, 95.0);

    // Calculate overall score across domains the user has actually played + speedIndex
    final activeDomainScores = <double>[
      if (memorySessions.isNotEmpty) memoryIndex,
      if (attentionSessions.isNotEmpty) attentionIndex,
      if (sequenceSessions.isNotEmpty) sequenceIndex,
      if (patternSessions.isNotEmpty) patternIndex,
      speedIndex,
    ];
    double overall = activeDomainScores.reduce((a, b) => a + b) / activeDomainScores.length;

    // Calculate streak days
    int streak = _calculateStreak(sessions);

    String statusNote;
    if (overall >= 85) {
      statusNote = 'High Engagement & Strong Recall';
    } else if (overall >= 70) {
      statusNote = 'Stable & Positive Active Engagement';
    } else {
      statusNote = 'Gentle Daily Practice Recommended';
    }

    final newScore = CognitiveScore(
      overallScore: double.parse(overall.toStringAsFixed(1)),
      memoryIndex: double.parse(memoryIndex.toStringAsFixed(1)),
      attentionIndex: double.parse(attentionIndex.toStringAsFixed(1)),
      sequenceIndex: double.parse(sequenceIndex.toStringAsFixed(1)),
      patternIndex: double.parse(patternIndex.toStringAsFixed(1)),
      processingSpeedIndex: double.parse(speedIndex.toStringAsFixed(1)),
      totalSessions: sessions.length,
      currentStreakDays: streak,
      statusNote: statusNote,
      lastUpdated: DateTime.now(),
    );

    await StorageService.saveCognitiveScore(newScore);
    return newScore;
  }

  static double _calculateDomainScore(List<GameSession> list, {required double defaultScore}) {
    if (list.isEmpty) return defaultScore;
    double total = 0;
    for (var s in list) {
      // Accuracy component (score) minus mistake penalty
      double sessionVal = (s.score - (s.mistakes * 5)).clamp(40.0, 100.0).toDouble();
      total += sessionVal;
    }
    return (total / list.length).clamp(50.0, 98.0).toDouble();
  }

  static int _calculateStreak(List<GameSession> sessions) {
    if (sessions.isEmpty) return 0;
    final dates = sessions
        .map((s) => DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);

    int streak = 0;
    DateTime checkDate = todayClean;

    for (var date in dates) {
      if (date.isAtSameMomentAs(checkDate) ||
          date.isAtSameMomentAs(checkDate.subtract(const Duration(days: 1)))) {
        streak++;
        checkDate = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return max(1, streak);
  }

  /// AI Suggests the best game to play today based on lowest domain index
  /// or daily rotation to keep cognitive practice balanced.
  static Future<Map<String, String>> getRecommendedActivity() async {
    final score = await StorageService.getCognitiveScore();
    
    // Find the domain that could benefit most from gentle practice
    Map<String, double> scores = {
      'memory': score.memoryIndex,
      'attention': score.attentionIndex,
      'sequence': score.sequenceIndex,
      'pattern': score.patternIndex,
    };

    String lowestDomain = 'memory';
    double minVal = 999;
    scores.forEach((key, val) {
      if (val < minVal) {
        minVal = val;
        lowestDomain = key;
      }
    });

    switch (lowestDomain) {
      case 'sequence':
        return {
          'type': 'sequence',
          'title': 'Sequence Game',
          'description': 'Gentle color recall to nurture working sequence',
          'emoji': '🔢',
        };
      case 'attention':
        return {
          'type': 'attention',
          'title': 'Attention Game',
          'description': 'Light focus exercise with soothing stars',
          'emoji': '👀',
        };
      case 'pattern':
        return {
          'type': 'pattern',
          'title': 'Pattern Game',
          'description': 'Simple shapes to stimulate visual logic',
          'emoji': '🔷',
        };
      case 'memory':
      default:
        return {
          'type': 'memory',
          'title': 'Memory Match',
          'description': 'Delightful matching pairs for memory and recall',
          'emoji': '🃏',
        };
    }
  }
}
