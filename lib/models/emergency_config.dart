import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class EmergencyConfig extends Equatable {
  const EmergencyConfig({
    required this.enabled,
    this.title,
    this.subtitle,
    this.body1,
    this.contact,
    this.body2,
    this.footer,
    this.updatedAt,
  });

  final bool enabled;
  final String? title;
  final String? subtitle;
  final String? body1;
  final String? contact;
  final String? body2;
  final String? footer;
  final DateTime? updatedAt;

  static const empty = EmergencyConfig(enabled: false);

  static final _phonePattern = RegExp(r'^\+?[0-9]{3,15}$');
  static final _phoneSeparators = RegExp(r'[\s\-().]');

  /// Sanitized dialable phone number derived from [contact], or null when
  /// [contact] is missing or not a valid phone number.
  String? get callablePhone {
    final raw = contact;
    if (raw == null) return null;
    final sanitized = raw.replaceAll(_phoneSeparators, '');
    return _phonePattern.hasMatch(sanitized) ? sanitized : null;
  }

  factory EmergencyConfig.fromJson(Map<String, dynamic> json) {
    return EmergencyConfig(
      enabled: json['enabled'] as bool? ?? false,
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      body1: json['body1'] as String?,
      contact: json['contact'] as String?,
      body2: json['body2'] as String?,
      footer: json['footer'] as String?,
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    if (title != null) 'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    if (body1 != null) 'body1': body1,
    if (contact != null) 'contact': contact,
    if (body2 != null) 'body2': body2,
    if (footer != null) 'footer': footer,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [
    enabled,
    title,
    subtitle,
    body1,
    contact,
    body2,
    footer,
    updatedAt,
  ];
}

// Firestore returns Timestamp; cached JSON returns ISO 8601 string.
DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}
