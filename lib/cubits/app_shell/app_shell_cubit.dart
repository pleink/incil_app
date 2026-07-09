import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/app_state.dart';
import '../../models/onboarding_config.dart';
import '../../services/app_state_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/image_prewarm_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/push_service.dart';
import '../../services/version_service.dart';
import '../../util/host_allowlist.dart';
import 'app_shell_state.dart';

class AppShellCubit extends Cubit<AppShellState> {
  AppShellCubit({
    required AppStateService appStateService,
    required VersionService versionService,
    required LocalStorageService storage,
    required PushService pushService,
    required ConnectivityService connectivity,
    required ImagePrewarmService imagePrewarm,
    Future<void> Function()? waitUntilForeground,
    Duration minSplashDuration = const Duration(seconds: 2),
    Duration splashTimeout = const Duration(seconds: 8),
  }) : _appStateService = appStateService,
       _versionService = versionService,
       _storage = storage,
       _pushService = pushService,
       _connectivity = connectivity,
       _imagePrewarm = imagePrewarm,
       _waitUntilForeground = waitUntilForeground,
       super(const AppShellSplash()) {
    _subscription = _appStateService.stream.listen(_onAppState);
    _connSubscription = _connectivity.onlineStream.listen(
      _onConnectivityChanged,
    );
    _connectivity.isOnline().then((online) => _isOnline = online);

    // Hold the branded splash for a beat so cached/fallback data can't resolve
    // it away before it's seen. The first Firestore snapshot and OneSignal init
    // run in the background meanwhile.
    if (minSplashDuration > Duration.zero) {
      _minSplashTimer = Timer(minSplashDuration, _onMinSplashElapsed);
    } else {
      _minSplashElapsed = true;
    }

    // The timeout always runs: with no data at all it lands on Offline, with
    // only cached/fallback data it resolves that as a last resort (see
    // _onSplashTimeout).
    _splashTimer = Timer(splashTimeout, _onSplashTimeout);
    if (_appStateService.current != null) {
      _onAppState(_appStateService.current);
    }
  }

  final AppStateService _appStateService;
  final VersionService _versionService;
  final LocalStorageService _storage;
  final PushService _pushService;
  final ConnectivityService _connectivity;
  final ImagePrewarmService _imagePrewarm;

  /// Completes once the app is foregrounded (`waitUntilAppResumed` in
  /// production; null in tests, where there is no widget binding).
  final Future<void> Function()? _waitUntilForeground;

  StreamSubscription<AppState?>? _subscription;
  StreamSubscription<bool>? _connSubscription;
  Timer? _splashTimer;
  Timer? _minSplashTimer;
  bool _minSplashElapsed = false;
  String? _lastTagsSignature;
  bool _isOnline = true;

  /// Deep link waiting for the shell to resolve to WebView (in-memory only).
  /// Validated against the allowlist at apply-time, not receive-time.
  Uri? _pendingDeepLink;

  /// Last `webviewUrl` seen from config. Lets us tell a routine Firestore
  /// snapshot (same config URL → keep whatever URL the user navigated to,
  /// e.g. an applied deep link) apart from a real config change.
  String? _lastConfigWebviewUrl;

  void _onSplashTimeout() {
    if (state is! AppShellSplash) return;
    // No fresh snapshot arrived in time — fall back to whatever we have
    // (cached or fallback state); only a fully empty service means Offline.
    final current = _appStateService.current;
    if (current != null) {
      _resolveAndEmit(current);
    } else {
      emit(const AppShellOffline());
    }
  }

  void _onMinSplashElapsed() {
    _minSplashElapsed = true;
    if (!_appStateService.hasFreshData) return; // keep holding on Splash
    final current = _appStateService.current;
    if (current != null) _resolveAndEmit(current);
  }

  void _onAppState(AppState? appState) {
    if (appState == null) return;
    _maybeApplyTags(appState.oneSignalTags);
    if (!_minSplashElapsed) return;
    // While still on the splash, don't resolve from the cached/fallback seed —
    // a stale cache could flash the wrong surface (e.g. WebView for a beat,
    // then Onboarding once the live snapshot lands). Hold for the first fresh
    // snapshot; _onSplashTimeout is the escape hatch when Firestore is
    // unreachable.
    if (state is AppShellSplash && !_appStateService.hasFreshData) return;
    _resolveAndEmit(appState);
  }

  void _resolveAndEmit(AppState appState) {
    _splashTimer?.cancel();
    _splashTimer = null;
    final resolved = _resolve(appState);
    // Leaving the splash for onboarding: hold until the slide images are in
    // the image cache (bounded by the prewarm timeout) so the slides never
    // pop in after the screen is already visible.
    if (state is AppShellSplash && resolved is AppShellOnboarding) {
      final urls = [
        for (final slide in resolved.config.slides)
          if (slide.imageUrl != null) slide.imageUrl!,
      ];
      if (urls.isNotEmpty) {
        unawaited(_emitAfterPrewarm(resolved, urls));
        return;
      }
    }
    emit(resolved);
  }

  Future<void> _emitAfterPrewarm(
    AppShellOnboarding resolved,
    List<String> urls,
  ) async {
    await _imagePrewarm.prewarm(urls);
    // Only emit if nothing else resolved the shell in the meantime.
    if (!isClosed && state is AppShellSplash) emit(resolved);
  }

