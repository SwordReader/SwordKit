# ``SwordKit``

Build Scripture-reading and biblical-study experiences with a Swift-native API
over the CrossWire SWORD engine.

## Overview

SwordKit provides immutable Swift values for Scripture content, references,
search results, translation comparisons, and study data. A small C bridge hides
the underlying C++ engine and the bundled XCFramework supplies native SWORD code
for every supported Apple platform.

Use ``SwordLibrary`` to discover installed modules and ``SwordModule`` to read,
render, search, and navigate their content. Live engine objects serialize native
access and can be shared across Swift concurrency domains. Retrieved values are
immutable `Sendable` snapshots.

@Links(visualStyle: detailedGrid) {
    - <doc:GettingStarted>
    - <doc:SearchingScripture>
    - <doc:ComparingTranslations>
    - <doc:ApplePlatformStorage>
    - <doc:BuildingAScriptureReader>
    - <doc:BuildingATranslationComparison>
    - <doc:ManagingModuleLifecycle>
    - <doc:UsingSwordKitWithConcurrency>
    - <doc:MigratingToCurrentSwordKit>
}

## Topics

### Essentials

- <doc:GettingStarted>
- ``SwordLibrary``
- ``SwordModule``
- ``SwordModuleLocation``

### Tutorials

- <doc:BuildingAScriptureReader>
- <doc:BuildingATranslationComparison>

### API guides

- <doc:ManagingModuleLifecycle>
- <doc:HandlingSwordKitErrors>
- <doc:UsingSwordKitWithConcurrency>
- <doc:RenderingScriptureContent>
- <doc:PersistingStudyData>
- <doc:MigratingToCurrentSwordKit>

### Scripture references and content

- ``SwordReference``
- ``SwordBook``
- ``SwordReferenceList``
- ``SwordPassageRange``
- ``SwordChapterReference``
- ``SwordVerse``
- ``SwordPassage``
- ``SwordChapter``

### Search

- <doc:SearchingScripture>
- ``SwordSearchType``
- ``SwordSearchResult``

### Translation and language comparison

- <doc:ComparingTranslations>
- ``SwordParallelPassage``
- ``SwordAlignedVerse``
- ``SwordVerseComparison``
- ``SwordWordToken``
- ``SwordWordLink``
- ``SwordWordLocation``

### Module management

- <doc:ApplePlatformStorage>
- <doc:ManagingModuleLifecycle>
- ``SwordModuleCatalog``
- ``SwordModuleCatalogEntry``
- ``SwordRemoteModuleCatalog``
- ``SwordTransferProgress``
- ``SwordInstallerConfiguration``
- ``SwordModuleInstaller``
- ``SwordModuleRepository``

### Study values

- <doc:PersistingStudyData>
- ``SwordFavorite``
- ``SwordBookmark``
- ``SwordHighlight``
- ``SwordNote``
- ``SwordReadingHistoryEntry``
- ``SwordReadingPlan``
- ``SwordSavedSearch``
- ``SwordVerseCollection``

### Errors

- <doc:HandlingSwordKitErrors>
- ``SwordError``
