cmake_minimum_required(VERSION 3.15)

foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT EXPECTED_VERSION)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

if(NOT EXPECTED_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
  message(FATAL_ERROR "EXPECTED_VERSION must be strict X.Y.Z, got '${EXPECTED_VERSION}'")
endif()

set(_root "${TEST_TEMPLATE_SOURCE_DIR}")

function(_read_required file_path out_var)
  if(NOT EXISTS "${file_path}")
    message(FATAL_ERROR "Required file not found: ${file_path}")
  endif()
  file(READ "${file_path}" _contents)
  set(${out_var} "${_contents}" PARENT_SCOPE)
endfunction()

function(_assert_matches file_path pattern)
  _read_required("${file_path}" _contents)
  if(NOT _contents MATCHES "${pattern}")
    message(FATAL_ERROR "Expected '${file_path}' to match '${pattern}'")
  endif()
endfunction()

function(_assert_not_matches file_path pattern)
  _read_required("${file_path}" _contents)
  if(_contents MATCHES "${pattern}")
    message(FATAL_ERROR "Expected '${file_path}' not to match '${pattern}'")
  endif()
endfunction()

function(_read_cache_value cache_path cache_key out_var)
  file(STRINGS "${cache_path}" _cache_lines REGEX "^${cache_key}:")
  list(LENGTH _cache_lines _cache_line_count)
  if(NOT _cache_line_count EQUAL 1)
    message(FATAL_ERROR "Missing CMake cache field: ${cache_key}")
  endif()
  list(GET _cache_lines 0 _cache_line)
  string(REGEX REPLACE "^[^=]*=" "" _cache_value "${_cache_line}")
  if(_cache_value STREQUAL "")
    message(FATAL_ERROR "Empty CMake cache field: ${cache_key}")
  endif()
  set(${out_var} "${_cache_value}" PARENT_SCOPE)
endfunction()

function(_assert_ros2_fence relative_path)
  set(_doc_path "${_root}/${relative_path}")
  _read_required("${_doc_path}" _contents)
  if(NOT _contents MATCHES "<!-- ros2-overlay-begin -->")
    message(FATAL_ERROR "Missing ROS 2 overlay begin fence in ${relative_path}")
  endif()
  if(NOT _contents MATCHES "<!-- ros2-overlay-end -->")
    message(FATAL_ERROR "Missing ROS 2 overlay end fence in ${relative_path}")
  endif()
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
    "ros2/template_project/CMakeLists.txt"
    "ros2/template_project/package.xml"
    "ros2/template_project_interfaces/package.xml"
    "ros2/template_project_ros/package.xml"
    "ros2/template_project_spinup/package.xml")
  if(NOT EXISTS "${_root}/${_required_path}")
    message(FATAL_ERROR "Missing ROS 2 overlay path: ${_required_path}")
  endif()
endforeach()

set(_root_cmake "${_root}/CMakeLists.txt")
_read_required("${_root_cmake}" _root_cmake_contents)
string(FIND "${_root_cmake_contents}" "if(NOT DEFINED CMAKE_INSTALL_PREFIX)" _install_prefix_default_index)
string(FIND "${_root_cmake_contents}" "project(\${project_name}" _project_command_index)
if(_install_prefix_default_index LESS 0
    OR _project_command_index LESS 0
    OR _install_prefix_default_index GREATER _project_command_index)
  message(FATAL_ERROR
      "The repository-local install prefix default must remain before project() initializes CMake's platform default.")
endif()
_assert_matches("${_root_cmake}" "set\\(project_description")
_assert_matches("${_root_cmake}" "set\\(project_homepage_url")
_assert_matches("${_root_cmake}" "PROJECT_MAINTAINER_NAME[ \\t]+\"[^\"]+\"[ \\t]+CACHE[ \\t]+STRING")
_assert_matches("${_root_cmake}" "PROJECT_MAINTAINER_EMAIL[ \\t]+\"[^\"]+\"[ \\t]+CACHE[ \\t]+STRING")
_assert_matches("${_root_cmake}" "PROJECT_LICENSE[ \\t]+\"[^\"]+\"[ \\t]+CACHE[ \\t]+STRING")
_assert_matches("${_root_cmake}" "PROJECT_METADATA_ONLY")
_assert_matches("${_root_cmake}" "set\\(languages NONE\\)")
_assert_matches("${_root_cmake}" "DESCRIPTION[ \\t]+\"\\$\\{project_description\\}\"")
_assert_matches("${_root_cmake}" "HOMEPAGE_URL[ \\t]+\"\\$\\{project_homepage_url\\}\"")
_assert_matches("${_root_cmake}" "return\\(\\)")
_assert_matches("${_root_cmake}" "CPACK_PACKAGE_DESCRIPTION_SUMMARY[ \\t]+\"\\$\\{PROJECT_DESCRIPTION\\}\"")
_assert_matches("${_root_cmake}" "CPACK_PACKAGE_HOMEPAGE_URL[ \\t]+\"\\$\\{PROJECT_HOMEPAGE_URL\\}\"")
_assert_matches("${_root_cmake}" "CPACK_PACKAGE_VENDOR[ \\t]+\"\\$\\{PROJECT_MAINTAINER_NAME\\}\"")
_assert_matches("${_root_cmake}" "CPACK_PACKAGE_CONTACT[ \\t]+\"\\$\\{PROJECT_MAINTAINER_NAME\\}")

foreach(_nested_header_module
    "src/wrapped_impl/CMakeLists.txt"
    "src/utils/CMakeLists.txt"
    "src/utils/logging/CMakeLists.txt"
    "src/utils/wrap_adapters/CMakeLists.txt"
    "src/template_src/CMakeLists.txt"
    "src/template_src_kernels/CMakeLists.txt")
  _assert_matches("${_root}/${_nested_header_module}" "PROJECT_SOURCE_DIR")
  _assert_not_matches("${_root}/${_nested_header_module}" "CMAKE_SOURCE_DIR")
endforeach()

foreach(_cuda_source_discovery_file
    "src/CMakeLists.txt"
    "src/wrapped_impl/CMakeLists.txt"
    "src/utils/CMakeLists.txt"
    "src/utils/logging/CMakeLists.txt"
    "src/utils/wrap_adapters/CMakeLists.txt"
    "src/template_src/CMakeLists.txt"
    "src/template_src_kernels/CMakeLists.txt")
  _assert_not_matches(
      "${_root}/${_cuda_source_discovery_file}"
      "\\*\\.cpp;[ \\t]*\\*\\.cu")
endforeach()

set(_cuda_handler "${_root}/cmake/HandleCUDA.cmake")
_assert_matches("${_cuda_handler}" "BUILD_INTERFACE")

set(_optix_handler "${_root}/cmake/HandleOptiX.cmake")
_assert_not_matches("${_optix_handler}" "INSTALL_INTERFACE:include/optix")

set(_package_config_template "${_root}/src/cmake/template_projectConfig.cmake.in")
_assert_matches("${_package_config_template}" "find_path")
_assert_matches("${_package_config_template}" "optix\\.h")
_assert_matches("${_package_config_template}" "OPTIX_ROOT")
_assert_matches("${_package_config_template}" "ENV\\{OPTIX_HOME\\}")
_assert_matches("${_package_config_template}" "INTERFACE_INCLUDE_DIRECTORIES")
_assert_not_matches("${_package_config_template}" "/home/|/Users/")

set(_metadata_helper "${_root}/ros2/tools/sync_package_metadata.py")
_assert_matches("${_metadata_helper}" "xml\\.etree\\.ElementTree")
_assert_matches("${_metadata_helper}" "insert_comments=True")
_assert_matches("${_metadata_helper}" "insert_pis=True")
_assert_matches("${_metadata_helper}" "os\\.replace")

find_program(_bash_executable NAMES bash)
if(NOT _bash_executable)
  message(FATAL_ERROR "bash executable not found; cannot validate build_ros2.sh syntax")
