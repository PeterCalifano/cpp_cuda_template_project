# CMake configuration to extract version information from Git tags

function(get_version_from_git)
    find_package(Git QUIET)
    if(NOT Git_FOUND)
        message(WARNING "Git not found")
        return()
    endif()

    execute_process(
        COMMAND ${GIT_EXECUTABLE} describe --tags --always
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_TAG
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE GIT_RESULT
    )

    if(NOT GIT_RESULT EQUAL 0)
        message(WARNING "Failed to get git tag")
        return()
    endif()

    execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse --short=7 HEAD
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_COMMIT_SHORT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    string(REGEX REPLACE "^v" "" CLEAN_TAG "${GIT_TAG}")
    if(CLEAN_TAG MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)(-.*)?$")

        set(PROJECT_VERSION_MAJOR ${CMAKE_MATCH_1})
        set(PROJECT_VERSION_MAJOR ${CMAKE_MATCH_1} PARENT_SCOPE)
        set(PROJECT_VERSION_MINOR ${CMAKE_MATCH_2})
        set(PROJECT_VERSION_MINOR ${CMAKE_MATCH_2} PARENT_SCOPE)
        set(PROJECT_VERSION_PATCH ${CMAKE_MATCH_3})
        set(PROJECT_VERSION_PATCH ${CMAKE_MATCH_3} PARENT_SCOPE)

        set(FULL_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}+${GIT_COMMIT_SHORT_HASH}")
        set(FULL_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}+${GIT_COMMIT_SHORT_HASH}" PARENT_SCOPE)
        set(PROJECT_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}") 
        set(PROJECT_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}" PARENT_SCOPE)
    else()
        message(WARNING "Tag '${CLEAN_TAG}' does not match semver format")
    endif()
endfunction()

function (compose_version_string OUT_VAR)

    # Compose version string from major, minor, patch
    set(VERSION_STRING "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")
    set(STRING_TO_WRITE "Project version: ${VERSION_STRING}\n")

    # If FULL_VERSION is defined, append it
    if(DEFINED FULL_VERSION)
        set(STRING_TO_WRITE "${STRING_TO_WRITE}Full version: ${FULL_VERSION}\n")
    endif()

    set(${OUT_VAR} "${STRING_TO_WRITE}" PARENT_SCOPE)
endfunction()

# Function to write VERSION file in binary directory
function (write_build_VERSION_file)
    # Set target file name
    set(VERSION_FILE_PATH "${CMAKE_BINARY_DIR}/VERSION")

    # Get string to write
    set(STRING_TO_WRITE "")
    compose_version_string(STRING_TO_WRITE)
    file(WRITE "${VERSION_FILE_PATH}" "${STRING_TO_WRITE}\n")

endfunction()

# Function to write VERSION file in source directory
function (write_source_VERSION_file)
    # Set target file name
    set(VERSION_FILE_PATH "${CMAKE_SOURCE_DIR}/VERSION")
    # Get string to write
    set(STRING_TO_WRITE "")
    compose_version_string(STRING_TO_WRITE)
    file(WRITE "${VERSION_FILE_PATH}" "${STRING_TO_WRITE}\n")
endfunction()

# Function to write VERSION file in install directory
function (write_install_VERSION_file)
    # Set target file name
    set(VERSION_FILE_PATH "${CMAKE_INSTALL_PREFIX}/VERSION")
    # Get string to write
    set(STRING_TO_WRITE "")
    compose_version_string(STRING_TO_WRITE)
    file(WRITE "${VERSION_FILE_PATH}" "${STRING_TO_WRITE}\n")
endfunction()

