import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

final _background = 'assets/splash/splash_${Random().nextInt(6) + 1}.jpg';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A140D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(_background, fit: BoxFit.cover),
          const ColoredBox(color: Color(0x66000000)),
          Center(
            child: SvgPicture.asset(
              'assets/logo/incil_logo.svg',
              width: 240,
              semanticsLabel: 'incil',
            ),
          ),
        ],
      ),
    );
  }
}
