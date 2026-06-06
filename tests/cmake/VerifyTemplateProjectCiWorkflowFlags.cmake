cmake_minimum_required(VERSION 3.15)

if(NOT DEFINED TEST_TEMPLATE_SOURCE_DIR)
  message(FATAL_ERROR "Missing required variable: TEST_TEMPLATE_SOURCE_DIR")
endif()

function(_assert_full_history_checkouts workflow_path)
  file(READ "${workflow_path}" _workflow_contents)
  string(REGEX MATCHALL "uses: actions/checkout@v[0-9]+" _checkout_uses "${_workflow_contents}")
  list(LENGTH _checkout_uses _checkout_count)
  if(_checkout_count EQUAL 0)
    message(FATAL_ERROR "Workflow has no checkout step: ${workflow_path}")
  endif()

  string(REGEX MATCHALL "fetch-depth:[ ]*0" _full_depth_settings "${_workflow_contents}")
  list(LENGTH _full_depth_settings _full_depth_count)
  if(NOT _full_depth_count EQUAL _checkout_count)
    message(FATAL_ERROR
        "Every checkout step must use fetch-depth: 0 so git tags are available "
        "for version resolution. Found ${_full_depth_count}/${_checkout_count} "
        "full-history checkout settings in ${workflow_path}")
  endif()
endfunction()

function(_assert_test_prerequisites workflow_path)
  file(READ "${workflow_path}" _workflow_contents)

  if(_workflow_contents MATCHES "ctest-extra|ctest_extra|CTEST_EXTRA")
    message(FATAL_ERROR "CI workflow must not use local-only CTest extra-args hooks: ${workflow_path}")
  endif()

  if(NOT _workflow_contents MATCHES "command -v python3")
    message(FATAL_ERROR "CI workflow must validate Python availability for pytest-backed CTest entries: ${workflow_path}")
  endif()

  if(NOT _workflow_contents MATCHES "python3 -m pytest --version")
    message(FATAL_ERROR "CI workflow must validate pytest availability for pytest-backed CTest entries: ${workflow_path}")
  endif()

  if(NOT _workflow_contents MATCHES "command -v doxygen")
    message(FATAL_ERROR "CI workflow must validate Doxygen availability for docs CTests: ${workflow_path}")
  endif()

  if(NOT _workflow_contents MATCHES "command -v dot")
    message(FATAL_ERROR "CI workflow must validate Graphviz dot availability for docs CTests: ${workflow_path}")
  endif()
endfunction()

set(_workflow_paths
    "${TEST_TEMPLATE_SOURCE_DIR}/.github/workflows/build_linux.yml"
    "${TEST_TEMPLATE_SOURCE_DIR}/.github/workflows/build_linux_cuda.yml")

foreach(_workflow_path IN LISTS _workflow_paths)
  if(NOT EXISTS "${_workflow_path}")
    message(FATAL_ERROR "Required CI workflow not found: ${_workflow_path}")
  endif()

  _assert_full_history_checkouts("${_workflow_path}")
  _assert_test_prerequisites("${_workflow_path}")

  file(READ "${_workflow_path}" _workflow_contents)
  if(_workflow_contents MATCHES "CPU_ENABLE_NATIVE_TUNING=ON")
    message(FATAL_ERROR "CI workflow forces host-native CPU tuning: ${_workflow_path}")
  endif()

  if(NOT _workflow_contents MATCHES "CPU_ENABLE_NATIVE_TUNING=OFF")
    message(FATAL_ERROR "CI workflow must force portable CPU tuning: ${_workflow_path}")
  endif()
endforeach()

set(_linux_workflow_paths
    "${TEST_TEMPLATE_SOURCE_DIR}/.github/workflows/build_linux.yml")

foreach(_workflow_path IN LISTS _linux_workflow_paths)
  file(READ "${_workflow_path}" _linux_workflow_contents)
  if(NOT _linux_workflow_contents MATCHES "sudo apt install -y[^\n]*python3-pytest[^\n]*doxygen[^\n]*graphviz")
    message(FATAL_ERROR
        "GitHub-hosted Linux CI must install python3-pytest, doxygen, and graphviz "
        "for pytest-backed and docs CTests: ${_workflow_path}")
  endif()
endforeach()
