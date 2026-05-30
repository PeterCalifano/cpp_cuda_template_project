cmake_minimum_required(VERSION 3.15)

if(NOT DEFINED TEST_TEMPLATE_SOURCE_DIR)
  message(FATAL_ERROR "Missing required variable: TEST_TEMPLATE_SOURCE_DIR")
endif()

set(_workflow_paths
    "${TEST_TEMPLATE_SOURCE_DIR}/.github/workflows/build_linux.yml"
    "${TEST_TEMPLATE_SOURCE_DIR}/.github/workflows/build_linux_cuda.yml")

foreach(_workflow_path IN LISTS _workflow_paths)
  if(NOT EXISTS "${_workflow_path}")
    message(FATAL_ERROR "Required CI workflow not found: ${_workflow_path}")
  endif()

  file(READ "${_workflow_path}" _workflow_contents)
  if(_workflow_contents MATCHES "CPU_ENABLE_NATIVE_TUNING=ON")
    message(FATAL_ERROR "CI workflow forces host-native CPU tuning: ${_workflow_path}")
  endif()

  if(NOT _workflow_contents MATCHES "CPU_ENABLE_NATIVE_TUNING=OFF")
    message(FATAL_ERROR "CI workflow must force portable CPU tuning: ${_workflow_path}")
  endif()

  if(NOT _workflow_contents MATCHES "command -v doxygen")
    message(FATAL_ERROR "CI workflow must validate Doxygen availability for docs CTests: ${_workflow_path}")
  endif()

  if(NOT _workflow_contents MATCHES "command -v dot")
    message(FATAL_ERROR "CI workflow must validate Graphviz dot availability for docs CTests: ${_workflow_path}")
  endif()
endforeach()

set(_linux_workflow "${TEST_TEMPLATE_SOURCE_DIR}/.github/workflows/build_linux.yml")
file(READ "${_linux_workflow}" _linux_workflow_contents)
if(NOT _linux_workflow_contents MATCHES "sudo apt install -y[^\n]*doxygen[^\n]*graphviz")
  message(FATAL_ERROR "GitHub-hosted Linux CI must install doxygen and graphviz for docs CTests.")
endif()
