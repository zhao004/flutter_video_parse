import 'package:flutter/material.dart';

/// 应用级 Material 3 主题与响应式布局令牌。
///
/// 设计意图：页面只读取 [ColorScheme]、文本主题和统一间距，不直接保存
/// 表面色或文本色；成功和警告不属于标准 ColorScheme，使用扩展令牌承载。
abstract final class AppTheme {
  /// 图标取样色：主体天蓝 #6CAFFC、深蓝 #1F7AE9、冰蓝 #E8F2FD。
  ///
  /// 设计意图：使用主体天蓝作为 Material 3 种子，由保真色板生成满足
  /// 对比度要求的交互色和冷调表面，不在页面组件中直接复制图标颜色。
  static const Color seedColor = Color(0xFF6CAFFC);

  static const double compactBreakpoint = 600;
  static const double expandedBreakpoint = 840;
  static const double maximumContentWidth = 1040;

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;

  static ThemeData light() {
    final scheme = _createColorScheme(Brightness.light);
    return _buildTheme(scheme, AppStatusColors.light);
  }

  static ThemeData dark() {
    final scheme = _createColorScheme(Brightness.dark);
    return _buildTheme(scheme, AppStatusColors.dark);
  }

  static ColorScheme _createColorScheme(Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
  }

  static AppStatusColors statusColorsOf(BuildContext context) {
    return Theme.of(context).extension<AppStatusColors>()!;
  }

  static ThemeData _buildTheme(
    ColorScheme scheme,
    AppStatusColors statusColors,
  ) {
    final baseTheme = ThemeData(useMaterial3: true, colorScheme: scheme);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: scheme.outline),
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _zeroTracking(baseTheme.textTheme),
      extensions: <ThemeExtension<dynamic>>[statusColors],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surfaceTint,
        centerTitle: false,
        toolbarHeight: 64,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        elevation: 3,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        minWidth: 80,
        minExtendedWidth: 200,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        useIndicator: true,
        labelType: NavigationRailLabelType.all,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: _zeroTracking(
            baseTheme.textTheme,
          ).labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(48)),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: _zeroTracking(baseTheme.textTheme).labelLarge,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        elevation: 6,
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: scheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: _zeroTracking(
          baseTheme.textTheme,
        ).bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  static TextTheme _zeroTracking(TextTheme theme) {
    TextStyle? normalized(TextStyle? style, {FontWeight? weight}) {
      return style?.copyWith(letterSpacing: 0, fontWeight: weight);
    }

    return theme.copyWith(
      displayLarge: normalized(theme.displayLarge),
      displayMedium: normalized(theme.displayMedium),
      displaySmall: normalized(theme.displaySmall),
      headlineLarge: normalized(theme.headlineLarge),
      headlineMedium: normalized(theme.headlineMedium),
      headlineSmall: normalized(theme.headlineSmall, weight: FontWeight.w600),
      titleLarge: normalized(theme.titleLarge, weight: FontWeight.w600),
      titleMedium: normalized(theme.titleMedium, weight: FontWeight.w600),
      titleSmall: normalized(theme.titleSmall, weight: FontWeight.w600),
      bodyLarge: normalized(theme.bodyLarge),
      bodyMedium: normalized(theme.bodyMedium),
      bodySmall: normalized(theme.bodySmall),
      labelLarge: normalized(theme.labelLarge, weight: FontWeight.w600),
      labelMedium: normalized(theme.labelMedium, weight: FontWeight.w600),
      labelSmall: normalized(theme.labelSmall, weight: FontWeight.w600),
    );
  }
}

/// Material 3 标准色板之外的业务状态色。
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
  });

  static const light = AppStatusColors(
    success: Color(0xFF146C43),
    successContainer: Color(0xFFD2F8DE),
    warning: Color(0xFF745B00),
    warningContainer: Color(0xFFFFE08A),
  );

  static const dark = AppStatusColors(
    success: Color(0xFF7DDBA6),
    successContainer: Color(0xFF005231),
    warning: Color(0xFFF1C453),
    warningContainer: Color(0xFF574500),
  );

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
    );
  }

  @override
  AppStatusColors lerp(covariant AppStatusColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
    );
  }
}
