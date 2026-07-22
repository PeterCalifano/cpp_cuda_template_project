cmake_minimum_required(VERSION 3.15)

foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

if(NOT EXISTS "${TEST_TEMPLATE_SOURCE_DIR}/CMakeLists.txt")
  message(FATAL_ERROR "Invalid template source dir: ${TEST_TEMPLATE_SOURCE_DIR}")
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

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")

_run_step(
    "Configure template no-optimization build"
    ${CMAKE_COMMAND}
        -S "${TEST_TEMPLATE_SOURCE_DIR}"
        -B "${TEST_BINARY_ROOT}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
        -DNO_OPTIMIZATION=ON
        -DENABLE_TESTS=OFF
        -DENABLE_FETCH_CATCH2=OFF
        -DENABLE_CUDA=OFF
        -Dtemplate_project_BUILD_PROGRAMS=OFF
        -Dtemplate_project_BUILD_EXAMPLES=OFF)

set(_compile_commands "${TEST_BINARY_ROOT}/compile_commands.json")
if(NOT EXISTS "${_compile_commands}")
  message(FATAL_ERROR "compile_commands.json not found: ${_compile_commands}")
endif()

file(READ "${_compile_commands}" _commands)
foreach(_required "-O0" "-g3" "-fno-omit-frame-pointer" "-fno-inline" "-fno-optimize-sibling-calls")
  if(NOT _commands MATCHES "${_required}")
    message(FATAL_ERROR "No-optimization compile commands do not contain required flag: ${_required}")
  endif()
endforeach()

foreach(_forbidden "-O2" "-O3" "-march=native" "-mtune=native" "-DNDEBUG")
  if(_commands MATCHES "${_forbidden}")
    message(FATAL_ERROR "No-optimization compile commands contain forbidden flag: ${_forbidden}")
  endif()
endforeach()

_run_step("Build template no-optimization library" ${CMAKE_COMMAND} --build "${TEST_BINARY_ROOT}")
