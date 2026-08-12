# Changelog

All notable changes to StudyFlow AI are documented here. The version
follows [Semantic Versioning](https://semver.org) — `MAJOR.MINOR.PATCH+build`.

## [1.1.0] — 2026-08-12

### Added

- **Material 3 Expressive design system** — full token layer: complete
  light/dark ColorScheme roles, 15-role typography scale, motion and shape
  tokens, and component themes for navigation, cards, dialogs, sheets,
  buttons, inputs, chips, and more. StudyFlow's indigo identity is preserved
  throughout.
- **Dynamic color (Android 12+)** — the app harmonizes with the platform
  wallpaper palette where supported, with a branded indigo fallback on iOS
  and older Android.

### Changed

- Page transitions: FadeForwards on Android, Cupertino on iOS, with the M3
  sparkle ink ripple on press.
- `flutter analyze` is fully clean (0 issues) — 37 style lints fixed.
- Removed the unused `FeaturePlaceholder` widget.

### CI

- New `flutter` job in GitHub Actions: `dart format` check, `flutter
  analyze`, and `flutter test` on every push and pull request.

## [1.0.0] — First public release

Authentication, onboarding, dashboard, notebooks with source-grounded AI,
citations, notes, flashcards, quizzes, study planner with exam countdowns,
progress analytics, AI audio study podcasts, Premium paywall, creator page,
and the full glass design system.
