# SwordKit Agent Instructions

## Project

SwordKit is a modern Swift-native wrapper around the CrossWire SWORD C++ library.

The package declares macOS, iOS/iPadOS, tvOS, visionOS, and watchOS support.
Keep the platform/artifact matrix in `Docs/PLATFORMS.md` aligned with
`Package.swift`; local macOS tests alone do not validate every native slice.

## Required workflow

Work on one roadmap milestone at a time.

For every milestone:

1. Inspect the existing implementation.
2. Write or update tests first when practical.
3. Implement the smallest complete change.
4. Run:

   ./Scripts/test.sh

5. Do not commit unless all tests pass.
6. Review the diff for unrelated changes.
7. Commit the completed milestone with a descriptive commit message.
8. Stop after the commit unless explicitly instructed to continue.

## Testing

Prefer local validation; do not repeatedly trigger GitHub Actions for intermediate
work. Follow `Docs/RELEASING.md` for release-specific consumer, DocC, and platform
checks. Tests requiring installed modules must identify missing fixtures rather
than treating an early return as evidence of native-engine or shutdown safety.

## Ownership

SwordKit owns the Swift SWORD bridge and engine-specific APIs. BibleKit owns
provider-neutral contracts, BibleKitSword adapts SwordKit, BibleUI owns reusable
presentation, and SwordReader owns application behavior. Do not move app UI or
storage into SwordKit. Native-engine changes in ModernSwordAPI are not present
in this package until its vendored sources/artifacts are explicitly updated.

Update `Docs/ROADMAP.md` when a milestone completes. Distinguish implemented
features from host/device validation and outstanding safety work.

Use Swift Testing only:

```swift
import Testing
```
