import CSwordBridge
import Foundation

/// Performs explicit SWORD module installation operations.
public struct SwordModuleInstaller: Sendable {
    /// The destinations and repositories used by this installer.
    public let configuration: SwordInstallerConfiguration

    /// Creates an installer with explicit configuration.
    public init(configuration: SwordInstallerConfiguration) {
        self.configuration = configuration
    }

    /// Reads the most recently refreshed catalog for a configured repository.
    public func cachedCatalog(
        for repository: SwordModuleRepository
    ) throws -> SwordRemoteModuleCatalog {
        let shadow = configuration.privateDirectory.appending(
            path: repository.identifier,
            directoryHint: .isDirectory
        )
        let catalog = try SwordModuleCatalog(directory: shadow)
        return SwordRemoteModuleCatalog(
            repository: repository,
            modules: catalog.modules
        )
    }

    /// Refreshes and returns a remote repository catalog.
    ///
    /// Apps must present SWORD's remote-access warning before passing `true`.
    /// Progress callbacks can arrive on a background thread.
    public func refreshCatalog(
        for repository: SwordModuleRepository,
        acknowledgingRemoteAccessRisks: Bool,
        progress: @escaping @Sendable (SwordTransferProgress) -> Void = { _ in }
    ) async throws -> SwordRemoteModuleCatalog {
        guard acknowledgingRemoteAccessRisks else {
            throw SwordError.remoteAccessNotAuthorized
        }

        if repository.transport == .https {
            return try await SwordHTTPSRepositoryTransport.refreshCatalog(
                repository: repository,
                configuration: configuration,
                progress: progress
            )
        }

        let transfer = Task.detached {
            try Task.checkCancellation()
            try configuration.createInstallerDirectories()
            let status = withTransferProgress(progress) { callback, context in
                repository.withBridgeValues { values in
                    SwordRefreshRemoteCatalog(
                        self.configuration.privateDirectory.path,
                        values.transport,
                        values.host,
                        values.directory,
                        values.identifier,
                        values.name,
                        callback,
                        context
                    )
                }
            }

            try Task.checkCancellation()

            guard status == 0 else {
                throw SwordError.remoteCatalogRefreshFailed(
                    repository: repository.identifier,
                    status: status
                )
            }
            return try self.cachedCatalog(for: repository)
        }
        return try await withTaskCancellationHandler {
            try await transfer.value
        } onCancel: {
            transfer.cancel()
        }
    }

    /// Installs one module from a previously refreshed remote repository.
    ///
    /// Apps must present SWORD's remote-access warning before passing `true`.
    /// Progress callbacks can arrive on a background thread.
    public func install(
        moduleNamed moduleName: String,
        from repository: SwordModuleRepository,
        acknowledgingRemoteAccessRisks: Bool,
        progress: @escaping @Sendable (SwordTransferProgress) -> Void = { _ in }
    ) async throws {
        guard acknowledgingRemoteAccessRisks else {
            throw SwordError.remoteAccessNotAuthorized
        }
        guard try cachedCatalog(for: repository).modules.contains(
            where: { $0.name == moduleName }
        ) else {
            throw SwordError.moduleNotFound(moduleName)
        }

        if repository.transport == .https {
            return try await SwordHTTPSRepositoryTransport.install(
                moduleName: moduleName,
                repository: repository,
                installer: self,
                progress: progress
            )
        }

        let transfer = Task.detached {
            try Task.checkCancellation()
            try configuration.createInstallerDirectories()
            let status = withTransferProgress(progress) { callback, context in
                repository.withBridgeValues { values in
                    SwordInstallRemoteModule(
                        self.configuration.privateDirectory.path,
                        self.configuration.destinationDirectory.path,
                        values.transport,
                        values.host,
                        values.directory,
                        values.identifier,
                        values.name,
                        moduleName,
                        callback,
                        context
                    )
                }
            }

            try Task.checkCancellation()

            guard status == 0 else {
                throw SwordError.remoteModuleInstallationFailed(
                    module: moduleName,
                    repository: repository.identifier,
                    status: status
                )
            }
        }
        try await withTaskCancellationHandler {
            try await transfer.value
        } onCancel: {
            transfer.cancel()
        }
    }

