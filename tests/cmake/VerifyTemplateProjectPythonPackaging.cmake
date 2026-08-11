cmake_minimum_required(VERSION 3.15)

# Prove exact, relocatable wrapper packaging with a self-contained native
# fixture. No gtwrap checkout or network access is required.
foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

find_program(_python_executable NAMES python3 REQUIRED)

# Run fixture commands with captured diagnostics so a failed acceptance step
# identifies both its intent and the underlying tool output.
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

# Require a fixture command to fail for the intended contract violation rather
# than accepting an unrelated configure error as proof of rejection.
function(_run_failure step_name expected_message)
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
  string(FIND "${_combined_output}" "${expected_message}" _message_index)
  if(_message_index LESS 0)
    message(FATAL_ERROR
        "${step_name} failed without the expected diagnostic "
        "'${expected_message}'.\n"
        "stdout:\n${_stdout}\n"
        "stderr:\n${_stderr}")
  endif()
endfunction()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
set(_fixture_source "${TEST_BINARY_ROOT}/fixture_source")
set(_fixture_build "${TEST_BINARY_ROOT}/fixture_build")
set(_absolute_libdir_build "${TEST_BINARY_ROOT}/absolute_libdir_build")
set(_runtime_collision_build "${TEST_BINARY_ROOT}/runtime_collision_build")
set(_wrapper_collision_build "${TEST_BINARY_ROOT}/wrapper_collision_build")
set(_soname_collision_build "${TEST_BINARY_ROOT}/soname_collision_build")
set(_generator_output_build "${TEST_BINARY_ROOT}/generator_output_build")
set(_wheel_output "${TEST_BINARY_ROOT}/wheel_output")
set(_wheel_install "${TEST_BINARY_ROOT}/wheel_install")
set(_cmake_install "${TEST_BINARY_ROOT}/cmake_install")
set(_expected_wheel_version "1.0.0rc1+5.gabc1234")
file(MAKE_DIRECTORY
    "${_fixture_source}/python/fixture_package"
    "${_wheel_output}")

