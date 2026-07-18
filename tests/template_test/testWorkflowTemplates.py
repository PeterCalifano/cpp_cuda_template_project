"""Contracts for template-owned and project-owned GitHub workflows."""

from __future__ import annotations

from pathlib import Path
import subprocess

import yaml


_WORKFLOW_NAMES = (
    "build_linux.yml",
    "build_linux_cuda.yml",
    "docs_pages.yml",
    "build_ros2_overlay.yml",
)

_PROJECT_WORKFLOW_MARKER = "# project-ci-template: generic"
_MANIFEST_DRIFT_GUARD: str = "git diff --exit-code -- ros2/*/package.xml"

_TEMPLATE_ONLY_PATTERNS = (
    "VerifyTemplateProject",
    "testRos2OverlayStatic.py",
    "tailor_template_cleanup.sh",
    "add_ros2_support.sh",
    "CWrapperPlaceholder.h",
    "rollout-rehearsal",
    "Template usage",
    "Documentation workflow",
    "template_project_BUILD_PROGRAMS",
    "template_project_BUILD_EXAMPLES",
)

_PROJECT_WORKFLOW_GATES = {
    "build_linux.yml": (
        "cmake -S .",
        "cmake --build",
        "ctest --test-dir",
    ),
    "build_linux_cuda.yml": (
        "-DENABLE_CUDA=ON",
        "nvcc --version",
        "ctest --test-dir",
    ),
    "docs_pages.yml": (
        "--target doc",
        "actions/upload-pages-artifact",
        "actions/deploy-pages",
    ),
    "build_ros2_overlay.yml": (
        "src/**",
        "rosdep install --from-paths ros2",
        _MANIFEST_DRIFT_GUARD,
        "::warning::",
        "./build_ros2.sh --clean",
    ),
}

_TEMPLATE_WORKFLOW_GATES = {
    "build_linux.yml": (
        "tailored-project-validation",
        "tailor_template_cleanup.sh --apply --yes",
        "git clone --no-local",
        "./build_lib.sh -B build_tailored_ci",
        "cmake --preset docs",
    ),
    "build_linux_cuda.yml": (
        "Verify dormant workflow templates",
        "testWorkflowTemplates.py",
        "Materialize tailored CUDA project",
        "Match tailored project source tree",
        "Verify project CUDA source graph",
        "src/template_src_kernels/placeholder.cu",
        "placeholder_to_ptx.ptx.cu",
    ),
    "docs_pages.yml": (
        "Template usage",
        "template_project_BUILD_PROGRAMS",
        "VerifyTemplateProjectDocsStatic.cmake",
    ),
    "build_ros2_overlay.yml": (
        "Verify installed core header layout",
        _MANIFEST_DRIFT_GUARD,
        "Project version core",
        "testRos2OverlayStatic.py",
        "rollout-rehearsal",
        "Rehearse default-tailored overlay",
        "git clone --no-local",
    ),
}

_TEMPLATE_WORKFLOW_FORBIDDEN_PATTERNS = {
    "build_linux.yml": ("--exclude='./build*'", "-cf - . | tar"),
    "build_ros2_overlay.yml": ("-cf - . | tar",),
}


def _RepoRoot() -> Path:
    """Return the template repository root.

    Example:
        repoRoot_ = _RepoRoot()
        print(repoRoot_.name)
        # Output:
        # cpp_cuda_template_project
    """
    return Path(__file__).resolve().parents[2]


def _WorkflowTriggers(workflowPath_: Path) -> dict[object, object]:
    """Parse a workflow and return its trigger mapping.

    Example:
        triggers_ = _WorkflowTriggers(
            _RepoRoot() / ".github/workflows/build_ros2_overlay.yml"
        )
        print("push" in triggers_)
        # Output:
        # True
    """
    parsed_: object = yaml.safe_load(workflowPath_.read_text(encoding="utf-8"))
    assert isinstance(parsed_, dict), workflowPath_
    triggers_: object = parsed_.get("on", parsed_.get(True))
    assert isinstance(triggers_, dict), (workflowPath_, parsed_)
    return triggers_


