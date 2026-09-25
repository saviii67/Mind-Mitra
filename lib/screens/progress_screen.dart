import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/cognitive_score.dart';
import '../models/game_session.dart';
import '../models/patient_profile.dart';
import '../services/storage_service.dart';
import '../services/ai_engine.dart';
import '../services/localization_service.dart';
import 'login_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _isCaregiverView = false;
  CognitiveScore _cognitiveScore = CognitiveScore.initial();
  List<GameSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    StorageService.profileNotifier.addListener(_loadAllData);
    StorageService.dataVersionNotifier.addListener(_loadAllData);
    _loadAllData();
  }

  @override
  void dispose() {
    StorageService.profileNotifier.removeListener(_loadAllData);
    StorageService.dataVersionNotifier.removeListener(_loadAllData);
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final score = await AIEngine.recomputeCognitiveScore();
    final sessions = await StorageService.getGameSessions();

    if (mounted) {
      setState(() {
        _cognitiveScore = score;
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  void _exportCaregiverReport(PatientProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.description_rounded, color: AppTheme.sageGreen),
            SizedBox(width: 10),
            Text('Caregiver Report'),
          ],
        ),
        content: Text(
          'MindMitra Cognitive Summary Report generated for ${profile.name} (Age: ${profile.age}, Gender: ${profile.gender}, City: ${profile.city}).\n\n'
          '• Overall Score: ${_cognitiveScore.overallScore} / 100\n'
          '• Memory Index: ${_cognitiveScore.memoryIndex}%\n'
          '• Attention Index: ${_cognitiveScore.attentionIndex}%\n'
          '• Sequence Index: ${_cognitiveScore.sequenceIndex}%\n'
          '• Pattern Index: ${_cognitiveScore.patternIndex}%\n'
          '• Active Streak: ${_cognitiveScore.currentStreakDays} days\n'
          '• Sessions Recorded: ${_cognitiveScore.totalSessions}\n\n'
          'Shared with Caregiver ${profile.caregiverName} (${profile.caregiverPhone}) and ${profile.doctorName}.',
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(fontSize: 18, color: AppTheme.sageGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.currentLanguage,
      builder: (context, _, _) {
        return ValueListenableBuilder<PatientProfile>(
          valueListenable: StorageService.profileNotifier,
          builder: (context, profile, _) {
            return Scaffold(
              appBar: AppBar(
                title: Text(_isCaregiverView ? LocalizationService.get('caregiver_title') : LocalizationService.get('progress')),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _loadAllData,
                    tooltip: 'Refresh Data',
                  ),
                ],
              ),
              body: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadAllData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // View Switcher (Patient Mode vs Caregiver Mode)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2ECE9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isCaregiverView = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: !_isCaregiverView ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: !_isCaregiverView
                                              ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)]
                                              : [],
                                        ),
                                        child: Center(
                                          child: Text(
                                            LocalizationService.get('patient_mode'),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: !_isCaregiverView ? const Color(0xFF2F4F44) : Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isCaregiverView = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _isCaregiverView ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: _isCaregiverView
                                              ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)]
                                              : [],
                                        ),
                                        child: Center(
                                          child: Text(
                                            LocalizationService.get('caregiver_mode'),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _isCaregiverView ? const Color(0xFF2F4F44) : Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Logged-In Patient Summary Card (Always visible so user sees their details)
                            Card(
                              color: const Color(0xFFF9FBFB),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '👤 Logged-In Patient Profile',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                        ),
                                        TextButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (ctx) => const LoginScreen(isEditing: true)),
                                            );
                                          },
                                          icon: const Icon(Icons.edit_rounded, size: 16),
                                          label: const Text('Edit'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    _ProfileRow(label: 'Full Name', value: profile.name),
                                    _ProfileRow(label: 'Age & Gender', value: '${profile.age} years • ${profile.gender}'),
                                    _ProfileRow(label: 'District & State', value: profile.city),
                                    _ProfileRow(label: 'Caregiver', value: '${profile.caregiverName} (${profile.caregiverPhone})'),
                                    if (_isCaregiverView) ...[
                                      _ProfileRow(label: 'Doctor', value: profile.doctorName),
                                      _ProfileRow(label: 'Clinical Note', value: profile.stageNotes),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.sageGreen,
                                          minimumSize: const Size(double.infinity, 50),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        icon: const Icon(Icons.share_rounded, color: Colors.white),
                                        label: Text(LocalizationService.get('export_report'), style: const TextStyle(fontSize: 16, color: Colors.white)),
                                        onPressed: () => _exportCaregiverReport(profile),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Offline / Online Connectivity Banner
                            ValueListenableBuilder<bool>(
                              valueListenable: StorageService.isOnlineNotifier,
                              builder: (context, isOnline, _) {
                                return ValueListenableBuilder<int>(
                                  valueListenable: StorageService.unsyncedCountNotifier,
                                  builder: (context, unsynced, _) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isOnline ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isOnline ? const Color(0xFF81C784) : const Color(0xFFFFB74D),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                            color: isOnline ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                            size: 22,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              isOnline
                                                  ? LocalizationService.get('sync_status_online')
                                                  : '${LocalizationService.get('sync_status_offline')} ($unsynced queued)',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isOnline ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () => StorageService.toggleOnlineOffline(),
                                            child: Text(
                                              isOnline ? 'Test Offline' : 'Sync Now',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 18),

                            // Main Cognitive Gauge Card
                            Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${LocalizationService.get('cognitive_health_overview')} (${profile.name.split(' ').first})',
                                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.sageGreen.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text('AI Analyzed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44))),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Center(
                                      child: Column(
                                        children: [
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              SizedBox(
                                                width: 140,
                                                height: 140,
                                                child: CircularProgressIndicator(
                                                  value: _cognitiveScore.overallScore / 100,
                                                  strokeWidth: 14,
                                                  backgroundColor: const Color(0xFFE0E0E0),
                                                  color: AppTheme.sageGreen,
                                                ),
                                              ),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '${_cognitiveScore.overallScore.toInt()}',
                                                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                                  ),
                                                  const Text('/ 100', style: TextStyle(fontSize: 15, color: Colors.grey)),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            _cognitiveScore.statusNote,
                                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(),
                                    const SizedBox(height: 10),

                                    // Streak & Sessions stats
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _StatBox(
                                          icon: '🔥',
                                          value: '${_cognitiveScore.currentStreakDays}',
                                          label: LocalizationService.get('streak_days'),
                                        ),
                                        _StatBox(
                                          icon: '🎮',
                                          value: '${_cognitiveScore.totalSessions}',
                                          label: LocalizationService.get('sessions_completed'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Domain breakdown bars
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Cognitive Domain Indices',
                                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                    ),
                                    const SizedBox(height: 16),
                                    _DomainBar(
                                      label: LocalizationService.get('memory_index'),
                                      score: _cognitiveScore.memoryIndex,
                                      color: const Color(0xFF4A7C6F),
                                    ),
                                    const SizedBox(height: 12),
                                    _DomainBar(
                                      label: LocalizationService.get('attention_index'),
                                      score: _cognitiveScore.attentionIndex,
                                      color: const Color(0xFFE6A100),
                                    ),
                                    const SizedBox(height: 12),
                                    _DomainBar(
                                      label: LocalizationService.get('sequence_index'),
                                      score: _cognitiveScore.sequenceIndex,
                                      color: const Color(0xFF388E3C),
                                    ),
                                    const SizedBox(height: 12),
                                    _DomainBar(
                                      label: LocalizationService.get('pattern_index'),
                                      score: _cognitiveScore.patternIndex,
                                      color: const Color(0xFF1976D2),
                                    ),
                                    const SizedBox(height: 12),
                                    _DomainBar(
                                      label: LocalizationService.get('processing_speed'),
                                      score: _cognitiveScore.processingSpeedIndex,
                                      color: const Color(0xFF7B1FA2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Recent Sessions List
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      LocalizationService.get('recent_sessions'),
                                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                    ),
                                    const SizedBox(height: 14),
                                    if (_sessions.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 20),
                                        child: Center(
                                          child: Text(
                                            LocalizationService.get('no_sessions_yet'),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 16, color: Colors.black54),
                                          ),
                                        ),
                                      )
                                    else
                                      ..._sessions.take(6).map((session) {
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF9F9F9),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFEAEAEA)),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.sageGreen.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    session.gameType == 'memory'
                                                        ? '🃏'
                                                        : session.gameType == 'sequence'
                                                            ? '🔢'
                                                            : session.gameType == 'attention'
                                                                ? '👀'
                                                                : session.gameType == 'listen_speak'
                                                                    ? '🎧'
                                                                    : session.gameType == 'voice_talk'
                                                                        ? '🗣️'
                                                                        : '🔷',
                                                    style: const TextStyle(fontSize: 22),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      session.gameName,
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                    ),
                                                    Text(
                                                      '${session.durationSeconds}s • ${session.mistakes} mistakes • L${session.difficultyLevel}',
                                                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${session.score}%',
                                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                                                  ),
                                                  Icon(
                                                    session.isSynced ? Icons.cloud_done : Icons.cloud_off,
                                                    size: 16,
                                                    color: session.isSynced ? Colors.green : Colors.orange,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _StatBox({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
      ],
    );
  }
}

class _DomainBar extends StatelessWidget {
  final String label;
  final double score;
  final Color color;

  const _DomainBar({required this.label, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
            Text('${score.toInt()}%', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: const Color(0xFFEBEBEB),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}