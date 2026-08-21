import CSwordBridge
import Foundation

enum SwordHTTPSRepositoryTransport {
    static func refreshCatalog(
        repository: SwordModuleRepository,
        configuration: SwordInstallerConfiguration,
        progress: @escaping @Sendable (SwordTransferProgress) -> Void
    ) async throws -> SwordRemoteModuleCatalog {
        try configuration.createInstallerDirectories()
        let workspace = try temporaryWorkspace(in: configuration)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let archive = workspace.appending(path: "mods.d.tar.gz")
        try await download(
            try repository.catalogURL(),
            to: archive,
            message: "Downloading catalog",
            progress: progress
        )

        let extracted = workspace.appending(
            path: "catalog",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: extracted,
            withIntermediateDirectories: true
        )
        try extractCatalogArchive(archive, to: extracted)

        let stagedCatalog = try SwordModuleCatalog(directory: extracted)
        let destination = configuration.privateDirectory.appending(
            path: repository.identifier,
            directoryHint: .isDirectory
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(
                destination,
                withItemAt: extracted
            )
        } else {
            try FileManager.default.moveItem(at: extracted, to: destination)
        }

        return SwordRemoteModuleCatalog(
            repository: repository,
            modules: stagedCatalog.modules
        )
    }

    static func install(
        moduleName: String,
        repository: SwordModuleRepository,
        installer: SwordModuleInstaller,
        progress: @escaping @Sendable (SwordTransferProgress) -> Void
    ) async throws {
        let configuration = installer.configuration
        try configuration.createInstallerDirectories()
        let workspace = try temporaryWorkspace(in: configuration)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let archive = workspace.appending(path: moduleName + ".zip")
        try await download(
            try repository.moduleArchiveURL(named: moduleName),
            to: archive,
            message: "Downloading \(moduleName)",
            progress: progress
        )

        let extracted = workspace.appending(
            path: "module",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: extracted,
            withIntermediateDirectories: true
        )
        try extractModuleArchive(archive, to: extracted)

        let catalog = try SwordModuleCatalog(directory: extracted)
        guard catalog.modules.contains(where: { $0.name == moduleName }) else {
            throw SwordError.moduleNotFound(moduleName)
        }
        try installer.install(moduleNamed: moduleName, from: catalog)
    }

    private static func temporaryWorkspace(
        in configuration: SwordInstallerConfiguration
    ) throws -> URL {
        let downloads = configuration.privateDirectory.appending(
            path: "Downloads",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: downloads,
            withIntermediateDirectories: true
        )
        let workspace = downloads.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: workspace,
            withIntermediateDirectories: true
        )
        return workspace
    }

    static func extractCatalogArchive(
        _ archive: URL,
        to destination: URL
    ) throws {
        guard SwordExtractRemoteCatalogArchive(
            archive.path,
            destination.path
        ) == 0 else {
            throw SwordError.invalidRemoteArchive(archive.lastPathComponent)
        }
    }

    static func extractModuleArchive(
        _ archive: URL,
        to destination: URL
    ) throws {
        guard SwordExtractRemoteModuleArchive(
            archive.path,
            destination.path
        ) == 0 else {
            throw SwordError.invalidRemoteArchive(archive.lastPathComponent)
        }
    }

    private static func download(
        _ url: URL,
        to destination: URL,
        message: String,
        progress: @escaping @Sendable (SwordTransferProgress) -> Void
    ) async throws {
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        guard
            let response = response as? HTTPURLResponse,
            (200..<300).contains(response.statusCode)
        else {
            throw SwordError.invalidRemoteRepositoryURL(url.absoluteString)
        }

        FileManager.default.createFile(
            atPath: destination.path,
            contents: nil
        )
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }

        let totalBytes = response.expectedContentLength > 0
            ? UInt64(response.expectedContentLength)
            : 0
        var completedBytes: UInt64 = 0
        var buffer: [UInt8] = []
        buffer.reserveCapacity(64 * 1024)

        for try await byte in bytes {
            try Task.checkCancellation()
            buffer.append(byte)
            if buffer.count == buffer.capacity {
                try handle.write(contentsOf: Data(buffer))
                completedBytes += UInt64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                progress(
                    SwordTransferProgress(
                        message: message,
                        totalBytes: totalBytes,
                        completedBytes: completedBytes
                    )
                )
            }
        }

        if !buffer.isEmpty {
            try handle.write(contentsOf: Data(buffer))
            completedBytes += UInt64(buffer.count)
        }
        progress(
            SwordTransferProgress(
                message: message,
                totalBytes: totalBytes,
                completedBytes: completedBytes
            )
        )
    }
}