endif()

execute_process(
    COMMAND "${_bash_executable}" -n "${_root}/build_ros2.sh"
    RESULT_VARIABLE _bash_result
    OUTPUT_VARIABLE _bash_stdout
    ERROR_VARIABLE _bash_stderr)
if(NOT _bash_result EQUAL 0)
  message(FATAL_ERROR
      "build_ros2.sh syntax check failed with exit code ${_bash_result}.\n"
      "stdout:\n${_bash_stdout}\n"
      "stderr:\n${_bash_stderr}")
endif()

execute_process(
    COMMAND "${_bash_executable}" -n "${_root}/add_ros2_support.sh"
    RESULT_VARIABLE _add_bash_result
    OUTPUT_VARIABLE _add_bash_stdout
    ERROR_VARIABLE _add_bash_stderr)
if(NOT _add_bash_result EQUAL 0)
  message(FATAL_ERROR
      "add_ros2_support.sh syntax check failed with exit code ${_add_bash_result}.\n"
      "stdout:\n${_add_bash_stdout}\n"
      "stderr:\n${_add_bash_stderr}")
endif()

foreach(_marker
    "python/COLCON_IGNORE"
    "lib/COLCON_IGNORE"
    "examples/COLCON_IGNORE"
    "tests/COLCON_IGNORE")
  if(NOT EXISTS "${_root}/${_marker}")
    message(FATAL_ERROR "Missing required colcon marker: ${_marker}")
  endif()
endforeach()

foreach(_package_name
    template_project
    template_project_interfaces
    template_project_ros
    template_project_spinup)
  set(_package_xml "${_root}/ros2/${_package_name}/package.xml")
  _read_required("${_package_xml}" _package_contents)
  string(REGEX MATCH "<version>[ \t\r\n]*([^< \t\r\n]+)[ \t\r\n]*</version>" _version_match "${_package_contents}")
  if(NOT _version_match)
    message(FATAL_ERROR "No <version> tag found in ${_package_xml}")
  endif()
  set(_package_version "${CMAKE_MATCH_1}")
  if(NOT "${_package_version}" STREQUAL "${EXPECTED_VERSION}")
    message(FATAL_ERROR
        "Expected ${_package_xml} version '${EXPECTED_VERSION}', got '${_package_version}'")
  endif()
  if(_package_contents MATCHES "example\\.com")
    message(FATAL_ERROR "Placeholder metadata remains in ${_package_xml}")
  endif()
  if(NOT _package_contents MATCHES "<url[ \\t]+type=\\\"website\\\">[^<]+</url>")
    message(FATAL_ERROR "No website URL metadata found in ${_package_xml}")
  endif()
endforeach()

set(_interfaces_cmake "${_root}/ros2/template_project_interfaces/CMakeLists.txt")
set(_interfaces_package "${_root}/ros2/template_project_interfaces/package.xml")
_assert_not_matches("${_interfaces_cmake}" "std_msgs")
_assert_not_matches("${_interfaces_package}" "<depend>std_msgs</depend>")
_assert_not_matches("${_interfaces_package}" "ament_lint_auto|ament_lint_common")

set(_shim_cmake "${_root}/ros2/template_project/CMakeLists.txt")
_assert_matches("${_shim_cmake}" "CMAKE_MODULE_PATH")
_assert_matches("${_shim_cmake}" "ENABLE_TESTS[ \t\r\n]+OFF")
_assert_matches("${_shim_cmake}" "ENABLE_FETCH_CATCH2[ \t\r\n]+OFF")
_assert_matches("${_shim_cmake}" "_ros2_overlay_legacy_version_file")
_assert_matches("${_shim_cmake}" "_ros2_overlay_nested_version_file")
_assert_matches("${_shim_cmake}" "configure_file")
_assert_not_matches("${_shim_cmake}" "python/")

set(_ros_bridge_cmake "${_root}/ros2/template_project_ros/CMakeLists.txt")
_assert_matches("${_ros_bridge_cmake}" "additive rollout compatibility")
_assert_matches(
    "${_ros_bridge_cmake}"
    "target_include_directories\\(template_project_ros_conversions[^)]*TEMPLATE_PROJECT_REPOSITORY_ROOT}/src")
_assert_matches(
    "${_ros_bridge_cmake}"
    "target_link_libraries\\(template_project_ros_component[^)]*template_project::template_project")
_assert_not_matches(
    "${_ros_bridge_cmake}"
    "target_include_directories\\(template_project_ros_component[^)]*TEMPLATE_PROJECT_REPOSITORY_ROOT}/src")

set(_conversions_cpp "${_root}/ros2/template_project_ros/src/conversions.cpp")
_assert_matches("${_conversions_cpp}" "template-core call site \\(EDIT ME")
_assert_matches("${_conversions_cpp}" "#include \"wrapped_impl/CWrapperPlaceholder\\.h\"")
_assert_matches("${_conversions_cpp}" "double EvaluateTemplateCore")
_assert_matches("${_conversions_cpp}" "cpp_playground::CWrapperPlaceholder::multiplyBy2")

set(_standalone_launch "${_root}/ros2/template_project_spinup/launch/template_project.launch.py")
_assert_matches("${_standalone_launch}" "from launch_ros.actions import LifecycleNode")
_assert_matches("${_standalone_launch}" "LifecycleNode\\(")
_assert_matches("${_standalone_launch}" "autostart=True")
_assert_matches("${_standalone_launch}" "# from launch_ros.actions import Node")
_assert_matches("${_standalone_launch}" "# Node\\(")
_assert_matches("${_standalone_launch}" "external lifecycle manager")

set(_composition_launch "${_root}/ros2/template_project_spinup/launch/template_project_composition.launch.py")
_assert_matches("${_composition_launch}" "from launch_ros.descriptions import ComposableLifecycleNode as _RosComposableLifecycleNode")
_assert_matches("${_composition_launch}" "ComposableLifecycleNode\\(")
_assert_matches("${_composition_launch}" "autostart=True")
_assert_matches("${_composition_launch}" "# from launch_ros.descriptions import ComposableNode")
_assert_matches("${_composition_launch}" "# ComposableNode\\(")
_assert_matches("${_composition_launch}" "external lifecycle manager")
_assert_matches("${_composition_launch}" "class ComposableLifecycleNode\\(_RosComposableLifecycleNode\\)")
_assert_matches("${_composition_launch}" "LifecycleEventManager")
_assert_matches("${_composition_launch}" "charFullyQualifiedName_")
_assert_matches("${_composition_launch}" "make_namespace_absolute")
_assert_matches("${_composition_launch}" "launch_configurations.get\\(\"ros_namespace\"")
_assert_matches("${_composition_launch}" "super\\(\\).__init__\\(autostart=False")
_assert_matches("${_composition_launch}" "LifecycleTransition\\(")
_assert_matches("${_composition_launch}" "makeAutostartAction")

set(_spinup_config "${_root}/ros2/template_project_spinup/config/template_project.yaml")
_assert_matches("${_spinup_config}" "/\\*\\*:")

set(_spinup_cmake "${_root}/ros2/template_project_spinup/CMakeLists.txt")
_assert_matches("${_spinup_cmake}" "find_package\\(launch_testing_ament_cmake REQUIRED\\)")
_assert_matches("${_spinup_cmake}" "add_launch_test\\(")
_assert_matches("${_spinup_cmake}" "TIMEOUT")

set(_spinup_package "${_root}/ros2/template_project_spinup/package.xml")
foreach(_runtime_dependency ament_index_python lifecycle_msgs rclcpp_components)
  _assert_matches("${_spinup_package}" "<exec_depend>${_runtime_dependency}</exec_depend>")
endforeach()
foreach(_test_dependency launch_testing_ament_cmake rclpy lifecycle_msgs template_project_interfaces)
  _assert_matches("${_spinup_package}" "<test_depend>${_test_dependency}</test_depend>")
