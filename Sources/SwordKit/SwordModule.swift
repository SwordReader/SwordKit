import CSwordBridge
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// An installed module provided by the SWORD engine.
///
/// A module may represent a Bible, commentary, dictionary, lexicon,
/// or general book.
public final class SwordModule: Hashable, @unchecked Sendable {
    /// The module's internal SWORD identifier.
    public let name: String
    
    /// The human-readable module title or description.
    public let title: String
    
    /// The module's language code.
    public let language: String

    /// The module version supplied by its SWORD configuration.
    public let version: String?

    /// Copyright information supplied by the module publisher.
    public let copyright: String?
    
    /// The general type of content contained in the module.
    public let category: Category
    
    private let storage: SwordManagerStorage
    let accessLock = NSRecursiveLock()
    internal let handle: OpaquePointer
    
    internal init(
        storage: SwordManagerStorage,
        handle: OpaquePointer
    ) {
        self.storage = storage
        self.handle = handle
        
        self.name = SwordLibrary.string(
            from: SwordModuleName(handle)
        )
        
        self.title = SwordLibrary.string(
            from: SwordModuleDescription(handle)
        )
        
        self.language = SwordLibrary.string(
            from: SwordModuleLanguage(handle)
        )

        self.version = SwordLibrary.string(
            from: SwordModuleVersion(handle)
        ).nilIfEmpty

        self.copyright = SwordLibrary.string(
            from: SwordModuleCopyright(handle)
        ).nilIfEmpty
        
        let type = SwordLibrary.string(
            from: SwordModuleType(handle)
        )
        
        self.category = Category(swordType: type)
    }

    /// Returns the ordered books in this Bible module's native versification.
    ///
    /// Book identifiers and chapter counts come from the module's configured
    /// SWORD versification rather than from a fixed application canon.
    public func books() throws -> [SwordBook] {
        try accessLock.withLock {
            guard category == .bible else {
                throw SwordError.unsupportedModuleType
            }

            return (0..<SwordModuleBookCount(handle)).compactMap {
                index -> SwordBook? in
                let osisName = SwordLibrary.string(
                    from: SwordModuleBookOSISName(handle, index)
                )
                let name = SwordLibrary.string(
                    from: SwordModuleBookName(handle, index)
                )
                let chapterCount = SwordModuleBookChapterCount(handle, index)
                let testament = SwordModuleBookTestament(handle, index)

                guard
                    !osisName.isEmpty,
                    !name.isEmpty,
                    chapterCount > 0,
                    testament == 1 || testament == 2
                else {
                    return nil
                }

                return SwordBook(
                    osisName: osisName,
                    name: name,
                    preferredAbbreviation: SwordLibrary.string(
                        from: SwordModuleBookPreferredAbbreviation(handle, index)
                    ),
                    chapterCount: Int(chapterCount),
                    testament: testament == 1 ? .old : .new
                )
            }
        }
    }
    
    /// Parses a Scripture reference expression using the module's
    /// native SWORD versification.
    public func references(
        in expression: String
    ) throws -> SwordReferenceList {
        try accessLock.withLock {
            try referencesWithoutLock(in: expression)
        }
    }

    private func referencesWithoutLock(
        in expression: String
    ) throws -> SwordReferenceList {
        guard category == .bible else {
            throw SwordError.unsupportedModuleType
        }

        let trimmedExpression = expression.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedExpression.isEmpty else {
            throw SwordError.invalidReferenceList(expression)
        }

        SwordModuleClearParsedReferences(handle)

        defer {
            SwordModuleClearParsedReferences(handle)
        }

        let count = trimmedExpression.withCString { pointer in
            SwordModuleParseReferenceCount(
                handle,
                pointer
            )
        }

        guard count > 0 else {
            throw SwordError.invalidReferenceList(expression)
        }

        var references: [SwordReference] = []
        references.reserveCapacity(count)

        for index in 0..<count {
            guard let pointer = SwordModuleParsedReference(
                handle,
                index
            ) else {
                throw SwordError.invalidReferenceList(expression)
            }

            let value = String(cString: pointer)

            guard !value.isEmpty else {
                throw SwordError.invalidReferenceList(expression)
            }

            references.append(
                try SwordReference(value)
            )
        }

        return SwordReferenceList(
            references: references
        )
    }

