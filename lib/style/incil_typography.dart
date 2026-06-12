import 'package:flutter/material.dart';

abstract final class IncilTypography {
  static const _family = 'Roboto';

  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: _family,
      fontWeight: FontWeight.w700,
      fontSize: 32,
    ),
    headlineSmall: TextStyle(
      fontFamily: _family,
      fontWeight: FontWeight.w600,
      fontSize: 22,
    ),
    titleMedium: TextStyle(
      fontFamily: _family,
      fontWeight: FontWeight.w600,
      fontSize: 16,
    ),
    bodyLarge: TextStyle(
      fontFamily: _family,
      fontWeight: FontWeight.w400,
      fontSize: 16,
      height: 1.4,
    ),
    bodyMedium: TextStyle(
      fontFamily: _family,
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontFamily: _family,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      letterSpacing: 0.5,
    ),
  );
}
