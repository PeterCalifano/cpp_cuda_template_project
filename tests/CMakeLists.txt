# Basic usage of catch2 for build config:
# These tests can use the Catch2-provided main
#add_executable(tests test.cpp)
#target_link_libraries(tests PRIVATE Catch2::Catch2WithMain)

# These tests need their own main
#add_executable(custom-main-tests test.cpp test-main.cpp)
#target_link_libraries(custom-main-tests PRIVATE Catch2::Catch2)

include(CTest)

################################################################################
# CMake template development tests (remove for instantiation)
add_test(
    NAME template_project_no_optimization_flags
    COMMAND ${CMAKE_COMMAND}
        -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -DTEST_BINARY_ROOT=${PROJECT_BINARY_DIR}/no_optimization
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectNoOptimization.cmake
)
set_tests_properties(
    template_project_no_optimization_flags
    PROPERTIES
    LABELS "flags;noopt"
    TIMEOUT 180
)

add_test(
    NAME template_project_optimized_config_flags
    COMMAND ${CMAKE_COMMAND}
        -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -DTEST_BINARY_ROOT=${PROJECT_BINARY_DIR}/optimized_flags
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectOptimizedFlags.cmake
)
set_tests_properties(
    template_project_optimized_config_flags
    PROPERTIES
    LABELS "flags;optimized"
    TIMEOUT 180
)

add_test(
    NAME template_project_ci_workflow_cpu_flags
    COMMAND ${CMAKE_COMMAND}
        -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectCiWorkflowFlags.cmake
)
set_tests_properties(
    template_project_ci_workflow_cpu_flags
    PROPERTIES
    LABELS "flags;ci"
    TIMEOUT 60
)

add_test(
    NAME template_project_docs_static_contract
    COMMAND ${CMAKE_COMMAND}
        -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectDocsStatic.cmake
)
set_tests_properties(
    template_project_docs_static_contract
    PROPERTIES
    LABELS "docs;workflow;issues"
    TIMEOUT 60
)

add_test(
    NAME template_project_docs_build_output
    COMMAND ${CMAKE_COMMAND}
        -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -DTEST_BINARY_ROOT=${PROJECT_BINARY_DIR}/docs_workflow
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectDocsWorkflow.cmake
)
set_tests_properties(
    template_project_docs_build_output
    PROPERTIES
    LABELS "docs;doxygen"
    TIMEOUT 240
)

add_test(
    NAME template_project_nested_docs_isolation
    COMMAND ${CMAKE_COMMAND}
        -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -DTEST_BINARY_ROOT=${PROJECT_BINARY_DIR}/nested_docs_isolation
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectNestedDocsIsolation.cmake
)
set_tests_properties(
    template_project_nested_docs_isolation
    PROPERTIES
    LABELS "docs;nested"
    TIMEOUT 180
)

add_test(
    NAME template_project_nested_install_headers
    COMMAND ${CMAKE_COMMAND}
        -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -DTEST_BINARY_ROOT=${PROJECT_BINARY_DIR}/nested_install_headers
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectNestedInstallHeaders.cmake
)
set_tests_properties(
    template_project_nested_install_headers
    PROPERTIES
    LABELS "nested;install;template"
    TIMEOUT 240
)

add_test(
    NAME template_project_version_no_source_side_effect
    COMMAND ${CMAKE_COMMAND}
        -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -DTEST_BINARY_ROOT=${PROJECT_BINARY_DIR}/version_side_effect
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectVersionSideEffects.cmake
)
set_tests_properties(
    template_project_version_no_source_side_effect
    PROPERTIES
    LABELS "version;configure"
    TIMEOUT 180
)

add_test(
    NAME template_project_python_test_option_gates
    COMMAND ${CMAKE_COMMAND}
        -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -DTEST_BINARY_ROOT=${PROJECT_BINARY_DIR}/python_test_options
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectPythonTestOptions.cmake
)
set_tests_properties(
    template_project_python_test_option_gates
    PROPERTIES
    LABELS "tests;python"
    TIMEOUT 180
)

add_test(
    NAME template_project_build_tree_package_root
    COMMAND ${CMAKE_COMMAND}
        -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -DTEST_BINARY_ROOT=${PROJECT_BINARY_DIR}/build_tree_package
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectBuildTreePackage.cmake
)
set_tests_properties(
    template_project_build_tree_package_root
    PROPERTIES
    LABELS "package;template"
    TIMEOUT 180
)

add_test(
    NAME template_project_tailoring_cleanup_script
    COMMAND ${CMAKE_COMMAND}
        -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -DTEST_BINARY_ROOT=${PROJECT_BINARY_DIR}/tailoring_cleanup
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectTailoringScript.cmake
)
set_tests_properties(
    template_project_tailoring_cleanup_script
    PROPERTIES
    LABELS "tailoring;template"
    TIMEOUT 60
)

