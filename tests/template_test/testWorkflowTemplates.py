"""Parser-backed and behavioral contracts for GitHub workflows."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
from typing import cast

import yaml


_WORKFLOW_NAMES: tuple[str, ...] = (
    "build_linux.yml",
    "build_linux_cuda.yml",
    "docs_pages.yml",
    "build_ros2_overlay.yml",
)


def _RepoRoot() -> Path:
    """Return the template repository root.

    Example:
        print(_RepoRoot().name)
        # Output: cpp_cuda_template_project
    """
    return Path(__file__).resolve().parents[2]


def _LoadWorkflow(workflowPath_: Path) -> dict[str, object]:
    """Load one workflow through PyYAML.

    Example:
        workflow_ = _LoadWorkflow(_RepoRoot() / ".github/workflows/build_linux.yml")
        print("jobs" in workflow_)
        # Output: True
    """
    parsed_: object = yaml.safe_load(workflowPath_.read_text(encoding="utf-8"))
    assert isinstance(parsed_, dict), workflowPath_
    return cast(dict[str, object], parsed_)


def _WorkflowTriggers(workflowPath_: Path) -> dict[str, object]:
    """Return the parsed trigger mapping for one workflow.

    Example:
        triggers_ = _WorkflowTriggers(
            _RepoRoot() / ".github/workflows/build_linux.yml"
        )
        print("push" in triggers_)
        # Output: True
    """
    workflow_ = _LoadWorkflow(workflowPath_)
    workflowObjects_ = cast(dict[object, object], workflow_)
    triggers_: object = workflowObjects_.get("on", workflowObjects_.get(True))
    assert isinstance(triggers_, dict), workflowPath_
    return cast(dict[str, object], triggers_)


def _Jobs(workflowPath_: Path) -> dict[str, dict[str, object]]:
    """Return the parsed jobs keyed by job identifier.

    Example:
        jobs_ = _Jobs(_RepoRoot() / ".github/workflows/docs_pages.yml")
        print("build-docs" in jobs_)
        # Output: True
    """
    jobsRaw_: object = _LoadWorkflow(workflowPath_).get("jobs")
    assert isinstance(jobsRaw_, dict), workflowPath_
    jobs_: dict[str, dict[str, object]] = {}
    for jobName_, jobRaw_ in jobsRaw_.items():
        assert isinstance(jobName_, str), workflowPath_
        assert isinstance(jobRaw_, dict), (workflowPath_, jobName_)
        jobs_[jobName_] = cast(dict[str, object], jobRaw_)
    return jobs_


def _Steps(job_: dict[str, object]) -> list[dict[str, object]]:
    """Return a job's parsed step mappings.

    Example:
        job_ = _Jobs(_RepoRoot() / ".github/workflows/docs_pages.yml")["build-docs"]
        print(len(_Steps(job_)) > 0)
        # Output: True
    """
    stepsRaw_: object = job_.get("steps")
    assert isinstance(stepsRaw_, list), job_
    steps_: list[dict[str, object]] = []
    for stepRaw_ in stepsRaw_:
        assert isinstance(stepRaw_, dict), stepRaw_
        steps_.append(cast(dict[str, object], stepRaw_))
    return steps_


def _StepById(job_: dict[str, object], stepId_: str) -> dict[str, object]:
    """Return the uniquely identified step from a parsed job.

    Example:
        job_ = _Jobs(_RepoRoot() / ".github/workflows/docs_pages.yml")["build-docs"]
        print(_StepById(job_, "build_docs")["id"])
        # Output: build_docs
    """
    matches_: list[dict[str, object]] = [
        step_ for step_ in _Steps(job_) if step_.get("id") == stepId_
    ]
    assert len(matches_) == 1, (stepId_, matches_)
    return matches_[0]


def _TriggerPaths(workflowPath_: Path, eventName_: str) -> list[str]:
    """Return a branch event's parsed path filter.

    Example:
        paths_ = _TriggerPaths(
            _RepoRoot() / ".github/workflows/build_linux.yml", "push"
        )
        print("CMakeLists.txt" in paths_)
        # Output: True
    """
    event_: object = _WorkflowTriggers(workflowPath_).get(eventName_)
    assert isinstance(event_, dict), (workflowPath_, eventName_)
    paths_: object = event_.get("paths")
    assert isinstance(paths_, list), (workflowPath_, eventName_)
    assert all(isinstance(path_, str) for path_ in paths_), paths_
    return cast(list[str], paths_)


def _InitializeManifestRepository(repositoryRoot_: Path) -> None:
    """Create a committed ROS manifest fixture.

    Example:
        # _InitializeManifestRepository(Path("/tmp/workflow-contract"))
        # Output: a Git repository containing ros2/demo/package.xml
    """
    manifestPath_ = repositoryRoot_ / "ros2/demo/package.xml"
    manifestPath_.parent.mkdir(parents=True)
    manifestPath_.write_text(
        "<package><name>demo</name><version>1.2.3</version></package>\n",
        encoding="utf-8",
    )
    subprocess.run(["git", "init", "--quiet", str(repositoryRoot_)], check=True)
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


def _WriteMetadataHelper(
    repositoryRoot_: Path, *, includeCapabilityMarkers_: bool = True
) -> None:
    """Write an executable fake metadata helper for workflow execution.

    Example:
        # _WriteMetadataHelper(Path("/tmp/workflow-contract"))
        # Output: executable generate_version.sh
    """
    helperPath_ = repositoryRoot_ / "generate_version.sh"
    capabilityMarkers_ = ""
    if includeCapabilityMarkers_:
        capabilityMarkers_ = (
            "# Contract fixture supports --sync-ros2.\n"
            "ROS2_PROJECT_METADATA_SYNC=1\n"
        )
    helperPath_.write_text(
        "#!/usr/bin/env bash\n"
        + capabilityMarkers_
        + """if [[ "${MUTATE_MANIFEST:-0}" == "1" ]]; then
  python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
