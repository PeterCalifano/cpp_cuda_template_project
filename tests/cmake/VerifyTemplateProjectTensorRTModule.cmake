cmake_minimum_required(VERSION 3.15)

# Verify portable TensorRT discovery and module delivery without requiring a
# real SDK or linking vendor binaries.
foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

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

function(_run_failure step_name)
  execute_process(
      COMMAND ${ARGN}
      RESULT_VARIABLE _result
      OUTPUT_VARIABLE _stdout
      ERROR_VARIABLE _stderr)
  if(_result EQUAL 0)
    message(FATAL_ERROR
        "${step_name} unexpectedly succeeded.\n"
        "stdout:\n${_stdout}\n"
        "stderr:\n${_stderr}")
  endif()
endfunction()

function(_configure_consumer step_name module_dir build_dir root_argument
         sdk_root architecture)
  _run_step(
      "${step_name}"
      "${CMAKE_COMMAND}"
          -S "${_consumer_source}"
          -B "${build_dir}"
          "-DTEST_TENSORRT_MODULE_DIR=${module_dir}"
          "-DTEST_TENSORRT_ROOT=${sdk_root}"
          "-DTEST_TENSORRT_ARCH=${architecture}"
          "-D${root_argument}=${sdk_root}")
endfunction()

function(_configure_handler step_name build_dir enabled)
  _run_step(
      "${step_name}"
      "${CMAKE_COMMAND}"
          -S "${_handler_source}"
          -B "${build_dir}"
          "-DTEST_ENABLE_TENSORRT=${enabled}"
          "-DTEST_TENSORRT_ROOT=${_tensorrt_root}")
endfunction()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
set(_tensorrt_arch "aarch64-linux-gnu")
set(_tensorrt_root "${TEST_BINARY_ROOT}/TensorRT")
set(_tensorrt_include
    "${_tensorrt_root}/targets/${_tensorrt_arch}/include")
set(_tensorrt_lib "${_tensorrt_root}/targets/${_tensorrt_arch}/lib")
set(_tensorrt_x86_arch "x86_64-linux-gnu")
set(_tensorrt_x86_root "${TEST_BINARY_ROOT}/TensorRT-x86")
set(_tensorrt_x86_include
    "${_tensorrt_x86_root}/targets/${_tensorrt_x86_arch}/include")
set(_tensorrt_x86_lib
    "${_tensorrt_x86_root}/targets/${_tensorrt_x86_arch}/lib")
set(_consumer_source "${TEST_BINARY_ROOT}/consumer")
set(_handler_source "${TEST_BINARY_ROOT}/handler")
file(MAKE_DIRECTORY
    "${_tensorrt_include}"
    "${_tensorrt_lib}"
    "${_tensorrt_x86_include}"
    "${_tensorrt_x86_lib}"
    "${_consumer_source}"
    "${_handler_source}")

