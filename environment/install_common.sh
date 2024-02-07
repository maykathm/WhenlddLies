#!/bin/sh

set -e

install_common()
{
    cmake \
        -S /root/common/ \
        -B /root/common/build \
        -DCOMMON_V1=$1 \
        -DADD_VERSION_PROPERTY=$2 \
        -DCMAKE_SHARED_LINKER_FLAGS=$3 \
        -DCMAKE_INSTALL_PREFIX=$4

    cmake --build /root/common/build
    cmake --install /root/common/build
}

# Install version 1 with versioned symbols and version property information to /opt/common1SV
install_common "ON" "ON" "-Wl,--default-symver" "/opt/common1SV"

# Install version 2 with versioned symbols and version property information to /opt/common2SV
install_common "OFF" "ON" "-Wl,--default-symver" "/opt/common2SV"

# Install version 1 without versioned symbols but with version property information to /opt/common1V
install_common "ON" "ON" "" "/opt/common1V"

# Install version 2 without versioned symbols but with version property information to /opt/common2V
install_common "OFF" "ON" "" "/opt/common2V"

# Install version 1 without versioned symbols and without version information to /opt/common1
install_common "ON" "OFF" "" "/opt/common1"

# Install version 2 without versioned symbols and without version information to /opt/common2
install_common "OFF" "OFF" "" "/opt/common2"
