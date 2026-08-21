import Foundation

/// A cached snapshot of modules advertised by a remote SWORD repository.
public struct SwordRemoteModuleCatalog: Hashable, Sendable {
    /// The repository that supplied this catalog.
    public let repository: SwordModuleRepository
    /// Module metadata cached during the latest successful refresh.
    public let modules: [SwordModuleCatalogEntry]
}

/// Progress reported while SWORD transfers remote repository content.
public struct SwordTransferProgress: Hashable, Sendable {
    /// The status message supplied by SWORD, when available.
    public let message: String
    /// The expected transfer size in bytes, when known.
    public let totalBytes: UInt64
    /// The number of bytes transferred so far.
    public let completedBytes: UInt64

    /// A normalized completion value when SWORD knows the total size.
    public var fractionCompleted: Double? {
        guard totalBytes > 0 else { return nil }
        return min(Double(completedBytes) / Double(totalBytes), 1)
    }
}
