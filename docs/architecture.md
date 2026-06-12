# Architecture

This is a deliberately **lightweight** version of the architecture used in
`migrol-flutter-app`. We borrow the spine — Cubit + GetIt + a Firestore-backed
state service + a typed router — but skip migrol's heavier machinery (Realm,
Chopper, scoped DI ladder, `Either<Failure,T>`, encrypted env files) because a
WebView shell driven by a single Firestore document doesn't need them.

---

## Folder layout

```
lib/
  main_dev.dart, main_prod.dart       # flavor entrypoints → bootstrap()
  bootstrap.dart                      # init Firebase, OneSignal, DI, AppStateService, runApp
  app.dart                            # IncilApp = MaterialApp.router + BlocProvider<AppShellCubit>

  config/
    flavor.dart                       # Flavor enum (display name, OneSignal ID, Firebase project, defaultAppState)
    firebase/                         # firebase_options_{dev,prod}.dart (stubs until flutterfire configure)

  di/service_locator.dart             # GetIt singletons

  models/                             # AppState, EmergencyConfig, ForceUpdateConfig, OnboardingConfig, OnboardingSlide
  services/                           # AppStateService, LocalStorageService, VersionService, ConnectivityService, PushService, UrlService

  cubits/
    app_shell/                        # screen-priority decision
    onboarding/                       # PageView index state
    webview/                          # webview load/error state

  navigation/app_router.dart          # GoRouter + redirect + ChangeNotifier wrapper around cubit stream

  screens/                            # splash, onboarding, emergency, force_update, webview, offline
  widgets/                            # IncilLogo, PrimaryButton, LoadingView, ErrorView
  style/                              # IncilColors, IncilTypography, IncilSpacing, IncilTheme
  util/host_allowlist.dart            # pure isHostAllowed function
  l10n/                               # generated AppLocalizations

l10n/app_de.arb                       # source ARB
test/                                 # util/, cubits/, models round-trip
```

---

## Data flow

```
Firestore doc                                      SharedPreferences cache
 apps/incil/config/app_state                        cachedAppStateJson
        │                                                  ▲
        ▼                                                  │
 AppStateService                                           │
   - snapshot → AppState.fromJson → write cache → emit     │
   - BehaviorSubject seeded from (cache ?? flavor.defaultAppState)
        │
        ▼  Stream<AppState?>
 AppShellCubit
   - resolves screen-priority: emergency > forceUpdate > onboarding > webview
   - applies oneSignalTags (de-duplicated)
   - 8s splash timeout → AppShellOffline if no data
        │
        ▼  AppShellState
 GoRouter.redirect (refreshListenable wraps the cubit's stream)
        │
        ▼
 Screen widgets read the typed state via cubit.state (or via the route).
```

OneSignal click listener → `AppShellCubit.handleDeepLink(uri)` → if host allowed
**and** WebView is the active surface, emit a new `AppShellWebView` with the
deep-link URL.

WebView load errors → `WebViewCubit.onLoadFailed` → `BlocListener` →
`AppShellCubit.reportWebViewFailure` → `AppShellOffline`.

---

## Services (GetIt singletons)

All in one scope (`lib/di/service_locator.dart`). No scope ladder.

| Service | Type | Responsibility |
|---|---|---|
| `Flavor` | singleton | Current flavor, read by any service that needs the OneSignal ID / Firebase project / default URL |
| `SharedPreferences` | singleton | Underlying KV store |
| `LocalStorageService` | singleton | Typed access to `completedOnboardingVersion` + cached AppState JSON |
| `VersionService` | singleton | `currentBuild` from package_info_plus + `mustForceUpdate(config)` |
| `ConnectivityService` | lazySingleton | `isOnline()` + `onlineStream` from connectivity_plus |
| `UrlService` | lazySingleton | `openExternal(Uri)`, `dial(phone)` via url_launcher |
| `PushService` | lazySingleton | OneSignal `initialize`, `requestPermission`, `applyTags`; exposes `onTargetUrl` callback |
| `FirebaseFirestore` | lazySingleton | `FirebaseFirestore.instance` |
| `AppStateService` | lazySingleton | Firestore listener + offline cache, seeded by `flavor.defaultAppState` |

`AppShellCubit` and the screen-level cubits are **not** registered in GetIt —
`AppShellCubit` is owned by `IncilApp`'s state, and per-screen cubits are
constructed inline via `BlocProvider`.

---

## Screen-priority logic (the only routing decision)

`AppShellCubit._resolve(AppState)`:

```dart
if (appState.emergency.enabled)              return AppShellEmergency(...);
if (versionService.mustForceUpdate(...))     return AppShellForceUpdate(...);
if (shouldShowOnboarding(...))               return AppShellOnboarding(...);
return AppShellWebView(...);
```

`shouldShowOnboarding`:
```dart
onboarding.enabled && storage.completedOnboardingVersion < onboarding.version
```

The `GoRouter.redirect` collapses the cubit state to a path:

| State                | Path             |
|----------------------|------------------|
| `AppShellSplash`     | `/splash`        |
| `AppShellEmergency`  | `/emergency`     |
| `AppShellForceUpdate`| `/force-update`  |
| `AppShellOnboarding` | `/onboarding`    |
| `AppShellWebView`    | `/webview`       |
| `AppShellOffline`    | `/offline`       |

Each route's `builder` reads the live cubit state for its config payload.

---

## Offline & retry behavior

Two paths into `AppShellOffline`:

1. **Cold start, no data:** `AppStateService` has no cache and Firestore never
   responds. After `splashTimeout` (8 s by default), `AppShellCubit` emits
   `AppShellOffline`.
2. **WebView load failure:** `WebViewCubit.onLoadFailed` fires on main-frame
   errors → `BlocListener` calls `AppShellCubit.reportWebViewFailure`.

Retry: `OfflineScreen` button → `AppShellCubit.retryFromOffline()` → cancels
and restarts the Firestore subscription and re-arms the splash timer.

---

## Push notifications

`PushService.initialize(flavor)` runs once from `bootstrap()`:
- `OneSignal.initialize(flavor.oneSignalAppId)`
- Adds a click listener that extracts `additionalData['targetUrl']` and calls
  `onTargetUrl(Uri)`.

`IncilApp.initState` sets `PushService.onTargetUrl = _cubit.handleDeepLink`,
so notification taps always go through the cubit (which enforces the host
allowlist and the active-surface check).

Push permission is requested **after onboarding completes** (not at cold start)
per OneSignal's UX guidance.

Tags are applied whenever `AppStateService` emits a new `oneSignalTags` map; a
signature check avoids re-applying the same map on every snapshot.

---

## What we explicitly skipped vs migrol

| migrol pattern | Why we don't use it (yet) |
|---|---|
| Realm | One Firestore doc + onboarding flag fits in SharedPreferences |
| Chopper / OpenAPI codegen | No REST API in the shell — everything is Firestore or WebView |
| `Either<Failure,T>` + sealed Failure | Try/catch at service boundaries is enough for a 6-screen shell |
| Scoped GetIt ladder (core/services/repos/usecases/blocs) | Single scope; no auth flow or multi-stage init |
| Encrypted `.env.{flavor}.enc` files | OneSignal IDs and Firebase project names aren't secrets |
| `go_router_builder` typed routes + codegen | 6 static routes don't justify the codegen overhead yet |
| `intl_utils` / POEditor | German-only, one ARB file, no translator workflow |

All of these are easy to layer in later if requirements grow.
