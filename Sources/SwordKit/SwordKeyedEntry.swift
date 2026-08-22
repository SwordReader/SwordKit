import CSwordBridge
import Foundation

/// A rendered entry from a dictionary, general book, or daily devotional.
public struct SwordKeyedEntry: Hashable, Sendable {
    /// The module-native key used to locate the entry.
    public let key: String

    /// The entry rendered as plain text by SWORD.
    public let text: String

    /// The entry rendered as SWORD-generated XHTML.
    public let html: String
}

public extension SwordModule {
    /// Returns the module-native keys in reading order.
    ///
    /// This API supports dictionaries, general books, and daily devotionals.
    /// Bible and commentary modules continue to use Scripture references.
    func keyedEntryKeys() throws -> [String] {
        try accessLock.withLock {
            guard category.supportsKeyedEntries else {
                throw SwordError.unsupportedModuleType
            }

            let count = SwordModuleEntryKeyCount(handle)
            defer { SwordModuleClearEntryKeys(handle) }

            return (0..<count).compactMap { index in
                let key = SwordLibrary.string(
                    from: SwordModuleEntryKey(handle, index)
                )
                return key.isEmpty ? nil : key
            }
        }
    }

    /// Renders the entry at a module-native key.
    func keyedEntry(for key: String) throws -> SwordKeyedEntry {
        try accessLock.withLock {
            guard category.supportsKeyedEntries else {
                throw SwordError.unsupportedModuleType
            }

            let requestedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !requestedKey.isEmpty else {
                throw SwordError.emptyReference
            }

            let status = requestedKey.withCString {
                SwordModuleSetKey(handle, $0)
            }
            guard status == 0 else {
                throw SwordError.referenceNotFound(requestedKey)
            }

            let resolvedKey = SwordLibrary.string(
                from: SwordModuleCurrentKey(handle)
            )
            guard !resolvedKey.isEmpty else {
                throw SwordError.missingResolvedReference
            }

            return SwordKeyedEntry(
                key: resolvedKey,
                text: SwordLibrary.string(from: SwordModuleRenderText(handle)),
                html: SwordLibrary.string(from: SwordModuleRenderHTML(handle))
            )
        }
    }
}
