import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/patient_profile.dart';
import '../services/localization_service.dart';
import '../services/storage_service.dart';
import '../services/voice_service.dart';
import '../games/memory_game.dart';
import '../games/sequence_game.dart';
import '../games/attention_game.dart';
import '../games/pattern_game.dart';
import '../games/listen_and_speak_game.dart';
import '../games/voice_riddle_game.dart';

class HelpScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HelpScreen({super.key, this.onNavigateToTab});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  // States: 'idle', 'listening', 'thinking', 'speaking'
  String _voiceState = 'idle';
  bool _handsFreeMode = true; // Continuous ChatGPT-like conversation loop
  String _liveTranscript = '';

  final List<Map<String, String>> _messages = [];

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _lastProfileId = '';

  @override
  void initState() {
    super.initState();
    _lastProfileId = StorageService.profileNotifier.value.id;
    _initGreeting();
    StorageService.profileNotifier.addListener(_onProfileChanged);
  }

  void _initGreeting() {
    final profile = StorageService.profileNotifier.value;
    _messages.clear();
    _messages.add({
      'role': 'assistant',
      'content':
          'Namaskar ${profile.name} ji! 🌸 I am MindMitra, your personal AI companion in ${profile.city}. You can talk to me about anything — how you are feeling, your caregiver ${profile.caregiverName}, stories from ${profile.city}, or we can play a brain game together. Tap the microphone and speak freely!',
    });
  }

  void _onProfileChanged() {
    if (!mounted) return;
    final currentProfile = StorageService.profileNotifier.value;
    setState(() {
      if (currentProfile.id != _lastProfileId) {
        _lastProfileId = currentProfile.id;
        VoiceService.stop();
        _voiceState = 'idle';
        _liveTranscript = '';
        _initGreeting();
      } else if (_messages.length == 1 && _messages.first['role'] == 'assistant') {
        _initGreeting();
      }
    });
  }

  @override
  void dispose() {
    StorageService.profileNotifier.removeListener(_onProfileChanged);
    _textController.dispose();
    _scrollController.dispose();
    VoiceService.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onOrbTapped() {
    if (_voiceState == 'speaking') {
      VoiceService.stop();
      setState(() => _voiceState = 'idle');
      return;
    }
    if (_voiceState == 'listening') {
      VoiceService.finishListening();
      return;
    }
    if (_voiceState == 'thinking') return;

    _startListening();
  }

  void _startListening() {
    if (!mounted) return;
    setState(() {
      _voiceState = 'listening';
      _liveTranscript = 'Listening... Speak naturally!';
    });

    VoiceService.listenToUserVoice(
      onInterim: (interim) {
        if (!mounted) return;
        setState(() {
          _liveTranscript = '"$interim..."';
        });
      },
      onResult: (finalTranscript) {
        if (!mounted) return;
        if (finalTranscript.trim().isEmpty) {
          setState(() {
            _voiceState = 'idle';
            _liveTranscript = '';
          });
          return;
        }
        _sendUserMessage(finalTranscript.trim(), fromVoice: true);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _voiceState = 'idle';
          if (err == 'no-speech') {
            _liveTranscript = 'No speech heard. Tap the microphone whenever you are ready to talk.';
          } else {
            _liveTranscript = 'Mic info: $err — You can also type in the chat box below!';
          }
        });
      },
    );
  }

  Future<void> _sendUserMessage(String userText, {bool fromVoice = false}) async {
    if (userText.isEmpty) return;

    VoiceService.stop();

    setState(() {
      _messages.add({'role': 'user', 'content': userText});
      _voiceState = 'thinking';
      _liveTranscript = 'MindMitra is thinking... ✨';
    });
    _scrollToBottom();

    // Build history for multi-turn context
    final historyForAI = _messages
        .take(_messages.length - 1)
        .map((m) => {'role': m['role']!, 'content': m['content']!})
        .toList();

    final result = await VoiceService.askConversationalAI(userText, historyForAI);

    if (!mounted) return;

    setState(() {
      _messages.add({'role': 'assistant', 'content': result.responseMessage});
      _voiceState = 'speaking';
      _liveTranscript = '🔊 Speaking response... (Tap orb to interrupt)';
    });
    _scrollToBottom();

    // Speak the AI response out loud with natural voice
    VoiceService.speak(
      result.responseMessage,
      onDone: () {
        if (!mounted) return;
        setState(() {
          _voiceState = 'idle';
          _liveTranscript = '';
        });

        // If no navigation was triggered and Hands-Free mode is ON & user used voice,
        // automatically listen for their next reply like ChatGPT Voice Mode!
        if (fromVoice &&
            _handsFreeMode &&
            result.targetGame == null &&
            result.targetTabIndex == null &&
            !result.shouldCallCaregiver) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _voiceState == 'idle') {
              _startListening();
            }
          });
        }
      },
    );

    final profile = StorageService.profileNotifier.value;

    // Execute app actions if user asked to open a game, tab, or call caregiver
    if (result.shouldCallCaregiver) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          _showCallDialog(profile.caregiverName, profile.caregiverPhone, 'Primary Caregiver');
        }
      });
    } else if (result.targetGame != null) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        Widget targetWidget;
        switch (result.targetGame) {
          case 'listen_speak':
            targetWidget = const ListenAndSpeakGame();
            break;
          case 'voice_talk':
            targetWidget = const VoiceRiddleGame();
            break;
          case 'sequence':
            targetWidget = const SequenceGame();
            break;
          case 'attention':
            targetWidget = const AttentionGame();
            break;
          case 'pattern':
            targetWidget = const PatternGame();
            break;
          case 'memory':
          default:
            targetWidget = const MemoryGame();
            break;
        }
        Navigator.push(context, MaterialPageRoute(builder: (ctx) => targetWidget));
      });
    } else if (result.targetTabIndex != null && widget.onNavigateToTab != null) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        widget.onNavigateToTab!(result.targetTabIndex!);
      });
    }
  }

  void _showContactsBottomSheet(PatientProfile profile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              LocalizationService.get('caregiver_contacts'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 14),
            _ContactCard(
              name: '${profile.caregiverName} (Primary Caregiver)',
              phone: profile.caregiverPhone,
              icon: Icons.person_rounded,
              color: AppTheme.sageGreen,
              onTap: () {
                Navigator.pop(ctx);
                _showCallDialog(profile.caregiverName, profile.caregiverPhone, 'Primary Caregiver');
              },
            ),
            const SizedBox(height: 10),
            _ContactCard(
              name: '${profile.doctorName} (${profile.city})',
              phone: '+91 98123 45678',
              icon: Icons.medical_services_rounded,
              color: const Color(0xFF1976D2),
              onTap: () {
                Navigator.pop(ctx);
                _showCallDialog(profile.doctorName, '+91 98123 45678', 'Family Neurologist');
              },
            ),
            const SizedBox(height: 10),
            _ContactCard(
              name: 'National Senior Helpline (Elderline)',
              phone: 'Toll-Free: 14567 (All NER States)',
              icon: Icons.emergency_rounded,
              color: const Color(0xFFD32F2F),
              onTap: () {
                Navigator.pop(ctx);
                _showCallDialog('Elderline 14567', '14567', 'National Senior Citizen Helpline');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showCallDialog(String name, String phone, String role) {
    VoiceService.speak('Connecting your call to $name now.');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF2E7D32), size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(name)),
          ],
        ),
        content: Text(
          'Connecting to $role ($phone)...\n\nPriority emergency assistance active.',
          style: const TextStyle(fontSize: 17, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('End Call', style: TextStyle(fontSize: 18, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getOrbColor() {
    switch (_voiceState) {
      case 'listening':
        return const Color(0xFFE53935); // Warm Red when listening
      case 'thinking':
        return const Color(0xFFF59E0B); // Amber Gold when thinking
      case 'speaking':
        return const Color(0xFF0288D1); // Calming Blue when speaking
      case 'idle':
      default:
        return const Color(0xFF4A7C6F); // MindMitra Sage Green
    }
  }

  IconData _getOrbIcon() {
    switch (_voiceState) {
      case 'listening':
        return Icons.mic_rounded;
      case 'thinking':
        return Icons.auto_awesome_rounded;
      case 'speaking':
        return Icons.graphic_eq_rounded;
      case 'idle':
      default:
        return Icons.mic_none_rounded;
    }
  }

  String _getOrbLabel() {
    switch (_voiceState) {
      case 'listening':
        return '🔴 Listening... (Speak full sentences, or tap to send)';
      case 'thinking':
        return '✨ Thinking...';
      case 'speaking':
        return '🔊 MindMitra is Speaking... (Tap to interrupt)';
      case 'idle':
      default:
        return '🎤 Tap Orb to Talk (Human AI Voice)';
    }
  }

  void _showGeminiKeyDialog() {
    final keyController = TextEditingController(text: StorageService.geminiApiKeyNotifier.value);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Color(0xFF4A7C6F), size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Connect Google Gemini AI')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your free Google Gemini API Key (from aistudio.google.com/apikey) below. It is saved privately on your device.',
              style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: keyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Gemini API Key (starts with AIzaSy...)',
                hintText: 'AIzaSy...',
                prefixIcon: const Icon(Icons.vpn_key_rounded, color: Color(0xFF4A7C6F)),
                filled: true,
                fillColor: const Color(0xFFF5F7F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A7C6F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            label: const Text('Save Key', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              await StorageService.saveGeminiApiKey(keyController.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✨ Google Gemini AI Key saved! Try talking to MindMitra now.'),
                  backgroundColor: Color(0xFF2E7D32),
                ),
              );
            },
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
            return ValueListenableBuilder<String>(
              valueListenable: StorageService.geminiApiKeyNotifier,
              builder: (context, geminiKey, _) {
                final orbColor = _getOrbColor();
                final hasGeminiKey = geminiKey.trim().length > 5;

                return Scaffold(
                  appBar: AppBar(
                    title: Text(LocalizationService.get('voice_assistant_title')),
                    actions: [
                      // Google Gemini API Key Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: hasGeminiKey ? const Color(0xFF2E7D32) : const Color(0xFF1976D2),
                          backgroundColor: hasGeminiKey ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                          side: BorderSide(
                            color: hasGeminiKey ? const Color(0xFF2E7D32) : const Color(0xFF1976D2),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: Icon(hasGeminiKey ? Icons.auto_awesome_rounded : Icons.key_rounded, size: 18),
                        label: Text(
                          hasGeminiKey ? 'Gemini Active' : 'Set Gemini Key',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _showGeminiKeyDialog,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD32F2F),
                          side: const BorderSide(color: Color(0xFFD32F2F)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: const Text('Caregiver Call', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _showContactsBottomSheet(profile),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
              body: Column(
                children: [
                  // 1. Top Interactive ChatGPT-Style Voice Mode Header Card
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.psychology_rounded, color: Color(0xFF4A7C6F), size: 22),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'AI Companion for ${profile.name.split(' ').first}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                const Text('Hands-Free', style: TextStyle(fontSize: 13, color: Colors.black54)),
                                Switch(
                                  value: _handsFreeMode,
                                  activeColor: const Color(0xFF4A7C6F),
                                  onChanged: (val) => setState(() => _handsFreeMode = val),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Animated Voice Mode Orb
                        GestureDetector(
                          onTap: _onOrbTapped,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _voiceState == 'idle' ? 84 : 94,
                            height: _voiceState == 'idle' ? 84 : 94,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: orbColor,
                              boxShadow: [
                                BoxShadow(
                                  color: orbColor.withOpacity(0.4),
                                  blurRadius: _voiceState == 'idle' ? 12 : 24,
                                  spreadRadius: _voiceState == 'idle' ? 2 : 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              _getOrbIcon(),
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _getOrbLabel(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: orbColor,
                          ),
                        ),
                        if (_liveTranscript.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _liveTranscript,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 2. Suggested Topics / Starters (Horizontal Scroll with User's Details)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _TopicChip(
                          label: '🇮🇳 "தமிழில் பேசுங்கள் (Talk in Tamil)"',
                          onTap: () => _sendUserMessage('Please talk to me in Tamil (தமிழ்) and ask how I am doing today.'),
                        ),
                        _TopicChip(
                          label: '🇮🇳 "हिंदी में बात करें (Talk in Hindi)"',
                          onTap: () => _sendUserMessage('Please talk to me in Hindi (हिन्दी) and ask how I am doing today.'),
                        ),
                        _TopicChip(
                          label: '💬 "Who am I & where do I live?"',
                          onTap: () => _sendUserMessage('Can you remind me of my name, age, city, and caregiver?'),
                        ),
                        _TopicChip(
                          label: '🌿 "I feel a little lonely today"',
                          onTap: () => _sendUserMessage('I am feeling a little lonely today, can you comfort me?'),
                        ),
                        _TopicChip(
                          label: '👨‍👦 "Remind me about ${profile.caregiverName.split(' ').first}"',
                          onTap: () => _sendUserMessage('Can you remind me about ${profile.caregiverName}?'),
                        ),
                        _TopicChip(
                          label: '🍵 "Tell me a story about ${profile.city.split(',').first}"',
                          onTap: () => _sendUserMessage('Tell me a short, peaceful story about ${profile.city}.'),
                        ),
                        _TopicChip(
                          label: '📅 "What day and time is it?"',
                          onTap: () => _sendUserMessage('What day is today and what time is it?'),
                        ),
                        _TopicChip(
                          label: '🃏 "Start Memory Game"',
                          onTap: () => _sendUserMessage('Start memory game'),
                        ),
                        _TopicChip(
                          label: '👀 "Start Attention Game"',
                          onTap: () => _sendUserMessage('Start attention game'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 3. Multi-Turn Chat Conversation List (Like ChatGPT)
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['role'] == 'user';
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.78,
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isUser ? const Color(0xFF4A7C6F) : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isUser ? 18 : 4),
                                bottomRight: Radius.circular(isUser ? 4 : 18),
                              ),
                              border: isUser ? null : Border.all(color: const Color(0xFFE0DCD0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isUser ? profile.name.split(' ').first : '🌿 MindMitra',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isUser ? Colors.white70 : const Color(0xFF4A7C6F),
                                      ),
                                    ),
                                    if (!isUser) ...[
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          setState(() => _voiceState = 'speaking');
                                          VoiceService.speak(
                                            msg['content'] ?? '',
                                            onDone: () {
                                              if (mounted) setState(() => _voiceState = 'idle');
                                            },
                                          );
                                        },
                                        child: const Row(
                                          children: [
                                            Icon(Icons.volume_up_rounded, size: 17, color: Color(0xFF4A7C6F)),
                                            SizedBox(width: 2),
                                            Text('Listen', style: TextStyle(fontSize: 12, color: Color(0xFF4A7C6F), fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  msg['content'] ?? '',
                                  style: TextStyle(
                                    fontSize: 17,
                                    height: 1.4,
                                    color: isUser ? Colors.white : AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 4. Bottom ChatGPT-Style Input Bar (Type or Speak Anything)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _onOrbTapped,
                          icon: Icon(
                            _voiceState == 'listening' ? Icons.stop_circle_rounded : Icons.mic_rounded,
                            color: _voiceState == 'listening' ? Colors.red : const Color(0xFF4A7C6F),
                            size: 30,
                          ),
                          tooltip: 'Speak with Microphone',
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(fontSize: 17),
                            decoration: InputDecoration(
                              hintText: 'Talk to MindMitra about anything...',
                              filled: true,
                              fillColor: const Color(0xFFF5F7F6),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                final text = val.trim();
                                _textController.clear();
                                _sendUserMessage(text, fromVoice: false);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF4A7C6F),
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.send_rounded, color: Colors.white),
                          onPressed: () {
                            if (_textController.text.trim().isNotEmpty) {
                              final text = _textController.text.trim();
                              _textController.clear();
                              _sendUserMessage(text, fromVoice: false);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
              },
            );
          },
        );
      },
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TopicChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFCFDCD7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2F4F44)),
        ),
        onPressed: onTap,
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String name;
  final String phone;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ContactCard({
    required this.name,
    required this.phone,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(phone, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                ],
              ),
            ),
            Icon(Icons.call_rounded, color: color, size: 26),
          ],
        ),
      ),
    );
  }
}