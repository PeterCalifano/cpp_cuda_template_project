#!/usr/bin/env bash
set -euo pipefail

#
# @file run_gpu_profiling.sh
# @authors Pietro Califano (petercalifano.gs@gmail.com)
# @brief NVIDIA GPU profiling via Nsight Systems (nsys), Nsight Compute (ncu), or nvprof.
# @date 2025-07-24
#
# @copyright Copyright (C) 2021 DART Lab - Politecnico di Milano. All rights reserved.
#
# Tool selection (auto-detected or forced via --mode):
#   nsys   — Nsight Systems: system-level CPU+GPU timeline, API traces, memory transfers.
#             Output: .nsys-rep  → open with: nsys-ui
#   ncu    — Nsight Compute: per-kernel metrics (occupancy, memory BW, warp efficiency).
#             Output: .ncu-rep   → open with: ncu-ui (Nsight Compute GUI)
#   nvprof — Legacy profiler (deprecated in CUDA 12+, kept for backwards compatibility).
#             Output: .nvvp      → open with: nvvp (NVIDIA Visual Profiler)
#
# Install Nsight tools: https://developer.nvidia.com/nsight-systems
#                       https://developer.nvidia.com/nsight-compute
#

# Source common parser
source "$(dirname "$0")/common_parser.sh"

# Script-specific defaults
GPU_PROFILING_MODE="auto"   # auto | nsys | ncu | nvprof

function usage() {
    usage_parser
    echo "CUDA GPU Profiling Tool"
    echo ""
    echo "Profiles CUDA executables using NVIDIA Nsight Systems, Nsight Compute, or nvprof."
    echo "Tool is auto-detected unless --mode is specified."
    echo ""
    echo "Script-specific options:"
    echo "  --mode <mode>   Profiling mode: auto, nsys, ncu, nvprof (default: auto)"
    echo ""
    echo "Output files (per trial index N):"
    echo "  nsys:   nsys_profile.N.nsys-rep   → open with: nsys-ui"
    echo "          nsys_report.N.txt          (text stats)"
    echo "  ncu:    ncu_profile.N.ncu-rep      → open with: ncu-ui"
    echo "          ncu_report.N.txt            (text metrics)"
    echo "  nvprof: nvprof_profile.N.nvvp      → open with: nvvp"
    echo "          nvprof_report.N.txt         (text summary)"
    echo ""
}

function parse_specific_args() {
    parse_common_args "$@"
    set -- "${_remaining_args[@]}"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                if [[ -z "${2:-}" ]]; then
                    echo -e "\033[0;31mERROR: --mode requires an argument (auto|nsys|ncu|nvprof).\033[0m" >&2
                    exit 1
                fi
                GPU_PROFILING_MODE="$2"
                shift 2
                ;;
            *)
                echo -e "\033[38;5;208mParsing failure: not a valid option: $1\033[0m" >&2
                usage
                exit 1
                ;;
        esac
    done
}

# Detect the best available GPU profiling tool
function detect_gpu_tool() {
    local mode="$1"
    case "$mode" in
        auto)
            if   command -v nsys   >/dev/null 2>&1; then echo "nsys"
            elif command -v ncu    >/dev/null 2>&1; then echo "ncu"
            elif command -v nvprof >/dev/null 2>&1; then echo "nvprof"
            else echo ""
            fi
            ;;
        nsys|ncu|nvprof)
            if command -v "$mode" >/dev/null 2>&1; then echo "$mode"
            else echo ""
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

### Parse and validate arguments
parse_specific_args "$@"
validate_common_args
create_target_folder
build_execution_command

# Validate mode value
case "$GPU_PROFILING_MODE" in
    auto|nsys|ncu|nvprof) ;;
    *) echo -e "\033[0;31mERROR: Invalid --mode '$GPU_PROFILING_MODE'. Use: auto, nsys, ncu, nvprof.\033[0m" >&2; exit 1 ;;
esac

