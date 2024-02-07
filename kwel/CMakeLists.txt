
cmake_minimum_required(VERSION 3.16)

project(kwel)
set(CMAKE_CXX_STANDARD 11)

set(CMAKE_BUILD_TYPE "Release")

add_library(${PROJECT_NAME} INTERFACE)
add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})

target_include_directories(${PROJECT_NAME} INTERFACE
$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDE_DIR}>
)

###################################################################################################################
##                                                                                                              ###
##                                                    Install                                                   ###
##                                                                                                              ###
###################################################################################################################

include(GNUInstallDirs)

set(CMAKE_INSTALL_CMAKEDIR
    ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
    CACHE STRING "Path to cpptemplate cmake files"
)

install(TARGETS ${PROJECT_NAME} EXPORT ${PROJECT_NAME}Targets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} 
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} 
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/KwelPluginInterface.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

set(configFile ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake)

include(CMakePackageConfigHelpers)

configure_package_config_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/kwelConfig.cmake.in
    ${configFile}
    INSTALL_DESTINATION ${CMAKE_INSTALL_CMAKEDIR}
)

install(FILES
    ${configFile}
    DESTINATION ${CMAKE_INSTALL_CMAKEDIR}
)

install(EXPORT ${PROJECT_NAME}Targets
    DESTINATION ${CMAKE_INSTALL_CMAKEDIR}
    NAMESPACE ${PROJECT_NAME}::
    FILE ${PROJECT_NAME}Targets.cmake
)