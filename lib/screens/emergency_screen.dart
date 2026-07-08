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
        // Design pins the call button to the bottom edge; the min-height +
        // Spacer trick keeps that while staying scrollable when the body
        // texts run long.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(IncilSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: IncilSpacing.xl),
                      const Center(child: _PulsingWarningIcon()),
                      const SizedBox(height: IncilSpacing.lg),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displayLarge?.copyWith(
                          color: IncilColors.onEmergency,
                          fontSize: 44,
                        ),
                      ),
                      if (_hasText(config.subtitle)) ...[
                        const SizedBox(height: IncilSpacing.md),
                        Center(child: _SubtitlePill(text: config.subtitle!)),
                      ],
                      const SizedBox(height: IncilSpacing.xl),
                      if (_hasText(config.body1))
                        _MessageCard(text: config.body1!),
                      if (_hasText(config.body2)) ...[
                        const SizedBox(height: IncilSpacing.md),
                        _MessageCard(text: config.body2!),
                      ],
                      const Spacer(),
                      const SizedBox(height: IncilSpacing.xl),
                      if (callablePhone != null) ...[
                        PrimaryButton(
                          label: l.emergencyCallButton,
                          icon: Icons.phone,
                          tone: PrimaryButtonTone.emergencyInverse,
                          onPressed: () => urls.dial(callablePhone),
                        ),
                        const SizedBox(height: IncilSpacing.md),
                      ],
                      if (_hasText(config.footer))
                        Text(
                          config.footer!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: IncilColors.onEmergency.withValues(
                              alpha: 0.9,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (updatedAt != null) ...[
                        const SizedBox(height: IncilSpacing.xs),
                        Text(
                          l.emergencyLastUpdated(_formatTimestamp(updatedAt)),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: IncilColors.onEmergency.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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

/// White circle with the warning icon and an expanding, fading pulse ring
/// behind it — draws attention without being frantic.
class _PulsingWarningIcon extends StatefulWidget {
  const _PulsingWarningIcon();

  @override
  State<_PulsingWarningIcon> createState() => _PulsingWarningIconState();
}

class _PulsingWarningIconState extends State<_PulsingWarningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: 1.9,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  late final Animation<double> _fade = Tween(
    begin: 0.55,
    end: 0.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: _scale,
            child: FadeTransition(
              opacity: _fade,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: IncilColors.onEmergency,
                ),
                child: SizedBox.expand(),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: IncilColors.onEmergency,
            ),
            child: SizedBox.expand(
              child: Icon(
                Icons.warning_amber_rounded,
                color: IncilColors.emergency,
                size: 48,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined translucent pill under the title ("Das ist eine Übung").
class _SubtitlePill extends StatelessWidget {
  const _SubtitlePill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: BoxDecoration(
        color: IncilColors.onEmergency.withValues(alpha: 0.18),
        border: Border.all(
          color: IncilColors.onEmergency.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: IncilColors.onEmergency,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Translucent rounded card for the body messages.
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: IncilSpacing.lg,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: IncilColors.onEmergency.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: IncilColors.onEmergency,
          fontSize: 19,
          height: 1.45,
        ),
      ),
    );
  }
}
