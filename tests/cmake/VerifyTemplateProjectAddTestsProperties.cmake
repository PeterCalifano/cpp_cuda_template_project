cmake_minimum_required(VERSION 3.24)   # CMP0054 NEW: quoted if() args are not re-dereferenced

# Regression test for resolve_catch2_test_properties() in cmake/cmake_utils.cmake.
#
# The add_tests() 5th argument selects the catch_discover_tests PROPERTIES. It may
# be a defined variable NAME (preferred idiom) or a literal value/list. Passing a
# literal LIST (e.g. "FIXTURES_REQUIRED;Optix") previously hard-errored at parse
# time because the list expanded to multiple tokens inside an if(DEFINED ${var})
# check ("Unknown arguments specified"). The resolver must accept both forms.

if(NOT DEFINED TEST_CMAKE_UTILS_FILE)
    message(FATAL_ERROR "Missing required variable: TEST_CMAKE_UTILS_FILE")
endif()
if(NOT EXISTS "${TEST_CMAKE_UTILS_FILE}")
    message(FATAL_ERROR "cmake_utils.cmake not found: ${TEST_CMAKE_UTILS_FILE}")
endif()

include("${TEST_CMAKE_UTILS_FILE}")

if(NOT COMMAND resolve_catch2_test_properties)
    message(FATAL_ERROR "resolve_catch2_test_properties() is not defined by ${TEST_CMAKE_UTILS_FILE}")
endif()

function(_expect label actual expected)
    if(NOT "${actual}" STREQUAL "${expected}")
        message(FATAL_ERROR "${label}: expected [${expected}], got [${actual}]")
    endif()
endfunction()

# 1) Literal list - the form that previously hard-errored at parse time.
resolve_catch2_test_properties(_out "FIXTURES_REQUIRED;Optix")
_expect("literal list" "${_out}" "FIXTURES_REQUIRED;Optix")

# 2) Defined variable NAME - dereferenced to its value.
set(MY_TEST_PROPS "LABELS;catch2;FIXTURES_REQUIRED;Cuda")
resolve_catch2_test_properties(_out "MY_TEST_PROPS")
_expect("variable name" "${_out}" "LABELS;catch2;FIXTURES_REQUIRED;Cuda")

# 3) Empty argument - resolves to empty.
resolve_catch2_test_properties(_out "")
_expect("empty" "${_out}" "")

# 4) Single-token literal that is not a defined variable - passed through.
resolve_catch2_test_properties(_out "DISABLED")
_expect("single-token literal" "${_out}" "DISABLED")

message(STATUS "resolve_catch2_test_properties: all cases passed")
