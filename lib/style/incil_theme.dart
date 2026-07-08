import 'package:flutter/material.dart';

import 'incil_colors.dart';
import 'incil_typography.dart';

abstract final class IncilTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: IncilColors.primary,
      primary: IncilColors.primary,
      onPrimary: IncilColors.onPrimary,
      surface: IncilColors.surface,
      onSurface: IncilColors.onSurface,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: IncilTypography.textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: IncilTypography.textTheme.labelLarge,
        ),
      ),
    );
  }
}
