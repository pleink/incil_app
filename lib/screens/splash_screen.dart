import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../style/incil_spacing.dart';
import '../widgets/incil_logo.dart';
import '../widgets/loading_view.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IncilLogo(size: 120),
              const SizedBox(height: IncilSpacing.xl),
              Text(l.appTitle, style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: IncilSpacing.xxl),
              LoadingView(message: l.loadingMessage),
            ],
          ),
        ),
      ),
    );
  }
}
