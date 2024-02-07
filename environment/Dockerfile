FROM ubuntu:latest AS base_dependencies
 
RUN   apt update && apt install -y \
      build-essential \
      nasm \
      file \
      gdb \
      git \
      cmake-curses-gui \
      gcc-multilib

RUN   cd opt && \
      git clone https://github.com/pwndbg/pwndbg && \
      cd pwndbg && \
      ./setup.sh && \
      echo "export LC_CTYPE=C.UTF-8" >> ~/.bashrc

FROM  base_dependencies AS lib_common
COPY  common /root/common
COPY  environment/install_common.sh /root/install_common.sh
RUN   sh /root/install_common.sh

FROM  lib_common AS kwel_interface
COPY  kwel /root/kwel
RUN   cmake -S /root/kwel -B /root/kwel/build -DCMAKE_INSTALL_PREFIX="/opt/kwel" && \
      cmake --build /root/kwel/build && \
      cmake --install /root/kwel/build

FROM  kwel_interface AS lib_plugin
COPY  plugin /root/plugin
COPY  environment/install_plugin.sh /root/install_plugin.sh
RUN   sh /root/install_plugin.sh

FROM  lib_plugin AS kwe_mains
COPY  main /root/main
COPY  environment/install_main.sh /root/install_main.sh
RUN   sh /root/install_main.sh