endforeach()

set(_spinup_launch_test "${_root}/ros2/template_project_spinup/test/test_spinup_launch.py")
_assert_matches("${_spinup_launch_test}" "launch_testing.parametrize")
_assert_matches("${_spinup_launch_test}" "template_project.launch.py")
_assert_matches("${_spinup_launch_test}" "template_project_composition.launch.py")
_assert_matches("${_spinup_launch_test}" "PushRosNamespace")
_assert_matches("${_spinup_launch_test}" "integration")
_assert_matches("${_spinup_launch_test}" "PRIMARY_STATE_ACTIVE")
_assert_matches("${_spinup_launch_test}" "f\"{charNodePath_}/run_algorithm\"")
_assert_matches("${_spinup_launch_test}" "from template_project_interfaces.msg import AlgorithmStatus")
_assert_matches("${_spinup_launch_test}" "f\"{charNodePath_}/status\"")
_assert_matches("${_spinup_launch_test}" "create_subscription")
_assert_matches("${_spinup_launch_test}" "get_publisher_count")
_assert_matches("${_spinup_launch_test}" "dDiscoverySettleDeadline_")
_assert_matches("${_spinup_launch_test}" "last_input")
_assert_matches("${_spinup_launch_test}" "last_output")
_assert_matches("${_spinup_launch_test}" "evaluation_count")
_assert_matches("${_spinup_launch_test}" "stamp")
_assert_matches("${_spinup_launch_test}" "destroy_subscription")
_assert_matches("${_spinup_launch_test}" "14.0")
_assert_matches("${_spinup_launch_test}" "ok")

set(_ros2_overlay_doc "${_root}/doc/ros2_overlay.md")
_assert_matches("${_ros2_overlay_doc}" "manual removal")
_assert_matches("${_ros2_overlay_doc}" "TEMPLATE_PROJECT_ENABLE_CUDA")
_assert_matches("${_ros2_overlay_doc}" "TEMPLATE_PROJECT_ENABLE_OPTIX")
_assert_matches("${_ros2_overlay_doc}" "stable[ \t\r\n]+overlay[ \t\r\n]+facade")
_assert_matches("${_ros2_overlay_doc}" "intentionally survive")
_assert_matches("${_ros2_overlay_doc}" "--cmake-arg -DENABLE_CUDA=ON")
_assert_matches("${_ros2_overlay_doc}" "--cmake-arg -DENABLE_OPTIX=ON")
_assert_matches("${_ros2_overlay_doc}" "overwritten by the shim")

_read_required("${_root}/generate_version.sh" _generate_version_script)
if(NOT _generate_version_script MATCHES "--sync-ros2")
  message(FATAL_ERROR "generate_version.sh does not advertise --sync-ros2")
endif()
if(NOT _generate_version_script MATCHES "tools/sync_package_metadata\\.py"
    OR NOT _generate_version_script MATCHES "python3")
  message(FATAL_ERROR "generate_version.sh does not invoke the structured ROS metadata helper")
endif()
if(NOT _generate_version_script MATCHES "ROS2_PROJECT_METADATA_SYNC=1")
  message(FATAL_ERROR "generate_version.sh does not expose the ROS metadata sync capability marker")
endif()

_read_required("${_root}/build_ros2.sh" _build_ros2_script)
if(NOT _build_ros2_script MATCHES "generate_version\\.sh[^\\n]*--sync-ros2")
  message(FATAL_ERROR "build_ros2.sh does not invoke generate_version.sh --sync-ros2")
endif()
if(NOT _build_ros2_script MATCHES "ROS2_PROJECT_METADATA_SYNC=1"
    OR NOT _build_ros2_script MATCHES "predates project metadata sync")
  message(FATAL_ERROR "build_ros2.sh does not reject an older version-only sync helper")
endif()
if(NOT _build_ros2_script MATCHES "package metadata"
    OR NOT _build_ros2_script MATCHES "legacy flag name")
  message(FATAL_ERROR "build_ros2.sh does not describe the expanded project metadata sync contract")
endif()
if(NOT _build_ros2_script MATCHES "test-result --test-result-base")
  message(FATAL_ERROR "build_ros2.sh does not scope selected-package result checks")
endif()

_read_required("${_root}/add_ros2_support.sh" _add_ros2_support_script)
if(NOT _add_ros2_support_script MATCHES "grep -Iq \\. \"\\$\\{file_path_\\}\" \\|\\| return 0")
  message(FATAL_ERROR "add_ros2_support.sh must suppress grep exit 1 while skipping non-text files.")
endif()
if(NOT _add_ros2_support_script MATCHES "project-ci-template: generic")
  message(FATAL_ERROR "add_ros2_support.sh must validate generic workflow ownership before rollout.")
endif()
if(NOT _add_ros2_support_script MATCHES "--ros-prefix")
  message(FATAL_ERROR "add_ros2_support.sh must support overriding the derived ROS package prefix.")
endif()
if(NOT _add_ros2_support_script MATCHES "cmake_project_name")
  message(FATAL_ERROR "add_ros2_support.sh must keep the CMake project name separate from the ROS package prefix.")
endif()
if(NOT _add_ros2_support_script MATCHES "ros_package_prefix")
  message(FATAL_ERROR "add_ros2_support.sh must track the ROS package prefix separately.")
endif()
if(_add_ros2_support_script MATCHES "target_has_conflicts")
  message(FATAL_ERROR "add_ros2_support.sh still uses inverted target_has_conflicts naming.")
endif()
if(NOT _add_ros2_support_script MATCHES "mktemp -d[^\\n]*add_ros2_support_verify")
  message(FATAL_ERROR "add_ros2_support.sh verify path does not create an isolated scratch dir.")
endif()
if(NOT _add_ros2_support_script MATCHES "trap[^\n]*rm -rf[^\n]*VERIFY_SCRATCH_DIR")
  message(FATAL_ERROR "add_ros2_support.sh verify scratch dir is not guarded by cleanup.")
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
  set(_last_stdout "${_stdout}" PARENT_SCOPE)
  set(_last_stderr "${_stderr}" PARENT_SCOPE)
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

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
set(_metadata_probe "${TEST_BINARY_ROOT}/metadata_probe")
_run_success(
    "Configure root project metadata without build languages"
    "${CMAKE_COMMAND}" -S "${_root}" -B "${_metadata_probe}" -DPROJECT_METADATA_ONLY=ON)
set(_metadata_cache_path "${_metadata_probe}/CMakeCache.txt")
_read_cache_value("${_metadata_cache_path}" "CMAKE_PROJECT_DESCRIPTION" _project_description)
_read_cache_value("${_metadata_cache_path}" "CMAKE_PROJECT_HOMEPAGE_URL" _project_homepage_url)
_read_cache_value("${_metadata_cache_path}" "PROJECT_MAINTAINER_NAME" _project_maintainer_name)
_read_cache_value("${_metadata_cache_path}" "PROJECT_MAINTAINER_EMAIL" _project_maintainer_email)
_read_cache_value("${_metadata_cache_path}" "PROJECT_LICENSE" _project_license)
file(STRINGS "${_metadata_cache_path}" _metadata_cxx_compiler REGEX "^CMAKE_CXX_COMPILER:")
if(_metadata_cxx_compiler)
  message(FATAL_ERROR "Metadata-only configure unexpectedly enabled the C++ language.")
endif()
if(EXISTS "${_metadata_probe}/src")
  message(FATAL_ERROR "Metadata-only configure unexpectedly entered the source target tree.")
endif()

string(REGEX REPLACE "[.]$" "" _project_description_base "${_project_description}")

