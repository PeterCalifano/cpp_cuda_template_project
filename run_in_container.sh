#!/usr/bin/env bash
# Launch a binary or command inside this repo's container image, built
# standalone from .devcontainer/Dockerfile (no VS Code / devcontainers CLI
# required). The repository is mounted at /workspace, so binaries built on
# the host (e.g. ./build/my_app) can be executed directly.
#
# Examples:
#   ./run_in_container.sh                          # interactive bash
#   ./run_in_container.sh ./build/my_app --flag    # run a binary
#   ./run_in_container.sh --build -- ctest --test-dir build
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_NAME="$(basename "$ROOT_DIR")"
IMAGE_TAG="$(echo "${REPO_NAME}" | tr '[:upper:]' '[:lower:]')-dev:latest"
ENGINE=""
FORCE_BUILD="no"
USE_GPU="yes"
CUDA_VERSION="12.9"

usage() {
  cat <<EOF
Usage: ./run_in_container.sh [options] [--] [command [args...]]

Runs a command inside the repo container image (default command: bash).
The image is built from .devcontainer/Dockerfile with INSTALL_CUDA=on the
first time (or when --build is given); the repo is mounted at /workspace.

Options:
  --build              Force (re)build of the image.
  --no-gpu             Do not request GPU access.
  --image <name>       Image tag (default: ${IMAGE_TAG}).
  --engine <e>         Container engine: docker or podman (default: autodetect).
  --cuda-version <v>   CUDA toolkit version build-arg (default: ${CUDA_VERSION}).
  -h, --help           Show this help.

GPU notes:
  - Docker: requires the NVIDIA Container Toolkit (uses --gpus all).
  - Podman: requires a CDI spec, e.g.
      sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
    (uses --device nvidia.com/gpu=all).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) FORCE_BUILD="yes" ;;
    --no-gpu) USE_GPU="no" ;;
    --image)
      shift
      IMAGE_TAG="${1:-}"
      [[ -n "$IMAGE_TAG" ]] || { echo "--image requires a value."; exit 1; }
      ;;
    --engine)
      shift
      ENGINE="${1:-}"
      case "$ENGINE" in
        docker|podman) ;;
        *) echo "--engine must be 'docker' or 'podman'."; exit 1 ;;
      esac
      ;;
    --cuda-version)
      shift
      CUDA_VERSION="${1:-}"
      [[ -n "$CUDA_VERSION" ]] || { echo "--cuda-version requires a value."; exit 1; }
      ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) break ;;
  esac
  shift
done

# Autodetect container engine
if [[ -z "$ENGINE" ]]; then
  if command -v docker >/dev/null 2>&1; then
    ENGINE="docker"
  elif command -v podman >/dev/null 2>&1; then
    ENGINE="podman"
  else
    echo "Neither docker nor podman found in PATH."
    exit 1
  fi
fi

# Build the image if missing or forced
need_build="$FORCE_BUILD"
if [[ "$need_build" != "yes" ]] && ! "$ENGINE" image inspect "$IMAGE_TAG" >/dev/null 2>&1; then
  need_build="yes"
fi
if [[ "$need_build" == "yes" ]]; then
  echo "Building image ${IMAGE_TAG} with ${ENGINE} (INSTALL_CUDA=on, CUDA ${CUDA_VERSION})..."
  "$ENGINE" build \
    --build-arg INSTALL_CUDA=on \
    --build-arg CUDA_VERSION="$CUDA_VERSION" \
    -t "$IMAGE_TAG" \
    "$ROOT_DIR/.devcontainer"
fi

# GPU flags per engine
gpu_args=()
if [[ "$USE_GPU" == "yes" ]]; then
  if [[ "$ENGINE" == "docker" ]]; then
    gpu_args=(--gpus all)
  else
    gpu_args=(--device nvidia.com/gpu=all --security-opt=label=disable)
  fi
fi

# Allocate a TTY only when attached to one
tty_args=()
if [[ -t 0 && -t 1 ]]; then
  tty_args=(-it)
fi

# Default command: interactive shell
if [[ $# -eq 0 ]]; then
  set -- bash
fi

exec "$ENGINE" run --rm "${tty_args[@]}" \
  "${gpu_args[@]}" \
  -v "$ROOT_DIR":/workspace \
  -w /workspace \
  -e DISPLAY="${DISPLAY:-}" \
  "$IMAGE_TAG" "$@"
