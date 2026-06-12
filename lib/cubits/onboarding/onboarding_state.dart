import 'package:equatable/equatable.dart';

class OnboardingPageState extends Equatable {
  const OnboardingPageState({required this.index, required this.total});

  final int index;
  final int total;

  bool get isFirst => index == 0;
  bool get isLast => index >= total - 1;

  OnboardingPageState copyWith({int? index, int? total}) => OnboardingPageState(
    index: index ?? this.index,
    total: total ?? this.total,
  );

  @override
  List<Object?> get props => [index, total];
}
