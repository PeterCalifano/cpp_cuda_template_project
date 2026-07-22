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
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}")

set(_build_dir "${TEST_BINARY_ROOT}/configure")
_run_step(
    "Configure CUDA build with Catch2 unavailable"
    ${CMAKE_COMMAND}
        -S "${TEST_TEMPLATE_SOURCE_DIR}"
        -B "${_build_dir}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DENABLE_CUDA=ON
        -DENABLE_OPTIX=OFF
        -DENABLE_OPENGL=OFF
        -DENABLE_TBB=OFF
        -DENABLE_TESTS=ON
        -DENABLE_PYTHON_TESTS=OFF
        -DENABLE_FETCH_CATCH2=OFF
        -DCMAKE_DISABLE_FIND_PACKAGE_Catch2=TRUE
        -Dtemplate_project_BUILD_PROGRAMS=OFF
        -Dtemplate_project_BUILD_EXAMPLES=OFF
        -Dtemplate_project_BUILD_PYTHON_WRAPPER=OFF
        -Dtemplate_project_BUILD_MATLAB_WRAPPER=OFF)
