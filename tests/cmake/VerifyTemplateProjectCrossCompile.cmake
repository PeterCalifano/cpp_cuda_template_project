cmake_minimum_required(VERSION 3.15)

foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT TEST_TOOLCHAIN_FILE TEST_CASE)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

if(NOT EXISTS "${TEST_TEMPLATE_SOURCE_DIR}/CMakeLists.txt")
  message(FATAL_ERROR "Invalid template source dir: ${TEST_TEMPLATE_SOURCE_DIR}")
endif()

if(NOT EXISTS "${TEST_TOOLCHAIN_FILE}")
  message(FATAL_ERROR "Invalid toolchain file: ${TEST_TOOLCHAIN_FILE}")
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

function(_configure_template build_dir install_dir)
  _run_step(
      "Configure template cross build"
      ${CMAKE_COMMAND}
          -S "${TEST_TEMPLATE_SOURCE_DIR}"
          -B "${build_dir}"
          -DCMAKE_TOOLCHAIN_FILE=${TEST_TOOLCHAIN_FILE}
          -DCMAKE_BUILD_TYPE=RelWithDebInfo
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
          -DCMAKE_INSTALL_PREFIX=${install_dir}
          -DENABLE_TESTS=OFF
          -DENABLE_FETCH_CATCH2=OFF
          -DENABLE_CUDA=OFF
          -Dtemplate_project_BUILD_PROGRAMS=OFF
          -Dtemplate_project_BUILD_EXAMPLES=OFF)
endfunction()

function(_assert_compile_commands build_dir)
  set(_compile_commands "${build_dir}/compile_commands.json")
  if(NOT EXISTS "${_compile_commands}")
    message(FATAL_ERROR "compile_commands.json not found: ${_compile_commands}")
  endif()

  file(READ "${_compile_commands}" _commands)
  foreach(_forbidden "-march=native" "-mtune=native")
    if(_commands MATCHES "${_forbidden}")
      message(FATAL_ERROR "Cross compile commands contain forbidden host-native flag: ${_forbidden}")
    endif()
  endforeach()

  foreach(_required "CROSS_COMPILED=1" "ARCH_AARCH64=1" "TARGET_OS_LINUX=1")
    if(NOT _commands MATCHES "${_required}")
      message(FATAL_ERROR "Cross compile commands do not contain required define: ${_required}")
    endif()
  endforeach()
endfunction()

function(_write_installed_consumer source_dir)
  file(REMOVE_RECURSE "${source_dir}")
  file(MAKE_DIRECTORY "${source_dir}")

  file(WRITE "${source_dir}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(template_project_cross_consumer LANGUAGES CXX)
find_package(template_project REQUIRED)
add_library(consumer_library STATIC consumer.cpp)
target_link_libraries(consumer_library PUBLIC template_project::template_project)
add_executable(consumer_main main.cpp)
target_link_libraries(consumer_main PRIVATE consumer_library)
")

  file(WRITE "${source_dir}/consumer.cpp"
"#include <template_src/placeholder.h>
void ConsumerCall()
{
    placeholder::placeholder_fcn();
}
")

  file(WRITE "${source_dir}/main.cpp"
"void ConsumerCall();
int main()
{
    ConsumerCall();
    return 0;
}
")
endfunction()

function(_write_nested_consumer source_dir)
  file(REMOVE_RECURSE "${source_dir}")
  file(MAKE_DIRECTORY "${source_dir}")

  file(WRITE "${source_dir}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.15)
project(template_project_nested_cross_consumer LANGUAGES CXX)
set(LIB_NAMESPACE_OVERRIDE nested_template CACHE STRING \"\" FORCE)
set(LIB_TARGET_NAME_OVERRIDE nested_template_project CACHE STRING \"\" FORCE)
set(ENABLE_TESTS OFF CACHE BOOL \"\" FORCE)
set(ENABLE_FETCH_CATCH2 OFF CACHE BOOL \"\" FORCE)
set(ENABLE_CUDA OFF CACHE BOOL \"\" FORCE)
set(nested_template_BUILD_PROGRAMS OFF CACHE BOOL \"\" FORCE)
set(nested_template_BUILD_EXAMPLES OFF CACHE BOOL \"\" FORCE)
add_subdirectory(\"${TEST_TEMPLATE_SOURCE_DIR}\" \"${CMAKE_CURRENT_BINARY_DIR}/template_project_subbuild\" EXCLUDE_FROM_ALL)
add_library(parent_library STATIC parent.cpp)
target_link_libraries(parent_library PUBLIC nested_template::template_project)
add_executable(nested_main main.cpp)
target_link_libraries(nested_main PRIVATE parent_library)
")

  file(WRITE "${source_dir}/parent.cpp"
"#include <template_src/placeholder.h>
void ParentCall()
{
    placeholder::placeholder_fcn();
}
")

  file(WRITE "${source_dir}/main.cpp"
"void ParentCall();
int main()
{
    ParentCall();
    return 0;
}
")
endfunction()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}")

if(TEST_CASE STREQUAL "configure_flags")
  set(_build_dir "${TEST_BINARY_ROOT}/template_build")
  set(_install_dir "${TEST_BINARY_ROOT}/template_install")
  _configure_template("${_build_dir}" "${_install_dir}")
  _assert_compile_commands("${_build_dir}")
  _run_step("Build template cross library" ${CMAKE_COMMAND} --build "${_build_dir}")
elseif(TEST_CASE STREQUAL "install_consumer")
  set(_build_dir "${TEST_BINARY_ROOT}/template_build")
  set(_install_dir "${TEST_BINARY_ROOT}/template_install")
  set(_consumer_source_dir "${TEST_BINARY_ROOT}/consumer_source")
  set(_consumer_build_dir "${TEST_BINARY_ROOT}/consumer_build")

  _configure_template("${_build_dir}" "${_install_dir}")
  _run_step("Install template cross library" ${CMAKE_COMMAND} --build "${_build_dir}" --target install)
  _write_installed_consumer("${_consumer_source_dir}")
  _run_step(
      "Configure installed cross consumer"
      ${CMAKE_COMMAND}
          -S "${_consumer_source_dir}"
          -B "${_consumer_build_dir}"
          -DCMAKE_TOOLCHAIN_FILE=${TEST_TOOLCHAIN_FILE}
          -DCMAKE_PREFIX_PATH=${_install_dir}
          -DCMAKE_BUILD_TYPE=RelWithDebInfo)
  _run_step("Build installed cross consumer" ${CMAKE_COMMAND} --build "${_consumer_build_dir}")
elseif(TEST_CASE STREQUAL "nested_consumer")
  set(_nested_source_dir "${TEST_BINARY_ROOT}/nested_source")
  set(_nested_build_dir "${TEST_BINARY_ROOT}/nested_build")

  _write_nested_consumer("${_nested_source_dir}")
  _run_step(
      "Configure nested cross consumer"
      ${CMAKE_COMMAND}
          -S "${_nested_source_dir}"
          -B "${_nested_build_dir}"
          -DCMAKE_TOOLCHAIN_FILE=${TEST_TOOLCHAIN_FILE}
          -DCMAKE_BUILD_TYPE=RelWithDebInfo
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON)
  _assert_compile_commands("${_nested_build_dir}")
  _run_step("Build nested cross consumer" ${CMAKE_COMMAND} --build "${_nested_build_dir}")
else()
  message(FATAL_ERROR "Unsupported TEST_CASE='${TEST_CASE}'.")
endif()
