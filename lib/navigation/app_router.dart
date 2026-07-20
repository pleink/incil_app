import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubits/app_shell/app_shell_cubit.dart';
import '../cubits/app_shell/app_shell_state.dart';
import '../screens/emergency_screen.dart';
import '../services/analytics_service.dart';
import '../screens/force_update_screen.dart';
import '../screens/offline_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/webview_screen.dart';
import '../style/incil_system_ui.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const emergency = '/emergency';
  static const forceUpdate = '/force-update';
  static const onboarding = '/onboarding';
  static const webview = '/webview';
  static const offline = '/offline';
}

GoRouter buildAppRouter(AppShellCubit cubit, {AnalyticsService? analytics}) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: _CubitListenable(cubit.stream),
    redirect: (context, state) {
      final target = _redirectFor(cubit.state);
      // Screen tracking lives here because navigation is redirect-driven:
      // every screen change passes through this resolver. The service
      // dedupes the repeat calls for an unchanged screen.
      analytics?.logScreen(target ?? state.matchedLocation);
      return target;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.emergency,
        // BlocBuilder instead of reading cubit.state once: the config can
        // change (new title/body) while the screen is already on display,
        // and go_router won't rebuild the page for a same-path redirect.
        builder: (_, __) => BlocBuilder<AppShellCubit, AppShellState>(
          builder: (_, s) => s is AppShellEmergency
              ? EmergencyScreen(config: s.config)
              : const SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forceUpdate,
        builder: (_, __) {
          final s = cubit.state;
          return s is AppShellForceUpdate
              ? ForceUpdateScreen(config: s.config)
              : const SplashScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) {
          final s = cubit.state;
          return s is AppShellOnboarding
              ? OnboardingScreen(config: s.config)
              : const SplashScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.webview,
        builder: (_, __) {
          final s = cubit.state;
          return s is AppShellWebView
              ? WebViewScreen(
                  url: s.url,
                  allowedHosts: s.allowedHosts,
                  inAppBrowserHosts: s.inAppBrowserHosts,
                  externalBrowserUrls: s.externalBrowserUrls,
                )
              : const SplashScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.offline,
        builder: (context, __) => OfflineScreen(
          onRetry: () => context.read<AppShellCubit>().retryFromOffline(),
        ),
      ),
    ],
  );
}

String? _redirectFor(AppShellState state) {
  return switch (state) {
    AppShellSplash() => AppRoutes.splash,
    AppShellEmergency() => AppRoutes.emergency,
    AppShellForceUpdate() => AppRoutes.forceUpdate,
    AppShellOnboarding() => AppRoutes.onboarding,
    AppShellWebView() => AppRoutes.webview,
    AppShellOffline() => AppRoutes.offline,
  };
}

/// Status-bar contrast for the active screen: dark backgrounds get light
/// icons, light backgrounds dark. Applied above the router, not per screen.
SystemUiOverlayStyle overlayStyleFor(AppShellState state) {
  return switch (state) {
    AppShellSplash() => IncilSystemUi.lightIcons,
    AppShellEmergency() => IncilSystemUi.lightIcons,
    AppShellOnboarding() => IncilSystemUi.lightIcons,
    AppShellForceUpdate() => IncilSystemUi.darkIcons,
    AppShellWebView() => IncilSystemUi.darkIcons,
    AppShellOffline() => IncilSystemUi.darkIcons,
  };
}

class _CubitListenable extends ChangeNotifier {
  _CubitListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
