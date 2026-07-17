cmake_minimum_required(VERSION 3.15)

foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

find_program(_git_executable NAMES git REQUIRED)
find_program(_bash_executable NAMES bash REQUIRED)

set(_synthetic_version "99.98.97")
set(_synthetic_tag "v${_synthetic_version}")
set(_scratch_root "${TEST_BINARY_ROOT}/release_clone")
set(_scratch_verifier "${_scratch_root}/tests/cmake/VerifyTemplateProjectRos2Overlay.cmake")
set(_manifest_paths
    "ros2/template_project/package.xml"
    "ros2/template_project_interfaces/package.xml"
    "ros2/template_project_ros/package.xml"
    "ros2/template_project_spinup/package.xml")

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
  set(_last_stdout "${_stdout}" PARENT_SCOPE)
endfunction()

function(_run_failure step_name expected_pattern)
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
  set(_combined_output "${_stdout}\n${_stderr}")
  if(NOT _combined_output MATCHES "${expected_pattern}")
    message(FATAL_ERROR
        "${step_name} failed, but output did not match '${expected_pattern}'.\n"
        "stdout:\n${_stdout}\n"
        "stderr:\n${_stderr}")
  endif()
endfunction()

execute_process(
    COMMAND "${_git_executable}" -C "${TEST_TEMPLATE_SOURCE_DIR}" show-ref --tags
    RESULT_VARIABLE _source_tags_result
    OUTPUT_VARIABLE _source_tags_before
    ERROR_VARIABLE _source_tags_stderr)
if(NOT _source_tags_result EQUAL 0 AND NOT _source_tags_result EQUAL 1)
  message(FATAL_ERROR "Could not capture source tags: ${_source_tags_stderr}")
endif()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}")
_run_success(
    "Create local scratch clone"
    "${CMAKE_COMMAND}" -E env GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
    "${_git_executable}" clone --no-local "${TEST_TEMPLATE_SOURCE_DIR}" "${_scratch_root}")
_run_success("Remove scratch remote" "${_git_executable}" -C "${_scratch_root}" remote remove origin)
_run_success("Configure scratch Git name" "${_git_executable}" -C "${_scratch_root}" config user.name "Template Release Test")
_run_success("Configure scratch Git email" "${_git_executable}" -C "${_scratch_root}" config user.email "release-test@example.invalid")
_run_success("Disable scratch commit signing" "${_git_executable}" -C "${_scratch_root}" config commit.gpgSign false)
_run_success("Disable scratch tag signing" "${_git_executable}" -C "${_scratch_root}" config tag.gpgSign false)
_run_success(
    "Create synthetic release-preparation commit"
    "${_git_executable}" -C "${_scratch_root}" commit --allow-empty -m "Start synthetic release preparation")

file(READ "${_scratch_root}/ros2/template_project/package.xml" _baseline_manifest)
string(REGEX MATCH "<version>[ \t\r\n]*([^< \t\r\n]+)" _baseline_match "${_baseline_manifest}")
if(NOT _baseline_match)
  message(FATAL_ERROR "Could not read the baseline ROS package version")
endif()
set(_baseline_version "${CMAKE_MATCH_1}")

_run_success(
    "Create temporary local lightweight release tag"
    "${_git_executable}" -C "${_scratch_root}" tag --no-sign "${_synthetic_tag}")
_run_success(
    "List tags on synthetic release-preparation commit"
    "${_git_executable}" -C "${_scratch_root}" tag --points-at HEAD)
string(STRIP "${_last_stdout}" _preparation_tags)
if(NOT _preparation_tags STREQUAL "${_synthetic_tag}")
  message(FATAL_ERROR
      "Synthetic release-preparation commit must have only ${_synthetic_tag}; got '${_preparation_tags}'")
endif()
_run_failure(
    "Reject stale manifests at the temporary release tag"
    "version '${_synthetic_version}', got"
    "${CMAKE_COMMAND}"
    -DTEST_TEMPLATE_SOURCE_DIR=${_scratch_root}
    -DTEST_BINARY_ROOT=${TEST_BINARY_ROOT}/stale_overlay
    -DEXPECTED_VERSION=${_synthetic_version}
    -P "${_scratch_verifier}")

