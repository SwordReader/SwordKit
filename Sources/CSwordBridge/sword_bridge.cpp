#include "sword_bridge.h"

#include <algorithm>
#include <cstdlib>
#include <regex.h>
#include <string>
#include <vector>

#include <swmgr.h>
#include <swmodule.h>
#include <swversion.h>

#include <listkey.h>
#include <filemgr.h>
#include <installmgr.h>
#include <markupfiltmgr.h>
#include <remotetrans.h>
#include <versekey.h>
#include <versificationmgr.h>
#include <zipcomprs.h>

extern "C" {
#include <internal/unzip/unzip.h>
#include <zlib.h>
}

namespace {

const char *safeCString(const char *value) {
    return value != nullptr ? value : "";
}

constexpr int searchAttributeNone = 0;
constexpr int searchAttributeStrongs = 1;
constexpr int searchAttributeMorphology = 2;

bool isSafeArchivePath(const std::string &path) {
    if (
        path.empty()
        || path.front() == '/'
        || path.front() == '\\'
        || path.find(':') != std::string::npos
    ) {
        return false;
    }

    std::string component;
    for (const char character : path) {
        if (character == '/' || character == '\\') {
            if (component == "..") {
                return false;
            }
            component.clear();
        } else {
            component += character;
        }
    }
    return component != "..";
}

unsigned long tarOctal(const char *value, size_t length) {
    unsigned long result = 0;
    for (size_t index = 0; index < length; ++index) {
        const char character = value[index];
        if (character == '\0') break;
        if (character == ' ') continue;
        if (character < '0' || character > '7') return 0;
        result = result * 8 + static_cast<unsigned long>(character - '0');
    }
    return result;
}

bool isSafeTarGZ(const char *archivePath) {
    gzFile archive = gzopen(archivePath, "rb");
    if (archive == nullptr) return false;

    char block[512];
    bool safe = true;
    while (true) {
        const int count = gzread(archive, block, sizeof(block));
        if (count == 0) break;
        if (count != sizeof(block)) {
            safe = false;
            break;
        }
        if (block[0] == '\0') break;

        const std::string name(block, strnlen(block, 100));
        const std::string prefix(block + 345, strnlen(block + 345, 155));
        const std::string path = prefix.empty() ? name : prefix + "/" + name;
        if (!isSafeArchivePath(path)) {
            safe = false;
            break;
        }

        const unsigned long size = tarOctal(block + 124, 12);
        const unsigned long dataBlocks = (size + 511) / 512;
        for (unsigned long index = 0; index < dataBlocks; ++index) {
            if (gzread(archive, block, sizeof(block)) != sizeof(block)) {
                safe = false;
                break;
            }
        }
        if (!safe) break;
    }

    gzclose(archive);
    return safe;
}

bool isSafeZip(const char *archivePath) {
    unzFile archive = unzOpen(archivePath);
    if (archive == nullptr) return false;

    unz_global_info globalInfo;
    bool safe = unzGetGlobalInfo(archive, &globalInfo) == UNZ_OK;
    for (uLong index = 0; safe && index < globalInfo.number_entry; ++index) {
        if (index > 0 && unzGoToNextFile(archive) != UNZ_OK) {
            safe = false;
            break;
        }
        unz_file_info fileInfo;
        char name[4096];
        if (
            unzGetCurrentFileInfo(
                archive,
                &fileInfo,
                name,
                sizeof(name),
                nullptr,
                0,
                nullptr,
                0
            ) != UNZ_OK
        ) {
            safe = false;
            break;
        }
        name[sizeof(name) - 1] = '\0';
        safe = isSafeArchivePath(name);
    }

    unzClose(archive);
    return safe;
}

struct SearchProgressContext {
    SwordSearchProgressCallback callback;
    void *userData;
};

class BridgeTransferReporter final : public sword::StatusReporter {
public:
    BridgeTransferReporter(
        SwordTransferProgressCallback callback,
        void *userData
    ) : callback(callback), userData(userData) {}

    void setInstaller(sword::InstallMgr *installer) {
        this->installer = installer;
    }

    void update(
        unsigned long totalBytes,
        unsigned long completedBytes
    ) override {
        report("", totalBytes, completedBytes);
    }

