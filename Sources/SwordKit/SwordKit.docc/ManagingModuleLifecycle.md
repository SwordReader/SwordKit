# Managing the Module Lifecycle

Inspect, install, remove, and refresh SWORD modules without hiding storage or
network policy inside the framework.

## Separate catalogs from live libraries

``SwordModuleCatalog`` is an immutable description of modules available in a
local SWORD repository. ``SwordLibrary`` owns live modules opened from an
installed SWORD root. Reading a catalog does not load its modules for use:

```swift
let sourceCatalog = try SwordModuleCatalog(directory: sourceURL)
let installedLibrary = try SwordLibrary(location: location)
```

Use catalog entries to present installation choices. Use live modules for
reading, rendering, navigation, and search.

## Configure installation explicitly

Create one ``SwordModuleLocation`` and share it between the installer and
library:

```swift
let location = try SwordModuleLocation.applicationSupport()
let configuration = SwordInstallerConfiguration(location: location)
let installer = SwordModuleInstaller(configuration: configuration)
let library = try SwordLibrary(location: location)
```

Repository descriptions are values stored in
``SwordInstallerConfiguration/repositories``. SwordKit never contacts a remote
repository merely because it appears in configuration.

## Refresh and browse a remote repository

Remote access can make Bible-reader traffic identifiable and third-party
repositories may contain unreviewed or improperly distributed content. Present
SWORD's warning in your interface and require an affirmative choice before
passing `true` for `acknowledgingRemoteAccessRisks`.

```swift
let crossWire = try SwordModuleRepository(
    identifier: "crosswire",
    name: "CrossWire Bible Society",
    transport: .https,
    host: "www.crosswire.org",
    directory: "/ftpmirror/pub/sword/raw"
)
let configuration = SwordInstallerConfiguration(
    location: location,
    repositories: [crossWire]
)
let installer = SwordModuleInstaller(configuration: configuration)

let catalog = try await installer.refreshCatalog(
    for: crossWire,
    acknowledgingRemoteAccessRisks: true
) { progress in
    print(progress.fractionCompleted as Any)
}
```

Refreshing stores the repository's SWORD configuration under the configured
installer-private directory. Use ``SwordModuleInstaller/cachedCatalog(for:)``
to reopen that snapshot without contacting the network. HTTP and HTTPS use the
SWORD build's cURL transport, currently available in SwordKit's macOS artifact;
FTP uses SWORD's built-in transport on every packaged platform. Prefer a
TLS-protected repository whenever the target artifact supports it.

## Install from a remote repository

Install an advertised module from a refreshed catalog:

```swift
try await installer.install(
    moduleNamed: "ASV",
    from: crossWire,
    acknowledgingRemoteAccessRisks: true
) { progress in
    print(progress.completedBytes)
}
library.refresh()
```

Both remote operations run away from the calling executor, report byte
progress, and honor task cancellation. A catalog refresh is required before
remote installation so applications can present current metadata and licensing
terms before downloading content.

## Install from a local catalog

The current installer API copies a selected module from a local repository:

```swift
try installer.install(moduleNamed: "KJV", from: sourceCatalog)
library.refresh()
```

Installation creates the destination and installer-private directories when
needed. Refresh explicitly after mutation so the library publishes a new module
snapshot.

## Remove and refresh

Removal operates on the configured destination:

```swift
try installer.remove(moduleNamed: "KJV")
library.refresh()
```

Previously retrieved verses and other immutable values remain valid. Existing
live module objects retain their original manager; replace application references
with modules from the refreshed library.

## Own restoration policy in the app

SwordKit does not decide when content should be redownloaded. Applications should
record stable module names and repository information needed to restore content,
especially on tvOS and watchOS where storage constraints are more significant.
