cmake_minimum_required(VERSION 3.16)

project(kwel_main)
set(CMAKE_CXX_STANDARD 11)

option(KWEL_USE_PLUGIN_WITH_HIDDEN_SYMBOLS "Use the plugin library that was built with hidden symbols" ON)
option(KWEL_USE_DEEP_BIND "Use the RTLD_DEEPBIND option when loading the plugin library" ON)
option(KWEL_USE_VERSIONED_SYM "Use the plugin library that was built linked to the common dependency with versioned symbols" ON)
option(KWEL_USE_VERSIONED_SO "Use the plugin library that was built linked to the common dependency with the version property" ON)
option(KWEL_DLMOPEN "Use dlmopen instead of dlopen" OFF)
set(KWEL_EXE_NAME "kwel_main" CACHE STRING "Set the name of the exe to build")
 
# use this specified rpath when installing, not during build
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
 
# don't strip rpath outside the build tree that was found (i.e. libcommon)
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

set(CMAKE_BUILD_TYPE "Release")

add_executable(${KWEL_EXE_NAME} main.cpp)

if (${KWEL_USE_PLUGIN_WITH_HIDDEN_SYMBOLS})
    target_compile_definitions(${KWEL_EXE_NAME} PRIVATE KWEL_USE_HIDDEN_SYM_LIB)
endif()

if (${KWEL_USE_DEEP_BIND})
    target_compile_definitions(${KWEL_EXE_NAME}  PRIVATE KWEL_DEEP_BIND)
endif()

if (${KWEL_USE_VERSIONED_SYM})
    target_compile_definitions(${KWEL_EXE_NAME} PRIVATE KWEL_USE_VERSIONED_SYM)
endif()

if (${KWEL_USE_VERSIONED_SO})
    target_compile_definitions(${KWEL_EXE_NAME} PRIVATE KWEL_USE_VERSIONED_SO)
endif()

if (${KWEL_DLMOPEN})
    target_compile_definitions(${KWEL_EXE_NAME} PRIVATE KWEL_DLMOPEN)
endif()

find_package(common REQUIRED)
target_link_libraries(${KWEL_EXE_NAME} PRIVATE common::common)

find_package(kwel REQUIRED)
target_link_libraries(${KWEL_EXE_NAME} PRIVATE kwel::kwel)

add_library(so_kwel SHARED SoKwel.cpp)
target_link_libraries(${KWEL_EXE_NAME} PRIVATE so_kwel)

install(TARGETS ${KWEL_EXE_NAME} so_kwel)