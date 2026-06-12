import 'package:flutter/material.dart';

import '../style/incil_colors.dart';

/// Placeholder logo widget. Replace with branded asset in M15.
class IncilLogo extends StatelessWidget {
  const IncilLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: IncilColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        'I',
        style: TextStyle(
          color: IncilColors.onPrimary,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.5,
          height: 1,
        ),
      ),
    );
  }
}
