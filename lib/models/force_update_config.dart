import 'package:equatable/equatable.dart';

class ForceUpdateConfig extends Equatable {
  const ForceUpdateConfig({
    required this.enabled,
    this.minIosBuild,
    this.minAndroidBuild,
    this.title,
    this.message,
    this.iosStoreUrl,
    this.androidStoreUrl,
  });

  final bool enabled;
  final int? minIosBuild;
  final int? minAndroidBuild;
  final String? title;
  final String? message;
  final String? iosStoreUrl;
  final String? androidStoreUrl;

  static const empty = ForceUpdateConfig(enabled: false);

  factory ForceUpdateConfig.fromJson(Map<String, dynamic> json) {
    return ForceUpdateConfig(
      enabled: json['enabled'] as bool? ?? false,
      minIosBuild: (json['minIosBuild'] as num?)?.toInt(),
      minAndroidBuild: (json['minAndroidBuild'] as num?)?.toInt(),
      title: json['title'] as String?,
      message: json['message'] as String?,
      iosStoreUrl: json['iosStoreUrl'] as String?,
      androidStoreUrl: json['androidStoreUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    if (minIosBuild != null) 'minIosBuild': minIosBuild,
    if (minAndroidBuild != null) 'minAndroidBuild': minAndroidBuild,
    if (title != null) 'title': title,
    if (message != null) 'message': message,
    if (iosStoreUrl != null) 'iosStoreUrl': iosStoreUrl,
    if (androidStoreUrl != null) 'androidStoreUrl': androidStoreUrl,
  };

  @override
  List<Object?> get props => [
    enabled,
    minIosBuild,
    minAndroidBuild,
    title,
    message,
    iosStoreUrl,
    androidStoreUrl,
  ];
}
