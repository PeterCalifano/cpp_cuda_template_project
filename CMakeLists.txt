# VERSION CONTROL 
cmake_minimum_required(VERSION 3.15 FATAL_ERROR)
set(PROJECT_PYTHON_VERSION 3.11)
set(MATLAB_DEFAULT_RELEASE "R2023b")

#set(CMAKE_C_COMPILER gcc-11)
#set(CMAKE_CXX_COMPILER g++-11)
#set(CMAKE_CUDA_COMPILER nvcc)

# PROJECT DEFINITION
set(project_name "template_project")

# Set install default directory if not specified
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/install CACHE PATH "Install path" FORCE)
endif()

# Major options
option(ENABLE_OPTIX "Enable OptiX" OFF)
option(ENABLE_CUDA "Enable CUDA" OFF)
include(cmake/HandleOpenMP.cmake)

set(languages CXX) # ACHTUNG: PTX code requires C language!

if (ENABLE_OPTIX)
  set(ENABLE_CUDA ON)
endif()

if (ENABLE_CUDA)
    list(APPEND languages CUDA)
    if (ENABLE_OPTIX)
      list(APPEND languages C)
    endif()
endif()

# Add cmake folder to path
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

# Add git version handling
include(cmake/HandleGitVersion.cmake)

# Set version number
set(PROJECT_VERSION_MAJOR 0)
set(PROJECT_VERSION_MINOR 0)
set(PROJECT_VERSION_PATCH 0)

# Get version from git if possible
get_version_from_git()

project( ${project_name} 
        LANGUAGES ${languages}
        VERSION ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH})

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING "Build type (Debug, Release, RelWithDebInfo, MinSizeRel, NOPTIM)" FORCE)
endif()
string(TOLOWER "${CMAKE_BUILD_TYPE}" CMAKE_BUILD_TYPE_LOWER)

# Guard against in-source builds
if(${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})
  message(FATAL_ERROR "In-source builds not allowed. Please make a new directory (called a build directory) and run CMake from there. You may need to remove CMakeCache.txt. ")
endif()

# Add GNU install dirs
include(GNUInstallDirs)

# Add CUDA/OptiX tools
include(cmake/HandleCUDA.cmake)
include(cmake/HandleOptiX.cmake)

# OPTIONS
option(ENABLE_TESTS              "Build and run tests" ON)
option(ENABLE_FETCH_CATCH2 "Fetch Catch2 from GitHub if not found" ON)
option(VERBOSE "Verbose output" OFF) # Defines VERBOSE flag in code if set to ON

option(BUILD_PYTHON_WRAPPER "Build Python wrapper" OFF)
option(BUILD_MATLAB_WRAPPER "Build MATLAB wrapper" OFF)
option(NO_OPTIMIZATION "Disable optimization flags" OFF)
option(WARNINGS_ARE_ERRORS "Treat warnings as errors" OFF)
option(USE_SYS_OPTIX_SDK "Use Optix system folder if specified" OFF)
option(SANITIZE_BUILD "Enable sanitizers in build" OFF)
set(SANITIZERS "address,undefined,leak" CACHE STRING "Sanitizers to enable when SANITIZE_BUILD is ON (comma-separated)")
set(PYTHON_EXECUTABLE "python3") # Specify the Python executable to use

# Set C++ standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# TIP: if different options need to be specified for different targets of the build, use INTERFACE targets

# COMPILER FLAGS
set(_common_c_warnings -Wall -Wextra)
set(_common_cxx_warnings ${_common_c_warnings} -Wsuggest-override)

set(_debug_flags -Og -g -fmax-errors=3)
set(_debug_sanitizers)
if(SANITIZE_BUILD AND SANITIZERS)
  set(_debug_sanitizers -fsanitize=${SANITIZERS})
endif()
set(_release_flags -O3 -fmax-errors=1)
set(_relwithdebinfo_flags -O2 -g)
set(_noptim_flags -O0 -g)
set(_safety_warnings -Wnull-dereference -Wfloat-equal -fdelete-null-pointer-checks -Wconversion)

