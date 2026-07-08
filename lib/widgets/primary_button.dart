import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.tone = PrimaryButtonTone.normal,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final PrimaryButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = switch (tone) {
      PrimaryButtonTone.normal => null,
      PrimaryButtonTone.danger => FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.error,
        foregroundColor: theme.colorScheme.onError,
      ),
    };

    if (icon != null || trailingIcon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? trailingIcon),
        label: Text(label),
        style: style,
        iconAlignment: icon != null ? IconAlignment.start : IconAlignment.end,
      );
    }
    return FilledButton(onPressed: onPressed, style: style, child: Text(label));
  }
}

enum PrimaryButtonTone { normal, danger }
