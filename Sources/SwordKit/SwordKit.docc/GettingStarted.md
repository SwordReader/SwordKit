# Getting Started with SwordKit

Open an app-owned SWORD library and retrieve Scripture with a small set of core
types.

## Create a library

For a sandboxed application, resolve a location beneath Application Support and
use it for both reading and installation:

```swift
import SwordKit

let location = try SwordModuleLocation.applicationSupport()
let library = try SwordLibrary(location: location)
let installer = SwordModuleInstaller(
    configuration: SwordInstallerConfiguration(location: location)
)
```

SwordKit does not create or download modules implicitly. The host application
chooses its repositories and installation policy.

## Select a module

Installed modules expose stable metadata and can be filtered by category or
language:

```swift
let englishBibles = library.modules(category: .bible, language: "en")

guard let bible = englishBibles.first else {
    // Present module installation in the application.
    return
}
```

## Read Scripture

Retrieve a single verse, passage, chapter, or disjoint reference expression:

```swift
let verse = try bible.verse("John 3:16")
let passage = try bible.passage("John 3:16-18")
let chapter = try bible.chapter("Romans 8")
let selected = try bible.verses(in: "John 3:16; Romans 8:28")
```

The returned values are immutable and `Sendable`, so applications can move them
into view models, actors, persistence layers, or SwiftUI views without retaining
the module's mutable native cursor.

## Render content

Plain text is available on ``SwordVerse/text``. Modules can also render XHTML or
a Swift `AttributedString`:

```swift
let html = try bible.html("John 3:16")
let attributedText = try bible.attributedString("John 3:16")
```

The attributed result can include SwordKit attributes for Strong's numbers and
morphology when the installed module supplies that information.

## Read non-Bible modules

Dictionaries, general books, and daily devotionals use module-native keys
instead of Scripture references:

```swift
guard let dictionary = library.modules(category: .dictionary).first,
      let firstKey = try dictionary.keyedEntryKeys().first else {
    return
}

let entry = try dictionary.keyedEntry(for: firstKey)
print(entry.text)
```

Commentary modules can currently be discovered and inspected, but reading their
entries is not yet public API. Calling a Bible-only or keyed-entry API on an
unsupported module category throws ``SwordError/unsupportedModuleType``.
