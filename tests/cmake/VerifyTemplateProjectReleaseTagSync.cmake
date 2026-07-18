cmake_minimum_required(VERSION 3.15)

foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

find_program(_git_executable NAMES git REQUIRED)
find_program(_bash_executable NAMES bash REQUIRED)
find_program(_cpack_executable NAMES cpack REQUIRED)
find_program(_python_executable NAMES python3 REQUIRED)

set(_synthetic_version "99.98.97")
set(_synthetic_tag "v${_synthetic_version}")
set(_scratch_root "${TEST_BINARY_ROOT}/build_parent/release_clone")
set(_scratch_verifier "${_scratch_root}/tests/cmake/VerifyTemplateProjectRos2Overlay.cmake")
set(_source_release_verifier
    "${TEST_TEMPLATE_SOURCE_DIR}/tests/cmake/VerifySourceReleaseArchive.cmake")
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

function(_read_xml_version manifest_path out_var)
  execute_process(
      COMMAND "${_python_executable}" -c
          "import sys, xml.etree.ElementTree as ET; value=ET.parse(sys.argv[1]).getroot().findtext('version'); assert value; print(value)"
          "${manifest_path}"
      RESULT_VARIABLE _parse_result
      OUTPUT_VARIABLE _version
      ERROR_VARIABLE _parse_stderr
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT _parse_result EQUAL 0)
    message(FATAL_ERROR
        "Could not parse manifest version from ${manifest_path}: ${_parse_stderr}")
  endif()
  set(${out_var} "${_version}" PARENT_SCOPE)
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

execute_process(
    COMMAND "${_git_executable}" -C "${TEST_TEMPLATE_SOURCE_DIR}" diff --binary HEAD
    RESULT_VARIABLE _source_diff_result
    OUTPUT_VARIABLE _source_diff
    ERROR_VARIABLE _source_diff_stderr)
if(NOT _source_diff_result EQUAL 0)
  message(FATAL_ERROR "Could not capture source working-tree diff: ${_source_diff_stderr}")
endif()
if(NOT _source_diff STREQUAL "")
  set(_source_patch "${TEST_BINARY_ROOT}/source_worktree.patch")
  file(WRITE "${_source_patch}" "${_source_diff}")
  _run_success(
      "Apply source working-tree diff to scratch clone"
      "${_git_executable}" -C "${_scratch_root}" apply --whitespace=nowarn "${_source_patch}")
endif()

_run_success(
    "List untracked source files"
    "${_git_executable}" -C "${TEST_TEMPLATE_SOURCE_DIR}" ls-files --others --exclude-standard)
string(REPLACE "\r\n" "\n" _untracked_files "${_last_stdout}")
string(REPLACE "\n" ";" _untracked_files "${_untracked_files}")
list(FILTER _untracked_files EXCLUDE REGEX "^$")
foreach(_untracked_file IN LISTS _untracked_files)
  set(_untracked_source "${TEST_TEMPLATE_SOURCE_DIR}/${_untracked_file}")
  # Git reports an untracked embedded repository, such as a fetched dependency,
  # as one directory entry. It is build state, not part of the source snapshot.
  if(IS_DIRECTORY "${_untracked_source}")
    continue()
  endif()
  get_filename_component(_untracked_parent "${_scratch_root}/${_untracked_file}" DIRECTORY)
  file(MAKE_DIRECTORY "${_untracked_parent}")
  configure_file(
      "${_untracked_source}"
      "${_scratch_root}/${_untracked_file}"
      COPYONLY)
endforeach()
_run_success("Stage source snapshot" "${_git_executable}" -C "${_scratch_root}" add -A)
_run_success(
    "Commit source snapshot under test"
    "${_git_executable}" -C "${_scratch_root}" commit --allow-empty -m "Snapshot source under test")
_run_success(
    "Create synthetic release-preparation commit"
    "${_git_executable}" -C "${_scratch_root}" commit --allow-empty -m "Start synthetic release preparation")

_read_xml_version(
    "${_scratch_root}/ros2/template_project/package.xml"
    _baseline_version)

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
    "${CMAKE_COMMAND}"
    -DTEST_TEMPLATE_SOURCE_DIR=${_scratch_root}
    -DTEST_BINARY_ROOT=${TEST_BINARY_ROOT}/untagged_overlay
    -DEXPECTED_VERSION=${_baseline_version}
    -P "${_scratch_verifier}")

_run_success(
    "Create final annotated release tag"
    "${_git_executable}" -C "${_scratch_root}" tag -a "${_synthetic_tag}" -m "Synthetic release ${_synthetic_version}")
_run_success(
    "Synchronize exact-tag release metadata"
    "${CMAKE_COMMAND}" -E env GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
    "${_bash_executable}" "${_scratch_root}/generate_version.sh" --sync-ros2)
_run_success(
    "Confirm exact-tag synchronization left manifests clean"
    "${_git_executable}" -C "${_scratch_root}" diff --exit-code -- ${_manifest_paths})

foreach(_manifest_path IN LISTS _manifest_paths)
  _run_success(
      "Read ${_manifest_path} from final tag"
      "${_git_executable}" -C "${_scratch_root}" show "${_synthetic_tag}:${_manifest_path}")
  set(_tag_manifest "${TEST_BINARY_ROOT}/tag_manifest.xml")
  file(WRITE "${_tag_manifest}" "${_last_stdout}")
  _read_xml_version("${_tag_manifest}" _tag_manifest_version)
  if(NOT _tag_manifest_version STREQUAL _synthetic_version)
    message(FATAL_ERROR
        "Final tag has ${_tag_manifest_version}, not ${_synthetic_version}, in ${_manifest_path}")
  endif()
