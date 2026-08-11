cmake_minimum_required(VERSION 3.15)

# Exercise every build-helper deletion path inside a disposable miniature
# checkout; this verifier must never clean the template's own build tree.
foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

set(_source_build_script "${TEST_TEMPLATE_SOURCE_DIR}/build_lib.sh")
if(NOT EXISTS "${_source_build_script}")
  message(FATAL_ERROR "Build helper not found: ${_source_build_script}")
endif()

function(_run_process step_name)
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

function(_expect_clean_rejection case_name build_dir expected_message)
  execute_process(
      COMMAND
        bash "${_fixture_build_script}"
        -B "${build_dir}"
        --clean
        --skip-tests
      WORKING_DIRECTORY "${_fixture_source}"
      RESULT_VARIABLE _result
      OUTPUT_VARIABLE _stdout
      ERROR_VARIABLE _stderr)

  if(_result EQUAL 0)
    message(FATAL_ERROR
        "Unsafe clean case '${case_name}' unexpectedly succeeded.")
  endif()

  set(_combined_output "${_stdout}\n${_stderr}")
  string(FIND "${_combined_output}" "${expected_message}" _message_index)
  if(_message_index EQUAL -1)
    message(FATAL_ERROR
        "Unsafe clean case '${case_name}' did not report the expected error.\n"
        "stdout:\n${_stdout}\n"
        "stderr:\n${_stderr}")
  endif()
endfunction()

# Isolate every destructive case inside a disposable miniature checkout so an
# externally configured template build exercises the same safety paths as an
# in-repository build.
file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
set(_fixture_source "${TEST_BINARY_ROOT}/fixture_source")
set(_foreign_source "${TEST_BINARY_ROOT}/foreign_source")
set(_outside_build "${TEST_BINARY_ROOT}/outside_build")
set(_external_rebuild "${TEST_BINARY_ROOT}/external_rebuild")
file(MAKE_DIRECTORY
    "${_fixture_source}/src"
    "${_fixture_source}/build_without_cache"
    "${_fixture_source}/build_missing_marker"
    "${_foreign_source}"
    "${_outside_build}")

configure_file(
    "${_source_build_script}"
    "${_fixture_source}/build_lib.sh"
    COPYONLY)
