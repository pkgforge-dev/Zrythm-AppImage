# Zrythm's JUCE is patched to drop its bundled HarfBuzz, and
# JUCE_INCLUDE_ZLIB_CODE=0 makes JUCE use the shared zlib. Link the libraries
# the AppImage already ships (libQt6Gui needs libharfbuzz as well).
add_compile_definitions(JUCE_INCLUDE_ZLIB_CODE=0)

function(_zrythm_use_system_libs)
    if(TARGET juce_lib)
        target_link_libraries(juce_lib PUBLIC harfbuzz z)
    endif()
endfunction()

cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL _zrythm_use_system_libs)
