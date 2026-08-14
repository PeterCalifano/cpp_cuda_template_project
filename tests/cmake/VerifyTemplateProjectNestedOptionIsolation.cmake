cmake_minimum_required(VERSION 3.15)

# Verify nested project-option isolation and top-level legacy-option migration.
foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

if(NOT EXISTS "${TEST_TEMPLATE_SOURCE_DIR}/CMakeLists.txt")
  message(FATAL_ERROR
      "Invalid template source directory: ${TEST_TEMPLATE_SOURCE_DIR}")
endif()

function(_run_success step_name)
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

function(_read_cache_value cache_path cache_key out_var)
  file(STRINGS "${cache_path}" _cache_lines REGEX "^${cache_key}:")
  list(LENGTH _cache_lines _cache_line_count)
  if(NOT _cache_line_count EQUAL 1)
    message(FATAL_ERROR "Missing generated CMake cache field: ${cache_key}")
  endif()
  list(GET _cache_lines 0 _cache_line)
  string(REGEX REPLACE "^[^=]*=" "" _cache_value "${_cache_line}")
  set(${out_var} "${_cache_value}" PARENT_SCOPE)
endfunction()

function(_require_cache_value cache_path cache_key expected_value)
  _read_cache_value("${cache_path}" "${cache_key}" _actual_value)
  if(NOT _actual_value STREQUAL expected_value)
    message(FATAL_ERROR
        "Expected ${cache_key}=${expected_value}, got ${_actual_value}.")
  endif()
endfunction()

function(_require_cache_entry_absent cache_path cache_key)
  file(STRINGS "${cache_path}" _cache_lines REGEX "^${cache_key}:")
  if(_cache_lines)
    message(FATAL_ERROR
        "Legacy cache field ${cache_key} was not removed after migration.")
  endif()
endfunction()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
set(_parent_source "${TEST_BINARY_ROOT}/parent")
set(_parent_build "${TEST_BINARY_ROOT}/build")
file(MAKE_DIRECTORY "${_parent_source}")