    void preStatus(
        long totalBytes,
        long completedBytes,
        const char *message
    ) override {
        report(
            safeCString(message),
            totalBytes < 0 ? 0 : static_cast<unsigned long>(totalBytes),
            completedBytes < 0
                ? 0
                : static_cast<unsigned long>(completedBytes)
        );
    }

private:
    SwordTransferProgressCallback callback;
    void *userData;
    sword::InstallMgr *installer = nullptr;

    void report(
        const char *message,
        unsigned long totalBytes,
        unsigned long completedBytes
    ) {
        if (callback != nullptr) {
            const int shouldCancel = callback(
                message,
                totalBytes,
                completedBytes,
                userData
            );
            if (shouldCancel != 0 && installer != nullptr) {
                installer->terminate();
            }
        }
    }
};

sword::InstallSource makeInstallSource(
    const char *transport,
    const char *host,
    const char *directory,
    const char *identifier,
    const char *name,
    const char *privatePath
) {
    std::string configuration = safeCString(name);
    configuration += "|";
    configuration += safeCString(host);
    configuration += "|";
    configuration += safeCString(directory);
    configuration += "|||";
    configuration += safeCString(identifier);

    sword::InstallSource source(transport, configuration.c_str());
    const std::string localShadow = std::string(privatePath)
        + "/" + safeCString(identifier);
    source.localShadow = localShadow.c_str();
    return source;
}

void reportSearchProgress(char percentage, void *userData) {
    auto *context = static_cast<SearchProgressContext *>(userData);

    if (context != nullptr && context->callback != nullptr) {
        context->callback(
            static_cast<unsigned char>(percentage),
            context->userData
        );
    }
}

} // namespace

struct SwordManager {
    sword::SWMgr manager;
    sword::SWMgr htmlManager;
    std::vector<sword::SWModule *> modules;

    SwordManager()
        : htmlManager(new sword::MarkupFilterMgr(sword::FMT_XHTML)) {
        loadModules();
    }

    explicit SwordManager(const char *path)
        : manager(path),
          htmlManager(
              path,
              true,
              new sword::MarkupFilterMgr(sword::FMT_XHTML)
          ) {
        loadModules();
    }

    void loadModules() {
        const auto &installedModules = manager.getModules();

        modules.reserve(installedModules.size());

        for (const auto &entry : installedModules) {
            if (entry.second != nullptr) {
                modules.push_back(entry.second);
            }
        }

        std::sort(
            modules.begin(),
            modules.end(),
            [](const sword::SWModule *lhs, const sword::SWModule *rhs) {
                return std::string(safeCString(lhs->getName()))
                    < std::string(safeCString(rhs->getName()));
            }
        );
    }
};

struct SwordModuleHandle {
    sword::SWModule *module;
    sword::SWModule *htmlModule;
    std::string currentKey;
    std::string renderedText;
    std::string renderedHTML;
    std::vector<std::string> wordAttributeTexts;
    std::vector<std::string> wordAttributeLemmas;
    std::vector<std::string> wordAttributeMorphologies;
    std::vector<std::string> footnoteIdentifiers;
    std::vector<std::string> footnoteBodies;
    std::vector<std::string> footnoteTypes;
    std::vector<std::string> footnoteReferenceLists;
    std::vector<std::string> headingPositions;
    std::vector<std::string> headingIdentifiers;
    std::vector<std::string> headingBodies;
    
    std::vector<std::string> parsedReferences;
    std::string parsedReferenceBuffer;

    std::vector<std::string> searchResultReferences;
    std::vector<long> searchResultScores;
    std::string searchResultReferenceBuffer;

    std::vector<std::string> entryKeys;
    std::string entryKeyBuffer;

    SwordModuleHandle(
        sword::SWModule *module,
        sword::SWModule *htmlModule
    ) : module(module), htmlModule(htmlModule) {}
};

namespace {

const sword::VersificationMgr::System *versificationSystem(
    const SwordModuleHandle *module
) {
    if (module == nullptr || module->module == nullptr) {
        return nullptr;
    }

    const auto *key = dynamic_cast<const sword::VerseKey *>(
        module->module->getKey()
    );

    if (key == nullptr) {
        return nullptr;
    }

    return sword::VersificationMgr::getSystemVersificationMgr()
        ->getVersificationSystem(key->getVersificationSystem());
}

const sword::VersificationMgr::Book *versificationBook(
    const SwordModuleHandle *module,
    size_t index
) {
    const auto *system = versificationSystem(module);

    if (
        system == nullptr
        || index >= static_cast<size_t>(system->getBookCount())
    ) {
        return nullptr;
    }

    return system->getBook(static_cast<int>(index));
}

} // namespace

