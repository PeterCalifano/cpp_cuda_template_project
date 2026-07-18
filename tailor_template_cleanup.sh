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
REMOVE_ROS2=0
TEMPORARY_PATHS=()

info() { printf '\033[34m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

cleanup_temporary_paths() {
    local temporary_path_

    for temporary_path_ in "${TEMPORARY_PATHS[@]}"; do
        if [[ -n "${temporary_path_}" ]]; then
            rm -f -- "${temporary_path_}" || true
        fi
    done
}

trap cleanup_temporary_paths EXIT

usage() {
    cat <<'EOF'
Usage:
  ./tailor_template_cleanup.sh --list
  ./tailor_template_cleanup.sh --apply [--yes] [--root <dir>] [--keep-profiling] [--remove-ros2]

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
  --remove-ros2   Remove the optional ROS 2 overlay. By default the overlay is kept.
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
    "doc/reports"
    "tests/cmake/AddMatlabWrapperRegressionTests.cmake"
    "tests/cmake/CheckTcmallocDependency.cmake"
    "tests/cmake/VerifyTemplateProjectAddTestsProperties.cmake"
    "tests/cmake/VerifyTemplateProjectBuildTreePackage.cmake"
    "tests/cmake/VerifyTemplateProjectCiWorkflowFlags.cmake"
    "tests/cmake/VerifyTemplateProjectCrossCompile.cmake"
    "tests/cmake/VerifyTemplateProjectCudaSources.cmake"
    "tests/cmake/VerifyTemplateProjectDocsStatic.cmake"
    "tests/cmake/VerifyTemplateProjectDocsWorkflow.cmake"
    "tests/cmake/VerifyTemplateProjectNestedDocsIsolation.cmake"
    "tests/cmake/VerifyTemplateProjectNoOptimization.cmake"
    "tests/cmake/VerifyTemplateProjectOptixInstallExport.cmake"
    "tests/cmake/VerifyTemplateProjectOptimizedFlags.cmake"
    "tests/cmake/VerifyTemplateProjectReleaseTagSync.cmake"
    "tests/cmake/VerifyTemplateProjectRos2Overlay.cmake"
    "tests/cmake/VerifyTemplateProjectTailoringScript.cmake"
    "tests/cmake/VerifyTemplateProjectVersionSideEffects.cmake"
    "tests/template_test/testRos2OverlayStatic.py"
    "tests/template_test/testWorkflowTemplates.py"
    "tests/matlab/RunTemplateWrapperRegression.m"
)

optional_paths=(
    "profiling"
)

project_workflow_names=(
    "build_linux.yml"
    "build_linux_cuda.yml"
    "docs_pages.yml"
    "build_ros2_overlay.yml"
)
project_workflow_marker="# project-ci-template: generic"

ros2_overlay_paths=(
    "ros2"
    "build_ros2.sh"
    "add_ros2_support.sh"
    "python/COLCON_IGNORE"
    "lib/COLCON_IGNORE"
    "examples/COLCON_IGNORE"
    "tests/COLCON_IGNORE"
    ".github/workflows/build_ros2_overlay.yml"
    ".github/workflows/build_ros2_overlay.yml.tpl"
    "doc/ros2_overlay.md"
    "tests/template_test/testRos2OverlayStatic.py"
)

ros2_overlay_doc_paths=(
    "README.md"
    "AGENTS.md"
    "CLAUDE.md"
    "doc/bootstrap_prompts.md"
    "doc/template_usage.md"
    "doc/versioning.md"
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

ROS 2 overlay:
  - ROS 2 overlay KEPT by default; pass --remove-ros2 to strip it.
EOF
    if ((REMOVE_ROS2)); then
        printf '  - --remove-ros2 is set; these paths will be removed when present:\n'
        for path_ in "${ros2_overlay_paths[@]}"; do
            printf '    - %s\n' "${path_}"
        done
    fi
    cat <<'EOF'

CMake edits made by --apply:
  - Remove the root CMake include/call for AddMatlabWrapperRegressionTests.cmake.
  - Replace tests/CMakeLists.txt template-validation registrations with the project unit-test section.
  - With --remove-ros2, strip <!-- ros2-overlay-begin/end --> fenced doc blocks.

Workflow edits made by --apply:
  - Materialize generic project CI workflows from the dormant *.yml.tpl files.
  - Remove active template-validation workflow content and all *.yml.tpl files.
  - With --remove-ros2, omit the runnable and dormant ROS 2 workflow.

Not removed:
  - cmake/, build_lib.sh, generate_version.sh, docs workflow files, issue forms, and docs guides.
  - src/utils/logging/ and doc/logging.md, because the logger is reusable project infrastructure.
  - tests/template_test and tests/template_fixtures, because they are starter project tests.
  - .devcontainer, .vscode, examples/, and toolchains, because they are reusable project infrastructure.
  - profiling/ only when --keep-profiling is set.
  - ROS 2 overlay files unless --remove-ros2 is set.
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
            --remove-ros2)
                REMOVE_ROS2=1
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

validate_workflow_templates() {
    local workflow_name_
    local active_workflow_
    local workflow_template_

    for workflow_name_ in "${project_workflow_names[@]}"; do
        active_workflow_="${ROOT_DIR}/.github/workflows/${workflow_name_}"
        workflow_template_="${active_workflow_}.tpl"

        if [[ -f "${workflow_template_}" ]]; then
            [[ -f "${active_workflow_}" ]] \
                || die "Generic workflow template has no active pair: .github/workflows/${workflow_name_}.tpl"
            grep -Fqx -- "${project_workflow_marker}" "${workflow_template_}" \
                || die "Generic workflow template is missing its ownership marker: .github/workflows/${workflow_name_}.tpl"
            continue
        fi

        if [[ -f "${active_workflow_}" ]]; then
            grep -Fqx -- "${project_workflow_marker}" "${active_workflow_}" \
                || die "Active template-validation workflow has no generic template: .github/workflows/${workflow_name_}"
            continue
        fi

        if ((REMOVE_ROS2)) && [[ "${workflow_name_}" == "build_ros2_overlay.yml" ]]; then
            continue
        fi

        die "Missing runnable workflow and generic template: .github/workflows/${workflow_name_}"
    done
}

materialize_project_workflows() {
    local workflow_name_
    local active_workflow_
    local workflow_template_
    local tmp_

    for workflow_name_ in "${project_workflow_names[@]}"; do
        if ((REMOVE_ROS2)) && [[ "${workflow_name_}" == "build_ros2_overlay.yml" ]]; then
            continue
        fi

        active_workflow_="${ROOT_DIR}/.github/workflows/${workflow_name_}"
        workflow_template_="${active_workflow_}.tpl"
        if [[ ! -f "${workflow_template_}" ]]; then
            [[ -f "${active_workflow_}" ]] \
                || die "Cannot materialize missing workflow: .github/workflows/${workflow_name_}"
            info "project workflow already materialized .github/workflows/${workflow_name_}"
            continue
        fi

        if ((APPLY)); then
            tmp_="$(mktemp "${active_workflow_}.tmp.XXXXXX")"
            TEMPORARY_PATHS+=("${tmp_}")
            cp -p -- "${workflow_template_}" "${tmp_}"
            chmod --reference="${workflow_template_}" "${tmp_}"
            mv -f -- "${tmp_}" "${active_workflow_}"
            rm -f -- "${workflow_template_}"
            info "materialized project workflow .github/workflows/${workflow_name_}"
        else
            info "would materialize project workflow .github/workflows/${workflow_name_}"
        fi
    done
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
        tmp_="$(mktemp "${cmakelists_}.tmp.XXXXXX")"
        TEMPORARY_PATHS+=("${tmp_}")
        awk '
            /^[[:space:]]*include\("\$\{CMAKE_CURRENT_SOURCE_DIR\}\/tests\/cmake\/AddMatlabWrapperRegressionTests.cmake"\)/ {next}
            /^[[:space:]]*add_template_matlab_wrapper_regression_tests\(\)/ {next}
            {print}
        ' "${cmakelists_}" > "${tmp_}"
        chmod --reference="${cmakelists_}" "${tmp_}"
        mv -f -- "${tmp_}" "${cmakelists_}"
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
        tmp_="$(mktemp "${tests_cmake_}.tmp.XXXXXX")"
        TEMPORARY_PATHS+=("${tmp_}")
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
add_subdirectory(template_cuda)  # CUDA-init fixture gate + placeholder (built only when ENABLE_CUDA)

# Add tests to build and register.
add_tests(${project_name} EXCLUDED_LIST TESTS_LIST ${CUDA_COMPILE_TARGET} CATCH2_TEST_PROPERTIES Catch2::Catch2WithMain)

# Make catch2 to search for tests
message(STATUS "List of test targets: ${TESTS_LIST}")
EOF
        } > "${tmp_}"
        chmod --reference="${tests_cmake_}" "${tmp_}"
        mv -f -- "${tmp_}" "${tests_cmake_}"
        info "patched tests/CMakeLists.txt"
    else
        info "would patch tests/CMakeLists.txt"
    fi
}

