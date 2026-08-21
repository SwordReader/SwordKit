import Foundation
import Testing
@testable import SwordKit

@Test
func bridgeVersionIsAvailable() {
    #expect(SwordLibrary.bridgeVersion == "0.5.0")
}

@Test
func engineVersionIsAvailable() {
    #expect(SwordLibrary.engineVersion.hasPrefix("1.9.0"))
}

@Test
func libraryLoadsInstalledModules() {
    let library = SwordLibrary()

    // The machine may have zero installed modules.
    #expect(library.modules.count >= 0)
}

@Test
func moduleNamesAreSorted() {
    let library = SwordLibrary()
    let names = library.modules.map(\.name)

    #expect(
        names == names.sorted {
            $0.lowercased() < $1.lowercased()
        }
    )
}

@Test
func moduleLookupReturnsMatchingModule() {
    let library = SwordLibrary()

    guard let first = library.modules.first else {
        return
    }

    #expect(library.module(named: first.name) == first)
}

@Test
func moduleLookupIsCaseInsensitive() {
    let library = SwordLibrary()

    guard let first = library.modules.first else {
        return
    }

    #expect(
        library.module(named: first.name.uppercased()) == first
    )
}

@Test
func subscriptLooksUpModule() {
    let library = SwordLibrary()

    guard let first = library.modules.first else {
        return
    }

    #expect(library[first.name] == first)
}

@Test
func libraryFiltersModulesByCategoryAndLanguage() {
    let library = SwordLibrary()
    let englishBibles = library.modules(
        category: .bible,
        language: "EN"
    )

    #expect(englishBibles.allSatisfy { $0.category == .bible })
    #expect(
        englishBibles.allSatisfy {
            $0.language.caseInsensitiveCompare("en") == .orderedSame
        }
    )
    #expect(
        englishBibles.map(\.name)
            == englishBibles.map(\.name).sorted()
    )
}

@Test
func bibleModuleExposesItsVersificationBooks() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    let books = try bible.books()
    let genesis = try #require(books.first)
    let matthew = try #require(books.first { $0.osisName == "Matt" })

    #expect(genesis.name == "Genesis")
    #expect(genesis.osisName == "Gen")
    #expect(genesis.preferredAbbreviation == "Gen")
    #expect(genesis.chapterCount == 50)
    #expect(genesis.testament == .old)
    #expect(matthew.chapterCount == 28)
    #expect(matthew.testament == .new)
}

@Test
func nonBibleModuleRejectsVersificationBooks() throws {
    let library = SwordLibrary()

    guard let dictionary = library.modules.first(
        where: { $0.category != .bible }
    ) else {
        return
    }

    #expect(throws: SwordError.unsupportedModuleType) {
        try dictionary.books()
    }
}

@Test
func installerConfigurationStoresExplicitDirectoriesAndRepositories() throws {
    let repository = try SwordModuleRepository(
        identifier: "crosswire",
        name: "CrossWire",
        transport: .https,
        host: "www.crosswire.org",
        directory: "/ftpmirror/pub/sword/raw"
    )
    let configuration = try SwordInstallerConfiguration(
        destinationDirectory: URL(fileURLWithPath: "/tmp/sword-library"),
        privateDirectory: URL(fileURLWithPath: "/tmp/sword-installer"),
        repositories: [repository]
    )

    #expect(configuration.repositories == [repository])
    #expect(configuration.destinationDirectory.isFileURL)
    #expect(configuration.privateDirectory.isFileURL)
}

@Test
func moduleRepositoryRejectsPathLikeIdentifier() {
    #expect(throws: SwordError.invalidModuleRepository("../crosswire")) {
        try SwordModuleRepository(
            identifier: "../crosswire",
            name: "CrossWire",
            transport: .ftp,
            host: "ftp.crosswire.org",
            directory: "/pub/sword/raw"
        )
    }
}

@Test
func httpsRepositoryBuildsCatalogAndPackageURLs() throws {
    let repository = try SwordModuleRepository(
        identifier: "crosswire",
        name: "CrossWire",
        transport: .https,
        host: "www.crosswire.org",
        directory: "/ftpmirror/pub/sword/raw/",
        packageDirectory: "/ftpmirror/pub/sword/packages/rawzip/"
    )

    #expect(
        try repository.catalogURL().absoluteString
            == "https://www.crosswire.org/ftpmirror/pub/sword/raw/mods.d.tar.gz"
    )
    #expect(
        try repository.moduleArchiveURL(named: "ASV").absoluteString
            == "https://www.crosswire.org/ftpmirror/pub/sword/packages/rawzip/ASV.zip"
    )
}

@Test
func repositoryWithoutPackageDirectoryRejectsArchiveURL() throws {
    let repository = try SwordModuleRepository(
        identifier: "crosswire",
        name: "CrossWire",
        transport: .https,
        host: "www.crosswire.org",
        directory: "/ftpmirror/pub/sword/raw"
    )

    #expect(
        throws: SwordError.remoteModulePackagesUnavailable("crosswire")
    ) {
        try repository.moduleArchiveURL(named: "ASV")
    }
}

@Test
func repositoryRejectsPathLikeModuleArchiveName() throws {
    let repository = try SwordModuleRepository(
        identifier: "crosswire",
        name: "CrossWire",
        transport: .https,
        host: "www.crosswire.org",
        directory: "/ftpmirror/pub/sword/raw",
        packageDirectory: "/ftpmirror/pub/sword/packages/rawzip"
    )

    #expect(throws: SwordError.invalidRemoteModuleName("../ASV")) {
        try repository.moduleArchiveURL(named: "../ASV")
    }
}

@Test
func remoteModuleArchiveRejectsParentDirectoryEntry() throws {
    let workspace = FileManager.default.temporaryDirectory.appending(
        path: "SwordKitUnsafeArchive-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let archive = workspace.appending(path: "unsafe.zip")
    let destination = workspace.appending(
        path: "destination",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: destination,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: workspace) }

    let encoded =
        "UEsDBBQAAAAIAMaRFV37OSuCBQAAAAMAAAANAAAALi4vZXNjYXBlLnR4dEtKTAEA"
        + "UEsBAhQDFAAAAAgAxpEVXfs5K4IFAAAAAwAAAA0AAAAAAAAAAAAAAIABAAAAAC4u"
        + "L2VzY2FwZS50eHRQSwUGAAAAAAEAAQA7AAAAMAAAAAAA"
    try #require(Data(base64Encoded: encoded)).write(to: archive)

    #expect(throws: SwordError.invalidRemoteArchive("unsafe.zip")) {
        try SwordHTTPSRepositoryTransport.extractModuleArchive(
            archive,
            to: destination
        )
    }
    #expect(
        !FileManager.default.fileExists(
            atPath: workspace.appending(path: "escape.txt").path
        )
    )
}

