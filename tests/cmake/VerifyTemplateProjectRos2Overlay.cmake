cmake_minimum_required(VERSION 3.15)

foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT EXPECTED_VERSION)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

# EXPECTED_VERSION is generated release metadata whose strict representation is
# part of the release contract, so a syntax regex is appropriate here.
if(NOT EXPECTED_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
  message(FATAL_ERROR "EXPECTED_VERSION must be strict X.Y.Z, got '${EXPECTED_VERSION}'")
endif()

set(_root "${TEST_TEMPLATE_SOURCE_DIR}")

function(_require_path relative_path)
  if(NOT EXISTS "${_root}/${relative_path}")
    message(FATAL_ERROR "Missing ROS 2 overlay path: ${relative_path}")
  endif()
endfunction()

function(_read_required file_path out_var)
  if(NOT EXISTS "${file_path}")
    message(FATAL_ERROR "Required generated fixture not found: ${file_path}")
  endif()
  file(READ "${file_path}" _contents)
  set(${out_var} "${_contents}" PARENT_SCOPE)
endfunction()

function(_read_cache_value cache_path cache_key out_var)
  file(STRINGS "${cache_path}" _cache_lines REGEX "^${cache_key}:")
  list(LENGTH _cache_lines _cache_line_count)
  if(NOT _cache_line_count EQUAL 1)
    message(FATAL_ERROR "Missing generated CMake cache field: ${cache_key}")
  endif()
  list(GET _cache_lines 0 _cache_line)
  string(REGEX REPLACE "^[^=]*=" "" _cache_value "${_cache_line}")
  if(_cache_value STREQUAL "")
    message(FATAL_ERROR "Empty generated CMake cache field: ${cache_key}")
  endif()
  set(${out_var} "${_cache_value}" PARENT_SCOPE)
endfunction()

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
  set(_last_stderr "${_stderr}" PARENT_SCOPE)
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

function(_assert_ros2_fence relative_path)
  set(_doc_path "${_root}/${relative_path}")
  _read_required("${_doc_path}" _contents)
  # These exact comments are generator input consumed by --remove-ros2.
  string(FIND "${_contents}" "<!-- ros2-overlay-begin -->" _begin_index)
  string(FIND "${_contents}" "<!-- ros2-overlay-end -->" _end_index)
  if(_begin_index LESS 0 OR _end_index LESS 0 OR _begin_index GREATER _end_index)
    message(FATAL_ERROR "Missing or malformed ROS 2 overlay fence in ${relative_path}")
  endif()
endfunction()

function(_create_fake_target fake_root project_name)
  file(REMOVE_RECURSE "${fake_root}")
  file(MAKE_DIRECTORY
      "${fake_root}/.github/workflows"
      "${fake_root}/doc"
      "${fake_root}/examples"
      "${fake_root}/lib"
      "${fake_root}/python"
      "${fake_root}/tests")
  file(WRITE "${fake_root}/build_lib.sh" "#!/usr/bin/env bash\n")
  file(WRITE "${fake_root}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
set(project_name \"${project_name}\")
set(project_description \"Derived ${project_name} project\")
set(project_homepage_url \"https://example.test/${project_name}\")
set(PROJECT_MAINTAINER_NAME \"Derived Maintainer\" CACHE STRING \"\")
set(PROJECT_MAINTAINER_EMAIL \"maintainer@example.test\" CACHE STRING \"\")
set(PROJECT_LICENSE \"Apache-2.0\" CACHE STRING \"\")
project(\${project_name}
  VERSION 2.3.4
  DESCRIPTION \"\${project_description}\"
  HOMEPAGE_URL \"\${project_homepage_url}\"
  LANGUAGES NONE)
")
  configure_file(
      "${_root}/generate_version.sh"
      "${fake_root}/generate_version.sh"
      COPYONLY)
  file(WRITE "${fake_root}/VERSION"
"Project version: 2.3.4
Project version core: 2.3.4
Project version prerelease: <none>
Project version metadata: <none>
Full version: 2.3.4
")
endfunction()

foreach(_required_path
    "CMakeLists.txt"
    ".github/workflows/build_ros2_overlay.yml"
    ".github/workflows/build_ros2_overlay.yml.tpl"
    "build_ros2.sh"
    "add_ros2_support.sh"
    "tailor_template_cleanup.sh"
    "generate_version.sh"
    "doc/ros2_overlay.md"
    "ros2/tools/sync_package_metadata.py"
    "tests/template_test/testRos2OverlayStatic.py"
    "ros2/template_project/package.xml"
    "ros2/template_project_interfaces/package.xml"
    "ros2/template_project_ros/package.xml"
    "ros2/template_project_spinup/package.xml")
  _require_path("${_required_path}")
endforeach()

find_program(_bash_executable NAMES bash REQUIRED)
find_program(_python_executable NAMES python3 REQUIRED)

foreach(_script
    "build_ros2.sh"
    "add_ros2_support.sh"
    "tailor_template_cleanup.sh"
    "generate_version.sh")
  _run_success(
      "Validate ${_script} syntax"
      "${_bash_executable}" -n "${_root}/${_script}")
endforeach()

foreach(_marker
    "python/COLCON_IGNORE"
    "lib/COLCON_IGNORE"
    "examples/COLCON_IGNORE"
    "tests/COLCON_IGNORE")
  _require_path("${_marker}")
endforeach()

foreach(_fenced_doc
    "README.md"
    "AGENTS.md"
    "CLAUDE.md"
    "doc/bootstrap_prompts.md"
    "doc/template_usage.md"
    "doc/versioning.md")
  _assert_ros2_fence("${_fenced_doc}")
endforeach()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
set(_metadata_probe "${TEST_BINARY_ROOT}/metadata_probe")
_run_success(
    "Configure root project metadata without build languages"
    "${CMAKE_COMMAND}" -S "${_root}" -B "${_metadata_probe}"
    -DPROJECT_METADATA_ONLY=ON)
set(_metadata_cache_path "${_metadata_probe}/CMakeCache.txt")
foreach(_cache_key
    CMAKE_PROJECT_DESCRIPTION
    CMAKE_PROJECT_HOMEPAGE_URL
    PROJECT_MAINTAINER_NAME
    PROJECT_MAINTAINER_EMAIL
    PROJECT_LICENSE)
  _read_cache_value("${_metadata_cache_path}" "${_cache_key}" _cache_value)
endforeach()
file(STRINGS "${_metadata_cache_path}" _metadata_cxx_compiler
    REGEX "^CMAKE_CXX_COMPILER:")
if(_metadata_cxx_compiler)
  message(FATAL_ERROR "Metadata-only configure unexpectedly enabled C++.")
endif()
if(EXISTS "${_metadata_probe}/src")
  message(FATAL_ERROR "Metadata-only configure unexpectedly entered src/.")
endif()

_run_success(
    "Parse and validate source ROS manifests"
    "${_python_executable}"
    "${_root}/tests/template_test/testRos2OverlayStatic.py"
    --repo-root "${_root}"
    --expected-version "${EXPECTED_VERSION}"
    --metadata-cache "${_metadata_cache_path}")

set(_fake_list "${TEST_BINARY_ROOT}/fake_list")
set(_fake_conflict "${TEST_BINARY_ROOT}/fake_conflict")
set(_fake_doc_conflict "${TEST_BINARY_ROOT}/fake_doc_conflict")
set(_fake_workflow_conflict "${TEST_BINARY_ROOT}/fake_workflow_conflict")
set(_fake_workflow_no_ci "${TEST_BINARY_ROOT}/fake_workflow_no_ci")
set(_fake_apply "${TEST_BINARY_ROOT}/fake_apply")
set(_fake_apply_ci "${TEST_BINARY_ROOT}/fake_apply_ci")
set(_fake_boundary "${TEST_BINARY_ROOT}/fake_boundary")

_create_fake_target("${_fake_list}" "my_template_project_x")
_run_success(
    "List ROS 2 rollout plan for fake target"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --list --root "${_fake_list}")
if(EXISTS "${_fake_list}/ros2")
  message(FATAL_ERROR "Rollout list mode modified the target.")
endif()

_run_failure(
    "Reject rollout verification without apply mode"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --verify --root "${_fake_list}")

_create_fake_target("${_fake_conflict}" "space_nav")
file(MAKE_DIRECTORY "${_fake_conflict}/ros2")
_run_failure(
    "Refuse target with existing ROS overlay"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --apply --yes --root "${_fake_conflict}")

_create_fake_target("${_fake_doc_conflict}" "space_nav")
file(WRITE "${_fake_doc_conflict}/doc/ros2_overlay.md"
    "target-owned documentation\n")
_run_failure(
    "Refuse target with existing ROS documentation"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --apply --yes --root "${_fake_doc_conflict}")
if(EXISTS "${_fake_doc_conflict}/ros2"
    OR EXISTS "${_fake_doc_conflict}/build_ros2.sh")
  message(FATAL_ERROR "Documentation collision produced a partial overlay.")
endif()
_read_required("${_fake_doc_conflict}/doc/ros2_overlay.md" _target_doc_contents)
if(NOT _target_doc_contents STREQUAL "target-owned documentation\n")
  message(FATAL_ERROR "Documentation collision changed the target-owned file.")
endif()

_create_fake_target("${_fake_workflow_conflict}" "space_nav")
file(WRITE "${_fake_workflow_conflict}/.github/workflows/build_ros2_overlay.yml"
    "target-owned workflow\n")
_run_failure(
    "Refuse target with existing ROS workflow"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --apply --yes --root "${_fake_workflow_conflict}")
if(EXISTS "${_fake_workflow_conflict}/ros2"
    OR EXISTS "${_fake_workflow_conflict}/build_ros2.sh")
  message(FATAL_ERROR "Workflow collision produced a partial overlay.")
endif()
_read_required(
    "${_fake_workflow_conflict}/.github/workflows/build_ros2_overlay.yml"
    _target_workflow_contents)
if(NOT _target_workflow_contents STREQUAL "target-owned workflow\n")
  message(FATAL_ERROR "Workflow collision changed the target-owned file.")
endif()

_create_fake_target("${_fake_workflow_no_ci}" "space_nav")
file(WRITE "${_fake_workflow_no_ci}/.github/workflows/build_ros2_overlay.yml"
    "target-owned workflow\n")
_run_success(
    "Ignore target workflow under --no-ci"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --apply --yes --no-ci --root "${_fake_workflow_no_ci}")
if(NOT EXISTS "${_fake_workflow_no_ci}/ros2"
    OR NOT EXISTS "${_fake_workflow_no_ci}/build_ros2.sh")
  message(FATAL_ERROR "--no-ci rollout omitted required overlay paths.")
endif()
_read_required(
    "${_fake_workflow_no_ci}/.github/workflows/build_ros2_overlay.yml"
    _no_ci_workflow_contents)
if(NOT _no_ci_workflow_contents STREQUAL "target-owned workflow\n")
  message(FATAL_ERROR "--no-ci rollout changed the target workflow.")
endif()

_create_fake_target("${_fake_apply}" "space_nav")
_run_success(
    "Apply ROS rollout without CI"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --apply --yes --no-ci --root "${_fake_apply}")
foreach(_expected_path
    "build_ros2.sh"
    "ros2/tools/sync_package_metadata.py"
    "ros2/space_nav/package.xml"
    "ros2/space_nav_interfaces/package.xml"
    "ros2/space_nav_ros/package.xml"
    "ros2/space_nav_spinup/package.xml"
    "python/COLCON_IGNORE"
    "lib/COLCON_IGNORE"
    "examples/COLCON_IGNORE"
    "tests/COLCON_IGNORE")
  if(NOT EXISTS "${_fake_apply}/${_expected_path}")
    message(FATAL_ERROR "Rollout omitted ${_expected_path}")
  endif()
endforeach()
foreach(_forbidden_path
    "add_ros2_support.sh"
    "tests/cmake/VerifyTemplateProjectRos2Overlay.cmake"
    "ros2/build"
    "ros2/install"
    "ros2/log")
  if(EXISTS "${_fake_apply}/${_forbidden_path}")
    message(FATAL_ERROR "Rollout unexpectedly copied ${_forbidden_path}")
  endif()
endforeach()

_run_success(
    "Synchronize copied overlay metadata"
    "${CMAKE_COMMAND}" -E env "GIT_CEILING_DIRECTORIES=${TEST_BINARY_ROOT}"
    "${_bash_executable}" "${_fake_apply}/generate_version.sh" --sync-ros2)
_run_success(
    "Parse copied overlay manifests"
    "${_python_executable}"
    "${_root}/tests/template_test/testRos2OverlayStatic.py"
    --repo-root "${_fake_apply}"
    --expected-version 2.3.4)

# Placeholder removal is generated rollout output, so exact textual absence is
# a valid generator contract here.
file(GLOB_RECURSE _fake_apply_files LIST_DIRECTORIES false
    "${_fake_apply}/ros2/*")
foreach(_fake_file IN LISTS _fake_apply_files)
  file(READ "${_fake_file}" _fake_contents)
  if(_fake_contents MATCHES "template_project")
    message(FATAL_ERROR "Placeholder remained in generated file ${_fake_file}")
  endif()
endforeach()

_create_fake_target("${_fake_apply_ci}" "space_nav")
_run_success(
    "Apply ROS rollout with generic CI"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --apply --yes --root "${_fake_apply_ci}")
set(_generated_workflow
    "${_fake_apply_ci}/.github/workflows/build_ros2_overlay.yml")
if(NOT EXISTS "${_generated_workflow}"
    OR EXISTS "${_fake_apply_ci}/.github/workflows/build_ros2_overlay.yml.tpl")
  message(FATAL_ERROR "Rollout did not materialize exactly one runnable workflow.")
endif()
# The workflow is generator output copied from the generic template; byte
# equality is the intended generation contract.
_run_success(
    "Compare generated workflow with its template"
    "${CMAKE_COMMAND}" -E compare_files
    "${_generated_workflow}"
    "${_root}/.github/workflows/build_ros2_overlay.yml.tpl")

_create_fake_target("${_fake_boundary}" "my_template_project_x")
_run_success(
    "Apply ROS rollout to a word-boundary project name"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --apply --yes --no-ci --root "${_fake_boundary}")
if(NOT EXISTS "${_fake_boundary}/ros2/my_template_project_x/package.xml"
    OR EXISTS "${_fake_boundary}/ros2/my_my_template_project_x_x/package.xml")
  message(FATAL_ERROR "Rollout violated identifier-boundary renaming.")
endif()

set(_fake_cmake_name_split "${TEST_BINARY_ROOT}/fake_cmake_name_split")
_create_fake_target("${_fake_cmake_name_split}" "space-nav-frontend")
_run_success(
    "Apply ROS rollout with a non-ROS CMake package name"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --apply --yes --no-ci --root "${_fake_cmake_name_split}")
foreach(_expected_path
    "ros2/space_nav_frontend/package.xml"
    "ros2/space_nav_frontend_interfaces/package.xml"
    "ros2/space_nav_frontend_ros/package.xml"
    "ros2/space_nav_frontend_spinup/package.xml")
  if(NOT EXISTS "${_fake_cmake_name_split}/${_expected_path}")
    message(FATAL_ERROR "Split-name rollout omitted ${_expected_path}")
  endif()
endforeach()

# These CMake tokens are generated code from the rollout renamer, making their
# exact representation part of this generator test.
_read_required(
    "${_fake_cmake_name_split}/ros2/space_nav_frontend_ros/CMakeLists.txt"
    _split_bridge_cmake)
foreach(_generated_token
    "find_package(space-nav-frontend REQUIRED)"
    "space-nav-frontend::space-nav-frontend")
  string(FIND "${_split_bridge_cmake}" "${_generated_token}" _token_index)
  if(_token_index LESS 0)
    message(FATAL_ERROR "Generated bridge CMake omitted '${_generated_token}'.")
  endif()
endforeach()
_run_success(
    "Parse generated split-name dependencies"
    "${_python_executable}" -c
    "import sys, xml.etree.ElementTree as ET; root=ET.parse(sys.argv[1]).getroot(); deps={node.text for node in root.findall('depend')}; assert 'space_nav_frontend' in deps; assert 'space-nav-frontend' not in deps"
    "${_fake_cmake_name_split}/ros2/space_nav_frontend_ros/package.xml")

set(_fake_ros_prefix_override "${TEST_BINARY_ROOT}/fake_ros_prefix_override")
_create_fake_target("${_fake_ros_prefix_override}" "space-nav-frontend")
_run_success(
    "Apply rollout with an explicit ROS prefix"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --apply --yes --no-ci --root "${_fake_ros_prefix_override}"
    --ros-prefix snf)
if(NOT EXISTS "${_fake_ros_prefix_override}/ros2/snf_ros/package.xml")
  message(FATAL_ERROR "--ros-prefix did not control generated package names.")
endif()

set(_fake_invalid_ros_prefix "${TEST_BINARY_ROOT}/fake_invalid_ros_prefix")
_create_fake_target("${_fake_invalid_ros_prefix}" "space-nav-frontend")
_run_failure(
    "Reject an invalid explicit ROS prefix"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --list --root "${_fake_invalid_ros_prefix}" --ros-prefix bad-name)

set(_fake_rollout_source "${TEST_BINARY_ROOT}/fake_rollout_source")
set(_fake_filtered_rollout "${TEST_BINARY_ROOT}/fake_filtered_rollout")
file(REMOVE_RECURSE "${_fake_rollout_source}")
file(MAKE_DIRECTORY
    "${_fake_rollout_source}/ros2/template_project/__pycache__")
configure_file(
    "${_root}/add_ros2_support.sh"
    "${_fake_rollout_source}/add_ros2_support.sh"
    COPYONLY)
file(WRITE "${_fake_rollout_source}/build_ros2.sh" "#!/usr/bin/env bash\n")
file(WRITE "${_fake_rollout_source}/ros2/template_project/package.xml"
    "<package><name>template_project</name></package>\n")
file(WRITE
    "${_fake_rollout_source}/ros2/template_project/__pycache__/generated.cpython-312.pyc"
    "generated bytecode\n")
file(WRITE "${_fake_rollout_source}/ros2/template_project/generated.pyc"
    "generated bytecode\n")
file(WRITE
    "${_fake_rollout_source}/ros2/template_project/nottemplate_projectile.txt"
    "boundary fixture\n")

_create_fake_target("${_fake_filtered_rollout}" "space_nav")
_run_success(
    "Apply filtered rollout from a synthetic source"
    "${_bash_executable}" "${_fake_rollout_source}/add_ros2_support.sh"
    --apply --yes --no-ci --root "${_fake_filtered_rollout}")
if(EXISTS "${_fake_filtered_rollout}/ros2/space_nav/__pycache__"
    OR EXISTS "${_fake_filtered_rollout}/ros2/space_nav/generated.pyc")
  message(FATAL_ERROR "Rollout copied generated Python cache artifacts.")
endif()
if(NOT EXISTS
    "${_fake_filtered_rollout}/ros2/space_nav/nottemplate_projectile.txt")
  message(FATAL_ERROR "Rollout renamed an unrelated path substring.")
endif()
