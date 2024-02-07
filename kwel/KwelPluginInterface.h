#ifndef KWEL_KWEL_PLUGIN_INTERFACE_H
#define KWEL_KWEL_PLUGIN_INTERFACE_H

namespace kwel {
    class KwelPluginInterface {
    public:
        virtual ~KwelPluginInterface() = default;
        virtual void doThings() const = 0;
    };
}

#endif