endforeach()

_run_success(
    "Validate final tagged ROS overlay"
    "${CMAKE_COMMAND}"
    -DTEST_TEMPLATE_SOURCE_DIR=${_scratch_root}
    -DTEST_BINARY_ROOT=${TEST_BINARY_ROOT}/final_overlay
    -DEXPECTED_VERSION=${_synthetic_version}
    -P "${_scratch_verifier}")

set(_release_build "${TEST_BINARY_ROOT}/release_build")
set(_archive_output "${TEST_BINARY_ROOT}/archive_output")
set(_archive_extract "${TEST_BINARY_ROOT}/archive_extract")
file(MAKE_DIRECTORY
    "${_scratch_root}/build_release_sentinel"
    "${_scratch_root}/ros2/build/generated"
    "${_scratch_root}/ros2/install/generated"
    "${_scratch_root}/ros2/log/generated"
    "${_archive_output}"
    "${_archive_extract}")
file(WRITE "${_scratch_root}/build_release_sentinel/must_not_ship.txt" "generated build output\n")
file(WRITE "${_scratch_root}/ros2/build/generated/must_not_ship.txt" "generated ROS build output\n")
file(WRITE "${_scratch_root}/ros2/install/generated/must_not_ship.txt" "generated ROS install output\n")
file(WRITE "${_scratch_root}/ros2/log/generated/must_not_ship.txt" "generated ROS log output\n")

_run_success(
    "Configure full exact-tag source release"
    "${CMAKE_COMMAND}"
    -S "${_scratch_root}"
    -B "${_release_build}"
    -DCMAKE_BUILD_TYPE=Release
    -DENABLE_TESTS=OFF
    -DENABLE_CUDA=OFF
    -DENABLE_OPTIX=OFF
    -DENABLE_SPDLOG=OFF
    -DENABLE_FETCH_CATCH2=OFF
    -DENABLE_FETCH_SPDLOG=OFF
    -Dtemplate_project_BUILD_PROGRAMS=OFF
    -Dtemplate_project_BUILD_EXAMPLES=OFF)
_run_success(
    "Create canonical CPack source TGZ"
    "${CMAKE_COMMAND}" -E chdir "${_archive_output}"
    "${_cpack_executable}" --config "${_release_build}/CPackSourceConfig.cmake")

file(GLOB _source_archives "${_archive_output}/template_project-${_synthetic_version}.tar.gz")
list(LENGTH _source_archives _source_archive_count)
if(NOT _source_archive_count EQUAL 1)
  message(FATAL_ERROR
      "Expected one canonical source archive, found ${_source_archive_count}: ${_source_archives}")
endif()
list(GET _source_archives 0 _source_archive)
_run_success(
    "Extract canonical source TGZ outside Git"
    "${CMAKE_COMMAND}" -E chdir "${_archive_extract}"
    "${CMAKE_COMMAND}" -E tar xzf "${_source_archive}")

file(GLOB _extracted_entries LIST_DIRECTORIES TRUE "${_archive_extract}/*")
set(_extracted_roots)
foreach(_extracted_entry IN LISTS _extracted_entries)
  if(IS_DIRECTORY "${_extracted_entry}")
    list(APPEND _extracted_roots "${_extracted_entry}")
  endif()
endforeach()
list(LENGTH _extracted_roots _extracted_root_count)
if(NOT _extracted_root_count EQUAL 1)
  message(FATAL_ERROR
      "Expected one extracted source root, found ${_extracted_root_count}: ${_extracted_roots}")
endif()
list(GET _extracted_roots 0 _extracted_root)

_run_success(
    "Validate extracted no-Git canonical source"
    "${CMAKE_COMMAND}"
    -DTEST_SOURCE_ROOT=${_extracted_root}
    -DTEST_BINARY_ROOT=${TEST_BINARY_ROOT}/archive_validation
    -DEXPECTED_VERSION=${_synthetic_version}
    -DEXPECTED_FULL_VERSION=${_synthetic_version}
    -DTEST_ROS_STATIC_VERIFIER=${_extracted_root}/tests/cmake/VerifyTemplateProjectRos2Overlay.cmake
    -P "${_source_release_verifier}")

set(_missing_version_root "${TEST_BINARY_ROOT}/missing_version_source")
file(MAKE_DIRECTORY "${_missing_version_root}")
file(COPY "${_extracted_root}/" DESTINATION "${_missing_version_root}")
file(REMOVE "${_missing_version_root}/VERSION")
_run_failure(
    "Reject source archive without VERSION"
    "${CMAKE_COMMAND}"
    -DTEST_SOURCE_ROOT=${_missing_version_root}
    -DTEST_BINARY_ROOT=${TEST_BINARY_ROOT}/missing_version_validation
    -DEXPECTED_VERSION=${_synthetic_version}
    -DEXPECTED_FULL_VERSION=${_synthetic_version}
    -P "${_source_release_verifier}")

file(REMOVE_RECURSE
    "${_scratch_root}/build_release_sentinel"
    "${_scratch_root}/ros2/build"
    "${_scratch_root}/ros2/install"
    "${_scratch_root}/ros2/log")
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
