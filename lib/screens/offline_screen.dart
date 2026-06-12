import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/error_view.dart';
import '../widgets/primary_button.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ErrorView(
            title: l.offlineTitle,
            message: l.offlineMessage,
            icon: Icons.wifi_off_rounded,
            action: onRetry == null
                ? null
                : PrimaryButton(
                    label: l.retry,
                    icon: Icons.refresh,
                    onPressed: onRetry,
                  ),
          ),
        ),
      ),
    );
  }
}
