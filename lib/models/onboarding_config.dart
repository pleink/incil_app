import 'package:equatable/equatable.dart';

import 'onboarding_slide.dart';

class OnboardingConfig extends Equatable {
  const OnboardingConfig({
    required this.enabled,
    required this.version,
    required this.slides,
  });

  final bool enabled;
  final int version;
  final List<OnboardingSlide> slides;

  static const empty = OnboardingConfig(enabled: false, version: 0, slides: []);

  factory OnboardingConfig.fromJson(Map<String, dynamic> json) {
    final rawSlides = json['slides'];
    final slides = rawSlides is List
        ? rawSlides
              .whereType<Map>()
              .map(
                (e) => OnboardingSlide.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList(growable: false)
        : const <OnboardingSlide>[];
    return OnboardingConfig(
      enabled: json['enabled'] as bool? ?? false,
      version: (json['version'] as num?)?.toInt() ?? 0,
      slides: slides,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'version': version,
    'slides': slides.map((s) => s.toJson()).toList(),
  };

  @override
  List<Object?> get props => [enabled, version, slides];
}
