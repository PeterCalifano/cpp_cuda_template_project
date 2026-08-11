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

function(_configure_consumer step_name module_dir build_dir root_argument)
  _run_step(
      "${step_name}"
      "${CMAKE_COMMAND}"
          -S "${_consumer_source}"
          -B "${build_dir}"
          "-DTEST_TENSORRT_MODULE_DIR=${module_dir}"
          "-D${root_argument}=${_tensorrt_root}")
endfunction()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
set(_tensorrt_arch "aarch64-linux-gnu")
set(_tensorrt_root "${TEST_BINARY_ROOT}/TensorRT")
set(_tensorrt_include
    "${_tensorrt_root}/targets/${_tensorrt_arch}/include")
set(_tensorrt_lib "${_tensorrt_root}/targets/${_tensorrt_arch}/lib")
set(_consumer_source "${TEST_BINARY_ROOT}/consumer")
file(MAKE_DIRECTORY
    "${_tensorrt_include}"
    "${_tensorrt_lib}"
    "${_consumer_source}")

file(WRITE "${_tensorrt_include}/NvInfer.h" "#pragma once\n")
file(WRITE "${_tensorrt_include}/NvInferVersion.h"
"#define NV_TENSORRT_MAJOR 10
#define NV_TENSORRT_MINOR 7
#define NV_TENSORRT_PATCH 0
#define NV_TENSORRT_BUILD 1
")
file(WRITE "${_tensorrt_lib}/libnvinfer.so" "fixture\n")
file(WRITE "${_tensorrt_lib}/libnvinfer_plugin.so" "fixture\n")

file(WRITE "${_consumer_source}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(tensorrt_module_consumer LANGUAGES NONE)
set(CMAKE_LIBRARY_ARCHITECTURE \"${_tensorrt_arch}\")
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
if(NOT TensorRT_INCLUDE_DIRS STREQUAL \"${_tensorrt_include}\")
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
    TensorRT_ROOT)
_configure_consumer(
    "Discover source TensorRT module through TENSORRT_ROOT"
    "${TEST_TEMPLATE_SOURCE_DIR}/cmake"
    "${TEST_BINARY_ROOT}/consumer_source_compatibility"
    TENSORRT_ROOT)

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
    TensorRT_ROOT)
_configure_consumer(
    "Discover installed TensorRT module"
    "${_install_module_dir}"
    "${TEST_BINARY_ROOT}/consumer_install_tree"
    TensorRT_ROOT)
