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

function(_assert_mode file_path expected_mode)
  execute_process(
      COMMAND stat -c %a "${file_path}"
      RESULT_VARIABLE _mode_result
      OUTPUT_VARIABLE _actual_mode
      ERROR_VARIABLE _mode_stderr
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT _mode_result EQUAL 0)
    message(FATAL_ERROR
        "Failed to read mode for ${file_path}.\n"
        "stderr:\n${_mode_stderr}")
  endif()
  if(NOT _actual_mode STREQUAL "${expected_mode}")
    message(FATAL_ERROR
        "Expected mode ${expected_mode} for ${file_path}, got ${_actual_mode}")
  endif()
endfunction()

function(_snapshot_tree tree_root inventory_output hashes_output)
  execute_process(
      COMMAND bash -c
          "find . -printf '%y|%m|%p|%l\\n' | LC_ALL=C sort"
      WORKING_DIRECTORY "${tree_root}"
      RESULT_VARIABLE _inventory_result
      OUTPUT_VARIABLE _inventory
      ERROR_VARIABLE _inventory_stderr)
  if(NOT _inventory_result EQUAL 0)
    message(FATAL_ERROR
        "Failed to snapshot path inventory for ${tree_root}.\n"
        "stderr:\n${_inventory_stderr}")
  endif()

  execute_process(
      COMMAND bash -c
          "find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum"
      WORKING_DIRECTORY "${tree_root}"
      RESULT_VARIABLE _hashes_result
      OUTPUT_VARIABLE _hashes
      ERROR_VARIABLE _hashes_stderr)
  if(NOT _hashes_result EQUAL 0)
    message(FATAL_ERROR
        "Failed to snapshot file hashes for ${tree_root}.\n"
        "stderr:\n${_hashes_stderr}")
  endif()

  set(${inventory_output} "${_inventory}" PARENT_SCOPE)
  set(${hashes_output} "${_hashes}" PARENT_SCOPE)
endfunction()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
set(_fake_default "${TEST_BINARY_ROOT}/fake_default")
set(_fake_keep "${TEST_BINARY_ROOT}/fake_keep")
set(_fake_remove_ros2 "${TEST_BINARY_ROOT}/fake_remove_ros2")
set(_fake_missing_template "${TEST_BINARY_ROOT}/fake_missing_template")
set(_fake_orphan_fence "${TEST_BINARY_ROOT}/fake_orphan_fence")
set(_fake_nested_fence "${TEST_BINARY_ROOT}/fake_nested_fence")
set(_fake_unclosed_fence "${TEST_BINARY_ROOT}/fake_unclosed_fence")
set(_workflow_names
    "build_linux.yml"
    "build_linux_cuda.yml"
    "docs_pages.yml"
    "build_ros2_overlay.yml")

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
    "tests/cmake/VerifyTemplateProjectCudaSources.cmake"
    "tests/cmake/VerifyTemplateProjectDocsWorkflow.cmake"
    "tests/cmake/VerifyTemplateProjectOptixInstallExport.cmake"
    "tests/cmake/VerifyTemplateProjectRos2Overlay.cmake"
    "tests/template_test/testWorkflowTemplates.py"
    "src/utils/logging/ and doc/logging.md"
    "ROS 2 overlay KEPT by default; pass --remove-ros2 to strip it"
    "Materialize generic project CI workflows"
    "CMake edits made by --apply")
  if(NOT _list_stdout MATCHES "${_expected}")
    message(FATAL_ERROR "Cleanup list output did not contain '${_expected}'")
  endif()
endforeach()

