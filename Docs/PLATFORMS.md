# Apple Platform Strategy

SwordKit is designed for the Apple ecosystem. Platform support becomes official
only when the package manifest, native SWORD artifacts, automated builds, and
platform integration tests all cover that destination.

## Intended platform family

| Platform | Intended baseline | Product direction |
| --- | --- | --- |
| macOS | macOS 14 | Full framework, local modules, installation, search, and study tools |
| iOS and iPadOS | iOS 17 | Full framework with sandbox-aware module storage and installation |
| tvOS | tvOS 17 | Reading, search, comparison, and app-managed module storage |
| visionOS | visionOS 1 | Full reading and study framework with app-managed module storage |
| watchOS | watchOS 10 | Full framework for compact local libraries, with companion-assisted content delivery recommended |

These baselines align the first cross-platform release around the same generation
of Foundation, Swift concurrency, and attributed-string APIs. All listed
platforms are declared in `Package.swift`. Continuous integration compiles the
package and its tests for every platform; device runtime validation still gates
their first supported release.

## Portable today

The following layers are Swift-native and already suitable for every intended
platform:

- Scripture reference, verse, passage, chapter, and search-result values
- Translation and word-level comparison values
- Reading plans, favorites, bookmarks, notes, highlights, and collections
- `Sendable` result boundaries and cancellable async APIs
- Foundation-based attributed-string attributes

The public API hides raw C++ pointers, so clients do not need platform-specific
SWORD integration code.

## Native build requirement

`Scripts/build-libsword-apple.sh` produces reproducible static SWORD slices for
device and simulator SDKs. `Scripts/package-libsword-xcframework.sh` packages
those slices into the versioned `Artifacts/Sword.xcframework`, which Swift
Package Manager links through the `SwordNative` binary target.

This is a conventional distribution model for Swift wrappers around C and C++
libraries. Consumers receive a ready-to-link library without installing CMake or
compiling the SWORD engine themselves. The costs are a larger repository and the
need to regenerate every platform slice whenever the vendored engine changes.
SwordKit keeps the artifact in the repository while the package is experimental;
a future release may move the zipped XCFramework to release hosting and use a
checksum-based remote SwiftPM binary target.

The native build must cover:

- macOS
- iOS and iOS Simulator
- tvOS and tvOS Simulator
- visionOS and visionOS Simulator
- watchOS and watchOS Simulator

Each slice must use the same vendored SWORD revision and compatible feature
flags. The C bridge must compile against every supported SDK without importing UI
frameworks.

The iOS, tvOS, visionOS, and watchOS simulator builds have been validated. The
full package compiles for watchOS and its native device slice is approximately
3 MB, making the engine feasible there. Apps should still keep on-watch module
sets compact and prefer paired-iPhone delivery over direct remote installation.

## Storage and installation

SWORD module discovery cannot assume traditional desktop paths outside macOS.
Sandboxed apps must supply an app-owned module directory.

`SwordModuleLocation.applicationSupport()` resolves sandbox-safe module and
installer directories using the host app's bundle identifier. Apps can instead
construct `SwordModuleLocation` with explicit file URLs when they need an app
group, shared container, purgeable cache, or another storage policy. The same
location can initialize both `SwordLibrary` and `SwordInstallerConfiguration`.

- iOS, iPadOS, and visionOS should use Application Support for durable modules.
- tvOS must tolerate system-purgeable local storage and support restoration.
- watchOS should normally receive compact, app-selected content from its paired
  iPhone unless full on-watch module storage proves practical.
- Remote installation must remain explicitly configured by the host app.

## Rendering

SwordKit's plain text, HTML, and Swift `AttributedString` results remain the
cross-platform rendering boundary. AppKit and UIKit conversions are conveniences,
not requirements for the core engine. SwiftUI applications should consume the
portable values directly whenever possible.

## Delivery sequence

1. Validate module restoration on physical devices for each platform.
2. Measure watchOS runtime memory and storage with representative modules.
3. Publish support only after all required checks pass.
