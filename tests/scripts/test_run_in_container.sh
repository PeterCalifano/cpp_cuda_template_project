#!/usr/bin/env bash
# Validate container-launch arguments without requiring a daemon or image.

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
readonly REPO_ROOT
EXPECTED_PROJECT_SLUG="$(
  basename "${REPO_ROOT}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9_.-]+/-/g; s/^[._-]+//; s/[._-]+$//'
)"
readonly EXPECTED_PROJECT_SLUG
SCRIPT_PATH="${REPO_ROOT}/run_in_container.sh"
readonly SCRIPT_PATH
TEST_ROOT="$(mktemp -d)"
readonly TEST_ROOT
FAKE_BIN="${TEST_ROOT}/fake-bin"
ENGINE_LOG="${TEST_ROOT}/engine.log"
readonly FAKE_BIN ENGINE_LOG
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

assert_log_contains() {
  local expected_text_="$1"
  grep -Fqx -- "ARG ${expected_text_}" "${ENGINE_LOG}" || {
    sed -n '1,260p' "${ENGINE_LOG}" >&2
    fail "engine log does not contain argument '${expected_text_}'"
  }
}

assert_log_excludes() {
  local unexpected_text_="$1"
  if grep -Fqx -- "ARG ${unexpected_text_}" "${ENGINE_LOG}"; then
    sed -n '1,260p' "${ENGINE_LOG}" >&2
    fail "engine log unexpectedly contains argument '${unexpected_text_}'"
  fi
}

create_fake_engine() {
  mkdir -p "${FAKE_BIN}"
  cat >"${FAKE_BIN}/container-engine" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

printf 'CALL %s\n' "$(basename "$0")" >>"${CONTAINER_ENGINE_LOG}"
for argument_ in "$@"; do
  printf 'ARG %s\n' "${argument_}" >>"${CONTAINER_ENGINE_LOG}"
done

if [[ "${1:-}" == "info" ]]; then
  printf '%s\n' "${FAKE_PODMAN_ROOTLESS:-true}"
  exit 0
fi
if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
  exit 0
fi
if [[ "${1:-}" == "container" && "${2:-}" == "inspect" ]]; then
  exit 1
fi
if [[ "${1:-}" == "run" ]]; then
  if [[ "$*" == *'id -u vscode'* ]]; then
    printf '%s\n' "${FAKE_IMAGE_IDS}"
  elif [[ " $* " == *' --detach '* ]]; then
    printf 'fixture-container-id\n'
  fi
  exit 0
fi

exit 0
EOF
  chmod +x "${FAKE_BIN}/container-engine"
  ln -s container-engine "${FAKE_BIN}/docker"
  ln -s container-engine "${FAKE_BIN}/podman"
}

run_launcher() {
  : >"${ENGINE_LOG}"
  env -u SSH_AUTH_SOCK \
    PATH="${FAKE_BIN}:${PATH}" \
    CONTAINER_ENGINE_LOG="${ENGINE_LOG}" \
    FAKE_IMAGE_IDS="$(id -u):$(id -g)" \
    bash "${SCRIPT_PATH}" "$@" >/dev/null
}

test_docker_command_ownership() {
  run_launcher --engine docker --no-gpu -- printf fixture

  assert_log_contains run
  assert_log_contains "$(id -u):$(id -g)"
  assert_log_contains HOME=/tmp
  assert_log_contains "type=bind,source=${REPO_ROOT},target=/workspace"
  assert_log_excludes --gpus
  pass 'Docker command mode preserves host ownership without GPU flags'
}

test_podman_command_ownership() {
  run_launcher --engine podman -- printf fixture

  assert_log_contains --security-opt=label=disable
  assert_log_contains --userns=keep-id
  assert_log_contains nvidia.com/gpu=all
  assert_log_contains keep-groups
  pass 'rootless Podman command mode preserves ownership and GPU groups'
}

test_vscode_attachment_contract() {
  run_launcher --engine docker --no-gpu --vscode \
    --container-name fixture-vscode

  assert_log_contains --detach
  assert_log_contains fixture-vscode
  assert_log_contains vscode
  assert_log_contains \
    "type=bind,source=${REPO_ROOT},target=/workspaces/${EXPECTED_PROJECT_SLUG}"
  assert_log_contains /usr/bin/sleep
  assert_log_contains infinity
  pass 'VS Code mode starts a stable host-owned attachment container'
}

test_invalid_matlab_root_stops_before_engine() {
  local invalid_matlab_root_="${TEST_ROOT}/invalid-matlab"
  local output_file_="${TEST_ROOT}/invalid-matlab.out"

  mkdir -p "${invalid_matlab_root_}"
  : >"${ENGINE_LOG}"
  if env -u SSH_AUTH_SOCK \
       PATH="${FAKE_BIN}:${PATH}" \
       CONTAINER_ENGINE_LOG="${ENGINE_LOG}" \
       FAKE_IMAGE_IDS="$(id -u):$(id -g)" \
       bash "${SCRIPT_PATH}" --engine docker --matlab-root \
         "${invalid_matlab_root_}" -- true >"${output_file_}" 2>&1; then
    fail 'invalid MATLAB root unexpectedly succeeded'
  fi
  [[ ! -s "${ENGINE_LOG}" ]] || fail 'invalid MATLAB root invoked engine'
  grep -Fq 'extern/include/mex.h' "${output_file_}" || {
    sed -n '1,120p' "${output_file_}" >&2
    fail 'invalid MATLAB root produced no actionable diagnostic'
  }
  pass 'invalid MATLAB roots fail before container-engine access'
}

create_fake_engine
test_docker_command_ownership
test_podman_command_ownership
test_vscode_attachment_contract
test_invalid_matlab_root_stops_before_engine

printf '[SUMMARY] %d tests passed\n' "${PASS_COUNT}"
