import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Core palette from the MindMitra design direction
  static const Color cream = Color(0xFFFAF6EC);      // warm cream background
  static const Color sageGreen = Color(0xFF8FAE8B);  // soft sage green
  static const Color skyBlue = Color(0xFFA9D6E5);    // gentle sky blue
  static const Color warmYellow = Color(0xFFF4C95D); // warm yellow accent
  static const Color textDark = Color(0xFF3A3A3A);   // large readable dark text

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: sageGreen,
        primary: sageGreen,
        secondary: skyBlue,
        surface: cream,
      ),
      textTheme: const TextTheme(
        // Big screen titles, e.g. "MindMitra 🌿"
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: textDark,
          height: 1.3,
        ),
        // Section titles, e.g. "Today's Activity"
        titleLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: textDark,
          height: 1.3,
        ),
        // Main readable text, e.g. instructions, descriptions
        bodyLarge: TextStyle(
          fontSize: 20,
          color: textDark,
          height: 1.4,
          letterSpacing: 0.3,
        ),
        // Slightly smaller supporting text
        bodyMedium: TextStyle(
          fontSize: 18,
          color: textDark,
          height: 1.4,
          letterSpacing: 0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: sageGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 64), // extra-large, easy-to-tap button
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cream,
        indicatorColor: sageGreen.withOpacity(0.3),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textDark),
        ),
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(size: 28),
        ),
      ),
    );
  }
}