import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/app_state.dart';
import '../../services/app_state_service.dart';
import '../../services/connectivity_service.dart';
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
    Duration minSplashDuration = const Duration(seconds: 2),
    Duration splashTimeout = const Duration(seconds: 8),
  }) : _appStateService = appStateService,
       _versionService = versionService,
       _storage = storage,
       _pushService = pushService,
       _connectivity = connectivity,
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

    if (_appStateService.current != null) {
      _onAppState(_appStateService.current);
    } else {
      _splashTimer = Timer(splashTimeout, _onSplashTimeout);
    }
  }

  final AppStateService _appStateService;
  final VersionService _versionService;
  final LocalStorageService _storage;
  final PushService _pushService;
  final ConnectivityService _connectivity;

  StreamSubscription<AppState?>? _subscription;
  StreamSubscription<bool>? _connSubscription;
  Timer? _splashTimer;
  Timer? _minSplashTimer;
  bool _minSplashElapsed = false;
  String? _lastTagsSignature;
  bool _isOnline = true;

  void _onSplashTimeout() {
    if (state is AppShellSplash) emit(const AppShellOffline());
  }

  void _onMinSplashElapsed() {
    _minSplashElapsed = true;
    final current = _appStateService.current;
    if (current != null) _resolveAndEmit(current);
  }

  void _onAppState(AppState? appState) {
    if (appState == null) return;
    _maybeApplyTags(appState.oneSignalTags);
    if (!_minSplashElapsed) return;
    _resolveAndEmit(appState);
  }

  void _resolveAndEmit(AppState appState) {
    _splashTimer?.cancel();
    _splashTimer = null;
    final next = _resolve(appState);
    emit(next);
    if (next is AppShellWebView) _maybeRequestPushPermission();
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

  void _maybeRequestPushPermission() {
    if (_storage.pushPermissionRequested) return;
    unawaited(_pushService.requestPermission());
    unawaited(_storage.setPushPermissionRequested());
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
    return AppShellWebView(
      url: appState.webviewUrl,
      allowedHosts: appState.allowedHosts,
      oneSignalTags: appState.oneSignalTags,
    );
  }

  bool _shouldShowOnboarding(onboarding) {
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
    await _storage.setCompletedOnboardingVersion(version);
    _maybeRequestPushPermission();
    final current = _appStateService.current;
    if (current != null) emit(_resolve(current));
  }

  void handleDeepLink(Uri uri) {
    final current = _appStateService.current;
    if (current == null) return;
    if (!isHostAllowed(uri, current.allowedHosts)) return;
    // Only act when the WebView is the active surface — emergency / force-update
    // / onboarding take precedence and we don't want a push to bypass them.
    if (state is! AppShellWebView) return;
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
    // we don't hang on Splash when there's already data to work with.
    final current = _appStateService.current;
    if (current != null) _onAppState(current);
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