    /// Installs one module from a local repository catalog.
    public func install(
        moduleNamed moduleName: String,
        from catalog: SwordModuleCatalog
    ) throws {
        guard catalog.modules.contains(where: { $0.name == moduleName }) else {
            throw SwordError.moduleNotFound(moduleName)
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: configuration.destinationDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: configuration.destinationDirectory.appending(
                path: "mods.d",
                directoryHint: .isDirectory
            ),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: configuration.privateDirectory,
            withIntermediateDirectories: true
        )

        let status = configuration.privateDirectory.path.withCString {
            privatePath in
            configuration.destinationDirectory.path.withCString {
                destinationPath in
                catalog.directory.path.withCString { sourcePath in
                    moduleName.withCString { name in
                        SwordInstallLocalModule(
                            privatePath,
                            destinationPath,
                            sourcePath,
                            name
                        )
                    }
                }
            }
        }

        guard status == 0 else {
            throw SwordError.moduleInstallationFailed(
                module: moduleName,
                status: status
            )
        }
    }

    /// Removes one module from the configured destination.
    public func remove(moduleNamed moduleName: String) throws {
        let catalog = try SwordModuleCatalog(
            directory: configuration.destinationDirectory
        )

        guard catalog.modules.contains(where: { $0.name == moduleName }) else {
            throw SwordError.moduleNotFound(moduleName)
        }

        let status = configuration.privateDirectory.path.withCString {
            privatePath in
            configuration.destinationDirectory.path.withCString {
                destinationPath in
                moduleName.withCString { name in
                    SwordRemoveModule(privatePath, destinationPath, name)
                }
            }
        }

        guard status == 0 else {
            throw SwordError.moduleRemovalFailed(
                module: moduleName,
                status: status
            )
        }
    }
}

private final class TransferProgressBox: @unchecked Sendable {
    let callback: @Sendable (SwordTransferProgress) -> Void

    init(callback: @escaping @Sendable (SwordTransferProgress) -> Void) {
        self.callback = callback
    }
}

private func withTransferProgress<Result>(
    _ progress: @escaping @Sendable (SwordTransferProgress) -> Void,
    operation: (
        SwordTransferProgressCallback?,
        UnsafeMutableRawPointer?
    ) -> Result
) -> Result {
    let box = Unmanaged.passRetained(TransferProgressBox(callback: progress))
    defer { box.release() }

    return operation(
        { message, totalBytes, completedBytes, context in
            guard let context else { return 0 }
            let box = Unmanaged<TransferProgressBox>
                .fromOpaque(context)
                .takeUnretainedValue()
            box.callback(
                SwordTransferProgress(
                    message: message.map(String.init(cString:)) ?? "",
                    totalBytes: UInt64(totalBytes),
                    completedBytes: UInt64(completedBytes)
                )
            )
            return Task.isCancelled ? 1 : 0
        },
        box.toOpaque()
    )
}

extension SwordInstallerConfiguration {
    func createInstallerDirectories() throws {
        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: destinationDirectory.appending(
                path: "mods.d",
                directoryHint: .isDirectory
            ),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: privateDirectory,
            withIntermediateDirectories: true
        )
    }
}

private extension SwordModuleRepository {
    struct BridgeValues {
        let transport: UnsafePointer<CChar>
        let host: UnsafePointer<CChar>
        let directory: UnsafePointer<CChar>
        let identifier: UnsafePointer<CChar>
        let name: UnsafePointer<CChar>
    }

    func withBridgeValues<Result>(
        _ body: (BridgeValues) -> Result
    ) -> Result {
        transport.rawValue.withCString { transport in
            host.withCString { host in
                directory.withCString { directory in
                    identifier.withCString { identifier in
                        name.withCString { name in
                            body(
                                BridgeValues(
                                    transport: transport,
                                    host: host,
                                    directory: directory,
                                    identifier: identifier,
                                    name: name
                                )
                            )
                        }
                    }
                }
            }
        }
    }
}
