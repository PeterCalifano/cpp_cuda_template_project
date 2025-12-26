# CMake configuration to handle Catch2 testing framework
include_guard(GLOBAL)

if (ENABLE_TESTS)
  include(CTest)
  find_package(Catch2 3 QUIET)

  if(NOT Catch2_FOUND AND ENABLE_FETCH_CATCH2)
    message(STATUS "Catch2 not found. Will try to fetch it from GitHub...")
    # Try to see if git/network are available BEFORE calling FetchContent
    find_package(Git QUIET)
    if(NOT Git_FOUND)
      # Git not found, cannot check network
      message(WARNING "Git not found; cannot fetch Catch2. Tests will be disabled.")
      set(ENABLE_TESTS OFF CACHE BOOL "Build and run tests" FORCE)
    
      else()
      # Try checking network access to GitHub
        execute_process(
          COMMAND "${GIT_EXECUTABLE}" ls-remote https://github.com/catchorg/Catch2.git
          RESULT_VARIABLE _git_result
          OUTPUT_QUIET
          ERROR_QUIET
          TIMEOUT 10)

        if(_git_result EQUAL 0)
          # If network access is available, fetch Catch2
          include(FetchContent)
          FetchContent_Declare(
              catch2
              GIT_REPOSITORY https://github.com/catchorg/Catch2.git
              GIT_TAG        v3.8.1  # update as needed
          )
          FetchContent_MakeAvailable(catch2)

          # After FetchContent, Catch2 provides targets even if config lookup fails
          find_package(Catch2 3 CONFIG QUIET)
          if(TARGET Catch2::Catch2WithMain OR TARGET Catch2::Catch2)
            set(Catch2_FOUND TRUE)
          endif()

        else()
          # Network access fails
          message(WARNING "Cannot reach GitHub (no network or blocked). Catch2 not available; tests will be disabled.")
          set(ENABLE_TESTS OFF CACHE BOOL "Build and run tests" FORCE)
        endif()
      endif()
      
  elseif(NOT Catch2_FOUND AND NOT ENABLE_FETCH_CATCH2)
      message(STATUS "Catch2 not found and ENABLE_FETCH_CATCH2=OFF. Tests will be disabled.")
      set(ENABLE_TESTS OFF CACHE BOOL "Build and run tests" FORCE)
  endif()

  # Only add tests if we really have Catch2 (either found or fetched)
  if(ENABLE_TESTS AND Catch2_FOUND)
    include(Catch)  
    message(STATUS "Catch2 available: tests will be built.")
    # add_subdirectory(tests) or whatever you do:
    # add_executable(my_tests ...)
    # target_link_libraries(my_tests PRIVATE Catch2::Catch2WithMain)
  else()
      message(STATUS "Tests are disabled (Catch2 not available or ENABLE_TESTS=OFF).")
  endif()
else()
    message(STATUS "Tests are disabled and won't be built (ENABLE_TESTS=OFF).")
endif()
