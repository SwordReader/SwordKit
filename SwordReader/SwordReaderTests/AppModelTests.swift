import Foundation
import Testing
@testable import SwordReaderMac

@MainActor
struct AppModelTests {
    @Test func startSelectsFirstInstalledBible() async {
        let service = FakeScriptureService()
        let model = AppModel(service: service)

        await model.start()

        #expect(model.modules.map(\.id) == ["WEB"])
        #expect(model.selectedModuleID == "WEB")
    }

    @Test func openingSearchResultLoadsItsChapter() async throws {
        let service = FakeScriptureService()
        let model = AppModel(service: service)
        await model.start()

        model.open(reference: "Romans 8:28")
        try await Task.sleep(for: .milliseconds(20))

        #expect(model.section == .read)
        #expect(model.reference == "Romans 8")
        #expect(model.chapter?.reference == "Romans 8")
    }

    @Test func emptySearchClearsResults() async throws {
        let service = FakeScriptureService()
        let model = AppModel(service: service)
        await model.start()
        model.search("grace")
        try await Task.sleep(for: .milliseconds(20))
        #expect(model.searchResults.count == 1)

        model.search("  ")

        #expect(model.searchResults.isEmpty)
    }
}

private actor FakeScriptureService: ScriptureServing {
    func installedBibles() -> [BibleModule] {
        [BibleModule(id: "WEB", title: "World English Bible", language: "en", version: nil)]
    }

    func chapter(_ reference: String, moduleID: String) -> BibleChapter {
        BibleChapter(reference: reference, moduleID: moduleID, verses: [])
    }

    func search(_ query: String, moduleID: String) -> [BibleSearchResult] {
        [BibleSearchResult(reference: "Ephesians 2:8", moduleID: moduleID, text: query, score: 100)]
    }

    func catalog(at directory: URL) -> LocalCatalog { LocalCatalog(directory: directory, modules: []) }
    func install(moduleID: String, from catalog: LocalCatalog) {}
}
