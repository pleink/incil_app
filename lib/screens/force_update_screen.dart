import 'package:flutter/material.dart';

import '../models/force_update_config.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, required this.config});

  final ForceUpdateConfig config;

  @override
  Widget build(BuildContext context) {
    // Placeholder — full screen lands in M9.
    return Scaffold(
      body: Center(child: Text('Force update: ${config.title ?? "?"}')),
    );
  }
}