ACTIVE_TOOL="$(detect_gpu_tool "$GPU_PROFILING_MODE")"
if [[ -z "$ACTIVE_TOOL" ]]; then
    echo -e "\033[0;31mERROR: No GPU profiling tool found for mode '${GPU_PROFILING_MODE}'.\033[0m" >&2
    echo -e "\033[0;31m       Install Nsight Systems (nsys) or Nsight Compute (ncu) from:\033[0m" >&2
    echo -e "\033[0;31m       https://developer.nvidia.com/nsight-systems\033[0m" >&2
    exit 1
fi

echo -e "\033[1;34m[INFO] Starting GPU profiling tool...\033[0m"
echo -e "\033[1;36m[INFO] Profiling Configuration:\033[0m"
echo -e "\033[1;36m[INFO] - Target folder:     '$OUTPUT_FOLDER'\033[0m"
echo -e "\033[1;36m[INFO] - Number of trials:  $TRIALS_NUM\033[0m"
echo -e "\033[1;36m[INFO] - Starting index:    $CURRENT_INDEX\033[0m"
echo -e "\033[1;36m[INFO] - Execution command: '${EXEC_CMD_ARRAY[*]}'\033[0m"
echo -e "\033[1;36m[INFO] - Active GPU tool:   $ACTIVE_TOOL\033[0m"

for ((j=CURRENT_INDEX; j<CURRENT_INDEX+TRIALS_NUM; j++)); do
    echo -e "\033[1;33m[INFO] Running GPU profiling iteration $((j-CURRENT_INDEX+1)) of $TRIALS_NUM...\033[0m"

    case "$ACTIVE_TOOL" in
        nsys)
            OUTPUT_BASE="./$OUTPUT_FOLDER/nsys_profile.$j"
            "${_sudo[@]}" nsys profile \
                --output="$OUTPUT_BASE" \
                --stats=true \
                --force-overwrite=true \
                "${EXEC_CMD_ARRAY[@]}"

            echo -e "\033[1;32m[INFO] Generating nsys text report...\033[0m"
            # nsys-rep (CUDA 12+) or .qdrep (older)
            if [[ -f "${OUTPUT_BASE}.nsys-rep" ]]; then
                nsys stats "${OUTPUT_BASE}.nsys-rep" > "./$OUTPUT_FOLDER/nsys_report.$j.txt" 2>&1 || true
            elif [[ -f "${OUTPUT_BASE}.qdrep" ]]; then
                nsys stats "${OUTPUT_BASE}.qdrep"    > "./$OUTPUT_FOLDER/nsys_report.$j.txt" 2>&1 || true
            fi
            ;;

        ncu)
            OUTPUT_BASE="./$OUTPUT_FOLDER/ncu_profile.$j"
            "${_sudo[@]}" ncu \
                --set full \
                --output "$OUTPUT_BASE" \
                --force-overwrite \
                "${EXEC_CMD_ARRAY[@]}"

            echo -e "\033[1;32m[INFO] Generating ncu text report...\033[0m"
            ncu --import "${OUTPUT_BASE}.ncu-rep" > "./$OUTPUT_FOLDER/ncu_report.$j.txt" 2>&1 || true
            ;;

        nvprof)
            "${_sudo[@]}" nvprof \
                --log-file     "./$OUTPUT_FOLDER/nvprof_report.$j.txt" \
                --output-profile "./$OUTPUT_FOLDER/nvprof_profile.$j.nvvp" \
                "${EXEC_CMD_ARRAY[@]}"
            ;;
    esac
done

echo -e "\033[1;34m[INFO] GPU profiling completed.\033[0m"
echo -e "\033[1;36m[INFO] Results written to: ./$OUTPUT_FOLDER/\033[0m"
case "$ACTIVE_TOOL" in
    nsys)   echo -e "\033[1;36m[INFO] Open .nsys-rep with: nsys-ui ./$OUTPUT_FOLDER/nsys_profile.${CURRENT_INDEX}.nsys-rep\033[0m" ;;
    ncu)    echo -e "\033[1;36m[INFO] Open .ncu-rep with:  ncu-ui  (Nsight Compute GUI)\033[0m" ;;
    nvprof) echo -e "\033[1;36m[INFO] Open .nvvp with:     nvvp    (NVIDIA Visual Profiler, deprecated)\033[0m" ;;
esac