struct SwordModuleCatalogHandle {
    sword::SWMgr manager;
    std::vector<sword::SWModule *> modules;

    explicit SwordModuleCatalogHandle(const char *path)
        : manager(path) {
        for (const auto &entry : manager.getModules()) {
            if (entry.second != nullptr) {
                modules.push_back(entry.second);
            }
        }
    }
};

extern "C" {

SwordModuleCatalogHandle *SwordModuleCatalogCreate(const char *path) {
    if (path == nullptr || path[0] == '\0') {
        return nullptr;
    }

    try {
        return new SwordModuleCatalogHandle(path);
    } catch (...) {
        return nullptr;
    }
}

void SwordModuleCatalogDestroy(SwordModuleCatalogHandle *catalog) {
    delete catalog;
}

size_t SwordModuleCatalogCount(const SwordModuleCatalogHandle *catalog) {
    return catalog == nullptr ? 0 : catalog->modules.size();
}

const sword::SWModule *catalogModule(
    const SwordModuleCatalogHandle *catalog,
    size_t index
) {
    if (catalog == nullptr || index >= catalog->modules.size()) {
        return nullptr;
    }

    return catalog->modules[index];
}

#define SWORD_CATALOG_GETTER(functionName, expression) \
const char *functionName( \
    const SwordModuleCatalogHandle *catalog, \
    size_t index \
) { \
    const auto *module = catalogModule(catalog, index); \
    return module == nullptr ? "" : safeCString(module->expression); \
}

SWORD_CATALOG_GETTER(SwordModuleCatalogName, getName())
SWORD_CATALOG_GETTER(SwordModuleCatalogDescription, getDescription())
SWORD_CATALOG_GETTER(SwordModuleCatalogLanguage, getLanguage())
SWORD_CATALOG_GETTER(SwordModuleCatalogType, getType())
SWORD_CATALOG_GETTER(
    SwordModuleCatalogVersion,
    getConfigEntry("Version")
)
SWORD_CATALOG_GETTER(
    SwordModuleCatalogCopyright,
    getConfigEntry("Copyright")
)

#undef SWORD_CATALOG_GETTER

int SwordInstallLocalModule(
    const char *privatePath,
    const char *destinationPath,
    const char *sourcePath,
    const char *moduleName
) {
    if (
        privatePath == nullptr
        || destinationPath == nullptr
        || sourcePath == nullptr
        || moduleName == nullptr
        || moduleName[0] == '\0'
    ) {
        return -1;
    }

    try {
        sword::InstallMgr installer(privatePath);
        sword::SWMgr destination(destinationPath);
        return installer.installModule(
            &destination,
            sourcePath,
            moduleName
        );
    } catch (...) {
        return -1;
    }
}

int SwordRemoveModule(
    const char *privatePath,
    const char *destinationPath,
    const char *moduleName
) {
    if (
        privatePath == nullptr
        || destinationPath == nullptr
        || moduleName == nullptr
        || moduleName[0] == '\0'
    ) {
        return -1;
    }

    try {
        sword::InstallMgr installer(privatePath);
        sword::SWMgr destination(destinationPath);
        return installer.removeModule(&destination, moduleName);
    } catch (...) {
        return -1;
    }
}

int SwordRefreshRemoteCatalog(
    const char *privatePath,
    const char *transport,
    const char *host,
    const char *directory,
    const char *identifier,
    const char *name,
    SwordTransferProgressCallback progress,
    void *progressUserData
) {
    if (
        privatePath == nullptr
        || transport == nullptr
        || host == nullptr
        || identifier == nullptr
        || identifier[0] == '\0'
    ) {
        return -1;
    }

    try {
        BridgeTransferReporter reporter(progress, progressUserData);
        sword::InstallMgr installer(privatePath, &reporter);
        reporter.setInstaller(&installer);
        installer.setUserDisclaimerConfirmed(true);
        auto source = makeInstallSource(
            transport,
            host,
            directory,
            identifier,
            name,
            privatePath
        );
        return installer.refreshRemoteSource(&source);
    } catch (...) {
        return -1;
    }
}

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
) {
    if (
        privatePath == nullptr
        || destinationPath == nullptr
        || transport == nullptr
        || host == nullptr
        || identifier == nullptr
        || identifier[0] == '\0'
        || moduleName == nullptr
        || moduleName[0] == '\0'
    ) {
        return -1;
    }

    try {
        BridgeTransferReporter reporter(progress, progressUserData);
        sword::InstallMgr installer(privatePath, &reporter);
        reporter.setInstaller(&installer);
        installer.setUserDisclaimerConfirmed(true);
        sword::SWMgr destination(destinationPath);
        auto source = makeInstallSource(
            transport,
            host,
            directory,
            identifier,
            name,
            privatePath
        );
        return installer.installModule(
            &destination,
            nullptr,
            moduleName,
            &source
        );
    } catch (...) {
        return -1;
    }
}

