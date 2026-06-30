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
    message(FATAL_ERROR "Expected file does not exist: ${file_path}")
  endif()
endfunction()

function(_assert_not_exists file_path)
  if(EXISTS "${file_path}")
    message(FATAL_ERROR "Unexpected file exists: ${file_path}")
  endif()
endfunction()

function(_write_build_tree_consumer source_dir)
  file(REMOVE_RECURSE "${source_dir}")
  file(MAKE_DIRECTORY "${source_dir}")

  file(WRITE "${source_dir}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(template_project_build_tree_consumer LANGUAGES CXX)
find_package(template_project CONFIG REQUIRED)
add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE template_project::template_project)
")

  file(WRITE "${source_dir}/main.cpp"
"#include <template_src/placeholder.h>

static_assert(__cplusplus >= 202002L);

int main()
{
    placeholder::placeholder_fcn();
    return 0;
}
")
endfunction()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}")

set(_build_dir "${TEST_BINARY_ROOT}/template_build")
set(_install_dir "${TEST_BINARY_ROOT}/template_install")
set(_consumer_source_dir "${TEST_BINARY_ROOT}/consumer_source")
set(_consumer_build_dir "${TEST_BINARY_ROOT}/consumer_build")

_run_step(
    "Configure template build-tree package"
    ${CMAKE_COMMAND}
        -S "${TEST_TEMPLATE_SOURCE_DIR}"
        -B "${_build_dir}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DCMAKE_INSTALL_PREFIX=${_install_dir}
        -DENABLE_TESTS=OFF
        -DENABLE_FETCH_CATCH2=OFF
        -DENABLE_SPDLOG=OFF
        -DENABLE_FETCH_SPDLOG=OFF
        -DENABLE_CUDA=OFF
        -Dtemplate_project_BUILD_PROGRAMS=OFF
        -Dtemplate_project_BUILD_EXAMPLES=OFF)

foreach(_package_file
    "template_projectConfig.cmake"
    "template_projectConfigVersion.cmake"
    "template_projectTarget.cmake")
  _assert_exists("${_build_dir}/${_package_file}")
  _assert_not_exists("${_build_dir}/src/${_package_file}")
endforeach()

file(READ "${_build_dir}/template_projectConfig.cmake" _config_contents)
if(NOT _config_contents MATCHES "include\\(\"\\$\\{CMAKE_CURRENT_LIST_DIR\\}/template_projectTarget\\.cmake\"\\)")
  message(FATAL_ERROR "Build-tree config does not include the target export beside itself.")
endif()

file(READ "${_build_dir}/template_projectTarget.cmake" _target_contents)
if(NOT _target_contents MATCHES "INTERFACE_COMPILE_FEATURES \"cxx_std_20\"")
  message(FATAL_ERROR "Build-tree target export does not propagate cxx_std_20.")
endif()
if(NOT _target_contents MATCHES "template_project::template_project")
  message(FATAL_ERROR "Build-tree target export does not define the namespaced package target.")
endif()

_run_step("Build template library" ${CMAKE_COMMAND} --build "${_build_dir}")

_write_build_tree_consumer("${_consumer_source_dir}")
_run_step(
    "Configure build-tree package consumer"
    ${CMAKE_COMMAND}
        -S "${_consumer_source_dir}"
        -B "${_consumer_build_dir}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -Dtemplate_project_DIR=${_build_dir})
_run_step("Build build-tree package consumer" ${CMAKE_COMMAND} --build "${_consumer_build_dir}")
