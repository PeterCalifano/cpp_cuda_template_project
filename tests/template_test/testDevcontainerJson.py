"""Regression tests for the devcontainer JSON updater."""

from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import types
from pathlib import Path


def _LoadUpdateModule() -> types.ModuleType:
    """Load the devcontainer updater script as a Python module.

    Example:
        module_ = _LoadUpdateModule()
        print(hasattr(module_, "load_existing"))
        # Output:
        # True
    """
    repoRoot_ = Path(__file__).resolve().parents[2]
    modulePath_ = repoRoot_ / ".devcontainer" / "update_devcontainer_json.py"
    spec_ = importlib.util.spec_from_file_location(
        "update_devcontainer_json", modulePath_)
    assert spec_ is not None
    assert spec_.loader is not None

    module_ = importlib.util.module_from_spec(spec_)
    spec_.loader.exec_module(module_)
    return module_


def _RunWriter(
    devcontainerJson_: Path, *, cuda_: str, gpuRuntime_: str
) -> dict[str, object]:
    """Run the devcontainer updater and return its JSON output.

    Example:
        data_ = _RunWriter(
            Path("devcontainer.json"), cuda_="off", gpuRuntime_="docker"
        )
        print(isinstance(data_, dict))
        # Output:
        # True
    """
    repoRoot_ = Path(__file__).resolve().parents[2]
    writerPath_ = repoRoot_ / ".devcontainer" / "update_devcontainer_json.py"
    env_ = os.environ.copy()
    env_.update(
        {
            "CUDA": cuda_,
            "CUDA_VERSION": "12.9",
            "ROS_MODE": "none",
            "ROS_DISTRO": "",
            "ROS_PROFILE": "ros-base",
            "DEVCONTAINER_JSON_PATH": str(devcontainerJson_),
            "DEVCONTAINER_GPU_RUNTIME": gpuRuntime_,
        }
    )

    result_ = subprocess.run(
        [sys.executable, str(writerPath_)],
        check=True,
        capture_output=True,
        text=True,
        env=env_,
    )
    data_ = json.loads(result_.stdout)
    assert isinstance(data_, dict)
    return data_


