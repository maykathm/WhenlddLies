#!/bin/sh

set -e

install_main_exe()
{
    cmake  \
        -S /root/main \
        -B /root/main/build \
        -DKWEL_USE_PLUGIN_WITH_HIDDEN_SYMBOLS=$1 \
        -DKWEL_USE_DEEP_BIND=$2 \
        -DKWEL_USE_VERSIONED_SYM=$3 \
        -DKWEL_USE_VERSIONED_SO=$4 \
        -DKWEL_DLMOPEN=$5 \
        -DCMAKE_PREFIX_PATH=$6 \
        -DKWEL_EXE_NAME=$7 \
        -DCMAKE_INSTALL_PREFIX=/opt/mains

    cmake --build /root/main/build
    cmake --install /root/main/build
    rm -r /root/main/build
}

# look for plugin with exported symbols, don't RTLD_DEEPBIND, do not use versioned symbols, do not use versioned so
install_main_exe "OFF" "OFF" "OFF" "OFF" "OFF" "/opt/common1/" "attempt1"

# look for plugin with exported symbols, use dlmopen, do not use versioned symbols, don't use versioned so
install_main_exe "OFF" "OFF" "OFF" "OFF" "ON" "/opt/common1V/" "attempt2"

# look for plugin with exported symbols, use RTLD_DEEPBIND, do not use versioned symbols, do not use versioned so
install_main_exe "OFF" "ON" "OFF" "OFF" "OFF" "/opt/common1/" "attempt3"

# look for plugin with exported symbols, use RTLD_DEEPBIND, do not use versioned symbols, use versioned so
install_main_exe "OFF" "ON" "OFF" "ON" "OFF" "/opt/common1V/" "attempt4"

# look for plugin with hidden symbols, don't use RTLD_DEEPBIND, do not use versioned symbols, use versioned so
install_main_exe "ON" "OFF" "OFF" "ON" "OFF" "/opt/common1V/" "attempt5"

# look for plugin with hidden symbols, don't use RTLD_DEEPBIND, use versioned symbols, use versioned so
install_main_exe "ON" "OFF" "ON" "ON" "OFF" "/opt/common1SV/" "attempt6"