set(_debug_c_flags ${_debug_flags} ${_common_c_warnings} ${_debug_sanitizers})
set(_debug_cxx_flags ${_debug_flags} ${_common_cxx_warnings} ${_debug_sanitizers})
set(_release_c_flags ${_release_flags} ${_common_c_warnings})
set(_release_cxx_flags ${_release_flags} ${_common_cxx_warnings})
set(_relwithdebinfo_c_flags ${_relwithdebinfo_flags} ${_common_c_warnings} ${_safety_warnings})
set(_relwithdebinfo_cxx_flags ${_relwithdebinfo_flags} ${_common_cxx_warnings} ${_safety_warnings} -Wnon-virtual-dtor)
set(_noptim_c_flags ${_noptim_flags} ${_common_c_warnings} ${_safety_warnings})
set(_noptim_cxx_flags ${_noptim_flags} ${_common_cxx_warnings} ${_safety_warnings} -Wnon-virtual-dtor)

string(JOIN " " CMAKE_C_FLAGS_DEBUG ${_debug_c_flags})
string(JOIN " " CMAKE_CXX_FLAGS_DEBUG ${_debug_cxx_flags})
string(JOIN " " CMAKE_C_FLAGS_RELEASE ${_release_c_flags})
string(JOIN " " CMAKE_CXX_FLAGS_RELEASE ${_release_cxx_flags})
string(JOIN " " CMAKE_C_FLAGS_RELWITHDEBINFO ${_relwithdebinfo_c_flags})
string(JOIN " " CMAKE_CXX_FLAGS_RELWITHDEBINFO ${_relwithdebinfo_cxx_flags})
string(JOIN " " CMAKE_C_FLAGS_NOPTIM ${_noptim_c_flags})
string(JOIN " " CMAKE_CXX_FLAGS_NOPTIM ${_noptim_cxx_flags})

# Handle OpenMP
handle_openmp()

# Handle sanitizers
include(cmake/HandleSanitizers.cmake)
handle_sanitizers()

if (WARNINGS_ARE_ERRORS)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Werror")
    message(WARNING "ACHTUNG! Warnings will be treated treated as errors.")
endif()

message(STATUS "==============================================================")
message(STATUS "====================  Dependencies ===========================")

# Add submodules if any found
include(cmake/HandleSubmodules.cmake)
handle_submodules() # Automatically adds subdirectories in lib/ (and build them if CMakeLists.txt found)

# LIBRARY DEPENDENCIES DEFINITION
find_package( Eigen3 3.4 REQUIRED )
find_package( Doxygen QUIET)
include(cmake/HandleOpenGL.cmake)
handle_opengl(TARGET opengl_compile_interface)

# Handle Catch2 tools
include(cmake/HandleCatch2.cmake)

# Include cmake tools (depends on Catch2)
include(cmake/cmake_utils.cmake)

# Configure CUDA/OptiX (creates interface targets even when disabled)
handle_cuda(TARGET cuda_compile_interface 
            MIN_VERSION 12.0)
handle_optix(TARGET optix_compile_interface 
            CUDA_TARGET cuda_compile_interface)

# Set the dependencies for the automated export
set(EXPORT_TARGET_DEPS Eigen3) # TODO make automatic based on used packages

if(ENABLE_CUDA)
  list(APPEND EXPORT_TARGET_DEPS CUDAToolkit)
endif()
message(STATUS "Target dependencies: ${EXPORT_TARGET_DEPS}")

#find_package( GTSAM 4.0 REQUIRED )
#find_package( GTSAM_UNSTABLE REQUIRED)
#find_package( sopengv )
#find_package( OpenCV core imgproc highgui features2d calib3d video)
#find_package( DBoW2 )
#find_package( Pangolin )
#find_package( jsoncpp )
#find_package( rapid_yaml)

# Interface target for C++ flags
add_library(lib_compile_interface INTERFACE)

