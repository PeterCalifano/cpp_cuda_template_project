# Add programs to build
set(EXAMPLES_PATTERN "*.cpp" "*.cu")
file(GLOB srcProgramsFiles RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ${EXAMPLES_PATTERN})
message(STATUS "Programs files found: ${srcProgramsFiles}")

# Exclude EXCLUDED_LIST from the list of examples
set(EXCLUDED_LIST "")
list(REMOVE_ITEM srcProgramsFiles ${EXCLUDED_LIST})

set(programs_targets "")

# Add to build and link
foreach(exampleFile ${srcProgramsFiles})

    get_filename_component(exampleName ${exampleFile} NAME_WE)
    add_executable(${exampleName} ${exampleFile})

    target_link_libraries(${exampleName} PRIVATE ${project_name} cuda_compile_settings)

    # Optionally add additional targets or properties if required
    set_target_properties(${exampleName} PROPERTIES OUTPUT_NAME "${exampleName}_program")

    # Collect target names for further processing
    list(APPEND programs_targets ${exampleName})

endforeach()

# Add install configuration
install(TARGETS ${programs_targets} 
        RUNTIME DESTINATION bin)