foreach(_package_name
    template_project
    template_project_interfaces
    template_project_ros
    template_project_spinup)
  if(_package_name STREQUAL "template_project")
    set(_description_suffix "ROS 2 colcon shim package.")
  elseif(_package_name STREQUAL "template_project_interfaces")
    set(_description_suffix "ROS 2 message and service interfaces.")
  elseif(_package_name STREQUAL "template_project_ros")
    set(_description_suffix "ROS 2 bridge package.")
  else()
    set(_description_suffix "ROS 2 launch and runtime assets.")
  endif()

  set(_package_xml "${_root}/ros2/${_package_name}/package.xml")
  _read_required("${_package_xml}" _package_contents)
  string(REGEX MATCH "<name>([^<]+)</name>" _package_name_match "${_package_contents}")
  if(NOT CMAKE_MATCH_1 STREQUAL "${_package_name}")
    message(FATAL_ERROR "Recurring metadata sync changed package identity in ${_package_xml}.")
  endif()
  string(REGEX MATCH "<description>([^<]+)</description>" _description_match "${_package_contents}")
  set(_expected_description "${_project_description_base}: ${_description_suffix}")
  if(NOT CMAKE_MATCH_1 STREQUAL "${_expected_description}")
    message(FATAL_ERROR
        "Expected ${_package_xml} description '${_expected_description}', got '${CMAKE_MATCH_1}'.")
  endif()
  string(REGEX MATCH "<maintainer[ \\t]+email=\"([^\"]+)\">([^<]+)</maintainer>" _maintainer_match "${_package_contents}")
  if(NOT CMAKE_MATCH_1 STREQUAL "${_project_maintainer_email}"
      OR NOT CMAKE_MATCH_2 STREQUAL "${_project_maintainer_name}")
    message(FATAL_ERROR "Maintainer metadata does not match the root project in ${_package_xml}.")
  endif()
  string(REGEX MATCH "<license>([^<]+)</license>" _license_match "${_package_contents}")
  if(NOT CMAKE_MATCH_1 STREQUAL "${_project_license}")
    message(FATAL_ERROR "License metadata does not match the root project in ${_package_xml}.")
  endif()
  string(REGEX MATCH "<url[ \\t]+type=\"website\">([^<]+)</url>" _website_match "${_package_contents}")
  if(NOT CMAKE_MATCH_1 STREQUAL "${_project_homepage_url}")
    message(FATAL_ERROR "Website metadata does not match the root project in ${_package_xml}.")
  endif()
endforeach()

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
    "${_bash_executable}" "${_root}/add_ros2_support.sh" --list --root "${_fake_list}")
if(NOT _last_stdout MATCHES "Detected target project:[ ]+my_template_project_x")
  message(FATAL_ERROR "add_ros2_support.sh --list did not report the detected target project name.")
endif()
if(NOT _last_stdout MATCHES "ROS package prefix:[ ]+my_template_project_x")
  message(FATAL_ERROR "add_ros2_support.sh --list did not report the derived ROS package prefix.")
endif()
if(EXISTS "${_fake_list}/ros2")
  message(FATAL_ERROR "add_ros2_support.sh --list modified the target by creating ros2/.")
endif()

_run_failure(
    "Reject rollout verification without apply mode"
    "--verify requires --apply"
    "${_bash_executable}" "${_root}/add_ros2_support.sh" --verify --root "${_fake_list}")

_create_fake_target("${_fake_conflict}" "space_nav")
file(MAKE_DIRECTORY "${_fake_conflict}/ros2")
_run_failure(
    "Refuse target with existing ros2 overlay"
    "already has ros2"
    "${_bash_executable}" "${_root}/add_ros2_support.sh" --apply --yes --root "${_fake_conflict}")

_create_fake_target("${_fake_doc_conflict}" "space_nav")
file(WRITE "${_fake_doc_conflict}/doc/ros2_overlay.md" "target-owned documentation\n")
_run_failure(
    "Refuse target with existing ROS 2 overlay documentation"
    "doc/ros2_overlay.md"
    "${_bash_executable}" "${_root}/add_ros2_support.sh" --apply --yes --root "${_fake_doc_conflict}")
if(EXISTS "${_fake_doc_conflict}/ros2" OR EXISTS "${_fake_doc_conflict}/build_ros2.sh")
  message(FATAL_ERROR "Documentation collision left a partially copied ROS 2 overlay.")
endif()
_read_required("${_fake_doc_conflict}/doc/ros2_overlay.md" _target_doc_contents)
if(NOT _target_doc_contents STREQUAL "target-owned documentation\n")
  message(FATAL_ERROR "Documentation collision changed the target-owned file.")
endif()

_create_fake_target("${_fake_workflow_conflict}" "space_nav")
file(WRITE "${_fake_workflow_conflict}/.github/workflows/build_ros2_overlay.yml" "target-owned workflow\n")
_run_failure(
    "Refuse target with existing ROS 2 overlay workflow"
    "build_ros2_overlay.yml"
    "${_bash_executable}" "${_root}/add_ros2_support.sh" --apply --yes --root "${_fake_workflow_conflict}")
if(EXISTS "${_fake_workflow_conflict}/ros2" OR EXISTS "${_fake_workflow_conflict}/build_ros2.sh")
  message(FATAL_ERROR "Workflow collision left a partially copied ROS 2 overlay.")
endif()
_read_required("${_fake_workflow_conflict}/.github/workflows/build_ros2_overlay.yml" _target_workflow_contents)
if(NOT _target_workflow_contents STREQUAL "target-owned workflow\n")
  message(FATAL_ERROR "Workflow collision changed the target-owned file.")
endif()

_create_fake_target("${_fake_workflow_no_ci}" "space_nav")
file(WRITE "${_fake_workflow_no_ci}/.github/workflows/build_ros2_overlay.yml" "target-owned workflow\n")
_run_success(
    "Ignore existing workflow when rollout uses --no-ci"
    "${_bash_executable}" "${_root}/add_ros2_support.sh" --apply --yes --no-ci --root "${_fake_workflow_no_ci}")
if(NOT EXISTS "${_fake_workflow_no_ci}/ros2" OR NOT EXISTS "${_fake_workflow_no_ci}/build_ros2.sh")
  message(FATAL_ERROR "--no-ci rollout did not add the required ROS 2 overlay paths.")
endif()
_read_required("${_fake_workflow_no_ci}/.github/workflows/build_ros2_overlay.yml" _no_ci_workflow_contents)
if(NOT _no_ci_workflow_contents STREQUAL "target-owned workflow\n")
  message(FATAL_ERROR "--no-ci rollout changed the existing target workflow.")
endif()

_create_fake_target("${_fake_apply}" "space_nav")
_run_success(
    "Apply ROS 2 rollout to fake target"
    "${_bash_executable}" "${_root}/add_ros2_support.sh" --apply --yes --no-ci --root "${_fake_apply}")
if(NOT _last_stdout MATCHES "ros2/space_nav_ros/src/conversions\\.cpp")
  message(FATAL_ERROR "Post-apply checklist does not point at conversions.cpp as the primary seam.")
endif()
if(_last_stdout MATCHES "CTemplateLifecycleNode\\.cpp to a real")
  message(FATAL_ERROR "Post-apply checklist still names CTemplateLifecycleNode.cpp as the primary seam.")
endif()
if(NOT _last_stdout MATCHES "root CMake metadata contract"
    OR NOT _last_stdout MATCHES "PROJECT_METADATA_ONLY"
    OR NOT _last_stdout MATCHES "project metadata")
  message(FATAL_ERROR
      "Post-apply checklist does not require the root metadata contract before recurring sync.")
endif()
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
    message(FATAL_ERROR "Expected add_ros2_support.sh to create ${_expected_path}")
  endif()
endforeach()

_create_fake_target("${_fake_apply_ci}" "space_nav")
_run_success(
    "Apply ROS 2 rollout with generic CI workflow"
    "${_bash_executable}" "${_root}/add_ros2_support.sh"
    --apply --yes --root "${_fake_apply_ci}")
