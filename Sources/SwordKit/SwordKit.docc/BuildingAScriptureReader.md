# Building a Scripture Reader

Create the data flow for an Apple-platform reader that opens app-owned modules,
selects a Bible, loads a chapter, searches, and safely updates UI state.

## Resolve app-owned storage

Create one location and reuse it throughout the app. This keeps the reader and
installer pointed at the same SWORD root:

```swift
import SwordKit

let location = try SwordModuleLocation.applicationSupport()
let library = try SwordLibrary(location: location)
let installer = SwordModuleInstaller(
    configuration: SwordInstallerConfiguration(location: location)
)
```

The library can exist in a shared service, actor, or observable model. It and its
modules serialize live native access internally.

## Represent reader state with values

Keep live modules in the service layer and expose immutable SwordKit snapshots to
the interface:

```swift
@MainActor
final class ReaderModel: ObservableObject {
    @Published private(set) var chapter: SwordChapter?
    @Published private(set) var searchResults: [SwordSearchResult] = []

    private let library: SwordLibrary
    private var bible: SwordModule?

    init(library: SwordLibrary) {
        self.library = library
        self.bible = library.modules(category: .bible).first
    }
}
```

`SwordChapter` and `SwordSearchResult` are `Sendable`, so completed work can cross
back into the main actor without exposing a native cursor to the view.

## Load a chapter

Build navigation from the selected module's native versification rather than a
fixed application list:

```swift
let books = try bible.books()
let chaptersInGenesis = books.first { $0.osisName == "Gen" }?.chapterCount
```

This preserves the module's book order and supports alternate canons and
versification systems.

Use the textual convenience API for user-entered or navigation-generated
references:

```swift
extension ReaderModel {
    func loadChapter(_ reference: String) async throws {
        guard let bible else {
            throw SwordError.moduleNotFound("Bible")
        }

        chapter = try bible.chapter(reference)
    }
}
```

For long batches, prefer the asynchronous retrieval APIs so cancellation can be
observed between entries.

## Present rich Scripture

Choose the rendering boundary that fits the interface:

- Use ``SwordVerse/text`` for simple labels and indexing.
- Use `SwordModule.html(_:)` for web-based presentation.
- Use `SwordModule.attributedString(_:)` for native text with lexical attributes.

```swift
let text = try bible.attributedString("John 3:16")
```

Keep SwiftUI, UIKit, or AppKit styling in the application. SwordKit returns
portable content rather than prescribing a reader design.

## Add cancellable search

Store the current search task in the model so a new query can cancel the old one:

```swift
extension ReaderModel {
    func search(_ query: String) async throws {
        guard let bible else {
            throw SwordError.moduleNotFound("Bible")
        }

        searchResults = try await bible.searchAsync(
            query,
            caseSensitive: false
        )
    }
}
```

For interfaces that consume results incrementally, iterate over
`SwordModule.searchStream(_:type:caseSensitive:scope:progress:)` instead.

## Refresh after installation

After installing or removing content, explicitly refresh and select a new module
snapshot:

```swift
library.refresh()
bible = library.modules(category: .bible).first
```

Existing `SwordModule` objects remain valid snapshots of their original manager,
but newly installed content appears only after refresh.

## Adapt the product by platform

The same service works across the Apple ecosystem. Adjust the presentation and
content policy instead of forking the engine layer:

- iPhone and iPad can provide touch navigation and offline module management.
- macOS can expose denser search and study workspaces.
- tvOS should emphasize reading and app-restorable content.
- visionOS can arrange reader and comparison windows spatially.
- watchOS should use compact module sets and companion-assisted delivery.