int SwordExtractRemoteCatalogArchive(
    const char *archivePath,
    const char *destinationPath
) {
    if (
        archivePath == nullptr
        || destinationPath == nullptr
        || !isSafeTarGZ(archivePath)
    ) {
        return -1;
    }

    const int descriptor = sword::FileMgr::openFileReadOnly(archivePath);
    if (descriptor < 0) return -1;
    const int status = sword::ZipCompress::unTarGZ(
        descriptor,
        destinationPath
    );
    sword::FileMgr::closeFile(descriptor);
    return status;
}

int SwordExtractRemoteModuleArchive(
    const char *archivePath,
    const char *destinationPath
) {
    if (
        archivePath == nullptr
        || destinationPath == nullptr
        || !isSafeZip(archivePath)
    ) {
        return -1;
    }
    return sword::ZipCompress::unZip(archivePath, destinationPath);
}

size_t SwordModuleParseReferenceCount(
    SwordModuleHandle *module,
    const char *reference
) {
    if (
        module == nullptr
        || module->module == nullptr
        || reference == nullptr
        || reference[0] == '\0'
    ) {
        return 0;
    }

    module->parsedReferences.clear();
    module->parsedReferenceBuffer.clear();

    try {
        sword::VerseKey parser;

        sword::ListKey references = parser.parseVerseList(
            reference,
            module->module->getKeyText(),
            true
        );

        const int count = references.getCount();

        if (count <= 0) {
            return 0;
        }

        module->parsedReferences.reserve(
            static_cast<size_t>(count)
        );

        for (int index = 0; index < count; ++index) {
            const sword::SWKey *key =
                references.getElement(index);

            if (key == nullptr) {
                continue;
            }

            const char *text = key->getText();

            if (text == nullptr || text[0] == '\0') {
                continue;
            }

            module->parsedReferences.emplace_back(text);
        }

        return module->parsedReferences.size();
    } catch (...) {
        module->parsedReferences.clear();
        module->parsedReferenceBuffer.clear();
        return 0;
    }
}

const char *SwordModuleParsedReference(
    SwordModuleHandle *module,
    size_t index
) {
    if (
        module == nullptr
        || index >= module->parsedReferences.size()
    ) {
        return "";
    }

    try {
        module->parsedReferenceBuffer =
            module->parsedReferences[index];

        return module->parsedReferenceBuffer.c_str();
    } catch (...) {
        module->parsedReferenceBuffer.clear();
        return "";
    }
}

void SwordModuleClearParsedReferences(
    SwordModuleHandle *module
) {
    if (module == nullptr) {
        return;
    }

    module->parsedReferences.clear();
    module->parsedReferenceBuffer.clear();
}

