import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/patient_profile.dart';
import '../services/localization_service.dart';
import '../services/ai_engine.dart';
import '../services/storage_service.dart';
import '../games/memory_game.dart';
import '../games/sequence_game.dart';
import '../games/attention_game.dart';
import '../games/pattern_game.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, String> _recommendedActivity = {
    'type': 'memory',
    'title': 'Memory Match',
    'description': 'A fun little memory game',
    'emoji': '🃏',
  };

  String? _todayMood;

  @override
  void initState() {
    super.initState();
    StorageService.profileNotifier.addListener(_loadDailyData);
    StorageService.dataVersionNotifier.addListener(_loadDailyData);
    _loadDailyData();
  }

  @override
  void dispose() {
    StorageService.profileNotifier.removeListener(_loadDailyData);
    StorageService.dataVersionNotifier.removeListener(_loadDailyData);
    super.dispose();
  }

  Future<void> _loadDailyData() async {
    if (!mounted) return;
    final activity = await AIEngine.getRecommendedActivity();
    final mood = await StorageService.getTodayMood();
    if (mounted) {
      setState(() {
        _recommendedActivity = activity;
        _todayMood = mood;
      });
    }
  }

  void _launchRecommendedGame() {
    Widget gameWidget;
    switch (_recommendedActivity['type']) {
      case 'sequence':
        gameWidget = const SequenceGame();
        break;
      case 'attention':
        gameWidget = const AttentionGame();
        break;
      case 'pattern':
        gameWidget = const PatternGame();
        break;
      case 'memory':
      default:
        gameWidget = const MemoryGame();
        break;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => gameWidget),
    ).then((_) => _loadDailyData());
  }

  Future<void> _recordMood(String mood) async {
    await StorageService.saveDailyMood(mood);
    if (!mounted) return;
    setState(() => _todayMood = mood);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LocalizationService.get('mood_saved'),
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: AppTheme.sageGreen,
        duration: const Duration(seconds: 2),
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
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Personalized User Welcome & Details Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.sageGreen.withOpacity(0.18),
                                AppTheme.skyBlue.withOpacity(0.25),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: const Color(0xFF4A7C6F),
                                    child: Text(
                                      profile.gender == 'Female'
                                          ? '👵'
                                          : profile.gender == 'Male'
                                              ? '👴'
                                              : '🧑',
                                      style: const TextStyle(fontSize: 30),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Namaskar, ${profile.name}! 🌸',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          LocalizationService.get('app_subtitle'),
                                          style: const TextStyle(fontSize: 15, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit Profile Details',
                                    icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2F4F44), size: 28),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (ctx) => const LoginScreen(isEditing: true)),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ProfileInfoChip(
                                    icon: Icons.location_city_rounded,
                                    text: 'Location: ${profile.city}',
                                  ),
                                  _ProfileInfoChip(
                                    icon: Icons.cake_rounded,
                                    text: 'Age: ${profile.age} yrs',
                                  ),
                                  _ProfileInfoChip(
                                    icon: Icons.wc_rounded,
                                    text: 'Gender: ${profile.gender}',
                                  ),
                                  _ProfileInfoChip(
                                    icon: Icons.favorite_rounded,
                                    text: 'Caregiver: ${profile.caregiverName}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Daily Mood Check-In Widget
                      Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationService.get('mood_question'),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _MoodOption(
                                    emoji: '😊',
                                    label: 'Happy',
                                    isSelected: _todayMood == '😊',
                                    onTap: () => _recordMood('😊'),
                                  ),
                                  _MoodOption(
                                    emoji: '🌿',
                                    label: 'Calm',
                                    isSelected: _todayMood == '🌿',
                                    onTap: () => _recordMood('🌿'),
                                  ),
                                  _MoodOption(
                                    emoji: '😐',
                                    label: 'Okay',
                                    isSelected: _todayMood == '😐',
                                    onTap: () => _recordMood('😐'),
                                  ),
                                  _MoodOption(
                                    emoji: '🌧️',
                                    label: 'Low',
                                    isSelected: _todayMood == '🌧️',
                                    onTap: () => _recordMood('🌧️'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Today's Recommended Activity Card (Connected & Dynamic)
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_awesome, color: Color(0xFFE6A100), size: 24),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${LocalizationService.get('todays_activity')} for ${profile.name.split(' ').first}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    _recommendedActivity['emoji'] ?? '🃏',
                                    style: const TextStyle(fontSize: 48),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _recommendedActivity['title'] ?? 'Memory Match',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2F4F44),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _recommendedActivity['description'] ?? 'A gentle memory recall activity',
                                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.sageGreen,
                                  minimumSize: const Size(double.infinity, 58),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _launchRecommendedGame,
                                child: Text(
                                  LocalizationService.get('play_now'),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Need Some Help / Voice Companion card (Clickable)
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          if (widget.onNavigateToTab != null) {
                            widget.onNavigateToTab!(3); // Navigate to Help screen
                          }
                        },
                        child: Card(
                          color: AppTheme.warmYellow.withOpacity(0.25),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                const Text('🔊', style: TextStyle(fontSize: 34)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        LocalizationService.get('need_help'),
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        LocalizationService.get('talk_to_mindmitra'),
                                        style: const TextStyle(fontSize: 17, color: Color(0xFF5A4A00)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF7A6500), size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Dynamic Emergency Caregiver Quick Call
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD32F2F), width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          minimumSize: const Size(double.infinity, 54),
                        ),
                        icon: const Icon(Icons.call_rounded, color: Color(0xFFD32F2F)),
                        label: Text(
                          'Caregiver Quick Dial: ${profile.caregiverName} (${profile.caregiverPhone})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Row(
                                children: [
                                  Icon(Icons.phone_in_talk_rounded, color: Color(0xFF2E7D32)),
                                  SizedBox(width: 10),
                                  Text('Calling Caregiver'),
                                ],
                              ),
                              content: Text(
                                'Connecting call to ${profile.caregiverName} at ${profile.caregiverPhone} in ${profile.city}.\n\nElderline Helpline: 14567 is also available 24/7.',
                                style: const TextStyle(fontSize: 17),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close', style: TextStyle(fontSize: 18)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
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

class _ProfileInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ProfileInfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFDCD7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF4A7C6F)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2F4F44)),
          ),
        ],
      ),
    );
  }
}

class _MoodOption extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodOption({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.sageGreen.withOpacity(0.3) : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.sageGreen : Colors.black12,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF2F4F44) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}