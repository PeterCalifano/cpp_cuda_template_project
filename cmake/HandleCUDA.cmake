# Function to detect the compute capability using nvidia-smi
function(detect_cuda_arch cuda_arch compute_cap)
    if(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
        execute_process(
            COMMAND nvidia-smi --query-gpu=compute_cap --format=csv,noheader
            OUTPUT_VARIABLE gpu_compute_caps
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        # Split each compute capability
        separate_arguments(gpu_compute_caps_list UNIX_COMMAND "${gpu_compute_caps}")
        set(sm_archs "")
        set(clean_caps "")

        # Map the compute capability to the correct architecture
        foreach(cap ${gpu_compute_caps_list})
            string(REPLACE "." "" sm "${cap}")
            list(APPEND sm_archs "sm_${sm}")
            list(APPEND clean_caps "${sm}")
        endforeach()

        if (NOT gpu_compute_caps_list)
            message(WARNING "No CUDA device was found on this machine. Returning empty capability list.")

            # Return empty
            set(${cuda_arch} "" PARENT_SCOPE)
            set(${compute_cap} "" PARENT_SCOPE)

        else()
            #######
            # BUG selection of a single device is required to avoid failure of the cmake function building the ptx. Need to fix it and allow both capabilities to be used. In principle, the code should be built for all compute capabilities but not sure how to do it now.
            list(GET clean_caps 0 clean_caps)
            list(GET sm_archs 0 sm_archs)
            #######

            string(JOIN " " final_arch "${sm_archs}")
            string(JOIN " " final_caps "${clean_caps}")

            set(${cuda_arch} "${final_arch}" PARENT_SCOPE)
            set(${compute_cap} "${final_caps}" PARENT_SCOPE)

            message(STATUS "Detected CUDA compute capabilities: ${gpu_compute_caps_list}")
            message(STATUS "Using CUDA architectures: ${final_arch}")
        endif()
    else()
        message(WARNING "CUDA architecture detection is not supported for this platform.")
    endif()
endfunction()