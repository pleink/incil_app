# CLAUDE.md

Guidance for Claude Code when working in this repository.

Detailed references: [Tooling](docs/tooling.md)

> **Status:** project just initialized. Most architectural decisions (state management, navigation, DI, data layer, design system, conventions, git flow) have **not been made yet**. This file documents what exists today; expand it as decisions land.

---

## Commands

All Flutter/Dart commands go through `fvm` (Flutter is pinned to **3.35.7** in `.fvmrc`):

```bash
fvm flutter pub get            # fetch packages
fvm flutter run                # run on default device
fvm flutter analyze            # static analysis
fvm flutter test               # run tests
fvm flutter build ios          # iOS build
fvm flutter build apk          # Android APK
fvm flutter build appbundle    # Android AAB
```

---

## Project layout

- `lib/main.dart` — app entry point (currently the default Flutter counter app).
- `android/` — Android host app, package `ch.incil.incil_camp_app`.
- `ios/` — iOS host app, bundle `ch.incil.incilCampApp`, display name **Incil CampApp**.
- `test/` — widget tests (default `widget_test.dart` only).
- Platforms: **android, ios only** (web/desktop intentionally excluded).

---

## Architecture

**TBD.** No state management, navigation, DI, persistence, or API client has been chosen yet. When making architectural decisions, prefer:
1. Use the `mobile-dev:architect` sub-agent to plan the approach.
2. Re-run `/mobile-dev:setup` after major decisions land to refresh this file and create `docs/architecture.md`.

---

## Conventions

**TBD.** Defaults from `flutter create` apply:
- `flutter_lints ^5.0.0` (default `analysis_options.yaml`)
- Standard Dart naming (`lower_snake_case` files, `UpperCamelCase` types)
- No codegen, no localization, no enforced import style

---

## Domain

**TBD.** App is called **Incil CampApp** — purpose and features not yet defined.

---

## UI

**TBD.** Default Material theme (`ColorScheme.fromSeed(seedColor: Colors.deepPurple)`). No design tokens, no shared components, no screen skeleton pattern.

---

## Git

**TBD.** Currently on `main`, no commits yet, no CONTRIBUTING.md.

---

## Tooling

- Flutter pinned via fvm to **3.35.7**.
- MCP servers come from the **global** config (no project-local `.mcp.json`): `mobile-mcp`, `Framelink_Figma_MCP`, `context7`, `mcp-atlassian`, `gitlab`, Microsoft 365. Verify with `claude mcp list`.
- mobile-dev plugin skills (Flutter variants) are available for Jira → code, Figma → widget, emulator debugging, analyzer fixes, and smoke testing.
- No CI/CD configured yet.

See [docs/tooling.md](docs/tooling.md) for full detail.

---

## Further Reading

| File | Contents |
|------|----------|
| docs/tooling.md | fvm setup, MCP servers, mobile-dev plugin skills/agents, dev setup, CLI cheatsheet |

The following docs are **not yet created** — generate them by re-running `/mobile-dev:setup` once the relevant decisions are made:

| File | Will cover |
|------|------------|
| docs/architecture.md | Folder structure, state mgmt, navigation, DI, data layer, error handling |
| docs/conventions.md  | Naming, imports, codegen, l10n, testing patterns |
| docs/domain.md       | App purpose, feature map, glossary, integrations |
| docs/ui.md           | Design tokens, screen skeleton, shared components |
| docs/git.md          | Branch model, commit format, PR/MR flow, release flow |
