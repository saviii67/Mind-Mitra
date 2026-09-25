import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/login_screen.dart';
import 'services/storage_service.dart';
import 'services/ai_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await AIEngine.recomputeCognitiveScore();
  runApp(const MindMitraApp());
}

class MindMitraApp extends StatelessWidget {
  const MindMitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: StorageService.isLoggedInNotifier,
      builder: (context, isLoggedIn, _) {
        return MaterialApp(
          title: 'MindMitra',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: isLoggedIn ? const MainShell() : const LoginScreen(),
        );
      },
    );
  }
}