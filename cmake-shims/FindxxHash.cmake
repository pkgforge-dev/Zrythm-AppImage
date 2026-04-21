# Arch's xxhash package only ships headers, a shared library and a pkg-config
# file (no CMake package config). Zrythm does find_package(xxHash) and links
# xxHash::xxhash, so locate the system library and define that target here.
find_path(XXHASH_INCLUDE_DIR NAMES xxhash.h)
find_library(XXHASH_LIBRARY NAMES xxhash)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(xxHash
    REQUIRED_VARS XXHASH_LIBRARY XXHASH_INCLUDE_DIR)

if(xxHash_FOUND AND NOT TARGET xxHash::xxhash)
    add_library(xxHash::xxhash UNKNOWN IMPORTED)
    set_target_properties(xxHash::xxhash PROPERTIES
        IMPORTED_LOCATION "${XXHASH_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${XXHASH_INCLUDE_DIR}")
endif()

mark_as_advanced(XXHASH_INCLUDE_DIR XXHASH_LIBRARY)
