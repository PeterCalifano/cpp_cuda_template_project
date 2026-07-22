cmake_minimum_required(VERSION 3.15)

foreach(required_var
    TEST_TEMPLATE_SOURCE_DIR
    TEST_BINARY_ROOT
    TEST_PROJECT_NAME
    TEST_CORE_TARGET
    TEST_CUDA_ARCHITECTURES
    TEST_OPTIX_ROOT)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

if(NOT EXISTS "${TEST_OPTIX_ROOT}/include/optix.h")
  message(FATAL_ERROR "TEST_OPTIX_ROOT does not contain include/optix.h: ${TEST_OPTIX_ROOT}")
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

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
set(_build_dir "${TEST_BINARY_ROOT}/build")
set(_install_prefix "${TEST_BINARY_ROOT}/install")

_run_step(
    "Configure isolated OptiX package build"
    ${CMAKE_COMMAND}
        -S "${TEST_TEMPLATE_SOURCE_DIR}"
        -B "${_build_dir}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DCMAKE_INSTALL_PREFIX=${_install_prefix}
        "-DCMAKE_CUDA_ARCHITECTURES=${TEST_CUDA_ARCHITECTURES}"
        -DCPU_ENABLE_NATIVE_TUNING=OFF
        -DENABLE_CUDA=ON
        -DENABLE_OPTIX=ON
        -DOPTIX_AUTO_INSTALL=OFF
        "-DOPTIX_ROOT=${TEST_OPTIX_ROOT}"
        -DENABLE_OPENGL=OFF
        -DENABLE_TBB=OFF
        -DENABLE_TESTS=OFF
        -DENABLE_FETCH_CATCH2=OFF
        -Dtemplate_project_BUILD_PROGRAMS=OFF
        -Dtemplate_project_BUILD_EXAMPLES=OFF
        -Dtemplate_project_BUILD_PYTHON_WRAPPER=OFF
        -Dtemplate_project_BUILD_MATLAB_WRAPPER=OFF)

_run_step(
    "Build isolated OptiX core target"
    ${CMAKE_COMMAND}
        --build "${_build_dir}"
        --target "${TEST_CORE_TARGET}")
_run_step("Install isolated OptiX package" ${CMAKE_COMMAND} --install "${_build_dir}")

file(GLOB_RECURSE _target_exports "${_install_prefix}/*Target.cmake")
list(FILTER _target_exports INCLUDE REGEX "/${TEST_PROJECT_NAME}Target\\.cmake$")
list(LENGTH _target_exports _target_export_count)
if(NOT _target_export_count EQUAL 1)
  message(FATAL_ERROR
      "Expected one installed target export for ${TEST_PROJECT_NAME}, got: ${_target_exports}")
endif()
list(GET _target_exports 0 _target_export)
file(READ "${_target_export}" _target_export_contents)

string(FIND "${_target_export_contents}" "${TEST_OPTIX_ROOT}" _local_optix_path_index)
if(NOT _local_optix_path_index EQUAL -1)
  message(FATAL_ERROR
      "Installed target export contains the build machine's OptiX SDK path: ${_target_export}")
endif()
if(_target_export_contents MATCHES "include/optix")
  message(FATAL_ERROR
      "Installed target export requires a package-local include/optix directory that is not installed: "
      "${_target_export}")
endif()

set(_consumer_source_dir "${TEST_BINARY_ROOT}/consumer")
set(_consumer_build_dir "${TEST_BINARY_ROOT}/consumer-build")
file(MAKE_DIRECTORY "${_consumer_source_dir}")
file(WRITE "${_consumer_source_dir}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.15)
project(template_optix_install_consumer LANGUAGES CXX)
find_package(@TEST_PROJECT_NAME@ CONFIG REQUIRED)
add_executable(template_optix_install_consumer main.cpp)
target_link_libraries(
    template_optix_install_consumer
    PRIVATE @TEST_PROJECT_NAME@::@TEST_PROJECT_NAME@)
]=])
file(READ "${_consumer_source_dir}/CMakeLists.txt" _consumer_cmake)
string(REPLACE "@TEST_PROJECT_NAME@" "${TEST_PROJECT_NAME}" _consumer_cmake "${_consumer_cmake}")
file(WRITE "${_consumer_source_dir}/CMakeLists.txt" "${_consumer_cmake}")
file(WRITE "${_consumer_source_dir}/main.cpp" [=[
#include <optix.h>

int main()
{
    return OPTIX_VERSION > 0 ? 0 : 1;
}
]=])

_run_step(
    "Configure installed OptiX consumer"
    ${CMAKE_COMMAND}
        -S "${_consumer_source_dir}"
        -B "${_consumer_build_dir}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DCMAKE_PREFIX_PATH=${_install_prefix}
        "-DOPTIX_ROOT=${TEST_OPTIX_ROOT}")
_run_step(
    "Build installed OptiX consumer"
    ${CMAKE_COMMAND} --build "${_consumer_build_dir}")
