import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../di/service_locator.dart';
import '../l10n/app_localizations.dart';
import '../models/emergency_config.dart';
import '../services/url_service.dart';
import '../style/incil_colors.dart';
import '../style/incil_spacing.dart';
import '../widgets/primary_button.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key, required this.config});

  final EmergencyConfig config;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final urls = getIt<UrlService>();

    final title = config.title ?? l.emergencyDefaultTitle;
    final updatedAt = config.updatedAt;

    return Scaffold(
      backgroundColor: IncilColors.emergency,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(IncilSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: IncilSpacing.xl),
              const Icon(
                Icons.warning_amber_rounded,
                color: IncilColors.onEmergency,
                size: 72,
              ),
              const SizedBox(height: IncilSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  color: IncilColors.onEmergency,
                ),
              ),
              if (config.message != null) ...[
                const SizedBox(height: IncilSpacing.md),
                Text(
                  config.message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: IncilColors.onEmergency,
                  ),
                ),
              ],
              const Spacer(),
              if (updatedAt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: IncilSpacing.md),
                  child: Text(
                    l.emergencyLastUpdated(_formatTimestamp(updatedAt)),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: IncilColors.onEmergency.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              if (config.primaryActionPhone != null &&
                  config.primaryActionLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: IncilSpacing.sm),
                  child: PrimaryButton(
                    label: config.primaryActionLabel!,
                    icon: Icons.phone,
                    onPressed: () => urls.dial(config.primaryActionPhone!),
                  ),
                ),
              if (config.secondaryActionUrl != null &&
                  config.secondaryActionLabel != null)
                OutlinedButton.icon(
                  onPressed: () {
                    final uri = Uri.tryParse(config.secondaryActionUrl!);
                    if (uri != null) urls.openExternal(uri);
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: Text(config.secondaryActionLabel!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: IncilColors.onEmergency,
                    side: const BorderSide(color: IncilColors.onEmergency),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    // Format uses only numeric tokens — no locale data required.
    return DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());
  }
}
