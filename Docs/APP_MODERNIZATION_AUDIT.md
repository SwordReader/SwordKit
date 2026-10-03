# SwordReader modernization audit

Audit started October 3, 2026 using Xcode 27.0 (27A266a) and Apple Swift 6.4.

## Direction

Keep the existing app and migrate incrementally. SwordKit owns the native SWORD
bridge; BibleKit owns provider-neutral contracts; BibleKitSword adapts SWORD;
BibleUI owns reusable presentation; SwordReader owns product navigation and data.

## Verified baseline

- SwordKit's required test script passes: 115 Swift Testing tests.
- SwordReader macOS tests pass with the current working copy.
- SwordReader generic iOS build passes, including the companion dependency.
- SwordReader generic watchOS build passes.
- Swift 6.4 reports implicit strong/weak capture warnings in search and download
  tasks in AppModel. These should be corrected explicitly.
- These results do not prove native shutdown safety or device usability. Native
  integration tests that return early without KJV need deterministic fixtures.

## Ordered implementation milestones

1. Reconcile release configuration and async ownership.
   - Align project.yml with the pending SwordKit 0.6.1/build-3 project edits.
   - Resolve packages normally; do not treat a hand-edited lockfile as validation.
   - Add a controlled stale-chapter regression test. Snapshot the destination,
     reject cancelled/obsolete completions, and avoid retaining abandoned models.
   - Test shutdown with actual module reads in flight. The global engine lock
     does not synchronize with native static destructors at process exit.

2. Integrate BibleKitSword incrementally.
   - The other task owns the in-progress reading contract; do not edit or publish
     its uncommitted files from this task.
   - Start with catalogs and individual keyed-entry reads from a tested public tag.
   - Preserve module IDs and existing study-data references.
   - Add chapter/book navigation, search, download lifecycle, and rich footnote,
     cross-reference, heading, and lexical metadata contracts before replacing
     the complete ScriptureServing interface.
   - Keep watch transfer, reminders, Handoff, and persistence in the application.

3. Reader workspace UI and behavior.
   - Use one clear global toolbar; move module and location changes into pane
     headers. Avoid duplicate controls and ambiguous icon-only actions.
   - Represent a split workspace as a selectable, closable tab group. Preserve
     that group when opening a search result or selecting another workspace.
     The current combined label only hides the individual tab chips.
   - Ensure search targets scroll to their verse after chapter content arrives.
   - Use one rendering and selection path for single and split panes so font,
     red-letter text, notes, highlights, and links behave consistently.
   - Offer real colored swatches for Pink, Blue, Yellow, and Green. Verify native
     text selection receives the menu and that actions apply to the correct pane.
   - Verify notes and highlights distinguish translation and selected passage,
     including repeated words and selection spanning verses.

4. Library and responsive layouts.
   - Separate Installed from Downloads and make installation state unambiguous.
   - Preserve the workspace while downloading and refresh every open window.
   - Review keyboard focus, VoiceOver, accessibility text sizes, toolbar overflow,
     compact iPhone sheets, landscape, and narrow split layouts in the running UI.
   - Introduce BibleUI components only after the provider contracts support the
     existing rich content; do not reduce the reader to plain strings.

5. Release acceptance.
   - Run macOS/iOS/watchOS builds and physical-device acceptance.
   - Reconcile the roadmap, changelog, concurrency docs, and release metadata.
   - Complete signing and update delivery before publishing a new app binary.

## Scope of this audit

This document records source-level findings and compiler validation. UI proposals
still require inspection of the running app; BibleKitSword consumer migration
and crash reproduction have not yet been completed.
