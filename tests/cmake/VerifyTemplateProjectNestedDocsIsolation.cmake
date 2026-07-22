cmake_minimum_required(VERSION 3.15)

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

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}/parent")

file(WRITE "${TEST_BINARY_ROOT}/parent/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(parent_docs_isolation LANGUAGES CXX)
set(LIB_NAMESPACE_OVERRIDE nested_template CACHE STRING \"\" FORCE)
set(LIB_TARGET_NAME_OVERRIDE nested_template_project CACHE STRING \"\" FORCE)
set(ENABLE_TESTS OFF CACHE BOOL \"\" FORCE)
set(ENABLE_FETCH_CATCH2 OFF CACHE BOOL \"\" FORCE)
set(ENABLE_CUDA OFF CACHE BOOL \"\" FORCE)
set(nested_template_BUILD_PROGRAMS OFF CACHE BOOL \"\" FORCE)
set(nested_template_BUILD_EXAMPLES OFF CACHE BOOL \"\" FORCE)
add_subdirectory(\"${TEST_TEMPLATE_SOURCE_DIR}\" \"${CMAKE_CURRENT_BINARY_DIR}/template_subbuild\" EXCLUDE_FROM_ALL)
add_library(parent_library STATIC parent.cpp)
target_link_libraries(parent_library PRIVATE nested_template::template_project)
")

file(WRITE "${TEST_BINARY_ROOT}/parent/parent.cpp"
"#include <template_src/placeholder.h>
void ParentDocsIsolationCall()
{
    placeholder::placeholder_fcn();
}
")

set(_parent_build "${TEST_BINARY_ROOT}/parent_build")
_run_step(
    "Configure parent nested build"
    ${CMAKE_COMMAND}
        -S "${TEST_BINARY_ROOT}/parent"
        -B "${_parent_build}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo)

_run_step("Build parent nested library" ${CMAKE_COMMAND} --build "${_parent_build}" --target parent_library)

execute_process(
    COMMAND ${CMAKE_COMMAND} --build "${_parent_build}" --target doc
    RESULT_VARIABLE _doc_result
    OUTPUT_VARIABLE _doc_stdout
    ERROR_VARIABLE _doc_stderr)
if(_doc_result EQUAL 0)
  message(FATAL_ERROR
      "Nested template project unexpectedly created a parent-visible 'doc' target.\n"
      "stdout:\n${_doc_stdout}\n"
      "stderr:\n${_doc_stderr}")
endif()

if(EXISTS "${_parent_build}/template_subbuild/doc/Doxyfile")
  message(FATAL_ERROR "Nested template project configured Doxygen unexpectedly: ${_parent_build}/template_subbuild/doc/Doxyfile")
endif()
