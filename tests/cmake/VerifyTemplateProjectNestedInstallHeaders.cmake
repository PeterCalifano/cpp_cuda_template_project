cmake_minimum_required(VERSION 3.15)

foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

if(NOT EXISTS "${TEST_TEMPLATE_SOURCE_DIR}/CMakeLists.txt")
  message(FATAL_ERROR "Invalid template source dir: ${TEST_TEMPLATE_SOURCE_DIR}")
endif()

function(_run_step step_name)
  execute_process(
      COMMAND ${ARGN}
      RESULT_VARIABLE _result
      OUTPUT_VARIABLE _stdout
      ERROR_VARIABLE _stderr)

  if(NOT _result EQUAL 0)
    message(FATAL_ERROR
        "${step_name} failed with exit code ${_result}.\n"
        "stdout:\n${_stdout}\n"
        "stderr:\n${_stderr}")
  endif()
endfunction()

function(_assert_exists file_path)
  if(NOT EXISTS "${file_path}")
    message(FATAL_ERROR "Expected installed path does not exist: ${file_path}")
  endif()
endfunction()

function(_assert_not_exists file_path)
  if(EXISTS "${file_path}")
    message(FATAL_ERROR "Unexpected install-prefix path exists: ${file_path}")
  endif()
endfunction()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}/parent")