if (CMAKE_BUILD_TYPE_LOWER MATCHES "debug")
  # Set compile flags
  set(CMAKE_C_FLAGS ${CMAKE_CXX_FLAGS_DEBUG})
  set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS_DEBUG})

  # Set compile options for the interface target
  set(_sanitizer_flags)
  if(SANITIZE_BUILD AND SANITIZERS)
    set(_sanitizer_flags -fsanitize=${SANITIZERS})
  endif()
  target_compile_options(lib_compile_interface INTERFACE
                      ${_sanitizer_flags}
                      -fno-omit-frame-pointer
  )

  target_link_options(lib_compile_interface INTERFACE
                      ${_sanitizer_flags}
                      -fno-omit-frame-pointer
  )

elseif (CMAKE_BUILD_TYPE_LOWER MATCHES "release" AND NOT NO_OPTIMIZATION)
  # Set compile flags
  set(CMAKE_C_FLAGS ${CMAKE_CXX_FLAGS_RELEASE})
  set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS_RELEASE})

elseif (CMAKE_BUILD_TYPE_LOWER MATCHES "relwithdebinfo" AND NOT NO_OPTIMIZATION) 
  # Set compile flags
  set(CMAKE_C_FLAGS ${CMAKE_CXX_FLAGS_RELWITHDEBINFO})
  set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS_RELWITHDEBINFO})

elseif (NO_OPTIMIZATION)
  set(CMAKE_C_FLAGS ${CMAKE_CXX_FLAGS_NOPTIM})
  set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS_NOPTIM})
  target_compile_definitions(lib_compile_interface INTERFACE NDEBUG)

else()
  # Stop build
  message(FATAL_ERROR "Unknown build type: ${CMAKE_BUILD_TYPE}. Stopping build.")
endif()

# Add catch2 for unit testing
find_package(OpenCV QUIET)

# Create the installation target list 
set(installable_targets)

# TIP: To set target compilation options (or any other thing) that must be specific for a target or propagated, use the following cmake pattern (example). Requires cmake 3.15 or later. Here flag BUILD_INTERFACE regulates whether the compile flags are added to the target_compile_options. If true, they are added.
#add_library(library_compile_flags INTERFACE)
#target_compile_options(library_compile_flags INTERFACE 
#"$<${gcc_like_cxx}: $<BUILD_INTERFACE: -Wall;-Wextra;-Wshadow;-Wformat=2;-Wunused>>")
#target_link_libraries(library_target PUBLIC any_other_target library_compile_flags)

# Define include target interface
add_library(${project_name}_include INTERFACE)

# Define include directories for install compatibility
target_include_directories(${project_name}_include INTERFACE 
                           $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>  # Used during development
                           #$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/stb_PeterCdev>  
                           #$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/rapidyaml_PeterCdev>
                           #$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/gdt>
                           #$<BUILD_INTERFACE:${CUDA_INCLUDE_DIRS}> 
                           #$<BUILD_INTERFACE:${OPTIX_INCLUDE_DIR}>   
                           #$<BUILD_INTERFACE:${OpenCV_INCLUDE_DIRS}>  # Add OpenCV include directories
                           $<INSTALL_INTERFACE:include/${project_name}>  # Used in installed projects
)

# Build/install tree for runtime programs: $ORIGIN/../lib
target_link_options(${project_name}_include INTERFACE
                    $<$<PLATFORM_ID:Linux>:-Wl,-rpath,\$ORIGIN/../lib>
                  )

# Install-tree exes look next to themselves
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)

# Add other subdirectories if needed
#add_subdirectory( other_folder )

message(STATUS "===================================================================")
message(STATUS "====================  Library composition  ========================")

# Add library
add_subdirectory( src )

# Add examples to build
add_subdirectory( examples )

# Add tests to build
if (ENABLE_TESTS AND Catch2_FOUND)
  add_subdirectory( tests )
endif()

# Add documentation
set(DOC_SUBDIRS "${${project_name}_INCLUDE_DIRS}")
if (DOXYGEN_FOUND)
    add_subdirectory( "doc" )