def _PrepareConfigureWorkspace(tmpPath_: Path) -> Path:
    """Create a minimal configure_devcontainer.sh workspace.

    Example:
        workspace_ = _PrepareConfigureWorkspace(Path("/tmp/example"))
        print((workspace_ / "configure_devcontainer.sh").name)
        # Output:
        # configure_devcontainer.sh
    """
    repoRoot_ = Path(__file__).resolve().parents[2]
    workspace_ = tmpPath_ / "workspace"
    devcontainerDir_ = workspace_ / ".devcontainer"
    devcontainerDir_.mkdir(parents=True)

    (workspace_ / "configure_devcontainer.sh").write_text(
        (repoRoot_ / "configure_devcontainer.sh").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    (devcontainerDir_ / "update_devcontainer_json.py").write_text(
        (repoRoot_ / ".devcontainer" / "update_devcontainer_json.py").read_text(
            encoding="utf-8"
        ),
        encoding="utf-8",
    )
    (devcontainerDir_ / "Dockerfile").write_text(
        "FROM mcr.microsoft.com/devcontainers/cpp:1-ubuntu-24.04\n",
        encoding="utf-8",
    )
    (devcontainerDir_ / "devcontainer.json").write_text(
        json.dumps({"name": "Existing", "runArgs": ["--ipc", "host"]}),
        encoding="utf-8",
    )
    return workspace_


class TestDevcontainerJson:
    def test_load_existing_accepts_inline_jsonc_comments(self, tmp_path: Path) -> None:
        devcontainerJson_ = tmp_path / "devcontainer.json"
        devcontainerJson_.write_text(
            """
{
  // Existing hand-written comments should be tolerated.
  "name": "Existing", // Inline comments after properties should also work.
  "remoteEnv": {
    "DISPLAY": "unix:0", // Preserve unmanaged environment entries.
    "DOCS_URL": "https://example.invalid/docs"
  }
}
""",
            encoding="utf-8",
        )
        updateModule_ = _LoadUpdateModule()

        data_ = updateModule_.load_existing(str(devcontainerJson_))

        assert data_["name"] == "Existing"
        assert data_["remoteEnv"]["DISPLAY"] == "unix:0"
        assert data_["remoteEnv"]["DOCS_URL"] == "https://example.invalid/docs"
        json.dumps(data_)

    def test_cuda_docker_runtime_emits_docker_gpu_args(self, tmp_path: Path) -> None:
        devcontainerJson_ = tmp_path / "devcontainer.json"
        devcontainerJson_.write_text(
            json.dumps(
                {
                    "name": "Existing",
                    "runArgs": [
                        "--device",
                        "nvidia.com/gpu=all",
                        "--security-opt=label=disable",
                        "--ipc",
                        "host",
                    ],
                }
            ),
            encoding="utf-8",
        )

        data_ = _RunWriter(devcontainerJson_, cuda_="on", gpuRuntime_="docker")

        assert data_["runArgs"] == ["--gpus", "all", "--ipc", "host"]

    def test_cuda_podman_runtime_emits_cdi_gpu_args(self, tmp_path: Path) -> None:
        devcontainerJson_ = tmp_path / "devcontainer.json"
        devcontainerJson_.write_text(
            json.dumps(
                {
                    "name": "Existing",
                    "runArgs": ["--gpus", "all", "--ipc", "host"],
                }
            ),
            encoding="utf-8",
        )

        data_ = _RunWriter(devcontainerJson_, cuda_="on", gpuRuntime_="podman")

        assert data_["runArgs"] == [
            "--device",
            "nvidia.com/gpu=all",
            "--security-opt=label=disable",
            "--ipc",
            "host",
        ]

    def test_cuda_off_removes_all_managed_gpu_args(self, tmp_path: Path) -> None:
        devcontainerJson_ = tmp_path / "devcontainer.json"
        devcontainerJson_.write_text(
            json.dumps(
                {
                    "name": "Existing",
                    "runArgs": [
                        "--gpus=all",
                        "--device=nvidia.com/gpu=all",
                        "--security-opt",
                        "label=disable",
                        "--ipc",
                        "host",
                    ],
                }
            ),
            encoding="utf-8",
        )

        data_ = _RunWriter(devcontainerJson_, cuda_="off",
                           gpuRuntime_="docker")

        assert data_["runArgs"] == ["--ipc", "host"]

    def test_configure_devcontainer_passes_gpu_runtime_to_writer(
        self, tmp_path: Path
    ) -> None:
        workspace_ = _PrepareConfigureWorkspace(tmp_path)
        scriptPath_ = workspace_ / "configure_devcontainer.sh"

        subprocess.run(
            [
                "bash",
                str(scriptPath_),
                "--cuda",
                "--gpu-runtime",
                "docker",
                "--base",
                "ubuntu-24.04",
                "--non-interactive",
            ],
            check=True,
            cwd=workspace_,
            capture_output=True,
            text=True,
        )

        data_ = json.loads(
            (workspace_ / ".devcontainer" / "devcontainer.json").read_text(
                encoding="utf-8"
            )
        )
        assert data_["runArgs"] == ["--gpus", "all", "--ipc", "host"]

        subprocess.run(
            [
                "bash",
                str(scriptPath_),
                "--cuda",
                "--gpu-runtime",
                "podman",
                "--base",
                "ubuntu-24.04",
                "--non-interactive",
            ],
            check=True,
            cwd=workspace_,
            capture_output=True,
            text=True,
        )

        data_ = json.loads(
            (workspace_ / ".devcontainer" / "devcontainer.json").read_text(
                encoding="utf-8"
            )
        )
        assert data_["runArgs"] == [
            "--device",
            "nvidia.com/gpu=all",
            "--security-opt=label=disable",
            "--ipc",
            "host",
        ]