class TestWorkflowTemplates:
    def test_activeAndDormantWorkflowPairsParseAsYaml(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"

        for workflowName_ in _WORKFLOW_NAMES:
            activePath_ = workflowRoot_ / workflowName_
            templatePath_ = workflowRoot_ / f"{workflowName_}.tpl"

            assert activePath_.is_file(), activePath_
            assert templatePath_.is_file(), templatePath_
            assert isinstance(
                yaml.safe_load(activePath_.read_text(encoding="utf-8")), dict
            )
            assert isinstance(
                yaml.safe_load(templatePath_.read_text(encoding="utf-8")), dict
            )

    def test_ros2WorkflowsScheduleAndWatchCoreContracts(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"
        activePath_ = workflowRoot_ / "build_ros2_overlay.yml"
        templatePath_ = workflowRoot_ / "build_ros2_overlay.yml.tpl"

        for workflowPath_ in (activePath_, templatePath_):
            triggers_ = _WorkflowTriggers(workflowPath_)
            assert "workflow_dispatch" in triggers_, workflowPath_
            assert triggers_.get("schedule") == [{"cron": "17 3 * * 2"}], workflowPath_

            for eventName_ in ("push", "pull_request"):
                event_: object = triggers_.get(eventName_)
                assert isinstance(event_, dict), (workflowPath_, eventName_)
                paths_: object = event_.get("paths")
                assert isinstance(paths_, list), (workflowPath_, eventName_)
                assert "CMakeLists.txt" in paths_, (workflowPath_, eventName_)
                assert "cmake/**" in paths_, (workflowPath_, eventName_)
                assert "src/**" in paths_, (workflowPath_, eventName_)

        activeTriggers_ = _WorkflowTriggers(activePath_)
        for eventName_ in ("push", "pull_request"):
            event_ = activeTriggers_[eventName_]
            assert isinstance(event_, dict), (activePath_, eventName_)
            paths_ = event_["paths"]
            assert isinstance(paths_, list), (activePath_, eventName_)
            assert "tests/cmake/VerifyTemplateProjectNestedInstallHeaders.cmake" in paths_
            assert "tests/cmake/VerifyTemplateProjectCudaSources.cmake" in paths_

    def test_releaseTagsRunNativeAndRosWorkflows(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"

        for workflowName_ in (
            "build_linux.yml",
            "build_linux_cuda.yml",
            "build_ros2_overlay.yml",
        ):
            for workflowPath_ in (
                workflowRoot_ / workflowName_,
                workflowRoot_ / f"{workflowName_}.tpl",
            ):
                pushTrigger_: object = _WorkflowTriggers(workflowPath_).get("push")
                assert isinstance(pushTrigger_, dict), workflowPath_
                assert pushTrigger_.get("tags") == ["v*.*.*"], workflowPath_

    def test_activeWorkflowsContainTemplateValidation(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"

        for workflowName_, requiredGates_ in _TEMPLATE_WORKFLOW_GATES.items():
            activePath_ = workflowRoot_ / workflowName_
            activeText_ = activePath_.read_text(encoding="utf-8")

            for requiredGate_ in requiredGates_:
                assert requiredGate_ in activeText_, (activePath_, requiredGate_)

            for forbiddenPattern_ in _TEMPLATE_WORKFLOW_FORBIDDEN_PATTERNS.get(
                workflowName_, ()
            ):
                assert forbiddenPattern_ not in activeText_, (
                    activePath_,
                    forbiddenPattern_,
                )

        cudaWorkflow_ = (
            workflowRoot_ / "build_linux_cuda.yml"
        ).read_text(encoding="utf-8")
        assert cudaWorkflow_.count(
            "tailor_template_cleanup.sh --apply --yes"
        ) == 2

        rosWorkflow_ = (
            workflowRoot_ / "build_ros2_overlay.yml"
        ).read_text(encoding="utf-8")
        assert rosWorkflow_.count(_MANIFEST_DRIFT_GUARD) == 2
        assert "Skipping ROS package metadata sync" not in rosWorkflow_
        assert "Project version core" in rosWorkflow_
        assert 'ET.parse("ros2/template_project/package.xml")' not in rosWorkflow_

        docsWorkflow_ = (
            workflowRoot_ / "docs_pages.yml"
        ).read_text(encoding="utf-8")
        assert docsWorkflow_.count("VerifyTemplateProjectDocsStatic.cmake") == 3

    def test_dormantWorkflowsContainOnlyProjectCi(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"

        for workflowName_, requiredGates_ in _PROJECT_WORKFLOW_GATES.items():
            templatePath_ = workflowRoot_ / f"{workflowName_}.tpl"
            templateText_ = templatePath_.read_text(encoding="utf-8")

            assert templateText_.startswith(f"{_PROJECT_WORKFLOW_MARKER}\n"), templatePath_
            for pattern_ in _TEMPLATE_ONLY_PATTERNS:
                assert pattern_ not in templateText_, (templatePath_, pattern_)
            for requiredGate_ in requiredGates_:
                assert requiredGate_ in templateText_, (
                    templatePath_,
                    requiredGate_,
                )

    def test_manifestDriftGuardRejectsTrackedChanges(self, tmp_path: Path) -> None:
        repositoryRoot_ = tmp_path / "manifest-drift"
        manifestPath_ = repositoryRoot_ / "ros2" / "demo" / "package.xml"
        manifestPath_.parent.mkdir(parents=True)
        manifestPath_.write_text("<package><version>1.2.3</version></package>\n")

        subprocess.run(
            ["git", "init", "--quiet", str(repositoryRoot_)],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(repositoryRoot_), "add", "ros2/demo/package.xml"],
            check=True,
        )
        subprocess.run(
            [
                "git",
                "-C",
                str(repositoryRoot_),
                "-c",
                "user.name=Workflow Contract",
                "-c",
                "user.email=workflow-contract@example.invalid",
                "commit",
                "--quiet",
                "-m",
                "Record manifest",
            ],
            check=True,
        )

        cleanResult_ = subprocess.run(
            ["bash", "-c", _MANIFEST_DRIFT_GUARD],
            cwd=repositoryRoot_,
            check=False,
        )
        assert cleanResult_.returncode == 0

        manifestPath_.write_text("<package><version>1.2.4</version></package>\n")
        dirtyResult_ = subprocess.run(
            ["bash", "-c", _MANIFEST_DRIFT_GUARD],
            cwd=repositoryRoot_,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        assert dirtyResult_.returncode != 0