# The parent deliberately owns conflicting generic values. Canonical template
# selectors keep the nested library active while disabling its GPU paths.
file(WRITE "${_parent_source}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(template_project_option_isolation_parent LANGUAGES CXX)

set(PROJECT_METADATA_ONLY ON CACHE BOOL \"Parent metadata selector\" FORCE)
set(ENABLE_CUDA ON CACHE BOOL \"Parent CUDA selector\" FORCE)
set(ENABLE_OPTIX ON CACHE BOOL \"Parent OptiX selector\" FORCE)
set(ENABLE_TENSORRT ON CACHE BOOL \"Parent TensorRT selector\" FORCE)

set(template_project_METADATA_ONLY OFF CACHE BOOL \"\" FORCE)
set(template_project_ENABLE_CUDA OFF CACHE BOOL \"\" FORCE)
set(template_project_ENABLE_OPTIX OFF CACHE BOOL \"\" FORCE)
set(template_project_ENABLE_TENSORRT OFF CACHE BOOL \"\" FORCE)
set(ENABLE_TESTS OFF CACHE BOOL \"\" FORCE)
set(ENABLE_FETCH_CATCH2 OFF CACHE BOOL \"\" FORCE)
set(template_project_BUILD_PROGRAMS OFF CACHE BOOL \"\" FORCE)
set(template_project_BUILD_EXAMPLES OFF CACHE BOOL \"\" FORCE)

add_subdirectory(
  \"${TEST_TEMPLATE_SOURCE_DIR}\"
  \"\${CMAKE_CURRENT_BINARY_DIR}/template_project_subbuild\"
  EXCLUDE_FROM_ALL)

if(NOT TARGET template_project::template_project)
  message(FATAL_ERROR \"Nested template target was not created.\")
endif()
if(DEFINED CMAKE_CUDA_COMPILER)
  message(FATAL_ERROR
      \"Nested template consumed the parent's generic ENABLE_CUDA option.\")
endif()
if(NOT PROJECT_METADATA_ONLY OR NOT ENABLE_CUDA OR NOT ENABLE_OPTIX OR NOT ENABLE_TENSORRT)
  message(FATAL_ERROR \"Nested template changed parent-owned generic options.\")
endif()
")

execute_process(
    COMMAND
      "${CMAKE_COMMAND}"
      -S "${_parent_source}"
      -B "${_parent_build}"
      -DCMAKE_BUILD_TYPE=Release
    RESULT_VARIABLE _configure_result
    OUTPUT_VARIABLE _configure_stdout
    ERROR_VARIABLE _configure_stderr)
if(NOT _configure_result EQUAL 0)
  message(FATAL_ERROR
      "Nested option-isolation configure failed with exit code "
      "${_configure_result}.\n"
      "stdout:\n${_configure_stdout}\n"
      "stderr:\n${_configure_stderr}")
endif()

# Compatibility aliases are one-config inputs. Reconfigure the same build to
# prove they update, rather than merely initialize, their canonical options.
set(_metadata_alias_build "${TEST_BINARY_ROOT}/metadata_alias_build")
_run_success(
    "Enable metadata-only mode through the legacy alias"
    "${CMAKE_COMMAND}"
    -S "${TEST_TEMPLATE_SOURCE_DIR}"
    -B "${_metadata_alias_build}"
    -Dtemplate_project_METADATA_ONLY=OFF
    -DPROJECT_METADATA_ONLY=ON)
set(_metadata_alias_cache "${_metadata_alias_build}/CMakeCache.txt")
_require_cache_value(
    "${_metadata_alias_cache}" "template_project_METADATA_ONLY" "ON")
_require_cache_entry_absent(
    "${_metadata_alias_cache}" "PROJECT_METADATA_ONLY")
file(STRINGS "${_metadata_alias_cache}" _metadata_cxx_compiler
    REGEX "^CMAKE_CXX_COMPILER:")
if(_metadata_cxx_compiler)
  message(FATAL_ERROR "Metadata-only alias unexpectedly enabled C++.")
endif()

_run_success(
    "Disable metadata-only mode through the legacy alias"
    "${CMAKE_COMMAND}"
    -S "${TEST_TEMPLATE_SOURCE_DIR}"
    -B "${_metadata_alias_build}"
    -Dtemplate_project_METADATA_ONLY=ON
    -DPROJECT_METADATA_ONLY=OFF
    -DENABLE_TESTS=OFF
    -DENABLE_FETCH_CATCH2=OFF
    -Dtemplate_project_BUILD_PROGRAMS=OFF
    -Dtemplate_project_BUILD_EXAMPLES=OFF)
_require_cache_value(
    "${_metadata_alias_cache}" "template_project_METADATA_ONLY" "OFF")
_require_cache_entry_absent(
    "${_metadata_alias_cache}" "PROJECT_METADATA_ONLY")
_read_cache_value(
    "${_metadata_alias_cache}" "CMAKE_CXX_COMPILER" _metadata_cxx_compiler)

# Keep language selection disabled while exercising GPU feature aliases; this
# validates cache migration without requiring their SDKs on a CPU runner.
set(_feature_alias_build "${TEST_BINARY_ROOT}/feature_alias_build")
_run_success(
    "Enable GPU features through legacy aliases"
    "${CMAKE_COMMAND}"
    -S "${TEST_TEMPLATE_SOURCE_DIR}"
    -B "${_feature_alias_build}"
    -Dtemplate_project_METADATA_ONLY=ON
    -Dtemplate_project_ENABLE_CUDA=OFF
    -Dtemplate_project_ENABLE_OPTIX=OFF
    -Dtemplate_project_ENABLE_TENSORRT=OFF
    -DENABLE_CUDA=ON
    -DENABLE_OPTIX=ON
    -DENABLE_TENSORRT=ON)
set(_feature_alias_cache "${_feature_alias_build}/CMakeCache.txt")
foreach(_feature IN ITEMS CUDA OPTIX TENSORRT)
  _require_cache_value(
      "${_feature_alias_cache}" "template_project_ENABLE_${_feature}" "ON")
  _require_cache_entry_absent(
      "${_feature_alias_cache}" "ENABLE_${_feature}")
endforeach()

_run_success(
    "Disable GPU features through legacy aliases"
    "${CMAKE_COMMAND}"
    -S "${TEST_TEMPLATE_SOURCE_DIR}"
    -B "${_feature_alias_build}"
    -Dtemplate_project_ENABLE_CUDA=ON
    -Dtemplate_project_ENABLE_OPTIX=ON
    -Dtemplate_project_ENABLE_TENSORRT=ON
    -DENABLE_CUDA=OFF
    -DENABLE_OPTIX=OFF
    -DENABLE_TENSORRT=OFF)
foreach(_feature IN ITEMS CUDA OPTIX TENSORRT)
  _require_cache_value(
      "${_feature_alias_cache}" "template_project_ENABLE_${_feature}" "OFF")
  _require_cache_entry_absent(
      "${_feature_alias_cache}" "ENABLE_${_feature}")
endforeach()
