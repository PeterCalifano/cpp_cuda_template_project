cmake_minimum_required(VERSION 3.15)

foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

set(_script "${TEST_TEMPLATE_SOURCE_DIR}/tailor_template_cleanup.sh")
if(NOT EXISTS "${_script}")
  message(FATAL_ERROR "Tailoring cleanup script not found: ${_script}")
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
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}/fake/.github/workflows")
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}/fake/doc/developments")
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}/fake/tests/cmake")
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}/fake/tests/matlab")

_run_step("Validate script syntax" bash -n "${_script}")

execute_process(
    COMMAND bash "${_script}" --list
    WORKING_DIRECTORY "${TEST_TEMPLATE_SOURCE_DIR}"
    RESULT_VARIABLE _list_result
    OUTPUT_VARIABLE _list_stdout
    ERROR_VARIABLE _list_stderr)
if(NOT _list_result EQUAL 0)
  message(FATAL_ERROR
      "tailor_template_cleanup.sh --list failed.\n"
      "stdout:\n${_list_stdout}\n"
      "stderr:\n${_list_stderr}")
endif()

foreach(_expected
    "doc/developments"
    "doc/bootstrap_prompts.md"
    "tests/cmake/VerifyTemplateProjectDocsWorkflow.cmake"
    "CMake edits made by --apply")
  if(NOT _list_stdout MATCHES "${_expected}")
    message(FATAL_ERROR "Cleanup list output did not contain '${_expected}'")
  endif()
endforeach()

file(WRITE "${TEST_BINARY_ROOT}/fake/build_lib.sh" "#!/usr/bin/env bash\n")
file(WRITE "${TEST_BINARY_ROOT}/fake/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(fake_tailored_project)
if(BUILD_AS_MAIN_PROJECT)
  include(\"\${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/AddMatlabWrapperRegressionTests.cmake\")
  add_template_matlab_wrapper_regression_tests()
endif()
")
file(WRITE "${TEST_BINARY_ROOT}/fake/tests/CMakeLists.txt"
"set(CATCH2_TEST_PROPERTIES \"--output-on-failure;--reporter=compact\")
include(CTest)
add_test(NAME template_project_docs_build_output COMMAND false)
add_test(NAME template_project_version_no_source_side_effect COMMAND false)

# Exclude EXCLUDED_LIST from the list of tests
set(EXCLUDED_LIST \"test_to_exclude\")
set(TESTS_LIST \"\")
include_directories(\${CMAKE_CURRENT_SOURCE_DIR})
if(Catch2_FOUND)
  add_subdirectory(template_test)
endif()
")

foreach(_path
    "AGENTS.md"
    "CLAUDE.md"
    "CONTEXT.md"
    "TODO"
    "cpp_cuda_template_project.code-workspace"
    "doc/bootstrap_prompts.md"
    "doc/developments/plan.md"
    ".github/workflows/build_linux.yml.templ0"
    ".github/workflows/build_linux.yml.templ1"
    ".github/workflows/build_linux_cuda.yml.templ0"
    ".github/workflows/build_linux_cuda.yml.templ1"
    "tests/cmake/AddMatlabWrapperRegressionTests.cmake"
    "tests/cmake/CheckTcmallocDependency.cmake"
    "tests/cmake/VerifyTemplateProjectDocsWorkflow.cmake"
    "tests/cmake/VerifyTemplateProjectTailoringScript.cmake"
    "tests/matlab/RunTemplateWrapperRegression.m")
  get_filename_component(_path_dir "${TEST_BINARY_ROOT}/fake/${_path}" DIRECTORY)
  file(MAKE_DIRECTORY "${_path_dir}")
  file(WRITE "${TEST_BINARY_ROOT}/fake/${_path}" "template-only\n")
endforeach()

_run_step(
    "Apply tailoring cleanup to fake project"
    bash "${_script}" --apply --yes --root "${TEST_BINARY_ROOT}/fake")

foreach(_removed
    "AGENTS.md"
    "doc/bootstrap_prompts.md"
    "doc/developments"
    ".github/workflows/build_linux.yml.templ0"
    "tests/cmake/VerifyTemplateProjectDocsWorkflow.cmake")
  if(EXISTS "${TEST_BINARY_ROOT}/fake/${_removed}")
    message(FATAL_ERROR "Expected cleanup to remove '${_removed}'")
  endif()
endforeach()

file(READ "${TEST_BINARY_ROOT}/fake/CMakeLists.txt" _root_cmake)
if(_root_cmake MATCHES "AddMatlabWrapperRegressionTests|add_template_matlab_wrapper_regression_tests")
  message(FATAL_ERROR "Root CMakeLists.txt still references template MATLAB regression hook.")
endif()

file(READ "${TEST_BINARY_ROOT}/fake/tests/CMakeLists.txt" _tests_cmake)
if(_tests_cmake MATCHES "template_project_docs|VerifyTemplateProject")
  message(FATAL_ERROR "tests/CMakeLists.txt still references template validation tests.")
endif()
if(NOT _tests_cmake MATCHES "Project unit tests")
  message(FATAL_ERROR "tests/CMakeLists.txt was not rewritten with project unit-test header.")
endif()
