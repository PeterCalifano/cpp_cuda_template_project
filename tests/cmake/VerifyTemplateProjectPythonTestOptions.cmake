cmake_minimum_required(VERSION 3.15)

foreach(required_var TEST_TEMPLATE_SOURCE_DIR TEST_BINARY_ROOT)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

function(_configure_expect_success case_name)
  set(_build_dir "${TEST_BINARY_ROOT}/${case_name}")
  execute_process(
      COMMAND ${CMAKE_COMMAND}
          -S "${TEST_TEMPLATE_SOURCE_DIR}"
          -B "${_build_dir}"
          -DCMAKE_BUILD_TYPE=RelWithDebInfo
          -DENABLE_CUDA=OFF
          -DENABLE_OPTIX=OFF
          -DENABLE_OPENGL=OFF
          -DENABLE_TBB=OFF
          -DENABLE_FETCH_CATCH2=OFF
          -Dtemplate_project_BUILD_PROGRAMS=OFF
          -Dtemplate_project_BUILD_EXAMPLES=OFF
          ${ARGN}
      RESULT_VARIABLE _result
      OUTPUT_VARIABLE _stdout
      ERROR_VARIABLE _stderr)

  if(NOT _result EQUAL 0)
    message(FATAL_ERROR
        "Expected configure '${case_name}' to pass, but it failed with ${_result}.\n"
        "stdout:\n${_stdout}\n"
        "stderr:\n${_stderr}")
  endif()
endfunction()

function(_configure_expect_failure case_name)
  set(_build_dir "${TEST_BINARY_ROOT}/${case_name}")
  execute_process(
      COMMAND ${CMAKE_COMMAND}
          -S "${TEST_TEMPLATE_SOURCE_DIR}"
          -B "${_build_dir}"
          -DCMAKE_BUILD_TYPE=RelWithDebInfo
          -DENABLE_CUDA=OFF
          -DENABLE_OPTIX=OFF
          -DENABLE_OPENGL=OFF
          -DENABLE_TBB=OFF
          -DENABLE_FETCH_CATCH2=OFF
          -Dtemplate_project_BUILD_PROGRAMS=OFF
          -Dtemplate_project_BUILD_EXAMPLES=OFF
          ${ARGN}
      RESULT_VARIABLE _result
      OUTPUT_VARIABLE _stdout
      ERROR_VARIABLE _stderr)

  if(_result EQUAL 0)
    message(FATAL_ERROR "Expected configure '${case_name}' to fail, but it passed.")
  endif()

endfunction()

file(REMOVE_RECURSE "${TEST_BINARY_ROOT}")
file(MAKE_DIRECTORY "${TEST_BINARY_ROOT}")

_configure_expect_success(
    tests_disabled_ignores_python_options
    -DENABLE_TESTS=OFF
    -DPYTHON_TEST_RUNNER=unsupported
    -DPYTHON_TEST_CONDA_ENV=env_name
    -DPYTHON_TEST_CONDA_PREFIX="${TEST_BINARY_ROOT}/fake_prefix")

_configure_expect_success(
    python_tests_disabled_ignores_python_options
    -DENABLE_TESTS=ON
    -DENABLE_PYTHON_TESTS=OFF
    -DPYTHON_TEST_RUNNER=unsupported
    -DPYTHON_TEST_CONDA_ENV=env_name
    -DPYTHON_TEST_CONDA_PREFIX="${TEST_BINARY_ROOT}/fake_prefix")

_configure_expect_failure(
    python_tests_enabled_rejects_conflicting_conda_options
    -DENABLE_TESTS=ON
    -DENABLE_PYTHON_TESTS=ON
    -DPYTHON_TEST_CONDA_ENV=env_name
    -DPYTHON_TEST_CONDA_PREFIX="${TEST_BINARY_ROOT}/fake_prefix")
