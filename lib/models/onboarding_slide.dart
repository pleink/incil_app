import 'package:equatable/equatable.dart';

class OnboardingSlide extends Equatable {
  const OnboardingSlide({
    required this.title,
    required this.body,
    this.imageUrl,
  });

  final String title;
  final String body;
  final String? imageUrl;

  factory OnboardingSlide.fromJson(Map<String, dynamic> json) {
    return OnboardingSlide(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };

  @override
  List<Object?> get props => [title, body, imageUrl];
}
