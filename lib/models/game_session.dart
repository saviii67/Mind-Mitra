import 'dart:convert';

/// Represents a single game session completed by the user.
/// Designed for offline-first storage and eventual Firebase synchronization.
class GameSession {
  final String id;
  final String gameType; // 'memory', 'sequence', 'attention', 'pattern'
  final String gameName;
  final DateTime timestamp;
  final int durationSeconds;
  final int score;
  final int mistakes;
  final int totalAttempts;
  final int difficultyLevel; // 1 = Easy, 2 = Medium, 3 = Challenging
  final bool isSynced;

  GameSession({
    required this.id,
    required this.gameType,
    required this.gameName,
    required this.timestamp,
    required this.durationSeconds,
    required this.score,
    required this.mistakes,
    required this.totalAttempts,
    required this.difficultyLevel,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameType': gameType,
      'gameName': gameName,
      'timestamp': timestamp.toIso8601String(),
      'durationSeconds': durationSeconds,
      'score': score,
      'mistakes': mistakes,
      'totalAttempts': totalAttempts,
      'difficultyLevel': difficultyLevel,
      'isSynced': isSynced,
    };
  }

  factory GameSession.fromMap(Map<String, dynamic> map) {
    return GameSession(
      id: map['id'] ?? '',
      gameType: map['gameType'] ?? 'memory',
      gameName: map['gameName'] ?? 'Memory Game',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      durationSeconds: map['durationSeconds'] ?? 0,
      score: map['score'] ?? 0,
      mistakes: map['mistakes'] ?? 0,
      totalAttempts: map['totalAttempts'] ?? 0,
      difficultyLevel: map['difficultyLevel'] ?? 1,
      isSynced: map['isSynced'] ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GameSession.fromJson(String source) =>
      GameSession.fromMap(jsonDecode(source));

  GameSession copyWith({bool? isSynced}) {
    return GameSession(
      id: id,
      gameType: gameType,
      gameName: gameName,
      timestamp: timestamp,
      durationSeconds: durationSeconds,
      score: score,
      mistakes: mistakes,
      totalAttempts: totalAttempts,
      difficultyLevel: difficultyLevel,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
