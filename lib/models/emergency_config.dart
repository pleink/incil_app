import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class EmergencyConfig extends Equatable {
  const EmergencyConfig({
    required this.enabled,
    this.title,
    this.message,
    this.primaryActionLabel,
    this.primaryActionPhone,
    this.secondaryActionLabel,
    this.secondaryActionUrl,
    this.updatedAt,
  });

  final bool enabled;
  final String? title;
  final String? message;
  final String? primaryActionLabel;
  final String? primaryActionPhone;
  final String? secondaryActionLabel;
  final String? secondaryActionUrl;
  final DateTime? updatedAt;

  static const empty = EmergencyConfig(enabled: false);

  factory EmergencyConfig.fromJson(Map<String, dynamic> json) {
    return EmergencyConfig(
      enabled: json['enabled'] as bool? ?? false,
      title: json['title'] as String?,
      message: json['message'] as String?,
      primaryActionLabel: json['primaryActionLabel'] as String?,
      primaryActionPhone: json['primaryActionPhone'] as String?,
      secondaryActionLabel: json['secondaryActionLabel'] as String?,
      secondaryActionUrl: json['secondaryActionUrl'] as String?,
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    if (title != null) 'title': title,
    if (message != null) 'message': message,
    if (primaryActionLabel != null) 'primaryActionLabel': primaryActionLabel,
    if (primaryActionPhone != null) 'primaryActionPhone': primaryActionPhone,
    if (secondaryActionLabel != null)
      'secondaryActionLabel': secondaryActionLabel,
    if (secondaryActionUrl != null) 'secondaryActionUrl': secondaryActionUrl,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [
    enabled,
    title,
    message,
    primaryActionLabel,
    primaryActionPhone,
    secondaryActionLabel,
    secondaryActionUrl,
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
