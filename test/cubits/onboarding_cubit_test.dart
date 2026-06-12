import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:incil_camp_app/cubits/onboarding/onboarding_cubit.dart';
import 'package:incil_camp_app/cubits/onboarding/onboarding_state.dart';

void main() {
  group('OnboardingCubit', () {
    test('starts at index 0', () {
      final cubit = OnboardingCubit(total: 3);
      expect(cubit.state, const OnboardingPageState(index: 0, total: 3));
      expect(cubit.state.isFirst, isTrue);
      expect(cubit.state.isLast, isFalse);
    });

    blocTest<OnboardingCubit, OnboardingPageState>(
      'next() advances by one but stops at the last slide',
      build: () => OnboardingCubit(total: 2),
      act: (c) {
        c.next();
        c.next();
        c.next(); // no-op
      },
      expect: () => const [OnboardingPageState(index: 1, total: 2)],
    );

    blocTest<OnboardingCubit, OnboardingPageState>(
      'goTo() jumps to the given index and ignores out-of-range values',
      build: () => OnboardingCubit(total: 4),
      act: (c) {
        c.goTo(2);
        c.goTo(-1);
        c.goTo(10);
        c.goTo(0);
      },
      expect: () => const [
        OnboardingPageState(index: 2, total: 4),
        OnboardingPageState(index: 0, total: 4),
      ],
    );

    test('isLast reflects the last index', () {
      final cubit = OnboardingCubit(total: 3);
      cubit.goTo(2);
      expect(cubit.state.isLast, isTrue);
    });
  });
}
