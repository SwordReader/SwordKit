# Using SwordKit with Concurrency

Share live libraries safely and move immutable Scripture values through actors,
tasks, and UI models.

## Share live engine services

``SwordLibrary`` and ``SwordModule`` are `Sendable`. A library synchronizes
refresh and module snapshots, while each module serializes access to its own
native cursor, parsing, rendering, and search state.

```swift
actor ScriptureService {
    let library: SwordLibrary

    init(location: SwordModuleLocation) throws {
        library = try SwordLibrary(location: location)
    }

    func verse(_ reference: String, module name: String) throws -> SwordVerse {
        guard let module = library.module(named: name) else {
            throw SwordError.moduleNotFound(name)
        }

        return try module.verse(reference)
    }
}
```

An actor can still be useful for application state or policy even though SwordKit
protects native state internally.

## Understand serialization

Operations against the same module wait for one another. SWORD also shares
native parsing and locale state across modules, so SwordKit serializes all
engine calls within a process. Use Swift concurrency to keep that native work
off your UI actor; immutable results remain safe to pass between tasks.

The library's ``SwordLibrary/modules`` property returns a stable array snapshot.
Refreshing does not invalidate immutable values already returned to callers.

## Use asynchronous APIs for cancellation

`SwordModule.searchAsync(_:type:caseSensitive:scope:progress:)`,
`SwordModule.versesAsync(in:)`, and
`SwordLibrary.parallelPassageAsync(_:modules:)` check structured cancellation.
Native search also receives an explicit termination signal.

```swift
let task = Task {
    try await bible.searchAsync("grace", caseSensitive: false)
}

task.cancel()
```

## Stream search results

`SwordModule.searchStream(_:type:caseSensitive:scope:progress:)` adapts SWORD's
batch results to an `AsyncSequence`. Ending iteration cancels its producer:

```swift
for try await result in bible.searchStream("grace") {
    if shouldStop {
        break
    }

    consume(result)
}
```

Keep progress callbacks lightweight and `Sendable`; dispatch product-specific UI
state back to the main actor.
