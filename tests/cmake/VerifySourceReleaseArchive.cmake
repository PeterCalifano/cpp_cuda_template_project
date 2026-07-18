cmake_minimum_required(VERSION 3.15)

foreach(required_var TEST_SOURCE_ROOT TEST_BINARY_ROOT EXPECTED_VERSION EXPECTED_FULL_VERSION)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

if(NOT IS_DIRECTORY "${TEST_SOURCE_ROOT}")
  message(FATAL_ERROR "Extracted source root does not exist: ${TEST_SOURCE_ROOT}")
endif()
if(EXISTS "${TEST_SOURCE_ROOT}/.git")
  message(FATAL_ERROR "Canonical source archive must not contain .git")
endif()

foreach(required_path
    "VERSION"
    "LICENSE"
    "CMakeLists.txt"
    "generate_version.sh"
    "src/template_src/placeholder.cpp"
    "ros2/tools/sync_package_metadata.py"
    "ros2/template_project/package.xml"
    "ros2/template_project_interfaces/package.xml"
    "ros2/template_project_ros/package.xml"
    "ros2/template_project_spinup/package.xml")
  if(NOT EXISTS "${TEST_SOURCE_ROOT}/${required_path}")
    message(FATAL_ERROR "Canonical source archive is missing required ${required_path}")
  endif()
endforeach()

file(GLOB _root_build_entries LIST_DIRECTORIES TRUE "${TEST_SOURCE_ROOT}/build*")
foreach(_root_build_entry IN LISTS _root_build_entries)
  if(IS_DIRECTORY "${_root_build_entry}")
    message(FATAL_ERROR "Canonical source archive contains build tree: ${_root_build_entry}")
  endif()
endforeach()
foreach(generated_path "ros2/build" "ros2/install" "ros2/log")
  if(EXISTS "${TEST_SOURCE_ROOT}/${generated_path}")
    message(FATAL_ERROR "Canonical source archive contains generated ROS output: ${generated_path}")
  endif()
endforeach()

find_program(_python_executable NAMES python3 REQUIRED)

file(READ "${TEST_SOURCE_ROOT}/VERSION" _version_contents)
if(NOT _version_contents MATCHES "Project version core: ([0-9]+\\.[0-9]+\\.[0-9]+)")
  message(FATAL_ERROR "Canonical source VERSION has no strict core version")
endif()
set(_archive_core_version "${CMAKE_MATCH_1}")
if(NOT _archive_core_version STREQUAL EXPECTED_VERSION)
  message(FATAL_ERROR
      "Canonical source core version mismatch: expected ${EXPECTED_VERSION}, got ${_archive_core_version}")
endif()
if(NOT _version_contents MATCHES "Full version: ([^\n]+)")
  message(FATAL_ERROR "Canonical source VERSION has no full version")
endif()
set(_archive_full_version "${CMAKE_MATCH_1}")
if(NOT _archive_full_version STREQUAL EXPECTED_FULL_VERSION)
  message(FATAL_ERROR
      "Canonical source full version mismatch: expected ${EXPECTED_FULL_VERSION}, got ${_archive_full_version}")
endif()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
execute_process(
    COMMAND "${CMAKE_COMMAND}"
        -S "${TEST_SOURCE_ROOT}"
        -B "${TEST_BINARY_ROOT}/metadata"
        -DPROJECT_METADATA_ONLY=ON
    RESULT_VARIABLE _metadata_result
    OUTPUT_VARIABLE _metadata_stdout
    ERROR_VARIABLE _metadata_stderr)
if(NOT _metadata_result EQUAL 0)
  message(FATAL_ERROR
      "No-Git metadata-only configure failed with exit code ${_metadata_result}.\n"
      "stdout:\n${_metadata_stdout}\n"
      "stderr:\n${_metadata_stderr}")
endif()
file(READ "${TEST_BINARY_ROOT}/metadata/CMakeCache.txt" _metadata_cache)
if(NOT _metadata_cache MATCHES "CMAKE_PROJECT_VERSION:STATIC=${EXPECTED_VERSION}([\n\r]|$)")
  message(FATAL_ERROR "No-Git configure did not resolve expected version ${EXPECTED_VERSION}")
endif()
if(_metadata_cache MATCHES "CMAKE_CXX_COMPILER:")
  message(FATAL_ERROR "Metadata-only archive verification unexpectedly configured a C++ compiler")
endif()

file(GLOB _manifest_paths "${TEST_SOURCE_ROOT}/ros2/*/package.xml")
list(LENGTH _manifest_paths _manifest_count)
if(NOT _manifest_count EQUAL 4)
  message(FATAL_ERROR "Canonical source archive must contain four ROS manifests; found ${_manifest_count}")
endif()
foreach(_manifest_path IN LISTS _manifest_paths)
  execute_process(
      COMMAND "${_python_executable}" -c
          "import sys, xml.etree.ElementTree as ET; version=ET.parse(sys.argv[1]).getroot().findtext('version'); assert version == sys.argv[2], (sys.argv[1], version, sys.argv[2])"
          "${_manifest_path}" "${EXPECTED_VERSION}"
      RESULT_VARIABLE _manifest_parse_result
      ERROR_VARIABLE _manifest_parse_stderr)
  if(NOT _manifest_parse_result EQUAL 0)
    message(FATAL_ERROR
        "Archive manifest version validation failed: ${_manifest_path}\n"
        "${_manifest_parse_stderr}")
  endif()
  file(READ "${_manifest_path}" _manifest_contents)
  # The processing instruction is generated representation intentionally
  # preserved byte-for-byte by the metadata synchronizer.
  string(FIND "${_manifest_contents}" "<?xml-model " _xml_model_index)
  if(_xml_model_index LESS 0)
    message(FATAL_ERROR "Archive manifest lost its XML model processing instruction: ${_manifest_path}")
  endif()
endforeach()

if(DEFINED TEST_ROS_STATIC_VERIFIER AND NOT "${TEST_ROS_STATIC_VERIFIER}" STREQUAL "")
  execute_process(
      COMMAND "${CMAKE_COMMAND}"
          -DTEST_TEMPLATE_SOURCE_DIR=${TEST_SOURCE_ROOT}
          -DTEST_BINARY_ROOT=${TEST_BINARY_ROOT}/ros_static
          -DEXPECTED_VERSION=${EXPECTED_VERSION}
          -P "${TEST_ROS_STATIC_VERIFIER}"
      RESULT_VARIABLE _ros_static_result
      OUTPUT_VARIABLE _ros_static_stdout
      ERROR_VARIABLE _ros_static_stderr)
  if(NOT _ros_static_result EQUAL 0)
    message(FATAL_ERROR
        "Extracted ROS static verification failed with exit code ${_ros_static_result}.\n"
        "stdout:\n${_ros_static_stdout}\n"
        "stderr:\n${_ros_static_stderr}")
  endif()
endif()
