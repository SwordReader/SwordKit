import Foundation

/// Immutable configuration for module installation operations.
public struct SwordInstallerConfiguration: Hashable, Sendable {
    /// The SWORD library root that receives installed modules.
    public let destinationDirectory: URL

    /// Private storage for installer configuration and repository catalogs.
    public let privateDirectory: URL

    /// Remote repositories available to an explicitly created installer.
    public let repositories: [SwordModuleRepository]

    /// Creates validated installer configuration using local directories.
    public init(
        destinationDirectory: URL,
        privateDirectory: URL,
        repositories: [SwordModuleRepository] = []
    ) throws {
        guard destinationDirectory.isFileURL else {
            throw SwordError.invalidInstallDestination(
                destinationDirectory.absoluteString
            )
        }

        guard privateDirectory.isFileURL else {
            throw SwordError.invalidInstallerDirectory(
                privateDirectory.absoluteString
            )
        }

        self.destinationDirectory = destinationDirectory.standardizedFileURL
        self.privateDirectory = privateDirectory.standardizedFileURL
        self.repositories = repositories
    }

    /// Creates configuration using a shared app-owned module location.
    public init(
        location: SwordModuleLocation,
        repositories: [SwordModuleRepository] = []
    ) {
        self.destinationDirectory = location.modulesDirectory
        self.privateDirectory = location.installerDirectory
        self.repositories = repositories
    }
}

/// A remote SWORD module repository.
public struct SwordModuleRepository: Hashable, Sendable {
    /// A transport supported by the SWORD installer.
    public enum Transport: String, Hashable, Sendable {
        /// Unencrypted HTTP.
        case http = "HTTP"
        /// TLS-protected HTTP.
        case https = "HTTPS"
        /// File Transfer Protocol.
        case ftp = "FTP"
    }

    /// The repository's stable identifier.
    public let identifier: String
    /// The repository's user-visible name.
    public let name: String
    /// The network transport used to reach the repository.
    public let transport: Transport
    /// The repository server host name.
    public let host: String
    /// The catalog path on the server.
    public let directory: String

    /// Creates a validated remote repository description.
    public init(
        identifier: String,
        name: String,
        transport: Transport,
        host: String,
        directory: String
    ) throws {
        let identifier = identifier.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = directory.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            !identifier.isEmpty,
            identifier != ".",
            identifier != "..",
            !identifier.contains("/"),
            !identifier.contains("\\"),
            !name.isEmpty,
            !host.isEmpty
        else {
            throw SwordError.invalidModuleRepository(identifier)
        }

        self.identifier = identifier
        self.name = name
        self.transport = transport
        self.host = host
        self.directory = directory
    }
}
