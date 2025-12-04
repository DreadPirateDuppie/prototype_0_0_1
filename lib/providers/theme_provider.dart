import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'isDarkMode';
  bool _isDarkMode = true; // Default to dark mode for Matrix theme

  // Matrix color constants
  static const Color matrixGreen = Color(0xFF00FF41);
  static const Color matrixDarkGreen = Color(0xFF008F11);
  static const Color matrixBlack = Color(0xFF000000);
  static const Color matrixSurface = Color(0xFF0D0D0D);
  static const Color matrixText = Color(0xFF00FF41); // Back to neon green per user request

  ThemeProvider() {
    _loadThemeFromStorage();
  }

  bool get isDarkMode => _isDarkMode;

  ThemeData getLightTheme() {
    // Light theme with Matrix accent
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: matrixGreen,
        primary: matrixGreen,
        onPrimary: matrixBlack, // Text on green buttons should be black
        secondary: matrixDarkGreen,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: matrixBlack, // Text on white background should be black
        brightness: Brightness.light,
        error: const Color(0xFFD32F2F),
      ),
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      cardColor: const Color(0xFFF5F5F5),
      dividerColor: Colors.grey[300],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: matrixBlack,
        elevation: 0,
        iconTheme: IconThemeData(color: matrixBlack),
        titleTextStyle: TextStyle(
          color: matrixBlack,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: matrixBlack, fontFamily: 'monospace'),
        displayMedium: TextStyle(color: matrixBlack, fontFamily: 'monospace'),
        displaySmall: TextStyle(color: matrixBlack, fontFamily: 'monospace'),
        headlineLarge: TextStyle(color: matrixBlack, fontFamily: 'monospace'),
        headlineMedium: TextStyle(color: matrixBlack, fontFamily: 'monospace'),
        headlineSmall: TextStyle(color: matrixBlack, fontFamily: 'monospace'),
        bodyLarge: TextStyle(color: matrixBlack, fontFamily: 'monospace'),
        bodyMedium: TextStyle(color: matrixBlack, fontFamily: 'monospace'),
        bodySmall: TextStyle(color: matrixBlack, fontFamily: 'monospace'),
        labelLarge: TextStyle(color: matrixBlack, fontFamily: 'monospace'),
        labelMedium: TextStyle(color: matrixBlack, fontFamily: 'monospace'),
        labelSmall: TextStyle(color: matrixBlack, fontFamily: 'monospace'),
      ),
      iconTheme: const IconThemeData(
        color: matrixBlack,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: matrixGreen,
        foregroundColor: matrixBlack,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: matrixGreen,
          foregroundColor: matrixBlack,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: matrixBlack,
          side: const BorderSide(color: matrixBlack),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: matrixDarkGreen,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: matrixBlack),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: matrixGreen, width: 2),
        ),
        labelStyle: TextStyle(color: matrixBlack),
        hintStyle: TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleTextStyle: TextStyle(
          color: matrixBlack,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
        contentTextStyle: TextStyle(
          color: matrixBlack,
          fontFamily: 'monospace',
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: matrixGreen,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  ThemeData getDarkTheme() {
    // Full Matrix theme - neon green on pure black
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: matrixGreen,
        primary: matrixGreen,
        secondary: matrixDarkGreen,
        surface: matrixSurface,
        brightness: Brightness.dark,
        onPrimary: matrixBlack,
        onSecondary: matrixBlack,
        onSurface: matrixText,
        error: const Color(0xFFFF4444),
      ),
      scaffoldBackgroundColor: matrixBlack,
      cardColor: matrixSurface,
      dividerColor: matrixDarkGreen,
      useMaterial3: true,
      brightness: Brightness.dark,
      appBarTheme: const AppBarTheme(
        backgroundColor: matrixBlack,
        foregroundColor: matrixGreen,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: matrixGreen,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: matrixGreen),
        displayMedium: TextStyle(color: matrixGreen),
        displaySmall: TextStyle(color: matrixGreen),
        headlineLarge: TextStyle(color: matrixGreen),
        headlineMedium: TextStyle(color: matrixGreen),
        headlineSmall: TextStyle(color: matrixGreen),
        bodyLarge: TextStyle(color: matrixText),
        bodyMedium: TextStyle(color: matrixText),
        bodySmall: TextStyle(color: matrixText),
        labelLarge: TextStyle(color: matrixGreen),
        labelMedium: TextStyle(color: matrixText),
        labelSmall: TextStyle(color: matrixDarkGreen),
      ),
      iconTheme: const IconThemeData(
        color: matrixGreen,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: matrixGreen,
        foregroundColor: matrixBlack,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: matrixGreen,
          foregroundColor: matrixBlack,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: matrixGreen,
          side: const BorderSide(color: matrixGreen),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: matrixGreen,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: matrixGreen),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: matrixDarkGreen),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: matrixGreen, width: 2),
        ),
        labelStyle: TextStyle(color: matrixGreen),
        hintStyle: TextStyle(color: matrixDarkGreen),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: matrixSurface,
        selectedColor: Color(0x3300FF41), // matrixGreen with 0.2 opacity
        labelStyle: TextStyle(color: matrixGreen),
        side: BorderSide(color: matrixGreen),
      ),
    );
  }

  Future<void> _loadThemeFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? true; // Default to dark
      notifyListeners();
    } catch (e) {
      // Silently fail, default to dark mode
    }
  }

  Future<void> toggleDarkMode() async {
    try {
      _isDarkMode = !_isDarkMode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
      notifyListeners();
    } catch (e) {
      // Silently fail
    }
  }
}
