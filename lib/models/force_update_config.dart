import 'package:equatable/equatable.dart';

class ForceUpdateConfig extends Equatable {
  const ForceUpdateConfig({
    required this.enabled,
    this.minIosBuildNumber,
    this.minAndroidVersionCode,
    this.title,
    this.message,
    this.iosStoreUrl,
    this.androidStoreUrl,
  });

  final bool enabled;
  final int? minIosBuildNumber;
  final int? minAndroidVersionCode;
  final String? title;
  final String? message;
  final String? iosStoreUrl;
  final String? androidStoreUrl;

  static const empty = ForceUpdateConfig(enabled: false);

  factory ForceUpdateConfig.fromJson(Map<String, dynamic> json) {
    return ForceUpdateConfig(
      enabled: json['enabled'] as bool? ?? false,
      // Firestore uses the short `ios` / `android` keys; the offline cache
      // (toJson) keeps the long names.
      minIosBuildNumber: ((json['minIosBuildNumber'] ?? json['ios']) as num?)
          ?.toInt(),
      minAndroidVersionCode:
          ((json['minAndroidVersionCode'] ?? json['android']) as num?)?.toInt(),
      title: _nonEmpty(json['title'] as String?),
      message: _nonEmpty(json['message'] as String?),
      iosStoreUrl: _nonEmpty(json['iosStoreUrl'] as String?),
      androidStoreUrl: _nonEmpty(json['androidStoreUrl'] as String?),
    );
  }

  /// Firestore consoles make it easy to leave a field as `""`; treat that
  /// the same as absent so defaults/fallbacks apply.
  static String? _nonEmpty(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    if (minIosBuildNumber != null) 'minIosBuildNumber': minIosBuildNumber,
    if (minAndroidVersionCode != null)
      'minAndroidVersionCode': minAndroidVersionCode,
    if (title != null) 'title': title,
    if (message != null) 'message': message,
    if (iosStoreUrl != null) 'iosStoreUrl': iosStoreUrl,
    if (androidStoreUrl != null) 'androidStoreUrl': androidStoreUrl,
  };

  @override
  List<Object?> get props => [
    enabled,
    minIosBuildNumber,
    minAndroidVersionCode,
    title,
    message,
    iosStoreUrl,
    androidStoreUrl,
  ];
}