@Test
func installerInstallsReceivedModuleArchive() throws {
    let workspace = FileManager.default.temporaryDirectory.appending(
        path: "SwordKitReceivedArchive-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let archive = workspace.appending(path: "testbible.zip")
    let destination = workspace.appending(path: "destination", directoryHint: .isDirectory)
    let privateDirectory = workspace.appending(path: "installer", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workspace) }

    let encoded = "UEsDBAoAAAAAAKKWFV0AAAAAAAAAAAAAAAAHABwAbW9kcy5kL1VUCQADz9aIas/WiGp1eAsAAQT1AQAABAAAAABQSwMEFAAAAAgAopYVXUZ0hLZcAAAAZgAAABUAHABtb2RzLmQvdGVzdGJpYmxlLmNvbmZVVAkAA8/WiGrP1ohqdXgLAAEE9QEAAAQAAAAAiw5JLS5xykzKSY3lckksSQxILMmw1dPPzU8pzUkt1i9JrSgp1i9KLAcxgLzikiSQWn0u3/wUl6Iy26DE8hCgDJdLanFyUWZBSWZ+ni3IRAWwkVw+iXnptql5XABQSwMECgAAAAAAopYVXQAAAAAAAAAAAAAAAAgAHABtb2R1bGVzL1VUCQADz9aIas/WiGp1eAsAAQT1AQAABAAAAABQSwMECgAAAAAAopYVXQAAAAAAAAAAAAAAAA4AHABtb2R1bGVzL3RleHRzL1VUCQADz9aIas/WiGp1eAsAAQT1AQAABAAAAABQSwMECgAAAAAAopYVXQAAAAAAAAAAAAAAABYAHABtb2R1bGVzL3RleHRzL3Jhd3RleHQvVVQJAAPP1ohqz9aIanV4CwABBPUBAAAEAAAAAFBLAwQKAAAAAACilhVdAAAAAAAAAAAAAAAAIAAcAG1vZHVsZXMvdGV4dHMvcmF3dGV4dC90ZXN0YmlibGUvVVQJAAPP1ohqz9aIanV4CwABBPUBAAAEAAAAAFBLAwQKAAAAAACilhVdwAXdlAsAAAALAAAAKwAcAG1vZHVsZXMvdGV4dHMvcmF3dGV4dC90ZXN0YmlibGUvcGxhY2Vob2xkZXJVVAkAA8/WiGrP1ohqdXgLAAEE9QEAAAQAAAAAbW9kdWxlLWRhdGFQSwECHgMKAAAAAACilhVdAAAAAAAAAAAAAAAABwAYAAAAAAAAABAA7UEAAAAAbW9kcy5kL1VUBQADz9aIanV4CwABBPUBAAAEAAAAAFBLAQIeAxQAAAAIAKKWFV1GdIS2XAAAAGYAAAAVABgAAAAAAAEAAACkgUEAAABtb2RzLmQvdGVzdGJpYmxlLmNvbmZVVAUAA8/WiGp1eAsAAQT1AQAABAAAAABQSwECHgMKAAAAAACilhVdAAAAAAAAAAAAAAAACAAYAAAAAAAAABAA7UHsAAAAbW9kdWxlcy9VVAUAA8/WiGp1eAsAAQT1AQAABAAAAABQSwECHgMKAAAAAACilhVdAAAAAAAAAAAAAAAADgAYAAAAAAAAABAA7UEuAQAAbW9kdWxlcy90ZXh0cy9VVAUAA8/WiGp1eAsAAQT1AQAABAAAAABQSwECHgMKAAAAAACilhVdAAAAAAAAAAAAAAAAFgAYAAAAAAAAABAA7UF2AQAAbW9kdWxlcy90ZXh0cy9yYXd0ZXh0L1VUBQADz9aIanV4CwABBPUBAAAEAAAAAFBLAQIeAwoAAAAAAKKWFV0AAAAAAAAAAAAAAAAgABgAAAAAAAAAEADtQcYBAABtb2R1bGVzL3RleHRzL3Jhd3RleHQvdGVzdGJpYmxlL1VUBQADz9aIanV4CwABBPUBAAAEAAAAAFBLAQIeAwoAAAAAAKKWFV3ABd2UCwAAAAsAAAArABgAAAAAAAEAAACkgSACAABtb2R1bGVzL3RleHRzL3Jhd3RleHQvdGVzdGJpYmxlL3BsYWNlaG9sZGVyVVQFAAPP1ohqdXgLAAEE9QEAAAQAAAAAUEsFBgAAAAAHAAcAfQIAAJACAAAAAA=="
    try #require(Data(base64Encoded: encoded)).write(to: archive)
    let configuration = try SwordInstallerConfiguration(
        destinationDirectory: destination,
        privateDirectory: privateDirectory
    )
    let installer = SwordModuleInstaller(configuration: configuration)

    try installer.install(moduleNamed: "TestBible", fromArchive: archive)

    let catalog = try SwordModuleCatalog(directory: destination)
    #expect(catalog.modules.map(\.name) == ["TestBible"])
}

@Test
func cachedRemoteCatalogReadsRepositoryShadow() throws {
    let workspace = FileManager.default.temporaryDirectory.appending(
        path: "SwordKitRemoteCatalog-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let shadow = workspace.appending(
        path: "installer/crosswire/mods.d",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: shadow,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: workspace) }

    try """
    [ASV]
    DataPath=./modules/texts/ztext/asv/
    ModDrv=zText
    Description=American Standard Version (1901)
    Lang=en
    Version=2.0
    Copyright=Public Domain
    """.write(
        to: shadow.appending(path: "asv.conf"),
        atomically: true,
        encoding: .utf8
    )

    let repository = try SwordModuleRepository(
        identifier: "crosswire",
        name: "CrossWire",
        transport: .ftp,
        host: "ftp.crosswire.org",
        directory: "/pub/sword/raw"
    )
    let configuration = try SwordInstallerConfiguration(
        destinationDirectory: workspace.appending(path: "modules"),
        privateDirectory: workspace.appending(path: "installer"),
        repositories: [repository]
    )
    let installer = SwordModuleInstaller(configuration: configuration)

    let catalog = try installer.cachedCatalog(for: repository)
    let module = try #require(catalog.modules.first)

    #expect(catalog.repository == repository)
    #expect(module.name == "ASV")
    #expect(module.title == "American Standard Version (1901)")
    #expect(module.version == "2.0")
    #expect(module.copyright == "Public Domain")
}

@Test
func remoteCatalogRefreshRequiresExplicitRiskAcknowledgement() async throws {
    let workspace = FileManager.default.temporaryDirectory.appending(
        path: "SwordKitRemoteAuthorization-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: workspace) }
    let repository = try SwordModuleRepository(
        identifier: "crosswire",
        name: "CrossWire",
        transport: .ftp,
        host: "ftp.crosswire.org",
        directory: "/pub/sword/raw"
    )
    let configuration = try SwordInstallerConfiguration(
        destinationDirectory: workspace.appending(path: "modules"),
        privateDirectory: workspace.appending(path: "installer"),
        repositories: [repository]
    )
    let installer = SwordModuleInstaller(configuration: configuration)

    await #expect(throws: SwordError.remoteAccessNotAuthorized) {
        try await installer.refreshCatalog(
            for: repository,
            acknowledgingRemoteAccessRisks: false
        )
    }
}

