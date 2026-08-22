#ifndef SWORD_BRIDGE_H
#define SWORD_BRIDGE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

const char *SwordBridgeVersion(void);
const char *SwordEngineVersion(void);

typedef struct SwordManager SwordManager;
typedef struct SwordModuleHandle SwordModuleHandle;
typedef struct SwordModuleCatalogHandle SwordModuleCatalogHandle;
typedef int (*SwordTransferProgressCallback)(
    const char *message,
    unsigned long totalBytes,
    unsigned long completedBytes,
    void *userData
);
typedef void (*SwordSearchProgressCallback)(
    int percentage,
    void *userData
);

SwordManager *SwordManagerCreate(void);
SwordManager *SwordManagerCreateAtPath(const char *path);
void SwordManagerDestroy(SwordManager *manager);

SwordModuleCatalogHandle *SwordModuleCatalogCreate(const char *path);
void SwordModuleCatalogDestroy(SwordModuleCatalogHandle *catalog);
size_t SwordModuleCatalogCount(const SwordModuleCatalogHandle *catalog);
const char *SwordModuleCatalogName(
    const SwordModuleCatalogHandle *catalog,
    size_t index
);
const char *SwordModuleCatalogDescription(
    const SwordModuleCatalogHandle *catalog,
    size_t index
);
const char *SwordModuleCatalogLanguage(
    const SwordModuleCatalogHandle *catalog,
    size_t index
);
const char *SwordModuleCatalogType(
    const SwordModuleCatalogHandle *catalog,
    size_t index
);
const char *SwordModuleCatalogVersion(
    const SwordModuleCatalogHandle *catalog,
    size_t index
);
const char *SwordModuleCatalogCopyright(
    const SwordModuleCatalogHandle *catalog,
    size_t index
);

int SwordInstallLocalModule(
    const char *privatePath,
    const char *destinationPath,
    const char *sourcePath,
    const char *moduleName
);

int SwordRemoveModule(
    const char *privatePath,
    const char *destinationPath,
    const char *moduleName
);

int SwordRefreshRemoteCatalog(
    const char *privatePath,
    const char *transport,
    const char *host,
    const char *directory,
    const char *identifier,
    const char *name,
    SwordTransferProgressCallback progress,
    void *progressUserData
);

int SwordInstallRemoteModule(
    const char *privatePath,
    const char *destinationPath,
    const char *transport,
    const char *host,
    const char *directory,
    const char *identifier,
    const char *name,
    const char *moduleName,
    SwordTransferProgressCallback progress,
    void *progressUserData
);

int SwordExtractRemoteCatalogArchive(
    const char *archivePath,
    const char *destinationPath
);

int SwordExtractRemoteModuleArchive(
    const char *archivePath,
    const char *destinationPath
);

size_t SwordManagerModuleCount(const SwordManager *manager);

SwordModuleHandle *SwordManagerOpenModule(
    const SwordManager *manager,
    size_t index
);

void SwordModuleDestroy(SwordModuleHandle *module);

void SwordModuleIncrement(
    SwordModuleHandle *module
);

void SwordModuleDecrement(
    SwordModuleHandle *module
);

const char *SwordModuleName(
    const SwordModuleHandle *module
);

const char *SwordModuleDescription(
    const SwordModuleHandle *module
);

const char *SwordModuleLanguage(
    const SwordModuleHandle *module
);

const char *SwordModuleType(
    const SwordModuleHandle *module
);
const char *SwordModuleVersion(const SwordModuleHandle *module);
const char *SwordModuleCopyright(const SwordModuleHandle *module);

size_t SwordModuleBookCount(const SwordModuleHandle *module);
const char *SwordModuleBookName(
    const SwordModuleHandle *module,
    size_t index
);
const char *SwordModuleBookOSISName(
    const SwordModuleHandle *module,
    size_t index
);
const char *SwordModuleBookPreferredAbbreviation(
    const SwordModuleHandle *module,
    size_t index
);
int SwordModuleBookChapterCount(
    const SwordModuleHandle *module,
    size_t index
);
int SwordModuleBookTestament(
    const SwordModuleHandle *module,
    size_t index
);

int SwordModuleSetKey(
    SwordModuleHandle *module,
    const char *reference
);

const char *SwordModuleCurrentKey(
    SwordModuleHandle *module
);

const char *SwordModuleRenderText(
    SwordModuleHandle *module
);

const char *SwordModuleRenderHTML(
    SwordModuleHandle *module
);

size_t SwordModuleEntryKeyCount(SwordModuleHandle *module);
const char *SwordModuleEntryKey(SwordModuleHandle *module, size_t index);
void SwordModuleClearEntryKeys(SwordModuleHandle *module);

size_t SwordModuleWordAttributeCount(
    const SwordModuleHandle *module
);

const char *SwordModuleWordAttributeText(
    const SwordModuleHandle *module,
    size_t index
);

const char *SwordModuleWordAttributeLemma(
    const SwordModuleHandle *module,
    size_t index
);

const char *SwordModuleWordAttributeMorphology(
    const SwordModuleHandle *module,
    size_t index
);

size_t SwordModuleFootnoteCount(const SwordModuleHandle *module);
const char *SwordModuleFootnoteIdentifier(
    const SwordModuleHandle *module,
    size_t index
);
const char *SwordModuleFootnoteBody(
    const SwordModuleHandle *module,
    size_t index
);
const char *SwordModuleFootnoteType(
    const SwordModuleHandle *module,
    size_t index
);
const char *SwordModuleFootnoteReferenceList(
    const SwordModuleHandle *module,
    size_t index
);

size_t SwordModuleHeadingCount(const SwordModuleHandle *module);
const char *SwordModuleHeadingPosition(
    const SwordModuleHandle *module,
    size_t index
);
const char *SwordModuleHeadingIdentifier(
    const SwordModuleHandle *module,
    size_t index
);
const char *SwordModuleHeadingBody(
    const SwordModuleHandle *module,
    size_t index
);

size_t SwordModuleParseReferenceCount(
    SwordModuleHandle *module,
    const char *reference
);

const char *SwordModuleParsedReference(
    SwordModuleHandle *module,
    size_t index
);

void SwordModuleClearParsedReferences(
    SwordModuleHandle *module
);

size_t SwordModuleSearchCount(
    SwordModuleHandle *module,
    const char *query,
    const char *scope,
    int searchType,
    int attributeType,
    int caseSensitive,
    SwordSearchProgressCallback progress,
    void *progressUserData
);

const char *SwordModuleSearchResultReference(
    SwordModuleHandle *module,
    size_t index
);

long SwordModuleSearchResultScore(
    const SwordModuleHandle *module,
    size_t index
);

void SwordModuleClearSearchResults(
    SwordModuleHandle *module
);

void SwordModuleTerminateSearch(
    SwordModuleHandle *module
);

#ifdef __cplusplus
}
#endif

#endif