else()
    message(STATUS "Doxygen not found. Skipping building documentation.") 
endif()

# Print configuration variables
message(STATUS "===============================================================")
message(STATUS "================  Configuration Options  ======================")
message(STATUS "LIBRARY NAME                              : ${project_name}")
# CXX compiler
message(STATUS "CMAKE_CXX_COMPILER                        : ${CMAKE_CXX_COMPILER}")
message(STATUS "CMAKE_CXX_COMPILER_ID type                : ${CMAKE_CXX_COMPILER_ID}")
message(STATUS "CMAKE_CXX_COMPILER_VERSION                : ${CMAKE_CXX_COMPILER_VERSION}")

if (ENABLE_OPTIX)
  # C compiler
  message(STATUS "CMAKE_C_COMPILER                          : ${CMAKE_C_COMPILER}")
  message(STATUS "CMAKE_C_COMPILER_ID type                  : ${CMAKE_C_COMPILER_ID}")
  message(STATUS "CMAKE_C_COMPILER_VERSION                  : ${CMAKE_C_COMPILER_VERSION}")
endif()

# CUDA arch and compiler
if (ENABLE_CUDA)
  message(STATUS "CUDA enabled                             : ${ENABLE_CUDA}")
  message(STATUS "CUDA architecture                        : ${cuda_arch}")
  message(STATUS "CUDA architecture sm version             : ${sm_version}")
  message(STATUS "CMAKE_CUDA_COMPILER                      : ${CMAKE_CUDA_COMPILER}")
  message(STATUS "CMAKE_CUDA_COMPILER_ID type              : ${CMAKE_CUDA_COMPILER_ID}")
  message(STATUS "CMAKE_CUDA_COMPILER_VERSION              : ${CMAKE_CUDA_COMPILER_VERSION}")
endif()

# Installation
message(STATUS "CMAKE_INSTALL_PREFIX                      : ${CMAKE_INSTALL_PREFIX}")
message(STATUS "CMAKE_INSTALL_LIBDIR                      : ${CMAKE_INSTALL_LIBDIR}")
message(STATUS "CMAKE_INSTALL_INCLUDEDIR                  : ${CMAKE_INSTALL_INCLUDEDIR}")
message(STATUS "CMAKE_INSTALL_BINDIR                      : ${CMAKE_INSTALL_BINDIR}")

# Build type
if(NOT MSVC AND NOT XCODE_VERSION)
  message(STATUS "Build type                                : ${CMAKE_BUILD_TYPE}")  
  message(STATUS "Optimization override:                    : ${NO_OPTIMIZATION}")  

  if(CMAKE_BUILD_TYPE MATCHES Debug)
    message(STATUS "  C compilation flags                     : ${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_DEBUG}")
    message(STATUS "  C++ compilation flags                   : ${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_DEBUG}")
  elseif (CMAKE_BUILD_TYPE MATCHES Release)
    message(STATUS "  C compilation flags                     : ${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_RELEASE}")
    message(STATUS "  C++ compilation flags                   : ${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_RELEASE}")
  elseif (CMAKE_BUILD_TYPE MATCHES RelWithDebInfo)
    message(STATUS "  C compilation flags                     : ${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_RELWITHDEBINFO}")
    message(STATUS "  C++ compilation flags                   : ${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")
  elseif (NO_OPTIMIZATION)
    message(STATUS "  C compilation flags                     : ${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_NOPTIM}")
    message(STATUS "  C++ compilation flags                   : ${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_NOPTIM}")
  else()
    message(STATUS "  C compilation flags                     : ${CMAKE_C_FLAGS}")
    message(STATUS "  C++ compilation flags                   : ${CMAKE_CXX_FLAGS}")
  endif()

endif()
message(STATUS "===============================================================")

