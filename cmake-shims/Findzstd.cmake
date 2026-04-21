# The system zstd package's CMake config only defines zstd::libzstd_shared
# (and zstd::libzstd), but Zrythm links zstd::libzstd_static. Forward to the
# system config and add the missing target as an alias of the shared library;
# quick-sharun bundles libzstd.so into the AppImage anyway.
find_package(zstd CONFIG QUIET)

if(NOT zstd_FOUND)
    set(zstd_FOUND FALSE)
    if(zstd_FIND_REQUIRED)
        message(FATAL_ERROR
            "Could not find a package configuration file provided by zstd")
    endif()
    return()
endif()

if(NOT TARGET zstd::libzstd_static)
    add_library(zstd::libzstd_static INTERFACE IMPORTED)
    set_target_properties(zstd::libzstd_static PROPERTIES
        INTERFACE_LINK_LIBRARIES zstd::libzstd_shared)
endif()