function(_create_fake_project fake_root)
  file(MAKE_DIRECTORY "${fake_root}/.github/workflows")
  file(MAKE_DIRECTORY "${fake_root}/doc/developments")
  file(MAKE_DIRECTORY "${fake_root}/doc/reports")
  file(MAKE_DIRECTORY "${fake_root}/tests/cmake")
  file(MAKE_DIRECTORY "${fake_root}/tests/matlab")
  file(MAKE_DIRECTORY "${fake_root}/tests/template_test")
  file(MAKE_DIRECTORY "${fake_root}/ros2/template_project")
  file(MAKE_DIRECTORY "${fake_root}/python")
  file(MAKE_DIRECTORY "${fake_root}/lib")
  file(MAKE_DIRECTORY "${fake_root}/examples")
  file(MAKE_DIRECTORY "${fake_root}/profiling")
  file(MAKE_DIRECTORY "${fake_root}/src/utils/logging")

  file(WRITE "${fake_root}/build_lib.sh" "#!/usr/bin/env bash\n")
  file(WRITE "${fake_root}/build_ros2.sh" "#!/usr/bin/env bash\n")
  file(WRITE "${fake_root}/add_ros2_support.sh" "#!/usr/bin/env bash\n")
  file(WRITE "${fake_root}/generate_version.sh" "#!/usr/bin/env bash\n")
  file(WRITE "${fake_root}/src/utils/logging/CLogger.h" "reusable logger header\n")
  file(WRITE "${fake_root}/src/utils/logging/CLogger.cpp" "reusable logger source\n")
  file(WRITE "${fake_root}/doc/logging.md" "reusable logger guide\n")
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
  _run_step(
      "Set fake root CMake mode"
      chmod 0640 "${fake_root}/CMakeLists.txt")
  _run_step(
      "Set fake tests CMake mode"
      chmod 0600 "${fake_root}/tests/CMakeLists.txt")

  foreach(_path
      "AGENTS.md"
      "CLAUDE.md"
      "CONTEXT.md"
      "TODO"
      "cpp_cuda_template_project.code-workspace"
      "doc/developments/plan.md"
      "doc/reports/implementation_review.md"
      "tests/cmake/AddMatlabWrapperRegressionTests.cmake"
      "tests/cmake/CheckTcmallocDependency.cmake"
      "tests/cmake/VerifyTemplateProjectBuildTreePackage.cmake"
      "tests/cmake/VerifyTemplateProjectCudaSources.cmake"
      "tests/cmake/VerifyTemplateProjectDocsWorkflow.cmake"
      "tests/cmake/VerifyTemplateProjectOptixInstallExport.cmake"
      "tests/cmake/VerifyTemplateProjectReleaseTagSync.cmake"
      "tests/cmake/VerifyTemplateProjectRos2Overlay.cmake"
      "tests/cmake/VerifyTemplateProjectTailoringScript.cmake"
      "tests/template_test/testRos2OverlayStatic.py"
      "tests/template_test/testWorkflowTemplates.py"
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
      "doc/template_usage.md"
      "doc/versioning.md")
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
  _run_step(
      "Set fake README mode"
      chmod 0644 "${fake_root}/README.md")
  _run_step(
      "Set fake bootstrap guide mode"
      chmod 0640 "${fake_root}/doc/bootstrap_prompts.md")
  _run_step(
      "Set fake template usage mode"
      chmod 0604 "${fake_root}/doc/template_usage.md")
  _run_step(
      "Set fake versioning guide mode"
      chmod 0444 "${fake_root}/doc/versioning.md")

  foreach(_marker
      "python/COLCON_IGNORE"
      "lib/COLCON_IGNORE"
      "examples/COLCON_IGNORE"
      "tests/COLCON_IGNORE")
    file(WRITE "${fake_root}/${_marker}" "")
  endforeach()

  file(WRITE "${fake_root}/ros2/template_project/package.xml" "<package><version>1.2.3</version></package>\n")
  foreach(_workflow_name IN LISTS _workflow_names)
    file(WRITE
        "${fake_root}/.github/workflows/${_workflow_name}"
        "name: template-only-${_workflow_name}\n")
    configure_file(
        "${TEST_TEMPLATE_SOURCE_DIR}/.github/workflows/${_workflow_name}.tpl"
        "${fake_root}/.github/workflows/${_workflow_name}.tpl"
        COPYONLY)
  endforeach()
  execute_process(
      COMMAND chmod 0640 "${fake_root}/.github/workflows/build_linux.yml.tpl"
      RESULT_VARIABLE _chmod_result)
  if(NOT _chmod_result EQUAL 0)
    message(FATAL_ERROR "Failed to set fake workflow template mode for preservation test")
  endif()
  file(WRITE "${fake_root}/doc/ros2_overlay.md" "ROS 2 overlay docs\n")
endfunction()

