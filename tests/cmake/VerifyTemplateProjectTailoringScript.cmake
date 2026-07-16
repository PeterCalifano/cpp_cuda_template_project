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
set(_fake_default "${TEST_BINARY_ROOT}/fake_default")
set(_fake_keep "${TEST_BINARY_ROOT}/fake_keep")
set(_fake_remove_ros2 "${TEST_BINARY_ROOT}/fake_remove_ros2")

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
    "profiling"
    "tests/cmake/VerifyTemplateProjectDocsWorkflow.cmake"
    "tests/cmake/VerifyTemplateProjectRos2Overlay.cmake"
    "ROS 2 overlay KEPT by default; pass --remove-ros2 to strip it"
    "CMake edits made by --apply")
  if(NOT _list_stdout MATCHES "${_expected}")
    message(FATAL_ERROR "Cleanup list output did not contain '${_expected}'")
  endif()
endforeach()

function(_create_fake_project fake_root)
  file(MAKE_DIRECTORY "${fake_root}/.github/workflows")
  file(MAKE_DIRECTORY "${fake_root}/doc/developments")
  file(MAKE_DIRECTORY "${fake_root}/tests/cmake")
  file(MAKE_DIRECTORY "${fake_root}/tests/matlab")
  file(MAKE_DIRECTORY "${fake_root}/tests/template_test")
  file(MAKE_DIRECTORY "${fake_root}/ros2/template_project")
  file(MAKE_DIRECTORY "${fake_root}/python")
  file(MAKE_DIRECTORY "${fake_root}/lib")
  file(MAKE_DIRECTORY "${fake_root}/examples")
  file(MAKE_DIRECTORY "${fake_root}/profiling")

  file(WRITE "${fake_root}/build_lib.sh" "#!/usr/bin/env bash\n")
  file(WRITE "${fake_root}/build_ros2.sh" "#!/usr/bin/env bash\n")
  file(WRITE "${fake_root}/add_ros2_support.sh" "#!/usr/bin/env bash\n")
  file(WRITE "${fake_root}/generate_version.sh" "#!/usr/bin/env bash\n")
  file(WRITE "${fake_root}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(fake_tailored_project)
if(BUILD_AS_MAIN_PROJECT)
  include(\"\${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/AddMatlabWrapperRegressionTests.cmake\")
  add_template_matlab_wrapper_regression_tests()
endif()
")
  file(WRITE "${fake_root}/tests/CMakeLists.txt"
"include(CTest)
add_test(NAME template_project_docs_build_output COMMAND false)
add_test(NAME template_project_version_no_source_side_effect COMMAND false)
add_test(NAME template_project_ros2_overlay_static_contract COMMAND \${CMAKE_COMMAND} -P \${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectRos2Overlay.cmake)

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
      "doc/developments/plan.md"
      "tests/cmake/AddMatlabWrapperRegressionTests.cmake"
      "tests/cmake/CheckTcmallocDependency.cmake"
      "tests/cmake/VerifyTemplateProjectBuildTreePackage.cmake"
      "tests/cmake/VerifyTemplateProjectDocsWorkflow.cmake"
      "tests/cmake/VerifyTemplateProjectRos2Overlay.cmake"
      "tests/cmake/VerifyTemplateProjectTailoringScript.cmake"
      "tests/matlab/RunTemplateWrapperRegression.m"
      "profiling/run_ops_profiling.sh")
    get_filename_component(_path_dir "${fake_root}/${_path}" DIRECTORY)
    file(MAKE_DIRECTORY "${_path_dir}")
    file(WRITE "${fake_root}/${_path}" "template-only\n")
  endforeach()

  foreach(_path
      "README.md"
      "AGENTS.md"
      "CLAUDE.md"
      "doc/bootstrap_prompts.md"
      "doc/template_usage.md")
    get_filename_component(_path_dir "${fake_root}/${_path}" DIRECTORY)
    file(MAKE_DIRECTORY "${_path_dir}")
    file(WRITE "${fake_root}/${_path}"
"before ros2 fence
<!-- ros2-overlay-begin -->
remove this ros2 overlay block
<!-- ros2-overlay-end -->
after ros2 fence
")
  endforeach()

  foreach(_marker
      "python/COLCON_IGNORE"
      "lib/COLCON_IGNORE"
      "examples/COLCON_IGNORE"
      "tests/COLCON_IGNORE")
    file(WRITE "${fake_root}/${_marker}" "")
  endforeach()

  file(WRITE "${fake_root}/ros2/template_project/package.xml" "<package><version>1.2.3</version></package>\n")
  file(WRITE "${fake_root}/.github/workflows/build_ros2_overlay.yml" "name: ROS 2 overlay\n")
  file(WRITE "${fake_root}/doc/ros2_overlay.md" "ROS 2 overlay docs\n")
  file(WRITE "${fake_root}/tests/template_test/testRos2OverlayStatic.py" "def test_placeholder():\n    pass\n")
endfunction()

function(_assert_fake_project_cleaned fake_root expect_profiling)
  foreach(_removed
      "AGENTS.md"
      "doc/developments"
      "tests/cmake/VerifyTemplateProjectDocsWorkflow.cmake"
      "tests/cmake/VerifyTemplateProjectRos2Overlay.cmake")
    if(EXISTS "${fake_root}/${_removed}")
      message(FATAL_ERROR "Expected cleanup to remove '${_removed}'")
    endif()
  endforeach()

  if(expect_profiling)
    if(NOT EXISTS "${fake_root}/profiling/run_ops_profiling.sh")
      message(FATAL_ERROR "Expected --keep-profiling to preserve profiling scripts.")
    endif()
  else()
    if(EXISTS "${fake_root}/profiling")
      message(FATAL_ERROR "Expected cleanup to remove profiling by default.")
    endif()
  endif()

  file(READ "${fake_root}/CMakeLists.txt" _root_cmake)
  if(_root_cmake MATCHES "AddMatlabWrapperRegressionTests|add_template_matlab_wrapper_regression_tests")
    message(FATAL_ERROR "Root CMakeLists.txt still references template MATLAB regression hook.")
  endif()

  file(READ "${fake_root}/tests/CMakeLists.txt" _tests_cmake)
  if(_tests_cmake MATCHES "template_project_docs|VerifyTemplateProject")
    message(FATAL_ERROR "tests/CMakeLists.txt still references template validation tests.")
  endif()
  if(NOT _tests_cmake MATCHES "Project unit tests")
    message(FATAL_ERROR "tests/CMakeLists.txt was not rewritten with project unit-test header.")
  endif()
  if(NOT _tests_cmake MATCHES "add_tests\\(\\$\\{project_name\\} EXCLUDED_LIST TESTS_LIST")
    message(FATAL_ERROR "tests/CMakeLists.txt does not keep the reusable add_tests registration.")
  endif()
  if(_tests_cmake MATCHES "if\\(Catch2_FOUND\\)")
    message(FATAL_ERROR "tests/CMakeLists.txt still gates all starter tests on Catch2.")
  endif()
  if(_tests_cmake MATCHES "--output-on-failure|--reporter=compact")
    message(FATAL_ERROR "tests/CMakeLists.txt still passes CTest/Catch2 runner flags as Catch2 test properties.")
  endif()
endfunction()

function(_assert_ros2_overlay_kept fake_root)
  foreach(_kept
      "ros2/template_project/package.xml"
      "build_ros2.sh"
      "python/COLCON_IGNORE"
      "lib/COLCON_IGNORE"
      "examples/COLCON_IGNORE"
      "tests/COLCON_IGNORE"
      "tests/template_test/testRos2OverlayStatic.py")
    if(NOT EXISTS "${fake_root}/${_kept}")
      message(FATAL_ERROR "Expected default cleanup to keep '${_kept}'")
    endif()
  endforeach()

  foreach(_doc_path
      "README.md"
      "doc/bootstrap_prompts.md"
      "doc/template_usage.md")
    file(READ "${fake_root}/${_doc_path}" _doc_contents)
    if(NOT _doc_contents MATCHES "ros2-overlay-begin|remove this ros2 overlay block|ros2-overlay-end")
      message(FATAL_ERROR "Expected default cleanup to keep ROS 2 fence in ${_doc_path}")
    endif()
  endforeach()
endfunction()

function(_assert_ros2_overlay_removed fake_root)
  foreach(_removed
      "ros2"
      "build_ros2.sh"
      "add_ros2_support.sh"
      "python/COLCON_IGNORE"
      "lib/COLCON_IGNORE"
      "examples/COLCON_IGNORE"
      "tests/COLCON_IGNORE"
      ".github/workflows/build_ros2_overlay.yml"
      "doc/ros2_overlay.md"
      "tests/template_test/testRos2OverlayStatic.py")
    if(EXISTS "${fake_root}/${_removed}")
      message(FATAL_ERROR "Expected --remove-ros2 to remove '${_removed}'")
    endif()
  endforeach()

  if(NOT EXISTS "${fake_root}/generate_version.sh")
    message(FATAL_ERROR "--remove-ros2 must not remove generate_version.sh")
  endif()

  foreach(_doc_path
      "README.md"
      "AGENTS.md"
      "CLAUDE.md"
      "doc/bootstrap_prompts.md"
      "doc/template_usage.md")
    if(NOT EXISTS "${fake_root}/${_doc_path}")
      continue()
    endif()
    file(READ "${fake_root}/${_doc_path}" _doc_contents)
    if(_doc_contents MATCHES "ros2-overlay-begin|remove this ros2 overlay block|ros2-overlay-end")
      message(FATAL_ERROR "Expected --remove-ros2 to strip ROS 2 fence from ${_doc_path}")
    endif()
    if(NOT _doc_contents MATCHES "before ros2 fence" OR NOT _doc_contents MATCHES "after ros2 fence")
      message(FATAL_ERROR "Expected --remove-ros2 to preserve surrounding text in ${_doc_path}")
    endif()
  endforeach()
endfunction()

_create_fake_project("${_fake_default}")

_run_step(
    "Apply tailoring cleanup to fake project"
    bash "${_script}" --apply --yes --root "${_fake_default}")
_assert_fake_project_cleaned("${_fake_default}" FALSE)
_assert_ros2_overlay_kept("${_fake_default}")

_create_fake_project("${_fake_keep}")

_run_step(
    "Apply tailoring cleanup to fake project with profiling preserved"
    bash "${_script}" --apply --yes --keep-profiling --root "${_fake_keep}")
_assert_fake_project_cleaned("${_fake_keep}" TRUE)
_assert_ros2_overlay_kept("${_fake_keep}")

_create_fake_project("${_fake_remove_ros2}")

_run_step(
    "Apply tailoring cleanup to fake project with ROS 2 removed"
    bash "${_script}" --apply --yes --remove-ros2 --root "${_fake_remove_ros2}")
_assert_fake_project_cleaned("${_fake_remove_ros2}" FALSE)
_assert_ros2_overlay_removed("${_fake_remove_ros2}")
