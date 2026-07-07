# Manual setup steps

Some milestones (M2, M12) depend on credentials or Xcode/Android tooling that
the harness can't run. This file lists those one-time steps, grouped by what
they unblock.

---

## 1. Firebase (unblocks Firestore + DataStore)

Both flavors point at separate Firebase projects:

- `dev` → `incil-campapp-dev`
- `prod` → `incil-campapp`

### Prerequisites (once per machine)

```bash
# 1. Firebase CLI must be installed and logged in. Without this, flutterfire
#    configure hangs forever on "Fetching available Firebase projects…".
firebase login            # opens a browser; pick the Google account that owns the projects
firebase projects:list    # sanity check — should list incil-campapp-dev and incil-campapp

# 2. flutterfire_cli activated against fvm's Dart (matches the project SDK,
#    avoids "Invalid kernel binary format version" when invoked via the
#    pub-cache wrapper).
fvm dart pub global deactivate flutterfire_cli 2>/dev/null || true
fvm dart pub global activate flutterfire_cli
```

If you previously had system Dart in PATH, also make sure fvm's bin is in
front of it so the pub-cache `flutterfire` wrapper picks up Dart 3.9.2:

```bash
# Add to ~/.zshrc (already done in this repo's onboarding):
export PATH="$HOME/fvm/default/bin:$PATH"
fvm global 3.35.7         # ensures ~/fvm/default points at the right SDK
```

### Run the configure

```bash
dart pub global activate flutterfire_cli

# Dev
flutterfire configure \
  --project=incil-campapp-dev \
  --out=lib/config/firebase/firebase_options_dev.dart \
  --ios-bundle-id=ch.incil.campApp.dev \
  --android-package-name=ch.incil.camp_app.dev \
  --platforms=ios,android

# Move the per-platform files into the dev sourceset before running prod:
mkdir -p android/app/src/dev
mv android/app/google-services.json android/app/src/dev/google-services.json
mv ios/Runner/GoogleService-Info.plist ios/Runner/GoogleService-Info-Dev.plist

# Prod
flutterfire configure \
  --project=incil-campapp \
  --out=lib/config/firebase/firebase_options_prod.dart \
  --ios-bundle-id=ch.incil.campApp \
  --android-package-name=ch.incil.camp_app \
  --platforms=ios,android

mkdir -p android/app/src/prod
mv android/app/google-services.json android/app/src/prod/google-services.json
mv ios/Runner/GoogleService-Info.plist ios/Runner/GoogleService-Info-Prod.plist
```

The placeholder `firebase_options_{dev,prod}.dart` files throw `UnsupportedError`
at runtime — `flutterfire configure` replaces them with real generated code.

### Android Google Services plugin

After flutterfire configure, apply the Gradle plugin so `google-services.json`
is processed:

- `android/settings.gradle.kts` → in the `plugins {}` block add
  `id("com.google.gms.google-services") version "4.4.2" apply false`.
- `android/app/build.gradle.kts` → in the top `plugins {}` block add
  `id("com.google.gms.google-services")`.

### iOS GoogleService-Info copy phase

Add a Build Phase "Run Script" _before_ "Copy Bundle Resources":

```bash
case "$CONFIGURATION" in
  *dev*) PLIST="${PROJECT_DIR}/Runner/GoogleService-Info-Dev.plist" ;;
  *)     PLIST="${PROJECT_DIR}/Runner/GoogleService-Info-Prod.plist" ;;
esac
cp -v "$PLIST" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
```

Also **remove the plain `GoogleService-Info.plist` file reference** the template
ships — it shows red in the navigator and sits in Copy Bundle Resources, so the
build fails with _"Build input file cannot be found"_ until you select it and
**Remove Reference**. The run script above regenerates the right plist into the
bundle per flavor.

`bootstrap()` calls `Firebase.initializeApp(options: firebaseOptionsFor(flavor))`
with explicit Dart options, so the native plist isn't required just to launch —
this copy phase only matters for native Firebase features (Analytics
auto-collection, Crashlytics) that read `GoogleService-Info.plist` directly.

---

## 2. iOS flavor split (Dev / Prod schemes)

Unlike Android (flavors live in Gradle), iOS flavors are pure Xcode config — no
codegen. `--flavor dev` needs a matching **scheme** plus per-flavor **build
configurations**.

> **Scheme names must be exactly `Dev` / `Prod`** — not `Runner-Dev` /
> `Runner-Prod`. Flutter 3.35.7 matches `--flavor dev` to a scheme whose name
> (case-insensitive) **equals** `Dev` (`sentenceCase(flavor)`), so `Runner-Dev`
> does not match and the build exits with _"You must specify a --flavor
> option…"_. See `flutter_tools/lib/src/ios/xcodeproj.dart` → `schemeFor`.