@Test
func moduleLocationBuildsAppOwnedApplicationSupportDirectories() throws {
    let applicationSupport = URL(
        fileURLWithPath: "/tmp/Application Support",
        isDirectory: true
    )
    let location = try SwordModuleLocation(
        applicationSupportDirectory: applicationSupport,
        applicationIdentifier: "com.example.reader"
    )

    #expect(
        location.modulesDirectory.path
            == "/tmp/Application Support/com.example.reader/Sword"
    )
    #expect(
        location.installerDirectory.path
            == "/tmp/Application Support/com.example.reader/SwordInstaller"
    )
}

@Test
func moduleLocationRejectsUnsafeApplicationIdentifier() {
    let applicationSupport = URL(fileURLWithPath: "/tmp")

    #expect(throws: SwordError.invalidStorageIdentifier("../shared")) {
        try SwordModuleLocation(
            applicationSupportDirectory: applicationSupport,
            applicationIdentifier: "../shared"
        )
    }
}

@Test
func moduleLocationResolvesUserApplicationSupportDirectory() throws {
    let location = try SwordModuleLocation.applicationSupport(
        applicationIdentifier: "com.example.reader"
    )

    #expect(location.modulesDirectory.isFileURL)
    #expect(
        location.modulesDirectory.path.hasSuffix(
            "/com.example.reader/Sword"
        )
    )
}

@Test
func installerConfigurationUsesModuleLocationDirectories() throws {
    let location = try SwordModuleLocation(
        modulesDirectory: URL(fileURLWithPath: "/tmp/sword-modules"),
        installerDirectory: URL(fileURLWithPath: "/tmp/sword-installer")
    )
    let configuration = SwordInstallerConfiguration(location: location)

    #expect(configuration.destinationDirectory == location.modulesDirectory)
    #expect(configuration.privateDirectory == location.installerDirectory)
}

@Test
func libraryAcceptsModuleLocation() throws {
    let location = try SwordModuleLocation(
        modulesDirectory: FileManager.default.temporaryDirectory.appending(
            path: "SwordKit-Modules-\(UUID().uuidString)"
        ),
        installerDirectory: FileManager.default.temporaryDirectory.appending(
            path: "SwordKit-Installer-\(UUID().uuidString)"
        )
    )
    let library = try SwordLibrary(location: location)

    #expect(library.modules.isEmpty)
}

@Test
func installerConfigurationRejectsRemoteDestination() throws {
    let remoteURL = try #require(URL(string: "https://example.com/modules"))

    #expect(throws: SwordError.invalidInstallDestination(remoteURL.absoluteString)) {
        try SwordInstallerConfiguration(
            destinationDirectory: remoteURL,
            privateDirectory: URL(fileURLWithPath: "/tmp/sword-installer")
        )
    }
}

@Test
func moduleRepositoryRejectsBlankHost() {
    #expect(throws: SwordError.invalidModuleRepository("crosswire")) {
        try SwordModuleRepository(
            identifier: "crosswire",
            name: "CrossWire",
            transport: .http,
            host: "  ",
            directory: "/modules"
        )
    }
}

@Test
func localModuleCatalogReadsSwordConfiguration() throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "SwordKitCatalog-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let configurationDirectory = root.appending(
        path: "mods.d",
        directoryHint: .isDirectory
    )

    try FileManager.default.createDirectory(
        at: configurationDirectory,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: root) }

    let configuration = """
    [TestBible]
    DataPath=./modules/texts/rawtext/testbible/
    ModDrv=RawText
    Description=Test Bible
    Lang=en
    Version=2.1
    Copyright=Public Domain
    """
    try configuration.write(
        to: configurationDirectory.appending(path: "testbible.conf"),
        atomically: true,
        encoding: .utf8
    )

    let catalog = try SwordModuleCatalog(directory: root)
    let module = try #require(catalog.modules.first)

    #expect(module.name == "TestBible")
    #expect(module.title == "Test Bible")
    #expect(module.language == "en")
    #expect(module.category == .bible)
    #expect(module.version == "2.1")
    #expect(module.copyright == "Public Domain")
}

@Test
func localModuleCatalogRejectsMissingDirectory() {
    let directory = FileManager.default.temporaryDirectory.appending(
        path: "SwordKit-Missing-\(UUID().uuidString)"
    )

    #expect(throws: SwordError.moduleCatalogNotFound(directory.absoluteString)) {
        try SwordModuleCatalog(directory: directory)
    }
}

@Test
func installerCopiesModuleFromLocalCatalog() throws {
    let workspace = FileManager.default.temporaryDirectory.appending(
        path: "SwordKitInstall-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let source = workspace.appending(path: "source", directoryHint: .isDirectory)
    let data = source.appending(
        path: "modules/texts/rawtext/testbible",
        directoryHint: .isDirectory
    )
    let configurationDirectory = source.appending(
        path: "mods.d",
        directoryHint: .isDirectory
    )
    let destination = workspace.appending(
        path: "destination",
        directoryHint: .isDirectory
    )
    let privateDirectory = workspace.appending(
        path: "installer",
        directoryHint: .isDirectory
    )

    try FileManager.default.createDirectory(
        at: configurationDirectory,
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: data,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: workspace) }

    try "module-data".write(
        to: data.appending(path: "placeholder"),
        atomically: true,
        encoding: .utf8
    )
    try """
    [TestBible]
    DataPath=./modules/texts/rawtext/testbible/
    ModDrv=RawText
    Description=Test Bible
    Lang=en
    """.write(
        to: configurationDirectory.appending(path: "testbible.conf"),
        atomically: true,
        encoding: .utf8
    )

    let catalog = try SwordModuleCatalog(directory: source)
    let configuration = try SwordInstallerConfiguration(
        destinationDirectory: destination,
        privateDirectory: privateDirectory
    )
    let installer = SwordModuleInstaller(configuration: configuration)

    try installer.install(moduleNamed: "TestBible", from: catalog)

    let installedCatalog = try SwordModuleCatalog(directory: destination)
    #expect(installedCatalog.modules.map(\.name) == ["TestBible"])
    let library = try SwordLibrary(directory: destination)
    let installedModule = try #require(library.module(named: "TestBible"))

    try installer.remove(moduleNamed: "TestBible")

    let catalogAfterRemoval = try SwordModuleCatalog(directory: destination)
    #expect(catalogAfterRemoval.modules.isEmpty)
    #expect(library.module(named: "TestBible") != nil)

    library.refresh()

    #expect(library.modules.isEmpty)
    #expect(installedModule.name == "TestBible")
}