set(_copied_project_workflow
    "${_fake_apply_ci}/.github/workflows/build_ros2_overlay.yml")
if(NOT EXISTS "${_copied_project_workflow}")
  message(FATAL_ERROR "ROS rollout did not materialize the generic project workflow")
endif()
if(EXISTS "${_fake_apply_ci}/.github/workflows/build_ros2_overlay.yml.tpl")
  message(FATAL_ERROR "ROS rollout copied a dormant .tpl file into the target")
endif()
_read_required("${_copied_project_workflow}" _copied_project_workflow_contents)
foreach(_template_only_pattern
    "VerifyTemplateProject"
    "testRos2OverlayStatic"
    "tailor_template_cleanup"
    "CWrapperPlaceholder"
    "rollout-rehearsal")
  if(_copied_project_workflow_contents MATCHES "${_template_only_pattern}")
    message(FATAL_ERROR
        "Copied project workflow retained template-only pattern '${_template_only_pattern}'")
  endif()
endforeach()
foreach(_project_gate
    "rosdep install --from-paths ros2"
    "\\./build_ros2\\.sh --clean"
    "src/\\*\\*")
  if(NOT _copied_project_workflow_contents MATCHES "${_project_gate}")
    message(FATAL_ERROR "Copied project workflow is missing '${_project_gate}'")
  endif()
endforeach()
foreach(_forbidden_path
    "add_ros2_support.sh"
    "tests/cmake/VerifyTemplateProjectRos2Overlay.cmake"
    "ros2/build"
    "ros2/install"
    "ros2/log")
  if(EXISTS "${_fake_apply}/${_forbidden_path}")
    message(FATAL_ERROR "add_ros2_support.sh unexpectedly copied ${_forbidden_path}")
  endif()
endforeach()

_run_success(
    "Synchronize copied overlay metadata from fake target"
    "${CMAKE_COMMAND}" -E env "GIT_CEILING_DIRECTORIES=${TEST_BINARY_ROOT}"
    "${_bash_executable}" "${_fake_apply}/generate_version.sh" --sync-ros2)

file(GLOB_RECURSE _fake_apply_files LIST_DIRECTORIES false "${_fake_apply}/ros2/*")
foreach(_fake_file IN LISTS _fake_apply_files)
  file(READ "${_fake_file}" _fake_contents)
  if(_fake_contents MATCHES "template_project")
    message(FATAL_ERROR "Placeholder name remained in copied overlay file ${_fake_file}")
  endif()
endforeach()

_create_fake_target("${_fake_boundary}" "my_template_project_x")
_run_success(
    "Apply ROS 2 rollout to word-boundary fake target"
    "${_bash_executable}" "${_root}/add_ros2_support.sh" --apply --yes --no-ci --root "${_fake_boundary}")
if(NOT EXISTS "${_fake_boundary}/ros2/my_template_project_x/package.xml")
  message(FATAL_ERROR "Expected word-boundary project name to produce my_template_project_x package.")
endif()
if(EXISTS "${_fake_boundary}/ros2/my_my_template_project_x_x/package.xml")
  message(FATAL_ERROR "Project name was recursively or substring-renamed.")
endif()

set(_fake_cmake_name_split "${TEST_BINARY_ROOT}/fake_cmake_name_split")
_create_fake_target("${_fake_cmake_name_split}" "space-nav-frontend")
_run_success(
    "Apply ROS 2 rollout to fake target with non-ROS CMake package name"
    "${_bash_executable}" "${_root}/add_ros2_support.sh" --apply --yes --no-ci --root "${_fake_cmake_name_split}")
foreach(_expected_path
    "ros2/space_nav_frontend/package.xml"
    "ros2/space_nav_frontend_interfaces/package.xml"
    "ros2/space_nav_frontend_ros/package.xml"
    "ros2/space_nav_frontend_spinup/package.xml")
  if(NOT EXISTS "${_fake_cmake_name_split}/${_expected_path}")
    message(FATAL_ERROR "Expected non-ROS CMake name rollout to create ${_expected_path}")
  endif()
endforeach()
_read_required("${_fake_cmake_name_split}/ros2/space_nav_frontend_ros/CMakeLists.txt" _split_bridge_cmake)
if(NOT _split_bridge_cmake MATCHES "find_package\\(space-nav-frontend REQUIRED\\)")
  message(FATAL_ERROR "Bridge CMake did not preserve the original core CMake package name.")
endif()
if(NOT _split_bridge_cmake MATCHES "space-nav-frontend::space-nav-frontend")
  message(FATAL_ERROR "Bridge CMake did not preserve the original core CMake target namespace.")
endif()
_read_required("${_fake_cmake_name_split}/ros2/space_nav_frontend_ros/package.xml" _split_bridge_package)
if(NOT _split_bridge_package MATCHES "<depend>space_nav_frontend</depend>")
  message(FATAL_ERROR "Bridge package.xml does not depend on the ROS-valid shim package name.")
endif()
if(_split_bridge_package MATCHES "<depend>space-nav-frontend</depend>")
  message(FATAL_ERROR "Bridge package.xml used the non-ROS CMake name as a ROS package dependency.")
endif()

set(_fake_ros_prefix_override "${TEST_BINARY_ROOT}/fake_ros_prefix_override")
_create_fake_target("${_fake_ros_prefix_override}" "space-nav-frontend")
_run_success(
    "Apply ROS 2 rollout with explicit ROS package prefix"
    "${_bash_executable}" "${_root}/add_ros2_support.sh" --apply --yes --no-ci --root "${_fake_ros_prefix_override}" --ros-prefix snf)
if(NOT EXISTS "${_fake_ros_prefix_override}/ros2/snf_ros/package.xml")
  message(FATAL_ERROR "Expected --ros-prefix to control copied ROS package names.")
endif()

set(_fake_invalid_ros_prefix "${TEST_BINARY_ROOT}/fake_invalid_ros_prefix")
_create_fake_target("${_fake_invalid_ros_prefix}" "space-nav-frontend")
_run_failure(
    "Reject invalid explicit ROS package prefix"
    "Invalid ROS package prefix"
    "${_bash_executable}" "${_root}/add_ros2_support.sh" --list --root "${_fake_invalid_ros_prefix}" --ros-prefix bad-name)

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
file(WRITE
    "${_fake_rollout_source}/ros2/template_project/generated.pyc"
    "generated bytecode\n")
file(WRITE
    "${_fake_rollout_source}/ros2/template_project/nottemplate_projectile.txt"
    "boundary fixture\n")

_create_fake_target("${_fake_filtered_rollout}" "space_nav")
_run_success(
    "Apply filtered ROS 2 rollout from synthetic source"
    "${_bash_executable}" "${_fake_rollout_source}/add_ros2_support.sh"
    --apply --yes --no-ci --root "${_fake_filtered_rollout}")
if(EXISTS "${_fake_filtered_rollout}/ros2/space_nav/__pycache__"
    OR EXISTS "${_fake_filtered_rollout}/ros2/space_nav/generated.pyc")
  message(FATAL_ERROR "Rollout copied generated Python cache artifacts.")
endif()
if(NOT EXISTS "${_fake_filtered_rollout}/ros2/space_nav/nottemplate_projectile.txt")
  message(FATAL_ERROR "Rollout renamed template_project inside an unrelated path substring.")
endif()

