import CSwordBridge
import Foundation

/// Provides access to the SWORD engine and its installed modules.
public final class SwordLibrary: @unchecked Sendable {
    /// The version of the SwordKit native bridge.
    public static let bridgeVersion = string(
        from: SwordBridgeVersion()
    )

    /// The version of the linked SWORD engine.
    public static let engineVersion = string(
        from: SwordEngineVersion()
    )

    /// The modules available through this SWORD installation.
    public var modules: [SwordModule] {
        accessLock.withLock { storedModules }
    }

    private let accessLock = SwordEngineAccess.lock
    private var storedModules: [SwordModule]
    private var storage: SwordManagerStorage?
    private let directory: URL?

    /// Creates a library using the modules installed in the standard
    /// SWORD module locations.
    public init() {
        self.directory = nil
        self.storage = nil
        self.storedModules = []
        refresh()
    }

    /// Creates a library rooted at an explicit local SWORD directory.
    public init(directory: URL) throws {
        guard directory.isFileURL else {
            throw SwordError.moduleCatalogNotFound(directory.absoluteString)
        }

        self.directory = directory.standardizedFileURL
        self.storage = nil
        self.storedModules = []
        refresh()
    }

    /// Creates a library using an app-owned module location.
    public convenience init(location: SwordModuleLocation) throws {
        try self.init(directory: location.modulesDirectory)
    }

    /// Reloads installed modules into a new library snapshot.
    public func refresh() {
        accessLock.withLock {
            let storage = SwordManagerStorage(directory: directory?.path)

            guard let storage else {
                self.storage = nil
                self.storedModules = []
                return
            }

            self.storage = storage

            let count = SwordManagerModuleCount(storage.handle)

            storedModules = (0..<count).compactMap { index in
                guard let handle = SwordManagerOpenModule(
                    storage.handle,
                    index
                ) else {
                    return nil
                }

                return SwordModule(
                    storage: storage,
                    handle: handle
                )
            }
        }
    }

    /// Returns the installed module with the specified name.
    ///
    /// Module-name matching is case-insensitive.
    public func module(named name: String) -> SwordModule? {
        accessLock.withLock {
            storedModules.first {
                $0.name.lowercased() == name.lowercased()
            }
        }
    }

    /// Returns the installed module with the specified name.
    ///
    /// Module-name matching is case-insensitive.
    public subscript(name: String) -> SwordModule? {
        module(named: name)
    }

    /// Returns installed modules matching optional category and language.
    public func modules(
        category: SwordModule.Category? = nil,
        language: String? = nil
    ) -> [SwordModule] {
        accessLock.withLock {
            storedModules.filter { module in
                let matchesCategory = category.map {
                    module.category == $0
                } ?? true
                let matchesLanguage = language.map {
                    module.language.caseInsensitiveCompare($0) == .orderedSame
                } ?? true

                return matchesCategory && matchesLanguage
            }
        }
    }

    /// Retrieves the same Scripture range from multiple Bible modules.
    ///
    /// Passages are returned in the same order as the supplied module names.
    public func parallelPassage(
        _ reference: String,
        modules moduleNames: [String]
    ) throws -> SwordParallelPassage {
        let range = try SwordPassageRange(reference)

        let passages = try moduleNames.map { moduleName in
            guard let module = module(named: moduleName) else {
                throw SwordError.moduleNotFound(moduleName)
            }

            return try module.passage(range.value)
        }

        return SwordParallelPassage(
            reference: range,
            passages: passages
        )
    }

    /// Retrieves a parallel passage cooperatively in caller-supplied order.
    ///
    /// The operation checks for task cancellation between modules. Each live
    /// module serializes its native SWORD access.
    public func parallelPassageAsync(
        _ reference: String,
        modules moduleNames: [String]
    ) async throws -> SwordParallelPassage {
        let range = try SwordPassageRange(reference)
        var passages: [SwordPassage] = []
        passages.reserveCapacity(moduleNames.count)

        for moduleName in moduleNames {
            try Task.checkCancellation()

            guard let module = module(named: moduleName) else {
                throw SwordError.moduleNotFound(moduleName)
            }

            passages.append(try module.passage(range.value))
            await Task<Never, Never>.yield()
        }

        try Task.checkCancellation()
        return SwordParallelPassage(
            reference: range,
            passages: passages
        )
    }

    internal static func string(
        from pointer: UnsafePointer<CChar>?
    ) -> String {
        guard let pointer else {
            return ""
        }

        return String(cString: pointer)
    }
}
