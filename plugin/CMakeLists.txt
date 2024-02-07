
cmake_minimum_required(VERSION 3.16)

project(plugin)
set(CMAKE_CXX_STANDARD 11)

option(HIDE_SYMBOLS "hide all symbols that can be hidden" ON)
option(CMAKE_INSTALL_RPATH_USE_LINK_PATH "Don't strip rpath during install" TRUE)
set(PLUGIN_LIB_POSTFIX "" CACHE STRING "Postfix to add to the library name")

set(CMAKE_BUILD_TYPE "Release")

if (${HIDE_SYMBOLS})
    set(CMAKE_CXX_VISIBILITY_PRESET hidden)
    set(CMAKE_VISIBILITY_INLINES_HIDDEN YES)
endif()

if (${HIDE_SYMBOLS})
    set(lib_name "${PROJECT_NAME}_hidden_symbols${PLUGIN_LIB_POSTFIX}")
else()
    set(lib_name "${PROJECT_NAME}_visible_symbols${PLUGIN_LIB_POSTFIX}")
endif()

add_library(${lib_name} SHARED)
add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${lib_name})

target_include_directories(${lib_name} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
)

find_package(kwel REQUIRED)
target_link_libraries(${lib_name} PUBLIC kwel::kwel)

find_package(common REQUIRED)
target_link_libraries(${lib_name} PRIVATE common::common)

target_sources(${lib_name} PRIVATE
    Plugin.cpp
    SoKwel.cpp
)

install(TARGETS ${lib_name})