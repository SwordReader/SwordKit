# SwordReader

SwordReader is a multiplatform SwiftUI Bible reader for iOS, iPadOS, and macOS.
It consumes the public `SwordKit` 0.1.0 package and keeps SWORD modules in the
application's Application Support container.

## Open and run

Open `SwordReader.xcodeproj` in Xcode 26 or later, choose the SwordReader scheme,
and run on macOS or an iOS 17+ device or simulator.

SwordKit does not bundle or implicitly download Bible modules. Use **Library →
Import Local Catalog** to select a local SWORD repository containing a `mods.d`
directory, then install a Bible from that catalog.

## Architecture

- `AppModel` is the shared, main-actor application model.
- `SwordScriptureService` is the sole SwordKit integration boundary and keeps
  live library/module objects out of views.
- Immutable app snapshots cross from the service into SwiftUI.
- Compact layouts use a native tab-based hierarchy; iPad and macOS use a
  `NavigationSplitView` workspace.
- Platform-specific commands and toolbar placement stay in platform files.

## Verify

```sh
xcodebuild test \
  -project SwordReader.xcodeproj \
  -scheme SwordReader \
  -destination 'platform=macOS'
```