path_ = Path("ros2/demo/package.xml")
tree_ = ET.parse(path_)
version_ = tree_.getroot().find("version")
assert version_ is not None
version_.text = "1.2.4"
tree_.write(path_, encoding="unicode")
PY
fi
""",
        encoding="utf-8",
    )
    helperPath_.chmod(0o755)


def _RunMetadataStep(
    step_: dict[str, object], repositoryRoot_: Path, mutateManifest_: bool
) -> subprocess.CompletedProcess[str]:
    """Execute a workflow metadata-sync step in a Git fixture.

    Example:
        # result_ = _RunMetadataStep(step_, repositoryRoot_, False)
        # Output: result_.returncode == 0
    """
    runBlock_: object = step_.get("run")
    assert isinstance(runBlock_, str), step_
    environment_: dict[str, str] = dict(os.environ)
    environment_["GITHUB_WORKSPACE"] = str(repositoryRoot_)
    environment_["MUTATE_MANIFEST"] = "1" if mutateManifest_ else "0"
    return subprocess.run(
        ["bash", "-Eeuo", "pipefail", "-c", runBlock_],
        cwd=repositoryRoot_,
        env=environment_,
        check=False,
        capture_output=True,
        text=True,
    )


class TestWorkflowTemplates:
    def test_activeAndDormantWorkflowPairsParseAsYaml(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"
        for workflowName_ in _WORKFLOW_NAMES:
            for workflowPath_ in (
                workflowRoot_ / workflowName_,
                workflowRoot_ / f"{workflowName_}.tpl",
            ):
                assert workflowPath_.is_file(), workflowPath_
                assert _Jobs(workflowPath_), workflowPath_

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
                push_: object = _WorkflowTriggers(workflowPath_).get("push")
                assert isinstance(push_, dict), workflowPath_
                assert push_.get("tags") == ["v*.*.*"], workflowPath_

    def test_cudaJobsRequireExplicitSelfHostedRunnerOptIn(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"
        expectedCondition_ = "${{ vars.CI_USE_SELF_HOSTED == 'true' }}"
        for workflowPath_ in (
            workflowRoot_ / "build_linux_cuda.yml",
            workflowRoot_ / "build_linux_cuda.yml.tpl",
        ):
            for jobName_, job_ in _Jobs(workflowPath_).items():
                assert jobName_ in {"build", "test"}, workflowPath_
                assert job_.get("if") == expectedCondition_, (
                    workflowPath_,
                    jobName_,
                )

    def test_branchPathFiltersOwnTheirSemanticTests(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"
        nativePaths_: tuple[Path, ...] = (
            workflowRoot_ / "build_linux.yml",
            workflowRoot_ / "build_linux.yml.tpl",
        )
        rosPaths_: tuple[Path, ...] = (
            workflowRoot_ / "build_ros2_overlay.yml",
            workflowRoot_ / "build_ros2_overlay.yml.tpl",
        )
        for workflowPath_ in nativePaths_:
            for eventName_ in ("push", "pull_request"):
                assert "generate_version.sh" in _TriggerPaths(workflowPath_, eventName_)

        for workflowPath_ in rosPaths_:
            assert "workflow_dispatch" in _WorkflowTriggers(workflowPath_)
            for eventName_ in ("push", "pull_request"):
                paths_ = _TriggerPaths(workflowPath_, eventName_)
                assert {"CMakeLists.txt", "cmake/**", "src/**"} <= set(paths_)

        activeRos_ = workflowRoot_ / "build_ros2_overlay.yml"
        for eventName_ in ("push", "pull_request"):
            paths_ = _TriggerPaths(activeRos_, eventName_)
            assert "tests/template_test/testWorkflowTemplates.py" in paths_
            assert "tests/template_test/testRos2OverlayStatic.py" in paths_

        docsWorkflow_ = workflowRoot_ / "docs_pages.yml"
        for eventName_ in ("push", "pull_request"):
            paths_ = _TriggerPaths(docsWorkflow_, eventName_)
            assert "README.md" in paths_
            assert "tests/template_test/testWorkflowTemplates.py" in paths_

    def test_workflowTopologySeparatesTemplateAndGenericJobs(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"
        expectedJobs_: dict[str, tuple[set[str], set[str]]] = {
            "build_linux.yml": (
                {"build", "test", "tailored-project-validation"},
                {"build", "test"},
            ),
            "build_linux_cuda.yml": ({"build", "test"}, {"build", "test"}),
            "docs_pages.yml": ({"build-docs", "deploy"}, {"build-docs", "deploy"}),
            "build_ros2_overlay.yml": (
                {"overlay-build", "rollout-rehearsal"},
                {"overlay-build"},
            ),
        }
        for workflowName_, (activeJobs_, genericJobs_) in expectedJobs_.items():
            assert set(_Jobs(workflowRoot_ / workflowName_)) == activeJobs_
            assert set(_Jobs(workflowRoot_ / f"{workflowName_}.tpl")) == genericJobs_

        activeDocs_ = _Jobs(workflowRoot_ / "docs_pages.yml")["build-docs"]
        genericDocs_ = _Jobs(workflowRoot_ / "docs_pages.yml.tpl")["build-docs"]
        assert _StepById(activeDocs_, "workflow_contracts")
        assert all(
            step_.get("id") != "workflow_contracts"
            for step_ in _Steps(genericDocs_)
        )

        activeCuda_ = _Jobs(workflowRoot_ / "build_linux_cuda.yml")["build"]
        genericCuda_ = _Jobs(workflowRoot_ / "build_linux_cuda.yml.tpl")["build"]
        assert _StepById(activeCuda_, "workflow_contracts")
        assert _StepById(activeCuda_, "materialize_tailored_project")
        genericCudaIds_ = {step_.get("id") for step_ in _Steps(genericCuda_)}
        assert "workflow_contracts" not in genericCudaIds_
        assert "materialize_tailored_project" not in genericCudaIds_

    def test_everyCheckoutFetchesFullHistory(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"
        for workflowName_ in _WORKFLOW_NAMES:
            for workflowPath_ in (
                workflowRoot_ / workflowName_,
                workflowRoot_ / f"{workflowName_}.tpl",
            ):
                checkoutCount_ = 0
                for job_ in _Jobs(workflowPath_).values():
                    for step_ in _Steps(job_):
                        uses_: object = step_.get("uses")
                        if not isinstance(uses_, str) or not uses_.startswith(
                            "actions/checkout@"
                        ):
                            continue
                        checkoutCount_ += 1
                        with_: object = step_.get("with")
                        assert isinstance(with_, dict), (workflowPath_, step_)
                        assert with_.get("fetch-depth") == 0, (workflowPath_, step_)
                assert checkoutCount_ > 0, workflowPath_

    def test_shellRunBlocksParse(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"
        for workflowName_ in _WORKFLOW_NAMES:
            for workflowPath_ in (
                workflowRoot_ / workflowName_,
                workflowRoot_ / f"{workflowName_}.tpl",
            ):
                for jobId_, job_ in _Jobs(workflowPath_).items():
                    for stepIndex_, step_ in enumerate(_Steps(job_)):
                        runBlock_: object = step_.get("run")
                        if not isinstance(runBlock_, str):
                            continue
                        result_ = subprocess.run(
                            ["bash", "-n"],
                            input=runBlock_,
                            check=False,
                            capture_output=True,
                            text=True,
                        )
                        assert result_.returncode == 0, (
                            workflowPath_,
                            jobId_,
                            stepIndex_,
                            result_.stderr,
                        )

    def test_docsWorkflowUsesCurrentPagesActions(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"
        for workflowPath_ in (
            workflowRoot_ / "docs_pages.yml",
            workflowRoot_ / "docs_pages.yml.tpl",
        ):
            jobs_ = _Jobs(workflowPath_)
            buildSteps_ = _Steps(jobs_["build-docs"])
            deploySteps_ = _Steps(jobs_["deploy"])
            assert any(
                step_.get("uses") == "actions/upload-pages-artifact@v5"
                for step_ in buildSteps_
            )
            assert any(
                step_.get("uses") == "actions/configure-pages@v6"
                for step_ in deploySteps_
            )
            assert any(
                step_.get("uses") == "actions/deploy-pages@v5"
                for step_ in deploySteps_
            )

    def test_rosJobOrderIsRepresentedStructurally(self) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"
        activeJobs_ = _Jobs(workflowRoot_ / "build_ros2_overlay.yml")
        genericJobs_ = _Jobs(workflowRoot_ / "build_ros2_overlay.yml.tpl")

        for job_ in (*activeJobs_.values(), *genericJobs_.values()):
            container_: object = job_.get("container")
            assert isinstance(container_, dict), job_
            assert container_.get("image") == "ros:jazzy"
            stepIds_: list[object] = [step_.get("id") for step_ in _Steps(job_)]
            orderedIds_: tuple[str, ...] = (
                "checkout_repository",
                "trust_worktree",
                "install_dependencies",
                "sync_metadata",
                "resolve_dependencies",
            )
            indices_: list[int] = [stepIds_.index(id_) for id_ in orderedIds_]
            assert indices_ == sorted(indices_)

        assert _StepById(activeJobs_["overlay-build"], "static_contracts")
        assert _StepById(activeJobs_["rollout-rehearsal"], "additive_rollout")
        genericIds_ = {
            step_.get("id") for step_ in _Steps(genericJobs_["overlay-build"])
        }
        assert "static_contracts" not in genericIds_
        assert "additive_rollout" not in genericIds_

    def test_metadataSyncStepsRejectManifestDrift(self, tmp_path: Path) -> None:
        workflowRoot_ = _RepoRoot() / ".github/workflows"
        activeJobs_ = _Jobs(workflowRoot_ / "build_ros2_overlay.yml")
        genericJob_ = _Jobs(workflowRoot_ / "build_ros2_overlay.yml.tpl")[
            "overlay-build"
        ]

        steps_: list[tuple[str, dict[str, object]]] = [
            (
                f"active-{jobName_}",
                _StepById(job_, "sync_metadata"),
            )
            for jobName_, job_ in activeJobs_.items()
        ]
        steps_.append(
            (
                "generic-overlay-build",
                _StepById(genericJob_, "sync_metadata"),
            )
        )

        for fixtureName_, step_ in steps_:
            cleanRoot_ = tmp_path / f"{fixtureName_}-clean"
            _InitializeManifestRepository(cleanRoot_)
            _WriteMetadataHelper(cleanRoot_)
            cleanResult_ = _RunMetadataStep(step_, cleanRoot_, False)
            assert cleanResult_.returncode == 0, (
                cleanResult_.stdout,
                cleanResult_.stderr,
            )

            dirtyRoot_ = tmp_path / f"{fixtureName_}-dirty"
            _InitializeManifestRepository(dirtyRoot_)
            _WriteMetadataHelper(dirtyRoot_)
            dirtyResult_ = _RunMetadataStep(step_, dirtyRoot_, True)
            assert dirtyResult_.returncode != 0

        compatibleRoot_ = tmp_path / "generic-compatible-skip"
        _InitializeManifestRepository(compatibleRoot_)
        compatibleResult_ = _RunMetadataStep(
            _StepById(genericJob_, "sync_metadata"),
            compatibleRoot_,
            False,
        )
        assert compatibleResult_.returncode == 0, compatibleResult_.stderr

    def test_activeMetadataSyncExecutesMarkerFreeHelper(
        self, tmp_path: Path
    ) -> None:
        activeJobs_ = _Jobs(
            _RepoRoot() / ".github/workflows/build_ros2_overlay.yml"
        )
        for jobName_, job_ in activeJobs_.items():
            repositoryRoot_ = tmp_path / jobName_
            _InitializeManifestRepository(repositoryRoot_)
            _WriteMetadataHelper(
                repositoryRoot_, includeCapabilityMarkers_=False
            )
            result_ = _RunMetadataStep(
                _StepById(job_, "sync_metadata"), repositoryRoot_, False
            )
            assert result_.returncode == 0, (
                result_.stdout,
                result_.stderr,
            )

    def test_structuredRepositoryConfigurationParses(self) -> None:
        repoRoot_ = _RepoRoot()
        presets_: object = json.loads(
            (repoRoot_ / "CMakePresets.json").read_text(encoding="utf-8")
        )
        assert isinstance(presets_, dict)
        configurePresets_: object = presets_.get("configurePresets")
        buildPresets_: object = presets_.get("buildPresets")
        assert isinstance(configurePresets_, list)
        assert isinstance(buildPresets_, list)
        assert any(
            isinstance(preset_, dict) and preset_.get("name") == "docs"
            for preset_ in configurePresets_
        )
        assert any(
            isinstance(preset_, dict)
            and preset_.get("name") == "docs"
            and preset_.get("targets") == ["doc"]
            for preset_ in buildPresets_
        )

        issueRoot_ = repoRoot_ / ".github/ISSUE_TEMPLATE"
        for issuePath_ in (
            issueRoot_ / "bug_report.yml",
            issueRoot_ / "feature_request.yml",
            issueRoot_ / "config.yml",
        ):
            parsed_: object = yaml.safe_load(issuePath_.read_text(encoding="utf-8"))
            assert isinstance(parsed_, dict), issuePath_
