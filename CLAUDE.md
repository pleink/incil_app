# CLAUDE.md

Guidance for Claude Code when working in this repository.

Detailed references: [Architecture](docs/architecture.md) · [Conventions](docs/conventions.md) · [Setup](docs/setup.md) · [Tooling](docs/tooling.md)

---

## What this app is

**Incil CampApp** is a branded Flutter mobile shell around a huulo.io WebView.
Native screens cover splash, onboarding, emergency, force-update, and offline;
everything else is the WebView. Remote control comes from a single Firestore
document (`apps/incil/config/app_state`). Push notifications go through
OneSignal. Platforms: **iOS + Android only**.

Read [docs/architecture.md](docs/architecture.md) for the full spine and
[docs/setup.md](docs/setup.md) for the manual one-time steps (Firebase,
Xcode schemes, OneSignal capabilities, Firestore seed).

---

## Commands

Two flavor entrypoints; always run through `fvm` (Flutter pinned to 3.35.7).

```bash
fvm flutter pub get
fvm flutter run --flavor dev  -t lib/main_dev.dart
fvm flutter run --flavor prod -t lib/main_prod.dart

fvm flutter analyze
fvm flutter test

fvm flutter gen-l10n                                  # regenerate lib/l10n/
fvm flutter build apk      --flavor dev  -t lib/main_dev.dart
fvm flutter build appbundle --flavor prod -t lib/main_prod.dart
fvm flutter build ios      --flavor prod -t lib/main_prod.dart
```

`flutter run` against `lib/main.dart` throws on purpose — use the flavor entrypoints.

---

## Architecture in one screen

- **Stack:** Cubit + GetIt (single scope) + go_router (plain `GoRoute`, no codegen).
- **One Firestore listener** (`AppStateService`) feeds `AppShellCubit`, which
  resolves the screen-priority decision:
  `emergency > forceUpdate > onboarding > webview`. A `GoRouter.redirect`
  watches the cubit and snaps to the right path. `AppShellOffline` is reached
  either by an 8s splash timeout with no data, or by a WebView load failure.
- **Offline cache:** SharedPreferences. Last good Firestore doc is cached on
  every snapshot and seeds the BehaviorSubject on the next cold start.
- **Fallback:** Until the Firestore doc is seeded, `Flavor.defaultAppState`
  points at `https://incil-24-4366.huulo.app/` so the app boots into WebView
  without Firebase.
- **OneSignal:** initialized in `bootstrap()`. Click listener routes
  `additionalData.targetUrl` into `AppShellCubit.handleDeepLink`, which checks
  the host allowlist and only swaps the WebView when WebView is the active
  surface — pushes can't bypass emergency/force-update/onboarding.

Full detail: [docs/architecture.md](docs/architecture.md).

---

## Conventions

- File names `lower_snake_case`; types `UpperCamelCase`.
- All cubits are sealed-state `Cubit<T>`; state classes extend `Equatable`.
- Models use **manual `fromJson` / `toJson` / `copyWith`** — no codegen.
- Localization: `flutter_localizations` + `gen-l10n`, source ARB `l10n/app_de.arb`.
  Locale is currently `de` only. Access via `AppLocalizations.of(context)`.
- Lints: default `flutter_lints` set (`analysis_options.yaml`). Generated
  output (`lib/l10n/**`, `lib/**/*.g.dart`, `lib/config/firebase/**`) excluded.

Full detail: [docs/conventions.md](docs/conventions.md).

---

## Flavor / env config

Hardcoded in `lib/config/flavor.dart`:

| Flavor | Android package        | iOS bundle ID         | Firebase project    | OneSignal App ID                       |
|--------|------------------------|-----------------------|---------------------|----------------------------------------|
| `dev`  | `ch.incil.camp_app.dev`| `ch.incil.campApp.dev`| `incil-campapp-dev` | `028782a9-e433-4e82-8ccb-37b83aeb3b89` |
| `prod` | `ch.incil.camp_app`    | `ch.incil.campApp`    | `incil-campapp`     | `3e8f7a53-8b01-4d37-8748-058896c8329b` |

Android uses underscores; iOS uses camelCase because Apple rejects underscores in bundle IDs.

Android flavors live in `android/app/build.gradle.kts`. iOS scheme split is a
manual Xcode step — see [docs/setup.md](docs/setup.md).

---

## Further Reading

| File | Contents |
|------|----------|
| [docs/architecture.md](docs/architecture.md) | Folder layout, services, cubits, router, screen-priority logic, data flow |
| [docs/conventions.md](docs/conventions.md)   | Naming, l10n, testing patterns, codegen scope |
| [docs/setup.md](docs/setup.md)               | One-time manual steps: Firebase, iOS schemes, OneSignal, Firestore seed |
| [docs/tooling.md](docs/tooling.md)           | fvm, MCP servers, mobile-dev plugin skills, dev setup, CLI cheatsheet |