size_t SwordModuleSearchCount(
    SwordModuleHandle *module,
    const char *query,
    const char *scope,
    int searchType,
    int attributeType,
    int caseSensitive,
    SwordSearchProgressCallback progress,
    void *progressUserData
) {
    const bool isAttributeSearch =
        searchType == sword::SWModule::SEARCHTYPE_ENTRYATTR;

    if (
        module == nullptr
        || module->module == nullptr
        || query == nullptr
        || query[0] == '\0'
        || (
            searchType != sword::SWModule::SEARCHTYPE_PHRASE
            && searchType != sword::SWModule::SEARCHTYPE_MULTIWORD
            && searchType != sword::SWModule::SEARCHTYPE_REGEX
            && searchType != sword::SWModule::SEARCHTYPE_ENTRYATTR
        )
        || (
            isAttributeSearch
                ? (
                    attributeType != searchAttributeStrongs
                    && attributeType != searchAttributeMorphology
                )
                : attributeType != searchAttributeNone
        )
        || (caseSensitive != 0 && caseSensitive != 1)
    ) {
        return 0;
    }

    module->searchResultReferences.clear();
    module->searchResultScores.clear();
    module->searchResultReferenceBuffer.clear();

    try {
        std::string searchQuery = query;

        if (isAttributeSearch) {
            const char *attribute =
                attributeType == searchAttributeStrongs
                    ? "Lemma."
                    : "Morph.";

            searchQuery =
                "Word//" + std::string(attribute)
                + "/" + searchQuery + "/";
        }

        sword::ListKey scopeKeys;
        sword::SWKey *searchScope = nullptr;

        if (scope != nullptr && scope[0] != '\0') {
            sword::VerseKey parser;

            scopeKeys = parser.parseVerseList(
                scope,
                module->module->getKeyText(),
                true
            );

            if (scopeKeys.getCount() <= 0) {
                return 0;
            }

            searchScope = &scopeKeys;
        }

        SearchProgressContext progressContext {
            progress,
            progressUserData
        };

        sword::ListKey results = module->module->search(
            searchQuery.c_str(),
            searchType,
            caseSensitive ? 0 : REG_ICASE,
            searchScope,
            nullptr,
            &reportSearchProgress,
            &progressContext
        );

        const int count = results.getCount();

        if (count <= 0) {
            return 0;
        }

        module->searchResultReferences.reserve(
            static_cast<size_t>(count)
        );
        module->searchResultScores.reserve(
            static_cast<size_t>(count)
        );

        for (int index = 0; index < count; ++index) {
            const sword::SWKey *key = results.getElement(index);

            if (key == nullptr) {
                continue;
            }

            const char *reference = key->getText();

            if (reference == nullptr || reference[0] == '\0') {
                continue;
            }

            module->searchResultReferences.emplace_back(reference);
            module->searchResultScores.push_back(
                static_cast<long>(key->userData)
            );
        }

        return module->searchResultReferences.size();
    } catch (...) {
        module->searchResultReferences.clear();
        module->searchResultScores.clear();
        module->searchResultReferenceBuffer.clear();
        return 0;
    }
}

const char *SwordModuleSearchResultReference(
    SwordModuleHandle *module,
    size_t index
) {
    if (
        module == nullptr
        || index >= module->searchResultReferences.size()
    ) {
        return "";
    }

    try {
        module->searchResultReferenceBuffer =
            module->searchResultReferences[index];

        return module->searchResultReferenceBuffer.c_str();
    } catch (...) {
        module->searchResultReferenceBuffer.clear();
        return "";
    }
}

long SwordModuleSearchResultScore(
    const SwordModuleHandle *module,
    size_t index
) {
    if (
        module == nullptr
        || index >= module->searchResultScores.size()
    ) {
        return 0;
    }

    return module->searchResultScores[index];
}

void SwordModuleClearSearchResults(
    SwordModuleHandle *module
) {
    if (module == nullptr) {
        return;
    }

    module->searchResultReferences.clear();
    module->searchResultScores.clear();
    module->searchResultReferenceBuffer.clear();
}

void SwordModuleTerminateSearch(
    SwordModuleHandle *module
) {
    if (module == nullptr || module->module == nullptr) {
        return;
    }

    module->module->terminateSearch = true;
}

const char *SwordBridgeVersion(void) {
    return "0.5.1";
}

const char *SwordEngineVersion(void) {
    return sword::SWVersion::currentVersion.getText();
}

SwordManager *SwordManagerCreate(void) {
    try {
        return new SwordManager();
    } catch (...) {
        return nullptr;
    }
}

SwordManager *SwordManagerCreateAtPath(const char *path) {
    if (path == nullptr || path[0] == '\0') {
        return nullptr;
    }

    try {
        return new SwordManager(path);
    } catch (...) {
        return nullptr;
    }
}

void SwordManagerDestroy(SwordManager *manager) {
    delete manager;
}

size_t SwordManagerModuleCount(const SwordManager *manager) {
    if (manager == nullptr) {
        return 0;
    }

    return manager->modules.size();
}

