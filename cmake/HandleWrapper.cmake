# CMake configuration to handle Python and MATLAB wrapper configuration
include_guard(GLOBAL)

include(ExternalProject)
function(set_python_target_properties PYTHON_TARGET OUTPUT_NAME OUTPUT_DIRECTORY)
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
endfunction()

### Python and MATLAB wrapper configuration using gtwrap
# Function for common wrapper configuration
function(configure_gtwrappers_common)
  set(_gtwrap_python_option "${LIB_NAMESPACE}_BUILD_PYTHON_WRAPPER")
  set(_gtwrap_matlab_option "${LIB_NAMESPACE}_BUILD_MATLAB_WRAPPER")
  set(_gtwrap_interface_var "${LIB_NAMESPACE}_WRAPPER_INTERFACE_FILES")

  if (NOT DEFINED ${_gtwrap_interface_var})
    set(${_gtwrap_interface_var} "" CACHE STRING "Wrapper interface files")
  endif()

  message(STATUS "Configuring common gtwrap settings...")

  # Define the wrap directory
  set(_lib_wrap_dir "${CMAKE_CURRENT_SOURCE_DIR}/lib/wrap")

  if (NOT GTSAM_FOUND)
    message(STATUS "Attempt to find GTSAM package for wrapper configuration. This is required to build python and MATLAB bindings using gtwrap.")
    find_package(GTSAM 4.0 REQUIRED) # GTSAM types are required for wrappers TBC
  endif()

  # Set the default Python version to use for wrapping
  set(WRAP_PYTHON_VERSION ${PROJECT_PYTHON_VERSION}
    CACHE STRING "The Python version to use for wrapping")

  # Look for gtwrap
  find_package(gtwrap QUIET)

  # Check if wrap subdirectory exists, else fetch it from github as submodule
  if (NOT EXISTS "${_lib_wrap_dir}" AND NOT gtwrap_FOUND)

      message(STATUS "Wrap subdirectory not found. Attempting to fetch it from GitHub...")
      
      # Clone the wrap repository as a submodule
      execute_process(COMMAND git submodule add "git@github.com:PeterCalifano/wrap.git" 
                      WORKING_DIRECTORY ${_lib_wrap_dir}
                      RESULT_VARIABLE git_wrap_clone_submodule_result_)

      if(NOT git_wrap_clone_submodule_result_ EQUAL "0")
          message(FATAL_ERROR "Failed to add wrap submodule from GitHub. Please make sure git is installed and you have network access.")
      endif()
                      
      # Clone the submodule contents
      execute_process(COMMAND git checkout cpp_cuda_templ_reference_tag
                      WORKING_DIRECTORY ${_lib_wrap_dir}
                      RESULT_VARIABLE git_wrap_checkout_result_
                      )

      if(NOT git_wrap_checkout_result_ EQUAL "0")
          message(FATAL_ERROR "Failed to checkout the correct wrap submodule tag from GitHub. Please make sure git is installed and you have network access.")
      endif()

      if (NOT EXISTS "${_lib_wrap_dir}/.git")
      # Throw an error if the submodule was not fetched successfully
          message(FATAL_ERROR "Failed to fetch wrap subdirectory from GitHub. Something may have gone wrong in the configuration. Please report issue.")
      else()
          message(STATUS "Wrap subdirectory fetched successfully.")
      endif()

      # Add subdirectory to build it
      list(APPEND CMAKE_PREFIX_PATH ${_lib_wrap_dir})
      add_subdirectory(${_lib_wrap_dir})
      set(gtwrap_FOUND TRUE) # Mark as found
  else()
      message(STATUS "GTwrap package OR Wrap subdirectory found. Proceeding to build wrappers...")
  endif()

  # Set the include directory for matlab.h
  list(APPEND CMAKE_MODULE_PATH "${_lib_wrap_dir}/cmake")
  include_directories(${_lib_wrap_dir}/include)

  # DEFINE interface files for wrapper
  set(SEARCH_DIR_WRAP
      "${CMAKE_CURRENT_SOURCE_DIR}/src")

  # TODO update to recursive search if ${_gtwrap_interface_var} not set manually (no input)
  #message(STATUS "Searching for wrapper interface files in: ${SEARCH_DIR_WRAP}")
  #file(GLOB ${_gtwrap_interface_var} "${SEARCH_DIR_WRAP}" "*.i") # Not working for now

  # Template: set(${_gtwrap_interface_var} "${SEARCH_DIR_WRAP}/<name>.i") # Add the interface files here
  message(STATUS "Found wrapper interface files: ${${_gtwrap_interface_var}}")

  if (NOT ${_gtwrap_interface_var})
    message(WARNING "No wrapper interface files specified. Wrappers will be disabled.")
    set(${_gtwrap_interface_var} "")
    set(${_gtwrap_python_option} OFF "Disable Python wrapper build due to missing interface files." )
    set(${_gtwrap_matlab_option} OFF "Disable Matlab wrapper build due to missing interface files.")
  else()
    # Check if list has exactly one element that is empty
    list(LENGTH ${_gtwrap_interface_var} WRAPPER_INTERFACE_FILES_LEN)
    if (WRAPPER_INTERFACE_FILES_LEN EQUAL 1)
      list(GET ${_gtwrap_interface_var} 0 _first_interface)
      if (_first_interface STREQUAL "")
        message(WARNING "No interface files found for wrapping. Wrappers will be disabled.")
        set(${_gtwrap_python_option} OFF CACHE BOOL "Disable Python wrapper build due to missing interface files." FORCE)
        set(${_gtwrap_matlab_option} OFF CACHE BOOL "Disable Matlab wrapper build due to missing interface files." FORCE)
      endif()
    endif()
  endif()

  # Copy matlab.h to the correct folder.
  configure_file(${_lib_wrap_dir}/matlab.h
              ${PROJECT_BINARY_DIR}/wrap/matlab.h COPYONLY)