###########################################################################
### WRAPPERS CONFIGURATION
# Handle wrappers
# TODO requires some updates
if(BUILD_PYTHON_WRAPPER OR BUILD_MATLAB_WRAPPER)

  if (NOT GTSAM_FOUND)
    find_package( GTSAM 4.0 REQUIRED ) # GTSAM types are required for wrappers
  endif() 

  # Set the default Python version to use for wrapping
  set(WRAP_PYTHON_VERSION ${PROJECT_PYTHON_VERSION}
    CACHE STRING "The Python version to use for wrapping")

  # Look for gtwrap
  find_package(gtwrap QUIET)

  # Check if wrap subdirectory exists, else fetch it from github as submodule
  if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/wrap") 

      message(STATUS "Wrap subdirectory not found. Attempting to fetch it from GitHub...")
      execute_process(COMMAND git submodule add "git@github.com:PeterCalifano/wrap.git"
                      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
      execute_process(COMMAND git submodule update --init --recursive
                      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

      if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/wrap")
      # Throw an error if the submodule was not fetched successfully
          message(FATAL_ERROR "Failed to fetch wrap subdirectory from GitHub!")
      else()
          message(STATUS "Wrap subdirectory fetched successfully.")
      endif()
      
  else()
      message(STATUS "GTwrap package OR Wrap subdirectory found. Proceeding to build wrappers...")
  endif()

  # Set the include directory for matlab.h
  set(GTWRAP_INCLUDE_NAME ${PROJECT_SOURCE_DIR})
  include_directories(${GTWRAP_INCLUDE_NAME})

  # DEFINE interface files for wrapper
  set(SEARCH_DIR_WRAP 
      "${CMAKE_CURRENT_SOURCE_DIR}/src")
  
  #message(STATUS "Searching for wrapper interface files in: ${SEARCH_DIR_WRAP}")
  #file(GLOB WRAPPER_INTERFACE_FILES "${SEARCH_DIR_WRAP}" "*.i") # Not working for now

  # Template: set(WRAPPER_INTERFACE_FILES "${SEARCH_DIR_WRAP}/<name>.i") # Add the interface files here
  message(STATUS "Found wrapper interface files: ${WRAPPER_INTERFACE_FILES}")

  if (NOT WRAPPER_INTERFACE_FILES)
    message(FATAL_ERROR "WRAPPER_INTERFACE_FILES list not defined. Please check the cmake configuration.")
  else()
    # Check if list has exactly one element that is empty
    list(LENGTH WRAPPER_INTERFACE_FILES WRAPPER_INTERFACE_FILES_LEN)
    if (WRAPPER_INTERFACE_FILES_LEN EQUAL 1)
      list(GET WRAPPER_INTERFACE_FILES 0 _first_interface)
      if (_first_interface STREQUAL "")
        message(FATAL_ERROR "No interface files found for wrapping. Please check the search directory or provide files.")
      endif()
    endif()
  endif()

  # Copy matlab.h to the correct folder.
  configure_file(${PROJECT_SOURCE_DIR}/wrap/matlab.h
              ${PROJECT_BINARY_DIR}/wrap/matlab.h COPYONLY)

  if (NOT gtwrap_FOUND) # Build GTwrap within project
    message(STATUS "GTwrap package NOT found. Attempting to build it as ExternalProject...")
  
    include(ExternalProject)

    ExternalProject_Add(
      wrap_project
      SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/wrap
      CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${WRAP_INSTALL_DIR}
      BUILD_ALWAYS OFF  # Optional: rebuild every time (remove for performance)
    )

    # Add the install directory to CMake's module path
    list(APPEND CMAKE_PREFIX_PATH ${WRAP_INSTALL_DIR})

    message(STATUS "GTwrap package correctly built and added to CMAKE_PREFIX_PATH.")
    add_subdirectory(wrap)
    list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/wrap/cmake")

    # Python toolbox
    if(BUILD_PYTHON_WRAPPER)
      if ("${PYTHON_EXECUTABLE}" STREQUAL "python3")
          message(WARNING "PYTHON_EXECUTABLE is set to python3. This will likely fail at install time if no venv is activated. Please specify the full path to the python executable if conda.")
      endif()
    endif()

    # Matlab toolbox
    if(BUILD_MATLAB_WRAPPER)
        # Check if matlab folder exists
        #if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/matlab")
        #    message(FATAL_ERROR "MATLAB wrapper requested but matlab folder not found.")
        #endif()
        #add_subdirectory(matlab)
    endif()
  endif()

  # Python toolbox
  if(BUILD_PYTHON_WRAPPER)
    # TODO review code to make it general
    ## Install Python wrap
    message(STATUS "Configuring Python wrap...")

    set(PROJECT_PYTHON_SOURCE_DIR ${PROJECT_SOURCE_DIR}/python)
    set(PROJECT_PYTHON_BUILD_DIRECTORY ${PROJECT_BINARY_DIR}/python)

    # Generate setup.py from template # TODO see gtsam/python/CMakeLists.txt for how to do this
    file(READ "${PROJECT_SOURCE_DIR}/README.md" README_CONTENTS)
    configure_file(${PROJECT_PYTHON_SOURCE_DIR}/setup.py.in
                  ${PROJECT_PYTHON_BUILD_DIRECTORY}/setup.py)

    set(interface_files ${PROJECT_SOURCE_DIR}/cpp/${PROJECT_NAME}.h)

    include(PybindWrap)
    
    # TODO move this macro somewhere else
    macro(SET_PYTHON_TARGET_PROPERTIES PYTHON_TARGET OUTPUT_NAME OUTPUT_DIRECTORY)
    set_target_properties(${PYTHON_TARGET} PROPERTIES
        INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib"
        INSTALL_RPATH_USE_LINK_PATH TRUE
        OUTPUT_NAME "${OUTPUT_NAME}"
        LIBRARY_OUTPUT_DIRECTORY "${OUTPUT_DIRECTORY}"
        DEBUG_POSTFIX "" # Otherwise you will have a wrong name
        RELWITHDEBINFO_POSTFIX "" # Otherwise you will have a wrong name
        TIMING_POSTFIX "" # Otherwise you will have a wrong name
        PROFILING_POSTFIX "" # Otherwise you will have a wrong name
    )
    endmacro()

    # This is required to avoid an error in modern pybind11 cmake scripts:
    if(POLICY CMP0057)
        cmake_policy(SET CMP0057 NEW)
    endif()

    # Use bundled pybind11 version (in wrap)
    add_subdirectory(${PROJECT_SOURCE_DIR}/wrap/pybind11 pybind11)

    # Set the wrapping script variable
    set(PYBIND_WRAP_SCRIPT "${PROJECT_SOURCE_DIR}/wrap/scripts/pybind_wrap.py")

    set(ENABLE_BOOST_SERIALIZATION OFF)
    set(PROJECT_PYTHON_TARGET_NAME ${project_name}_py)

    pybind_wrap(${PROJECT_PYTHON_TARGET_NAME} # target
              "${WRAPPER_INTERFACE_FILES}" # list of interface header files
              "${PROJECT_PYTHON_TARGET_NAME}.cpp" # the generated cpp
              "${PROJECT_NAME}" # module_name
              "gtsam" # top namespace in the cpp file e.g. gtsam
              "${ignore}" # ignore classes
              ${PROJECT_BINARY_DIR}/${PROJECT_NAME}.tpl # the wrapping template file
              ${PROJECT_NAME} # libs
              "gtsam; gtsam_spaceNav" # dependencies
              ${ENABLE_BOOST_SERIALIZATION} # use boost serialization
              )

    SET_PYTHON_TARGET_PROPERTIES(${PROJECT_PYTHON_TARGET_NAME} ${project_name} "${PROJECT_PYTHON_BUILD_DIRECTORY}/${project_name}")

    # Copy all python files to build folder.
    copy_directory("${CMAKE_CURRENT_SOURCE_DIR}/${project_name}"
            "${PROJECT_PYTHON_BUILD_DIRECTORY}/${project_name}")

    set(PROJECT_PYTHON_DEPS ${project_name} gtsam)


    # TODO move this to a cmake scripts file
    # Add custom targets to install python package
    add_custom_target(
            python-stubs
            COMMAND
              ${CMAKE_COMMAND} -E env
              "PYTHONPATH=${PROJECT_PYTHON_BUILD_DIRECTORY}/$ENV{PYTHONPATH}"
            ${PYTHON_EXECUTABLE} -m pybind11_stubgen -o . --ignore ${ignore} #--ignore-all-errors
            DEPENDS ${PROJECT_PYTHON_DEPS} ${PROJECT_PYTHON_TARGET_NAME}
            WORKING_DIRECTORY "${PROJECT_PYTHON_BUILD_DIRECTORY}/"
    )

    add_custom_target(python-install
        COMMAND ${PYTHON_EXECUTABLE} -c "import sys, subprocess; cmd = [sys.executable, '-m', 'pip', 'install']; has_venv = hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix); cmd.append('--user' if not has_venv else ''); cmd.append('.'); subprocess.check_call([c for c in cmd if c])"
        DEPENDS ${PROJECT_PYTHON_DEPS}
        WORKING_DIRECTORY ${PROJECT_PYTHON_BUILD_DIRECTORY}
        VERBATIM)

  endif()

  # Matlab toolbox
  if(BUILD_MATLAB_WRAPPER)
    message(STATUS "Configuring MATLAB wrap...")
    include( MatlabWrap ) 

    # Configure MATLAB paths
    message (STATUS "Including MATLAB directories...")
    find_package (Matlab REQUIRED)
    set(MATLAB_MEX_INCLUDE "${Matlab_ROOT_DIR}/extern/include")

    message(STATUS "MATLAB_MEX_INCLUDE directory: ${MATLAB_MEX_INCLUDE}")
    message(STATUS "Matlab_MEX_LIBRARY directory: ${Matlab_MEX_LIBRARY}")
    message(STATUS "Matlab_MX_LIBRARY directory: ${Matlab_MX_LIBRARY}")

    # Set the include directories
    include_directories(${Matlab_INCLUDE_DIRS})
    include_directories(${MATLAB_MEX_INCLUDE})

    if ( NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/matlab" )
      # Make directory
      file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/matlab")
    endif()

    # Set up installation paths (#TODO need to review these options)
    set(WRAP_MEX_BUILD_STATIC_MODULE OFF) # Defines if the mex module is built as a static module
    #set(WRAP_BUILD_MEX_BINARY_FLAGS ${GTSAM_BUILD_MEX_BINARY_FLAGS})
    set(WRAP_TOOLBOX_INSTALL_PATH "${CMAKE_CURRENT_SOURCE_DIR}/matlab") # Defines the installation path for the MATLAB wrapper files
    #set(WRAP_CUSTOM_MATLAB_PATH ${GTSAM_CUSTOM_MATLAB_PATH})
    set(WRAP_BUILD_TYPE_POSTFIXES OFF) # Determines if post build type postfixes are added to the mex files 

    # Add the MATLAB wrapper
    wrap_and_install_library("${WRAPPER_INTERFACE_FILES}" "${project_name}" "" "" "" "" OFF)
  endif()
  
endif()

# AUXILIARY 
# Set dashboard properties (needed for CDash)
set(CTEST_PROJECT_NAME ${project_name})
set(CTEST_NIGHTLY_START_TIME "00:00:00 CET")

# Set the dashboard drop method and location
#set(CTEST_DROP_METHOD "http")
#set(CTEST_DROP_SITE "my.cdash.org")
#set(CTEST_DROP_LOCATION "/submit.php?project=CMakeTutorial")
#set(CTEST_DROP_SITE_CDASH TRUE)

# PACKAGING CONFIGURATION 
include(InstallRequiredSystemLibraries)
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
set(CPACK_PACKAGE_VERSION_MAJOR "${PROJECT_VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR "${PROJECT_VERSION_MINOR}")
set(CPACK_GENERATOR "TGZ")
set(CPACK_SOURCE_GENERATOR "TGZ")
include(CPack)
