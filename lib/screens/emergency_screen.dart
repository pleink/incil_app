import 'package:flutter/material.dart';

import '../models/emergency_config.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key, required this.config});

  final EmergencyConfig config;

  @override
  Widget build(BuildContext context) {
    // Placeholder — full screen lands in M8.
    return Scaffold(
      body: Center(child: Text('Emergency: ${config.title ?? "?"}')),
    );
  }
}
