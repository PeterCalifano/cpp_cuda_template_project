#!/usr/bin/env bash
# Remove template-development-only files after cloning this repository into a real project.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}"
APPLY=0
ASSUME_YES=0
LIST_ONLY=0
KEEP_PROFILING=0

info() { printf '\033[34m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage:
  ./tailor_template_cleanup.sh --list
  ./tailor_template_cleanup.sh --apply [--yes] [--root <dir>] [--keep-profiling]

Purpose:
  Remove files that are only useful while developing cpp_cuda_template_project
  itself, then patch CMake references to removed template-validation tests.

Options:
  --list          Print the cleanup list and exit.
  --apply         Remove files and patch CMake files.
  --yes           Do not prompt before applying.
  --root <dir>    Project root to clean. Defaults to the script directory.
  --keep-profiling
                  Keep profiling/ scripts. By default profiling/ is removed.
  -h, --help      Show this help.
EOF
}

template_development_paths=(
    "AGENTS.md"
    "CLAUDE.md"
    "CONTEXT.md"
    "TODO"
    "cpp_cuda_template_project.code-workspace"
    "doc/developments"
    "tests/cmake/AddMatlabWrapperRegressionTests.cmake"
    "tests/cmake/CheckTcmallocDependency.cmake"
    "tests/cmake/VerifyTemplateProjectCiWorkflowFlags.cmake"
    "tests/cmake/VerifyTemplateProjectCrossCompile.cmake"
    "tests/cmake/VerifyTemplateProjectDocsStatic.cmake"
    "tests/cmake/VerifyTemplateProjectDocsWorkflow.cmake"
    "tests/cmake/VerifyTemplateProjectNestedDocsIsolation.cmake"
    "tests/cmake/VerifyTemplateProjectNoOptimization.cmake"
    "tests/cmake/VerifyTemplateProjectOptimizedFlags.cmake"
    "tests/cmake/VerifyTemplateProjectTailoringScript.cmake"
    "tests/cmake/VerifyTemplateProjectVersionSideEffects.cmake"
    "tests/matlab/RunTemplateWrapperRegression.m"
)

optional_paths=(
    "profiling"
)

print_cleanup_list() {
    cat <<'EOF'
Template-development-only files/directories removed by --apply:
EOF
    for path_ in "${template_development_paths[@]}"; do
        printf '  - %s\n' "${path_}"
    done
    if ((KEEP_PROFILING)); then
        printf '  - profiling (kept because --keep-profiling is set)\n'
    else
        printf '  - profiling\n'
    fi
    cat <<'EOF'

CMake edits made by --apply:
  - Remove the root CMake include/call for AddMatlabWrapperRegressionTests.cmake.
  - Replace tests/CMakeLists.txt template-validation registrations with the project unit-test section.

Not removed:
  - cmake/, build_lib.sh, generate_version.sh, docs workflow files, issue forms, and docs guides.
  - tests/template_test and tests/template_fixtures, because they are starter project tests.
  - .devcontainer, .vscode, examples/, and toolchains, because they are reusable project infrastructure.
  - profiling/ only when --keep-profiling is set.
EOF
}

