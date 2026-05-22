# Basic usage of catch2 for build config:
# These tests can use the Catch2-provided main
#add_executable(tests test.cpp)
#target_link_libraries(tests PRIVATE Catch2::Catch2WithMain) 

# These tests need their own main
#add_executable(custom-main-tests test.cpp test-main.cpp)
#target_link_libraries(custom-main-tests PRIVATE Catch2::Catch2)

# Set additional properties for Catch2 test targets
set(CATCH2_TEST_PROPERTIES "--output-on-failure;--reporter=compact") 
include(CTest)

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

# Exclude EXCLUDED_LIST from the list of tests
set(EXCLUDED_LIST "test_to_exclude")  # Specify files to exclude WE
set(TESTS_LIST "") 

# Include the content of the fixtures directory
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

if(Catch2_FOUND)
    # Add subdirectory
    add_subdirectory(template_test)
    add_subdirectory(template_fixtures)

    # Add tests to build
    add_tests(${project_name} EXCLUDED_LIST TESTS_LIST ${CUDA_COMPILE_TARGET} CATCH2_TEST_PROPERTIES Catch2::Catch2WithMain)
else()
    message(STATUS "Catch2 not found. Skipping Catch2 unit tests.")
endif()

# Make catch2 to search for tests
message(STATUS "List of test targets: ${TESTS_LIST}")