@Test
func readingPlanTracksImmutableProgress() throws {
    let plan = try SwordReadingPlan(
        id: "gospel-week",
        title: "A Week in John",
        days: [
            try SwordReadingPlanDay(id: 1, readings: ["John 1"]),
            try SwordReadingPlanDay(id: 2, readings: ["John 2"])
        ]
    )
    let initial = SwordReadingPlanProgress(planID: plan.id)
    let updated = initial.completing(dayID: 1)

    #expect(initial.completedDayIDs.isEmpty)
    #expect(updated.completedDayIDs == [1])
    #expect(updated.completionFraction(for: plan) == 0.5)
}

@Test
func readingPlanRejectsDuplicateDayIdentifiers() throws {
    let first = try SwordReadingPlanDay(id: 1, readings: ["John 1"])
    let duplicate = try SwordReadingPlanDay(id: 1, readings: ["John 2"])

    #expect(throws: SwordError.invalidReadingPlan("duplicate")) {
        try SwordReadingPlan(
            id: "duplicate",
            title: "Duplicate",
            days: [first, duplicate]
        )
    }
}

@Test
func favoriteStoresPortableVerseIdentity() throws {
    let id = UUID()
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    let favorite = SwordFavorite(
        id: id,
        reference: try SwordReference("John 3:16"),
        moduleName: "KJV",
        createdAt: createdAt
    )

    #expect(favorite.id == id)
    #expect(favorite.reference.value == "John 3:16")
    #expect(favorite.moduleName == "KJV")
    #expect(favorite.createdAt == createdAt)
}

@Test
func bookmarkStoresOptionalUserLabel() throws {
    let bookmark = SwordBookmark(
        reference: try SwordReference("Romans 8:28"),
        moduleName: "KJV",
        label: "  Encouragement  "
    )
    let unlabeled = SwordBookmark(
        reference: try SwordReference("Romans 8:29"),
        label: "   "
    )

    #expect(bookmark.label == "Encouragement")
    #expect(bookmark.reference.value == "Romans 8:28")
    #expect(bookmark.moduleName == "KJV")
    #expect(unlabeled.label == nil)
}

@Test
func highlightStoresPortableStyleAndTextRange() throws {
    let range = try SwordTextRange(location: 4, length: 12)
    let highlight = try SwordHighlight(
        reference: SwordReference("Psalm 23:1"),
        moduleName: "KJV",
        styleIdentifier: "  yellow  ",
        range: range
    )

    #expect(highlight.styleIdentifier == "yellow")
    #expect(highlight.range == range)
    #expect(highlight.range?.location == 4)
    #expect(highlight.range?.length == 12)
}

@Test
func textRangeRejectsZeroLength() {
    #expect(throws: SwordError.invalidTextRange(location: 0, length: 0)) {
        try SwordTextRange(location: 0, length: 0)
    }
}

@Test
func noteUpdatesWithoutMutatingOriginalValue() throws {
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    let updatedAt = createdAt.addingTimeInterval(60)
    let note = try SwordNote(
        reference: SwordReference("John 1:1"),
        moduleName: "KJV",
        content: "  Opening of the Gospel  ",
        createdAt: createdAt
    )
    let updated = try note.updating(
        content: "The Word",
        at: updatedAt
    )

    #expect(note.content == "Opening of the Gospel")
    #expect(updated.content == "The Word")
    #expect(updated.id == note.id)
    #expect(updated.createdAt == createdAt)
    #expect(updated.updatedAt == updatedAt)
}

@Test
func noteRejectsBlankContent() throws {
    #expect(throws: SwordError.invalidNoteContent) {
        try SwordNote(
            reference: SwordReference("John 1:1"),
            content: "   "
        )
    }
}

@Test
func readingHistoryStoresAccessContext() throws {
    let accessedAt = Date(timeIntervalSince1970: 1_700_000_100)
    let entry = SwordReadingHistoryEntry(
        reference: try SwordReference("Luke 15:11"),
        moduleName: "KJV",
        accessedAt: accessedAt
    )

    #expect(entry.reference.value == "Luke 15:11")
    #expect(entry.moduleName == "KJV")
    #expect(entry.accessedAt == accessedAt)
}

@Test
func savedSearchPreservesReproducibleOptions() throws {
    let search = try SwordSavedSearch(
        query: "  faith hope  ",
        type: .multiWord,
        caseSensitive: false,
        scope: "Romans",
        moduleName: "KJV"
    )

    #expect(search.query == "faith hope")
    #expect(search.type == .multiWord)
    #expect(!search.caseSensitive)
    #expect(search.scope == "Romans")
    #expect(search.moduleName == "KJV")
}

@Test
func savedSearchRejectsBlankQuery() {
    #expect(throws: SwordError.invalidSearchQuery("")) {
        try SwordSavedSearch(query: "   ")
    }
}

@Test
func verseCollectionStoresUniquePortableReferences() throws {
    let john = try SwordReference("John 3:16")
    let romans = try SwordReference("Romans 8:1")
    let collection = try SwordVerseCollection(
        title: "  Promises  ",
        references: [john, romans]
    )

    #expect(collection.title == "Promises")
    #expect(collection.references == [john, romans])
}

@Test
func verseCollectionRejectsDuplicateReferences() throws {
    let reference = try SwordReference("John 3:16")

    #expect(throws: SwordError.invalidVerseCollection("Promises")) {
        try SwordVerseCollection(
            title: "Promises",
            references: [reference, reference]
        )
    }
}

@Test
func knownSwordCategoriesAreMapped() {
    #expect(
        SwordModule.Category(swordType: "Biblical Texts") == .bible
    )

    #expect(
        SwordModule.Category(swordType: "Commentaries") == .commentary
    )

    #expect(
        SwordModule.Category(
            swordType: "Lexicons / Dictionaries"
        ) == .dictionary
    )

    #expect(
        SwordModule.Category(swordType: "Generic Books") == .generalBook
    )

    #expect(
        SwordModule.Category(swordType: "Custom Type")
            == .other("Custom Type")
    )
}

@Test
func moduleKeepsNativeManagerAlive() {
    let module: SwordModule?

    do {
        let library = SwordLibrary()
        module = library.modules.first
    }

    guard let module else {
        // The machine may have zero installed modules.
        return
    }

    #expect(!module.name.isEmpty)
}

@Test
func referenceTrimsWhitespace() throws {
    let reference = try SwordReference("  John 3:16  ")

    #expect(reference.value == "John 3:16")
    #expect(reference.description == "John 3:16")
}

@Test
func emptyReferenceThrows() {
    #expect(throws: SwordError.emptyReference) {
        _ = try SwordReference("   \n   ")
    }
}

@Test
func verseStoresRetrievedValues() throws {
    let reference = try SwordReference("John 3:16")

    let verse = SwordVerse(
        reference: reference,
        moduleName: "KJV",
        text: "Test verse text"
    )

    #expect(verse.reference == reference)
    #expect(verse.moduleName == "KJV")
    #expect(verse.text == "Test verse text")
}

