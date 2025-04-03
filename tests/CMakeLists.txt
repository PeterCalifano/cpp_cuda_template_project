# Basic usage of catch2 for build config:
# These tests can use the Catch2-provided main
#add_executable(tests test.cpp)
#target_link_libraries(tests PRIVATE Catch2::Catch2WithMain) 

# These tests need their own main
#add_executable(custom-main-tests test.cpp test-main.cpp)
#target_link_libraries(custom-main-tests PRIVATE Catch2::Catch2)

# Set additional properties for Catch2 test targets
set(CATCH2_TEST_PROPERTIES "--output-on-failure;--reporter=compact") 

# Exclude EXCLUDED_LIST from the list of tests
set(EXCLUDED_LIST "test_to_exclude")  # Specify files to exclude WE
set(TESTS_LIST "") 

# Add subdirectory 
add_subdirectory(template_test)

# Add tests to build
add_tests(${project_name} EXCLUDED_LIST TESTS_LIST cuda_compile_settings CATCH2_TEST_PROPERTIES)
set(TESTS_LIST ${TESTS_LIST} PARENT_SCOPE) # Export list of tests to parent scope (applied ONLY here)
