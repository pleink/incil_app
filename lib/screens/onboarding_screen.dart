import 'package:flutter/material.dart';

import '../models/onboarding_config.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.config});

  final OnboardingConfig config;

  @override
  Widget build(BuildContext context) {
    // Placeholder — full screen lands in M10.
    return Scaffold(
      body: Center(
        child: Text(
          'Onboarding v${config.version} (${config.slides.length} slides)',
        ),
      ),
    );
  }
}
