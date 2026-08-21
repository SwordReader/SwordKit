# Changelog

Notable changes to SwordKit are recorded here. SwordKit follows Semantic
Versioning and is currently preparing its first pre-1.0 release.

## Unreleased

No changes yet.

## 0.5.1 - 2026-08-21

### Fixed

- Include both modern `arm64` and legacy `arm64_32` device architectures in
  the watchOS SWORD binary slice so current watchOS apps link successfully.

## 0.5.0 - 2026-08-21

### Added

- Safe installation of a raw SWORD ZIP package received through an app-owned
  transport such as WatchConnectivity.
- Automatic staging cleanup and reuse of archive traversal validation for
  received packages.

## 0.4.0 - 2026-08-21

### Added

- Apple-native HTTPS catalog and raw-package downloads across every supported
  Apple platform.
- Explicit repository package endpoints and safe remote resource URL creation.
- Path validation before extracting downloaded SWORD catalog and module
  archives.

### Changed

- HTTPS repository operations now use `URLSession` instead of depending on the
  native SWORD artifact's platform-specific cURL availability.

## 0.3.0 - 2026-08-21

### Added

- Remote SWORD repository catalog refresh and cached browsing.
- Remote module installation with Swift concurrency, byte progress, and task
  cancellation.
- Explicit acknowledgement of SWORD's remote-access warning before network
  operations.

## 0.2.0 - 2026-08-21

### Added

- Versification-aware `SwordModule.books()` metadata for canonical book and
  chapter navigation without hard-coding a single Bible canon in applications.
- `SwordBook` values with stable OSIS identity, display metadata, testament,
  and chapter count.

## 0.1.0 - 2026-08-03

### Added

- GPL-2.0-only licensing for SwordKit and explicit downstream distribution
  guidance.
- Swift-native access to installed SWORD modules, scripture content, rendering,
  navigation, reference parsing, and search.
- Cancellable asynchronous search with progress and `AsyncSequence` support.
- Parallel-passage and word-level Greek, Hebrew, and translation comparison
  values.
- Module installation, sandbox-aware storage, and immutable study-feature
  values.
- A versioned SWORD XCFramework for macOS, iOS, iPadOS, tvOS, visionOS, and
  watchOS.
- DocC tutorials, API guides, compatibility guidance, and migration guides.

### Changed

- Live library and module objects serialize access to mutable native SWORD state
  and conform to `Sendable`.

### Deferred

- Sample applications will be designed after product work identifies reusable
  UI boundaries.
