import Foundation
import SwordKit

protocol ScriptureServing: Sendable {
    func installedBibles() async throws -> [BibleModule]
    func chapter(_ reference: String, moduleID: String) async throws -> BibleChapter
    func search(_ query: String, moduleID: String) async throws -> [BibleSearchResult]
    func catalog(at directory: URL) async throws -> LocalCatalog
    func install(moduleID: String, from catalog: LocalCatalog) async throws
}

actor SwordScriptureService: ScriptureServing {
    private let library: SwordLibrary
    private let installer: SwordModuleInstaller

    init() throws {
        let location = try SwordModuleLocation.applicationSupport()
        library = try SwordLibrary(location: location)
        installer = SwordModuleInstaller(
            configuration: SwordInstallerConfiguration(location: location)
        )
    }

    func installedBibles() -> [BibleModule] {
        library.modules(category: .bible).map {
            BibleModule(
                id: $0.name,
                title: $0.title.isEmpty ? $0.name : $0.title,
                language: $0.language,
                version: $0.version
            )
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func chapter(_ reference: String, moduleID: String) async throws -> BibleChapter {
        guard let module = library.module(named: moduleID) else {
            throw SwordError.moduleNotFound(moduleID)
        }

        let chapter = try module.chapter(reference)
        return BibleChapter(
            reference: chapter.reference.value,
            moduleID: chapter.moduleName,
            verses: chapter.verses.map {
                BibleVerse(
                    reference: $0.reference.value,
                    number: Self.verseNumber(from: $0.reference.value),
                    text: $0.text
                )
            }
        )
    }

    func search(_ query: String, moduleID: String) async throws -> [BibleSearchResult] {
        guard let module = library.module(named: moduleID) else {
            throw SwordError.moduleNotFound(moduleID)
        }

        return try await module.searchAsync(query, caseSensitive: false).map {
            BibleSearchResult(
                reference: $0.reference.value,
                moduleID: $0.moduleName,
                text: $0.text,
                score: $0.score
            )
        }
    }

    func catalog(at directory: URL) throws -> LocalCatalog {
        let catalog = try SwordModuleCatalog(directory: directory)
        return LocalCatalog(
            directory: catalog.directory,
            modules: catalog.modules.map {
                CatalogModule(
                    id: $0.name,
                    title: $0.title.isEmpty ? $0.name : $0.title,
                    language: $0.language,
                    isBible: $0.category == .bible
                )
            }
        )
    }

    func install(moduleID: String, from catalog: LocalCatalog) throws {
        let source = try SwordModuleCatalog(directory: catalog.directory)
        try installer.install(moduleNamed: moduleID, from: source)
        library.refresh()
    }

    private static func verseNumber(from reference: String) -> String {
        reference.split(separator: ":").last.map(String.init) ?? reference
    }
}

