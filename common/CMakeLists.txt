###################################################################################################################
##                                                                                                              ###
##                                             Common Dependency                                                ###
##                                                                                                              ###
###################################################################################################################

cmake_minimum_required(VERSION 3.16)

project(common)
set(CMAKE_CXX_STANDARD 11)

option(COMMON_V1 "If on, build version 1, otherwise build verison 2" ON)
option(ADD_VERSION_PROPERTY "If on, add the target version property to library" ON)

set(CMAKE_BUILD_TYPE "Release")

# Add a new library with the project name (common) as its name
# Also create an alias so users can link to it with common::common
add_library(${PROJECT_NAME} SHARED)
add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})

target_include_directories(${PROJECT_NAME} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDE_DIR}>
)

if (${COMMON_V1})
    set(major_version 1)
else()
    set(major_version 2)
endif()
set(minor_version 0)
set(patch_version 0)

# Without the VERSION or SOVERSION property, the build will generate only a libcommon.so file.
if (${ADD_VERSION_PROPERTY})

# By adding the VERSION property, it will build the file: libcommon.so.<major>.<minor>.<patch>
# By adding the SOVERSION property, it will build the file: libcommon.so.<major_version>
# The libcommon.so is a symbolic link to libcommon.so.<major>, which is a symbolic link to libcommon.so.<major>.<minor>.<patch>

    set_target_properties(${PROJECT_NAME}
            PROPERTIES SOVERSION ${major_version}
            VERSION ${major_version}.${minor_version}.${patch_version}
        )
endif()

target_sources(${PROJECT_NAME} PRIVATE "CommonDependencyv${major_version}.cpp")

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

install(FILES CommonDependency.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

set(configFile ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake)
set(versionFile ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake)

include(CMakePackageConfigHelpers)

configure_package_config_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/commonConfig.cmake.in
    ${configFile}
    INSTALL_DESTINATION ${CMAKE_INSTALL_CMAKEDIR}
)

get_target_property(version ${PROJECT_NAME} VERSION)

write_basic_package_version_file(
    ${versionFile}
    VERSION ${version}
    COMPATIBILITY SameMajorVersion
)

install(FILES
    ${configFile}
    ${versionFile}
    DESTINATION ${CMAKE_INSTALL_CMAKEDIR}
)

install(EXPORT ${PROJECT_NAME}Targets
    DESTINATION ${CMAKE_INSTALL_CMAKEDIR}
    NAMESPACE ${PROJECT_NAME}::
    FILE ${PROJECT_NAME}Targets.cmake
)