@Test
func footnoteStoresEntryMetadata() {
    let footnote = SwordFootnote(
        identifier: "1",
        body: "See the alternate reading.",
        type: "crossReference",
        referenceList: "John 1:1"
    )

    #expect(footnote.identifier == "1")
    #expect(footnote.body == "See the alternate reading.")
    #expect(footnote.type == "crossReference")
    #expect(footnote.referenceList == "John 1:1")
}

@Test
func crossReferenceStoresTypedReferences() throws {
    let crossReference = SwordCrossReference(
        footnoteIdentifier: "2",
        references: [
            try SwordReference("John 1:1"),
            try SwordReference("Genesis 1:1")
        ]
    )

    #expect(crossReference.footnoteIdentifier == "2")
    #expect(
        crossReference.references.map(\.value)
            == ["John 1:1", "Genesis 1:1"]
    )
}

@Test
func headingStoresPositionAndBody() {
    let heading = SwordHeading(
        identifier: "1",
        body: "The Word Became Flesh",
        position: .preVerse
    )

    #expect(heading.identifier == "1")
    #expect(heading.body == "The Word Became Flesh")
    #expect(heading.position == .preVerse)
}

@Test
func bibleModuleCanRetrieveVerse() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        // Integration testing requires an installed Bible module.
        return
    }

    let verse = try bible.verse("John 3:16")

    #expect(!verse.text.isEmpty)
    #expect(!verse.reference.value.isEmpty)
    #expect(verse.moduleName == bible.name)
}

@Test
func bibleModuleCanRenderHTML() throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let html = try bible.html("John 3:16")

    #expect(html.contains("God"))
    #expect(html.contains("<"))
}

@Test
func bibleModuleCanRenderAttributedString() throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let attributedText = try bible.attributedString("John 3:16")

    #expect(String(attributedText.characters).contains("God"))
}

@Test
func htmlRenderingPreservesRedLetterStyling() throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let html = try bible.html("Matthew 5:3")

    #expect(html.contains(".wordsOfJesus { color: red; }"))
    #expect(html.contains("class=\"wordsOfJesus\""))
}

@Test
func attributedStringIncludesStrongsAnnotations() throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let attributedText = try bible.attributedString("John 3:16")
    let strongsNumbers = attributedText.runs.compactMap {
        $0[SwordStrongsNumberAttribute.self]
    }

    #expect(strongsNumbers.contains("G25"))
}

@Test
func attributedStringIncludesMorphologyAnnotations() throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let attributedText = try bible.attributedString("John 3:16")
    let morphology = attributedText.runs.compactMap {
        $0[SwordMorphologyAttribute.self]
    }

    #expect(!morphology.isEmpty)
}

@Test
func verseLookupRejectsNonBibleModule() {
    let library = SwordLibrary()

    guard let module = library.modules.first(
        where: { $0.category != .bible }
    ) else {
        return
    }

    #expect(throws: SwordError.unsupportedModuleType) {
        _ = try module.verse("John 3:16")
    }
}

@Test
func moduleCanAdvanceToNextVerse() throws {

    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    _ = try bible.verse("John 3:16")

    let first = bible.currentReference

    bible.advance()

    let second = bible.currentReference

    #expect(first != nil)
    #expect(second != nil)
    #expect(first != second)
}

@Test
func moduleCanRetrieveSequentialPassage() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    let passage = try bible.passage(
        startingAt: "John 3:16",
        verseCount: 3
    )

    #expect(passage.verses.count == 3)
    #expect(passage.verses[0].reference.value == "John 3:16")
    #expect(passage.verses[1].reference.value == "John 3:17")
    #expect(passage.verses[2].reference.value == "John 3:18")
}

@Test
func passageRejectsInvalidVerseCount() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    #expect(throws: SwordError.self) {
        try bible.passage(
            startingAt: "John 3:16",
            verseCount: 0
        )
    }
}

@Test
func passageRangeParsesSameChapterRange() throws {
    let range = try SwordPassageRange(
        "John 3:16-21"
    )

    #expect(range.start.value == "John 3:16")
    #expect(range.endingVerse == 21)
    #expect(range.verseCount == 6)
}

@Test
func passageRangeSupportsNumberedBooks() throws {
    let range = try SwordPassageRange(
        "1 Corinthians 13:4-8"
    )

    #expect(range.start.value == "1 Corinthians 13:4")
    #expect(range.endingVerse == 8)
    #expect(range.verseCount == 5)
}

@Test
func passageRangeRejectsReversedRange() {
    #expect(throws: SwordError.self) {
        try SwordPassageRange("John 3:21-16")
    }
}

@Test
func moduleCanRetrievePassageRange() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    let passage = try bible.passage("John 3:16-18")

    #expect(passage.verses.count == 3)
    #expect(passage.verses[0].reference.value == "John 3:16")
    #expect(passage.verses[1].reference.value == "John 3:17")
    #expect(passage.verses[2].reference.value == "John 3:18")
}

@Test
func libraryCanRetrievePassageFromMultipleBibles() throws {
    let library = SwordLibrary()
    let bibles = Array(
        library.modules
            .filter { $0.category == .bible }
            .prefix(2)
    )

    guard bibles.count == 2 else {
        return
    }

    let result = try library.parallelPassage(
        "John 3:16-18",
        modules: bibles.map(\.name)
    )

    #expect(result.reference.value == "John 3:16-18")
    #expect(result.passages.map(\.moduleName) == bibles.map(\.name))
    #expect(result.passages.allSatisfy { $0.verses.count == 3 })
}

@Test
func parallelPassageRejectsUnknownModule() {
    let library = SwordLibrary()

    #expect(throws: SwordError.moduleNotFound("NotInstalled")) {
        try library.parallelPassage(
            "John 3:16-18",
            modules: ["NotInstalled"]
        )
    }
}

@Test
func parallelPassageReportsMissingReferencesByModule() throws {
    let range = try SwordPassageRange("John 3:16-18")
    let passage = SwordParallelPassage(
        reference: range,
        passages: [
            SwordPassage(
                reference: try SwordReference("John 3:16"),
                moduleName: "KJV",
                verses: [
                    SwordVerse(
                        reference: try SwordReference("John 3:16"),
                        moduleName: "KJV",
                        text: "First"
                    ),
                    SwordVerse(
                        reference: try SwordReference("John 3:18"),
                        moduleName: "KJV",
                        text: "Third"
                    )
                ]
            )
        ]
    )

    #expect(
        passage.missingReferences["KJV"]?.map(\.value)
            == ["John 3:17"]
    )
}