SwordModuleHandle *SwordManagerOpenModule(
    const SwordManager *manager,
    size_t index
) {
    if (manager == nullptr || index >= manager->modules.size()) {
        return nullptr;
    }

    try {
        sword::SWModule *module = manager->modules[index];
        return new SwordModuleHandle(
            module,
            const_cast<sword::SWModule *>(
                manager->htmlManager.getModule(module->getName())
            )
        );
    } catch (...) {
        return nullptr;
    }
}

void SwordModuleDestroy(SwordModuleHandle *module) {
    delete module;
}

const char *SwordModuleName(
    const SwordModuleHandle *module
) {
    if (module == nullptr || module->module == nullptr) {
        return "";
    }

    return safeCString(module->module->getName());
}

const char *SwordModuleDescription(
    const SwordModuleHandle *module
) {
    if (module == nullptr || module->module == nullptr) {
        return "";
    }

    return safeCString(module->module->getDescription());
}

const char *SwordModuleLanguage(
    const SwordModuleHandle *module
) {
    if (module == nullptr || module->module == nullptr) {
        return "";
    }

    return safeCString(module->module->getLanguage());
}

const char *SwordModuleType(
    const SwordModuleHandle *module
) {
    if (module == nullptr || module->module == nullptr) {
        return "";
    }

    return safeCString(module->module->getType());
}

const char *SwordModuleVersion(const SwordModuleHandle *module) {
    return module == nullptr || module->module == nullptr
        ? ""
        : safeCString(module->module->getConfigEntry("Version"));
}

const char *SwordModuleCopyright(const SwordModuleHandle *module) {
    return module == nullptr || module->module == nullptr
        ? ""
        : safeCString(module->module->getConfigEntry("Copyright"));
}

size_t SwordModuleBookCount(const SwordModuleHandle *module) {
    const auto *system = versificationSystem(module);
    return system == nullptr
        ? 0
        : static_cast<size_t>(system->getBookCount());
}

const char *SwordModuleBookName(
    const SwordModuleHandle *module,
    size_t index
) {
    const auto *book = versificationBook(module, index);
    return book == nullptr ? "" : safeCString(book->getLongName());
}

const char *SwordModuleBookOSISName(
    const SwordModuleHandle *module,
    size_t index
) {
    const auto *book = versificationBook(module, index);
    return book == nullptr ? "" : safeCString(book->getOSISName());
}

const char *SwordModuleBookPreferredAbbreviation(
    const SwordModuleHandle *module,
    size_t index
) {
    const auto *book = versificationBook(module, index);
    return book == nullptr
        ? ""
        : safeCString(book->getPreferredAbbreviation());
}

int SwordModuleBookChapterCount(
    const SwordModuleHandle *module,
    size_t index
) {
    const auto *book = versificationBook(module, index);
    return book == nullptr ? 0 : book->getChapterMax();
}

int SwordModuleBookTestament(
    const SwordModuleHandle *module,
    size_t index
) {
    const auto *system = versificationSystem(module);

    if (
        system == nullptr
        || index >= static_cast<size_t>(system->getBookCount())
    ) {
        return 0;
    }

    return index < static_cast<size_t>(system->getBMAX()[0]) ? 1 : 2;
}

int SwordModuleSetKey(
    SwordModuleHandle *module,
    const char *reference
) {
    if (
        module == nullptr
        || module->module == nullptr
        || reference == nullptr
        || reference[0] == '\0'
    ) {
        return -1;
    }

    try {
        const char status = module->module->setKey(reference);

        module->currentKey = safeCString(
            module->module->getKeyText()
        );

        module->renderedText.clear();

        return static_cast<int>(status);
    } catch (...) {
        module->currentKey.clear();
        module->renderedText.clear();
        return -1;
    }
}

const char *SwordModuleCurrentKey(
    SwordModuleHandle *module
) {
    if (module == nullptr || module->module == nullptr) {
        return "";
    }

    try {
        module->currentKey = safeCString(
            module->module->getKeyText()
        );

        return module->currentKey.c_str();
    } catch (...) {
        module->currentKey.clear();
        return "";
    }
}