file(WRITE "${TEST_BINARY_ROOT}/parent/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(template_project_nested_install_parent LANGUAGES CXX)
set(ENABLE_TESTS OFF CACHE BOOL \"\" FORCE)
set(ENABLE_FETCH_CATCH2 OFF CACHE BOOL \"\" FORCE)
set(ENABLE_SPDLOG OFF CACHE BOOL \"\" FORCE)
set(ENABLE_FETCH_SPDLOG OFF CACHE BOOL \"\" FORCE)
set(ENABLE_CUDA OFF CACHE BOOL \"\" FORCE)
set(template_project_BUILD_PROGRAMS OFF CACHE BOOL \"\" FORCE)
set(template_project_BUILD_EXAMPLES OFF CACHE BOOL \"\" FORCE)
add_subdirectory(\"${TEST_TEMPLATE_SOURCE_DIR}\" \"\${CMAKE_CURRENT_BINARY_DIR}/template_subbuild\")
add_executable(parent_consumer parent_consumer.cpp)
target_link_libraries(parent_consumer PRIVATE template_project::template_project)
")

file(WRITE "${TEST_BINARY_ROOT}/parent/parent_consumer.cpp"
"#include <wrapped_impl/CWrapperPlaceholder.h>

int main()
{
    return cpp_playground::CWrapperPlaceholder::multiplyBy2(2.0) == 4.0 ? 0 : 1;
}
")

set(_parent_build "${TEST_BINARY_ROOT}/parent_build")
set(_install_prefix "${TEST_BINARY_ROOT}/install")
_run_step(
    "Configure parent nested install build"
    ${CMAKE_COMMAND}
        -S "${TEST_BINARY_ROOT}/parent"
        -B "${_parent_build}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DCMAKE_INSTALL_PREFIX=${_install_prefix})

# Refuse to execute install rules that traverse above the advertised include
# root. The current regression is expected to fail here before it can write
# outside the scratch install prefix.
file(GLOB_RECURSE _nested_install_scripts
    "${_parent_build}/template_subbuild/src/*/cmake_install.cmake")
if(NOT _nested_install_scripts)
  message(FATAL_ERROR "No nested module install scripts were generated")
endif()

foreach(_install_script IN LISTS _nested_install_scripts)
  file(READ "${_install_script}" _install_script_contents)
  string(FIND
      "${_install_script_contents}"
      "/include/template_project/.."
      _unsafe_destination_index)
  if(NOT _unsafe_destination_index EQUAL -1)
    message(FATAL_ERROR
        "Nested header install destination escapes include/template_project: "
        "${_install_script}")
  endif()
endforeach()

_run_step(
    "Build parent and nested template targets"
    ${CMAKE_COMMAND} --build "${_parent_build}" --target parent_consumer)
_run_step(
    "Install nested template package"
    ${CMAKE_COMMAND} --install "${_parent_build}")

set(_installed_headers
    "wrapped_impl/CWrapperPlaceholder.h"
    "template_src/placeholder.h"
    "template_src_kernels/placeholder.cuh"
    "utils/wrap_adapters/GtsamAliases.h")

foreach(_installed_header IN LISTS _installed_headers)
  _assert_exists(
      "${_install_prefix}/include/template_project/${_installed_header}")
endforeach()

foreach(_leaked_directory wrapped_impl template_src template_src_kernels utils)
  _assert_not_exists("${_install_prefix}/${_leaked_directory}")
endforeach()

# Exercise the optional logging module's real install rule without requiring a
# system spdlog package or a network fetch in this regression test.
set(_logging_probe_source "${TEST_BINARY_ROOT}/logging_install_probe")
set(_logging_probe_build "${TEST_BINARY_ROOT}/logging_install_probe_build")
set(_logging_install_prefix "${TEST_BINARY_ROOT}/logging_install")
file(MAKE_DIRECTORY "${_logging_probe_source}")
file(WRITE "${_logging_probe_source}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(template_project_logging_install_probe LANGUAGES NONE)
set(project_name template_project)
set(PROJECT_SOURCE_DIR \"${TEST_TEMPLATE_SOURCE_DIR}\")
add_subdirectory(
    \"${TEST_TEMPLATE_SOURCE_DIR}/src/utils/logging\"
    \"\${CMAKE_CURRENT_BINARY_DIR}/logging_subbuild\")
")

_run_step(
    "Configure optional logging header install probe"
    ${CMAKE_COMMAND}
        -S "${_logging_probe_source}"
        -B "${_logging_probe_build}"
        -DCMAKE_INSTALL_PREFIX=${_logging_install_prefix})

set(_logging_install_script
    "${_logging_probe_build}/logging_subbuild/cmake_install.cmake")
_assert_exists("${_logging_install_script}")
file(READ "${_logging_install_script}" _logging_install_script_contents)
string(FIND
    "${_logging_install_script_contents}"
    "/include/template_project/.."
    _unsafe_logging_destination_index)
if(NOT _unsafe_logging_destination_index EQUAL -1)
  message(FATAL_ERROR
      "Nested logging header install destination escapes "
      "include/template_project: ${_logging_install_script}")
endif()

_run_step(
    "Install optional logging module headers"
    ${CMAKE_COMMAND} --install "${_logging_probe_build}")
_assert_exists(
    "${_logging_install_prefix}/include/template_project/utils/logging/CLogger.h")
_assert_not_exists(
    "${_logging_install_prefix}/include/template_project/utils/logging/SpdlogUtils.h")
_assert_not_exists("${_logging_install_prefix}/utils")

set(_consumer_source "${TEST_BINARY_ROOT}/installed_consumer")
set(_consumer_build "${TEST_BINARY_ROOT}/installed_consumer_build")
set(_installed_package_dir
    "${_install_prefix}/lib/cmake/template_project")
file(MAKE_DIRECTORY "${_consumer_source}")

file(WRITE "${_consumer_source}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(template_project_installed_header_consumer LANGUAGES CXX)
find_package(template_project CONFIG REQUIRED)
add_executable(installed_consumer main.cpp)
target_link_libraries(installed_consumer PRIVATE template_project::template_project)
")

file(WRITE "${_consumer_source}/main.cpp"
"#include <wrapped_impl/CWrapperPlaceholder.h>

int main()
{
    return cpp_playground::CWrapperPlaceholder::multiplyBy2(3.0) == 6.0 ? 0 : 1;
}
")

_run_step(
    "Configure installed-only template consumer"
    ${CMAKE_COMMAND}
        -S "${_consumer_source}"
        -B "${_consumer_build}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -Dtemplate_project_DIR:PATH=${_installed_package_dir}
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF
        -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF)

file(STRINGS
    "${_consumer_build}/CMakeCache.txt"
    _resolved_package_dir_entry
    REGEX "^template_project_DIR:PATH=")
if(NOT _resolved_package_dir_entry STREQUAL
    "template_project_DIR:PATH=${_installed_package_dir}")
  message(FATAL_ERROR
      "Installed consumer resolved an unexpected template_project package: "
      "${_resolved_package_dir_entry}")
endif()

_run_step(
    "Build installed-only template consumer"
    ${CMAKE_COMMAND} --build "${_consumer_build}")
