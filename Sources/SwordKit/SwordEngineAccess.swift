import Foundation

/// Serializes access to SWORD's process-wide native state.
///
/// SWORD shares parsing, locale, and rendering infrastructure between module
/// instances. Per-module locks alone cannot prevent concurrent native access.
internal enum SwordEngineAccess {
    static let lock = NSRecursiveLock()
}