    /// Retrieves verses from a parsed Scripture reference list.
    ///
    /// Verses are returned in the same order as their references.
    public func verses(
        in references: SwordReferenceList
    ) throws -> [SwordVerse] {
        try references.map(verse)
    }

    /// Parses a Scripture reference expression and retrieves its verses.
    ///
    /// The expression may contain ranges, disjoint references, and
    /// references that span multiple books.
    public func verses(
        in expression: String
    ) throws -> [SwordVerse] {
        try verses(
            in: references(in: expression)
        )
    }

    /// Retrieves verses cooperatively, preserving reference order.
    ///
    /// The operation checks for task cancellation between entries. Native
    /// access is serialized with other operations on this module.
    public func versesAsync(
        in references: SwordReferenceList
    ) async throws -> [SwordVerse] {
        var verses: [SwordVerse] = []
        verses.reserveCapacity(references.count)

        for reference in references {
            try Task.checkCancellation()
            verses.append(try verse(reference))
            await Task<Never, Never>.yield()
        }

        try Task.checkCancellation()
        return verses
    }

    /// Parses a Scripture expression and retrieves its verses cooperatively.
    public func versesAsync(
        in expression: String
    ) async throws -> [SwordVerse] {
        try Task.checkCancellation()
        let references = try references(in: expression)
        return try await versesAsync(in: references)
    }

    /// Searches a Bible module for matching entries.
    ///
    /// - Parameters:
    ///   - query: The nonempty text to find.
    ///   - type: The matching strategy. The default is exact phrase search.
    ///   - caseSensitive: Whether letter case must match. The default is `true`.
    ///   - scope: An optional Scripture reference expression to search within.
    ///   - progress: An optional callback receiving search completion percentages.
    /// - Returns: Matching verses in the order returned by SWORD.
    public func search(
        _ query: String,
        type: SwordSearchType = .phrase,
        caseSensitive: Bool = true,
        scope: String? = nil,
        progress: (@Sendable (Int) -> Void)? = nil
    ) throws -> [SwordSearchResult] {
        try accessLock.withLock {
            try searchWithoutLock(
                query,
                type: type,
                caseSensitive: caseSensitive,
                scope: scope,
                progress: progress
            )
        }
    }

    private func searchWithoutLock(
        _ query: String,
        type: SwordSearchType,
        caseSensitive: Bool,
        scope: String?,
        progress: (@Sendable (Int) -> Void)?
    ) throws -> [SwordSearchResult] {
        guard category == .bible else {
            throw SwordError.unsupportedModuleType
        }

        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedQuery.isEmpty else {
            throw SwordError.invalidSearchQuery(query)
        }

        let normalizedQuery = try type.normalizedQuery(
            trimmedQuery
        )

        let normalizedScope: String

        if let scope {
            normalizedScope = scope.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !normalizedScope.isEmpty else {
                throw SwordError.invalidReferenceList(scope)
            }
        } else {
            normalizedScope = ""
        }

        SwordModuleClearSearchResults(handle)

        defer {
            SwordModuleClearSearchResults(handle)
        }

        let progressContext = progress.map {
            Unmanaged.passRetained(
                SearchProgressHandler($0)
            ).toOpaque()
        }

        defer {
            if let progressContext {
                Unmanaged<SearchProgressHandler>
                    .fromOpaque(progressContext)
                    .release()
            }
        }

        let count = normalizedQuery.withCString { queryPointer in
            normalizedScope.withCString { scopePointer in
                SwordModuleSearchCount(
                    handle,
                    queryPointer,
                    scopePointer,
                    type.bridgeValue,
                    type.bridgeAttributeType,
                    caseSensitive ? 1 : 0,
                    progress == nil ? nil : reportSearchProgress,
                    progressContext
                )
            }
        }

        var results: [SwordSearchResult] = []
        results.reserveCapacity(count)

        for index in 0..<count {
            guard let pointer = SwordModuleSearchResultReference(
                handle,
                index
            ) else {
                continue
            }

            let value = String(cString: pointer)

            guard !value.isEmpty else {
                continue
            }

            let verse = try verse(SwordReference(value))

            results.append(
                SwordSearchResult(
                    reference: verse.reference,
                    moduleName: verse.moduleName,
                    text: verse.text,
                    score: Int(
                        SwordModuleSearchResultScore(
                            handle,
                            index
                        )
                    )
                )
            )
        }

        return results
    }

