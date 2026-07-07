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

    final title = _hasText(config.title)
        ? config.title!
        : l.emergencyDefaultTitle;
    final callablePhone = config.callablePhone;
    final updatedAt = config.updatedAt;

    return Scaffold(
      backgroundColor: IncilColors.emergency,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(IncilSpacing.lg),
          child: SingleChildScrollView(
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
                if (_hasText(config.subtitle)) ...[
                  const SizedBox(height: IncilSpacing.sm),
                  Text(
                    config.subtitle!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: IncilColors.onEmergency,
                    ),
                  ),
                ],
                if (_hasText(config.body1)) ...[
                  const SizedBox(height: IncilSpacing.md),
                  Text(
                    config.body1!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: IncilColors.onEmergency,
                    ),
                  ),
                ],
                if (callablePhone != null) ...[
                  const SizedBox(height: IncilSpacing.lg),
                  PrimaryButton(
                    label: l.emergencyCallButton,
                    icon: Icons.phone,
                    onPressed: () => urls.dial(callablePhone),
                  ),
                ],
                if (_hasText(config.body2)) ...[
                  const SizedBox(height: IncilSpacing.lg),
                  Text(
                    config.body2!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: IncilColors.onEmergency,
                    ),
                  ),
                ],
                if (_hasText(config.footer)) ...[
                  const SizedBox(height: IncilSpacing.lg),
                  Text(
                    config.footer!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: IncilColors.onEmergency.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                if (updatedAt != null) ...[
                  const SizedBox(height: IncilSpacing.md),
                  Text(
                    l.emergencyLastUpdated(_formatTimestamp(updatedAt)),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: IncilColors.onEmergency.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  String _formatTimestamp(DateTime dt) {
    // Format uses only numeric tokens — no locale data required.
    return DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());
  }
}