function(_assert_fake_project_cleaned fake_root expect_profiling)
  foreach(_removed
      "AGENTS.md"
      "doc/developments"
      "doc/reports"
      "tests/cmake/VerifyTemplateProjectCudaSources.cmake"
      "tests/cmake/VerifyTemplateProjectDocsWorkflow.cmake"
      "tests/cmake/VerifyTemplateProjectOptixInstallExport.cmake"
      "tests/cmake/VerifyTemplateProjectReleaseTagSync.cmake"
      "tests/cmake/VerifyTemplateProjectRos2Overlay.cmake"
      "tests/template_test/testRos2OverlayStatic.py"
      "tests/template_test/testWorkflowTemplates.py")
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
  _assert_mode("${fake_root}/CMakeLists.txt" "640")

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
  _assert_mode("${fake_root}/tests/CMakeLists.txt" "600")

  foreach(_retained_logger_path
      "src/utils/logging/CLogger.h"
      "src/utils/logging/CLogger.cpp"
      "doc/logging.md")
    if(NOT EXISTS "${fake_root}/${_retained_logger_path}")
      message(FATAL_ERROR
          "Expected cleanup to retain reusable logger path '${_retained_logger_path}'")
    endif()
  endforeach()

  foreach(_workflow_name build_linux.yml build_linux_cuda.yml docs_pages.yml)
    set(_materialized_workflow "${fake_root}/.github/workflows/${_workflow_name}")
    set(_workflow_template "${fake_root}/.github/workflows/${_workflow_name}.tpl")
    if(NOT EXISTS "${_materialized_workflow}")
      message(FATAL_ERROR "Expected tailored workflow '${_workflow_name}'")
    endif()
    if(EXISTS "${_workflow_template}")
      message(FATAL_ERROR "Tailoring left dormant workflow '${_workflow_name}.tpl'")
    endif()
    file(READ "${_materialized_workflow}" _materialized_contents)
    file(READ
        "${TEST_TEMPLATE_SOURCE_DIR}/.github/workflows/${_workflow_name}.tpl"
        _expected_contents)
    if(NOT _materialized_contents STREQUAL _expected_contents)
      message(FATAL_ERROR "Tailoring did not materialize ${_workflow_name} byte-for-byte")
    endif()
    if(_materialized_contents MATCHES
        "template-only|VerifyTemplateProject|tailor_template_cleanup|CWrapperPlaceholder")
      message(FATAL_ERROR "Tailored workflow ${_workflow_name} contains template-only CI")
    endif()
    if(_workflow_name STREQUAL "build_linux.yml")
      execute_process(
          COMMAND stat -c %a "${_materialized_workflow}"
          RESULT_VARIABLE _mode_result
          OUTPUT_VARIABLE _materialized_mode
          OUTPUT_STRIP_TRAILING_WHITESPACE)
      if(NOT _mode_result EQUAL 0 OR NOT _materialized_mode STREQUAL "640")
        message(FATAL_ERROR
            "Tailoring did not preserve build_linux.yml.tpl mode 0640; got '${_materialized_mode}'")
      endif()
    endif()
  endforeach()
endfunction()

function(_assert_ros2_overlay_kept fake_root)
  foreach(_kept
      "ros2/template_project/package.xml"
      "build_ros2.sh"
      "python/COLCON_IGNORE"
      "lib/COLCON_IGNORE"
      "examples/COLCON_IGNORE"
      "tests/COLCON_IGNORE"
      ".github/workflows/build_ros2_overlay.yml")
    if(NOT EXISTS "${fake_root}/${_kept}")
      message(FATAL_ERROR "Expected default cleanup to keep '${_kept}'")
    endif()
  endforeach()

  set(_materialized_ros_workflow
      "${fake_root}/.github/workflows/build_ros2_overlay.yml")
  if(EXISTS "${fake_root}/.github/workflows/build_ros2_overlay.yml.tpl")
    message(FATAL_ERROR "Default tailoring left the dormant ROS workflow template")
  endif()
  file(READ "${_materialized_ros_workflow}" _materialized_ros_contents)
  file(READ
      "${TEST_TEMPLATE_SOURCE_DIR}/.github/workflows/build_ros2_overlay.yml.tpl"
      _expected_ros_contents)
  if(NOT _materialized_ros_contents STREQUAL _expected_ros_contents)
    message(FATAL_ERROR "Default tailoring did not materialize the generic ROS workflow")
  endif()
  if(_materialized_ros_contents MATCHES
      "VerifyTemplateProject|testRos2OverlayStatic|tailor_template_cleanup|CWrapperPlaceholder|rollout-rehearsal")
    message(FATAL_ERROR "Tailored ROS workflow contains template-only CI")
  endif()

  foreach(_doc_path
      "README.md"
      "doc/bootstrap_prompts.md"
      "doc/template_usage.md"
      "doc/versioning.md")
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
      ".github/workflows/build_ros2_overlay.yml.tpl"
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
      "doc/template_usage.md"
      "doc/versioning.md")
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

  _assert_mode("${fake_root}/README.md" "644")
  _assert_mode("${fake_root}/doc/bootstrap_prompts.md" "640")
  _assert_mode("${fake_root}/doc/template_usage.md" "604")
  _assert_mode("${fake_root}/doc/versioning.md" "444")
