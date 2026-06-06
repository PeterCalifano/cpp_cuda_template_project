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

function(_assert_file_contains file_path pattern)
  if(NOT EXISTS "${file_path}")
    message(FATAL_ERROR "Expected file does not exist: ${file_path}")
  endif()
  file(READ "${file_path}" _contents)
  if(NOT _contents MATCHES "${pattern}")
    message(FATAL_ERROR "Expected '${file_path}' to match pattern '${pattern}'")
  endif()
endfunction()

function(_assert_file_not_contains file_path pattern)
  if(NOT EXISTS "${file_path}")
    message(FATAL_ERROR "Expected file does not exist: ${file_path}")
  endif()
  file(READ "${file_path}" _contents)
  if(_contents MATCHES "${pattern}")
    message(FATAL_ERROR "Expected '${file_path}' not to match pattern '${pattern}'")
  endif()
endfunction()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}")

set(_build_dir "${TEST_BINARY_ROOT}/build")
_run_step(
    "Configure documentation build"
    ${CMAKE_COMMAND}
        -S "${TEST_TEMPLATE_SOURCE_DIR}"
        -B "${_build_dir}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DENABLE_TESTS=OFF
        -DENABLE_CUDA=OFF
        -DENABLE_OPTIX=OFF
        -DENABLE_OPENGL=OFF
        -DBUILD_DOC_HTML=ON
        -DBUILD_DOC_XML=ON
        -DBUILD_DOC_LATEX=OFF
        -DWRITE_SOURCE_VERSION_FILE=OFF
        -Dtemplate_project_BUILD_PROGRAMS=OFF
        -Dtemplate_project_BUILD_EXAMPLES=OFF)

execute_process(
    COMMAND ${CMAKE_COMMAND} --build "${_build_dir}" --target doc
    RESULT_VARIABLE _doc_build_result
    OUTPUT_VARIABLE _doc_build_stdout
    ERROR_VARIABLE _doc_build_stderr)
if(NOT _doc_build_result EQUAL 0)
  message(FATAL_ERROR
      "Build documentation failed with exit code ${_doc_build_result}.\n"
      "stdout:\n${_doc_build_stdout}\n"
      "stderr:\n${_doc_build_stderr}")
endif()
set(_doc_build_output "${_doc_build_stdout}\n${_doc_build_stderr}")
if(_doc_build_output MATCHES "(^|\n)[^\n]*(warning:|error:)")
  message(FATAL_ERROR
      "Doxygen documentation build emitted warnings/errors.\n"
      "stdout:\n${_doc_build_stdout}\n"
      "stderr:\n${_doc_build_stderr}")
endif()

set(_doxyfile "${_build_dir}/doc/Doxyfile")
set(_html_index "${_build_dir}/doc/html/index.html")
set(_xml_index "${_build_dir}/doc/xml/index.xml")

_assert_file_contains("${_doxyfile}" "GENERATE_HTML[ ]*=[ ]*YES")
_assert_file_contains("${_doxyfile}" "GENERATE_XML[ ]*=[ ]*YES")
_assert_file_contains("${_doxyfile}" "INPUT[ ]*=.*${TEST_TEMPLATE_SOURCE_DIR}/README.md.*${TEST_TEMPLATE_SOURCE_DIR}/src.*${TEST_TEMPLATE_SOURCE_DIR}/doc")
_assert_file_contains("${_doxyfile}" "EXCLUDE[ ]*=.*${TEST_TEMPLATE_SOURCE_DIR}/lib.*${TEST_TEMPLATE_SOURCE_DIR}/doc/developments")
_assert_file_contains("${_doxyfile}" "USE_MDFILE_AS_MAINPAGE[ ]*=[ ]*${TEST_TEMPLATE_SOURCE_DIR}/doc/main_page.md")
file(READ "${_doxyfile}" _doxyfile_contents)
string(REGEX MATCH "INPUT[^\n]*" _doxyfile_input_line "${_doxyfile_contents}")
if(_doxyfile_input_line MATCHES "${TEST_TEMPLATE_SOURCE_DIR}/lib")
  message(FATAL_ERROR "Doxygen INPUT includes lib directory: ${_doxyfile_input_line}")
endif()
string(REGEX MATCH "(^|\n)EXCLUDE[ ]*=[^\n]*" _doxyfile_exclude_line "${_doxyfile_contents}")
if(NOT _doxyfile_exclude_line MATCHES "${TEST_TEMPLATE_SOURCE_DIR}/doc/developments")
  message(FATAL_ERROR "Doxygen EXCLUDE does not include internal development notes: ${_doxyfile_exclude_line}")
endif()

if(NOT EXISTS "${_html_index}")
  message(FATAL_ERROR "Doxygen HTML index was not generated: ${_html_index}")
endif()
if(NOT EXISTS "${_xml_index}")
  message(FATAL_ERROR "Doxygen XML index was not generated: ${_xml_index}")
endif()

file(GLOB_RECURSE _html_files "${_build_dir}/doc/html/*.html")
set(_combined_html "")
foreach(_html_file IN LISTS _html_files)
  file(READ "${_html_file}" _html_text)
  string(APPEND _combined_html "\n${_html_text}")
endforeach()

foreach(_required_text
    "Agent Tailoring Prompt"
    "build_lib.sh Reference"
    "Template Usage Guide"
    "C\\+\\+ and CUDA Build Guide"
    "Python and MATLAB Wrapper Guide"
    "Versioning Guide"
    "Documentation Workflow"
    "Testing, CI, and Issue Workflow")
  if(NOT _combined_html MATCHES "${_required_text}")
    message(FATAL_ERROR "Generated HTML documentation does not contain '${_required_text}'")
  endif()
endforeach()

foreach(_internal_text
    "MATLAB wrapper crash investigation"
    "Documentation workflow rollout"
    "docs_workflow_rollout")
  if(_combined_html MATCHES "${_internal_text}")
    message(FATAL_ERROR "Generated HTML documentation contains internal note '${_internal_text}'")
  endif()
endforeach()
