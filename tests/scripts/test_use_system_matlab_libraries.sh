#!/usr/bin/env bash
# Verify dry-run, privilege, backup, apply, restore, and discovery contracts
# against a disposable MATLAB-library fixture.

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
readonly REPO_ROOT
readonly SCRIPT_PATH="${REPO_ROOT}/scripts/use_system_matlab_libraries.sh"
TEST_ROOT="$(mktemp -d)"
readonly TEST_ROOT

PASS_COUNT=0

cleanup() {
  if [[ -n "${TEST_ROOT:-}" && -d "${TEST_ROOT}" ]]; then
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

assert_contains() {
  local haystack_="$1"
  local needle_="$2"
  local context_="$3"

  [[ "${haystack_}" == *"${needle_}"* ]] ||
    fail "${context_}: expected output to contain '${needle_}'"
}

assert_link_text() {
  local link_path_="$1"
  local expected_text_="$2"
  local actual_text_

  [[ -L "${link_path_}" ]] || fail "Expected symlink: ${link_path_}"
  actual_text_="$(readlink "${link_path_}")"
  [[ "${actual_text_}" == "${expected_text_}" ]] ||
    fail "${link_path_}: expected '${expected_text_}', got '${actual_text_}'"
}

run_expect_success() {
  local output_file_="$1"
  shift

  if ! "$@" >"${output_file_}" 2>&1; then
    sed -n '1,240p' "${output_file_}" >&2
    fail "Command unexpectedly failed: $*"
  fi
}

run_expect_failure() {
  local output_file_="$1"
  shift

  if "$@" >"${output_file_}" 2>&1; then
    sed -n '1,240p' "${output_file_}" >&2
    fail "Command unexpectedly succeeded: $*"
  fi
}

create_executable_() {
  local path_="$1"
  shift

  printf '%s\n' "$@" >"${path_}"
  chmod +x "${path_}"
}

setup_fixture() {
  FIXTURE_PREFIX="${TEST_ROOT}/MATLAB"
  FIXTURE_MATLAB_ROOT="${FIXTURE_PREFIX}/R2024b"
  FIXTURE_BIN="${TEST_ROOT}/fake-bin"
  FIXTURE_SYSTEM_LIB="${TEST_ROOT}/system-lib"

  mkdir -p \
    "${FIXTURE_MATLAB_ROOT}/bin/glnxa64" \
    "${FIXTURE_MATLAB_ROOT}/sys/os/glnxa64/orig" \
    "${FIXTURE_MATLAB_ROOT}/toolbox/compiler_sdk/runtime/glnxa64" \
    "${FIXTURE_BIN}" \
    "${FIXTURE_SYSTEM_LIB}"

  create_executable_ "${FIXTURE_MATLAB_ROOT}/bin/matlab" \
    '#!/usr/bin/env bash' \
    'exit 0'
  ln -s "${FIXTURE_MATLAB_ROOT}/bin/matlab" "${FIXTURE_BIN}/matlab"

  touch \
    "${FIXTURE_MATLAB_ROOT}/sys/os/glnxa64/libstdc++.so.6.0.30" \
    "${FIXTURE_MATLAB_ROOT}/bin/glnxa64/libopencv_core.so.4.7.0" \
    "${FIXTURE_MATLAB_ROOT}/bin/glnxa64/libopencv_imgproc.so.4.7.0" \
    "${FIXTURE_SYSTEM_LIB}/libstdc++.so.6.0.35" \
    "${FIXTURE_SYSTEM_LIB}/libopencv_core.so.4.10.0" \
    "${FIXTURE_SYSTEM_LIB}/libopencv_imgproc.so.4.10.0"

  ln -s 'libstdc++.so.6.0.30' \
    "${FIXTURE_MATLAB_ROOT}/sys/os/glnxa64/libstdc++.so.6"
  ln -s 'libstdc++.so.6.0.30' \
    "${FIXTURE_MATLAB_ROOT}/sys/os/glnxa64/orig/libstdc++.so.6"
  ln -s 'libstdc++.so.6.0.30' \
    "${FIXTURE_MATLAB_ROOT}/toolbox/compiler_sdk/runtime/glnxa64/libstdc++.so.6"
  ln -s 'libopencv_core.so.4.7.0' \
    "${FIXTURE_MATLAB_ROOT}/bin/glnxa64/libopencv_core.so.407"
  ln -s 'libopencv_imgproc.so.4.7.0' \
    "${FIXTURE_MATLAB_ROOT}/bin/glnxa64/libopencv_imgproc.so.407"

  # The single-quoted strings are the literal source of the generated shim.
  # shellcheck disable=SC2016
  create_executable_ "${FIXTURE_BIN}/id" \
    '#!/usr/bin/env bash' \
    'if [[ "${1:-}" == "-u" ]]; then' \
    '  printf "%s\\n" "${FAKE_ID_UID:-1000}"' \
    'else' \
    '  /usr/bin/id "$@"' \
    'fi'

  # shellcheck disable=SC2016
  create_executable_ "${FIXTURE_BIN}/ldconfig" \
    '#!/usr/bin/env bash' \
    'printf "3 libs found in cache\\n"' \
    'printf "\\tlibstdc++.so.6 (libc6,x86-64) => %s/libstdc++.so.6.0.35\\n" "${FAKE_SYSTEM_LIB}"' \
    'printf "\\tlibopencv_core.so (libc6,x86-64) => %s/libopencv_core.so.4.10.0\\n" "${FAKE_SYSTEM_LIB}"' \
    'printf "\\tlibopencv_imgproc.so (libc6,x86-64) => %s/libopencv_imgproc.so.4.10.0\\n" "${FAKE_SYSTEM_LIB}"'

  # shellcheck disable=SC2016
  create_executable_ "${FIXTURE_BIN}/file" \
    '#!/usr/bin/env bash' \
    'printf "%s: ELF 64-bit LSB shared object, x86-64\\n" "${@: -1}"'

  # shellcheck disable=SC2016
  create_executable_ "${FIXTURE_BIN}/readelf" \
    '#!/usr/bin/env bash' \
    'case "${@: -1}" in' \
    '  *libstdc++*) soname_="libstdc++.so.6" ;;' \
    '  *libopencv_core*) soname_="libopencv_core.so.410" ;;' \
    '  *libopencv_imgproc*) soname_="libopencv_imgproc.so.410" ;;' \
    '  *) exit 1 ;;' \
    'esac' \
    'printf " 0x000000000000000e (SONAME) Library soname: [%s]\\n" "${soname_}"'
}

main() {
  local output_file_="${TEST_ROOT}/command-output.txt"
  local output_

  setup_fixture

  run_expect_failure "${output_file_}" bash "${SCRIPT_PATH}" --matlab-root "${FIXTURE_MATLAB_ROOT}"
  output_="$(<"${output_file_}")"
  assert_contains "${output_}" 'Select at least one library family' 'selector guard'
  pass 'requires an explicit library selector'

  run_expect_success "${output_file_}" env \
    PATH="${FIXTURE_BIN}:/usr/bin:/bin" \
    FAKE_SYSTEM_LIB="${FIXTURE_SYSTEM_LIB}" \
    bash "${SCRIPT_PATH}" --matlab-version R2024b \
      --matlab-prefix "${FIXTURE_PREFIX}" --all
  output_="$(<"${output_file_}")"
  assert_contains "${output_}" '[DRY-RUN]' 'dry-run mode'
  assert_contains "${output_}" 'OpenCV SONAME change: 407 -> 410' 'OpenCV mismatch warning'
  assert_contains "${output_}" '[CMD] ldconfig -p' 'command logging'
  assert_contains "${output_}" '[EXIT] 0' 'command exit logging'
  assert_link_text "${FIXTURE_MATLAB_ROOT}/sys/os/glnxa64/libstdc++.so.6" 'libstdc++.so.6.0.30'
  assert_link_text "${FIXTURE_MATLAB_ROOT}/bin/glnxa64/libopencv_core.so.407" 'libopencv_core.so.4.7.0'
  pass 'dry-run plans all selected replacements without mutation'

  run_expect_failure "${output_file_}" env \
    PATH="${FIXTURE_BIN}:/usr/bin:/bin" \
    FAKE_SYSTEM_LIB="${FIXTURE_SYSTEM_LIB}" \
    FAKE_ID_UID=1000 \
    bash "${SCRIPT_PATH}" --matlab-root "${FIXTURE_MATLAB_ROOT}" --all --apply
  output_="$(<"${output_file_}")"
  assert_contains "${output_}" 'sudo' 'root guard'
  assert_link_text "${FIXTURE_MATLAB_ROOT}/sys/os/glnxa64/libstdc++.so.6" 'libstdc++.so.6.0.30'
  pass 'apply refuses to mutate without root'

  run_expect_success "${output_file_}" env \
    PATH="${FIXTURE_BIN}:/usr/bin:/bin" \
    FAKE_SYSTEM_LIB="${FIXTURE_SYSTEM_LIB}" \
    FAKE_ID_UID=0 \
    bash "${SCRIPT_PATH}" --matlab-root "${FIXTURE_MATLAB_ROOT}" --all --apply
  assert_link_text "${FIXTURE_MATLAB_ROOT}/sys/os/glnxa64/libstdc++.so.6" \
    "${FIXTURE_SYSTEM_LIB}/libstdc++.so.6.0.35"
  assert_link_text "${FIXTURE_MATLAB_ROOT}/toolbox/compiler_sdk/runtime/glnxa64/libstdc++.so.6" \
    "${FIXTURE_SYSTEM_LIB}/libstdc++.so.6.0.35"
  assert_link_text "${FIXTURE_MATLAB_ROOT}/sys/os/glnxa64/orig/libstdc++.so.6" \
    'libstdc++.so.6.0.30'
  assert_link_text "${FIXTURE_MATLAB_ROOT}/bin/glnxa64/libopencv_core.so.407" \
    "${FIXTURE_SYSTEM_LIB}/libopencv_core.so.4.10.0"
  assert_link_text "${FIXTURE_MATLAB_ROOT}/sys/os/glnxa64/libstdc++.so.6.matlab-backup" \
    'libstdc++.so.6.0.30'
  assert_link_text "${FIXTURE_MATLAB_ROOT}/bin/glnxa64/libopencv_core.so.407.matlab-backup" \
    'libopencv_core.so.4.7.0'
  pass 'apply replaces selected links and preserves one-time backups'

  run_expect_success "${output_file_}" env \
    PATH="${FIXTURE_BIN}:/usr/bin:/bin" \
    FAKE_SYSTEM_LIB="${FIXTURE_SYSTEM_LIB}" \
    FAKE_ID_UID=0 \
    bash "${SCRIPT_PATH}" --matlab-root "${FIXTURE_MATLAB_ROOT}" --all --apply
  output_="$(<"${output_file_}")"
  assert_contains "${output_}" '[UNCHANGED]' 'idempotent apply'
  pass 'repeated apply is idempotent'

  run_expect_success "${output_file_}" env \
    PATH="${FIXTURE_BIN}:/usr/bin:/bin" \
    FAKE_SYSTEM_LIB="${FIXTURE_SYSTEM_LIB}" \
    FAKE_ID_UID=0 \
    bash "${SCRIPT_PATH}" --matlab-root "${FIXTURE_MATLAB_ROOT}" --all --restore
  assert_link_text "${FIXTURE_MATLAB_ROOT}/sys/os/glnxa64/libstdc++.so.6" 'libstdc++.so.6.0.30'
  assert_link_text "${FIXTURE_MATLAB_ROOT}/toolbox/compiler_sdk/runtime/glnxa64/libstdc++.so.6" \
    'libstdc++.so.6.0.30'
  assert_link_text "${FIXTURE_MATLAB_ROOT}/bin/glnxa64/libopencv_core.so.407" \
    'libopencv_core.so.4.7.0'
  [[ -L "${FIXTURE_MATLAB_ROOT}/bin/glnxa64/libopencv_core.so.407.matlab-backup" ]] ||
    fail 'Restore removed the recovery backup'
  pass 'restore reinstates exact original link text and retains backups'

  run_expect_success "${output_file_}" env \
    PATH="${FIXTURE_BIN}:/usr/bin:/bin" \
    FAKE_SYSTEM_LIB="${FIXTURE_SYSTEM_LIB}" \
    bash "${SCRIPT_PATH}" --libstdcxx
  output_="$(<"${output_file_}")"
  assert_contains "${output_}" "MATLAB root: ${FIXTURE_MATLAB_ROOT}" 'PATH autodetection'
  pass 'autodetects MATLAB from PATH'

  printf '[SUMMARY] %d tests passed\n' "${PASS_COUNT}"
}

main "$@"