# Build a two-library runtime chain plus an unrelated library in the same
# scratch build. The Python module calls through both declared runtime targets.
file(WRITE "${_fixture_source}/dependency.c"
"int FixtureDependencyValue(void)
{
    return 41;
}
")
file(WRITE "${_fixture_source}/runtime.c"
"int FixtureDependencyValue(void);

int FixtureRuntimeValue(void)
{
    return FixtureDependencyValue() + 1;
}
")
file(WRITE "${_fixture_source}/unrelated.c"
"int UnrelatedRuntimeValue(void)
{
    return -1;
}
")
file(WRITE "${_fixture_source}/packaged.c"
"int PackagedRuntimeValue(void)
{
    return 7;
}
")
file(WRITE "${_fixture_source}/module.c"
"#define PY_SSIZE_T_CLEAN
#include <Python.h>

int FixtureRuntimeValue(void);

static PyObject *RuntimeValue(PyObject *self, PyObject *args)
{
    (void)self;
    (void)args;
    return PyLong_FromLong(FixtureRuntimeValue());
}

static PyMethodDef FixtureMethods[] = {
    {\"Runtime_value\", RuntimeValue, METH_NOARGS,
     \"Return the value produced by the packaged runtime chain.\"},
    {NULL, NULL, 0, NULL}
};

static struct PyModuleDef FixtureModule = {
    PyModuleDef_HEAD_INIT,
    \"fixture_package\",
    \"Self-contained wrapper packaging fixture.\",
    -1,
    FixtureMethods
};

PyMODINIT_FUNC PyInit_fixture_package(void)
{
    return PyModule_Create(&FixtureModule);
}
")
file(WRITE "${_fixture_source}/python/fixture_package/__init__.py"
"\"\"\"Self-contained wrapper packaging fixture.\"\"\"

from .fixture_package import Runtime_value

__all__ = [\"Runtime_value\"]
")
file(WRITE
    "${_fixture_source}/python/fixture_package/stale_checkout_runtime.so.99"
    "stale checkout-native artifact\n")

set(_fixture_cmake_template [=[
cmake_minimum_required(VERSION 3.15)
project(python_packaging_fixture VERSION 1.0.0 LANGUAGES C)

include(GNUInstallDirs)
find_package(Python3 3.12 REQUIRED COMPONENTS Interpreter Development)
include("@TEST_TEMPLATE_SOURCE_DIR@/cmake/HandleWrapper.cmake")

# Export the small C fixture API on DLL platforms without adding
# platform-specific declarations to every generated source file.
if(WIN32)
  set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

add_library(fixture_dependency SHARED dependency.c)
set_target_properties(
  fixture_dependency
  PROPERTIES
    VERSION 2.3.4
    SOVERSION 2)

add_library(fixture_runtime SHARED runtime.c)
target_link_libraries(fixture_runtime PRIVATE fixture_dependency)
set_target_properties(
  fixture_runtime
  PROPERTIES
    VERSION 1.2.3
    SOVERSION 1)

add_library(unrelated_runtime SHARED unrelated.c)

# This declared runtime is intentionally not linked into the extension. Its
# staged copy must still refresh when only this target changes.
add_library(fixture_packaged SHARED packaged.c)
set_target_properties(
  fixture_packaged
  PROPERTIES
    VERSION 3.4.5
    SOVERSION 3)

# Exercise the flat package-directory collision contract without requiring a
# build that would already have overwritten one of the native artifacts.
option(FIXTURE_RUNTIME_COLLISION "Give two runtime targets identical filenames" OFF)
if(FIXTURE_RUNTIME_COLLISION)
  set_target_properties(
    fixture_dependency
    fixture_packaged
    PROPERTIES
      OUTPUT_NAME colliding_runtime
      VERSION 1.2.3
      SOVERSION 1)
  set_target_properties(
    fixture_dependency
    PROPERTIES
      LIBRARY_OUTPUT_DIRECTORY
        "${CMAKE_CURRENT_BINARY_DIR}/collision_outputs/dependency"
      RUNTIME_OUTPUT_DIRECTORY
        "${CMAKE_CURRENT_BINARY_DIR}/collision_outputs/dependency")
  set_target_properties(
    fixture_packaged
    PROPERTIES
      LIBRARY_OUTPUT_DIRECTORY
        "${CMAKE_CURRENT_BINARY_DIR}/collision_outputs/packaged"
      RUNTIME_OUTPUT_DIRECTORY
        "${CMAKE_CURRENT_BINARY_DIR}/collision_outputs/packaged")
endif()

add_library(fixture_package MODULE module.c)
target_link_libraries(
  fixture_package
  PRIVATE
    fixture_runtime
    Python3::Python)
set_target_properties(fixture_package PROPERTIES PREFIX "")
if(WIN32)
  set_target_properties(fixture_package PROPERTIES SUFFIX ".pyd")
endif()

# Additional collision fixtures build into separate directories so only the
# wrapper's flat staging contract can reject their resolved filenames.
set(_additional_runtime_targets)
option(FIXTURE_WRAPPER_COLLISION
  "Give a runtime target the wrapper extension filename" OFF)
if(FIXTURE_WRAPPER_COLLISION)
  add_library(fixture_wrapper_collision MODULE packaged.c)
  set_target_properties(
    fixture_wrapper_collision
    PROPERTIES
      PREFIX ""
      OUTPUT_NAME fixture_package
      LIBRARY_OUTPUT_DIRECTORY
        "${CMAKE_CURRENT_BINARY_DIR}/collision_outputs/wrapper"
      RUNTIME_OUTPUT_DIRECTORY
        "${CMAKE_CURRENT_BINARY_DIR}/collision_outputs/wrapper")
  if(WIN32)
    set_target_properties(fixture_wrapper_collision PROPERTIES SUFFIX ".pyd")
  endif()
  list(APPEND _additional_runtime_targets fixture_wrapper_collision)
endif()

option(FIXTURE_SONAME_COLLISION
  "Give one runtime the resolved SONAME filename of another" OFF)
if(FIXTURE_SONAME_COLLISION AND UNIX AND NOT APPLE)
  add_library(fixture_soname_owner SHARED packaged.c)
  set_target_properties(
    fixture_soname_owner
    PROPERTIES
      OUTPUT_NAME soname_collision
      VERSION 2.0.0
      SOVERSION 2
      LIBRARY_OUTPUT_DIRECTORY
        "${CMAKE_CURRENT_BINARY_DIR}/collision_outputs/soname_owner")

  add_library(fixture_target_owner SHARED packaged.c)
  set_target_properties(
    fixture_target_owner
    PROPERTIES
      PREFIX ""
      OUTPUT_NAME "libsoname_collision.so.2"
      SUFFIX ""
      NO_SONAME TRUE
      LIBRARY_OUTPUT_DIRECTORY
        "${CMAKE_CURRENT_BINARY_DIR}/collision_outputs/target_owner")
  list(APPEND
    _additional_runtime_targets
    fixture_soname_owner
    fixture_target_owner)
endif()

option(FIXTURE_GENERATOR_OUTPUT_NAME
  "Use a configuration-dependent runtime output name" OFF)
if(FIXTURE_GENERATOR_OUTPUT_NAME)
  set_target_properties(
    fixture_packaged
    PROPERTIES
      OUTPUT_NAME
        "$<IF:$<CONFIG:Debug>,fixture_packaged_debug,fixture_packaged_release>")
endif()

# Treat the generated package root as a build product and preserve the fixture
# source directory as immutable input.
set(_package_source "${CMAKE_CURRENT_SOURCE_DIR}/python")
set(_package_source_dir "${_package_source}/fixture_package")
set(_package_build_root "${CMAKE_CURRENT_BINARY_DIR}/python")
set(_package_build_dir "${_package_build_root}/fixture_package")
_stage_python_package_sources(
  "${_package_source_dir}"
  "${_package_build_dir}")
set_python_target_properties(
  fixture_package
  "fixture_package"
  "${_package_build_dir}")

# A full requested version must not leak its patch component into the
# major.minor site-packages directory selected for the resolved interpreter.
set(WRAP_PYTHON_VERSION "${Python3_VERSION}")
set(Python_VERSION_MAJOR "${Python3_VERSION_MAJOR}")
set(Python_VERSION_MINOR "${Python3_VERSION_MINOR}")
_resolve_python_install_root(_python_install_root)
set(_expected_python_install_root
  "${CMAKE_INSTALL_LIBDIR}/python${Python3_VERSION_MAJOR}.${Python3_VERSION_MINOR}/site-packages")
if(NOT "${_python_install_root}" STREQUAL "${_expected_python_install_root}")
  message(FATAL_ERROR
    "Resolved Python install root '${_python_install_root}' does not match "
    "'${_expected_python_install_root}' for requested version "
    "'${WRAP_PYTHON_VERSION}'.")
endif()
set(_package_install_destination
  "${_python_install_root}/fixture_package")
configure_python_runtime_artifacts(
  fixture_package
  "${_package_build_dir}"
  "${_package_install_destination}"
  "${_package_build_dir}/_wrapper_build.py"
  fixture_runtime
  fixture_dependency
  fixture_packaged
  ${_additional_runtime_targets})

set(PROJECT_NAME fixture_package)
set(PROJECT_VERSION 1.0.0)
set(FULL_VERSION "1.0.0-rc.1+5.gabc1234")
configure_file(
  "@TEST_TEMPLATE_SOURCE_DIR@/python/pyproject.toml.in"
  "${_package_build_root}/pyproject.toml"
  @ONLY)
configure_file(
  "@TEST_TEMPLATE_SOURCE_DIR@/python/setup.py.in"
  "${_package_build_root}/setup.py"
  @ONLY)

install(
  TARGETS fixture_package
  LIBRARY DESTINATION "${_package_install_destination}"
  RUNTIME DESTINATION "${_package_install_destination}")
install(
  DIRECTORY "${_package_build_dir}/"
  DESTINATION "${_package_install_destination}"
  PATTERN "_wrapper_build.py" EXCLUDE
  PATTERN "__pycache__" EXCLUDE
  PATTERN "*.pyc" EXCLUDE
  PATTERN "*.so*" EXCLUDE
  PATTERN "*.dylib" EXCLUDE
  PATTERN "*.dll" EXCLUDE
  PATTERN "*.pyd" EXCLUDE)

file(WRITE
  "${CMAKE_CURRENT_BINARY_DIR}/python_install_root.txt"
  "${_python_install_root}")
file(GENERATE
  OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/expected_runtime_names.txt"
  CONTENT
"$<TARGET_FILE_NAME:fixture_runtime>
$<TARGET_SONAME_FILE_NAME:fixture_runtime>
$<TARGET_FILE_NAME:fixture_dependency>
$<TARGET_SONAME_FILE_NAME:fixture_dependency>
$<TARGET_FILE_NAME:fixture_packaged>
$<TARGET_SONAME_FILE_NAME:fixture_packaged>
")
file(GENERATE
  OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/expected_wrapper_name.txt"
  CONTENT "$<TARGET_FILE_NAME:fixture_package>")
file(GENERATE
  OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/unrelated_name.txt"
  CONTENT "$<TARGET_FILE_NAME:unrelated_runtime>")
file(GENERATE
  OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/packaged_target_path.txt"
  CONTENT "$<TARGET_FILE:fixture_packaged>")
file(GENERATE
  OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/packaged_staged_path.txt"
  CONTENT "${_package_build_dir}/$<TARGET_FILE_NAME:fixture_packaged>")
]=])
string(CONFIGURE
    "${_fixture_cmake_template}"
    _fixture_cmake
    @ONLY)
file(WRITE "${_fixture_source}/CMakeLists.txt" "${_fixture_cmake}")

# A CMake install destination must remain below the user-selected prefix.
_run_failure(
    "Reject an absolute CMake Python library destination"
    "CMAKE_INSTALL_LIBDIR must be relative"
    "${CMAKE_COMMAND}"
        -S "${_fixture_source}"
        -B "${_absolute_libdir_build}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DCMAKE_INSTALL_LIBDIR=${TEST_BINARY_ROOT}/absolute_lib)

# Runtime collision validation uses the filenames resolved for the active
# configuration and must complete before the flat staging directory is changed.
_run_step(
    "Configure colliding Python runtime destinations"
    "${CMAKE_COMMAND}"
        -S "${_fixture_source}"
        -B "${_runtime_collision_build}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DFIXTURE_RUNTIME_COLLISION=ON)
_run_failure(
    "Reject colliding Python runtime destinations before staging"
    "Python runtime destination collision"
    "${CMAKE_COMMAND}"
        --build "${_runtime_collision_build}"
        --target fixture_package
        --parallel 4)
file(GLOB
    _collision_staged_files
    "${_runtime_collision_build}/python/fixture_package/*colliding_runtime*")
if(_collision_staged_files)
  message(FATAL_ERROR
      "Runtime collision staging left partial artifacts: "
      "${_collision_staged_files}")
endif()

# The wrapper module and declared runtimes also share the same flat namespace.
_run_step(
    "Configure a runtime that collides with the wrapper extension"
    "${CMAKE_COMMAND}"
        -S "${_fixture_source}"
        -B "${_wrapper_collision_build}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DFIXTURE_WRAPPER_COLLISION=ON)
_run_failure(
    "Reject a runtime that collides with the wrapper extension"
    "Python runtime destination collision"
    "${CMAKE_COMMAND}"
        --build "${_wrapper_collision_build}"
        --target fixture_package
        --parallel 4)

if(UNIX AND NOT APPLE)
  _run_step(
      "Configure a target-file versus SONAME collision"
      "${CMAKE_COMMAND}"
          -S "${_fixture_source}"
          -B "${_soname_collision_build}"
          -DCMAKE_BUILD_TYPE=RelWithDebInfo
          -DFIXTURE_SONAME_COLLISION=ON)
  _run_failure(
      "Reject a target-file versus SONAME collision"
      "Python runtime destination collision"
      "${CMAKE_COMMAND}"
          --build "${_soname_collision_build}"
          --target fixture_package
          --parallel 4)
endif()

# Actual active-configuration filenames make generator-expression output names
# safe to validate without approximating CMake's naming rules.
_run_step(
    "Configure generator-expression runtime output names"
    "${CMAKE_COMMAND}"
        -S "${_fixture_source}"
        -B "${_generator_output_build}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DFIXTURE_GENERATOR_OUTPUT_NAME=ON)
_run_step(
    "Build generator-expression runtime output names"
    "${CMAKE_COMMAND}"
        --build "${_generator_output_build}"
        --target fixture_package
        --parallel 4)

# Verify exact wheel contents using target-derived names emitted by the fixture
# configure, not platform-specific names duplicated in this verifier.
file(WRITE "${TEST_BINARY_ROOT}/verify_wheel.py"
"from email.parser import Parser
from pathlib import Path
import sys
from zipfile import ZipFile

wheel_path_ = Path(sys.argv[1])
expected_names_path_ = Path(sys.argv[2])
wrapper_name_path_ = Path(sys.argv[3])
unrelated_name_path_ = Path(sys.argv[4])
expected_version_ = sys.argv[5]

expected_runtime_names_ = {
    name_.strip()
    for name_ in expected_names_path_.read_text().splitlines()
    if name_.strip()
}
wrapper_name_ = wrapper_name_path_.read_text().strip()
unrelated_name_ = unrelated_name_path_.read_text().strip()
expected_native_names_ = expected_runtime_names_ | {wrapper_name_}

with ZipFile(wheel_path_) as wheel_file_:
    archive_names_ = set(wheel_file_.namelist())
    metadata_names_ = [
        name_
        for name_ in archive_names_
        if name_.endswith(\".dist-info/METADATA\")
    ]
    assert len(metadata_names_) == 1, metadata_names_
    metadata_ = Parser().parsestr(
        wheel_file_.read(metadata_names_[0]).decode(\"utf-8\")
    )

packaged_native_names_ = {
    Path(name_).name
    for name_ in archive_names_
    if name_.startswith(\"fixture_package/\")
    and (
        \".so\" in Path(name_).name
        or Path(name_).suffix in {\".dylib\", \".dll\", \".pyd\"}
    )
}

assert packaged_native_names_ == expected_native_names_, (
    packaged_native_names_,
    expected_native_names_,
)
assert unrelated_name_ not in packaged_native_names_
assert not any(name_.endswith(\"_wrapper_build.py\") for name_ in archive_names_)
assert metadata_[\"Version\"] == expected_version_, metadata_[\"Version\"]
print(\"wheel_contents=ok\")
")
file(WRITE "${TEST_BINARY_ROOT}/verify_install.py"
"from pathlib import Path
import sys

package_dir_ = Path(sys.argv[1])
expected_names_path_ = Path(sys.argv[2])
wrapper_name_path_ = Path(sys.argv[3])
unrelated_name_path_ = Path(sys.argv[4])

expected_runtime_names_ = {
    name_.strip()
    for name_ in expected_names_path_.read_text().splitlines()
    if name_.strip()
}
wrapper_name_ = wrapper_name_path_.read_text().strip()
unrelated_name_ = unrelated_name_path_.read_text().strip()

for expected_name_ in expected_runtime_names_ | {wrapper_name_}:
    assert (package_dir_ / expected_name_).is_file(), expected_name_

installed_native_names_ = {
    path_.name
    for path_ in package_dir_.iterdir()
    if path_.is_file()
    and (
        \".so\" in path_.name
        or path_.suffix in {\".dylib\", \".dll\", \".pyd\"}
    )
}
expected_native_names_ = expected_runtime_names_ | {wrapper_name_}
assert installed_native_names_ == expected_native_names_, (
    installed_native_names_,
    expected_native_names_,
)
assert not (package_dir_ / unrelated_name_).exists()
assert not (package_dir_ / \"_wrapper_build.py\").exists()
assert not list(package_dir_.glob(\"*.pyc\"))
assert not (package_dir_ / \"__pycache__\").exists()
print(\"cmake_install_contents=ok\")
")

_run_step(
    "Configure self-contained Python packaging fixture"
    "${CMAKE_COMMAND}"
        -S "${_fixture_source}"
        -B "${_fixture_build}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo)
if(EXISTS
   "${_fixture_build}/python/fixture_package/stale_checkout_runtime.so.99")
  message(FATAL_ERROR
      "Configure staged a stale checkout-native package artifact.")
endif()
_run_step(
    "Build self-contained Python packaging fixture"
    "${CMAKE_COMMAND}"
        --build "${_fixture_build}"
        --parallel 4)

# A configured package directory is a disposable build product. Reconfigure
# after injecting an undeclared file and require the package to be reconstructed
# exclusively from its source inputs.
set(_stale_package_marker
    "${_fixture_build}/python/fixture_package/stale_review_marker.py")
file(WRITE "${_stale_package_marker}" "raise RuntimeError('stale package file')\n")
_run_step(
    "Reconfigure fixture with a stale build-package file"
    "${CMAKE_COMMAND}"
        -S "${_fixture_source}"
        -B "${_fixture_build}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo)
if(EXISTS "${_stale_package_marker}")
  message(FATAL_ERROR
      "Reconfigure retained undeclared Python package file: "
      "${_stale_package_marker}")
endif()

# Configuration and build must not add packaging outputs beside the source
# package used to seed the disposable fixture.
file(GLOB_RECURSE
    _source_python_files
    LIST_DIRECTORIES FALSE
    RELATIVE "${_fixture_source}/python"
    "${_fixture_source}/python/*")
set(_expected_source_python_files
    "fixture_package/__init__.py;fixture_package/stale_checkout_runtime.so.99")
if(NOT "${_source_python_files}" STREQUAL "${_expected_source_python_files}")
  message(FATAL_ERROR
      "Python packaging mutated fixture sources: ${_source_python_files}")
endif()

# Rebuild an unlinked declared runtime through the wrapper target. Its staged
# file must refresh even though the extension itself does not need to relink.
file(WRITE "${_fixture_source}/packaged.c"
"int PackagedRuntimeValue(void)
{
    return 8;
}
")
_run_step(
    "Refresh an incrementally rebuilt declared runtime"
    "${CMAKE_COMMAND}"
        --build "${_fixture_build}"
        --target fixture_package
        --parallel 4)
file(READ "${_fixture_build}/packaged_target_path.txt" _packaged_target_path)
file(READ "${_fixture_build}/packaged_staged_path.txt" _packaged_staged_path)
string(STRIP "${_packaged_target_path}" _packaged_target_path)
string(STRIP "${_packaged_staged_path}" _packaged_staged_path)
_run_step(
    "Compare refreshed target and staged runtime"
    "${CMAKE_COMMAND}" -E compare_files
        "${_packaged_target_path}"
        "${_packaged_staged_path}")

_run_step(
    "Build isolated fixture wheel"
    "${_python_executable}"
        -m pip wheel
        "${_fixture_build}/python"
        --no-build-isolation
        --no-deps
        --wheel-dir "${_wheel_output}")
file(GLOB _wheel_paths "${_wheel_output}/fixture_package-*.whl")
list(LENGTH _wheel_paths _wheel_count)
if(NOT _wheel_count EQUAL 1)
  message(FATAL_ERROR
      "Expected one fixture wheel, found ${_wheel_count}: ${_wheel_paths}")
endif()
list(GET _wheel_paths 0 _wheel_path)

_run_step(
    "Verify exact fixture wheel contents"
    "${_python_executable}"
        "${TEST_BINARY_ROOT}/verify_wheel.py"
        "${_wheel_path}"
        "${_fixture_build}/expected_runtime_names.txt"
        "${_fixture_build}/expected_wrapper_name.txt"
        "${_fixture_build}/unrelated_name.txt"
        "${_expected_wheel_version}")
_run_step(
    "Install fixture wheel into isolated target"
    "${_python_executable}"
        -m pip install
        --no-deps
        --target "${_wheel_install}"
        "${_wheel_path}")
_run_step(
    "Import isolated fixture wheel"
    "${CMAKE_COMMAND}" -E env
        "PYTHONPATH=${_wheel_install}"
        "LD_LIBRARY_PATH="
        "${_python_executable}" -c
        "import fixture_package; assert fixture_package.Runtime_value() == 42")

_run_step(
    "Install fixture through CMake prefix"
    "${CMAKE_COMMAND}"
        --install "${_fixture_build}"
        --prefix "${_cmake_install}")
file(READ "${_fixture_build}/python_install_root.txt" _python_install_root)
string(STRIP "${_python_install_root}" _python_install_root)
set(_cmake_package_dir
    "${_cmake_install}/${_python_install_root}/fixture_package")
_run_step(
    "Verify exact CMake install contents"
    "${_python_executable}"
        "${TEST_BINARY_ROOT}/verify_install.py"
        "${_cmake_package_dir}"
        "${_fixture_build}/expected_runtime_names.txt"
        "${_fixture_build}/expected_wrapper_name.txt"
        "${_fixture_build}/unrelated_name.txt")
_run_step(
    "Import isolated CMake-installed fixture"
    "${CMAKE_COMMAND}" -E env
        "PYTHONPATH=${_cmake_install}/${_python_install_root}"
        "LD_LIBRARY_PATH="
        "${_python_executable}" -c
        "import fixture_package; assert fixture_package.Runtime_value() == 42")

# Import success proves the loader chain is viable. On supported host tools,
# also reject embedded absolute scratch paths directly.
file(READ "${_fixture_build}/expected_wrapper_name.txt" _wrapper_name)
string(STRIP "${_wrapper_name}" _wrapper_name)
set(_installed_wrapper "${_cmake_package_dir}/${_wrapper_name}")
file(
  STRINGS
  "${_fixture_build}/expected_runtime_names.txt"
  _runtime_names)
set(_installed_native_artifacts "${_installed_wrapper}")
foreach(_runtime_name IN LISTS _runtime_names)
  if(NOT "${_runtime_name}" STREQUAL "")
    list(APPEND
      _installed_native_artifacts
      "${_cmake_package_dir}/${_runtime_name}")
  endif()
endforeach()
list(REMOVE_DUPLICATES _installed_native_artifacts)

if(UNIX AND NOT APPLE)
  find_program(_readelf_executable NAMES readelf REQUIRED)
  foreach(_installed_native_artifact IN LISTS _installed_native_artifacts)
    execute_process(
        COMMAND "${_readelf_executable}" -d "${_installed_native_artifact}"
        RESULT_VARIABLE _readelf_result
        OUTPUT_VARIABLE _readelf_output
        ERROR_VARIABLE _readelf_stderr)
    if(NOT _readelf_result EQUAL 0)
      message(FATAL_ERROR
          "readelf failed for ${_installed_native_artifact}: "
          "${_readelf_stderr}")
    endif()
    if(NOT _readelf_output MATCHES "\\$ORIGIN")
      message(FATAL_ERROR
          "Installed native artifact has no loader-relative RUNPATH: "
          "${_installed_native_artifact}")
    endif()
    string(FIND "${_readelf_output}" "${TEST_BINARY_ROOT}" _scratch_rpath_index)
    if(NOT _scratch_rpath_index EQUAL -1)
      message(FATAL_ERROR
          "Installed native artifact retains scratch path: "
          "${_installed_native_artifact}\n${_readelf_output}")
    endif()
  endforeach()
elseif(APPLE)
  find_program(_otool_executable NAMES otool REQUIRED)
  foreach(_installed_native_artifact IN LISTS _installed_native_artifacts)
    execute_process(
        COMMAND "${_otool_executable}" -l "${_installed_native_artifact}"
        RESULT_VARIABLE _otool_result
        OUTPUT_VARIABLE _otool_output
        ERROR_VARIABLE _otool_stderr)
    if(NOT _otool_result EQUAL 0)
      message(FATAL_ERROR
          "otool failed for ${_installed_native_artifact}: ${_otool_stderr}")
    endif()
    if(NOT _otool_output MATCHES "@loader_path")
      message(FATAL_ERROR
          "Installed native artifact has no loader-relative RPATH: "
          "${_installed_native_artifact}")
    endif()
    string(FIND "${_otool_output}" "${TEST_BINARY_ROOT}" _scratch_rpath_index)
    if(NOT _scratch_rpath_index EQUAL -1)
      message(FATAL_ERROR
          "Installed native artifact retains scratch path: "
          "${_installed_native_artifact}\n${_otool_output}")
    endif()
  endforeach()
endif()
