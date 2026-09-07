/// App color themes. Four hand-tuned moods, each with a reading-friendly
/// palette: parchment (light), sepia (classic paper), slate (dark) and
/// midnight (deep night sky).
library;

import 'package:flutter/material.dart';

class AppTheme {
  final String id;
  final String label;
  final IconData icon;
  final Color background;
  final Color card;
  final Color surfaceAlt;
  final Color text;
  final Color textDim;
  final Color accent;
  final Color accent2;
  final Color verseNumber;
  final Color border;

  const AppTheme({
    required this.id,
    required this.label,
    required this.icon,
    required this.background,
    required this.card,
    required this.surfaceAlt,
    required this.text,
    required this.textDim,
    required this.accent,
    required this.accent2,
    required this.verseNumber,
    required this.border,
  });

  bool get isDark => ThemeData.estimateBrightnessForColor(background) ==
      Brightness.dark;

  Color get accentSoft => accent.withValues(alpha: 0.14);
  Color get textOnAccent => isDark ? const Color(0xFF131313) : Colors.white;

  ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: isDark ? Brightness.dark : Brightness.light,
      surface: card,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamilyFallback: const ['Noto Sans', 'Roboto', 'Arial'],
    );
    final textTheme = base.textTheme.apply(
      bodyColor: text,
      displayColor: text,
    );
    return base.copyWith(
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border.withValues(alpha: 0.6)),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: const ['Noto Sans', 'Roboto', 'Arial'],
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: TextStyle(color: textDim),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? surfaceAlt : const Color(0xFF23202B),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: textOnAccent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: accentSoft,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textDim,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? accent : textDim,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: border,
        overlayColor: accentSoft,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? accentSoft
              : border.withValues(alpha: 0.4),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}

const List<AppTheme> kAppThemes = [
  AppTheme(
    id: 'light',
    label: 'Parchment',
    icon: Icons.light_mode_outlined,
    background: Color(0xFFF7F4ED),
    card: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFEAE0),
    text: Color(0xFF26221B),
    textDim: Color(0xFF7A7365),
    accent: Color(0xFF6D28D9),
    accent2: Color(0xFF8B5CF6),
    verseNumber: Color(0xFFB08A0F),
    border: Color(0xFFE3DCCB),
  ),
  AppTheme(
    id: 'sepia',
    label: 'Sepia',
    icon: Icons.menu_book_outlined,
    background: Color(0xFFF0E6CE),
    card: Color(0xFFFBF4E2),
    surfaceAlt: Color(0xFFE5D7B6),
    text: Color(0xFF3C3020),
    textDim: Color(0xFF8A7A5E),
    accent: Color(0xFFA1622D),
    accent2: Color(0xFF8F6522),
    verseNumber: Color(0xFFB0863B),
    border: Color(0xFFDCCEAA),
  ),
  AppTheme(
    id: 'dark',
    label: 'Slate',
    icon: Icons.dark_mode_outlined,
    background: Color(0xFF10141D),
    card: Color(0xFF1A202E),
    surfaceAlt: Color(0xFF232B3D),
    text: Color(0xFFEBEEF6),
    textDim: Color(0xFF99A2B8),
    accent: Color(0xFFF0B429),
    accent2: Color(0xFFE8890C),
    verseNumber: Color(0xFFF0B429),
    border: Color(0xFF2B3450),
  ),
  AppTheme(
    id: 'midnight',
    label: 'Midnight',
    icon: Icons.nights_stay_outlined,
    background: Color(0xFF0B0F1A),
    card: Color(0xFF141B2E),
    surfaceAlt: Color(0xFF1D2742),
    text: Color(0xFFDCE3F7),
    textDim: Color(0xFF8C99BC),
    accent: Color(0xFF5EA8FF),
    accent2: Color(0xFF9D7BFF),
    verseNumber: Color(0xFF7CC4F5),
    border: Color(0xFF25315B),
  ),
];

const List<AppTheme> kAdditionalThemes = [
  AppTheme(
    id: 'oled',
    label: 'OLED',
    icon: Icons.brightness_2_outlined,
    background: Color(0xFF000000),
    card: Color(0xFF0B0B0D),
    surfaceAlt: Color(0xFF141417),
    text: Color(0xFFF2F2F5),
    textDim: Color(0xFF8E8E98),
    accent: Color(0xFFF0B429),
    accent2: Color(0xFFE8890C),
    verseNumber: Color(0xFFF0B429),
    border: Color(0xFF232327),
  ),
];

List<AppTheme> get kAllThemes => [...kAppThemes, ...kAdditionalThemes];

AppTheme themeById(String id) => kAllThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => kAppThemes.last,
    );

/// Resolves the 'auto' pseudo-theme against the device brightness so
/// [appThemeOf] and MaterialApp always agree on the active palette.
AppTheme resolveThemeId(String id, Brightness brightness) => themeById(
      id == 'auto'
          ? (brightness == Brightness.dark ? 'midnight' : 'light')
          : id,
    );

/// Highlight palette used for verse highlights (index 0..4).
final List<Color> kHighlightPalette = const [
  Color(0xFFF6D743),
  Color(0xFF7ED99A),
  Color(0xFF7CC4F5),
  Color(0xFFF5A3C0),
  Color(0xFFC6A6F2),
];
final List<String> kHighlightNames = const [
  'Gold',
  'Green',
  'Blue',
  'Rose',
  'Violet',
];

Color highlightWithTheme(Color base, AppTheme theme) => theme.isDark
    ? Color.alphaBlend(base.withValues(alpha: 0.30), theme.card)
    : Color.alphaBlend(base.withValues(alpha: 0.34), theme.card);