_run_success(
    "Synchronize manifests from the temporary local tag"
    "${CMAKE_COMMAND}" -E env GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
    "${_bash_executable}" "${_scratch_root}/generate_version.sh" --sync-ros2)
_run_success(
    "Delete temporary local tag"
    "${_git_executable}" -C "${_scratch_root}" tag -d "${_synthetic_tag}")

_run_success(
    "List synchronized files"
    "${_git_executable}" -C "${_scratch_root}" diff --name-only)
string(REPLACE "\r\n" "\n" _changed_files "${_last_stdout}")
string(REPLACE "\n" ";" _changed_files "${_changed_files}")
list(FILTER _changed_files EXCLUDE REGEX "^$")
list(SORT _changed_files)
set(_expected_changed_files ${_manifest_paths})
list(SORT _expected_changed_files)
if(NOT _changed_files STREQUAL _expected_changed_files)
  message(FATAL_ERROR
      "Metadata sync must modify exactly the four ROS manifests.\n"
      "Expected: ${_expected_changed_files}\n"
      "Actual: ${_changed_files}")
endif()

_run_success("Stage synchronized manifests" "${_git_executable}" -C "${_scratch_root}" add -- ${_manifest_paths})
_run_success(
    "Commit synchronized manifests"
    "${_git_executable}" -C "${_scratch_root}" commit -m "Prepare synthetic ROS release metadata")

_run_failure(
    "Reject unpublished synchronized commit before final tag"
    "version '${_baseline_version}', got"
    "${CMAKE_COMMAND}"
    -DTEST_TEMPLATE_SOURCE_DIR=${_scratch_root}
    -DTEST_BINARY_ROOT=${TEST_BINARY_ROOT}/untagged_overlay
    -DEXPECTED_VERSION=${_baseline_version}
    -P "${_scratch_verifier}")

_run_success(
    "Create final annotated release tag"
    "${_git_executable}" -C "${_scratch_root}" tag -a "${_synthetic_tag}" -m "Synthetic release ${_synthetic_version}")

foreach(_manifest_path IN LISTS _manifest_paths)
  _run_success(
      "Read ${_manifest_path} from final tag"
      "${_git_executable}" -C "${_scratch_root}" show "${_synthetic_tag}:${_manifest_path}")
  if(NOT _last_stdout MATCHES "<version>${_synthetic_version}</version>")
    message(FATAL_ERROR
        "Final tag does not contain ${_synthetic_version} in ${_manifest_path}")
  endif()
endforeach()

_run_success(
    "Validate final tagged ROS overlay"
    "${CMAKE_COMMAND}"
    -DTEST_TEMPLATE_SOURCE_DIR=${_scratch_root}
    -DTEST_BINARY_ROOT=${TEST_BINARY_ROOT}/final_overlay
    -DEXPECTED_VERSION=${_synthetic_version}
    -P "${_scratch_verifier}")
_run_success("Check final scratch status" "${_git_executable}" -C "${_scratch_root}" status --porcelain)
if(NOT _last_stdout STREQUAL "")
  message(FATAL_ERROR "Final tagged scratch clone is dirty:\n${_last_stdout}")
endif()

execute_process(
    COMMAND "${_git_executable}" -C "${TEST_TEMPLATE_SOURCE_DIR}" show-ref --tags
    RESULT_VARIABLE _source_tags_after_result
    OUTPUT_VARIABLE _source_tags_after
    ERROR_VARIABLE _source_tags_after_stderr)
if(NOT _source_tags_after_result EQUAL 0 AND NOT _source_tags_after_result EQUAL 1)
  message(FATAL_ERROR "Could not recapture source tags: ${_source_tags_after_stderr}")
endif()
if(NOT _source_tags_before STREQUAL _source_tags_after)
  message(FATAL_ERROR "Release regression changed tags in the source repository")
endif()
