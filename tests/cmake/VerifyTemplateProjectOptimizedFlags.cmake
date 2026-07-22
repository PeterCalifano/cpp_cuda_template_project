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

function(_assert_flags build_dir build_type)
  set(_compile_commands "${build_dir}/compile_commands.json")
  if(NOT EXISTS "${_compile_commands}")
    message(FATAL_ERROR "compile_commands.json not found: ${_compile_commands}")
  endif()

  file(READ "${_compile_commands}" _commands)
  if(build_type STREQUAL "Release")
    set(_required_flags "-O3" "-DNDEBUG")
  elseif(build_type STREQUAL "RelWithDebInfo")
    set(_required_flags "-O2" "-g" "-DNDEBUG")
  else()
    message(FATAL_ERROR "Unsupported optimized build type: ${build_type}")
  endif()

  foreach(_required ${_required_flags})
    if(NOT _commands MATCHES "${_required}")
      message(FATAL_ERROR "${build_type} compile commands do not contain required flag: ${_required}")
    endif()
  endforeach()

  foreach(_forbidden "-O0" "-Og" "-g3" "-fno-omit-frame-pointer" "-fno-inline" "-fno-optimize-sibling-calls" "-fsanitize")
    if(_commands MATCHES "${_forbidden}")
      message(FATAL_ERROR "${build_type} compile commands contain profiling/debug-only flag: ${_forbidden}")
    endif()
  endforeach()
endfunction()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")

foreach(_build_type IN ITEMS Release RelWithDebInfo)
  set(_build_dir "${TEST_BINARY_ROOT}/${_build_type}")
  _run_step(
      "Configure template ${_build_type} build"
      ${CMAKE_COMMAND}
          -S "${TEST_TEMPLATE_SOURCE_DIR}"
          -B "${_build_dir}"
          -DCMAKE_BUILD_TYPE=${_build_type}
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
          -DCPU_ENABLE_NATIVE_TUNING=OFF
          -DENABLE_TESTS=OFF
          -DENABLE_FETCH_CATCH2=OFF
          -DENABLE_CUDA=OFF
          -Dtemplate_project_BUILD_PROGRAMS=OFF
          -Dtemplate_project_BUILD_EXAMPLES=OFF)
  _assert_flags("${_build_dir}" "${_build_type}")
  _run_step("Build template ${_build_type} library" ${CMAKE_COMMAND} --build "${_build_dir}")
endforeach()
