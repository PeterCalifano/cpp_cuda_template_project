cmake_minimum_required(VERSION 3.15)

foreach(required_var
    TEST_TEMPLATE_SOURCE_DIR
    TEST_BINARY_ROOT
    TEST_CORE_TARGET
    TEST_CUDA_ARCHITECTURES)
  if(NOT DEFINED ${required_var})
    message(FATAL_ERROR "Missing required variable: ${required_var}")
  endif()
endforeach()

if(NOT EXISTS "${TEST_TEMPLATE_SOURCE_DIR}/CMakeLists.txt")
  message(FATAL_ERROR "Invalid template source dir: ${TEST_TEMPLATE_SOURCE_DIR}")
endif()

if(TEST_CUDA_ARCHITECTURES STREQUAL "")
  message(FATAL_ERROR "TEST_CUDA_ARCHITECTURES must contain at least one CUDA architecture")
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
set(_build_dir "${TEST_BINARY_ROOT}/build")

_run_step(
    "Configure isolated CUDA source build"
    ${CMAKE_COMMAND}
        -S "${TEST_TEMPLATE_SOURCE_DIR}"
        -B "${_build_dir}"
        -DCMAKE_BUILD_TYPE=RelWithDebInfo
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
        "-DCMAKE_CUDA_ARCHITECTURES=${TEST_CUDA_ARCHITECTURES}"
        -DCPU_ENABLE_NATIVE_TUNING=OFF
        -DENABLE_CUDA=ON
        -DENABLE_OPTIX=OFF
        -DENABLE_OPENGL=OFF
        -DENABLE_TBB=OFF
        -DENABLE_TESTS=OFF
        -DENABLE_FETCH_CATCH2=OFF
        -DENABLE_SPDLOG=OFF
        -DENABLE_FETCH_SPDLOG=OFF
        -Dtemplate_project_BUILD_PROGRAMS=OFF
        -Dtemplate_project_BUILD_EXAMPLES=OFF
        -Dtemplate_project_BUILD_PYTHON_WRAPPER=OFF
        -Dtemplate_project_BUILD_MATLAB_WRAPPER=OFF)

_run_step(
    "Build isolated CUDA core target"
    ${CMAKE_COMMAND}
        --build "${_build_dir}"
        --target "${TEST_CORE_TARGET}")

set(_compile_commands_path "${_build_dir}/compile_commands.json")
if(NOT EXISTS "${_compile_commands_path}")
  message(FATAL_ERROR "compile_commands.json not found: ${_compile_commands_path}")
endif()

file(READ "${_compile_commands_path}" _compile_commands)
string(REPLACE "\\" "/" _compile_commands "${_compile_commands}")

if(NOT _compile_commands MATCHES "src/template_src_kernels/placeholder\\.cu")
  message(FATAL_ERROR
      "CUDA was enabled, but src/template_src_kernels/placeholder.cu is absent "
      "from the isolated core target compile graph: ${_compile_commands_path}")
endif()

if(_compile_commands MATCHES "src/template_src_kernels/placeholder_to_ptx\\.ptx\\.cu")
  message(FATAL_ERROR
      "OptiX PTX input was compiled as an ordinary library translation unit while "
      "ENABLE_OPTIX=OFF: ${_compile_commands_path}")
endif()