    /// Searches a Bible module with cooperative task cancellation.
    ///
    /// Cancelling the calling task signals SWORD to terminate its active
    /// search and causes this method to throw `CancellationError`.
    /// The optional progress callback receives SWORD's completion percentage.
    /// As a nonisolated async method, native search runs on Swift's generic
    /// executor rather than the caller's actor executor.
    public func searchAsync(
        _ query: String,
        type: SwordSearchType = .phrase,
        caseSensitive: Bool = true,
        scope: String? = nil,
        progress: (@Sendable (Int) -> Void)? = nil
    ) async throws -> [SwordSearchResult] {
        let nativeHandle = SendableSwordModuleHandle(
            value: handle
        )

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()

            let results = try search(
                query,
                type: type,
                caseSensitive: caseSensitive,
                scope: scope,
                progress: progress
            )

            try Task.checkCancellation()
            return results
        } onCancel: {
            SwordModuleTerminateSearch(nativeHandle.value)
        }
    }

    /// Streams search results in SWORD result order.
    ///
    /// Cancelling iteration cancels the producing task and signals an active
    /// native search to terminate. SWORD produces its result list as a batch,
    /// after which this sequence yields each immutable result cooperatively.
    public func searchStream(
        _ query: String,
        type: SwordSearchType = .phrase,
        caseSensitive: Bool = true,
        scope: String? = nil,
        progress: (@Sendable (Int) -> Void)? = nil
    ) -> AsyncThrowingStream<SwordSearchResult, any Error> {
        AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    let results = try await searchAsync(
                        query,
                        type: type,
                        caseSensitive: caseSensitive,
                        scope: scope,
                        progress: progress
                    )

                    for result in results {
                        try Task.checkCancellation()
                        continuation.yield(result)
                        await Task<Never, Never>.yield()
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                producer.cancel()
            }
        }
    }
    
    /// Retrieves a complete chapter from a Bible module.
    public func chapter(
        _ reference: SwordChapterReference
    ) throws -> SwordChapter {
        try accessLock.withLock {
            try chapterWithoutLock(reference)
        }
    }

    private func chapterWithoutLock(
        _ reference: SwordChapterReference
    ) throws -> SwordChapter {
        guard category == .bible else {
            throw SwordError.unsupportedModuleType
        }

        let firstVerse = try verse(reference.firstVerse)

        var verses = [firstVerse]

        let chapterPrefix = "\(reference.book) \(reference.chapterNumber):"

        while true {
            let previousReference = currentReference

            advance()

            guard let nextVerse = currentVerse else {
                break
            }

            guard nextVerse.reference != previousReference else {
                break
            }

            guard nextVerse.reference.value.hasPrefix(chapterPrefix) else {
                break
            }

            verses.append(nextVerse)
        }

        return SwordChapter(
            reference: reference,
            moduleName: name,
            verses: verses
        )
    }

    /// Retrieves a complete chapter using a textual reference.
    public func chapter(
        _ reference: String
    ) throws -> SwordChapter {
        try chapter(
            SwordChapterReference(reference)
        )
    }
    
    /// Retrieves a verse from this module.
    ///
    /// - Parameter reference: A Scripture reference such as
    ///   `"John 3:16"`.
    /// - Returns: The verse and its SWORD-normalized reference.
    /// - Throws: A ``SwordError`` when the reference is invalid,
    ///   unavailable, or incompatible with the module.
    public func verse(
        _ reference: SwordReference
    ) throws -> SwordVerse {
        try accessLock.withLock {
            try verseWithoutLock(reference)
        }
    }

    private func verseWithoutLock(
        _ reference: SwordReference
    ) throws -> SwordVerse {
        guard category == .bible else {
            throw SwordError.unsupportedModuleType
        }
        
        let status = reference.value.withCString {
            SwordModuleSetKey(handle, $0)
        }
        
        guard status == 0 else {
            throw SwordError.referenceNotFound(reference.value)
        }
        
        let resolvedValue = SwordLibrary.string(
            from: SwordModuleCurrentKey(handle)
        )
        
        guard !resolvedValue.isEmpty else {
            throw SwordError.missingResolvedReference
        }
        
        let resolvedReference = try SwordReference(resolvedValue)
        
        let text = SwordLibrary.string(
            from: SwordModuleRenderText(handle)
        )
        
        guard !text.isEmpty else {
            throw SwordError.emptyRenderedText(
                reference: resolvedReference.value
            )
        }

        let lexicalAttributes = (0..<SwordModuleWordAttributeCount(handle)).map {
            SwordLexicalAttribute(
                text: SwordLibrary.string(
                    from: SwordModuleWordAttributeText(handle, $0)
                ),
                lemma: SwordLibrary.string(
                    from: SwordModuleWordAttributeLemma(handle, $0)
                ),
                morphology: SwordLibrary.string(
                    from: SwordModuleWordAttributeMorphology(handle, $0)
                ).nilIfEmpty
            )
        }

        let footnotes = (0..<SwordModuleFootnoteCount(handle)).map {
            SwordFootnote(
                identifier: SwordLibrary.string(
                    from: SwordModuleFootnoteIdentifier(handle, $0)
                ),
                body: SwordLibrary.string(
                    from: SwordModuleFootnoteBody(handle, $0)
                ),
                type: SwordLibrary.string(
                    from: SwordModuleFootnoteType(handle, $0)
                ).nilIfEmpty,
                referenceList: SwordLibrary.string(
                    from: SwordModuleFootnoteReferenceList(handle, $0)
                ).nilIfEmpty
            )
        }

        let crossReferences: [SwordCrossReference] = footnotes.compactMap {
            (footnote: SwordFootnote) -> SwordCrossReference? in
            guard
                footnote.type == "crossReference",
                let expression = footnote.referenceList,
                let parsedReferences = try? references(in: expression),
                !parsedReferences.isEmpty
            else {
                return nil
            }

            return SwordCrossReference(
                footnoteIdentifier: footnote.identifier,
                references: parsedReferences.references
            )
        }
        let headings = (0..<SwordModuleHeadingCount(handle)).map { index in
            let position = SwordLibrary.string(
                from: SwordModuleHeadingPosition(handle, index)
            )
            let headingPosition: SwordHeading.Position = switch position {
            case "Preverse": .preVerse
            case "Interverse": .interVerse
            default: .other(position)
            }

            return SwordHeading(
                identifier: SwordLibrary.string(
                    from: SwordModuleHeadingIdentifier(handle, index)
                ),
                body: SwordLibrary.string(
                    from: SwordModuleHeadingBody(handle, index)
                ),
                position: headingPosition
            )
        }
        
        return SwordVerse(
            reference: resolvedReference,
            moduleName: name,
            text: text,
            lexicalAttributes: lexicalAttributes,
            footnotes: footnotes,
            crossReferences: crossReferences,
            headings: headings
        )
    }
    
    /// Retrieves a verse using a textual reference.
    ///
    /// This convenience overload creates a ``SwordReference`` before
    /// performing the lookup.
    ///
    /// - Parameter reference: A reference such as `"John 3:16"`.
    /// - Returns: The retrieved verse.
    /// - Throws: A ``SwordError`` when the reference cannot be retrieved.
    public func verse(
        _ reference: String
    ) throws -> SwordVerse {
        try verse(SwordReference(reference))
    }

    /// Renders a Bible entry as SWORD-generated XHTML.
    public func html(_ reference: String) throws -> String {
        try accessLock.withLock {
            try htmlWithoutLock(reference)
        }
    }

    private func htmlWithoutLock(_ reference: String) throws -> String {
        _ = try verse(reference)

        let html = SwordLibrary.string(
            from: SwordModuleRenderHTML(handle)
        )

        guard !html.isEmpty else {
            throw SwordError.emptyRenderedText(reference: reference)
        }

        return html
    }

    /// Renders a Bible entry as a Swift-native attributed string.
    public func attributedString(
        _ reference: String
    ) throws -> AttributedString {
        try accessLock.withLock {
            try attributedStringWithoutLock(reference)
        }
    }

    private func attributedStringWithoutLock(
        _ reference: String
    ) throws -> AttributedString {
        let verse = try verse(reference)
        let html = try html(reference)

        let attributedText: AttributedString

        #if canImport(AppKit) || canImport(UIKit)
        if let data = html.data(using: .utf8),
           let value = try? NSAttributedString(
               data: data,
               options: [
                   .documentType: NSAttributedString.DocumentType.html,
                   .characterEncoding: String.Encoding.utf8.rawValue
               ],
               documentAttributes: nil
           ) {
            attributedText = AttributedString(value)
        } else {
            attributedText = AttributedString(verse.text)
        }
        #else
        attributedText = AttributedString(verse.text)
        #endif

        return attributedText.addingLexicalAttributes(
            verse.lexicalAttributes
        )
    }
    
    deinit {
        SwordModuleDestroy(handle)
    }
    
    /// Returns whether two values represent the same live module instance.
    public static func == (
        lhs: SwordModule,
        rhs: SwordModule
    ) -> Bool {
        lhs === rhs
    }
    
    /// Hashes the module's object identity.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    /// Retrieves a sequential passage beginning at the supplied reference.
    ///
    /// - Parameters:
    ///   - reference: The first verse in the passage.
    ///   - verseCount: The number of verses to retrieve.
    /// - Returns: A sequential collection of verses.
    /// - Throws: A ``SwordError`` when the request cannot be completed.
    public func passage(
        startingAt reference: SwordReference,
        verseCount: Int
    ) throws -> SwordPassage {
        try accessLock.withLock {
            try passageWithoutLock(
                startingAt: reference,
                verseCount: verseCount
            )
        }
    }

    private func passageWithoutLock(
        startingAt reference: SwordReference,
        verseCount: Int
    ) throws -> SwordPassage {
        guard category == .bible else {
            throw SwordError.unsupportedModuleType
        }
        
        guard verseCount > 0 else {
            throw SwordError.invalidVerseCount(verseCount)
        }
        
        let firstVerse = try verse(reference)
        
        var verses = [firstVerse]
        verses.reserveCapacity(verseCount)
        
        while verses.count < verseCount {
            let previousReference = currentReference
            
            advance()
            
            guard let nextVerse = currentVerse else {
                break
            }
            
            guard nextVerse.reference != previousReference else {
                break
            }
            
            verses.append(nextVerse)
        }
        
        return SwordPassage(
            reference: firstVerse.reference,
            moduleName: name,
            verses: verses
        )
    }
    
    /// Retrieves a sequential passage using a textual starting reference.
    public func passage(
        startingAt reference: String,
        verseCount: Int
    ) throws -> SwordPassage {
        try passage(
            startingAt: SwordReference(reference),
            verseCount: verseCount
        )
    }
    /// Retrieves a same-chapter passage using a textual verse range.
    ///
    /// Supported examples include:
    ///
    /// ```swift
    /// try module.passage("John 3:16-21")
    /// try module.passage("1 Corinthians 13:4-8")
    /// ```
    ///
    /// Cross-chapter ranges are not yet supported.
    public func passage(
        _ range: String
    ) throws -> SwordPassage {
        let parsedRange = try SwordPassageRange(range)

        return try passage(
            startingAt: parsedRange.start,
            verseCount: parsedRange.verseCount
        )
    }
}

