import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var section: AppSection = .read
    private(set) var modules: [BibleModule] = []
    var selectedModuleID: String? {
        didSet {
            guard selectedModuleID != oldValue else { return }
            if let selectedModuleID {
                UserDefaults.standard.set(selectedModuleID, forKey: Self.moduleKey)
            }
            loadChapter()
        }
    }
    var reference = "John 3"
    private(set) var chapter: BibleChapter?
    private(set) var searchResults: [BibleSearchResult] = []
    private(set) var catalog: LocalCatalog?
    private(set) var isLoading = false
    private(set) var isSearching = false
    private(set) var isInstalling = false
    var presentedError: PresentedError?

    private let service: any ScriptureServing
    private var chapterTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private static let moduleKey = "selectedBibleModule"

    init(service: any ScriptureServing) {
        self.service = service
    }

    convenience init() {
        do {
            try self.init(service: SwordScriptureService())
        } catch {
            self.init(service: UnavailableScriptureService(error: error))
            presentedError = PresentedError(error)
        }
    }

    func start() async {
        do {
            modules = try await service.installedBibles()
            let saved = UserDefaults.standard.string(forKey: Self.moduleKey)
            selectedModuleID = modules.contains(where: { $0.id == saved }) ? saved : modules.first?.id
        } catch {
            presentedError = PresentedError(error)
        }
    }

    func submitReference() {
        reference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        loadChapter()
    }

    func open(reference newReference: String) {
        reference = Self.chapterReference(from: newReference)
        section = .read
        loadChapter()
    }

    func moveChapter(by offset: Int) {
        guard offset != 0 else { return }
        let parts = reference.split(whereSeparator: \.isWhitespace)
        guard let last = parts.last, let number = Int(last) else { return }
        let next = number + offset
        guard next > 0 else { return }
        reference = parts.dropLast().joined(separator: " ") + " \(next)"
        loadChapter()
    }

    func search(_ query: String) {
        searchTask?.cancel()
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, let selectedModuleID else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            do {
                searchResults = try await service.search(normalized, moduleID: selectedModuleID)
            } catch is CancellationError {
                return
            } catch {
                presentedError = PresentedError(error)
            }
            isSearching = false
        }
    }

    func inspectCatalog(at directory: URL) async {
        let hasAccess = directory.startAccessingSecurityScopedResource()
        defer { if hasAccess { directory.stopAccessingSecurityScopedResource() } }
        do {
            catalog = try await service.catalog(at: directory)
        } catch {
            presentedError = PresentedError(error)
        }
    }

    func install(_ module: CatalogModule) async {
        guard let catalog else { return }
        let hasAccess = catalog.directory.startAccessingSecurityScopedResource()
        defer { if hasAccess { catalog.directory.stopAccessingSecurityScopedResource() } }
        isInstalling = true
        defer { isInstalling = false }
        do {
            try await service.install(moduleID: module.id, from: catalog)
            modules = try await service.installedBibles()
            selectedModuleID = module.id
            self.catalog = nil
        } catch {
            presentedError = PresentedError(error)
        }
    }

    private func loadChapter() {
        chapterTask?.cancel()
        guard let selectedModuleID, !reference.isEmpty else {
            chapter = nil
            return
        }
        isLoading = true
        chapterTask = Task {
            do {
                chapter = try await service.chapter(reference, moduleID: selectedModuleID)
            } catch is CancellationError {
                return
            } catch {
                presentedError = PresentedError(error)
            }
            isLoading = false
        }
    }

    static func chapterReference(from reference: String) -> String {
        reference.split(separator: ":", maxSplits: 1).first.map(String.init) ?? reference
    }
}

struct PresentedError: Identifiable {
    let id = UUID()
    let message: String

    init(_ error: any Error) {
        message = error.localizedDescription
    }
}

private actor UnavailableScriptureService: ScriptureServing {
    let error: any Error

    init(error: any Error) {
        self.error = error
    }

    func installedBibles() async throws -> [BibleModule] { throw error }
    func chapter(_ reference: String, moduleID: String) async throws -> BibleChapter { throw error }
    func search(_ query: String, moduleID: String) async throws -> [BibleSearchResult] { throw error }
    func catalog(at directory: URL) async throws -> LocalCatalog { throw error }
    func install(moduleID: String, from catalog: LocalCatalog) async throws { throw error }
}