@Test
func parallelPassageAlignsVersesByReference() throws {
    let range = try SwordPassageRange("John 3:16-17")
    let verse = SwordVerse(
        reference: try SwordReference("John 3:16"),
        moduleName: "KJV",
        text: "Text"
    )
    let passage = SwordParallelPassage(
        reference: range,
        passages: [
            SwordPassage(
                reference: verse.reference,
                moduleName: "KJV",
                verses: [verse]
            )
        ]
    )

    #expect(passage.alignedVerses.map(\.reference.value) == ["John 3:16", "John 3:17"])
    #expect(passage.alignedVerses[0].versesByModule["KJV"] == verse)
    #expect(passage.alignedVerses[1].versesByModule["KJV"] == nil)
}

@Test
func alignedVerseComparesRenderedTextByModule() throws {
    let reference = try SwordReference("John 3:16")
    let comparison = SwordAlignedVerse(
        reference: reference,
        versesByModule: [
            "KJV": SwordVerse(
                reference: reference,
                moduleName: "KJV",
                text: "For God so loved the world"
            ),
            "ASV": SwordVerse(
                reference: reference,
                moduleName: "ASV",
                text: "For God so loved the world"
            ),
            "WEB": SwordVerse(
                reference: reference,
                moduleName: "WEB",
                text: "For God so loved the world,"
            )
        ]
    ).comparison

    #expect(comparison.textByModule["KJV"] == "For God so loved the world")
    #expect(comparison.hasTextDifferences)
}

@Test
func verseComparisonTokenizesGreekHebrewAndEnglishText() throws {
    let comparison = SwordVerseComparison(
        reference: try SwordReference("John 1:1"),
        textByModule: [
            "Greek": "Ἐν ἀρχῇ ἦν ὁ λόγος.",
            "Hebrew": "בְּרֵאשִׁית בָּרָא אֱלֹהִים׃",
            "English": "In the beginning, God created."
        ]
    )

    #expect(
        comparison.tokensByModule["Greek"]?.map(\.text)
            == ["Ἐν", "ἀρχῇ", "ἦν", "ὁ", "λόγος"]
    )
    #expect(
        comparison.tokensByModule["Hebrew"]?.map(\.text)
            == ["בְּרֵאשִׁית", "בָּרָא", "אֱלֹהִים"]
    )
    #expect(
        comparison.tokensByModule["English"]?.map(\.text)
            == ["In", "the", "beginning", "God", "created"]
    )
}

@Test
func wordTokensNormalizeCaseAndCanonicalUnicode() {
    let uppercase = SwordWordToken(text: "ΛΌΓΟΣ")
    let decomposed = SwordWordToken(text: "λο\u{0301}γος")

    #expect(uppercase.normalizedText == "λόγοσ")
    #expect(decomposed.normalizedText == "λόγοσ")
    #expect(uppercase.text == "ΛΌΓΟΣ")
    #expect(decomposed.text == "λο\u{0301}γος")
}

@Test
func lexicalAttributesNormalizeStrongsLemmaIdentifiers() {
    #expect(
        SwordLexicalAttribute(text: "ἀγάπη", lemma: "strong:G26")
            .strongsNumber == "G26"
    )
}

@Test
func verseRetrievalIncludesLexicalAttributes() throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let verse = try bible.verse("John 3:16")

    #expect(!verse.lexicalAttributes.isEmpty)
    #expect(verse.lexicalAttributes.contains { $0.strongsNumber == "G25" })
}

@Test
func comparisonTokensCarryMatchingLexicalAttributes() throws {
    let comparison = SwordVerseComparison(
        reference: try SwordReference("John 3:16"),
        textByModule: ["Greek": "θεὸς ἀγάπη"],
        lexicalAttributesByModule: [
            "Greek": [
                SwordLexicalAttribute(text: "θεὸς", lemma: "strong:G2316"),
                SwordLexicalAttribute(text: "ἀγάπη", lemma: "strong:G26")
            ]
        ]
    )

    #expect(
        comparison.tokensByModule["Greek"]?.map(\.strongsNumber)
            == ["G2316", "G26"]
    )
}

@Test
func comparisonTokensCarryMorphology() throws {
    let comparison = SwordVerseComparison(
        reference: try SwordReference("John 1:1"),
        textByModule: ["Greek": "ἦν"],
        lexicalAttributesByModule: [
            "Greek": [
                SwordLexicalAttribute(
                    text: "ἦν",
                    lemma: "strong:G1510",
                    morphology: "robinson:V-IAI-3S"
                )
            ]
        ]
    )

    #expect(
        comparison.tokensByModule["Greek"]?.first?.morphology
            == "robinson:V-IAI-3S"
    )
}

@Test
func comparisonLinksTokensAcrossModulesByStrongsNumber() throws {
    let comparison = SwordVerseComparison(
        reference: try SwordReference("John 3:16"),
        textByModule: [
            "Greek": "ἠγάπησεν",
            "English": "loved"
        ],
        lexicalAttributesByModule: [
            "Greek": [
                SwordLexicalAttribute(
                    text: "ἠγάπησεν",
                    lemma: "strong:G25"
                )
            ],
            "English": [
                SwordLexicalAttribute(
                    text: "loved",
                    lemma: "strong:G25"
                )
            ]
        ]
    )

    let link = try #require(comparison.wordLinks.first)
    #expect(link.strongsNumber == "G25")
    #expect(link.locations.map(\.moduleName) == ["English", "Greek"])
    #expect(link.locations.map(\.token.text) == ["loved", "ἠγάπησεν"])
}

@Test
func comparisonSupportsOneToManyLinksAndReportsUnlinkedWords() throws {
    let comparison = SwordVerseComparison(
        reference: try SwordReference("John 3:16"),
        textByModule: [
            "Greek": "ὁ θεὸς ἠγάπησεν",
            "English": "God truly loved"
        ],
        lexicalAttributesByModule: [
            "Greek": [
                SwordLexicalAttribute(text: "ὁ", lemma: "strong:G3588"),
                SwordLexicalAttribute(text: "θεὸς", lemma: "strong:G2316"),
                SwordLexicalAttribute(text: "ἠγάπησεν", lemma: "strong:G25")
            ],
            "English": [
                SwordLexicalAttribute(text: "God", lemma: "strong:G2316"),
                SwordLexicalAttribute(text: "truly", lemma: "strong:G25"),
                SwordLexicalAttribute(text: "loved", lemma: "strong:G25")
            ]
        ]
    )

    let love = try #require(
        comparison.wordLinks.first { $0.strongsNumber == "G25" }
    )
    #expect(love.locations.count == 3)
    #expect(
        comparison.unlinkedWordLocations.map(\.token.text) == ["ὁ"]
    )
}

@Test
func chapterReferenceParsesBookAndChapter() throws {
    let reference = try SwordChapterReference("John 3")

    #expect(reference.value == "John 3")
    #expect(reference.book == "John")
    #expect(reference.chapterNumber == 3)
}