// SWORD permits its termination flag to be set from a cancellation handler.
private struct SendableSwordModuleHandle: @unchecked Sendable {
    let value: OpaquePointer
}

private final class SearchProgressHandler: @unchecked Sendable {
    let callback: @Sendable (Int) -> Void

    init(_ callback: @escaping @Sendable (Int) -> Void) {
        self.callback = callback
    }
}

private let reportSearchProgress:
    @convention(c) (Int32, UnsafeMutableRawPointer?) -> Void = {
        percentage,
        userData in
        guard let userData else {
            return
        }

        let handler = Unmanaged<SearchProgressHandler>
            .fromOpaque(userData)
            .takeUnretainedValue()

        handler.callback(Int(percentage))
    }

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension AttributedString {
    func addingLexicalAttributes(
        _ attributes: [SwordLexicalAttribute]
    ) -> AttributedString {
        var result = self
        var searchStart = result.startIndex

        for attribute in attributes {
            guard
                !attribute.text.isEmpty,
                let range = result[searchStart...].range(of: attribute.text)
            else {
                continue
            }

            if let strongsNumber = attribute.strongsNumber {
                result[range][SwordStrongsNumberAttribute.self] = strongsNumber
            }

            if let morphology = attribute.morphology {
                result[range][SwordMorphologyAttribute.self] = morphology
            }

            searchStart = range.upperBound
        }

        return result
    }
}