add_test(
    NAME template_project_add_tests_property_resolution
    COMMAND ${CMAKE_COMMAND}
        -DTEST_CMAKE_UTILS_FILE=${PROJECT_SOURCE_DIR}/cmake/cmake_utils.cmake
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectAddTestsProperties.cmake
)
set_tests_properties(
    template_project_add_tests_property_resolution
    PROPERTIES
    LABELS "tests;cmake_utils"
    TIMEOUT 60
)

add_test(
    NAME template_project_ros2_overlay_static_contract
    COMMAND ${CMAKE_COMMAND}
        -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -DTEST_BINARY_ROOT=${PROJECT_BINARY_DIR}/ros2_overlay
        -DEXPECTED_VERSION=${PROJECT_VERSION_CORE}
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectRos2Overlay.cmake
)
set_tests_properties(
    template_project_ros2_overlay_static_contract
    PROPERTIES
    LABELS "ros2;template"
    TIMEOUT 60
)

find_program(
    TEMPLATE_NVCC_EXECUTABLE
    NAMES nvcc
    PATHS
        "$ENV{CUDA_HOME}/bin"
        "$ENV{CUDA_PATH}/bin"
        "/usr/local/cuda/bin"
        "/usr/local/cuda-12.9/bin"
)

if(TEMPLATE_NVCC_EXECUTABLE)
    add_test(
        NAME template_project_cuda_without_catch2_configure
        COMMAND ${CMAKE_COMMAND}
            -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
            -DTEST_BINARY_ROOT=${PROJECT_BINARY_DIR}/cuda_without_catch2
            -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectCudaWithoutCatch2.cmake
    )
    set_tests_properties(
        template_project_cuda_without_catch2_configure
        PROPERTIES
        LABELS "cuda;catch2;configure"
        TIMEOUT 180
    )
else()
    message(STATUS "nvcc not found. Skipping CUDA-without-Catch2 configure regression test.")
endif()

find_program(TEMPLATE_AARCH64_GCC_EXECUTABLE NAMES aarch64-linux-gnu-gcc)
find_program(TEMPLATE_AARCH64_GXX_EXECUTABLE NAMES aarch64-linux-gnu-g++)
set(TEMPLATE_AARCH64_TOOLCHAIN_FILE "${PROJECT_SOURCE_DIR}/cmake/toolchains/defaults/aarch64-linux-gnu.cmake")

if(TEMPLATE_AARCH64_GCC_EXECUTABLE AND TEMPLATE_AARCH64_GXX_EXECUTABLE AND EXISTS "${TEMPLATE_AARCH64_TOOLCHAIN_FILE}")
    foreach(_cross_case IN ITEMS configure_flags install_consumer nested_consumer)
        add_test(
            NAME template_project_aarch64_cross_${_cross_case}
            COMMAND ${CMAKE_COMMAND}
                -DTEST_TEMPLATE_SOURCE_DIR=${PROJECT_SOURCE_DIR}
                -DTEST_BINARY_ROOT=${PROJECT_BINARY_DIR}/cross_compile/${_cross_case}
                -DTEST_TOOLCHAIN_FILE=${TEMPLATE_AARCH64_TOOLCHAIN_FILE}
                -DTEST_CASE=${_cross_case}
                -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyTemplateProjectCrossCompile.cmake
        )
    endforeach()

    set_tests_properties(
        template_project_aarch64_cross_configure_flags
        template_project_aarch64_cross_install_consumer
        template_project_aarch64_cross_nested_consumer
        PROPERTIES
        LABELS "cross;aarch64"
        TIMEOUT 180
    )
else()
    message(STATUS "aarch64-linux-gnu compilers not found. Skipping aarch64 cross-compilation regression tests.")
endif()

################################################################################

# Exclude EXCLUDED_LIST from the list of tests
set(EXCLUDED_LIST "test_to_exclude")  # Specify files to exclude WE
set(TESTS_LIST "")

# Include the content of the fixtures directory
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

# Add subdirectories that may contain compiled and/or Python tests.
add_subdirectory(template_test)
add_subdirectory(template_fixtures)
add_subdirectory(template_cuda)  # CUDA-init fixture gate + placeholder (built only when ENABLE_CUDA)

# Add tests to build and register.
add_tests(${project_name} EXCLUDED_LIST TESTS_LIST ${CUDA_COMPILE_TARGET} CATCH2_TEST_PROPERTIES Catch2::Catch2WithMain)

# Make catch2 to search for tests
message(STATUS "List of test targets: ${TESTS_LIST}")
