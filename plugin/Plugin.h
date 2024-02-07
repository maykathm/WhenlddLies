#ifndef KWEL_PLUGIN_H
#define KWEL_PLUGIN_H

#include <KwelPluginInterface.h>

namespace kwel {
    class Plugin : public kwel::KwelPluginInterface {
        void doThings() const override;
    };
}

#ifndef PLUGIN_GETPLUGIN
#define PLUGIN_GETPLUGIN

extern "C" {
    __attribute__((visibility("default"))) kwel::KwelPluginInterface* getPlugin() {
        return new kwel::Plugin();
    }
}
#endif

#endif