parse_args() {
    while (($# > 0)); do
        case "$1" in
            --list)
                LIST_ONLY=1
                shift
                ;;
            --apply)
                APPLY=1
                shift
                ;;
            --yes|-y)
                ASSUME_YES=1
                shift
                ;;
            --keep-profiling)
                KEEP_PROFILING=1
                shift
                ;;
            --root)
                [[ $# -ge 2 ]] || die "--root requires a directory"
                ROOT_DIR="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "Unknown argument: $1"
                ;;
        esac
    done
}

validate_root() {
    [[ -d "${ROOT_DIR}" ]] || die "Root directory does not exist: ${ROOT_DIR}"
    ROOT_DIR="$(cd "${ROOT_DIR}" && pwd)"
    [[ -f "${ROOT_DIR}/CMakeLists.txt" ]] || die "Missing CMakeLists.txt in root: ${ROOT_DIR}"
    [[ -f "${ROOT_DIR}/build_lib.sh" ]] || die "Missing build_lib.sh in root: ${ROOT_DIR}"
}

remove_path() {
    local relative_path_="$1"
    local absolute_path_="${ROOT_DIR}/${relative_path_}"

    if [[ ! -e "${absolute_path_}" && ! -L "${absolute_path_}" ]]; then
        info "skip missing ${relative_path_}"
        return
    fi

    if ((APPLY)); then
        rm -rf -- "${absolute_path_}"
        info "removed ${relative_path_}"
    else
        info "would remove ${relative_path_}"
    fi
}

patch_root_cmakelists() {
    local cmakelists_="${ROOT_DIR}/CMakeLists.txt"
    local tmp_

    if ! grep -q "AddMatlabWrapperRegressionTests.cmake\\|add_template_matlab_wrapper_regression_tests" "${cmakelists_}"; then
        info "root CMakeLists.txt has no template MATLAB regression hook"
        return
    fi

    if ((APPLY)); then
        tmp_="$(mktemp)"
        awk '
            /^[[:space:]]*include\("\$\{CMAKE_CURRENT_SOURCE_DIR\}\/tests\/cmake\/AddMatlabWrapperRegressionTests.cmake"\)/ {next}
            /^[[:space:]]*add_template_matlab_wrapper_regression_tests\(\)/ {next}
            {print}
        ' "${cmakelists_}" > "${tmp_}"
        mv "${tmp_}" "${cmakelists_}"
        info "patched CMakeLists.txt"
    else
        info "would patch CMakeLists.txt"
    fi
}

patch_tests_cmakelists() {
    local tests_cmake_="${ROOT_DIR}/tests/CMakeLists.txt"
    local tmp_

    [[ -f "${tests_cmake_}" ]] || {
        warn "tests/CMakeLists.txt not found; skipping test CMake patch"
        return
    }

    if ! grep -q "VerifyTemplateProject\\|template_project_.*flags\\|template_project_docs" "${tests_cmake_}"; then
        info "tests/CMakeLists.txt has no template validation registrations"
        return
    fi

    if ! grep -q "^# Exclude EXCLUDED_LIST" "${tests_cmake_}"; then
        warn "tests/CMakeLists.txt marker not found; skipping automatic patch"
        return
    fi

    if ((APPLY)); then
        tmp_="$(mktemp)"
        {
            cat <<'EOF'
# Project unit tests. Template-development validation tests were removed by tailor_template_cleanup.sh.
include(CTest)

# Exclude EXCLUDED_LIST from the list of tests
set(EXCLUDED_LIST "test_to_exclude")
set(TESTS_LIST "")

# Include the content of the fixtures directory
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

# Add subdirectories that may contain compiled and/or Python tests.
add_subdirectory(template_test)
add_subdirectory(template_fixtures)

# Add tests to build and register.
add_tests(${project_name} EXCLUDED_LIST TESTS_LIST ${CUDA_COMPILE_TARGET} CATCH2_TEST_PROPERTIES Catch2::Catch2WithMain)

# Make catch2 to search for tests
message(STATUS "List of test targets: ${TESTS_LIST}")
EOF
        } > "${tmp_}"
        mv "${tmp_}" "${tests_cmake_}"
        info "patched tests/CMakeLists.txt"
    else
        info "would patch tests/CMakeLists.txt"
    fi
}

confirm_apply() {
    ((APPLY)) || return
    ((ASSUME_YES)) && return

    printf 'Apply template cleanup to %s? Type "yes" to continue: ' "${ROOT_DIR}"
    read -r answer_
    [[ "${answer_}" == "yes" ]] || die "Aborted"
}

main() {
    parse_args "$@"

    if ((LIST_ONLY)); then
        print_cleanup_list
        exit 0
    fi

    if ((! APPLY)); then
        usage
        exit 1
    fi

    validate_root
    print_cleanup_list
    confirm_apply

    for path_ in "${template_development_paths[@]}"; do
        remove_path "${path_}"
    done
    if ((! KEEP_PROFILING)); then
        for path_ in "${optional_paths[@]}"; do
            remove_path "${path_}"
        done
    else
        info "keeping profiling/"
    fi

    patch_root_cmakelists
    patch_tests_cmakelists

    info "template cleanup complete"
}

main "$@"
