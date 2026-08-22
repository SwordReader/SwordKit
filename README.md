# SwordKit

[![CI](https://github.com/orbeavers14/SwordKit/actions/workflows/ci.yml/badge.svg)](https://github.com/orbeavers14/SwordKit/actions/workflows/ci.yml)
[![License: GPL v2](https://img.shields.io/badge/License-GPL_v2-blue.svg)](LICENSE)

SwordKit is an experimental Swift package for building Bible readers and study
tools on Apple platforms. It wraps the [CrossWire SWORD
engine](https://www.crosswire.org/sword/) in an idiomatic Swift API and hides
the underlying C++ implementation behind a small C-compatible bridge.

SwordKit is a library, not a finished reader application. It supplies the
Scripture engine, module access, search, rendering, installation, and portable
study-data models; the host app supplies its SwiftUI or AppKit/UIKit interface,
chooses repositories, stores user data, and enforces module licenses.

## What SwordKit can do

- Discover installed Bibles, commentaries, dictionaries, lexicons, general
  books, and daily devotionals, including their metadata.
- Navigate a Bible's own versification and retrieve verses, ranges, chapters,
  and disjoint reference lists.
- Read module-native keyed entries from dictionaries, general books, and daily
  devotionals.
- Render content as plain text, SWORD-generated XHTML, or Swift
  `AttributedString` values with supported Strong's-number and morphology
  attributes.
- Search Bible modules by phrase, all words, POSIX regular expression, Strong's
  number, or morphology, optionally within a reference scope.
- Run synchronous, cancellable asynchronous, progress-reporting, or streaming
  searches.
- Retrieve passages from several translations and compare verses and linguistic
  word metadata.
- Inspect, install, refresh, and remove modules from local or explicitly
  configured remote repositories, including Apple-native HTTPS transfers.
- Model favorites, bookmarks, highlights, notes, reading history, reading
  plans, saved searches, and verse collections as immutable Swift values.

The package includes a versioned SWORD XCFramework, so applications do not need
to install CMake or compile C++ themselves. It supports macOS 14, iOS and iPadOS
17, tvOS 17, visionOS 1, and watchOS 10 or later.

## What applications still provide

SwordKit intentionally does not include a user interface, Bible modules, a
module-repository policy, cloud synchronization, or a persistence database for
study data. Applications decide how content is presented, which repositories
and licenses they accept, where modules and user data live, and how that data is
backed up or synchronized. Physical-device storage and restoration behavior
should be validated for the platforms an application ships.

The current reading and search APIs focus on Bible modules. Dictionary,
general-book, and devotional entries can be read through keyed-entry APIs;
commentary modules can be discovered and inspected but commentary-entry reading
is not yet exposed as public API.

## Add SwordKit to an app

In Xcode, choose **File > Add Package Dependencies** and enter:

```text
https://github.com/orbeavers14/SwordKit.git
```

Select a tagged release and add the `SwordKit` library product to the app
target. Then create an app-owned module location:

```swift
import SwordKit

let location = try SwordModuleLocation.applicationSupport()
let library = try SwordLibrary(location: location)

for module in library.modules {
    print(module.name, module.title, module.category)
}
```

SwordKit does not download content automatically. Use
`SwordModuleInstaller` with a repository your app has deliberately configured,
or place compatible SWORD modules in the selected module directory.

## Documentation

See [Docs/ROADMAP.md](Docs/ROADMAP.md) for planned milestones.

See [Docs/CONCURRENCY.md](Docs/CONCURRENCY.md) for task and actor isolation
guarantees.

See [Docs/COMPATIBILITY.md](Docs/COMPATIBILITY.md) for supported environments,
versioning, and migration policy.

See [Docs/MIGRATING_TO_CURRENT.md](Docs/MIGRATING_TO_CURRENT.md) when updating an
earlier macOS-oriented or manually linked integration.

See [Docs/PLATFORMS.md](Docs/PLATFORMS.md) for the macOS, iOS, iPadOS, tvOS,
visionOS, and watchOS delivery strategy.

See [Docs/NATIVE_DISTRIBUTION.md](Docs/NATIVE_DISTRIBUTION.md) for why SwordKit
ships a native XCFramework and how it is maintained.

See [CHANGELOG.md](CHANGELOG.md) for notable changes and
[Docs/RELEASING.md](Docs/RELEASING.md) for the release process.

Open the SwordKit product documentation in Xcode for complete DocC guides and
API reference covering setup, reading and rendering, module lifecycle, search,
translation comparison, concurrency, persistence, errors, and migration.

## Sample application

[SwordReader](https://github.com/orbeavers14/SwordReader) is the standalone
multiplatform SwiftUI reference app and public-release integration test bed. It
depends on tagged SwordKit releases as an external consumer rather than patching
or vendoring the framework.

Framework defects discovered while developing SwordReader belong in this
repository. Reproduce them against public SwordKit, add a focused regression
test, fix and release SwordKit here, then update SwordReader's pinned version.

## License

SwordKit is licensed under GPL-2.0-only and statically links the GPL-2.0 SWORD
engine. Applications distributed with SwordKit ordinarily need to comply with
the GPL for the combined work, including corresponding-source and redistribution
requirements. Bible modules retain their own licenses and distribution terms.

See [LICENSE](LICENSE) and [NOTICE](NOTICE), and obtain appropriate legal advice
before distributing through a platform whose terms may add restrictions to
recipients.

## Development requirements

- macOS 14, iOS/iPadOS 17, tvOS 17, visionOS 1, or watchOS 10
- Swift 6.3 or later
- Xcode 26 or a compatible Swift toolchain

CMake is required only when rebuilding the bundled SWORD artifact.

## Building the package

Consumers build SwordKit normally; the versioned XCFramework is already included:

```bash
swift build
```

Maintainers can rebuild a platform-specific native slice under
`.build/sword-apple`:

```bash
./Scripts/build-libsword-apple.sh ios-simulator
```

Use `all` to rebuild every supported Apple destination.

Package completed slices into an XCFramework:

```bash
./Scripts/package-libsword-xcframework.sh
```

## App-owned module storage

Use the sandbox-aware Application Support location for ordinary applications:

```swift
let location = try SwordModuleLocation.applicationSupport()
let library = try SwordLibrary(location: location)
let installerConfiguration = SwordInstallerConfiguration(location: location)
```

Apps with shared containers or platform-specific restoration policies can create
`SwordModuleLocation` from explicit module and installer directory URLs instead.

## Streaming search

Search results can also be consumed as a cancellable asynchronous sequence:

```swift
for try await result in bible.searchStream("grace") {
    print(result.reference.value)
}
```