@Test
func chapterReferenceSupportsNumberedBooks() throws {
    let reference = try SwordChapterReference(
        "1 Corinthians 13"
    )

    #expect(reference.value == "1 Corinthians 13")
    #expect(reference.book == "1 Corinthians")
    #expect(reference.chapterNumber == 13)
}

@Test
func chapterReferenceRejectsVerseReference() {
    #expect(throws: SwordError.self) {
        try SwordChapterReference("John 3:16")
    }
}

@Test
func moduleCanRetrieveChapter() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    let chapter = try bible.chapter("John 3")
    let expectedReference = try SwordChapterReference("John 3")

    #expect(chapter.reference == expectedReference)
    #expect(!chapter.verses.isEmpty)
    #expect(chapter.verses.first?.reference.value == "John 3:1")
    #expect(chapter.verses.last?.reference.value == "John 3:36")
}

@Test
func moduleCanParseReferenceList() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    let references = try bible.references(
        in: "John 3:16-18; Romans 8:28"
    )

    #expect(references.count == 4)
    #expect(references[0].value == "John 3:16")
    #expect(references[1].value == "John 3:17")
    #expect(references[2].value == "John 3:18")
    #expect(references[3].value == "Romans 8:28")
}

@Test
func moduleCanParseNumberedBookReferenceList() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    let references = try bible.references(
        in: "1 Corinthians 13:4-6"
    )

    #expect(references.count == 3)
    #expect(references.first?.value == "1 Corinthians 13:4")
    #expect(references.last?.value == "1 Corinthians 13:6")
}

@Test
func referenceListRejectsEmptyExpression() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    #expect(throws: SwordError.self) {
        try bible.references(in: "   ")
    }
}

@Test
func moduleCanRetrieveVersesFromDisjointExpression() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    let verses = try bible.verses(
        in: "John 3:16; Romans 8:28"
    )

    #expect(verses.map(\.reference.value) == [
        "John 3:16",
        "Romans 8:28",
    ])
    #expect(verses.allSatisfy { !$0.text.isEmpty })
}

@Test
func moduleCanRetrieveVersesFromReferenceList() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    let references = try bible.references(
        in: "John 3:16-18; Romans 8:28"
    )
    let verses = try bible.verses(in: references)

    #expect(
        verses.map(\.reference)
            == Array(references)
    )
    #expect(verses.allSatisfy { $0.moduleName == bible.name })
}

@Test
func moduleCanRetrieveCrossBookChapters() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    let verses = try bible.verses(
        in: "John 21; Acts 1"
    )

    #expect(verses.count == 51)
    #expect(verses.first?.reference.value == "John 21:1")
    #expect(verses[24].reference.value == "John 21:25")
    #expect(verses[25].reference.value == "Acts 1:1")
    #expect(verses.last?.reference.value == "Acts 1:26")
}

@Test
func searchResultStoresRetrievedValues() throws {
    let result = SwordSearchResult(
        reference: try SwordReference("John 11:35"),
        moduleName: "KJV",
        text: "Jesus wept.",
        score: 42
    )

    #expect(result.reference.value == "John 11:35")
    #expect(result.moduleName == "KJV")
    #expect(result.text == "Jesus wept.")
    #expect(result.score == 42)
}

@Test
func searchResultsCanBeRankedByDescendingRelevance() throws {
    let results = [
        SwordSearchResult(
            reference: try SwordReference("John 1:1"),
            moduleName: "KJV",
            text: "First",
            score: 10
        ),
        SwordSearchResult(
            reference: try SwordReference("John 1:2"),
            moduleName: "KJV",
            text: "Second",
            score: 30
        ),
        SwordSearchResult(
            reference: try SwordReference("John 1:3"),
            moduleName: "KJV",
            text: "Third",
            score: 20
        )
    ]

    #expect(
        results.rankedByRelevance().map(\.score) == [30, 20, 10]
    )
}

@Test
func relevanceRankingPreservesOriginalOrderForTies() throws {
    let results = [
        SwordSearchResult(
            reference: try SwordReference("John 1:1"),
            moduleName: "KJV",
            text: "First",
            score: 20
        ),
        SwordSearchResult(
            reference: try SwordReference("John 1:2"),
            moduleName: "KJV",
            text: "Second",
            score: 20
        )
    ]

    #expect(
        results.rankedByRelevance().map(\.reference.value)
            == ["John 1:1", "John 1:2"]
    )
}

@Test
func bibleModuleCanSearchForPhrase() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: {
            $0.category == .bible
                && $0.language.lowercased().hasPrefix("en")
        }
    ) else {
        return
    }

    let results = try bible.search("Jesus wept")

    let result = results.first {
        $0.reference.value == "John 11:35"
    }

    #expect(result != nil)
    #expect(result?.moduleName == bible.name)
    #expect(result?.text.isEmpty == false)
}

@Test
func searchRejectsEmptyQuery() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    #expect(throws: SwordError.invalidSearchQuery("   ")) {
        try bible.search("   ")
    }
}

@Test
func bibleModuleCanSearchForMultipleWords() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: {
            $0.category == .bible
                && $0.language.lowercased().hasPrefix("en")
        }
    ) else {
        return
    }

    let results = try bible.search(
        "Jesus Lazarus",
        type: .multiWord
    )

    #expect(
        results.contains {
            $0.reference.value == "John 11:14"
        }
    )
}

@Test
func bibleModuleCanSearchWithRegularExpression() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: {
            $0.category == .bible
                && $0.language.lowercased().hasPrefix("en")
        }
    ) else {
        return
    }

    let results = try bible.search(
        "Jesus (wept|cried)",
        type: .regularExpression
    )

    #expect(
        results.contains {
            $0.reference.value == "John 11:35"
        }
    )
}

@Test
func bibleModuleCanSearchIgnoringCase() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: {
            $0.category == .bible
                && $0.language.lowercased().hasPrefix("en")
        }
    ) else {
        return
    }

    let results = try bible.search(
        "jEsUs WePt",
        caseSensitive: false
    )

    #expect(
        results.contains {
            $0.reference.value == "John 11:35"
        }
    )
}

@Test
func bibleModuleCanSearchByStrongsNumber() throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let results = try bible.search(
        "G25",
        type: .strongs
    )

    #expect(
        results.contains {
            $0.reference.value == "John 3:16"
        }
    )
}

@Test
func strongsSearchRejectsInvalidNumber() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    #expect(throws: SwordError.invalidStrongsNumber("grace")) {
        try bible.search(
            "grace",
            type: .strongs
        )
    }
}

@Test
func bibleModuleCanSearchByMorphology() throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let results = try bible.search(
        "V-AAI-3S",
        type: .morphology
    )

    #expect(
        results.contains {
            $0.reference.value == "Acts 2:22"
        }
    )
}

@Test
func bibleModuleCanSearchWithinScope() throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let results = try bible.search(
        "faith",
        caseSensitive: false,
        scope: "Romans"
    )

    #expect(!results.isEmpty)
    #expect(
        results.allSatisfy {
            $0.reference.value.hasPrefix("Romans ")
        }
    )
}