size_t SwordModuleEntryKeyCount(SwordModuleHandle *module) {
    if (module == nullptr || module->module == nullptr) {
        return 0;
    }

    module->entryKeys.clear();
    module->entryKeyBuffer.clear();

    try {
        const std::string originalKey = safeCString(
            module->module->getKeyText()
        );

        module->module->setPosition(sword::SW_POSITION(1));
        constexpr size_t maximumEntryCount = 100000;

        while (
            module->module->popError() == 0
            && module->entryKeys.size() < maximumEntryCount
        ) {
            const std::string key = safeCString(
                module->module->getKeyText()
            );

            if (
                !key.empty()
                && (module->entryKeys.empty() || module->entryKeys.back() != key)
            ) {
                module->entryKeys.push_back(key);
            }

            module->module->increment();
        }

        if (!originalKey.empty()) {
            module->module->setKey(originalKey.c_str());
        }

        return module->entryKeys.size();
    } catch (...) {
        module->entryKeys.clear();
        module->entryKeyBuffer.clear();
        return 0;
    }
}

const char *SwordModuleEntryKey(
    SwordModuleHandle *module,
    size_t index
) {
    if (module == nullptr || index >= module->entryKeys.size()) {
        return "";
    }

    module->entryKeyBuffer = module->entryKeys[index];
    return module->entryKeyBuffer.c_str();
}

void SwordModuleClearEntryKeys(SwordModuleHandle *module) {
    if (module == nullptr) {
        return;
    }

    module->entryKeys.clear();
    module->entryKeyBuffer.clear();
}

const char *SwordModuleRenderText(
    SwordModuleHandle *module
                                  ) {
    if (module == nullptr || module->module == nullptr) {
        return "";
    }
    
    try {
        module->wordAttributeTexts.clear();
        module->wordAttributeLemmas.clear();
        module->wordAttributeMorphologies.clear();
        module->footnoteIdentifiers.clear();
        module->footnoteBodies.clear();
        module->footnoteTypes.clear();
        module->footnoteReferenceLists.clear();
        module->headingPositions.clear();
        module->headingIdentifiers.clear();
        module->headingBodies.clear();
        module->module->setProcessEntryAttributes(true);
        module->renderedText =
        module->module->renderText().c_str();

        auto &attributes = module->module->getEntryAttributes();
        const auto words = attributes.find("Word");

        if (words != attributes.end()) {
            for (const auto &word : words->second) {
                const auto text = word.second.find("Text");
                const auto partCountValue = word.second.find("PartCount");
                int partCount = partCountValue == word.second.end()
                    ? 1
                    : std::max(1, std::atoi(partCountValue->second.c_str()));

                for (int part = 0; part < partCount; ++part) {
                    std::string lemmaKey = "Lemma";

                    if (partCount > 1) {
                        lemmaKey += "." + std::to_string(part + 1);
                    }

                    const auto lemma = word.second.find(lemmaKey.c_str());
                    std::string morphologyKey = "Morph";

                    if (partCount > 1) {
                        morphologyKey += "." + std::to_string(part + 1);
                    }

                    const auto morphology = word.second.find(
                        morphologyKey.c_str()
                    );

                    if (lemma == word.second.end()) {
                        continue;
                    }

                    module->wordAttributeTexts.emplace_back(
                        text == word.second.end() ? "" : text->second.c_str()
                    );
                    module->wordAttributeLemmas.emplace_back(
                        lemma->second.c_str()
                    );
                    module->wordAttributeMorphologies.emplace_back(
                        morphology == word.second.end()
                            ? ""
                            : morphology->second.c_str()
                    );
                }
            }
        }

        const auto footnotes = attributes.find("Footnote");

        if (footnotes != attributes.end()) {
            for (const auto &footnote : footnotes->second) {
                if (footnote.first == "count") {
                    continue;
                }

                const auto body = footnote.second.find("body");
                const auto type = footnote.second.find("type");
                const auto references = footnote.second.find("refList");

                module->footnoteIdentifiers.emplace_back(
                    footnote.first.c_str()
                );
                module->footnoteBodies.emplace_back(
                    body == footnote.second.end() ? "" : body->second.c_str()
                );
                module->footnoteTypes.emplace_back(
                    type == footnote.second.end() ? "" : type->second.c_str()
                );
                module->footnoteReferenceLists.emplace_back(
                    references == footnote.second.end()
                        ? ""
                        : references->second.c_str()
                );
            }
        }

        const auto headings = attributes.find("Heading");

        if (headings != attributes.end()) {
            for (const auto &position : headings->second) {
                for (const auto &heading : position.second) {
                    module->headingPositions.emplace_back(
                        position.first.c_str()
                    );
                    module->headingIdentifiers.emplace_back(
                        heading.first.c_str()
                    );
                    module->headingBodies.emplace_back(
                        heading.second.c_str()
                    );
                }
            }
        }
        
        return module->renderedText.c_str();
    } catch (...) {
        module->renderedText.clear();
        return "";
    }
}

