#!/bin/sh

set -e

install_plugin_lib()
{
    cmake \
        -S /root/plugin \
        -B /root/plugin/build \
        -DHIDE_SYMBOLS=$1 \
        -DCMAKE_PREFIX_PATH=$2 \
        -DPLUGIN_LIB_POSTFIX=$3

    cmake --build /root/plugin/build
    cmake --install /root/plugin/build
    rm -r /root/plugin/build
}

# install the plugin with symbols hidden and linked to versioned symbols
install_plugin_lib "ON" "/opt/common2SV/" "_s_v"

# install the plugin with symbols hidden and linked to non-versioned symbols but versioned common so
install_plugin_lib "ON" "/opt/common2V/" "_v"

# install the plugin with symbols not hidden and linked to versioned symbols
install_plugin_lib "OFF" "/opt/common2SV/" "_s_v"

# install the plugin with symbols not hidden and linked to non-versioned symbols but versioned common so
install_plugin_lib "OFF" "/opt/common2V/" "_v"

# install the plugin with symbols not hidden and linked to non-versioned symbols and not versioned common so
install_plugin_lib "OFF" "/opt/common2/" ""

# Run ldconfig to add /usr/local/lib to linker path since the plugin was added into that folder
ldconfig