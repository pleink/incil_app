import 'package:flutter/material.dart';

/// Style guide: Masqualero is reserved for the logo (shipped as SVG);
/// Neue Regrade is used for "literally alles andere". The bundled file is a
/// variable font, so weights are selected via the `wght` axis — `fontWeight`
/// alone would not change the rendering.
abstract final class IncilTypography {
  static const _family = 'NeueRegrade';

  static const _regular = [FontVariation('wght', 400)];
  static const _semiBold = [FontVariation('wght', 600)];
  // The variable font's wght axis tops out at 800.
  static const _extraBold = [FontVariation('wght', 800)];

  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: _family,
      fontVariations: _extraBold,
      fontWeight: FontWeight.w800,
      fontSize: 44,
      height: 1.04,
      letterSpacing: -0.5,
    ),
    headlineSmall: TextStyle(
      fontFamily: _family,
      fontVariations: _semiBold,
      fontWeight: FontWeight.w600,
      fontSize: 22,
    ),
    titleMedium: TextStyle(
      fontFamily: _family,
      fontVariations: _semiBold,
      fontWeight: FontWeight.w600,
      fontSize: 16,
    ),
    bodyLarge: TextStyle(
      fontFamily: _family,
      fontVariations: _regular,
      fontWeight: FontWeight.w400,
      fontSize: 16,
      height: 1.4,
    ),
    bodyMedium: TextStyle(
      fontFamily: _family,
      fontVariations: _regular,
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontFamily: _family,
      fontVariations: _semiBold,
      fontWeight: FontWeight.w600,
      fontSize: 16,
      letterSpacing: 0.5,
    ),
  );
}
