include_guard(GLOBAL)

function(handle_sanitizers)
    if(TARGET sanitizer_target_interface)
        return()
    endif()

    # Add sanitizer target if enabled
    add_library(sanitizer_target_interface INTERFACE)
    if(SANITIZE_BUILD AND SANITIZERS)
        target_compile_options(sanitizer_target_interface INTERFACE
            $<$<NOT:$<CONFIG:Release>>:-fsanitize=${SANITIZERS}>
        )
    endif()
endfunction()
