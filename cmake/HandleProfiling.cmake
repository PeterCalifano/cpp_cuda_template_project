# CMake configuration for profiling-friendly builds
# Provides ENABLE_PROFILING option and optional gperftools (tcmalloc/heap profiler) integration.
#
# When ENABLE_PROFILING=ON:
#   - Adds -fno-omit-frame-pointer so perf/callgrind produce useful call stacks
#   - Adds -fno-inline-functions to prevent inlining from obscuring call graphs
#   - Optionally links gperftools (tcmalloc + heap profiler) if found
#
# Usage in CMakeLists.txt:
#   include(cmake/HandleProfiling.cmake)
#   handle_profiling(TARGET <interface_target>)
#   target_link_libraries(my_lib PRIVATE <interface_target>)
#
# ACHTUNG! ENABLE_PROFILING adds -fno-omit-frame-pointer to all build types,
# including Release. This has a small (~1%) runtime cost but is required for
# perf, callgrind, and gperftools to produce accurate call stacks.

include_guard(GLOBAL)

option(ENABLE_PROFILING "Enable profiling-friendly build flags and optional gperftools" OFF)

function(handle_profiling)
    cmake_parse_arguments(PROF "" "TARGET" "" ${ARGN})

    if(NOT DEFINED PROF_TARGET)
        if(DEFINED LIB_NAMESPACE)
            set(PROF_TARGET "${LIB_NAMESPACE}_profiling_interface")
        else()
            set(PROF_TARGET "profiling_interface")
        endif()
    endif()

    if(TARGET ${PROF_TARGET})
        return()
    endif()

    add_library(${PROF_TARGET} INTERFACE)

    if(NOT ENABLE_PROFILING)
        message(STATUS "Profiling support: OFF (set ENABLE_PROFILING=ON to enable)")
        return()
    endif()

    message(STATUS "Profiling support: ON")

    # Core flags: keep frame pointers and function symbols visible to profilers.
    # -fno-omit-frame-pointer: required for perf/callgrind/gperftools stack unwinding.
    # -fno-inline-functions: optional but prevents inlining from hiding hot paths.
    target_compile_options(${PROF_TARGET} INTERFACE
        -fno-omit-frame-pointer
        -fno-inline-functions
    )

    # Optional: gperftools (tcmalloc + heap profiler / CPU profiler)
    find_package(GooglePerftools QUIET)
    if(NOT GooglePerftools_FOUND)
        # Fall back to the legacy FindGooglePerfTools module in cmake/
        find_package(GooglePerfTools QUIET)
    endif()

    if(GOOGLE_PERFTOOLS_FOUND)
        message(STATUS "  gperftools (tcmalloc): ${TCMALLOC_LIBRARY}")
        target_include_directories(${PROF_TARGET} INTERFACE ${GOOGLE_PERFTOOLS_INCLUDE_DIR})
        target_link_libraries(${PROF_TARGET} INTERFACE ${TCMALLOC_LIBRARIES})
        target_compile_definitions(${PROF_TARGET} INTERFACE PROFILING_GPERFTOOLS_ENABLED)
    else()
        message(STATUS "  gperftools not found — using system allocator (install libgoogle-perftools-dev to enable)")
    endif()

    # Export the target name to parent scope so callers can link against it
    set(PROFILING_TARGET ${PROF_TARGET} PARENT_SCOPE)
endfunction()