@Test
func searchRejectsEmptyScope() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    #expect(throws: SwordError.invalidReferenceList("   ")) {
        try bible.search(
            "faith",
            scope: "   "
        )
    }
}

@Test
func bibleModuleCanSearchAsynchronously() async throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let results = try await bible.searchAsync(
        "Jesus wept",
        scope: "John 11"
    )

    #expect(
        results.contains {
            $0.reference.value == "John 11:35"
        }
    )
}

@Test
func bibleModuleCanRetrieveVersesAsynchronously() async throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let verses = try await bible.versesAsync(
        in: "John 3:16-18"
    )

    #expect(verses.map(\.reference.value) == [
        "John 3:16",
        "John 3:17",
        "John 3:18"
    ])
}

@Test
func libraryCanRetrieveParallelPassageAsynchronously() async throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let passage = try await library.parallelPassageAsync(
        "John 3:16-18",
        modules: [bible.name]
    )

    #expect(passage.passages.map(\.moduleName) == [bible.name])
    #expect(passage.alignedVerses.count == 3)
}

@Test
func asynchronousVerseRetrievalHonorsCancellation() async throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let task = Task {
        try await bible.versesAsync(in: "Genesis 1-50")
    }
    task.cancel()

    await #expect(throws: CancellationError.self) {
        try await task.value
    }
}

@Test
func asynchronousSearchReportsProgress() async throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let progress = SearchProgressRecorder()

    _ = try await bible.searchAsync(
        "Jesus wept",
        scope: "John 11",
        progress: { percentage in
            progress.record(percentage)
        }
    )

    let percentages = progress.percentages
    #expect(!percentages.isEmpty)
    #expect(percentages.allSatisfy { (0...100).contains($0) })
}

@MainActor
@Test
func asynchronousSearchRunsProgressOffMainThread() async throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let progress = SearchProgressRecorder()

    _ = try await bible.searchAsync(
        "Jesus wept",
        scope: "John 11",
        progress: { percentage in
            progress.record(
                percentage,
                isMainThread: Thread.isMainThread
            )
        }
    )

    #expect(progress.observedBackgroundThread)
}

@Test
func asynchronousSearchCanBeCancelled() async throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let task = Task {
        try await bible.searchAsync(
            "the",
            caseSensitive: false
        )
    }

    task.cancel()

    do {
        _ = try await task.value
        Issue.record("Expected the search to be cancelled")
    } catch is CancellationError {
        // Expected.
    }
}

@Test
func searchStreamYieldsOrderedResults() async throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let expected = try await bible.searchAsync(
        "Jesus wept",
        scope: "John 11"
    )
    var streamed: [SwordSearchResult] = []

    for try await result in bible.searchStream(
        "Jesus wept",
        scope: "John 11"
    ) {
        streamed.append(result)
    }

    #expect(streamed == expected)
}

@Test
func searchStreamPropagatesValidationErrors() async throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    await #expect(throws: SwordError.invalidSearchQuery("   ")) {
        for try await _ in bible.searchStream("   ") {}
    }
}

@Test
func sharedBibleSerializesConcurrentVerseAccess() async throws {
    let library = SwordLibrary()

    guard let bible = library.module(named: "KJV") else {
        return
    }

    let references = ["John 3:16", "Romans 8:28", "Psalm 23:1"]
    let retrieved = try await withThrowingTaskGroup(
        of: SwordVerse.self,
        returning: [SwordVerse].self
    ) { group in
        for index in 0..<30 {
            group.addTask {
                try bible.verse(references[index % references.count])
            }
        }

        var verses: [SwordVerse] = []
        for try await verse in group {
            verses.append(verse)
        }
        return verses
    }

    #expect(retrieved.count == 30)
    #expect(
        retrieved.allSatisfy {
            references.contains($0.reference.value) && !$0.text.isEmpty
        }
    )
}

@Test
func sharedLibrarySerializesRefreshAndModuleSnapshots() async {
    let library = SwordLibrary()

    await withTaskGroup(of: Void.self) { group in
        for index in 0..<20 {
            group.addTask {
                if index.isMultiple(of: 2) {
                    library.refresh()
                } else {
                    _ = library.modules.map(\.name)
                }
            }
        }
    }

    #expect(library.modules.map(\.name) == library.modules.map(\.name).sorted())
}

@Test
func portablePublicValuesAreSendable() {
    requireSendable(SwordBook.self)
    requireSendable(SwordReference.self)
    requireSendable(SwordReferenceList.self)
    requireSendable(SwordPassageRange.self)
    requireSendable(SwordVerse.self)
    requireSendable(SwordChapter.self)
    requireSendable(SwordPassage.self)
    requireSendable(SwordSearchResult.self)
    requireSendable(SwordParallelPassage.self)
    requireSendable(SwordVerseComparison.self)
    requireSendable(SwordReadingPlan.self)
    requireSendable(SwordFavorite.self)
    requireSendable(SwordBookmark.self)
    requireSendable(SwordHighlight.self)
    requireSendable(SwordNote.self)
    requireSendable(SwordReadingHistoryEntry.self)
    requireSendable(SwordSavedSearch.self)
    requireSendable(SwordVerseCollection.self)
    requireSendable(SwordLibrary.self)
    requireSendable(SwordModule.self)
}

@Test
func installedBibleSupportsCompleteReadingWorkflow() throws {
    let library = SwordLibrary()

    guard let bible = library.modules.first(
        where: { $0.category == .bible }
    ) else {
        return
    }

    let verse = try bible.verse("John 3:16")
    let chapter = try bible.chapter("John 3")
    let passage = try bible.passage("John 3:16-18")
    let results = try bible.search(
        "God",
        caseSensitive: false,
        scope: "John 3"
    )
    let parallel = try library.parallelPassage(
        "John 3:16-18",
        modules: [bible.name]
    )

    #expect(verse.moduleName == bible.name)
    #expect(chapter.verses.contains(verse))
    #expect(passage.verses.first == verse)
    #expect(results.contains { $0.reference == verse.reference })
    #expect(parallel.passages == [passage])
    #expect(
        parallel.alignedVerses.first?
            .comparison.tokensByModule[bible.name]?.isEmpty == false
    )
}

private func requireSendable<Value: Sendable>(_: Value.Type) {}

private final class SearchProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedPercentages: [Int] = []
    private var recordedMainThreadValues: [Bool] = []

    var percentages: [Int] {
        lock.withLock { recordedPercentages }
    }

    var observedBackgroundThread: Bool {
        lock.withLock {
            recordedMainThreadValues.contains(false)
        }
    }

    func record(
        _ percentage: Int,
        isMainThread: Bool = Thread.isMainThread
    ) {
        lock.withLock {
            recordedPercentages.append(percentage)
            recordedMainThreadValues.append(isMainThread)
        }
    }
}
