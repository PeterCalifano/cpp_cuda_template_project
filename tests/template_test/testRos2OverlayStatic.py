"""Behavioral and structured-data tests for the optional ROS 2 overlay."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from email.headerregistry import Address
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import xml.etree.ElementTree as ET

import pytest


@dataclass(frozen=True)
class CProjectMetadata:
    """Project metadata exported by a metadata-only CMake configure.

    Example:
        metadata_ = CProjectMetadata("Description", "https://example.test", "A", "a@example.test", "MIT")
        print(metadata_.license)
        # Output: MIT
    """

    description: str
    homepage: str
    maintainerName: str
    maintainerEmail: str
    license: str


def _RepoRoot() -> Path:
    """Return the template repository root.

    Example:
        print(_RepoRoot().name)
        # Output: cpp_cuda_template_project
    """
    return Path(__file__).resolve().parents[2]


def _SkipIfNoRos2(repoRoot_: Path) -> None:
    """Skip pytest checks when tailoring removed the overlay.

    Example:
        _SkipIfNoRos2(_RepoRoot())
        print("overlay present")
        # Output: overlay present
    """
    if not (repoRoot_ / "ros2").is_dir():
        pytest.skip("ROS 2 overlay is not present in this tailored project")


def _PackageXmlPaths(repoRoot_: Path) -> list[Path]:
    """Return immediate ROS package manifests.

    Example:
        print(all(path_.name == "package.xml" for path_ in _PackageXmlPaths(_RepoRoot())))
        # Output: True
    """
    return sorted((repoRoot_ / "ros2").glob("*/package.xml"))


def _IsStrictVersion(version_: str) -> bool:
    """Return whether a value is a strict three-component numeric version.

    Example:
        print(_IsStrictVersion("1.2.3"))
        # Output: True
    """
    components_: list[str] = version_.split(".")
    return len(components_) == 3 and all(
        component_.isdecimal()
        and (component_ == "0" or not component_.startswith("0"))
        for component_ in components_
    )


def _PackageRoot(packageXml_: Path) -> ET.Element:
    """Parse and return a package manifest root element.

    Example:
        print(_PackageRoot(_PackageXmlPaths(_RepoRoot())[0]).tag)
        # Output: package
    """
    root_ = ET.parse(packageXml_).getroot()
    assert root_.tag == "package", packageXml_
    return root_


def _PackageVersion(packageXml_: Path) -> str:
    """Return a package manifest's semantic version value.

    Example:
        print(_PackageVersion(_PackageXmlPaths(_RepoRoot())[0]).count("."))
        # Output: 2
    """
    version_: str | None = _PackageRoot(packageXml_).findtext("version")
    assert version_ is not None, packageXml_
    return version_.strip()


def _ReadKeyValueFile(filePath_: Path) -> dict[str, str]:
    """Read colon-separated generated metadata fields without regular expressions.

    Example:
        # fields_ = _ReadKeyValueFile(Path("VERSION"))
        # Output: fields_["Project version core"] == "1.11.0"
    """
    fields_: dict[str, str] = {}
    for line_ in filePath_.read_text(encoding="utf-8").splitlines():
        key_, separator_, value_ = line_.partition(":")
        if separator_:
            fields_[key_.strip()] = value_.strip()
    return fields_


def _ReadVersionCore(versionFile_: Path) -> str:
    """Read the strict core value from new or legacy VERSION output.

    Example:
        # version_ = _ReadVersionCore(Path("VERSION"))
        # Output: version_ == "1.11.0"
    """
    fields_ = _ReadKeyValueFile(versionFile_)
    for fieldName_ in ("Project version core", "Project version"):
        version_: str | None = fields_.get(fieldName_)
        if version_ is not None and _IsStrictVersion(version_):
            return version_
    raise AssertionError(f"No strict core version found in {versionFile_}")


def _ReadCMakeCache(cachePath_: Path) -> dict[str, str]:
    """Read generated CMake cache entries into a key/value mapping.

    Example:
        # cache_ = _ReadCMakeCache(Path("build/CMakeCache.txt"))
        # Output: cache_["CMAKE_PROJECT_NAME"] == "template_project"
    """
    cache_: dict[str, str] = {}
    for line_ in cachePath_.read_text(encoding="utf-8").splitlines():
        keyAndType_, separator_, value_ = line_.partition("=")
        if not separator_ or keyAndType_.startswith(("//", "#")):
            continue
        key_, typeSeparator_, _ = keyAndType_.partition(":")
        if typeSeparator_:
            cache_[key_] = value_
    return cache_


def _MetadataFromCache(cachePath_: Path) -> CProjectMetadata:
    """Construct project metadata from a generated CMake cache.

    Example:
        # metadata_ = _MetadataFromCache(Path("build/CMakeCache.txt"))
        # Output: metadata_.homepage starts with "https://"
    """
    cache_ = _ReadCMakeCache(cachePath_)
    keys_: tuple[str, ...] = (
        "CMAKE_PROJECT_DESCRIPTION",
        "CMAKE_PROJECT_HOMEPAGE_URL",
        "PROJECT_MAINTAINER_NAME",
        "PROJECT_MAINTAINER_EMAIL",
        "PROJECT_LICENSE",
    )
    for key_ in keys_:
        assert cache_.get(key_), (cachePath_, key_)
    return CProjectMetadata(
        description=cache_["CMAKE_PROJECT_DESCRIPTION"],
        homepage=cache_["CMAKE_PROJECT_HOMEPAGE_URL"],
        maintainerName=cache_["PROJECT_MAINTAINER_NAME"],
        maintainerEmail=cache_["PROJECT_MAINTAINER_EMAIL"],
        license=cache_["PROJECT_LICENSE"],
    )


def _DescriptionSuffix(packageName_: str) -> str:
    """Return the role-specific description suffix for a ROS package.

    Example:
        print(_DescriptionSuffix("demo_interfaces"))
        # Output: ROS 2 message and service interfaces.
    """
    if packageName_.endswith("_interfaces"):
        return "ROS 2 message and service interfaces."
    if packageName_.endswith("_ros"):
        return "ROS 2 bridge package."
    if packageName_.endswith("_spinup"):
        return "ROS 2 launch and runtime assets."
    return "ROS 2 colcon shim package."


def ValidateRos2Manifests(
    repoRoot_: Path,
    expectedVersion_: str,
    metadataCachePath_: Path | None = None,
) -> None:
    """Validate ROS manifests through ElementTree and optional CMake metadata.

    Example:
        # ValidateRos2Manifests(_RepoRoot(), "1.11.0")
        # Output: returns without error when all manifests match
    """
    assert _IsStrictVersion(expectedVersion_), expectedVersion_
    packagePaths_ = _PackageXmlPaths(repoRoot_)
    assert packagePaths_, repoRoot_
    metadata_: CProjectMetadata | None = (
        _MetadataFromCache(metadataCachePath_)
        if metadataCachePath_ is not None
        else None
    )

    for packagePath_ in packagePaths_:
        root_ = _PackageRoot(packagePath_)
        packageName_: str | None = root_.findtext("name")
        assert packageName_ == packagePath_.parent.name, packagePath_
        assert _PackageVersion(packagePath_) == expectedVersion_, packagePath_

        description_: str | None = root_.findtext("description")
        license_: str | None = root_.findtext("license")
        maintainer_ = root_.find("maintainer")
        assert description_ and description_.strip(), packagePath_
        assert license_ and license_.strip(), packagePath_
        assert maintainer_ is not None and maintainer_.text, packagePath_
        assert maintainer_.get("email"), packagePath_
        websiteUrls_: list[str] = [
            (url_.text or "").strip()
            for url_ in root_.findall("url")
            if url_.get("type") == "website"
        ]
        assert len(websiteUrls_) == 1 and websiteUrls_[0].startswith("https://"), (
            packagePath_,
            websiteUrls_,
        )

        if metadata_ is None:
            continue
        descriptionBase_ = metadata_.description.removesuffix(".")
        assert description_ == (
            f"{descriptionBase_}: {_DescriptionSuffix(packageName_)}"
        ), packagePath_
        assert maintainer_.text == metadata_.maintainerName, packagePath_
        assert maintainer_.get("email") == metadata_.maintainerEmail, packagePath_
        assert license_ == metadata_.license, packagePath_
        assert websiteUrls_ == [metadata_.homepage], packagePath_


def _PrepareManifestFixture(
    sourcePath_: Path, targetPath_: Path, packagePrefix_: str, addRepositoryUrl_: bool
) -> tuple[str, int]:
    """Create a stale copied-manifest fixture using ElementTree.

    Example:
        # name_, mode_ = _PrepareManifestFixture(source_, target_, "demo", False)
        # Output: target_ contains stale metadata while preserving its XML preamble
    """
    sourceText_ = sourcePath_.read_text(encoding="utf-8")
    packageIndex_ = sourceText_.index("<package")
    preamble_ = sourceText_[:packageIndex_]
    root_ = ET.fromstring(sourceText_[packageIndex_:])

    for element_ in root_.iter():
        if element_.text is not None:
            element_.text = element_.text.replace("template_project", packagePrefix_)
    version_ = root_.find("version")
    description_ = root_.find("description")
    maintainer_ = root_.find("maintainer")
    license_ = root_.find("license")
    assert version_ is not None
    assert description_ is not None
    assert maintainer_ is not None
    assert license_ is not None
    version_.text = "0.0.1"
    description_.text = "stale"
    maintainer_.text = "Stale Maintainer"
    maintainer_.set("email", "stale@example.test")
    license_.text = "stale-license"
    if addRepositoryUrl_:
        repositoryUrl_ = ET.Element("url", {"type": "repository"})
        repositoryUrl_.text = "https://example.test/source.git"
        root_.insert(list(root_).index(license_) + 1, repositoryUrl_)

    ET.indent(root_, space="  ")
    targetPath_.parent.mkdir(parents=True, exist_ok=True)
    targetPath_.write_text(
        f"{preamble_}{ET.tostring(root_, encoding='unicode')}\n",
        encoding="utf-8",
    )
    packageName_: str | None = root_.findtext("name")
    assert packageName_ is not None
    return packageName_, stat.S_IMODE(targetPath_.stat().st_mode)


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
        cachePath_ = metadataBuild_ / "CMakeCache.txt"
        metadata_ = _MetadataFromCache(cachePath_)
        assert metadata_.homepage.startswith("https://")
        maintainerAddress_ = Address(addr_spec=metadata_.maintainerEmail)
        assert maintainerAddress_.username
        assert maintainerAddress_.domain
        assert "CMAKE_CXX_COMPILER" not in _ReadCMakeCache(cachePath_)
        assert not (metadataBuild_ / "src").exists()

    def test_packageMetadataMatchesRootProject(self, tmp_path: Path) -> None:
        repoRoot_ = _RepoRoot()
        _SkipIfNoRos2(repoRoot_)
        metadataBuild_ = tmp_path / "metadata_build"
        subprocess.run(
            [
                "cmake",
                "-S",
                str(repoRoot_),
                "-B",
                str(metadataBuild_),
                "-DPROJECT_METADATA_ONLY=ON",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        versionFile_ = repoRoot_ / "VERSION"
        expectedVersion_ = (
            _ReadVersionCore(versionFile_)
            if versionFile_.exists()
            else next(iter({_PackageVersion(path_) for path_ in _PackageXmlPaths(repoRoot_)}))
        )
        ValidateRos2Manifests(
            repoRoot_, expectedVersion_, metadataBuild_ / "CMakeCache.txt"
        )

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

    def test_buildScriptFailsBeforeMutationWithoutRosEnvironment(self) -> None:
        repoRoot_ = _RepoRoot()
        _SkipIfNoRos2(repoRoot_)
        generatedPaths_: tuple[Path, ...] = tuple(
            repoRoot_ / "ros2" / name_ for name_ in ("build", "install", "log")
        )
        existedBefore_: dict[Path, bool] = {
            path_: path_.exists() for path_ in generatedPaths_
        }
        environment_: dict[str, str] = dict(os.environ)
        environment_["ROS_DISTRO"] = "template_contract_missing"
        result_ = subprocess.run(
            ["bash", str(repoRoot_ / "build_ros2.sh"), "--skip-tests"],
            cwd=repoRoot_,
            env=environment_,
            check=False,
            capture_output=True,
            text=True,
        )
        assert result_.returncode != 0
        assert {path_: path_.exists() for path_ in generatedPaths_} == existedBefore_

    def test_generateVersionSyncsCopiedRosPackageMetadata(self, tmp_path: Path) -> None:
        repoRoot_ = _RepoRoot()
        _SkipIfNoRos2(repoRoot_)

        scriptCopy_ = tmp_path / "generate_version.sh"
        shutil.copy2(repoRoot_ / "generate_version.sh", scriptCopy_)
        scriptCopy_.chmod(0o755)
        helperCopy_ = tmp_path / "ros2/tools/sync_package_metadata.py"
        helperCopy_.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repoRoot_ / "ros2/tools/sync_package_metadata.py", helperCopy_)

        scratchDescription_ = "Scratch project metadata used by the ROS overlay test."
        scratchHomepage_ = "https://example.test/space-nav-frontend"
        scratchMaintainer_ = "Scratch Maintainer"
        scratchEmail_ = "maintainer@example.test"
        scratchLicense_ = "Apache-2.0"
        (tmp_path / "CMakeLists.txt").write_text(
            "\n".join(
                (
                    "cmake_minimum_required(VERSION 3.15)",
                    f'set(project_description "{scratchDescription_}")',
                    f'set(project_homepage_url "{scratchHomepage_}")',
                    f'set(PROJECT_MAINTAINER_NAME "{scratchMaintainer_}" CACHE STRING "")',
                    f'set(PROJECT_MAINTAINER_EMAIL "{scratchEmail_}" CACHE STRING "")',
                    f'set(PROJECT_LICENSE "{scratchLicense_}" CACHE STRING "")',
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

        expectedModes_: dict[Path, int] = {}
        expectedNames_: list[str] = []
        for index_, packagePath_ in enumerate(_PackageXmlPaths(repoRoot_)):
            tailoredPackageName_ = packagePath_.parent.name.replace(
                "template_project", "snf"
            )
            targetPath_ = tmp_path / "ros2" / tailoredPackageName_ / "package.xml"
            packageName_, _ = _PrepareManifestFixture(
                packagePath_, targetPath_, "snf", index_ == 0
            )
            targetPath_.chmod(0o664 if index_ == 0 else 0o640)
            expectedModes_[targetPath_] = stat.S_IMODE(targetPath_.stat().st_mode)
            expectedNames_.append(packageName_)

        result_ = subprocess.run(
            ["bash", str(scriptCopy_)],
            cwd=tmp_path,
            check=False,
            capture_output=True,
            text=True,
        )
        assert result_.returncode == 0, (result_.stdout, result_.stderr)

        metadataBuild_ = tmp_path / "metadata_validation"
        subprocess.run(
            [
                "cmake",
                "-S",
                str(tmp_path),
                "-B",
                str(metadataBuild_),
                "-DPROJECT_METADATA_ONLY=ON",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        ValidateRos2Manifests(
            tmp_path,
            _ReadVersionCore(tmp_path / "VERSION"),
            metadataBuild_ / "CMakeCache.txt",
        )

        syncedPaths_ = sorted((tmp_path / "ros2").glob("*/package.xml"))
        assert [_PackageRoot(path_).findtext("name") for path_ in syncedPaths_] == (
            expectedNames_
        )
        repositoryUrls_: list[str | None] = [
            url_.text
            for url_ in _PackageRoot(tmp_path / "ros2/snf/package.xml").findall("url")
            if url_.get("type") == "repository"
        ]
        assert repositoryUrls_ == ["https://example.test/source.git"]
        bridgeDependencies_: set[str] = {
            dependency_.text or ""
            for dependency_ in _PackageRoot(
                tmp_path / "ros2/snf_ros/package.xml"
            ).findall("depend")
        }
        assert {"snf", "snf_interfaces"} <= bridgeDependencies_
        assert {
            path_: stat.S_IMODE(path_.stat().st_mode) for path_ in syncedPaths_
        } == expectedModes_

        # The XML model instruction is generated representation deliberately
        # preserved byte-for-byte by the synchronizer, so an exact marker check
        # is appropriate here.
        assert all(
            "<?xml-model " in path_.read_text(encoding="utf-8")
            for path_ in syncedPaths_
        )

        firstBytes_: dict[Path, bytes] = {path_: path_.read_bytes() for path_ in syncedPaths_}
        secondResult_ = subprocess.run(
            ["bash", str(scriptCopy_)],
            cwd=tmp_path,
            check=False,
            capture_output=True,
            text=True,
        )
        assert secondResult_.returncode == 0, secondResult_.stderr
        assert {path_: path_.read_bytes() for path_ in syncedPaths_} == firstBytes_

    def test_generateVersionNoSyncOptOutPreservesRosMetadata(
        self,
        tmp_path: Path,
    ) -> None:
        repoRoot_ = _RepoRoot()
        _SkipIfNoRos2(repoRoot_)

        scriptCopy_ = tmp_path / "generate_version.sh"
        shutil.copy2(repoRoot_ / "generate_version.sh", scriptCopy_)
        helperCopy_ = tmp_path / "ros2/tools/sync_package_metadata.py"
        helperCopy_.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repoRoot_ / "ros2/tools/sync_package_metadata.py", helperCopy_)

        packageSource_ = _PackageXmlPaths(repoRoot_)[0]
        packageTarget_ = tmp_path / "ros2" / packageSource_.parent.name / "package.xml"
        packageTarget_.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(packageSource_, packageTarget_)
        bytesBefore_ = packageTarget_.read_bytes()
        (tmp_path / "VERSION").write_text(
            "Project version core: 9.8.7\n"
            "Project version prerelease: <none>\n"
            "Project version metadata: <none>\n"
            "Full version: 9.8.7\n",
            encoding="utf-8",
        )

        result_ = subprocess.run(
            ["bash", str(scriptCopy_), "--no-sync-ros2"],
            cwd=tmp_path,
            check=False,
            capture_output=True,
            text=True,
        )

        assert result_.returncode == 0, (result_.stdout, result_.stderr)
        assert packageTarget_.read_bytes() == bytesBefore_


def _Main(arguments_: list[str]) -> int:
    """Run the manifest validator for CMake release fixtures.

    Example:
        # _Main(["--repo-root", ".", "--expected-version", "1.11.0"])
        # Output: 0 when manifests satisfy the contract
    """
    parser_ = argparse.ArgumentParser()
    parser_.add_argument("--repo-root", type=Path, required=True)
    parser_.add_argument("--expected-version", required=True)
    parser_.add_argument("--metadata-cache", type=Path)
    options_ = parser_.parse_args(arguments_)
    ValidateRos2Manifests(
        options_.repo_root,
        options_.expected_version,
        options_.metadata_cache,
    )
    return 0


if __name__ == "__main__":
    sys.exit(_Main(sys.argv[1:]))
