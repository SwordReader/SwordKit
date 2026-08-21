/// A book in a Bible module's native versification system.
public struct SwordBook: Hashable, Sendable, Identifiable {
    /// The testament containing the book.
    public enum Testament: Hashable, Sendable {
        /// A book in the Old Testament portion of the versification.
        case old
        /// A book in the New Testament portion of the versification.
        case new
    }

    /// The stable OSIS identifier, such as `"Gen"` or `"John"`.
    public let id: String

    /// The long display name supplied by SWORD.
    public let name: String

    /// The stable OSIS identifier.
    public var osisName: String { id }

    /// SWORD's preferred abbreviation for the book.
    public let preferredAbbreviation: String

    /// The number of chapters in this versification.
    public let chapterCount: Int

    /// The testament containing the book.
    public let testament: Testament

    /// Creates immutable Bible-book metadata.
    public init(
        osisName: String,
        name: String,
        preferredAbbreviation: String,
        chapterCount: Int,
        testament: Testament
    ) {
        self.id = osisName
        self.name = name
        self.preferredAbbreviation = preferredAbbreviation
        self.chapterCount = chapterCount
        self.testament = testament
    }
}
