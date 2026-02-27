import 'package:flutter/material.dart';

/// Centralised design tokens and [ThemeData] for the entire application.
///
/// Direction: dark cinematic — a streaming platform aesthetic defined by deep
/// charcoal surfaces, YouTube-adjacent accent red, and restrained typography.
/// All UI components draw from this theme; no hard-coded colours appear in
/// page or widget files.
abstract final class AppTheme {
  // ---------------------------------------------------------------------------
  // Colour palette
  // ---------------------------------------------------------------------------

  /// Primary background — near-black base surface.
  static const Color backgroundDark = Color(0xFF0D0D12);

  /// Slightly elevated surface — cards, modals, AppBar.
  static const Color surfaceDark = Color(0xFF16161E);

  /// Card / input field fill.
  static const Color cardDark = Color(0xFF1E1E28);

  /// Subtle border / divider colour.
  static const Color borderDark = Color(0xFF2A2A38);

  /// Accent — vivid red evoking YouTube and broadcasting.
  static const Color accent = Color(0xFFE53935);

  /// Accent with reduced opacity — disabled / secondary states.
  static const Color accentMuted = Color(0x55E53935);

  /// Primary text — warm off-white.
  static const Color textPrimary = Color(0xFFF0EFF4);

  /// Secondary text — muted grey for labels and captions.
  static const Color textSecondary = Color(0xFF8A8A9E);

  // ---------------------------------------------------------------------------
  // Typography scale
  // ---------------------------------------------------------------------------

  /// Display title used on form headings (e.g. "Connexion").
  static const TextStyle displayTitle = TextStyle(
    fontFamily: 'Georgia',
    fontSize: 26,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    letterSpacing: 0.4,
  );

  /// Section heading (e.g. "Groupes publics").
  static const TextStyle sectionHeading = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 1.4,
  );

  /// Standard body text.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  /// Caption / hint text.
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    color: textSecondary,
  );

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------

  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      surface: surfaceDark,
      onSurface: textPrimary,
      error: Color(0xFFCF6679),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundDark,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: textPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCF6679)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCF6679), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFCF6679), fontSize: 12),
      ),

      // Filled (primary) buttons — "Se connecter", "Créer le compte"
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: accentMuted,
          disabledForegroundColor: Colors.white54,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Outlined (secondary) buttons — "Annuler", "Créer un compte"
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderDark),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // Text buttons — inline links
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(color: borderDark, space: 1),
    );
  }
}