set(_fixture_build_script "${_fixture_source}/build_lib.sh")
file(WRITE "${_fixture_source}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(clean_safety_fixture LANGUAGES NONE)
")
file(WRITE "${_foreign_source}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(foreign_clean_fixture LANGUAGES NONE)
")
file(WRITE
    "${_fixture_source}/build_missing_marker/CMakeCache.txt"
    "UNRELATED_CACHE_ENTRY:INTERNAL=value\n")

# Reject every path or cache that cannot prove it is a conventional build
# owned by the disposable checkout.
_expect_clean_rejection(
    outside_repository
    "${_outside_build}"
    "--clean requires a build directory inside")
_expect_clean_rejection(
    source_subdirectory
    "${_fixture_source}/src"
    "--clean requires a conventional build path")
_expect_clean_rejection(
    build_directory_without_cache
    "${_fixture_source}/build_without_cache"
    "Refusing to clean a directory without a CMake cache")
_expect_clean_rejection(
    cache_without_source_marker
    "${_fixture_source}/build_missing_marker"
    "CMake source marker is missing")

set(_foreign_build "${_fixture_source}/build_foreign")
_run_process(
    "Configure foreign-owned build"
    "${CMAKE_COMMAND}"
        -S "${_foreign_source}"
        -B "${_foreign_build}")
_expect_clean_rejection(
    foreign_owned_cache
    "${_foreign_build}"
    "Refusing to clean a build owned by")

# Invoke the copied helper through an absolute path from a different checkout.
# A relative build path must still resolve against the helper's owning checkout,
# leaving the caller's equally named CMake build untouched.
set(_foreign_cwd_build "${_foreign_source}/build_absolute_invocation")
_run_process(
    "Configure foreign-CWD build"
    "${CMAKE_COMMAND}"
        -S "${_foreign_source}"
        -B "${_foreign_cwd_build}")
file(WRITE
    "${_foreign_cwd_build}/must_be_preserved.txt"
    "foreign checkout build output\n")
execute_process(
    COMMAND
      bash "${_fixture_build_script}"
      -B build_absolute_invocation
      --clean
      --skip-tests
    WORKING_DIRECTORY "${_foreign_source}"
    RESULT_VARIABLE _foreign_cwd_result
    OUTPUT_VARIABLE _foreign_cwd_stdout
    ERROR_VARIABLE _foreign_cwd_stderr)
if(NOT _foreign_cwd_result EQUAL 0)
  message(FATAL_ERROR
      "Absolute helper invocation from a foreign CWD failed with exit code "
      "${_foreign_cwd_result}.\n"
      "stdout:\n${_foreign_cwd_stdout}\n"
      "stderr:\n${_foreign_cwd_stderr}")
endif()
if(NOT EXISTS "${_foreign_cwd_build}/must_be_preserved.txt")
  message(FATAL_ERROR
      "Absolute helper invocation removed the foreign checkout's build tree.")
endif()
if(NOT EXISTS
   "${_fixture_source}/build_absolute_invocation/CMakeCache.txt")
  message(FATAL_ERROR
      "Relative build path did not resolve against the helper's checkout.")
endif()

# Accept an owned cache, remove its sentinel, and recreate a usable build tree.
set(_valid_build "${_fixture_source}/build_valid")
_run_process(
    "Configure valid owned build"
    "${CMAKE_COMMAND}"
        -S "${_fixture_source}"
        -B "${_valid_build}")
file(WRITE "${_valid_build}/must_be_removed.txt" "stale build output\n")
execute_process(
    COMMAND
      bash "${_fixture_build_script}"
      -B "${_valid_build}"
      --clean
      --skip-tests
    WORKING_DIRECTORY "${_fixture_source}"
    RESULT_VARIABLE _valid_clean_result
    OUTPUT_VARIABLE _valid_clean_stdout
    ERROR_VARIABLE _valid_clean_stderr)
if(NOT _valid_clean_result EQUAL 0)
  message(FATAL_ERROR
      "Clean and rebuild valid owned build failed with exit code "
      "${_valid_clean_result}.\n"
      "stdout:\n${_valid_clean_stdout}\n"
      "stderr:\n${_valid_clean_stderr}")
endif()
if(EXISTS "${_valid_build}/must_be_removed.txt")
  message(FATAL_ERROR "Owned clean did not remove the stale build sentinel.")
endif()
if(NOT EXISTS "${_valid_build}/CMakeCache.txt")
  message(FATAL_ERROR "Owned clean did not recreate a usable CMake build.")
endif()

# Rebuild-only must ignore --clean even for an external build and preserve all
# existing build-tree contents.
_run_process(
    "Configure external rebuild-only tree"
    "${CMAKE_COMMAND}"
        -S "${_fixture_source}"
        -B "${_external_rebuild}")
file(WRITE "${_external_rebuild}/must_be_preserved.txt" "rebuild-only sentinel\n")
execute_process(
    COMMAND
      bash "${_fixture_build_script}"
      -B "${_external_rebuild}"
      --rebuild-only
      --clean
      --skip-tests
    WORKING_DIRECTORY "${_fixture_source}"
    RESULT_VARIABLE _rebuild_only_result
    OUTPUT_VARIABLE _rebuild_only_stdout
    ERROR_VARIABLE _rebuild_only_stderr)
if(NOT _rebuild_only_result EQUAL 0)
  message(FATAL_ERROR
      "Rebuild-only with ignored clean flag failed with exit code "
      "${_rebuild_only_result}.\n"
      "stdout:\n${_rebuild_only_stdout}\n"
      "stderr:\n${_rebuild_only_stderr}")
endif()
if(NOT EXISTS "${_external_rebuild}/must_be_preserved.txt")
  message(FATAL_ERROR "--rebuild-only unexpectedly removed the external build.")
endif()
