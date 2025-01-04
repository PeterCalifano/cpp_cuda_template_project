# Add config.h file to build
configure_file(config.h.in config.h)

# Add src files to library
set(SRC_PATTERN "*.cpp")
file(GLOB srcLibFiles RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ${SRC_PATTERN})
message("Library src files found: ${srcTestFiles}")

# Exclude EXCLUDED_LIST from the list of examples
set(EXCLUDED_LIST "")
list(REMOVE_ITEM srcLibFiles ${EXCLUDED_LIST})

# Add custom library
add_library(lib_name SHARED
            ${srcLibFiles})

# Link targets
target_include_directories(lib_name PUBLIC ${OpenCV_INCLUDE_DIRS} ${PROJECT_SOURCE_DIR} ${JSONCPP_INCLUDE_DIRS} )
target_link_libraries(lib_name PUBLIC ${OpenCV_LIBS} Eigen3::Eigen jsoncpp)

# Define INCLUDE_DIRECTORIES
set(lib_name_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR} PARENT_SCOPE)
