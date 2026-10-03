# SwordKit Roadmap

> A modern, Swift-native API for the CrossWire SWORD engine.
>
> **Vision**
>
> SwordKit aims to be the definitive Bible and biblical studies framework for
> Apple platforms, providing a clean, Swifty API while leveraging the mature
> CrossWire SWORD engine underneath.
>
> Design goals:
>
> - Swift-first API
> - Value-oriented types
> - Safe memory management
> - Modern concurrency
> - Cross-platform (macOS, iOS, iPadOS, tvOS, visionOS, and watchOS)
> - Excellent documentation
> - Stable public API

---

# Current Progress

Reviewed October 3, 2026. GitHub's latest published release is `v0.6.1`.
Checked items describe implemented APIs, not proof of every host/device scenario.

## Core Engine

- [x] Swift Package
- [x] C++ bridge layer
- [x] Link against SWORD
- [x] Open installed modules
- [x] Module discovery
- [x] Module metadata
- [x] Explicit manager/module ownership and serialized native-engine access
- [ ] Deterministic host shutdown validation with real module reads in flight

---

## Scripture Reading

- [x] Read a verse
- [x] Navigate next verse
- [x] Navigate previous verse
- [x] Retrieve passages
- [x] Retrieve chapters
- [x] Retrieve verses from reference lists

---

## Scripture Reference System

- [x] `SwordReference`
- [x] `SwordVerse`
- [x] `SwordPassage`
- [x] `SwordChapter`
- [x] `SwordReferenceList`
- [x] Native SWORD verse parsing
- [x] Expanded verse ranges
- [x] Numbered book support
- [x] Multiple disjoint passages
- [x] Cross-book passage parsing

Examples:

```swift
try bible.references(
    in: "John 3:16-18"
)

try bible.references(
    in: "John 3:16; Romans 8:28"
)

try bible.references(
    in: "John 21; Acts 1"
)
```

---

## Search

- [x] Basic phrase search
- [x] Multi-word search
- [x] Regular-expression search
- [x] Case-insensitive search
- [x] Strong's-number search
- [x] Morphology search
- [x] Scoped search
- [x] Cancellable asynchronous search
- [x] Search progress reporting
- [x] Search result ranking
- [x] Swift-native `SwordSearchType`
- [x] Immutable `SwordSearchResult` values
- [x] SWORD relevance scores

Example:

```swift
let results = try bible.search("grace")
```

---

# Next Milestone

## Native Safety and Consumer Integration

The initial pre-1.0 release checklist is complete. The current priorities are
native shutdown validation and feedback from the BibleKitSword/SwordReader
consumer migration. The process-wide lock in 0.6.1 serializes SWORD access and
teardown; it does not by itself prove safety against native static destructors.

- [ ] Add deterministic installed-module fixtures to native integration tests
- [ ] Reproduce and validate process exit with active reads in a host application
- [ ] Address provider-adapter defects through focused SwordKit regression tests
- [ ] Validate any future ModernSwordAPI artifact refresh on every supported SDK

### Completed release foundation

- [x] Define the release checklist and changelog
- [x] Refresh contributor documentation
- [x] Verify package consumption from a clean external project
- [x] Decide and publish the project license
- [x] Establish the first pre-1.0 version and tag

---

# Upcoming Features

## Apple Platform Support

- [x] Define platform support and delivery matrix
- [x] Build multi-SDK SWORD artifacts
- [x] Integrate platform-aware native artifacts with SwiftPM
- [x] Declare iOS and iPadOS support
- [x] Declare tvOS support
- [x] Declare visionOS support
- [x] Validate watchOS native-engine feasibility
- [x] Add sandbox-aware module locations
- [x] Add platform compile and integration CI

---

## Parallel Bible Support

Example:

```swift
let passage = try library.parallelPassage(
    "John 3:16-18",
    modules: [
        "KJV",
        "WEB",
        "ESV"
    ]
)
```

Planned:

- [x] Side-by-side verses
- [x] Missing verse detection
- [x] Verse alignment
- [x] Verse-level translation comparison

## Word-Level Language Comparison

Long-term direction:

- [x] Unicode-aware tokenization for Greek, Hebrew, and translated text
- [x] Normalized word comparison without losing original display text
- [x] Strong's-number and lemma alignment
- [x] Morphology-aware Greek and Hebrew comparison
- [x] Source-to-translation word links
- [x] One-to-many and missing-word alignment

---

## Rich Text

- [x] HTML rendering
- [x] AttributedString rendering
- [x] Strong's numbers
- [x] Morphology
- [x] Footnotes
- [x] Cross references
- [x] Headings
- [x] Red-letter text

---

## Module Management

- [x] Open by module name
- [x] Filter modules
- [x] Installer configuration
- [x] Local catalog inspection
- [x] Install modules
- [x] Remove modules
- [x] Refresh library
- [x] Inspect module metadata
- [x] Version information
- [x] Remote catalog refresh and cached browsing
- [x] Remote installation progress and cancellation
- [x] Apple-native HTTPS transport across supported platforms
- [x] Safe catalog and module archive extraction

---

## Study Features

- [x] Reading plans
- [x] Favorites
- [x] Bookmarks
- [x] Highlights
- [x] Notes
- [x] Reading history
- [x] Saved searches
- [x] Verse collections

---

## Maintenance

- [x] Finalize public naming and ownership semantics
- [x] Document every public declaration
- [x] Establish concurrency guarantees
- [x] Add native integration test coverage
- [ ] Make fixture-dependent coverage deterministic rather than silently bypassed
- [x] Add continuous integration
- [x] Publish migration and compatibility policies

---

## Concurrency

- [x] Async APIs
- [x] Thread-safe module access
- [x] Background searching
- [x] AsyncSequence support

Example:

```swift
for try await result in bible.searchStream(
    "grace"
) {
    print(result.reference)
}
```

---

## Documentation

- [x] DocC
- [x] Tutorials
- [x] Standalone sample application
- [x] API guides
- [x] Migration guides

[SwordReader](https://github.com/SwordReader/SwordReader) is maintained in its
own repository as both a potential product and the reference consumer for tagged
SwordKit releases. Application-specific UI, navigation, and persistence remain
outside this framework.

---

# Long-Term Vision

SwordKit should become the standard Swift framework for Bible software on Apple
platforms.

Potential applications include:

- Bible readers
- Study applications
- Sermon preparation
- Devotional apps
- Reading plans
- Academic research
- Original language tools
- Parallel Bible study
- Church presentation software
- Scripture search utilities
- Bible journaling apps

---

# API Philosophy

SwordKit should always feel like modern Swift.

Good:

```swift
let verse = try bible.verse("John 3:16")
```

```swift
let chapter = try bible.chapter("Romans 8")
```

```swift
let verses = try bible.verses(
    in: "John 3; Romans 8"
)
```

```swift
let search = try bible.search("grace")
```

Not:

```swift
module.setKey(...)
module.increment()
module.renderText()
```

Those remain internal implementation details hidden behind a clean Swift API.

---

# Project Status

The listed core APIs are implemented, and 0.6.1 is published. Native shutdown
hardening and deterministic fixtures remain open. BibleKitSword integration is
owned by BibleKit and its consuming apps; ModernSwordAPI improvements require
an explicit vendor/artifact update before becoming part of SwordKit.
