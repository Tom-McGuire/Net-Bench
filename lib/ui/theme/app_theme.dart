import 'package:material_ui/material_ui.dart';

class AppTheme {
  AppTheme._();

  /// Global runtime toggle updated when `SharedDeviceDatabase` changes.
  static bool isDark = true;

  // --- Surface & Structural Tokens ---
  static Color get scaffoldBg =>
      isDark ? const Color(0xFF141414) : const Color(0xFFF3F4F6);

  static Color get surface =>
      isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);

  static Color get surfaceHigh =>
      isDark ? const Color(0xFF252526) : const Color(0xFFF9FAFB);

  static Color get surfaceElevated =>
      isDark ? const Color(0xFF2D2D2D) : const Color(0xFFFFFFFF);

  static Color get surfaceHighest =>
      isDark ? const Color(0xFF323232) : const Color(0xFFE5E7EB);

  static Color get inputFill =>
      isDark ? const Color(0xFF252526) : const Color(0xFFF9FAFB);

  static Color get border =>
      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB);

  // --- Typography Tokens ---
  static Color get textPrimary =>
      isDark ? const Color(0xFFE0E0E0) : const Color(0xFF111827);

  static Color get textSecondary =>
      isDark ? const Color(0xFF9E9E9E) : const Color(0xFF4B5563);

  static Color get textMuted =>
      isDark ? const Color(0xFF6E6E6E) : const Color(0xFF6B7280);

  // --- Semantic & Action Tokens ---
  static Color get accent =>
      isDark ? const Color(0xFF007ACC) : const Color(0xFF0284C7);

  static Color get primary => accent;

  static Color get primaryLight =>
      isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

  static Color get success =>
      isDark ? const Color(0xFF10B981) : const Color(0xFF059669);

  static Color get warning =>
      isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);

  static Color get error =>
      isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);

  static Color get info =>
      isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);

  static Color get commandBg =>
      isDark ? const Color(0xFF0F141C) : const Color(0xFFF1F5F9);

  static Color get codeText =>
      isDark ? const Color(0xFFE6EDF3) : const Color(0xFF0F172A);

  // Monospace font family string
  static const String monoFont = 'Consolas, monospace';

  static TextStyle monoStyle({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: monoFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  // --- ThemeData Builders ---
  static ThemeData get currentTheme => isDark ? darkTheme() : lightTheme();

  static ThemeData darkTheme() => _buildTheme(Brightness.dark);

  static ThemeData lightTheme() => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    final bgColor = dark ? const Color(0xFF141414) : const Color(0xFFF3F4F6);
    final surfaceColor =
        dark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
    final surfaceHighColor =
        dark ? const Color(0xFF252526) : const Color(0xFFF9FAFB);
    final surfaceElevatedColor =
        dark ? const Color(0xFF2D2D2D) : const Color(0xFFFFFFFF);
    final surfaceHighestColor =
        dark ? const Color(0xFF323232) : const Color(0xFFE5E7EB);
    final inputFillColor =
        dark ? const Color(0xFF252526) : const Color(0xFFF9FAFB);
    final borderColor =
        dark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB);
    final inputBorderColor =
        dark ? const Color(0xFF3E3E42) : const Color(0xFFD1D5DB);
    final textPrimaryColor =
        dark ? const Color(0xFFE0E0E0) : const Color(0xFF111827);
    final textSecondaryColor =
        dark ? const Color(0xFF9E9E9E) : const Color(0xFF4B5563);
    final textMutedColor =
        dark ? const Color(0xFF6E6E6E) : const Color(0xFF6B7280);
    final accentColor =
        dark ? const Color(0xFF007ACC) : const Color(0xFF0284C7);
    final errorColor =
        dark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);

    final baseTypography = dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      dividerColor: borderColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: brightness,
        primary: accentColor,
        onPrimary: Colors.white,
        secondary: accentColor,
        onSecondary: Colors.white,
        error: errorColor,
        onError: Colors.white,
        surface: surfaceColor,
        onSurface: textPrimaryColor,
        onSurfaceVariant: textSecondaryColor,
        outline: borderColor,
        surfaceContainerLowest: bgColor,
        surfaceContainerLow:
            dark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB),
        surfaceContainer: surfaceHighColor,
        surfaceContainerHigh:
            dark ? const Color(0xFF282828) : const Color(0xFFF3F4F6),
        surfaceContainerHighest: surfaceHighestColor,
      ),
      textTheme: baseTypography.apply(
        bodyColor: textPrimaryColor,
        displayColor: textPrimaryColor,
      ),
      iconTheme: IconThemeData(color: textSecondaryColor),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevatedColor,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceElevatedColor,
        textStyle: TextStyle(color: textPrimaryColor, fontSize: 12),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: inputFillColor,
        hintStyle: TextStyle(color: textMutedColor),
        labelStyle: TextStyle(color: textSecondaryColor),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
