# Tooling

## Flutter SDK

The Flutter SDK is pinned via [fvm](https://fvm.app/) to **3.35.7** (see `.fvmrc`).

All `flutter` and `dart` invocations should go through `fvm` so the pinned version is used:

```bash
fvm flutter <command>
fvm dart <command>
```

If you don't have the pinned version locally, run `fvm install` once.

## MCP servers

This project does **not** define a project-local `.mcp.json`. It relies on the globally configured servers (verify with `claude mcp list`):

| Server | Purpose |
|--------|---------|
| `plugin:mobile-dev:mobile-mcp` | Drive the iOS simulator / Android emulator (taps, screenshots, screen state). Used by `emulator-debug-flutter` and `smoketest`. |
| `plugin:mobile-dev:Framelink_Figma_MCP` | Fetch Figma node data and download design images. Used by `figma-to-widget-flutter`. |
| `plugin:mobile-dev:context7` | Resolve and query library docs (Flutter packages, Dart APIs, etc.) at current versions. |
| `mcp-atlassian` | Read Jira tickets. Used by `implement-jira-flutter`. |
| `gitlab` | Read/write GitLab merge requests, issues, pipelines. |
| `claude.ai Microsoft 365` | Microsoft 365 (mail, calendar, etc.) — requires interactive auth. |

## mobile-dev plugin skills (Flutter variants)

Trigger these via natural language or by typing the slash form. The relevant ones for this project:

| Skill | When to use |
|-------|-------------|
| `mobile-dev:setup` | Re-run this onboarding scan after architectural decisions are made. |
| `mobile-dev:implement-jira-flutter` | Implement a Jira ticket end-to-end (requires Jira project key). |
| `mobile-dev:figma-to-widget-flutter` | Build a widget/screen from a Figma URL. |
| `mobile-dev:emulator-debug-flutter` | Debug UI / behavior on the iOS sim or Android emulator. |
| `mobile-dev:smoketest` | Capture/compare baseline screenshots of key screens. |
| `mobile-dev:fix-analyzer-flutter` | Auto-fix `fvm flutter analyze` errors and warnings. |

Translation skills (`translations-sync-flutter`, `translations-add`) are **not applicable** — this project does not use POEditor and has no l10n setup yet.

## Sub-agents (Flutter)

| Agent | Role |
|-------|------|
| `mobile-dev:architect` | Plan technical approach / review structural compliance before merge. |
| `mobile-dev:requirements-engineer` | Break down a Jira ticket into requirements before any code is written. |
| `mobile-dev:dev-flutter` | Implement features, widgets, BLoC/Cubit, etc. |
| `mobile-dev:test-engineer-flutter` | Write / audit unit, widget, golden, integration tests. |
| `mobile-dev:code-reviewer-flutter` | Code review before merge. |
| `mobile-dev:ux-expert` | Review Figma designs and implemented UI for fidelity/accessibility. |
| `mobile-dev:release-manager-flutter` | Version bumps in `pubspec.yaml`, Fastlane builds, release checklist. |

## CI/CD

None configured yet. No `.github/`, no `fastlane/`, no `codemagic.yaml`. Release tooling will be added when needed.

## Developer setup

```bash
# 1. Install fvm (once per machine)
brew tap leoafarias/fvm
brew install fvm

# 2. Install the pinned Flutter version
fvm install

# 3. Fetch packages
fvm flutter pub get

# 4. Run on a connected device / simulator
fvm flutter run
```

Useful commands:

```bash
fvm flutter analyze            # static analysis
fvm flutter test               # run tests
fvm flutter run                # run on default device
fvm flutter build ios          # iOS build (requires Xcode)
fvm flutter build apk          # Android APK
fvm flutter build appbundle    # Android AAB
```
