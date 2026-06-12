import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../di/service_locator.dart';
import '../l10n/app_localizations.dart';
import '../models/force_update_config.dart';
import '../services/url_service.dart';
import '../style/incil_spacing.dart';
import '../widgets/incil_logo.dart';
import '../widgets/primary_button.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, required this.config});

  final ForceUpdateConfig config;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final urls = getIt<UrlService>();

    final title = config.title ?? l.forceUpdateDefaultTitle;
    final storeUrl = Platform.isIOS
        ? config.iosStoreUrl
        : config.androidStoreUrl;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(IncilSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: IncilLogo(size: 96)),
              const SizedBox(height: IncilSpacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge,
              ),
              if (config.message != null) ...[
                const SizedBox(height: IncilSpacing.md),
                Text(
                  config.message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
              const Spacer(),
              PrimaryButton(
                label: l.forceUpdateAction,
                icon: Icons.system_update,
                onPressed: storeUrl == null
                    ? null
                    : () {
                        final uri = Uri.tryParse(storeUrl);
                        if (uri != null) urls.openExternal(uri);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
