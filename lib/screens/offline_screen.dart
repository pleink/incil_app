import 'package:flutter/material.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Placeholder — full screen lands in M13.
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Offline'),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
