import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/app_shell/app_shell_cubit.dart';
import '../cubits/onboarding/onboarding_cubit.dart';
import '../l10n/app_localizations.dart';
import '../models/onboarding_config.dart';
import '../models/onboarding_slide.dart';
import '../style/incil_colors.dart';
import '../style/incil_spacing.dart';
import '../widgets/primary_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.config});

  final OnboardingConfig config;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(total: config.slides.length),
      child: _OnboardingView(config: config),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView({required this.config});

  final OnboardingConfig config;

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  late final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _complete() {
    context.read<AppShellCubit>().markOnboardingCompleted(
      widget.config.version,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.watch<OnboardingCubit>();
    final pageState = cubit.state;
    final slides = widget.config.slides;

    if (slides.isEmpty) {
      // Guard: misconfigured Firestore — bypass onboarding.
      WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(IncilSpacing.sm),
                child: TextButton(
                  onPressed: _complete,
                  child: Text(l.onboardingSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: cubit.goTo,
                itemBuilder: (_, i) => _Slide(slide: slides[i]),
              ),
            ),
            _PageDots(count: slides.length, current: pageState.index),
            Padding(
              padding: const EdgeInsets.all(IncilSpacing.lg),
              child: PrimaryButton(
                label: pageState.isLast ? l.onboardingDone : l.onboardingNext,
                onPressed: () {
                  if (pageState.isLast) {
                    _complete();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.slide});
  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: IncilSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (slide.imageUrl != null)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: IncilSpacing.lg),
                child: Image.network(
                  slide.imageUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported_outlined, size: 96),
                  loadingBuilder: (_, child, p) => p == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: IncilSpacing.md),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? IncilColors.primary : IncilColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
