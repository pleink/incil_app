import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/app_state.dart';
import '../../services/app_state_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/push_service.dart';
import '../../services/version_service.dart';
import 'app_shell_state.dart';

class AppShellCubit extends Cubit<AppShellState> {
  AppShellCubit({
    required AppStateService appStateService,
    required VersionService versionService,
    required LocalStorageService storage,
    required PushService pushService,
    Duration splashTimeout = const Duration(seconds: 8),
  }) : _appStateService = appStateService,
       _versionService = versionService,
       _storage = storage,
       _pushService = pushService,
       super(const AppShellSplash()) {
    _subscription = _appStateService.stream.listen(_onAppState);
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

  StreamSubscription<AppState?>? _subscription;
  Timer? _splashTimer;
  String? _lastTagsSignature;

  void _onSplashTimeout() {
    if (state is AppShellSplash) emit(const AppShellOffline());
  }

  void _onAppState(AppState? appState) {
    _splashTimer?.cancel();
    _splashTimer = null;

    if (appState == null) return;

    _maybeApplyTags(appState.oneSignalTags);
    emit(_resolve(appState));
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
    unawaited(_pushService.requestPermission());
    final current = _appStateService.current;
    if (current != null) emit(_resolve(current));
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
  }

  @override
  Future<void> close() async {
    _splashTimer?.cancel();
    await _subscription?.cancel();
    return super.close();
  }
}
