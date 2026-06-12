# Manual setup steps

Some milestones (M2, M12) depend on credentials or Xcode/Android tooling that
the harness can't run. This file lists those one-time steps, grouped by what
they unblock.

---

## 1. Firebase (unblocks Firestore + DataStore)

Both flavors point at separate Firebase projects:

- `dev` → `incil-campapp-dev`
- `prod` → `incil-campapp`

```bash
dart pub global activate flutterfire_cli

# Dev
flutterfire configure \
  --project=incil-campapp-dev \
  --out=lib/config/firebase/firebase_options_dev.dart \
  --ios-bundle-id=ch.incil.incilCampApp.dev \
  --android-package-name=ch.incil.incil_camp_app.dev \
  --platforms=ios,android

# Move the per-platform files into the dev sourceset before running prod:
mkdir -p android/app/src/dev
mv android/app/google-services.json android/app/src/dev/google-services.json
mv ios/Runner/GoogleService-Info.plist ios/Runner/GoogleService-Info-Dev.plist

# Prod
flutterfire configure \
  --project=incil-campapp \
  --out=lib/config/firebase/firebase_options_prod.dart \
  --ios-bundle-id=ch.incil.incilCampApp \
  --android-package-name=ch.incil.incil_camp_app \
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

Add a Build Phase "Run Script" *before* "Copy Bundle Resources":

```bash
case "$CONFIGURATION" in
  *dev*) PLIST="${PROJECT_DIR}/Runner/GoogleService-Info-Dev.plist" ;;
  *)     PLIST="${PROJECT_DIR}/Runner/GoogleService-Info-Prod.plist" ;;
esac
cp -v "$PLIST" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
```

---

## 2. iOS scheme split (Runner-Dev / Runner-Prod)

Flutter's `--flavor dev` on iOS requires a matching scheme in the Xcode project.

In Xcode → Product → Scheme → Manage Schemes:
1. Duplicate the default `Runner` scheme twice → `Runner-Dev`, `Runner-Prod`.
2. In Project settings, duplicate Build Configurations: `Debug-dev`, `Release-dev`,
   `Profile-dev`, plus the matching `*-prod` set.
3. Create `ios/Flutter/Dev.xcconfig` / `Prod.xcconfig` that set
   `PRODUCT_BUNDLE_IDENTIFIER` to `ch.incil.incilCampApp.dev` / `ch.incil.incilCampApp`
   and `BUNDLE_DISPLAY_NAME` to `Incil CampApp (Dev)` / `Incil CampApp`.

Until this is done, run on iOS without `--flavor`:

```bash
fvm flutter run -t lib/main_dev.dart
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
  "emergency":   { "enabled": false },
  "forceUpdate": { "enabled": false },
  "onboarding":  { "enabled": false, "version": 1, "slides": [] },
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
