include_guard(GLOBAL)
include(CMakeParseArguments)

# DEfault path to OptiX SDK (empty)
set(OPTIX_ROOT "" CACHE PATH "OptiX SDK root (contains include/)")

function(handle_optix)

    # Add function arguments
    set(options)
    set(oneValueArgs TARGET CUDA_TARGET)
    cmake_parse_arguments(HOPT "${options}" "${oneValueArgs}" "" ${ARGN})

    # Define target for compile settings (OptiX specific, empty interface by default)
    if(NOT HOPT_TARGET)
        set(HOPT_TARGET optix_compile_interface)
    endif()
    if(NOT TARGET ${HOPT_TARGET})
        add_library(${HOPT_TARGET} INTERFACE)
    endif()

    set(OPTIX_FOUND OFF PARENT_SCOPE)
    set(optix_LIBRARY "" PARENT_SCOPE)

    if(NOT ENABLE_OPTIX)
        return() # Return if OptiX not enabled
    endif()

    if(NOT ENABLE_CUDA)
        message(FATAL_ERROR "ENABLE_OPTIX requires ENABLE_CUDA=ON.")
    endif()

    set(_optix_root "")

    ### Select OptiX root directory
    # If USE_SYS_OPTIX_SDK is ON, use system-installed OptiX (from ENV{OPTIX_HOME})
    # Else if ENV{OPTIX_HOME} is defined, but USE_SYS_OPTIX_SDK and OPTIX_ROOT are not, use that anyway
    # Else if OPTIX_ROOT is defined, use that
    # Else try default path relative to this file
    if(USE_SYS_OPTIX_SDK OR (DEFINED ENV{OPTIX_HOME} AND NOT OPTIX_ROOT))
        if(DEFINED ENV{OPTIX_HOME})
            set(_optix_root "$ENV{OPTIX_HOME}")
        else()
            message(FATAL_ERROR "USE_SYS_OPTIX_SDK is enabled but OPTIX_HOME is not defined.")
        endif()
    elseif(OPTIX_ROOT)
        set(_optix_root "${OPTIX_ROOT}")
    else()
        set(_default_root "${CMAKE_CURRENT_LIST_DIR}/../lib/NVIDIA-OptiX-SDK-8.0.0-linux64-x86_64")
        if(EXISTS "${_default_root}")
            set(_optix_root "${_default_root}")
        endif()
    endif()

    if(NOT _optix_root OR NOT EXISTS "${_optix_root}/include")
        message(FATAL_ERROR "OptiX SDK not found. Set OPTIX_ROOT or OPTIX_HOME.")
    endif()

    if(NOT OPTIX_ROOT)
        set(OPTIX_ROOT "${_optix_root}" CACHE PATH "OptiX SDK root")
    endif()

    # Include SDK directories (typically used) TBC
    set(_optix_includes
        "${_optix_root}/include"
        "${_optix_root}/SDK"
        "${_optix_root}/SDK/sutil"
        "${_optix_root}/SDK/support"
        "${_optix_root}/SDK/optixConsole"
    )
    foreach(_dir IN LISTS _optix_includes)
        if(NOT EXISTS "${_dir}")
            list(REMOVE_ITEM _optix_includes "${_dir}")
        endif()
    endforeach()

    # Add include dirs and definitions to the target
    target_include_directories(${HOPT_TARGET} INTERFACE ${_optix_includes})
    target_compile_definitions(${HOPT_TARGET} INTERFACE __OPTIX_ENABLED__=1)

    if(HOPT_CUDA_TARGET)
        target_include_directories(${HOPT_CUDA_TARGET} INTERFACE ${_optix_includes})
        target_compile_definitions(${HOPT_CUDA_TARGET} INTERFACE __OPTIX_ENABLED__=1)
    endif()

    message(STATUS "OptiX enabled")
    message(STATUS "OPTIX_ROOT: ${_optix_root}")
    message(STATUS "OPTIX_INCLUDE_DIRS: ${_optix_includes}")

    find_library(_optix_library optix
        PATHS "${_optix_root}/lib64" "${_optix_root}/lib"
        NO_DEFAULT_PATH
    )
    if(NOT _optix_library)
        find_library(_optix_library optix)
    endif()
    if(_optix_library)
        target_link_libraries(${HOPT_TARGET} INTERFACE "${_optix_library}")
    endif()

    set(OPTIX_INCLUDE_DIRS "${_optix_includes}" PARENT_SCOPE)
    set(OPTIX_FOUND ON PARENT_SCOPE)
    set(optix_LIBRARY "${_optix_library}" PARENT_SCOPE)
endfunction()