const char *SwordModuleRenderHTML(
    SwordModuleHandle *module
) {
    if (module == nullptr || module->htmlModule == nullptr) {
        return "";
    }

    try {
        module->htmlModule->setKey(module->module->getKeyText());
        module->renderedHTML = "<style>";
        module->renderedHTML += safeCString(
            module->htmlModule->getRenderHeader()
        );
        module->renderedHTML += "</style>";
        module->renderedHTML += module->htmlModule->renderText().c_str();
        return module->renderedHTML.c_str();
    } catch (...) {
        module->renderedHTML.clear();
        return "";
    }
}

size_t SwordModuleWordAttributeCount(
    const SwordModuleHandle *module
) {
    return module == nullptr ? 0 : module->wordAttributeLemmas.size();
}

const char *SwordModuleWordAttributeText(
    const SwordModuleHandle *module,
    size_t index
) {
    if (module == nullptr || index >= module->wordAttributeTexts.size()) {
        return "";
    }

    return module->wordAttributeTexts[index].c_str();
}

const char *SwordModuleWordAttributeLemma(
    const SwordModuleHandle *module,
    size_t index
) {
    if (module == nullptr || index >= module->wordAttributeLemmas.size()) {
        return "";
    }

    return module->wordAttributeLemmas[index].c_str();
}

const char *SwordModuleWordAttributeMorphology(
    const SwordModuleHandle *module,
    size_t index
) {
    if (
        module == nullptr
        || index >= module->wordAttributeMorphologies.size()
    ) {
        return "";
    }

    return module->wordAttributeMorphologies[index].c_str();
}

size_t SwordModuleFootnoteCount(const SwordModuleHandle *module) {
    return module == nullptr ? 0 : module->footnoteIdentifiers.size();
}

#define SWORD_FOOTNOTE_GETTER(functionName, field) \
const char *functionName(const SwordModuleHandle *module, size_t index) { \
    if (module == nullptr || index >= module->field.size()) return ""; \
    return module->field[index].c_str(); \
}

SWORD_FOOTNOTE_GETTER(
    SwordModuleFootnoteIdentifier,
    footnoteIdentifiers
)
SWORD_FOOTNOTE_GETTER(SwordModuleFootnoteBody, footnoteBodies)
SWORD_FOOTNOTE_GETTER(SwordModuleFootnoteType, footnoteTypes)
SWORD_FOOTNOTE_GETTER(
    SwordModuleFootnoteReferenceList,
    footnoteReferenceLists
)

#undef SWORD_FOOTNOTE_GETTER

size_t SwordModuleHeadingCount(const SwordModuleHandle *module) {
    return module == nullptr ? 0 : module->headingIdentifiers.size();
}

#define SWORD_HEADING_GETTER(functionName, field) \
const char *functionName(const SwordModuleHandle *module, size_t index) { \
    if (module == nullptr || index >= module->field.size()) return ""; \
    return module->field[index].c_str(); \
}

SWORD_HEADING_GETTER(SwordModuleHeadingPosition, headingPositions)
SWORD_HEADING_GETTER(SwordModuleHeadingIdentifier, headingIdentifiers)
SWORD_HEADING_GETTER(SwordModuleHeadingBody, headingBodies)

#undef SWORD_HEADING_GETTER

void SwordModuleIncrement(
    SwordModuleHandle *module
) {
    if (module == nullptr || module->module == nullptr) {
        return;
    }

    try {
        module->module->increment();

        module->currentKey =
            safeCString(module->module->getKeyText());

        module->renderedText.clear();
    }
    catch (...) {
    }
}

void SwordModuleDecrement(
    SwordModuleHandle *module
) {
    if (module == nullptr || module->module == nullptr) {
        return;
    }

    try {
        module->module->decrement();

        module->currentKey =
            safeCString(module->module->getKeyText());

        module->renderedText.clear();
    }
    catch (...) {
    }
}

} // extern "C"