set(_workflow "${_root}/.github/workflows/build_ros2_overlay.yml")
_assert_matches("${_workflow}" "workflow_dispatch")
_assert_matches("${_workflow}" "schedule:")
_assert_matches("${_workflow}" "cron:[ ]*\"17 3 \\* \\* 2\"")
_assert_matches("${_workflow}" "push:")
_assert_matches("${_workflow}" "tags:[ ]*\n[ ]*- \"v\\*\\.\\*\\.\\*\"")
_assert_matches("${_workflow}" "pull_request:")
_assert_matches("${_workflow}" "ros2/\\*\\*")
_assert_matches("${_workflow}" "build_ros2\\.sh")
_assert_matches("${_workflow}" "add_ros2_support\\.sh")
_assert_matches("${_workflow}" "generate_version\\.sh")
_assert_matches("${_workflow}" "CMakeLists\\.txt")
_assert_matches("${_workflow}" "tailor_template_cleanup\\.sh")
_assert_matches("${_workflow}" "doc/ros2_overlay\\.md")
_assert_matches("${_workflow}" "doc/template_usage\\.md")
_assert_matches("${_workflow}" "doc/bootstrap_prompts\\.md")
_assert_matches("${_workflow}" "tests/cmake/VerifyTemplateProjectRos2Overlay\\.cmake")
_assert_matches("${_workflow}" "tests/cmake/VerifyTemplateProjectNestedInstallHeaders\\.cmake")
_assert_matches("${_workflow}" "tests/cmake/VerifyTemplateProjectCudaSources\\.cmake")
_assert_matches("${_workflow}" "tests/template_test/testRos2OverlayStatic\\.py")
_assert_matches("${_workflow}" "tests/template_test/testWorkflowTemplates\\.py")
_assert_matches("${_workflow}" "\\.github/workflows/build_ros2_overlay\\.yml")
_assert_matches("${_workflow}" "\\.github/workflows/build_ros2_overlay\\.yml\\.tpl")
_assert_matches("${_workflow}" "src/\\*\\*")
_assert_matches("${_workflow}" "cmake/\\*\\*")
_assert_matches("${_workflow}" "overlay-build:")
_assert_matches("${_workflow}" "rollout-rehearsal:")
_assert_matches("${_workflow}" "ubuntu-24\\.04")
_assert_matches("${_workflow}" "ros:jazzy")
_assert_matches("${_workflow}" "build-essential")
_assert_matches("${_workflow}" "cmake")
_assert_matches("${_workflow}" "libeigen3-dev")
_assert_matches("${_workflow}" "python3-colcon-common-extensions")
_assert_matches("${_workflow}" "python3-pytest")
_assert_matches("${_workflow}" "ros-dev-tools")
_assert_matches("${_workflow}" "rosdep install --from-paths ros2 -i -r -y --rosdistro jazzy")
_assert_matches("${_workflow}" "Synchronize ROS package metadata")
_assert_matches("${_workflow}" "grep -q -- \"--sync-ros2\"")
_assert_matches("${_workflow}" "grep -q -- \"ROS2_PROJECT_METADATA_SYNC=1\"")
_assert_matches("${_workflow}" "\\./generate_version\\.sh --sync-ros2")
_assert_matches("${_workflow}" "git diff --exit-code -- ros2/\\*/package\\.xml")
_assert_not_matches("${_workflow}" "Skipping ROS package metadata sync")
_assert_matches("${_workflow}" "\\./build_ros2\\.sh --clean")
_assert_matches("${_workflow}" "name: Verify installed core header layout")
_assert_matches("${_workflow}" "core_cmake_name_=")
_assert_matches("${_workflow}" "_ros2_overlay_nested_version_file")
_assert_matches(
    "${_workflow}"
    "include/\\$\\{core_cmake_name_\\}/wrapped_impl/CWrapperPlaceholder\\.h")
_assert_matches(
    "${_workflow}"
    "test ! -e[^\n]*wrapped_impl/CWrapperPlaceholder\\.h")
_assert_matches("${_workflow}" "tests/template_test/testRos2OverlayStatic\\.py")
_assert_matches("${_workflow}" "tests/template_test/testWorkflowTemplates\\.py")
_assert_not_matches("${_workflow}" "Skipping template-only pytest checks")
_assert_matches("${_workflow}" "expected_version")
_assert_matches("${_workflow}" "Project version core")
_assert_matches("${_workflow}" "strict X\\.Y\\.Z")
_assert_not_matches("${_workflow}" "ET\\.parse\\(\"ros2/template_project/package\\.xml\"\\)")
_assert_matches("${_workflow}" "-DEXPECTED_VERSION")
_assert_matches("${_workflow}" "-P tests/cmake/VerifyTemplateProjectRos2Overlay\\.cmake")
_assert_not_matches("${_workflow}" "Skipping template-only CMake checks")
_assert_matches("${_workflow}" "tailor_template_cleanup\\.sh --apply --yes --remove-ros2")
_assert_matches("${_workflow}" "name: Rehearse default-tailored overlay")
_assert_matches("${_workflow}" "add_ros2_support\\.sh --root")
_assert_matches("${_workflow}" "cmake -S \\. -B build_plain -DENABLE_TESTS=OFF")
_assert_not_matches("${_workflow}" "build_ros2\\.sh[^\\n]*--cuda")

_read_required("${_workflow}" _workflow_contents)
foreach(_owned_trigger_pattern
    "README\\.md"
    "AGENTS\\.md"
    "CLAUDE\\.md"
    "- CMakeLists\\.txt"
    "- cmake/\\*\\*"
    "- src/\\*\\*"
    "python/COLCON_IGNORE"
    "lib/COLCON_IGNORE"
    "examples/COLCON_IGNORE"
    "tests/COLCON_IGNORE"
    "tests/cmake/VerifyTemplateProjectNestedInstallHeaders\\.cmake"
    "tests/cmake/VerifyTemplateProjectCudaSources\\.cmake")
  string(REGEX MATCHALL "${_owned_trigger_pattern}" _owned_trigger_paths "${_workflow_contents}")
  list(LENGTH _owned_trigger_paths _owned_trigger_count)
  if(NOT _owned_trigger_count EQUAL 2)
    message(FATAL_ERROR
        "${_owned_trigger_pattern} must appear in both ROS 2 overlay workflow path filters; "
        "found ${_owned_trigger_count} occurrences.")
  endif()
endforeach()
string(REGEX MATCHALL "\n  schedule:" _workflow_schedules "${_workflow_contents}")
list(LENGTH _workflow_schedules _workflow_schedule_count)
string(REGEX MATCHALL
    "cron:[ ]*\"17 3 \\* \\* 2\""
    _workflow_weekly_crons
    "${_workflow_contents}")
list(LENGTH _workflow_weekly_crons _workflow_weekly_cron_count)
if(NOT _workflow_schedule_count EQUAL 1 OR NOT _workflow_weekly_cron_count EQUAL 1)
  message(FATAL_ERROR
      "ROS 2 overlay workflow must define exactly one Tuesday 03:17 UTC schedule; "
      "found ${_workflow_schedule_count} schedule blocks and "
      "${_workflow_weekly_cron_count} matching cron entries.")
endif()
string(REGEX MATCHALL "- generate_version\\.sh" _version_trigger_paths "${_workflow_contents}")
list(LENGTH _version_trigger_paths _version_trigger_count)
if(NOT _version_trigger_count EQUAL 2)
  message(FATAL_ERROR
      "generate_version.sh must appear in both ROS 2 overlay workflow path filters; "
      "found ${_version_trigger_count} occurrences.")
endif()
string(REGEX MATCHALL "\\./generate_version\\.sh --sync-ros2" _workflow_metadata_syncs "${_workflow_contents}")
list(LENGTH _workflow_metadata_syncs _workflow_metadata_sync_count)
if(NOT _workflow_metadata_sync_count EQUAL 2)
  message(FATAL_ERROR
      "Both ROS 2 workflow jobs must synchronize project metadata before rosdep; "
      "found ${_workflow_metadata_sync_count} invocations.")
endif()
string(REGEX MATCHALL
    "git config --global --add safe\\.directory \"\\$\\{GITHUB_WORKSPACE\\}\""
    _workflow_workspace_trusts
    "${_workflow_contents}")
list(LENGTH _workflow_workspace_trusts _workflow_workspace_trust_count)
string(REGEX MATCHALL
    "git -C \"\\$\\{GITHUB_WORKSPACE\\}\" rev-parse --is-inside-work-tree"
    _workflow_worktree_probes
    "${_workflow_contents}")
