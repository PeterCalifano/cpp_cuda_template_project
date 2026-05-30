cmake_minimum_required(VERSION 3.15)

foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

set(_source_version "${TEST_TEMPLATE_SOURCE_DIR}/VERSION")
set(_had_source_version OFF)
set(_source_version_before "")
if(EXISTS "${_source_version}")
  set(_had_source_version ON)
  file(READ "${_source_version}" _source_version_before)
endif()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}")

execute_process(
    COMMAND ${CMAKE_COMMAND}
        -S "${TEST_TEMPLATE_SOURCE_DIR}"
        -B "${TEST_BINARY_ROOT}/build"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DENABLE_TESTS=OFF
        -DENABLE_CUDA=OFF
        -DENABLE_OPTIX=OFF
        -DENABLE_OPENGL=OFF
        -DWRITE_SOURCE_VERSION_FILE=OFF
        -Dtemplate_project_BUILD_PROGRAMS=OFF
        -Dtemplate_project_BUILD_EXAMPLES=OFF
    RESULT_VARIABLE _configure_result
    OUTPUT_VARIABLE _configure_stdout
    ERROR_VARIABLE _configure_stderr)
if(NOT _configure_result EQUAL 0)
  message(FATAL_ERROR
      "Configure failed with exit code ${_configure_result}.\n"
      "stdout:\n${_configure_stdout}\n"
      "stderr:\n${_configure_stderr}")
endif()

if(NOT EXISTS "${TEST_BINARY_ROOT}/build/VERSION")
  message(FATAL_ERROR "Build-tree VERSION was not written.")
endif()

if(_had_source_version)
  file(READ "${_source_version}" _source_version_after)
  if(NOT "${_source_version_after}" STREQUAL "${_source_version_before}")
    message(FATAL_ERROR "Source VERSION changed even though WRITE_SOURCE_VERSION_FILE=OFF.")
  endif()
elseif(EXISTS "${_source_version}")
  message(FATAL_ERROR "Source VERSION was created even though WRITE_SOURCE_VERSION_FILE=OFF.")
endif()
