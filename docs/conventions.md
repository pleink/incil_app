# Conventions

## Naming

- Files: `lower_snake_case.dart` (e.g. `app_shell_cubit.dart`).
- Types: `UpperCamelCase` (e.g. `AppShellState`, `IncilTheme`).
- Constants / static finals: `lowerCamelCase` (e.g. `IncilSpacing.md`).
- Static token classes use `abstract final class` and only `static const`
  members (see `lib/style/incil_colors.dart`).

## Folder split

Feature-light, layer-first:

- `models/` — pure data + JSON.
- `services/` — long-lived singletons (registered in `lib/di/service_locator.dart`).
- `cubits/<feature>/<feature>_cubit.dart` + `<feature>_state.dart` (paired files).
- `screens/<feature>_screen.dart` — full-screen widgets, one per priority slot.
- `widgets/` — small reusable widgets (`IncilLogo`, `PrimaryButton`, `LoadingView`, `ErrorView`).
- `style/` — design tokens (no widget code, only `Color` / `TextStyle` / `double`).
- `util/` — pure functions (testable without Flutter).

## Cubits

- Always `extends Cubit<T>` with a **sealed** state class.
- State classes `extend Equatable`.
- One file per cubit, one for state, in `lib/cubits/<feature>/`.
- Don't expose the underlying stream; rely on `BlocBuilder` / `BlocListener` / `context.watch`.
- Constructor takes services as parameters — never reach into GetIt from inside
  a cubit. The widget that creates the cubit pulls services from `getIt<…>()`.

## Models (manual JSON)

Pattern, matching migrol:

```dart
class FooConfig extends Equatable {
  const FooConfig({required this.enabled, this.title});
  final bool enabled;
  final String? title;

  static const empty = FooConfig(enabled: false);

  factory FooConfig.fromJson(Map<String, dynamic> json) => FooConfig(
        enabled: json['enabled'] as bool? ?? false,
        title: json['title'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (title != null) 'title': title,
      };

  @override
  List<Object?> get props => [enabled, title];
}
```

No `freezed`, no `json_serializable`. Fields with `Timestamp` values in
Firestore are parsed by a small `_parseDate` helper that accepts both
`Timestamp` and ISO strings (so the cached-JSON round-trip works).

## Localization

- Source: `l10n/app_de.arb`.
- Generated: `lib/l10n/app_localizations.dart` + `app_localizations_de.dart`.
- Trigger regeneration: `fvm flutter gen-l10n` (also runs implicitly when
  `flutter.generate: true` is set in `pubspec.yaml` and you build/run).
- In widgets: `AppLocalizations.of(context).<key>`.
- New key workflow:
  1. Add to `l10n/app_de.arb` with `"key": "Wert"` + `"@key": {}`.
  2. `fvm flutter gen-l10n`.
  3. Reference as `AppLocalizations.of(context).key`.

Only `de` for v1. Adding `en` later = create `l10n/app_en.arb` (same keys),
regen, add `Locale('en')` to `supportedLocales`.

## Tests

- Pure functions: plain `test()` in `test/util/`.
- Cubits: `bloc_test` + `mocktail`. Mock services that the cubit consumes;
  use `setUpAll(() => registerFallbackValue(...))` for any `any()` matcher
  that needs a non-primitive type.
- Models: round-trip `toJson → fromJson` checks (see
  `test/widget_test.dart` for the AppState round-trip).
- VersionService isn't directly tested — its branch uses `dart:io Platform`
  which is awkward to mock. The cubit tests stub `mustForceUpdate(...)`
  to cover the routing branches.

## Codegen scope

- `flutter_localizations` + `gen-l10n` (automatic on build with
  `flutter.generate: true`).
- **No** `build_runner` codegen in source for now. `build_runner` and
  `go_router_builder` are pinned in `dev_dependencies` so we can add typed
  routes later without a pubspec edit.

## Excluded from analysis

Set in `analysis_options.yaml`:
- `lib/l10n/**` (generated)
- `lib/**/*.g.dart` (future codegen output)
- `lib/config/firebase/**` (flutterfire-generated)
