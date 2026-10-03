# Concurrency

SwordKit separates portable Swift values from live SWORD engine objects.

## Portable values

Retrieved content, references, search results, comparison values, installer
configuration, and study-feature models conform to `Sendable`. They are immutable
snapshots and may be passed between tasks and actors.

This includes values such as `SwordVerse`, `SwordPassage`,
`SwordSearchResult`, `SwordVerseComparison`, and `SwordNote`.

## Live engine objects

`SwordLibrary` and `SwordModule` conform to `Sendable` using internal recursive
locks around their mutable native SWORD manager, cursor, parsing, rendering, and
search state. A library or module may be shared between tasks and actors. Calls
are serialized through one process-wide recursive lock, including manager and
module teardown. Separate modules share native parsing and locale state and do
not perform engine work independently.

Returned values remain immutable snapshots and do not retain mutable cursor or
search-result state.

## Asynchronous search

`SwordModule.searchAsync` supports Swift task cancellation and accepts an
`@Sendable` progress callback. Other operations targeting the same module wait
until the active search releases its serialized native access.

Because it is a non-actor-isolated async method, `searchAsync` performs native
search work on Swift's generic executor instead of blocking the caller's actor.
It preserves structured cancellation rather than creating an unstructured
detached task.

Cancellation may signal the native search from Swift's cancellation handler.
Callers should handle `CancellationError` in the same way as other cancellable
Swift APIs.

This locking does not establish a process-shutdown barrier. Applications and
test hosts must manage outstanding tasks before termination. A passing test run
without installed native module fixtures does not verify shutdown safety.

## Asynchronous retrieval

`SwordModule.versesAsync(in:)` and
`SwordLibrary.parallelPassageAsync(_:modules:)` preserve input order and check
for cancellation between native retrieval operations. They may be called from
any concurrency domain; operations sharing a module are serialized internally.

## Streaming search results

`SwordModule.searchStream` returns an `AsyncThrowingStream` that preserves SWORD
result order. SWORD first completes its native batch search, then the stream
yields immutable results cooperatively. Ending or cancelling iteration cancels
the producer and signals an active native search to terminate.
