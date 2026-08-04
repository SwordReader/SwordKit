import Foundation

struct BibleModule: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let language: String
    let version: String?
}

struct BibleVerse: Identifiable, Hashable, Sendable {
    var id: String { reference }
    let reference: String
    let number: String
    let text: String
}

struct BibleChapter: Hashable, Sendable {
    let reference: String
    let moduleID: String
    let verses: [BibleVerse]
}

struct BibleSearchResult: Identifiable, Hashable, Sendable {
    var id: String { "\(moduleID):\(reference)" }
    let reference: String
    let moduleID: String
    let text: String
    let score: Int
}

struct CatalogModule: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let language: String
    let isBible: Bool
}

struct LocalCatalog: Hashable, Sendable {
    let directory: URL
    let modules: [CatalogModule]
}

enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case read
    case search
    case library

    var id: Self { self }

    var title: String {
        switch self {
        case .read: "Read"
        case .search: "Search"
        case .library: "Library"
        }
    }

    var systemImage: String {
        switch self {
        case .read: "book.pages"
        case .search: "magnifyingglass"
        case .library: "books.vertical"
        }
    }
}

