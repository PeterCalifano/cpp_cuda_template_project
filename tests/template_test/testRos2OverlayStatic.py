"""Static regression tests for the optional ROS 2 overlay."""

from __future__ import annotations

import os
import re
import shutil
import stat
import subprocess
from pathlib import Path

import pytest


_VERSION_TAG_RE = re.compile(r"<version>[^<]+</version>")
_ROS_REFERENCE_RE = re.compile(r"\b(rclcpp|ament|rosidl)\b")
_STALE_NODE_SEAM_RE = re.compile(r"CTemplateLifecycleNode\.cpp[^\n]*(?:call the real library API|real API call)")


def _RepoRoot() -> Path:
    """Return the template repository root.

    Example:
        repoRoot_ = _RepoRoot()
        print(repoRoot_.name)
        # Output:
        # cpp_cuda_template_project
    """
    return Path(__file__).resolve().parents[2]


def _SkipIfNoRos2(repoRoot_: Path) -> None:
    """Skip overlay checks in tailored projects that removed ros2/.

    Example:
        _SkipIfNoRos2(Path("."))
        print("continued")
        # Output:
        # continued
    """
    if not (repoRoot_ / "ros2").is_dir():
        pytest.skip("ROS 2 overlay is not present in this tailored project")


def _PackageXmlPaths(repoRoot_: Path) -> list[Path]:
    """Return immediate ROS 2 package manifests.

    Example:
        paths_ = _PackageXmlPaths(_RepoRoot())
        print(all(path_.name == "package.xml" for path_ in paths_))
        # Output:
        # True
    """
    return sorted((repoRoot_ / "ros2").glob("*/package.xml"))


def _PackageVersion(packageXml_: Path) -> str:
    """Read the first package.xml version tag.

    Example:
        version_ = _PackageVersion(Path("ros2/template_project/package.xml"))
        print(version_.count(".") == 2)
        # Output:
        # True
    """
    text_ = packageXml_.read_text(encoding="utf-8")
    match_ = _VERSION_TAG_RE.search(text_)
    assert match_ is not None, f"No <version> tag found in {packageXml_}"
    return match_.group(0).removeprefix("<version>").removesuffix("</version>")


def _ReadVersionCore(versionFile_: Path) -> str:
    """Read the strict core version from a VERSION file.

    Example:
        version_ = _ReadVersionCore(Path("VERSION"))
        print(version_.count(".") == 2)
        # Output:
        # True
    """
    text_ = versionFile_.read_text(encoding="utf-8")
    for fieldName_ in ("Project version core", "Project version"):
        match_ = re.search(rf"^{re.escape(fieldName_)}:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$", text_, re.MULTILINE)
        if match_ is not None:
            return match_.group(1)
    raise AssertionError(f"No strict core version found in {versionFile_}")