list(LENGTH _workflow_worktree_probes _workflow_worktree_probe_count)
if(NOT _workflow_workspace_trust_count EQUAL 2
    OR NOT _workflow_worktree_probe_count EQUAL 2)
  message(FATAL_ERROR
      "Both ROS 2 workflow jobs must trust and validate the exact mounted Git workspace; "
      "found ${_workflow_workspace_trust_count} trust commands and "
      "${_workflow_worktree_probe_count} worktree probes.")
endif()
if(_workflow_contents MATCHES "safe\\.directory[^\n]*[\"']?\\*")
  message(FATAL_ERROR "ROS 2 workflow must not trust every Git repository with safe.directory '*'.")
endif()
string(REGEX MATCHALL
    "git diff --exit-code -- ros2/\\*/package\\.xml"
    _workflow_manifest_drift_guards
    "${_workflow_contents}")
list(LENGTH _workflow_manifest_drift_guards _workflow_manifest_drift_guard_count)
if(NOT _workflow_manifest_drift_guard_count EQUAL 2)
  message(FATAL_ERROR
      "Both ROS 2 workflow metadata syncs must reject tracked manifest drift; "
      "found ${_workflow_manifest_drift_guard_count} guards.")
endif()
string(REGEX MATCHALL "grep -q -- \"--sync-ros2\"" _workflow_metadata_guards "${_workflow_contents}")
list(LENGTH _workflow_metadata_guards _workflow_metadata_guard_count)
if(NOT _workflow_metadata_guard_count EQUAL 2)
  message(FATAL_ERROR
      "Both ROS 2 workflow metadata syncs must tolerate older generated helpers; "
      "found ${_workflow_metadata_guard_count} guards.")
endif()
string(REGEX MATCHALL "grep -q -- \"ROS2_PROJECT_METADATA_SYNC=1\"" _workflow_capability_guards "${_workflow_contents}")
list(LENGTH _workflow_capability_guards _workflow_capability_guard_count)
if(NOT _workflow_capability_guard_count EQUAL 2)
  message(FATAL_ERROR
      "Both ROS 2 workflow metadata syncs must reject the older version-only helper; "
      "found ${_workflow_capability_guard_count} capability guards.")
endif()
string(REGEX MATCHALL "uses: actions/checkout@v[0-9]+" _checkout_uses "${_workflow_contents}")
list(LENGTH _checkout_uses _checkout_count)
string(REGEX MATCHALL "fetch-depth:[ ]*0" _fetch_depth_settings "${_workflow_contents}")
list(LENGTH _fetch_depth_settings _fetch_depth_count)
if(NOT _checkout_count EQUAL 2 OR NOT _fetch_depth_count EQUAL _checkout_count)
  message(FATAL_ERROR
      "ROS 2 overlay workflow must use fetch-depth: 0 in both checkout steps. "
      "Found ${_checkout_count} checkout steps and ${_fetch_depth_count} full-depth settings.")
endif()

_assert_not_matches("${_workflow}" "id: rollout-tooling")
_assert_not_matches("${_workflow}" "steps\\.rollout-tooling")
_assert_not_matches("${_workflow}" "Skipping template-only rollout validation")

set(_workflow_template
    "${_root}/.github/workflows/build_ros2_overlay.yml.tpl")
_assert_matches("${_workflow_template}" "# project-ci-template: generic")
_assert_matches("${_workflow_template}" "workflow_dispatch")
_assert_matches("${_workflow_template}" "schedule:")
_assert_matches("${_workflow_template}" "cron:[ ]*\"17 3 \\* \\* 2\"")
_assert_matches("${_workflow_template}" "push:")
_assert_matches("${_workflow_template}" "tags:[ ]*\n[ ]*- \"v\\*\\.\\*\\.\\*\"")
_assert_matches("${_workflow_template}" "pull_request:")
_assert_matches("${_workflow_template}" "CMakeLists\\.txt")
_assert_matches("${_workflow_template}" "cmake/\\*\\*")
_assert_matches("${_workflow_template}" "src/\\*\\*")
_assert_matches("${_workflow_template}" "lib/\\*\\*")
_assert_matches("${_workflow_template}" "ros2/\\*\\*")
_assert_matches("${_workflow_template}" "build_ros2\\.sh")
_assert_matches("${_workflow_template}" "generate_version\\.sh")
_assert_matches("${_workflow_template}" "overlay-build:")
_assert_matches("${_workflow_template}" "rosdep install --from-paths ros2 -i -r -y --rosdistro jazzy")
_assert_matches("${_workflow_template}" "git diff --exit-code -- ros2/\\*/package\\.xml")
_assert_matches("${_workflow_template}" "::warning::")
_assert_matches("${_workflow_template}" "\\./build_ros2\\.sh --clean")
foreach(_template_only_pattern
    "Verify installed core header layout"
    "VerifyTemplateProject"
    "testRos2OverlayStatic"
    "testWorkflowTemplates"
    "tailor_template_cleanup"
    "add_ros2_support"
    "CWrapperPlaceholder"
    "rollout-rehearsal")
  _assert_not_matches("${_workflow_template}" "${_template_only_pattern}")
endforeach()

_read_required("${_workflow_template}" _workflow_template_contents)
string(REGEX MATCHALL
    "\n  schedule:"
    _project_workflow_schedules
    "${_workflow_template_contents}")
list(LENGTH _project_workflow_schedules _project_workflow_schedule_count)
string(REGEX MATCHALL
    "cron:[ ]*\"17 3 \\* \\* 2\""
    _project_workflow_weekly_crons
    "${_workflow_template_contents}")
list(LENGTH _project_workflow_weekly_crons _project_workflow_weekly_cron_count)
if(NOT _project_workflow_schedule_count EQUAL 1
    OR NOT _project_workflow_weekly_cron_count EQUAL 1)
  message(FATAL_ERROR
      "Generic ROS workflow must define exactly one Tuesday 03:17 UTC schedule; "
      "found ${_project_workflow_schedule_count} schedule blocks and "
      "${_project_workflow_weekly_cron_count} matching cron entries.")
endif()
string(REGEX MATCHALL
    "\\./generate_version\\.sh --sync-ros2"
    _project_workflow_metadata_syncs
    "${_workflow_template_contents}")
list(LENGTH _project_workflow_metadata_syncs _project_workflow_metadata_sync_count)
if(NOT _project_workflow_metadata_sync_count EQUAL 1)
  message(FATAL_ERROR
      "Generic ROS workflow must synchronize metadata exactly once; "
      "found ${_project_workflow_metadata_sync_count} invocations.")
endif()
string(REGEX MATCHALL
    "git config --global --add safe\\.directory \"\\$\\{GITHUB_WORKSPACE\\}\""
    _project_workflow_workspace_trusts
    "${_workflow_template_contents}")
list(LENGTH
    _project_workflow_workspace_trusts
    _project_workflow_workspace_trust_count)
string(REGEX MATCHALL
    "git -C \"\\$\\{GITHUB_WORKSPACE\\}\" rev-parse --is-inside-work-tree"
    _project_workflow_worktree_probes
    "${_workflow_template_contents}")
list(LENGTH
    _project_workflow_worktree_probes
    _project_workflow_worktree_probe_count)
if(NOT _project_workflow_workspace_trust_count EQUAL 1
    OR NOT _project_workflow_worktree_probe_count EQUAL 1)
  message(FATAL_ERROR
      "Generic ROS workflow must trust and validate the exact mounted Git workspace once; "
      "found ${_project_workflow_workspace_trust_count} trust commands and "
      "${_project_workflow_worktree_probe_count} worktree probes.")
endif()
if(_workflow_template_contents MATCHES "safe\\.directory[^\n]*[\"']?\\*")
  message(FATAL_ERROR "Generic ROS workflow must not trust every Git repository with safe.directory '*'.")
