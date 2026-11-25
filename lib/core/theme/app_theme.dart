import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/settings_controller.dart';

@immutable
class AppPalette {
  const AppPalette({
    required this.primary,
    required this.secondary,
    required this.onPrimary,
    required this.gradient,
    required this.name,
  });

  final Color primary;
  final Color secondary;
  final Color onPrimary;
  final List<Color> gradient;
  final String name;

  static const solar = AppPalette(
    primary: Color(0xFFFFB648),
    secondary: Color(0xFFFF6B4A),
    onPrimary: Color(0xFF1A1004),
    gradient: [Color(0xFFFFC75C), Color(0xFFFF6B4A)],
    name: 'Solar',
  );

  static const aurora = AppPalette(
    primary: Color(0xFF5FE3BE),
    secondary: Color(0xFF38BDF8),
    onPrimary: Color(0xFF03130F),
    gradient: [Color(0xFF6CF0C7), Color(0xFF2AA7F0)],
    name: 'Aurora',
  );

  static const nebula = AppPalette(
    primary: Color(0xFFB79CFF),
    secondary: Color(0xFFF472B6),
    onPrimary: Color(0xFF120A20),
    gradient: [Color(0xFFC4ADFF), Color(0xFFF472B6)],
    name: 'Nebula',
  );

  static const ocean = AppPalette(
    primary: Color(0xFF65D6E8),
    secondary: Color(0xFF4F8DFF),
    onPrimary: Color(0xFF041218),
    gradient: [Color(0xFF6FE7E0), Color(0xFF4F8DFF)],
    name: 'Ocean',
  );

  static AppPalette forChoice(AccentChoice choice) => switch (choice) {
        AccentChoice.solar => solar,
        AccentChoice.aurora => aurora,
        AccentChoice.nebula => nebula,
        AccentChoice.ocean => ocean,
      };
}

@immutable
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.elevated,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.faint,
    required this.error,
    required this.success,
    required this.logoTile,
    required this.isPureBlack,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color elevated;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color muted;
  final Color faint;
  final Color error;
  final Color success;
  final Color logoTile;
  final bool isPureBlack;

  static const midnight = AppColors(
    background: Color(0xFF070B14),
    surface: Color(0xFF0C1220),
    surfaceAlt: Color(0xFF111A2B),
    elevated: Color(0xFF172136),
    border: Color(0xFF1D2739),
    borderStrong: Color(0xFF2A364C),
    text: Color(0xFFF3F6FC),
    muted: Color(0xFFA2ACC2),
    faint: Color(0xFF6C7891),
    error: Color(0xFFFF6171),
    success: Color(0xFF4ADE80),
    logoTile: Color(0xFFE9EDF5),
    isPureBlack: false,
  );

  static const pureBlack = AppColors(
    background: Color(0xFF000000),
    surface: Color(0xFF08080B),
    surfaceAlt: Color(0xFF0E0E12),
    elevated: Color(0xFF15151A),
    border: Color(0xFF202027),
    borderStrong: Color(0xFF2E2E38),
    text: Color(0xFFF5F5F7),
    muted: Color(0xFFA3A3AD),
    faint: Color(0xFF6B6B76),
    error: Color(0xFFFF6171),
    success: Color(0xFF4ADE80),
    logoTile: Color(0xFFE6E6EC),
    isPureBlack: true,
  );

  static AppColors forVariant(ThemeVariant variant) =>
      variant == ThemeVariant.pureBlack ? pureBlack : midnight;
}

@immutable
class AppLook extends ThemeExtension<AppLook> {
  const AppLook({
    required this.colors,
    required this.palette,
    required this.variant,
  });

  final AppColors colors;
  final AppPalette palette;
  final ThemeVariant variant;

  @override
  AppLook copyWith({
    AppColors? colors,
    AppPalette? palette,
    ThemeVariant? variant,
  }) =>
      AppLook(
        colors: colors ?? this.colors,
        palette: palette ?? this.palette,
        variant: variant ?? this.variant,
      );

  @override
  AppLook lerp(ThemeExtension<AppLook>? other, double t) {
    if (other is! AppLook) return this;
    return AppLook(
      colors: t < .5 ? colors : other.colors,
      palette: AppPalette(
        primary: Color.lerp(palette.primary, other.palette.primary, t)!,
        secondary: Color.lerp(palette.secondary, other.palette.secondary, t)!,
        onPrimary: Color.lerp(palette.onPrimary, other.palette.onPrimary, t)!,
        gradient: [
          for (var i = 0; i < palette.gradient.length; i++)
            Color.lerp(
              palette.gradient[i],
              other.palette.gradient[i % other.palette.gradient.length],
              t,
            )!,
        ],
        name: t < .5 ? palette.name : other.palette.name,
      ),
      variant: t < .5 ? variant : other.variant,
    );
  }
}

