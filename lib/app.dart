import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'config/flavor.dart';
import 'models/app_state.dart';
import 'cubits/app_shell/app_shell_cubit.dart';
import 'di/service_locator.dart';
import 'l10n/app_localizations.dart';
import 'navigation/app_router.dart';
import 'services/app_state_service.dart';
import 'services/connectivity_service.dart';
import 'services/image_prewarm_service.dart';
import 'services/local_storage_service.dart';
import 'services/push_service.dart';
import 'services/version_service.dart';
import 'style/incil_theme.dart';

class IncilApp extends StatefulWidget {
  const IncilApp({super.key, required this.flavor});

  final Flavor flavor;

  @override
  State<IncilApp> createState() => _IncilAppState();
}

class _IncilAppState extends State<IncilApp> {
  late final AppShellCubit _cubit = AppShellCubit(
    appStateService: getIt<AppStateService>(),
    versionService: getIt<VersionService>(),
    storage: getIt<LocalStorageService>(),
    pushService: getIt<PushService>(),
    connectivity: getIt<ConnectivityService>(),
    imagePrewarm: getIt<ImagePrewarmService>(),
  );

  late final _router = buildAppRouter(_cubit);

  @override
  void initState() {
    super.initState();
    // Route OneSignal notification taps through the shell so the host allowlist
    // applies and a tap can never bypass an emergency / force-update screen.
    getIt<PushService>().onTargetUrl = _cubit.handleDeepLink;
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppShellCubit>.value(
      value: _cubit,
      child: MaterialApp.router(
        title: widget.flavor.displayName,
        debugShowCheckedModeBanner: widget.flavor == Flavor.dev,
        theme: IncilTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
        builder: (context, child) =>
            _OnboardingImagePrecacher(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Warms Flutter's image cache with the onboarding slide images as soon as an
/// [AppState] is available — i.e. while the artificial splash is still
/// showing — so the slides don't pop in after the onboarding screen appears.
class _OnboardingImagePrecacher extends StatefulWidget {
  const _OnboardingImagePrecacher({required this.child});

  final Widget child;

  @override
  State<_OnboardingImagePrecacher> createState() =>
      _OnboardingImagePrecacherState();
}

class _OnboardingImagePrecacherState extends State<_OnboardingImagePrecacher> {
  StreamSubscription<AppState?>? _sub;
  final _precached = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= getIt<AppStateService>().stream.listen(_precacheSlides);
  }

  void _precacheSlides(AppState? state) {
    if (state == null || !mounted) return;
    for (final slide in state.onboarding.slides) {
      final url = slide.imageUrl;
      if (url == null || !_precached.add(url)) continue;
      // Failures are non-fatal: the slide's errorBuilder shows the beige
      // fallback and a later Image.network retries the download itself.
      unawaited(precacheImage(NetworkImage(url), context, onError: (_, __) {}));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
