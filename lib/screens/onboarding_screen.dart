import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

    // Full-bleed design: the slide photo runs to the bottom edge; the
    // story-style progress bars + logo sit on top, the button floats at the
    // bottom.
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: slides.length,
            onPageChanged: cubit.goTo,
            itemBuilder: (_, i) =>
                _Slide(slide: slides[i], active: i == pageState.index),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: IncilSpacing.lg,
                  right: IncilSpacing.lg,
                  top: IncilSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StoryBars(count: slides.length, current: pageState.index),
                    const SizedBox(height: IncilSpacing.md),
                    const _LogoCard(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(IncilSpacing.lg),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    // Slight glow lifting the button off the photo.
                    boxShadow: [
                      BoxShadow(
                        color: IncilColors.primary.withValues(alpha: 0.45),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: pageState.isLast
                          ? l.onboardingDone
                          : l.onboardingNext,
                      trailingIcon: Icons.chevron_right,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Instagram-stories-style progress: one thin rounded bar per slide, past and
/// current bars filled, upcoming ones translucent.
class _StoryBars extends StatelessWidget {
  const _StoryBars({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              // Seen slides light up orange, upcoming ones stay cream.
              color: i <= current ? IncilColors.primary : IncilColors.beige,
              borderRadius: BorderRadius.circular(2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 3),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// The incil logo in its own small rounded card, matching the mockup's
/// top-left badge.
class _LogoCard extends StatelessWidget {
  const _LogoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: IncilSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: IncilColors.card.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SvgPicture.asset(
        'assets/logo/incil_logo_classic.svg',
        height: 28,
        semanticsLabel: 'incil',
      ),
    );
  }
}

class _Slide extends StatefulWidget {
  const _Slide({required this.slide, required this.active});
  final OnboardingSlide slide;

  /// Whether this slide is the current page. PageView pre-builds neighbours
  /// during the swipe, so the entrance animation must wait for activation
  /// instead of firing on build.
  final bool active;

  @override
  State<_Slide> createState() => _SlideState();
}

class _SlideState extends State<_Slide> with SingleTickerProviderStateMixin {
  // Chat-bubble entrance: the card pops in from its top-left "tail" corner.
  late final AnimationController _bubbleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _bubbleScale = CurvedAnimation(
    parent: _bubbleController,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _bubbleFade = CurvedAnimation(
    parent: _bubbleController,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _bubbleController.forward();
  }

  @override
  void didUpdateWidget(covariant _Slide oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Replay the entrance every time this slide becomes the current page.
    // The outgoing slide keeps its finished animation so it doesn't blink
    // while it scrolls away.
    if (widget.active && !oldWidget.active) {
      _bubbleController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slide = widget.slide;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (slide.imageUrl != null)
          Image(
            // Disk-backed: survives restarts and shares the cache key with
            // ImagePrewarmService, so a prewarmed slide renders instantly.
            image: CachedNetworkImageProvider(slide.imageUrl!),
            fit: BoxFit.cover,
            // Crop overflow at the bottom, never at the top.
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: IncilColors.beige),
            loadingBuilder: (_, child, p) =>
                p == null ? child : const ColoredBox(color: IncilColors.beige),
          )
        else
          const ColoredBox(color: IncilColors.beige),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: IncilSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 108),
                ScaleTransition(
                  scale: _bubbleScale,
                  alignment: Alignment.topLeft,
                  child: FadeTransition(
                    opacity: _bubbleFade,
                    // Message-bubble illusion: hug the left edge and leave a
                    // gap on the right instead of spanning the full width.
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                      ),
                      padding: const EdgeInsets.all(IncilSpacing.lg),
                      decoration: BoxDecoration(
                        color: IncilColors.card.withValues(alpha: 0.97),
                        // Chat-bubble shape: sharp top-left "tail" corner.
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(28),
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TwoToneTitle(title: slide.title),
                          const SizedBox(height: IncilSpacing.md),
                          Text(
                            slide.body,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders the slide title in the two-tone style of the mockups: everything
/// black except the last word, which gets the orange accent ("Was geht als
/// Nächstes?"). Newlines in the Firestore `title` field are kept as manual
/// line breaks. A single-word title renders fully in orange.
class _TwoToneTitle extends StatelessWidget {
  const _TwoToneTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayLarge;
    final match = RegExp(
      r'^([\s\S]*\s)(\S+)\s*$',
    ).firstMatch(title.trimRight());
    return Text.rich(
      TextSpan(
        style: style?.copyWith(color: IncilColors.onSurface),
        children: [
          if (match != null) TextSpan(text: match.group(1)),
          TextSpan(
            text: match?.group(2) ?? title,
            style: const TextStyle(color: IncilColors.primary),
          ),
        ],
      ),
    );
  }
}