  void _onConnectivityChanged(bool online) {
    final wasOnline = _isOnline;
    _isOnline = online;
    if (online && !wasOnline && state is AppShellOffline) {
      // Network just came back while the user was looking at the Offline
      // screen — bounce them back into the regular shell.
      unawaited(retryFromOffline());
    }
  }

  Future<void> _maybeRequestPushPermission() async {
    if (_storage.pushPermissionRequested) return;
    unawaited(_storage.setPushPermissionRequested());
    await _pushService.requestPermission();
  }

  AppShellState _resolve(AppState appState) {
    if (appState.emergency.enabled) {
      return AppShellEmergency(appState.emergency);
    }
    if (_versionService.mustForceUpdate(appState.forceUpdate)) {
      return AppShellForceUpdate(appState.forceUpdate);
    }
    if (_shouldShowOnboarding(appState.onboarding)) {
      return AppShellOnboarding(appState.onboarding);
    }
    // First-launch offline guard: if we're showing the fallback URL with no
    // real Firestore/cached data AND the device is offline, the WebView is
    // guaranteed to fail. Skip the flicker and go straight to Offline.
    if (!_appStateService.hasRealData && !_isOnline) {
      return const AppShellOffline();
    }
    return _resolveWebView(appState);
  }

  AppShellState _resolveWebView(AppState appState) {
    // Consume the pending deep link unconditionally — whether it is applied
    // or rejected by the allowlist, it must not resurface on later snapshots.
    final pending = _pendingDeepLink;
    _pendingDeepLink = null;

    final configUrlUnchanged = appState.webviewUrl == _lastConfigWebviewUrl;
    _lastConfigWebviewUrl = appState.webviewUrl;

    if (pending != null && isHostAllowed(pending, appState.allowedHosts)) {
      return AppShellWebView(
        url: pending.toString(),
        allowedHosts: appState.allowedHosts,
        oneSignalTags: appState.oneSignalTags,
      );
    }

    // URL stability: on a routine snapshot with an unchanged config URL,
    // preserve the currently displayed URL (which may be a deep link) so
    // Firestore churn doesn't yank the user back to the home page.
    final current = state;
    if (current is AppShellWebView && configUrlUnchanged) {
      return AppShellWebView(
        url: current.url,
        allowedHosts: appState.allowedHosts,
        oneSignalTags: appState.oneSignalTags,
      );
    }

    return AppShellWebView(
      url: appState.webviewUrl,
      allowedHosts: appState.allowedHosts,
      oneSignalTags: appState.oneSignalTags,
    );
  }

  bool _shouldShowOnboarding(OnboardingConfig onboarding) {
    if (!onboarding.enabled) return false;
    return _storage.completedOnboardingVersion < onboarding.version;
  }

  void _maybeApplyTags(Map<String, String> tags) {
    final signature =
        (tags.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
            .map((e) => '${e.key}=${e.value}')
            .join('&');
    if (signature == _lastTagsSignature) return;
    _lastTagsSignature = signature;
    unawaited(_pushService.applyTags(tags));
  }

  Future<void> markOnboardingCompleted(int version) async {
    // The slide images no longer need to be pinned in the image cache.
    _imagePrewarm.release();
    // iOS: the permission alert puts the app in the inactive state; a
    // WKWebView platform view created during that window never paints (white
    // screen until the app is restarted). Hold the shell on Onboarding until
    // the user has answered the alert, and only then resolve to the WebView.
    // The version is persisted afterwards for the same reason: incoming
    // Firestore snapshots keep resolving to Onboarding while we wait.
    await _maybeRequestPushPermission();
    // The permission future resolves on the tap itself, while the dismissing
    // alert still holds the app inactive — a WebView created in that window
    // hangs mid-load. Wait until the app is fully resumed.
    await _waitUntilForeground?.call();
    await _storage.setCompletedOnboardingVersion(version);
    if (isClosed) return;
    final current = _appStateService.current;
    if (current != null) emit(_resolve(current));
  }

  void handleDeepLink(Uri uri) {
    final current = _appStateService.current;
    // Only act immediately when the WebView is the active surface — emergency /
    // force-update / onboarding take precedence and a push must not bypass
    // them. Otherwise queue the link (last-write-wins) and apply it once the
    // shell resolves to WebView; the allowlist check happens at apply-time.
    if (current == null || state is! AppShellWebView) {
      _pendingDeepLink = uri;
      return;
    }
    if (!isHostAllowed(uri, current.allowedHosts)) return;
    emit(
      AppShellWebView(
        url: uri.toString(),
        allowedHosts: current.allowedHosts,
        oneSignalTags: current.oneSignalTags,
      ),
    );
  }

  void reportWebViewFailure() {
    if (state is AppShellOffline) return;
    emit(const AppShellOffline());
  }

  Future<void> retryFromOffline() async {
    emit(const AppShellSplash());
    _splashTimer?.cancel();
    _splashTimer = Timer(const Duration(seconds: 8), _onSplashTimeout);
    await _appStateService.retry();
    // Re-resolve immediately against the (possibly cached) current state so
    // we don't hang on Splash when there's already data to work with. This
    // deliberately skips the hold-for-fresh gate: the user explicitly retried,
    // and _resolve's offline guard catches the still-offline case.
    final current = _appStateService.current;
    if (current != null) _resolveAndEmit(current);
  }

  @override
  Future<void> close() async {
    _splashTimer?.cancel();
    _minSplashTimer?.cancel();
    await _subscription?.cancel();
    await _connSubscription?.cancel();
    return super.close();
  }
}