extension AppLookContext on BuildContext {
  AppLook get look =>
      Theme.of(this).extension<AppLook>() ??
      const AppLook(
        colors: AppColors.midnight,
        palette: AppPalette.solar,
        variant: ThemeVariant.midnight,
      );
  AppColors get colors => look.colors;
  AppPalette get palette => look.palette;
}

class AppTheme {
  AppTheme._();

  static ThemeData build(Settings settings) {
    final colors = AppColors.forVariant(settings.themeVariant);
    final palette = AppPalette.forChoice(settings.accent);
    final look = AppLook(
      colors: colors,
      palette: palette,
      variant: settings.themeVariant,
    );

    final textTheme = _textTheme(colors);
    final scheme = ColorScheme.dark(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      primaryContainer: palette.primary.withValues(alpha: .16),
      onPrimaryContainer: palette.primary,
      secondary: palette.secondary,
      onSecondary: palette.onPrimary,
      secondaryContainer: palette.secondary.withValues(alpha: .16),
      onSecondaryContainer: palette.secondary,
      surface: colors.surface,
      onSurface: colors.text,
      onSurfaceVariant: colors.muted,
      error: colors.error,
      onError: Colors.white,
      outline: colors.border,
      outlineVariant: colors.borderStrong,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: colors.text,
      onInverseSurface: colors.background,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surfaceAlt,
      surfaceContainerHigh: colors.elevated,
      surfaceContainerHighest: colors.elevated,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      fontFamily: 'Manrope',
      textTheme: textTheme,
      extensions: [look],
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.text,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      iconTheme: IconThemeData(color: colors.text, size: 22),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        hintStyle: TextStyle(color: colors.faint, fontSize: 14),
        labelStyle: TextStyle(color: colors.muted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIconColor: colors.muted,
        suffixIconColor: colors.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.primary, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.error),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.elevated,
        contentTextStyle: TextStyle(
          color: colors.text,
          fontFamily: 'Manrope',
          fontSize: 13.5,
          height: 1.35,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        textStyle: TextStyle(color: colors.text, fontFamily: 'Manrope'),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: colors.surfaceAlt,
        circularTrackColor: colors.surfaceAlt,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.primary,
        inactiveTrackColor: colors.surfaceAlt,
        thumbColor: palette.primary,
        overlayColor: palette.primary.withValues(alpha: .12),
        trackHeight: 3,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.primary.withValues(alpha: .55);
          }
          return colors.surfaceAlt;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.primary;
          return colors.borderStrong;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.primary;
          return colors.muted;
        }),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(colors.borderStrong),
        radius: const Radius.circular(8),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.primary,
        selectionColor: palette.primary.withValues(alpha: .28),
        selectionHandleColor: palette.primary,
      ),
    );
  }

  static TextTheme _textTheme(AppColors colors) {
    TextStyle display(double size, FontWeight weight,
            {double? height, double? spacing}) =>
        TextStyle(
          fontFamily: 'Sora',
          fontSize: size,
          fontWeight: weight,
          height: height ?? 1.12,
          letterSpacing: spacing ?? -0.5,
          color: colors.text,
        );
    TextStyle body(double size, FontWeight weight,
            {double? height, Color? color}) =>
        TextStyle(
          fontFamily: 'Manrope',
          fontSize: size,
          fontWeight: weight,
          height: height ?? 1.4,
          color: color ?? colors.text,
        );

    return TextTheme(
      displayLarge: display(38, FontWeight.w700, spacing: -1.1),
      displayMedium: display(33, FontWeight.w700, spacing: -0.9),
      displaySmall: display(29, FontWeight.w700, spacing: -0.7),
      headlineLarge: display(26, FontWeight.w700, spacing: -0.5),
      headlineMedium: display(23, FontWeight.w600, spacing: -0.3),
      headlineSmall: display(21, FontWeight.w600, spacing: -0.2),
      titleLarge: display(19, FontWeight.w600, spacing: -0.1),
      titleMedium: body(16, FontWeight.w700, height: 1.25),
      titleSmall: body(14, FontWeight.w700, height: 1.3),
      bodyLarge: body(15, FontWeight.w500, height: 1.5),
      bodyMedium: body(13.5, FontWeight.w500, height: 1.45),
      bodySmall: body(12, FontWeight.w500, height: 1.4, color: colors.muted),
      labelLarge: body(13, FontWeight.w700, height: 1.2),
      labelMedium: body(11.5, FontWeight.w700, height: 1.2),
      labelSmall: body(10.5, FontWeight.w700, height: 1.2, color: colors.muted),
    );
  }
}
