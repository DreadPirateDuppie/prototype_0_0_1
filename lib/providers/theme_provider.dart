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
        secondary: matrixDarkGreen,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      cardColor: const Color(0xFFF5F5F5),
      appBarTheme: AppBarTheme(
        backgroundColor: matrixBlack,
        foregroundColor: matrixGreen,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontFamily: 'monospace'),
        bodyMedium: TextStyle(fontFamily: 'monospace'),
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