In Xcode:

1. **Schemes** (Product → Scheme → Manage Schemes): create two schemes named
   exactly `Dev` and `Prod`, and tick **Shared** for both (so `xcodebuild -list`
   finds them). Keep the default `Runner` scheme.
2. **Build configurations** (PROJECT ▸ Runner → Info → Configurations):
   duplicate `Debug`/`Release`/`Profile` into the six flavor configs —
   `Debug-dev`, `Release-dev`, `Profile-dev` and the matching `*-prod` set. The
   `-dev` / `-prod` suffix is what Flutter matches (`Debug-<flavor>`).
3. **Bundle IDs** (TARGETS ▸ Runner → Build Settings → _Product Bundle
   Identifier_), set per configuration:
   - `Debug-dev` / `Release-dev` / `Profile-dev` → `ch.incil.campApp.dev`
   - `Debug-prod` / `Release-prod` / `Profile-prod` → `ch.incil.campApp`

   Set this in **Build Settings**, not an `.xcconfig`: the project defines
   `PRODUCT_BUNDLE_IDENTIFIER` at the target level, which overrides any base
   `.xcconfig`. iOS bundle IDs are **camelCase** (`campApp`) — Apple rejects the
   underscores used in the Android package names.

4. **Podfile config map** (`ios/Podfile`): map all nine configs so CocoaPods
   builds the flavor configs as debug/release correctly:

   ```ruby
   project 'Runner', {
     'Debug' => :debug,     'Debug-dev' => :debug,     'Debug-prod' => :debug,
     'Profile' => :release, 'Profile-dev' => :release, 'Profile-prod' => :release,
     'Release' => :release, 'Release-dev' => :release, 'Release-prod' => :release,
   }
   ```

5. **Deployment target ≥ 15.0** (Firebase `cloud_firestore` minimum): set
   `platform :ios, '15.0'` in the Podfile and _iOS Deployment Target_ = 15.0 in
   the project Build Settings.

After `pod install`, CocoaPods prints _"did not set the base configuration …
your project already has a custom config set"_ for each flavor config. **This is
expected and harmless** — the flavor Pod xcconfigs are byte-identical to the
generic `Pods-Runner.debug/release.xcconfig` (flavors share the same pods), and
`PODS_CONFIGURATION_BUILD_DIR` uses `$(CONFIGURATION)`, so framework paths still
resolve per-config at build time. If `pod install` instead fails with _"specs
repository is too out-of-date"_, run `pod install --repo-update` once.

Then both flavors build:

```bash
fvm flutter run --flavor dev  -t lib/main_dev.dart
fvm flutter run --flavor prod -t lib/main_prod.dart
```

---

## 3. OneSignal push notifications

App IDs are hardcoded in `lib/config/flavor.dart`:

- dev → `028782a9-e433-4e82-8ccb-37b83aeb3b89`
- prod → `3e8f7a53-8b01-4d37-8748-058896c8329b`

### iOS

In Xcode → Runner target → Signing & Capabilities (for **both** schemes):

- Add **Push Notifications**
- Add **Background Modes** and tick **Remote notifications**

Upload your APNs Auth Key (`.p8`) to the OneSignal dashboard before testing on
a real device. The simulator can't receive real APNs payloads.

### Android

Add a monochrome 192×192 PNG named `ic_stat_onesignal_default.png` to each
`android/app/src/main/res/drawable-{m,h,xh,xxh,xxxh}dpi/` folder. Without it,
notifications still arrive but show a default Android icon.

---

## 4. Firestore document seed

Create the `apps/incil/config/app_state` document with the shape described in
the project brief. Until this doc exists, the app uses the `defaultAppState`
fallback in `Flavor` (currently points at `https://incil-24-4366.huulo.app/`).

Minimal first document:

```json
{
  "webviewUrl": "https://incil-24-4366.huulo.app/",
  "allowedHosts": ["incil-24-4366.huulo.app", "huulo.app", "huulo.io"],
  "emergency": { "enabled": false, "title": "", "subtitle": "", "body1": "", "contact": "", "body2": "", "footer": "" },
  "forceUpdate": { "enabled": false, "minAndroidVersionCode": 1, "minIosBuildNumber": 1, "title": "", "message": "", "androidStoreUrl": "", "iosStoreUrl": "" },
  "onboarding": { "enabled": false, "version": 1, "slides": [] },
  "oneSignalTags": { "app": "incil", "camp": "incil" }
}
```

Firestore security rules (read-only for the app):

```js
match /apps/incil/config/{document} {
  allow read: if true;
  allow write: if false;
}
```
