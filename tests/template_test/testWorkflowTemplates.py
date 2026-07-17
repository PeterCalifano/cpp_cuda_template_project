"""Contracts for template-owned and project-owned GitHub workflows."""

from __future__ import annotations

from pathlib import Path

import yaml


_WORKFLOW_NAMES = (
    "build_linux.yml",
    "build_linux_cuda.yml",
    "docs_pages.yml",
    "build_ros2_overlay.yml",
)

_PROJECT_WORKFLOW_MARKER = "# project-ci-template: generic"

_TEMPLATE_ONLY_PATTERNS = (
    "VerifyTemplateProject",
    "testRos2OverlayStatic.py",
    "tailor_template_cleanup.sh",
    "add_ros2_support.sh",
    "CWrapperPlaceholder.h",
    "rollout-dogfood",
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
        "./build_ros2.sh --clean",
    ),
}

_TEMPLATE_WORKFLOW_GATES = {
    "build_linux.yml": (
        "tailored-project-dogfood",
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
    ),
    "docs_pages.yml": (
        "Template usage",
        "template_project_BUILD_PROGRAMS",
    ),
    "build_ros2_overlay.yml": (
        "Verify installed core header layout",
        "testRos2OverlayStatic.py",
        "rollout-dogfood",
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
