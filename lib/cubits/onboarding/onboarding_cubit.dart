import 'package:flutter_bloc/flutter_bloc.dart';

import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingPageState> {
  OnboardingCubit({required int total})
    : super(OnboardingPageState(index: 0, total: total));

  void next() {
    if (state.isLast) return;
    emit(state.copyWith(index: state.index + 1));
  }

  void goTo(int index) {
    if (index < 0 || index >= state.total) return;
    emit(state.copyWith(index: index));
  }
}