class TestRos2OverlayStatic:
    def test_packageVersionsMatchSourceVersionWhenPresent(self) -> None:
        repoRoot_ = _RepoRoot()
        _SkipIfNoRos2(repoRoot_)

        packageVersions_ = {
            packageXml_.relative_to(repoRoot_).as_posix(): _PackageVersion(packageXml_)
            for packageXml_ in _PackageXmlPaths(repoRoot_)
        }

        assert packageVersions_, "No ROS 2 package.xml files found"
        assert len(set(packageVersions_.values())) == 1, packageVersions_

        versionFile_ = repoRoot_ / "VERSION"
        if versionFile_.exists():
            assert set(packageVersions_.values()) == {_ReadVersionCore(versionFile_)}

    def test_colconIgnoreMarkersArePresent(self) -> None:
        repoRoot_ = _RepoRoot()
        _SkipIfNoRos2(repoRoot_)

        for marker_ in (
            "python/COLCON_IGNORE",
            "lib/COLCON_IGNORE",
            "examples/COLCON_IGNORE",
            "tests/COLCON_IGNORE",
        ):
            assert (repoRoot_ / marker_).is_file(), marker_

    def test_pythonTreeHasNoRosReferences(self) -> None:
        repoRoot_ = _RepoRoot()
        _SkipIfNoRos2(repoRoot_)

        pythonRoot_ = repoRoot_ / "python"
        offendingPaths_: list[str] = []
        for path_ in pythonRoot_.rglob("*"):
            if not path_.is_file() or path_.name == "COLCON_IGNORE":
                continue
            try:
                text_ = path_.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            if _ROS_REFERENCE_RE.search(text_) is not None:
                offendingPaths_.append(path_.relative_to(repoRoot_).as_posix())

        assert offendingPaths_ == []

    def test_buildScriptContainsRosEnvironmentGuard(self) -> None:
        repoRoot_ = _RepoRoot()
        _SkipIfNoRos2(repoRoot_)

        buildScript_ = (repoRoot_ / "build_ros2.sh").read_text(encoding="utf-8")

        assert "die \"ROS setup file not found" in buildScript_
        assert "./build_lib.sh" in buildScript_
        assert "never needs ROS" in buildScript_

    def test_rolloutDocsPointToConversionsSeam(self) -> None:
        repoRoot_ = _RepoRoot()
        _SkipIfNoRos2(repoRoot_)

        rolloutDocs_ = (
            repoRoot_ / "doc/bootstrap_prompts.md",
            repoRoot_ / "doc/template_usage.md",
            repoRoot_ / "doc/ros2_overlay.md",
        )
        for docPath_ in rolloutDocs_:
            text_ = docPath_.read_text(encoding="utf-8")
            assert "conversions.cpp" in text_, docPath_
            assert _STALE_NODE_SEAM_RE.search(text_) is None, docPath_

    def test_generateVersionSyncsCopiedRosPackageVersions(self, tmp_path: Path) -> None:
        repoRoot_ = _RepoRoot()
        _SkipIfNoRos2(repoRoot_)

        scriptSource_ = repoRoot_ / "generate_version.sh"
        scriptCopy_ = tmp_path / "generate_version.sh"
        shutil.copy2(scriptSource_, scriptCopy_)
        os.chmod(scriptCopy_, 0o755)

        sourceVersion_ = repoRoot_ / "VERSION"
        if sourceVersion_.exists():
            shutil.copy2(sourceVersion_, tmp_path / "VERSION")
        else:
            (tmp_path / "VERSION").write_text(
                "\n".join(
                    (
                        "Project version: 9.8.7",
                        "Project version core: 9.8.7",
                        "Project version prerelease: <none>",
                        "Project version metadata: <none>",
                        "Full version: 9.8.7",
                        "",
                    )
                ),
                encoding="utf-8",
            )

        expectedVersion_ = _ReadVersionCore(tmp_path / "VERSION")
        packagePaths_ = _PackageXmlPaths(repoRoot_)
        assert packagePaths_, "No ROS 2 package.xml files found"
        expectedModes_: dict[str, int] = {}

        for index_, packagePath_ in enumerate(packagePaths_):
            targetPath_ = tmp_path / packagePath_.relative_to(repoRoot_)
            targetPath_.parent.mkdir(parents=True, exist_ok=True)
            text_ = packagePath_.read_text(encoding="utf-8")
            if index_ == 0:
                text_ = _VERSION_TAG_RE.sub("<version>0.0.1</version>", text_, count=1)
            targetPath_.write_text(text_, encoding="utf-8")
            os.chmod(targetPath_, 0o664 if index_ == 0 else 0o640)
            expectedModes_[targetPath_.relative_to(tmp_path).as_posix()] = stat.S_IMODE(
                targetPath_.stat().st_mode
            )

        result_ = subprocess.run(
            ["bash", str(scriptCopy_), "--sync-ros2"],
            cwd=tmp_path,
            check=False,
            capture_output=True,
            text=True,
        )

        assert result_.returncode == 0, result_.stderr
        syncedVersions_ = {
            packageXml_.relative_to(tmp_path).as_posix(): _PackageVersion(packageXml_)
            for packageXml_ in sorted((tmp_path / "ros2").glob("*/package.xml"))
        }
        assert syncedVersions_, "Copied ROS 2 package.xml files disappeared"
        assert set(syncedVersions_.values()) == {expectedVersion_}, (
            result_.stdout,
            result_.stderr,
            syncedVersions_,
        )
        syncedModes_ = {
            packageXml_.relative_to(tmp_path).as_posix(): stat.S_IMODE(
                packageXml_.stat().st_mode
            )
            for packageXml_ in sorted((tmp_path / "ros2").glob("*/package.xml"))
        }
        assert syncedModes_ == expectedModes_, (result_.stdout, result_.stderr, syncedModes_)
