#!/usr/bin/env bash
# Verify that wrapper checkout maintenance is explicit and CMake-owned.

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
readonly REPO_ROOT
REAL_CMAKE="$(command -v cmake)"
readonly REAL_CMAKE
TEST_ROOT="$(mktemp -d)"
readonly TEST_ROOT
PASS_COUNT=0

cleanup() {
  if [[ -d "${TEST_ROOT}" ]]; then
    rm -rf -- "${TEST_ROOT}"
  fi
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '[PASS] %s\n' "$*"
}

assert_not_contains() {
  local file_path_="$1"
  local unexpected_text_="$2"
  local context_="$3"

  if grep -Fq -- "${unexpected_text_}" "${file_path_}"; then
    sed -n '1,240p' "${file_path_}" >&2
    fail "${context_}: found '${unexpected_text_}'"
  fi
}

assert_contains_once() {
  local file_path_="$1"
  local expected_text_="$2"
  local context_="$3"
  local match_count_

  match_count_="$(grep -Fxc -- "${expected_text_}" "${file_path_}" || true)"
  [[ "${match_count_}" == "1" ]] || {
    sed -n '1,240p' "${file_path_}" >&2
    fail "${context_}: expected one '${expected_text_}', found ${match_count_}"
  }
}

create_fixture() {
  FIXTURE_PROJECT="${TEST_ROOT}/project"
  FIXTURE_WRAP="${TEST_ROOT}/wrap"
  FAKE_BIN="${TEST_ROOT}/fake-bin"
  readonly FIXTURE_PROJECT FIXTURE_WRAP FAKE_BIN

  mkdir -p \
    "${FIXTURE_PROJECT}/src" \
    "${FIXTURE_WRAP}/cmake" \
    "${FIXTURE_WRAP}/.git" \
    "${FAKE_BIN}"
  cp "${REPO_ROOT}/build_lib.sh" "${FIXTURE_PROJECT}/build_lib.sh"
  touch "${FIXTURE_PROJECT}/src/wrap_interface.i"
  touch "${FIXTURE_WRAP}/cmake/PybindWrap.cmake"

  printf '%s\n' \
    'cmake_minimum_required(VERSION 3.15)' \
    'set(project_name "maintenance_fixture")' \
    'project(maintenance_fixture LANGUAGES NONE)' \
    >"${FIXTURE_PROJECT}/CMakeLists.txt"

  cat >"${FAKE_BIN}/cmake" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${1:-}" == "--version" ]]; then
  printf 'cmake version 3.28.3\n'
  exit 0
fi
if [[ "${1:-}" == "--build" ]]; then
  exit 0
fi

printf '%s\n' "$@" >>"${WRAPPER_CMAKE_LOG}"
EOF
  chmod +x "${FAKE_BIN}/cmake"

  cat >"${FAKE_BIN}/git" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >>"${WRAPPER_GIT_LOG}"
exit 0
EOF
  chmod +x "${FAKE_BIN}/git"
}

run_build_helper() {
  local build_name_="$1"
  shift

  : >"${WRAPPER_CMAKE_LOG}"
  : >"${WRAPPER_GIT_LOG}"
  PATH="${FAKE_BIN}:${PATH}" \
    WRAPPER_CMAKE_LOG="${WRAPPER_CMAKE_LOG}" \
    WRAPPER_GIT_LOG="${WRAPPER_GIT_LOG}" \
    bash "${FIXTURE_PROJECT}/build_lib.sh" \
      -B "${build_name_}" \
      -p \
      --gtwrap-root "${FIXTURE_WRAP}" \
      --skip-tests \
      "$@" \
      >/dev/null
}

test_default_is_non_mutating() {
  run_build_helper build_default

  [[ ! -s "${WRAPPER_GIT_LOG}" ]] || fail "default build invoked Git"
  assert_not_contains "${WRAPPER_CMAKE_LOG}" \
    '-DGTWRAP_MAINTENANCE_UPDATE=' 'default maintenance grant'
  assert_not_contains "${WRAPPER_CMAKE_LOG}" \
    '-DGTWRAP_SYNC_TO_MASTER=' 'default synchronization request'
  assert_not_contains "${WRAPPER_CMAKE_LOG}" \
    '-DGTWRAP_INIT_SUBMODULE_IF_MISSING=' 'default submodule request'
  assert_not_contains "${WRAPPER_CMAKE_LOG}" \
    '-DGTWRAP_ADD_SUBMODULE_IF_MISSING=' 'removed submodule-add request'
  pass 'default wrapper build passes no maintenance policy'
}

test_update_is_delegated_to_cmake() {
  run_build_helper build_update --wrap-update

  [[ ! -s "${WRAPPER_GIT_LOG}" ]] || fail "--wrap-update invoked Git directly"
  assert_contains_once "${WRAPPER_CMAKE_LOG}" \
    '-DGTWRAP_MAINTENANCE_UPDATE=ON' 'maintenance grant'
  assert_contains_once "${WRAPPER_CMAKE_LOG}" \
    '-DGTWRAP_SYNC_TO_MASTER=ON' 'synchronization request'
  assert_contains_once "${WRAPPER_CMAKE_LOG}" \
    '-DGTWRAP_BRANCH=master' 'maintenance branch'
  pass '--wrap-update delegates one explicit maintenance request to CMake'
}

test_declared_submodule_only() {
  local cmake_source_="${TEST_ROOT}/submodule-fixture"
  local cmake_build_="${TEST_ROOT}/submodule-build"

  mkdir -p "${cmake_source_}/project"
  touch "${cmake_source_}/project/.gitmodules"
  : >"${WRAPPER_GIT_LOG}"
  cat >"${cmake_source_}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.15)
project(wrapper_submodule_policy LANGUAGES NONE)
set(PROJECT_SOURCE_DIR "${cmake_source_}/project")
set(CMAKE_CURRENT_SOURCE_DIR "${cmake_source_}/project")
set(GTWRAP_ADD_SUBMODULE_IF_MISSING ON)
set(GTWRAP_SUBMODULE_PATH "lib/wrap")
set(GTWRAP_SUBMODULE_REPO "example.invalid/wrap.git")
include("${REPO_ROOT}/cmake/HandleWrapper.cmake")
maybe_init_wrap_submodule(_resolved_wrap_root)
EOF

  PATH="${FAKE_BIN}:${PATH}" \
    WRAPPER_GIT_LOG="${WRAPPER_GIT_LOG}" \
    "${REAL_CMAKE}" -S "${cmake_source_}" -B "${cmake_build_}" >/dev/null

  [[ ! -s "${WRAPPER_GIT_LOG}" ]] || {
    sed -n '1,240p' "${WRAPPER_GIT_LOG}" >&2
    fail 'undeclared wrapper submodule invoked Git'
  }
  pass 'wrapper initialization ignores undeclared submodules'
}

create_fixture
WRAPPER_CMAKE_LOG="${TEST_ROOT}/cmake.log"
WRAPPER_GIT_LOG="${TEST_ROOT}/git.log"
export WRAPPER_CMAKE_LOG WRAPPER_GIT_LOG

test_default_is_non_mutating
test_update_is_delegated_to_cmake
test_declared_submodule_only

printf '[SUMMARY] %d tests passed\n' "${PASS_COUNT}"