endif()
string(REGEX MATCHALL
    "git diff --exit-code -- ros2/\\*/package\\.xml"
    _project_workflow_manifest_drift_guards
    "${_workflow_template_contents}")
list(LENGTH
    _project_workflow_manifest_drift_guards
    _project_workflow_manifest_drift_guard_count)
if(NOT _project_workflow_manifest_drift_guard_count EQUAL 1)
  message(FATAL_ERROR
      "Generic ROS workflow must reject tracked manifest drift after supported sync; "
      "found ${_project_workflow_manifest_drift_guard_count} guards.")
endif()
string(REGEX MATCHALL
    "uses: actions/checkout@v[0-9]+"
    _project_workflow_checkouts
    "${_workflow_template_contents}")
list(LENGTH _project_workflow_checkouts _project_workflow_checkout_count)
string(REGEX MATCHALL
    "fetch-depth:[ ]*0"
    _project_workflow_fetch_depths
    "${_workflow_template_contents}")
list(LENGTH _project_workflow_fetch_depths _project_workflow_fetch_depth_count)
if(NOT _project_workflow_checkout_count EQUAL 1
    OR NOT _project_workflow_fetch_depth_count EQUAL 1)
  message(FATAL_ERROR
      "Generic ROS workflow must have one full-depth checkout; found "
      "${_project_workflow_checkout_count} checkouts and "
      "${_project_workflow_fetch_depth_count} full-depth settings.")
endif()

set(_ros2_doc "${_root}/doc/ros2_overlay.md")
_assert_matches("${_ros2_doc}" "CUDA")
_assert_matches("${_ros2_doc}" "\\./build_ros2\\.sh --cuda")
_assert_matches("${_ros2_doc}" "CI")
_assert_matches("${_ros2_doc}" "Encapsulation contract")
_assert_matches("${_ros2_doc}" "add_subdirectory")
_assert_matches("${_ros2_doc}" "template_project::template_project")
_assert_matches("${_ros2_doc}" "conversions-vs-node")
_assert_matches("${_ros2_doc}" "source-adjacent")
_assert_matches("${_ros2_doc}" "build_ros2\\.sh")
_assert_matches("${_ros2_doc}" "-DTEMPLATE_PROJECT_ENABLE_CUDA=ON")
_assert_matches("${_ros2_doc}" "ENABLE_CUDA")
_assert_matches("${_ros2_doc}" "ENABLE_FETCH_SPDLOG=OFF")
_assert_matches("${_ros2_doc}" "Last local GPU validation")
_assert_matches("${_ros2_doc}" "2026-07-17")
_assert_matches("${_ros2_doc}" "CUDA 12\\.9\\.41")
_assert_matches("${_ros2_doc}" "OptiX 8\\.0\\.0")
_assert_matches("${_ros2_doc}" "OPTIX_HOME")
_assert_matches("${_ros2_doc}" "RTX 5090")
_assert_matches("${_ros2_doc}" "sm_120")
_assert_matches("${_ros2_doc}" "CPU-only")
_assert_not_matches("${_ros2_doc}" "/home/|/Users/")
_assert_matches("${_ros2_doc}" "COLCON_IGNORE")
_assert_matches("${_ros2_doc}" "parent workspace")
_assert_matches("${_ros2_doc}" "--sync-ros2")
_assert_matches("${_ros2_doc}" "Project metadata sync")
_assert_matches("${_ros2_doc}" "PROJECT_METADATA_ONLY")
_assert_matches("${_ros2_doc}" "CMAKE_PROJECT_DESCRIPTION")
_assert_matches("${_ros2_doc}" "preserves the established")
_assert_matches("${_ros2_doc}" "ROS package names")
_assert_matches("${_ros2_doc}" "--no-version-sync")
_assert_matches("${_ros2_doc}" "add_ros2_support\\.sh")
_assert_matches("${_ros2_doc}" "EDIT-ME core-call")
_assert_matches("${_ros2_doc}" "conversions\\.cpp")
_assert_matches("${_ros2_doc}" "ros2/<ros_prefix>_ros/src/conversions\\.cpp")
_assert_not_matches("${_ros2_doc}" "ros2/<project_name>_ros/src/conversions\\.cpp")
_assert_matches("${_ros2_doc}" "ROS package prefix")
_assert_matches("${_ros2_doc}" "CMake package name")
_assert_matches("${_ros2_doc}" "manual tailoring")
_assert_matches("${_ros2_doc}" "rename-then-overlay")
_assert_matches("${_ros2_doc}" "overlay-then-rename")
_assert_matches("${_ros2_doc}" "--remove-ros2")
_assert_matches("${_ros2_doc}" "ROS_DISTRO")
_assert_matches("${_ros2_doc}" "ros:jazzy")
_assert_matches("${_ros2_doc}" "`python/` bindings remain a separate ROS-free optional feature")
_assert_not_matches("${_ros2_doc}" "`python/ bindings remain a separate ROS-free optional feature`")

foreach(_fenced_doc
    "README.md"
    "AGENTS.md"
    "CLAUDE.md"
    "doc/bootstrap_prompts.md"
    "doc/template_usage.md"
    "doc/versioning.md")
  _assert_ros2_fence("${_fenced_doc}")
endforeach()

foreach(_entrypoint_doc
    "README.md"
    "AGENTS.md"
    "CLAUDE.md")
  _assert_matches("${_root}/${_entrypoint_doc}" "doc/ros2_overlay\\.md")
  _assert_matches("${_root}/${_entrypoint_doc}" "build_lib\\.sh")
  _assert_matches("${_root}/${_entrypoint_doc}" "build_ros2\\.sh")
  _assert_matches("${_root}/${_entrypoint_doc}" "never needs ROS")
endforeach()

foreach(_rollout_doc
    "doc/bootstrap_prompts.md"
    "doc/template_usage.md"
    "doc/ros2_overlay.md")
  _assert_matches("${_root}/${_rollout_doc}" "conversions\\.cpp")
  _assert_not_matches("${_root}/${_rollout_doc}" "CTemplateLifecycleNode\\.cpp[^\\n]*call the real library API")
  _assert_not_matches("${_root}/${_rollout_doc}" "CTemplateLifecycleNode\\.cpp[^\\n]*real API call")
endforeach()

set(_bootstrap_prompts "${_root}/doc/bootstrap_prompts.md")
_assert_matches("${_bootstrap_prompts}" "ROS 2 Overlay Rollout Prompt")
_assert_matches("${_bootstrap_prompts}" "keep/remove")
_assert_matches("${_bootstrap_prompts}" "script")
_assert_matches("${_bootstrap_prompts}" "manual")
_assert_matches("${_bootstrap_prompts}" "node/topic names")
_assert_matches("${_bootstrap_prompts}" "distro")
_assert_matches("${_bootstrap_prompts}" "ros2/<ros_prefix>_ros/src/conversions\\.cpp")

set(_template_usage "${_root}/doc/template_usage.md")
_assert_matches("${_template_usage}" "template_project_ros")
_assert_matches("${_template_usage}" "template_project_interfaces")
_assert_matches("${_template_usage}" "template_project_spinup")
_assert_matches("${_template_usage}" "ros2/template_project")
_assert_matches("${_template_usage}" "--remove-ros2")
_assert_matches("${_template_usage}" "ros2/<ros_prefix>_ros/src/conversions\\.cpp")
_assert_matches("${_template_usage}" "project_description")
_assert_matches("${_template_usage}" "project_homepage_url")
_assert_matches("${_template_usage}" "PROJECT_MAINTAINER_NAME")
_assert_matches("${_template_usage}" "PROJECT_MAINTAINER_EMAIL")
_assert_matches("${_template_usage}" "PROJECT_LICENSE")
_assert_matches("${_template_usage}" "one-time package identity")
_assert_matches("${_template_usage}" "recurring project metadata")
