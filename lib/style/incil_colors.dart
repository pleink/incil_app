import 'package:flutter/material.dart';

/// Brand palette from the incil festival style guide:
/// Hauptfarben white/beige/orange/black, Akzente pink/yellow.
abstract final class IncilColors {
  static const primary = Color(0xFFFF7C00); // orange
  static const onPrimary = Color(0xFFFAF5F0);
  static const surface = Color(0xFFFAF5F0); // white
  static const onSurface = Color(0xFF2D2926); // black

  /// Near-neutral off-white for cards/bubbles floating on photos — the brand
  /// white reads too yellow on top of warm imagery.
  static const card = Color(0xFFFAFAF7);
  static const beige = Color(0xFFFAE9D8);

  static const accentPink = Color(0xFFD82C5F);
  static const accentYellow = Color(0xFFFEBB13);

  static const emergency = Color(0xFFB22424);
  static const onEmergency = Color(0xFFFAF5F0);

  static const muted = Color(0xFF7A716B);
  static const border = Color(0xFFEADFD3);
}
