/// Errors produced by SwordKit operations.
public enum SwordError: Error, Equatable, Sendable {
    /// A reference contained no non-whitespace characters.
    case emptyReference

    /// The requested operation is not supported by this module type.
    case unsupportedModuleType

    /// The SWORD engine could not position the module at the reference.
    case referenceNotFound(String)

    /// SWORD returned no normalized reference after positioning.
    case missingResolvedReference

    /// SWORD returned no rendered content for the requested reference.
    case emptyRenderedText(reference: String)

    /// A sequential passage requested a nonpositive number of verses.
    case invalidVerseCount(Int)

    /// The supplied passage range could not be interpreted.
    case invalidPassageRange(String)

    /// The ending verse precedes the starting verse.
    case reversedPassageRange(String)

    /// The supplied chapter reference could not be interpreted.
    case invalidChapterReference(String)

    /// A reference-list expression was empty or could not be parsed.
    case invalidReferenceList(String)

    /// A search query contained no non-whitespace characters.
    case invalidSearchQuery(String)

    /// A Strong's number was not a `G` or `H` followed by digits.
    case invalidStrongsNumber(String)

    /// No installed module matched the requested name.
    case moduleNotFound(String)

    /// An installer destination was not a local file URL.
    case invalidInstallDestination(String)

    /// Installer-private storage was not a local file URL.
    case invalidInstallerDirectory(String)

    /// An Application Support directory could not be resolved.
    case applicationSupportDirectoryUnavailable

    /// An app storage identifier was empty or contained path separators.
    case invalidStorageIdentifier(String)

    /// A module repository omitted a required identity or host value.
    case invalidModuleRepository(String)

    /// No local SWORD repository existed at the supplied directory.
    case moduleCatalogNotFound(String)

    /// Remote access was attempted before the app confirmed the SWORD warning.
    case remoteAccessNotAuthorized

    /// SWORD could not refresh a remote repository catalog.
    case remoteCatalogRefreshFailed(repository: String, status: Int32)

    /// SWORD could not install a module from a remote repository.
    case remoteModuleInstallationFailed(
        module: String,
        repository: String,
        status: Int32
    )

    /// SWORD could not install a selected module.
    case moduleInstallationFailed(module: String, status: Int32)

    /// SWORD could not remove a selected module.
    case moduleRemovalFailed(module: String, status: Int32)

    /// A reading plan omitted required identity, title, or unique days.
    case invalidReadingPlan(String)

    /// A reading-plan day had an invalid identifier or reading expression.
    case invalidReadingPlanDay(Int)

    /// A serializable text range had an invalid location or length.
    case invalidTextRange(location: Int, length: Int)

    /// A highlight style identifier was empty.
    case invalidHighlightStyle(String)

    /// Note content was empty after trimming whitespace.
    case invalidNoteContent

    /// A verse collection had an empty title, no references, or duplicates.
    case invalidVerseCollection(String)
}