endfunction()

function(_assert_malformed_fence_rejected fake_root readme_contents case_name)
  _create_fake_project("${fake_root}")
  file(WRITE "${fake_root}/README.md" "${readme_contents}")
  _run_step(
      "Reset malformed-fence README mode"
      chmod 0644 "${fake_root}/README.md")
  _snapshot_tree("${fake_root}" _inventory_before _hashes_before)
  execute_process(
      COMMAND bash "${_script}" --apply --yes --remove-ros2 --root "${fake_root}"
      RESULT_VARIABLE _malformed_result
      OUTPUT_VARIABLE _malformed_stdout
      ERROR_VARIABLE _malformed_stderr)
  if(_malformed_result EQUAL 0)
    message(FATAL_ERROR "Tailoring accepted ${case_name} ROS 2 overlay fences")
  endif()
  if(NOT _malformed_stderr MATCHES "Malformed ROS 2 overlay fence in README.md")
    message(FATAL_ERROR
        "Tailoring rejected ${case_name} fences for the wrong reason.\n"
        "stdout:\n${_malformed_stdout}\n"
        "stderr:\n${_malformed_stderr}")
  endif()
  _snapshot_tree("${fake_root}" _inventory_after _hashes_after)
  if(NOT _inventory_after STREQUAL _inventory_before)
    message(FATAL_ERROR
        "Tailoring changed the path inventory or modes before rejecting ${case_name} fences.\n"
        "Before:\n${_inventory_before}\n"
        "After:\n${_inventory_after}")
  endif()
  if(NOT _hashes_after STREQUAL _hashes_before)
    message(FATAL_ERROR
        "Tailoring changed file contents before rejecting ${case_name} fences.\n"
        "Before:\n${_hashes_before}\n"
        "After:\n${_hashes_after}")
  endif()
endfunction()

_assert_malformed_fence_rejected(
    "${_fake_nested_fence}"
    "before\n<!-- ros2-overlay-begin -->\nouter\n<!-- ros2-overlay-begin -->\ninner\n<!-- ros2-overlay-end -->\n<!-- ros2-overlay-end -->\nafter\n"
    "nested-begin")
_assert_malformed_fence_rejected(
    "${_fake_orphan_fence}"
    "before\n<!-- ros2-overlay-end -->\nafter\n"
    "orphan-end")
_assert_malformed_fence_rejected(
    "${_fake_unclosed_fence}"
    "before\n<!-- ros2-overlay-begin -->\nunclosed\n"
    "unclosed-begin")

foreach(_expected "doc/reports" "tests/cmake/VerifyTemplateProjectReleaseTagSync.cmake")
  if(NOT _list_stdout MATCHES "${_expected}")
    message(FATAL_ERROR "Cleanup list output did not contain '${_expected}'")
  endif()
endforeach()

_create_fake_project("${_fake_default}")

_run_step(
    "Apply tailoring cleanup to fake project"
    bash "${_script}" --apply --yes --root "${_fake_default}")
_assert_fake_project_cleaned("${_fake_default}" FALSE)
_assert_ros2_overlay_kept("${_fake_default}")
_run_step(
    "Reapply tailoring cleanup to an already materialized project"
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
_run_step(
    "Reapply tailoring cleanup after ROS 2 removal"
    bash "${_script}" --apply --yes --remove-ros2 --root "${_fake_remove_ros2}")
_assert_fake_project_cleaned("${_fake_remove_ros2}" FALSE)
_assert_ros2_overlay_removed("${_fake_remove_ros2}")

_create_fake_project("${_fake_missing_template}")
file(REMOVE
    "${_fake_missing_template}/.github/workflows/build_linux.yml.tpl")
execute_process(
    COMMAND bash "${_script}" --apply --yes --root "${_fake_missing_template}"
    RESULT_VARIABLE _missing_template_result
    OUTPUT_VARIABLE _missing_template_stdout
    ERROR_VARIABLE _missing_template_stderr)
if(_missing_template_result EQUAL 0)
  message(FATAL_ERROR
      "Tailoring accepted an active template-validation workflow whose generic .tpl was missing")
endif()
if(NOT _missing_template_stderr MATCHES
    "Active template-validation workflow has no generic template")
  message(FATAL_ERROR
      "Tailoring rejected the missing template for the wrong reason.\n"
      "stdout:\n${_missing_template_stdout}\n"
      "stderr:\n${_missing_template_stderr}")
endif()
