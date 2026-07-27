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

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
set(_fixture_source "${TEST_BINARY_ROOT}/fixture_source")
set(_fixture_build "${TEST_BINARY_ROOT}/fixture_build")
set(_wheel_output "${TEST_BINARY_ROOT}/wheel_output")
set(_wheel_install "${TEST_BINARY_ROOT}/wheel_install")
set(_cmake_install "${TEST_BINARY_ROOT}/cmake_install")
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

set(_package_source "${CMAKE_CURRENT_SOURCE_DIR}/python")
set(_package_dir "${_package_source}/fixture_package")
set(_package_build_dir "${CMAKE_CURRENT_BINARY_DIR}/python/fixture_package")
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
  _runtime_metadata_entries
  fixture_runtime
  fixture_dependency
  fixture_packaged)

set(_wrapper_metadata
"\"\"\"Generated wrapper packaging fixture metadata.\"\"\"

WRAPPER_MODULE_PATH = r\"$<TARGET_FILE:fixture_package>\"
WRAPPER_RUNTIME_LIBRARY_PATHS = [
${_runtime_metadata_entries}]
")
file(GENERATE
  OUTPUT "${_package_dir}/_wrapper_build.py"
  CONTENT "${_wrapper_metadata}")

set(PROJECT_NAME fixture_package)
set(PROJECT_VERSION 1.0.0)
configure_file(
  "@TEST_TEMPLATE_SOURCE_DIR@/python/pyproject.toml.in"
  "${_package_source}/pyproject.toml"
  @ONLY)
configure_file(
  "@TEST_TEMPLATE_SOURCE_DIR@/python/setup.py.in"
  "${_package_source}/setup.py"
  @ONLY)

install(
  TARGETS fixture_package
  LIBRARY DESTINATION "${_package_install_destination}"
  RUNTIME DESTINATION "${_package_install_destination}")
install(
  DIRECTORY "${_package_dir}/"
  DESTINATION "${_package_install_destination}"
  PATTERN "_wrapper_build.py" EXCLUDE
  PATTERN "__pycache__" EXCLUDE
  PATTERN "*.pyc" EXCLUDE)

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

# Verify exact wheel contents using target-derived names emitted by the fixture
# configure, not platform-specific names duplicated in this verifier.
file(WRITE "${TEST_BINARY_ROOT}/verify_wheel.py"
"from pathlib import Path
import sys
from zipfile import ZipFile

wheel_path_ = Path(sys.argv[1])
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
expected_native_names_ = expected_runtime_names_ | {wrapper_name_}

with ZipFile(wheel_path_) as wheel_file_:
    archive_names_ = set(wheel_file_.namelist())

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
_run_step(
    "Build self-contained Python packaging fixture"
    "${CMAKE_COMMAND}"
        --build "${_fixture_build}"
        --parallel 4)

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
        "${_fixture_source}/python"
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
        "${_fixture_build}/unrelated_name.txt")
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