endfunction()

# TODO review code to make it general / test it
# Python wrapper configuration using gtwrap
function(configure_python_gtwrapper)
  ## Install Python wrap
  message(STATUS "Configuring Python wrap...")

  set(PROJECT_PYTHON_SOURCE_DIR ${PROJECT_SOURCE_DIR}/python)
  set(PROJECT_PYTHON_BUILD_DIRECTORY ${PROJECT_BINARY_DIR}/python)

  # Generate setup.py from template # TODO update, new version using pyproject toml
  file(READ "${PROJECT_SOURCE_DIR}/README.md" README_CONTENTS)
  configure_file(${PROJECT_PYTHON_SOURCE_DIR}/setup.py.in
                ${PROJECT_PYTHON_BUILD_DIRECTORY}/setup.py)

  set(interface_files ${PROJECT_SOURCE_DIR}/cpp/${PROJECT_NAME}.h)

  include(PybindWrap)

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

  set(_gtwrap_interface_var "${LIB_NAMESPACE}_WRAPPER_INTERFACE_FILES")
  pybind_wrap(${PROJECT_PYTHON_TARGET_NAME} # target
            "${${_gtwrap_interface_var}}" # list of interface header files
            "${PROJECT_PYTHON_TARGET_NAME}.cpp" # the generated cpp
            "${PROJECT_NAME}" # module_name
            "gtsam" # top namespace in the cpp file e.g. gtsam
            "${ignore}" # ignore classes
            ${PROJECT_BINARY_DIR}/${PROJECT_NAME}.tpl # the wrapping template file
            ${PROJECT_NAME} # libs
            "gtsam; gtsam_spaceNav" # dependencies
            ${ENABLE_BOOST_SERIALIZATION} # use boost serialization
            )

  set_python_target_properties(${PROJECT_PYTHON_TARGET_NAME} ${project_name} "${PROJECT_PYTHON_BUILD_DIRECTORY}/${project_name}")

  # Copy all python files to build folder.
  copy_directory("${CMAKE_CURRENT_SOURCE_DIR}/${project_name}"
          "${PROJECT_PYTHON_BUILD_DIRECTORY}/${project_name}")

  set(PROJECT_PYTHON_DEPS ${project_name} gtsam)

  # TODO move this to a cmake scripts file and add custom targets to install python package. Also make sure path to python exists and available and NOT python system-wide.
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
endfunction()

# MATLAB wrapper configuration using gtwrap
function(configure_matlab_gtwrapper )
  message(STATUS "Configuring MATLAB wrap...")
  include(MatlabWrap)

  # Configure MATLAB paths
  message (STATUS "Including MATLAB directories...")
  find_package(Matlab REQUIRED)
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
  set(_gtwrap_interface_var "${LIB_NAMESPACE}_WRAPPER_INTERFACE_FILES")
  wrap_and_install_library("${${_gtwrap_interface_var}}" "${project_name}" "" "" "" "" OFF)
endfunction()

function(handle_gtwrappers)
  set(_gtwrap_python_option "${LIB_NAMESPACE}_BUILD_PYTHON_WRAPPER")
  set(_gtwrap_matlab_option "${LIB_NAMESPACE}_BUILD_MATLAB_WRAPPER")

  if (NOT DEFINED ${_gtwrap_python_option})
    set(${_gtwrap_python_option} OFF)
  endif()
  if (NOT DEFINED ${_gtwrap_matlab_option})
    set(${_gtwrap_matlab_option} OFF)
  endif()

  if(NOT ${_gtwrap_python_option} AND NOT ${_gtwrap_matlab_option})
    # Return if none of the wrappers are to be built
    return()
  endif()

  # Configure common gtwrap settings
  configure_gtwrappers_common()

  # Configure python wrapper if requested
  if(${_gtwrap_python_option})
    configure_python_gtwrapper()
  endif()

  # Configure matlab wrapper if requested
  if(${_gtwrap_matlab_option})
    configure_matlab_gtwrapper()
  endif()
endfunction()


### Python wrapper configuration using pybind11 directly
# TODO
function(handle_pybind11_wrapper)


endfunction()