public extension SwordModule {
    /// A broad classification of a SWORD module's contents.
    enum Category: Hashable, Sendable {
        /// A biblical text or translation.
        case bible

        /// A biblical commentary.
        case commentary

        /// A dictionary or lexicon.
        case dictionary

        /// A general-purpose book.
        case generalBook

        /// A calendar-keyed daily devotional.
        case devotional

        /// A module type not recognized by SwordKit.
        case other(String)

        internal init(swordType: String) {
            switch swordType {
            case "Biblical Texts":
                self = .bible

            case "Commentaries":
                self = .commentary

            case "Lexicons / Dictionaries":
                self = .dictionary

            case "Generic Books":
                self = .generalBook

            case "Daily Devotional", "Daily Devotionals":
                self = .devotional

            default:
                self = .other(swordType)
            }
        }

        /// Whether modules in this category expose navigable keyed entries.
        public var supportsKeyedEntries: Bool {
            switch self {
            case .dictionary, .generalBook, .devotional:
                true
            case .bible, .commentary, .other:
                false
            }
        }
    }
}

extension SwordModule {
    internal func advance() {
        accessLock.withLock {
            SwordModuleIncrement(handle)
        }
    }

    internal func retreat() {
        accessLock.withLock {
            SwordModuleDecrement(handle)
        }
    }

    internal var currentReference: SwordReference? {
        accessLock.withLock {
            let text = SwordLibrary.string(
                from: SwordModuleCurrentKey(handle)
            )

            return try? SwordReference(text)
        }
    }

    internal var currentText: String {
        accessLock.withLock {
            SwordLibrary.string(
                from: SwordModuleRenderText(handle)
            )
        }
    }
    
    internal var currentVerse: SwordVerse? {
        accessLock.withLock {
            guard let reference = currentReference else {
                return nil
            }

            let text = currentText

            guard !text.isEmpty else {
                return nil
            }

            return SwordVerse(
                reference: reference,
                moduleName: name,
                text: text
            )
        }
    }
}