filter_ros2_overlay_doc() {
    local doc_file_="$1"

    awk '
        /<!--[[:space:]]*ros2-overlay-begin[[:space:]]*-->/ {
            if (in_ros2_overlay_) {
                exit 1
            }
            in_ros2_overlay_ = 1
            next
        }
        /<!--[[:space:]]*ros2-overlay-end[[:space:]]*-->/ {
            if (!in_ros2_overlay_) {
                exit 1
            }
            in_ros2_overlay_ = 0
            next
        }
        !in_ros2_overlay_ { print }
        END {
            if (in_ros2_overlay_) {
                exit 1
            }
        }
    ' "${doc_file_}"
}

validate_ros2_overlay_doc_fences() {
    local relative_path_
    local doc_file_

    ((REMOVE_ROS2)) || return 0

    for relative_path_ in "${ros2_overlay_doc_paths[@]}"; do
        doc_file_="${ROOT_DIR}/${relative_path_}"
        [[ -f "${doc_file_}" ]] || continue

        if ! filter_ros2_overlay_doc "${doc_file_}" > /dev/null; then
            die "Malformed ROS 2 overlay fence in ${relative_path_}"
        fi
    done
}

strip_ros2_overlay_doc_fences() {
    local relative_path_
    local doc_file_
    local tmp_

    ((REMOVE_ROS2)) || return

    for relative_path_ in "${ros2_overlay_doc_paths[@]}"; do
        doc_file_="${ROOT_DIR}/${relative_path_}"
        if [[ ! -f "${doc_file_}" ]]; then
            info "skip missing ${relative_path_}"
            continue
        fi

        if ! grep -q "<!-- ros2-overlay-begin -->" "${doc_file_}" && \
           ! grep -q "<!-- ros2-overlay-end -->" "${doc_file_}"; then
            info "no ROS 2 overlay fence in ${relative_path_}"
            continue
        fi

        if ((APPLY)); then
            tmp_="$(mktemp "${doc_file_}.tmp.XXXXXX")"
            TEMPORARY_PATHS+=("${tmp_}")
            if filter_ros2_overlay_doc "${doc_file_}" > "${tmp_}"; then
                chmod --reference="${doc_file_}" "${tmp_}"
                mv -f -- "${tmp_}" "${doc_file_}"
                info "stripped ROS 2 overlay fence from ${relative_path_}"
            else
                die "Malformed ROS 2 overlay fence in ${relative_path_}"
            fi
        else
            info "would strip ROS 2 overlay fence from ${relative_path_}"
        fi
    done
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
    validate_workflow_templates
    validate_ros2_overlay_doc_fences
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

    if ((REMOVE_ROS2)); then
        for path_ in "${ros2_overlay_paths[@]}"; do
            remove_path "${path_}"
        done
        strip_ros2_overlay_doc_fences
    else
        info "keeping ROS 2 overlay; pass --remove-ros2 to strip it"
    fi

    materialize_project_workflows

    patch_root_cmakelists
    patch_tests_cmakelists

    info "template cleanup complete"
}

main "$@"