file(WRITE "${_tensorrt_include}/NvInfer.h" "#pragma once\n")
file(WRITE "${_tensorrt_include}/NvInferVersion.h"
"#define NV_TENSORRT_MAJOR 10
#define NV_TENSORRT_MINOR 7
#define NV_TENSORRT_PATCH 0
#define NV_TENSORRT_BUILD 1
")
file(WRITE "${_tensorrt_lib}/libnvinfer.so" "fixture\n")
file(WRITE "${_tensorrt_lib}/libnvinfer_plugin.so" "fixture\n")
file(WRITE "${_tensorrt_x86_include}/NvInfer.h" "#pragma once\n")
file(WRITE "${_tensorrt_x86_include}/NvInferVersion.h"
"#define NV_TENSORRT_MAJOR 10
#define NV_TENSORRT_MINOR 7
#define NV_TENSORRT_PATCH 0
#define NV_TENSORRT_BUILD 1
")
file(WRITE "${_tensorrt_x86_lib}/libnvinfer.so" "fixture\n")
file(WRITE "${_tensorrt_x86_lib}/libnvinfer_plugin.so" "fixture\n")

# Exercise the handler contract without enabling the CUDA language or linking
# fixture libraries. The root integration separately owns language selection.
file(WRITE "${_handler_source}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(tensorrt_handler_consumer LANGUAGES NONE)
set(CMAKE_LIBRARY_ARCHITECTURE \"${_tensorrt_arch}\")
set(CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH FALSE)
set(CMAKE_FIND_USE_CMAKE_SYSTEM_PATH FALSE)
list(APPEND CMAKE_MODULE_PATH
     \"${TEST_TEMPLATE_SOURCE_DIR}/cmake\"
     \"${TEST_BINARY_ROOT}/caller_modules\")
set(_caller_module_path \"\${CMAKE_MODULE_PATH}\")
include(\"${TEST_TEMPLATE_SOURCE_DIR}/cmake/HandleTensorRT.cmake\")

set(ENABLE_TENSORRT \"\${TEST_ENABLE_TENSORRT}\")
set(ENABLE_CUDA \"\${TEST_ENABLE_TENSORRT}\")
if(TEST_ENABLE_TENSORRT)
  add_library(CUDA::cudart INTERFACE IMPORTED)
  set(TensorRT_ROOT \"\${TEST_TENSORRT_ROOT}\")
endif()

handle_tensorrt(TARGET fixture_tensorrt_interface)

if(NOT CMAKE_MODULE_PATH STREQUAL _caller_module_path)
  message(FATAL_ERROR \"HandleTensorRT changed the caller module path.\")
endif()
if(NOT TARGET fixture_tensorrt_interface)
  message(FATAL_ERROR \"HandleTensorRT did not create its interface target.\")
endif()

get_target_property(_definitions fixture_tensorrt_interface INTERFACE_COMPILE_DEFINITIONS)
get_target_property(_links fixture_tensorrt_interface INTERFACE_LINK_LIBRARIES)
if(TEST_ENABLE_TENSORRT)
  if(NOT \"__TENSORRT_ENABLED__=1\" IN_LIST _definitions)
    message(FATAL_ERROR \"Enabled handler omitted __TENSORRT_ENABLED__=1: \${_definitions}\")
  endif()
  foreach(_required_target IN ITEMS TensorRT::nvinfer TensorRT::nvinfer_plugin CUDA::cudart)
    if(NOT \"\${_required_target}\" IN_LIST _links)
      message(FATAL_ERROR \"Enabled handler omitted \${_required_target}: \${_links}\")
    endif()
  endforeach()
else()
  if(_definitions OR _links)
    message(FATAL_ERROR
        \"Disabled handler propagated TensorRT usage requirements: \"
        \"definitions='\${_definitions}', links='\${_links}'\")
  endif()
endif()
")

_configure_handler(
    "Configure disabled TensorRT handler"
    "${TEST_BINARY_ROOT}/handler_disabled"
    OFF)
_configure_handler(
    "Configure enabled TensorRT handler"
    "${TEST_BINARY_ROOT}/handler_enabled"
    ON)

file(WRITE "${_consumer_source}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(tensorrt_module_consumer LANGUAGES NONE)
set(CMAKE_LIBRARY_ARCHITECTURE \"\${TEST_TENSORRT_ARCH}\")
set(CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH FALSE)
set(CMAKE_FIND_USE_CMAKE_SYSTEM_PATH FALSE)
list(PREPEND CMAKE_MODULE_PATH \"\${TEST_TENSORRT_MODULE_DIR}\")
find_package(TensorRT 10.7 REQUIRED)
if(NOT TARGET TensorRT::nvinfer OR NOT TARGET TensorRT::nvinfer_plugin)
  message(FATAL_ERROR \"TensorRT imported targets are unavailable.\")
endif()
if(NOT TensorRT_VERSION STREQUAL \"10.7.0.1\")
  message(FATAL_ERROR \"Unexpected TensorRT version: \${TensorRT_VERSION}\")
endif()
set(_expected_include
    \"\${TEST_TENSORRT_ROOT}/targets/\${TEST_TENSORRT_ARCH}/include\")
if(NOT TensorRT_INCLUDE_DIRS STREQUAL _expected_include)
  message(FATAL_ERROR \"Unexpected TensorRT includes: \${TensorRT_INCLUDE_DIRS}\")
endif()
list(LENGTH TensorRT_LIBRARIES _library_count)
if(NOT _library_count EQUAL 2)
  message(FATAL_ERROR \"Unexpected TensorRT libraries: \${TensorRT_LIBRARIES}\")
endif()
")

# Accept the canonical package-name hint and the established all-uppercase
# compatibility spelling against a non-x86 SDK layout.
_configure_consumer(
    "Discover source TensorRT module through TensorRT_ROOT"
    "${TEST_TEMPLATE_SOURCE_DIR}/cmake"
    "${TEST_BINARY_ROOT}/consumer_source_canonical"
    TensorRT_ROOT
    "${_tensorrt_root}"
    "${_tensorrt_arch}")
_configure_consumer(
    "Discover source TensorRT module through TENSORRT_ROOT"
    "${TEST_TEMPLATE_SOURCE_DIR}/cmake"
    "${TEST_BINARY_ROOT}/consumer_source_compatibility"
    TENSORRT_ROOT
    "${_tensorrt_root}"
    "${_tensorrt_arch}")
_configure_consumer(
    "Discover source TensorRT module in x86_64 archive layout"
    "${TEST_TEMPLATE_SOURCE_DIR}/cmake"
    "${TEST_BINARY_ROOT}/consumer_source_x86"
    TensorRT_ROOT
    "${_tensorrt_x86_root}"
    "${_tensorrt_x86_arch}")

set(_template_build "${TEST_BINARY_ROOT}/template_build")
set(_template_install "${TEST_BINARY_ROOT}/template_install")
_run_step(
    "Configure template for TensorRT module delivery"
    "${CMAKE_COMMAND}"
        -S "${TEST_TEMPLATE_SOURCE_DIR}"
        -B "${_template_build}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_LIBDIR=lib
        -DENABLE_TESTS=OFF
        -DENABLE_FETCH_CATCH2=OFF
        -Dtemplate_project_ENABLE_CUDA=OFF
        -Dtemplate_project_BUILD_PROGRAMS=OFF
        -Dtemplate_project_BUILD_EXAMPLES=OFF)
_run_step(
    "Build template for TensorRT module delivery"
    "${CMAKE_COMMAND}" --build "${_template_build}" --parallel 4)
_run_step(
    "Install template TensorRT module"
    "${CMAKE_COMMAND}" --install "${_template_build}" --prefix "${_template_install}")

set(_build_module_dir "${_template_build}/modules")
set(_install_module_dir
    "${_template_install}/lib/cmake/template_project/modules")
foreach(_module_dir IN ITEMS "${_build_module_dir}" "${_install_module_dir}")
  if(NOT EXISTS "${_module_dir}/FindTensorRT.cmake")
    message(FATAL_ERROR "TensorRT module was not delivered to ${_module_dir}.")
  endif()
endforeach()

_configure_consumer(
    "Discover build-tree TensorRT module"
    "${_build_module_dir}"
    "${TEST_BINARY_ROOT}/consumer_build_tree"
    TensorRT_ROOT
    "${_tensorrt_root}"
    "${_tensorrt_arch}")
_configure_consumer(
    "Discover installed TensorRT module"
    "${_install_module_dir}"
    "${TEST_BINARY_ROOT}/consumer_install_tree"
    TensorRT_ROOT
    "${_tensorrt_root}"
    "${_tensorrt_arch}")

# Poison the delivered finders after their standalone checks. A default package
# consumer must not include them or acquire TensorRT targets when the feature
# was disabled in the producing build.
foreach(_module_dir IN ITEMS "${_build_module_dir}" "${_install_module_dir}")
  file(WRITE "${_module_dir}/FindTensorRT.cmake"
      "message(FATAL_ERROR \"Disabled package loaded FindTensorRT.cmake\")\n")
endforeach()
set(_disabled_package_consumer "${TEST_BINARY_ROOT}/disabled_package_consumer")
file(MAKE_DIRECTORY "${_disabled_package_consumer}")
file(WRITE "${_disabled_package_consumer}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(tensorrt_disabled_package_consumer LANGUAGES NONE)
set(CMAKE_MODULE_PATH \"${TEST_BINARY_ROOT}/disabled_caller_modules\")
set(_caller_module_path \"\${CMAKE_MODULE_PATH}\")
find_package(template_project CONFIG REQUIRED)
if(NOT CMAKE_MODULE_PATH STREQUAL _caller_module_path)
  message(FATAL_ERROR \"Disabled package changed the caller module path.\")
endif()
if(TARGET TensorRT::nvinfer OR TARGET TensorRT::nvinfer_plugin)
  message(FATAL_ERROR \"Disabled package resolved an unrequested TensorRT SDK.\")
endif()
")

set(_disabled_build_package "${_template_build}")
set(_disabled_install_package
    "${_template_install}/lib/cmake/template_project")
foreach(_package_kind IN ITEMS build install)
  if(_package_kind STREQUAL "build")
    set(_package_dir "${_disabled_build_package}")
  else()
    set(_package_dir "${_disabled_install_package}")
  endif()
  _run_step(
      "Configure ${_package_kind}-tree disabled TensorRT package consumer"
      "${CMAKE_COMMAND}"
          -S "${_disabled_package_consumer}"
          -B "${TEST_BINARY_ROOT}/disabled_package_consumer_${_package_kind}"
          "-Dtemplate_project_DIR=${_package_dir}")
endforeach()

# Configure the real package-config template in an enabled fixture. Its target
# export references the exact external targets that an installed project built
# with TensorRT requires.
set(_package_fixture_source "${TEST_BINARY_ROOT}/package_fixture")
set(_package_fixture_build "${TEST_BINARY_ROOT}/package_fixture_build")
set(_package_consumer_source "${TEST_BINARY_ROOT}/package_consumer")
file(MAKE_DIRECTORY "${_package_fixture_source}" "${_package_consumer_source}")
file(WRITE "${_package_fixture_source}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(tensorrt_package_fixture LANGUAGES NONE)
include(CMakePackageConfigHelpers)
set(PROJECT_NAME template_project)
set(EXPORT_TARGET_DEPS \"\")
set(ENABLE_OPTIX OFF)
set(ENABLE_TENSORRT ON)
set(OPTIX_COMPILE_TARGET unused_optix_interface)
configure_package_config_file(
    \"${TEST_TEMPLATE_SOURCE_DIR}/src/cmake/template_projectConfig.cmake.in\"
    \"\${CMAKE_CURRENT_BINARY_DIR}/template_projectConfig.cmake\"
    INSTALL_DESTINATION lib/cmake/template_project)
")
_run_step(
    "Configure enabled TensorRT package fixture"
    "${CMAKE_COMMAND}"
        -S "${_package_fixture_source}"
        -B "${_package_fixture_build}")

set(_package_target_contents
"add_library(template_project::template_project INTERFACE IMPORTED)
add_library(template_project::template_project_tensorrt_compile_interface INTERFACE IMPORTED)
set_target_properties(
    template_project::template_project_tensorrt_compile_interface
    PROPERTIES
      INTERFACE_COMPILE_DEFINITIONS \"__TENSORRT_ENABLED__=1\"
      INTERFACE_LINK_LIBRARIES \"TensorRT::nvinfer;TensorRT::nvinfer_plugin;CUDA::cudart\")
set_target_properties(
    template_project::template_project
    PROPERTIES
      INTERFACE_LINK_LIBRARIES template_project::template_project_tensorrt_compile_interface)
")

set(_enabled_build_package "${TEST_BINARY_ROOT}/enabled_build_package")
set(_enabled_install_package
    "${TEST_BINARY_ROOT}/enabled_install/lib/cmake/template_project")
foreach(_package_dir IN ITEMS "${_enabled_build_package}" "${_enabled_install_package}")
  file(MAKE_DIRECTORY "${_package_dir}/modules")
  configure_file(
      "${_package_fixture_build}/template_projectConfig.cmake"
      "${_package_dir}/template_projectConfig.cmake"
      COPYONLY)
  configure_file(
      "${TEST_TEMPLATE_SOURCE_DIR}/cmake/FindTensorRT.cmake"
      "${_package_dir}/modules/FindTensorRT.cmake"
      COPYONLY)
  file(WRITE "${_package_dir}/template_projectTarget.cmake" "${_package_target_contents}")
endforeach()

file(WRITE "${_package_consumer_source}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(tensorrt_package_consumer LANGUAGES NONE)
set(CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH FALSE)
set(CMAKE_FIND_USE_CMAKE_SYSTEM_PATH FALSE)
set(CMAKE_MODULE_PATH \"${TEST_BINARY_ROOT}/caller_modules\")
set(_caller_module_path \"\${CMAKE_MODULE_PATH}\")
set(template_project_DIR \"\${TEST_PACKAGE_DIR}\")
set(TensorRT_ROOT \"\${TEST_TENSORRT_ROOT}\")
add_library(CUDA::cudart INTERFACE IMPORTED)

if(TEST_PACKAGE_REQUIRED)
  find_package(template_project CONFIG REQUIRED)
else()
  find_package(template_project CONFIG QUIET)
endif()

if(NOT CMAKE_MODULE_PATH STREQUAL _caller_module_path)
  message(FATAL_ERROR \"Package config changed the caller module path.\")
endif()
if(TEST_EXPECT_FOUND)
  if(NOT template_project_FOUND)
    message(FATAL_ERROR \"TensorRT-enabled package was not found.\")
  endif()
  foreach(_required_target IN ITEMS
      TensorRT::nvinfer
      TensorRT::nvinfer_plugin
      template_project::template_project
      template_project::template_project_tensorrt_compile_interface)
    if(NOT TARGET \"\${_required_target}\")
      message(FATAL_ERROR \"Package consumer is missing \${_required_target}.\")
    endif()
  endforeach()
elseif(template_project_FOUND)
  message(FATAL_ERROR \"TensorRT-enabled package ignored a missing SDK.\")
endif()
")

foreach(_package_kind IN ITEMS build install)
  if(_package_kind STREQUAL "build")
    set(_package_dir "${_enabled_build_package}")
  else()
    set(_package_dir "${_enabled_install_package}")
  endif()
  _run_step(
      "Configure ${_package_kind}-tree TensorRT package consumer"
      "${CMAKE_COMMAND}"
          -S "${_package_consumer_source}"
          -B "${TEST_BINARY_ROOT}/package_consumer_${_package_kind}"
          "-DTEST_PACKAGE_DIR=${_package_dir}"
          "-DTEST_TENSORRT_ROOT=${_tensorrt_root}"
          -DTEST_PACKAGE_REQUIRED=ON
          -DTEST_EXPECT_FOUND=ON)
endforeach()

set(_missing_tensorrt_root "${TEST_BINARY_ROOT}/missing_tensorrt")
_run_step(
    "Keep a missing TensorRT package quiet"
    "${CMAKE_COMMAND}"
        -S "${_package_consumer_source}"
        -B "${TEST_BINARY_ROOT}/package_consumer_missing_quiet"
        "-DTEST_PACKAGE_DIR=${_enabled_install_package}"
        "-DTEST_TENSORRT_ROOT=${_missing_tensorrt_root}"
        -DTEST_PACKAGE_REQUIRED=OFF
        -DTEST_EXPECT_FOUND=OFF)
_run_failure(
    "Reject a required package when TensorRT is missing"
    "${CMAKE_COMMAND}"
        -S "${_package_consumer_source}"
        -B "${TEST_BINARY_ROOT}/package_consumer_missing_required"
        "-DTEST_PACKAGE_DIR=${_enabled_install_package}"
        "-DTEST_TENSORRT_ROOT=${_missing_tensorrt_root}"
        -DTEST_PACKAGE_REQUIRED=ON
        -DTEST_EXPECT_FOUND=OFF)

# When a CUDA compiler is available, prove the complete root option, target,
# export, and consumer chain with valid local stub libraries.
find_program(_cuda_compiler NAMES nvcc)
find_program(_host_cxx_compiler NAMES c++ g++ clang++)
if(_cuda_compiler AND _host_cxx_compiler)
  set(_stub_source "${TEST_BINARY_ROOT}/tensorrt_stub.cpp")
  file(WRITE "${_stub_source}" "extern \"C\" int tensorrt_fixture_symbol() { return 0; }\n")
  foreach(_stub_name IN ITEMS nvinfer nvinfer_plugin)
    _run_step(
        "Build ${_stub_name} TensorRT fixture library"
        "${_host_cxx_compiler}" -shared -fPIC "${_stub_source}"
        -o "${_tensorrt_lib}/lib${_stub_name}.so")
  endforeach()

  set(_enabled_template_build "${TEST_BINARY_ROOT}/enabled_template_build")
  set(_enabled_template_install "${TEST_BINARY_ROOT}/enabled_template_install")
  _run_step(
      "Configure TensorRT-enabled template"
      "${CMAKE_COMMAND}"
          -S "${TEST_TEMPLATE_SOURCE_DIR}"
          -B "${_enabled_template_build}"
          -DCMAKE_BUILD_TYPE=Release
          -DCMAKE_INSTALL_LIBDIR=lib
          "-DCMAKE_INSTALL_PREFIX=${_enabled_template_install}"
          -DCMAKE_CUDA_ARCHITECTURES=75
          -DCPU_ENABLE_NATIVE_TUNING=OFF
          -DENABLE_TESTS=OFF
          -DENABLE_FETCH_CATCH2=OFF
          -Dtemplate_project_ENABLE_CUDA=OFF
          -Dtemplate_project_ENABLE_TENSORRT=ON
          "-DTensorRT_ROOT=${_tensorrt_root}"
          -Dtemplate_project_BUILD_PROGRAMS=OFF
          -Dtemplate_project_BUILD_EXAMPLES=OFF
          -Dtemplate_project_BUILD_PYTHON_WRAPPER=OFF
          -Dtemplate_project_BUILD_MATLAB_WRAPPER=OFF)
  _run_step(
      "Build TensorRT-enabled template"
      "${CMAKE_COMMAND}" --build "${_enabled_template_build}" --parallel 4)
  _run_step(
      "Install TensorRT-enabled template"
      "${CMAKE_COMMAND}" --install "${_enabled_template_build}")

  set(_enabled_consumer_source "${TEST_BINARY_ROOT}/enabled_consumer")
  file(MAKE_DIRECTORY "${_enabled_consumer_source}")
  file(WRITE "${_enabled_consumer_source}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(tensorrt_enabled_consumer LANGUAGES CXX)
set(CMAKE_MODULE_PATH \"${TEST_BINARY_ROOT}/root_consumer_modules\")
set(_caller_module_path \"\${CMAKE_MODULE_PATH}\")
find_package(template_project CONFIG REQUIRED)
if(NOT CMAKE_MODULE_PATH STREQUAL _caller_module_path)
  message(FATAL_ERROR \"TensorRT-enabled package changed the caller module path.\")
endif()
if(NOT TARGET template_project::template_project_tensorrt_compile_interface)
  message(FATAL_ERROR \"TensorRT-enabled package omitted its interface target.\")
endif()
add_executable(tensorrt_enabled_consumer main.cpp)
target_link_libraries(
    tensorrt_enabled_consumer PRIVATE template_project::template_project)
")
  file(WRITE "${_enabled_consumer_source}/main.cpp"
"#include <NvInfer.h>

#ifndef __TENSORRT_ENABLED__
#error \"TensorRT feature definition was not propagated\"
#endif

int main()
{
    return 0;
}
")

  set(_enabled_install_package_dir
      "${_enabled_template_install}/lib/cmake/template_project")
  foreach(_consumer_kind IN ITEMS build install)
    if(_consumer_kind STREQUAL "build")
      set(_template_package_dir "${_enabled_template_build}")
    else()
      set(_template_package_dir "${_enabled_install_package_dir}")
    endif()
    set(_enabled_consumer_build
        "${TEST_BINARY_ROOT}/enabled_consumer_${_consumer_kind}")
    _run_step(
        "Configure ${_consumer_kind}-tree enabled TensorRT consumer"
        "${CMAKE_COMMAND}"
            -S "${_enabled_consumer_source}"
            -B "${_enabled_consumer_build}"
            "-Dtemplate_project_DIR=${_template_package_dir}"
            "-DTensorRT_ROOT=${_tensorrt_root}")
    _run_step(
        "Build ${_consumer_kind}-tree enabled TensorRT consumer"
        "${CMAKE_COMMAND}" --build "${_enabled_consumer_build}" --parallel 4)
  endforeach()
else()
  message(STATUS
      "Skipping CUDA-enabled TensorRT root acceptance because nvcc or a host "
      "C++ compiler is unavailable.")
endif()
