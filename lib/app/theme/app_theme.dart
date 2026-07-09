import 'package:flutter/material.dart';

/// 应用视觉令牌，集中承接 Pencil 画板中的颜色、间距和圆角。
///
/// 设计意图：页面实现只引用语义化令牌，避免散落魔法值；当设计稿调整时，
/// 只需要在这里同步视觉变量，降低跨页面维护成本。
abstract final class AppTheme {
  static const Color accentPrimary = Color(0xFF4A9FD8);
  static const Color borderPrimary = Color(0xFF1A1A1A);
  static const Color borderSoft = Color(0xFFD7DEE4);
  static const Color borderMuted = Color(0xFFC9DCE8);
  static const Color danger = Color(0xFFC43A31);
  static const Color foregroundInverse = Color(0xFFFFFFFF);
  static const Color foregroundPrimary = Color(0xFF1A1A1A);
  static const Color foregroundSecondary = Color(0xFF666666);
  static const Color foregroundMuted = Color(0xFF5F6F7A);
  static const Color success = Color(0xFF16794C);
  static const Color warning = Color(0xFFB26A00);
  static const Color surfaceChip = Color(0xFFE8F2FA);
  static const Color surfaceInfo = Color(0xFFEAF4FA);
  static const Color surfaceMuted = Color(0xFFF4F7F9);
  static const Color surfacePanel = Color(0xFFF4F8FB);
  static const Color surfacePrimary = Color(0xFFFFFFFF);
  static const Color successSoft = Color(0xFFDDF5E8);
  static const Color warningSoft = Color(0xFFFFF1D6);
  static const Color dangerSoft = Color(0xFFFDE8E5);

  static const double pageWidth = 390;
  static const double compactBottomNavHeight = 76;

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentPrimary,
      primary: accentPrimary,
      error: danger,
      surface: surfacePrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfacePrimary,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surfacePrimary,
        foregroundColor: foregroundPrimary,
        centerTitle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: foregroundPrimary,
        contentTextStyle: const TextStyle(
          color: foregroundInverse,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfacePrimary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: borderMuted),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: borderMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: accentPrimary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: danger),
        ),
      ),
    );
  }
}
