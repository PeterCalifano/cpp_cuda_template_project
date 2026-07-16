"""Static regression tests for the optional ROS 2 overlay."""

from __future__ import annotations

import os
import re
import shutil
import stat
import subprocess
import xml.etree.ElementTree as ET
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


def _CMakeCacheValue(cacheText_: str, key_: str) -> str:
    """Read one value from CMakeCache.txt text.

    Example:
        value_ = _CMakeCacheValue("FIELD:STRING=value\n", "FIELD")
        print(value_)
        # Output:
        # value
    """
    match_ = re.search(rf"^{re.escape(key_)}:[^=]+=(.*)$", cacheText_, re.MULTILINE)
    assert match_ is not None, f"Missing CMake cache field: {key_}"
    return match_.group(1)


class TestRos2OverlayStatic:
    def test_rootMetadataOnlyConfigureExportsStandardFields(self, tmp_path: Path) -> None:
        repoRoot_ = _RepoRoot()
        metadataBuild_ = tmp_path / "metadata_build"

        result_ = subprocess.run(
            [
                "cmake",
                "-S",
                str(repoRoot_),
                "-B",
                str(metadataBuild_),
                "-DPROJECT_METADATA_ONLY=ON",
            ],
            cwd=repoRoot_,
            check=False,
            capture_output=True,
            text=True,
        )

        assert result_.returncode == 0, (result_.stdout, result_.stderr)
        cacheText_ = (metadataBuild_ / "CMakeCache.txt").read_text(encoding="utf-8")
        assert _CMakeCacheValue(cacheText_, "CMAKE_PROJECT_DESCRIPTION")
        assert _CMakeCacheValue(cacheText_, "CMAKE_PROJECT_HOMEPAGE_URL").startswith("https://")
        assert _CMakeCacheValue(cacheText_, "PROJECT_MAINTAINER_NAME")
        assert "@" in _CMakeCacheValue(cacheText_, "PROJECT_MAINTAINER_EMAIL")
        assert _CMakeCacheValue(cacheText_, "PROJECT_LICENSE")
        assert "CMAKE_CXX_COMPILER:" not in cacheText_
        assert not (metadataBuild_ / "src").exists()

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

    def test_generateVersionSyncsCopiedRosPackageMetadata(self, tmp_path: Path) -> None:
        repoRoot_ = _RepoRoot()
        _SkipIfNoRos2(repoRoot_)

        scriptSource_ = repoRoot_ / "generate_version.sh"
        scriptCopy_ = tmp_path / "generate_version.sh"
        shutil.copy2(scriptSource_, scriptCopy_)
        os.chmod(scriptCopy_, 0o755)

        helperSource_ = repoRoot_ / "ros2/tools/sync_package_metadata.py"
        assert helperSource_.is_file(), "Missing structured ROS package metadata helper"
        helperCopy_ = tmp_path / "ros2/tools/sync_package_metadata.py"
        helperCopy_.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(helperSource_, helperCopy_)

        scratchDescription_ = "Scratch project metadata used by the ROS overlay test."
        scratchHomepage_ = "https://example.test/space-nav-frontend"
        scratchMaintainer_ = "Scratch Maintainer"
        scratchEmail_ = "maintainer@example.test"
        scratchLicense_ = "Apache-2.0"
        (tmp_path / "CMakeLists.txt").write_text(
            "\n".join(
                (
                    "cmake_minimum_required(VERSION 3.15)",
                    'set(project_description "Scratch project metadata used by the ROS overlay test.")',
                    'set(project_homepage_url "https://example.test/space-nav-frontend")',
                    'set(PROJECT_MAINTAINER_NAME "Scratch Maintainer" CACHE STRING "")',
                    'set(PROJECT_MAINTAINER_EMAIL "maintainer@example.test" CACHE STRING "")',
                    'set(PROJECT_LICENSE "Apache-2.0" CACHE STRING "")',
                    "project(space-nav-frontend",
                    "  VERSION 9.8.7",
                    '  DESCRIPTION "${project_description}"',
                    '  HOMEPAGE_URL "${project_homepage_url}"',
                    "  LANGUAGES NONE)",
                    "",
                )
            ),
            encoding="utf-8",
        )
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
        expectedPackageNames_: list[str] = []

        for index_, packagePath_ in enumerate(packagePaths_):
            targetPath_ = tmp_path / packagePath_.relative_to(repoRoot_)
            targetPath_.parent.mkdir(parents=True, exist_ok=True)
            text_ = packagePath_.read_text(encoding="utf-8").replace("template_project", "snf")
            text_ = _VERSION_TAG_RE.sub("<version>0.0.1</version>", text_, count=1)
            text_ = re.sub(r"<description>[^<]+</description>", "<description>stale</description>", text_, count=1)
            text_ = re.sub(
                r'<maintainer email="[^"]+">[^<]+</maintainer>',
                '<maintainer email="stale@example.test">Stale Maintainer</maintainer>',
                text_,
                count=1,
            )
            text_ = re.sub(r"<license>[^<]+</license>", "<license>stale-license</license>", text_, count=1)
            if index_ == 0:
                text_ = text_.replace(
                    "  <license>stale-license</license>",
                    "  <license>stale-license</license>\n"
                    '  <url type="repository">https://example.test/source.git</url>',
                    1,
                )
            targetPath_.write_text(text_, encoding="utf-8")
            os.chmod(targetPath_, 0o664 if index_ == 0 else 0o640)
            expectedModes_[targetPath_.relative_to(tmp_path).as_posix()] = stat.S_IMODE(
                targetPath_.stat().st_mode
            )
            packageRoot_ = ET.fromstring(text_[text_.index("<package"):])
            packageName_ = packageRoot_.findtext("name")
            assert packageName_ is not None
            expectedPackageNames_.append(packageName_)

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

        descriptionSuffixes_ = {
            "snf": "ROS 2 colcon shim package.",
            "snf_interfaces": "ROS 2 message and service interfaces.",
            "snf_ros": "ROS 2 bridge package.",
            "snf_spinup": "ROS 2 launch and runtime assets.",
        }
        syncedPackageNames_: list[str] = []
        for packageXml_ in sorted((tmp_path / "ros2").glob("*/package.xml")):
            packageRoot_ = ET.parse(packageXml_).getroot()
            packageName_ = packageRoot_.findtext("name")
            assert packageName_ is not None
            syncedPackageNames_.append(packageName_)
            assert packageRoot_.findtext("description") == (
                f"{scratchDescription_.removesuffix('.')}: {descriptionSuffixes_[packageName_]}"
            )
            maintainer_ = packageRoot_.find("maintainer")
            assert maintainer_ is not None
            assert maintainer_.text == scratchMaintainer_
            assert maintainer_.get("email") == scratchEmail_
            assert packageRoot_.findtext("license") == scratchLicense_
            websiteUrls_ = [
                url_.text
                for url_ in packageRoot_.findall("url")
                if url_.get("type") == "website"
            ]
            assert websiteUrls_ == [scratchHomepage_]
            rawText_ = packageXml_.read_text(encoding="utf-8")
            assert "<?xml-model " in rawText_

        assert syncedPackageNames_ == expectedPackageNames_
        shimText_ = (tmp_path / "ros2/template_project/package.xml").read_text(encoding="utf-8")
        assert '<url type="repository">https://example.test/source.git</url>' in shimText_
        bridgeText_ = (tmp_path / "ros2/template_project_ros/package.xml").read_text(encoding="utf-8")
        assert "<depend>snf</depend>" in bridgeText_
        assert "<depend>snf_interfaces</depend>" in bridgeText_

        syncedModes_ = {
            packageXml_.relative_to(tmp_path).as_posix(): stat.S_IMODE(
                packageXml_.stat().st_mode
            )
            for packageXml_ in sorted((tmp_path / "ros2").glob("*/package.xml"))
        }
        assert syncedModes_ == expectedModes_, (result_.stdout, result_.stderr, syncedModes_)

    def test_workflowSyncsMetadataBeforeRosdepInstall(self) -> None:
        repoRoot_ = _RepoRoot()
        _SkipIfNoRos2(repoRoot_)

        workflowText_ = (repoRoot_ / ".github/workflows/build_ros2_overlay.yml").read_text(
            encoding="utf-8"
        )
        overlayJob_, rolloutJob_ = workflowText_.split("  rollout-dogfood:", maxsplit=1)
        for jobText_ in (overlayJob_, rolloutJob_):
            installIndex_ = jobText_.find("apt-get install")
            syncIndex_ = jobText_.find("./generate_version.sh --sync-ros2")
            rosdepIndex_ = jobText_.find("rosdep install --from-paths ros2")
            assert min(installIndex_, syncIndex_, rosdepIndex_) >= 0
            assert installIndex_ < syncIndex_ < rosdepIndex_
            assert 'grep -q -- "--sync-ros2"' in jobText_
            assert 'grep -q -- "ROS2_PROJECT_METADATA_SYNC=1"' in jobText_
