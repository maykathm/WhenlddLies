#include <cstdlib>
#include <dlfcn.h>
#include <string>
#include <KwelPluginInterface.h>
#include <memory>
#include <CommonDependency.h>
#include "SoKwel.h"
#include <iostream>

#ifdef KWEL_DEEP_BIND
static int openMode = RTLD_LAZY | RTLD_DEEPBIND;
#else
static int openMode = RTLD_LAZY;
#endif

#ifdef KWEL_USE_HIDDEN_SYM_LIB
static std::string pluginName = "libplugin_hidden_symbols";
#else
static std::string pluginName = "libplugin_visible_symbols";
#endif

#ifdef KWEL_USE_VERSIONED_SYM
static std::string versionedSym ="_s";
#else
static std::string versionedSym ="";
#endif

#ifdef KWEL_USE_VERSIONED_SO
static std::string versionedSo ="_v";
#else
static std::string versionedSo ="";
#endif


int main(int argc, char* argv[]) {
    std::string fullPluginName = pluginName + versionedSym + versionedSo + ".so";
    std::cout << "Getting ready to load plugin " << fullPluginName << std::endl;
#ifdef KWEL_DLMOPEN
    void* library = dlmopen(LM_ID_NEWLM, fullPluginName.c_str(), openMode);
#else
    void* library = dlopen(fullPluginName.c_str(), openMode);
#endif
    if (library == nullptr) {
        printf("The plugin library was not found.\n");
        return EXIT_FAILURE;
    }
    auto func = reinterpret_cast<kwel::KwelPluginInterface *(*)()>(dlsym(library, "getPlugin"));
    if (func == nullptr) {
        printf("The getPlugin symbol was not found in the plugin library\n");
        dlclose(library);
        return EXIT_FAILURE;
    }
    auto things(std::shared_ptr<kwel::KwelPluginInterface>(func(), [library](kwel::KwelPluginInterface *p){delete p; dlclose(library);}));
    things->doThings();
    kwel::SoKwel soKwel;
    soKwel.soKwel();
    common::CommonDependency common;
    common.sayHello();
    return EXIT_SUCCESS;
}