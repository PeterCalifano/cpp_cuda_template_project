#!/usr/bin/env python3
"""Regenerate .devcontainer/devcontainer.json from environment options.

Merge-preserve behaviour: the existing devcontainer.json (if any) is loaded
first and only the keys managed by this script are rewritten. Everything else
(remoteEnv extras such as OPTIX_HOME, customizations settings, mounts, ...) is
kept verbatim, so re-running the configure script never wipes project-specific
settings. The default VS Code extension set (DEFAULT_EXTENSIONS) is seeded and
guaranteed present, while any extra extensions in the file are preserved.
Output is plain JSON (JSONC comments in the input are stripped).
"""
import json
import os
import re
import sys

DEFAULT_CUDA_VERSION = "12.9"

# remoteEnv entries owned by the CUDA option.
CUDA_REMOTE_ENV = {
    "PATH": "/usr/local/cuda/bin:${containerEnv:PATH}",
    "LD_LIBRARY_PATH": "/usr/local/cuda/lib64:${containerEnv:LD_LIBRARY_PATH}",
    "CUDA_HOME": "/usr/local/cuda",
}

# containerEnv entries owned by the ROS option.
ROS_CONTAINER_ENV = {
    "ROS_LOCALHOST_ONLY": "1",
    "ROS_DOMAIN_ID": "42",
}

CUDA_FEATURE_KEY = "ghcr.io/devcontainers/features/nvidia-cuda:2"

# Default VS Code extensions seeded into customizations.vscode.extensions.
# Managed like the conda/python features: regeneration guarantees these are
# present (even from scratch), while any extra extensions already in the file
# are preserved. Edit this list to change the template's editor defaults.
DEFAULT_EXTENSIONS = [
    "ms-vscode.cpptools",
    "ms-vscode.cpptools-themes",
    "ms-vscode.cmake-tools",
    "twxs.cmake",
    "njpwerner.autodocstring",
    "ms-python.autopep8",
    "ms-python.vscode-pylance",
    "ms-vscode.cpp-devtools",
    "Anthropic.claude-code",
    "ms-python.debugpy",
    "openai.chatgpt",
    "Gruntfuggly.todo-tree",
    "ms-vscode.cpptools-extension-pack",
    "ms-python.python",
    "donjayamanne.python-extension-pack",
    "llvm-vs-code-extensions.vscode-clangd",
]


def load_existing(path: str) -> dict:
    """Load an existing devcontainer.json, tolerating JSONC line comments."""
    if not os.path.isfile(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    # Strip // line comments (not inside strings: comments in devcontainer
    # templates always start the line or follow whitespace).
    text = re.sub(r"^\s*//.*$", "", text, flags=re.MULTILINE)
    # Strip trailing commas before } or ] left behind by comment removal.
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    text = text.strip()
    if not text:
        return {}
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        print(
            f"update_devcontainer_json.py: cannot parse existing {path}: {exc}",
            file=sys.stderr,
        )
        sys.exit(1)


def main() -> int:
    # Options come from the configure script via environment variables.
    cuda = os.environ.get("CUDA", "off")
    cuda_version = os.environ.get("CUDA_VERSION", DEFAULT_CUDA_VERSION)
    ros_mode = os.environ.get("ROS_MODE", "none")
    ros_distro = os.environ.get("ROS_DISTRO", "")
    ros_profile = os.environ.get("ROS_PROFILE", "ros-base")
    existing_path = os.environ.get(
        "DEVCONTAINER_JSON_PATH",
        os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "devcontainer.json"),
    )

    data = load_existing(existing_path)

    data.setdefault("name", "C++")

    # Managed: build (dockerfile + ROS build args)
    build = data.get("build", {})
    if not isinstance(build, dict):
        build = {}
    build["dockerfile"] = "Dockerfile"
    if ros_mode != "none":
        build["args"] = {
            "ROS_MODE": ros_mode,
            "ROS_DISTRO": ros_distro,
            "ROS_PROFILE": ros_profile,
        }
    else:
        build.pop("args", None)
    data["build"] = build

    # Managed: features (conda + python always; nvidia-cuda when CUDA=on)
    features = data.get("features", {})
    if not isinstance(features, dict):
        features = {}
    features["ghcr.io/devcontainers/features/conda:1"] = {
        "addCondaForge": True,
        "version": "latest",
    }
    features["ghcr.io/devcontainers/features/python:1"] = {
        "installTools": True,
        "enableShared": True,
        "version": "3.12",
    }
    if cuda == "on":
        features[CUDA_FEATURE_KEY] = {
            "installCudnn": True,
            "installCudnnDev": True,
            "installNvtx": True,
            "installToolkit": True,
            "cudaVersion": cuda_version,
            "cudnnVersion": "automatic",
        }
    else:
        features.pop(CUDA_FEATURE_KEY, None)
    # Sorted for stable output regardless of option toggling history.
    data["features"] = dict(sorted(features.items()))

    # Managed: runArgs --gpus all (CUDA only); other runArgs preserved.
    run_args = [a for a in data.get(
        "runArgs", []) if a not in ("--gpus", "all")]
    if cuda == "on":
        run_args = ["--gpus", "all"] + run_args
    if run_args:
        data["runArgs"] = run_args
    else:
        data.pop("runArgs", None)

    # Managed: CUDA entries in remoteEnv; unrelated entries preserved.
    remote_env = data.get("remoteEnv", {})
    if not isinstance(remote_env, dict):
        remote_env = {}
    if cuda == "on":
        remote_env.update(CUDA_REMOTE_ENV)
    else:
        for key in CUDA_REMOTE_ENV:
            remote_env.pop(key, None)
    if remote_env:
        data["remoteEnv"] = remote_env
    else:
        data.pop("remoteEnv", None)

    # Managed: ROS entries in containerEnv; unrelated entries preserved.
    container_env = data.get("containerEnv", {})
    if not isinstance(container_env, dict):
        container_env = {}
    if ros_mode != "none":
        container_env.update(ROS_CONTAINER_ENV)
    else:
        for key in ROS_CONTAINER_ENV:
            container_env.pop(key, None)
    if container_env:
        data["containerEnv"] = container_env
    else:
        data.pop("containerEnv", None)

    # Managed: default VS Code extensions. Ensures DEFAULT_EXTENSIONS are present (template editor defaults), preserving any extra extensions and other customizations (e.g. settings) already in the file.
    customizations = data.get("customizations", {})
    if not isinstance(customizations, dict):
        customizations = {}
    vscode = customizations.get("vscode", {})
    if not isinstance(vscode, dict):
        vscode = {}
    existing_ext = vscode.get("extensions", [])
    if not isinstance(existing_ext, list):
        existing_ext = []
    extras = [e for e in existing_ext if e not in DEFAULT_EXTENSIONS]
    vscode["extensions"] = list(DEFAULT_EXTENSIONS) + extras
    customizations["vscode"] = vscode
    data["customizations"] = customizations

    json.dump(data, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
