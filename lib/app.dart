import 'package:flutter/material.dart';

import 'config/flavor.dart';
import 'l10n/app_localizations.dart';
import 'style/incil_theme.dart';

class IncilApp extends StatelessWidget {
  const IncilApp({super.key, required this.flavor});

  final Flavor flavor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: flavor.displayName,
      debugShowCheckedModeBanner: flavor == Flavor.dev,
      theme: IncilTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _BootstrapPlaceholder(flavor: flavor),
    );
  }
}

class _BootstrapPlaceholder extends StatelessWidget {
  const _BootstrapPlaceholder({required this.flavor});

  final Flavor flavor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlutterLogo(size: 96),
            const SizedBox(height: 16),
            Text(
              flavor.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Bootstrap placeholder — scaffolded in M1.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
