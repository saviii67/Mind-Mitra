import 'package:flutter/material.dart';
import '../models/patient_profile.dart';
import '../services/localization_service.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';
import '../games/games_screen.dart';
import 'progress_screen.dart';
import 'help_screen.dart';
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.currentLanguage,
      builder: (context, currentLang, _) {
        return ValueListenableBuilder<PatientProfile>(
          valueListenable: StorageService.profileNotifier,
          builder: (context, profile, _) {
            final List<Widget> screens = [
              HomeScreen(onNavigateToTab: _onTabSelected),
              const GamesScreen(),
              const ProgressScreen(),
              HelpScreen(onNavigateToTab: _onTabSelected),
            ];

            return Scaffold(
              appBar: AppBar(
                elevation: 0,
                toolbarHeight: 64,
                title: Row(
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        LocalizationService.get('app_title').replaceAll(' 🌿', ''),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Online / Offline Indicator Pill
                  ValueListenableBuilder<bool>(
                    valueListenable: StorageService.isOnlineNotifier,
                    builder: (context, isOnline, _) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOnline ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isOnline ? const Color(0xFF81C784) : const Color(0xFFFFB74D),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                                size: 15,
                                color: isOnline ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isOnline ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),

                  // Regional Language Selector Dropdown (NER Languages)
                  PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCCD7D3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded, size: 18, color: Color(0xFF2F4F44)),
                          const SizedBox(width: 4),
                          Text(
                            currentLang.toUpperCase(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2F4F44)),
                          ),
                        ],
                      ),
                    ),
                    tooltip: 'Select Indian Language',
                    onSelected: (code) => LocalizationService.setLanguage(code),
                    itemBuilder: (context) => LocalizationService.supportedLanguages.entries
                        .map(
                          (e) => PopupMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                  ),

                  // User Profile & Login Menu Button
                  PopupMenuButton<String>(
                    tooltip: 'User Profile & Login Options',
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A7C6F),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            profile.name.split(' ').first,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onSelected: (action) {
                      if (action == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => const LoginScreen(isEditing: true)),
                        );
                      } else if (action == 'logout') {
                        StorageService.logout();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                            ),
                            Text(
                              '${profile.age} yrs • ${profile.gender} • 📍 ${profile.city}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            const Divider(),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18, color: Color(0xFF4A7C6F)),
                            SizedBox(width: 8),
                            Text('Edit Profile Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 18, color: Color(0xFFD32F2F)),
                            SizedBox(width: 8),
                            Text('Switch User / Logout', style: TextStyle(color: Color(0xFFD32F2F))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: IndexedStack(index: _selectedIndex, children: screens),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onTabSelected,
                height: 80,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_rounded),
                    label: LocalizationService.get('home'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.videogame_asset_rounded),
                    label: LocalizationService.get('games'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.insights_rounded),
                    label: LocalizationService.get('progress'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.help_rounded),
                    label: LocalizationService.get('help'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}