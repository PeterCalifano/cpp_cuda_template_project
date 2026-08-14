# Template Consolidation and v2.0.0 Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking and stop at every staged-review gate.

**Goal:** Simplify canonical source packaging, preserve TensorRT as an optional
first-class feature, reconcile the changes into v2 and TestField, finish the
v2.0.0 release review, and only then realign derived repositories.

**Architecture:** A canonical source archive is built from a prepared checkout:
`generate_version.sh` synchronizes `VERSION` before CMake configures and CPack
packages that unchanged tree. CPack excludes deterministic generated paths and
the exact active binary tree without scanning arbitrary caches or claiming
public extension hooks. TensorRT discovery remains in `FindTensorRT.cmake`,
while `HandleTensorRT.cmake` owns opt-in feature activation and package export.

**Tech Stack:** CMake 3.15+, CPack, Git-derived version metadata, C++20,
optional CUDA/TensorRT, CTest, Bash, and Python 3.12+.

**Spec:** `doc/developments/template_v2_test_ownership_plan.md`, section
"Current simplification and reconciliation design" below.

## Status

- Authoritative execution tracker for the v1.12.1 prerequisite and the
  subsequent v2.0.0 test-ownership migration.
- Tracking started: 2026-07-28.
- Current stage: continuation Stage 2 TensorRT integration awaiting staged
  user review.
- Template release baseline: signed `v1.12.0` tag at
  `b277e4b84e2f1e501d6c2e73370efe0ecd101f23`.
- TestField working baseline:
  `237eb7e67e709578a0e15e812e2a7568433eb017`.
- Final commits, pushes, PR mutations, and release tags require the review gates
  stated below.

This file is the single source of truth. Do not create a separate design,
execution-plan, stage-output, discrepancy, or final-report document.

## Design

### Release sequence

1. Settle and stage the maintainable template corrections.
2. The user reviews, commits, and tags template `v1.12.1`.
3. Align TestField with that exact tag and prepare its `v1.12.1` release.
4. Move template-conformance ownership into a standalone TestField harness.
5. Remove migrated conformance tests from the template and simplify tailoring.
6. Validate both repositories and prepare, but do not create, final v2.0.0
   release tags without explicit authorization.

The v1.12.1 tag remains a correctness baseline. The v2 major boundary is the
cross-repository test-ownership change, not an intentional redesign of the
starter C++/CUDA APIs.

### Wrapper implementation

- `cmake/HandleWrapper.cmake` remains the public facade and common gtwrap
  orchestration module.
- Python-specific configuration moves to `cmake/HandlePythonWrapper.cmake`.
- MATLAB-specific configuration moves to `cmake/HandleMatlabWrapper.cmake`.
- `cmake/StagePythonRuntimeArtifacts.cmake` performs build-time validation,
  copying, and checkout-only metadata generation.
- The configuration-specific manifest uses CMake-resolved wrapper, target-file,
  and SONAME filenames. It replaces manual output-name prediction.
- One serialized staging operation validates the complete flat destination
  namespace before copying any artifact.
- The documented
  `<namespace>_GTWRAP_RUNTIME_DEPENDENCY_TARGETS` option remains public.
  Private helper signatures and layout have no compatibility requirement.
- Wheels and CMake installs remain prefix-relative and loader-relative.
  `_wrapper_build.py` remains checkout-only.
- CMake 3.15 is the compatibility floor. Do not use `cmake_path`,
  `file(COPY_FILE)`, or `CMAKE_CURRENT_FUNCTION_LIST_DIR`.

### Test ownership after v2

The template retains tests that a tailored project should inherit:

- C++ starter and dependency-free logger behavior;
- Python import smoke behavior;
- CUDA runtime initialization and placeholder behavior;
- ROS 2 runtime, conversion, node, lifecycle, service, publication, and launch
  behavior;
- MATLAB wrapper smoke behavior and target-owned dependency checks;
- reusable project fixtures.

TestField owns template-system conformance:

- every `VerifyTemplateProject*` verifier;
- source-release and release-tag verification;
- build, install, consumer, nested-build, flags, version, cross-compilation,
  CUDA, and OptiX contracts;
- Python and MATLAB wrapper conformance;
- tailoring, generated workflows, static ROS 2, and devcontainer contracts;
- logger namespace-tailoring and retained-file verification.

Normal TestField builds remain independent of a template checkout. External
conformance uses an explicit standalone harness with:

- `TEMPLATE_PROJECT_SOURCE_DIR`;
- `TEMPLATE_PROJECT_GTWRAP_SOURCE_DIR` when wrapper tests are enabled;
- `TEMPLATE_HARNESS_PROFILE=cpu|docs|cuda|ros2|all`.

The current TestField `ENABLE_TEMPLATE_PROJECT_BUILD_TESTS` facade and implicit
sibling-source discovery are removed in v2 rather than preserved through a
compatibility layer.

### Tailoring after v2

- `tests/CMakeLists.txt` is a stable starter-project test file.
- Tailoring does not rewrite root or test CMake files.
- Production wrapper modules, starter tests, MATLAB wrapper tests, and
  downstream custom tests survive unchanged except intentional project and
  namespace renaming.
- Template-development reports, conformance harnesses, and active
  template-validation workflows do not survive tailoring.
- Generic derived-project workflows remain independent of TestField.

## Execution rules

- Work red-green-refactor for every behavioral correction.
- Record the red command and expected failure before the production change.
- Append concise commands, exit status, totals, skips, warnings, and blockers
  to the owning stage evidence.
- Record every implementation discrepancy before changing the plan or design.
- Preserve user-owned or unrelated work in both repositories.
- Apply the complete staged-code documentation and readability gate before
  every review handoff.
- Do not reply to or resolve GitHub review threads during implementation.
- No additional subagents are authorized after the completed Stage 1
  maintainability review.

## Current simplification and reconciliation design

### Global constraints

- Preserve the PEP 440 `PYTHON_PACKAGE_VERSION` conversion independently of
  source-package simplification.
- Preserve `FindTensorRT.cmake` as the portable discovery module and add
  `HandleTensorRT.cmake` as the opt-in integration owner.
- Do not use `CPACK_PROJECT_CONFIG_FILE`, `CPACK_INSTALL_SCRIPT`, or
  `CPACK_INSTALL_SCRIPTS` for template-owned source-package repair.
- Require `generate_version.sh` to synchronize `VERSION` before configuring a
  release build; do not repair a stale checkout during CPack execution.
- Exclude fixed generated paths and the exact active binary directory only.
  Do not recursively scan `CMakeCache.txt` files to infer ownership.
- Keep legitimate build-prefixed source directories and foreign child-project
  caches in source archives.
- Use at least two functional commits: source-package simplification and
  TensorRT feature integration.
- Never commit, tag, push, merge, or amend without the separate authorization
  required for that exact operation.
- Stage only one reviewed batch at a time and wait for the exact keyword
  `next` after the user has committed or cleared the preceding index.
- Do not stage or commit any derived repository during propagation.

### Continuation Stage 0 - Snapshot and protect repository state

**Files:**

- Inspect the primary template Git index, branch, HEAD, and submodules.
- Inspect `/home/peterc/devDir/dev-tools/cpp_cuda_template_project-v2` paused
  merge, Git index, branch, HEAD, `MERGE_HEAD`, and submodules.
- Inspect `/home/peterc/devDir/dev-tools/cpp_cuda_template_testfield-v2` Git
  index, branch, HEAD, and submodules.

- [x] Record the primary template HEAD, branch, index hash, and worktree status
  before implementation edits.
- [x] Record the v2 template HEAD, `MERGE_HEAD`, staged-tree hash, cached-diff
  hash, and absence or presence of unstaged changes without altering the merge.
- [x] Record the TestField v2 HEAD, staged-tree hash, cached-diff hash, and
  absence or presence of unstaged changes.
- [x] Confirm that Stage 1 modifies only the primary template checkout.

Stage 0 evidence, recorded 2026-08-14:

- Primary template branch `feature/harden-ownership-and-workflow` was at
  `4fb3e386ac55ef423f1d59ad686a4a90116b25b5`; its index was empty
  (`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`)
  and only this tracker was modified to persist the plan.
- The paused v2 merge remained at HEAD
  `2ed71c4786b102b3a420846cc78bb628576b9c35` with `MERGE_HEAD`
  `403c223f4b5abb39779bf2dd858bb4110405f9bf`. Its staged tree was
  `3ced15a64dff580011af01f8c1036c62a5c34956`, its cached binary diff hash
  was `3713ba1dcd5c5d7fb5af9f7ddc9d0dd165cf619a59efdcd26ed58514b14556cc`,
  and it had no unstaged tracked changes or unresolved index entries.
- TestField v2 remained at
  `bc0604f65da01be0a5ba141aadabd5dd08cf260e`; its staged tree was
  `44e189c21b3d0a92d590fd026e54967727381a54`, its cached binary diff hash
  was `9255ddcda418a1df080fc1555456e7263822dfd76fbcfe4ecb77a68b7147728a`,
  and it had no unstaged tracked changes or unresolved index entries.
- No v2 or TestField file was changed while recording this snapshot.

### Continuation Stage 1 - Simplify canonical source-package preparation

**Files:**

- Modify `tests/cmake/VerifyTemplateProjectReleaseTagSync.cmake`.
- Modify `CMakeLists.txt`.
- Delete `cmake/StagePackageVersion.cmake.in`.
- Delete `cmake/RefreshCPackSourceIgnores.cmake.in`.
- Modify `doc/versioning.md` and this tracker.

**Produces:** A prepared-checkout release contract that preserves caller-owned
CPack extension hooks and excludes the exact active binary tree without cache
discovery.

- [x] Change the release fixture so `generate_version.sh --sync-ros2`
  synchronizes `VERSION` before configuration and no file is mutated between
  configure and CPack execution.
- [x] Add a harmless caller-owned `CPACK_PROJECT_CONFIG_FILE` fixture whose
  observable archive exclusion proves that the template does not overwrite the
  public hook.
- [x] Retain archive assertions for the exact active nested binary directory,
  ROS-generated paths, legitimate build-prefixed source content, foreign
  child-project caches, no-Git validation, and rejection of missing `VERSION`.
- [x] Remove the late-created-build and stale-source-`VERSION` expectations,
  because both violate the prepared-checkout contract.
- [x] Run the focused verifier before production edits and record the expected
  failure showing that the existing template overwrites the caller hook:
  `cmake -DTEST_TEMPLATE_SOURCE_DIR="$PWD"
  -DTEST_BINARY_ROOT=/tmp/cpp_cuda_template_source_package_red
  -P tests/cmake/VerifyTemplateProjectReleaseTagSync.cmake`.
- [x] Remove package-time `VERSION` staging and package-time ignore refresh
  wiring from `CMakeLists.txt`.
- [x] Stop excluding the synchronized source-tree `VERSION` file.
- [x] Keep deterministic `.git`, install, ROS output, pytest cache, Python
  bytecode, and active-binary-tree exclusions anchored below this checkout.
- [x] Delete the two package-time helper templates after all call sites are
  removed.
- [x] Update versioning documentation to state the clean prepared-checkout
  sequence and explain why caller-owned CPack hooks remain available.
- [x] Run the focused verifier again and require success.
- [x] Run `ctest --test-dir build --output-on-failure
  -R '^template_project_release_tag_sync$'`, the CMake-floor policy,
  `cmake --build build --target template_project_doc --parallel 4`, and
  whitespace/conflict-marker checks.
- [x] Review every candidate line for correctness, scope, CMake 3.15
  compatibility, logical-block formatting, comments, and documentation.
- [x] Stage only the Stage 1 file allowlist, inspect `git diff --cached`, run
  `git diff --cached --check`, and stop for user review without committing.

Proposed commit:

```text
[BUGFIX] Simplify canonical source package preparation

- Require synchronized source version metadata before packaging

- Exclude deterministic generated paths and the active build tree

- Stop overriding public CPack extension hooks
```

Stage 1 evidence before staging, recorded 2026-08-14:

- RED: the direct release verifier exited `1` at the new archive assertion
  `Canonical source archive ignored the caller's CPack project hook` while the
  old root CMake still replaced `CPACK_PROJECT_CONFIG_FILE`.
- GREEN: the same direct verifier exited `0` after the simplification. It
  exercised exact-tag metadata synchronization, caller policy, active nested
  binary exclusion, retained source fixtures, no-Git configuration, ROS
  metadata, and missing-`VERSION` rejection.
- GREEN: registered CTest `template_project_release_tag_sync` passed `1/1` in
  `3.68` seconds.
- GREEN: `template_project_doc` rebuilt with Doxygen 1.9.8 and exited `0`.
- GREEN: whitespace, conflict-marker, removed-helper-reference, and forbidden
  post-CMake-3.15 API scans exited `0`.
- Simplification: package-time scripts fell from 142 lines to zero; the root
  packaging policy now consists of anchored fixed exclusions plus the exact
  active binary path and does not claim a public CPack extension hook.

### Continuation Stage 2 - Promote TensorRT to an optional handled feature

**Files:**

- Modify `CMakeLists.txt`, `cmake/FindTensorRT.cmake`, `src/CMakeLists.txt`, and
  `src/cmake/template_projectConfig.cmake.in`.
- Create `cmake/HandleTensorRT.cmake`.
- Modify `tests/cmake/VerifyTemplateProjectTensorRTModule.cmake`,
  `tests/cmake/VerifyTemplateProjectNestedOptionIsolation.cmake`, `README.md`,
  `doc/Doxyfile.in`, `doc/build_script_doc.md`, `doc/template_usage.md`,
  `doc/cpp_cuda_build.md`, and this tracker.

**Consumes:** `FindTensorRT.cmake`, `TensorRT::nvinfer`,
`TensorRT::nvinfer_plugin`, and the existing CUDA option normalization.

**Produces:** `template_project_ENABLE_TENSORRT`, the top-level compatibility
alias, and a target-oriented integration path owned by
`HandleTensorRT.cmake`.

- [x] Confirm that the Stage 1 index is empty because the user committed or
  cleared it; otherwise stop without preparing this batch.
- [x] Extend the TensorRT verifier first with disabled, enabled, fake aarch64,
  source/build/install consumer, missing-package quiet/required, and unchanged
  caller `CMAKE_MODULE_PATH` cases.
- [x] Run the focused verifier and record the expected failure for the absent
  handled feature.
- [x] Add `template_project_ENABLE_TENSORRT=OFF` and a top-level legacy alias;
  normalize the option before language selection so enabling TensorRT implies
  CUDA.
- [x] Add `HandleTensorRT.cmake` to call `find_package(TensorRT REQUIRED)` and
  expose TensorRT and `CUDA::cudart` through the owning project target without
  adding global module-path state.
- [x] Define `__TENSORRT_ENABLED__=1` only for enabled consumers.
- [x] Install `FindTensorRT.cmake` and include it directly from the generated
  package config only when TensorRT was enabled at build time.
- [x] Preserve the existing portable root, environment, version, imported
  target, x86_64, and aarch64 behavior in `FindTensorRT.cmake`.
- [x] Run the focused TensorRT verifier, CPU configuration/build/tests, package
  install/consumer acceptance, documentation, and static gates.
- [x] Review and stage only the Stage 2 allowlist, inspect the complete index,
  run `git diff --cached --check`, and stop for user review without committing.

Proposed commit:

```text
[MAJOR] Add optional TensorRT feature integration

- Keep portable TensorRT discovery in the installed package

- Enable CUDA and target wiring only when TensorRT is requested

- Preserve caller module paths in build-tree and installed consumers
```

Stage 2 evidence before staging, recorded 2026-08-14:

- RED: the direct TensorRT verifier first failed because
  `cmake/HandleTensorRT.cmake` and `handle_tensorrt()` did not exist. After the
  handler was introduced, the nested-option verifier failed because the root
  did not yet expose `template_project_ENABLE_TENSORRT`.
- RED: the enabled package consumer then failed because the generated package
  config did not rediscover `TensorRT::nvinfer`. The first direct-include
  attempt exposed two CMake integration defects: the finder erased a normal
  `TensorRT_ROOT` hint under the CMake 3.15 policy baseline, and
  `FindPackageHandleStandardArgs` observed the outer package name.
- RED: the real CUDA root acceptance finally failed because the exported
  project omitted its TensorRT interface target. This proved that standalone
  discovery alone was insufficient for build/install consumers.
- GREEN: the direct TensorRT verifier and nested-option verifier both exited
  `0`. The registered tests passed `2/2`; the TensorRT verifier covered
  canonical and compatibility roots, x86_64 and aarch64 archive layouts,
  disabled and enabled handlers, build/install package consumers, missing SDK
  QUIET/REQUIRED behavior, and a real CUDA configure/build/install/consumer
  chain using local stub TensorRT libraries.
- GREEN: `./build_lib.sh --clean -j 4` configured and built the default CPU
  project with TensorRT disabled and passed `32/32` tests. Doxygen 1.9.8 built
  `template_project_doc`, and whitespace, conflict-marker, CMake-floor API, and
  removed-helper scans exited `0`.
- Simplification: the final handler removed an unused parent-scope configured
  flag and owns one stable interface target. TensorRT and OptiX join the export
  set through independent conditions, while the root owns their shared CUDA
  prerequisite. The root project description remains unchanged, avoiding an
  unrelated ROS manifest metadata expansion; the two affected ROS tests and
  the full CPU suite passed after that scope correction.

### Continuation Stage 3 - Consolidate and version the template repositories

- [ ] Confirm that the user created both reviewed primary-template commits and
  that the primary index is empty.
- [ ] Re-run clean CPU, source archive, version, TensorRT, wrapper, tailoring,
  documentation, shell, Python, JSON/YAML/XML, whitespace, and conflict-marker
  gates against the exact committed primary tree.
- [ ] Stop for explicit merge authorization before integrating the reviewed
  feature branch into the primary release branch.
- [ ] Verify the resulting primary release-branch SHA and tree rather than
  assuming merge equivalence.
- [ ] Preserve a hash-based record of the paused v2 merge, then replace that
  obsolete merge with one integration from the exact finalized primary SHA.
- [ ] Reconcile v2 by removing `StagePackageVersion.cmake.in` and
  `RefreshCPackSourceIgnores.cmake.in`, retaining the prepared-checkout CPack
  policy, and aligning its TensorRT feature with `HandleTensorRT.cmake`.
- [ ] Reconcile the v2 development tracker and all directly dependent docs.
- [ ] Stage the coherent v2 reconciliation batch and stop for user review
  without committing or tagging.
- [ ] After the user commits v2, synchronize release metadata with
  `./generate_version.sh --sync-ros2`, validate the exact candidate with the
  intended local `v2.0.0` tag present, and verify the no-Git CPack archive.
- [ ] Stop for separate user authorization before creating, pushing, or
  publishing the `v2.0.0` tag.

### Continuation Stage 4 - Align TestField with the post-simplification v2

- [ ] Confirm that the v2 template index is empty and record its exact reviewed
  commit SHA before changing TestField.
- [ ] Reconcile the staged TestField harness with the prepared-checkout source
  package contract and the handled TensorRT feature.
- [ ] Remove expectations for package-time repair, late-build cache scanning,
  and copied helper templates.
- [ ] Preserve TestField ownership of template conformance rather than copying
  those recursive verifiers into derived projects.
- [ ] Run CPU, source-package, TensorRT, wrapper, tailoring, docs, CUDA/OptiX
  where available, ROS 2 where available, and static validation profiles.
- [ ] Stage only the coherent TestField v2 batch and stop for user review
  without committing or tagging.
- [ ] After the user commits TestField, validate the exact paired template and
  TestField SHAs and stop for separate authorization before any TestField
  `v2.0.0` tag or push.

### Continuation Stage 5 - Final reconciliation before propagation

- [ ] Confirm primary template, v2 template, and TestField histories contain
  the reviewed commits and have clear indexes.
- [ ] Confirm release metadata, package filenames, ROS manifests, and no-Git
  archive validation all resolve exactly to `v2.0.0`.
- [ ] Compare template and TestField conformance inventories and account for
  every removed, retained, or transferred assertion.
- [ ] Record exact commands, exit codes, test counts, skips, toolchain limits,
  artifact hashes, and repository SHAs in this tracker.
- [ ] Obtain the user's explicit confirmation that consolidation, commits, and
  versioning are complete before beginning propagation.

### Continuation Stage 6 - Audit and realign derived repositories

**Roots:**

- `/home/peterc/devDir`
- `/media/peterc/SCRATCH_PRO/devDir/event-based-repos`

- [ ] Discover Git repositories under both roots and identify template-derived
  candidates from owned CMake, wrapper, packaging, and documentation markers.
- [ ] Record each candidate repository, branch, HEAD, dirty state, imported
  template version when identifiable, and matching overcomplex CPack/TensorRT
  changes before editing any repository.
- [ ] Exclude the primary template, its worktrees, TestField, unrelated
  repositories, generated build trees, vendored dependencies, and submodules
  from propagation targets.
- [ ] For every affected derived repository, remove imported package-time
  `VERSION` staging, recursive cache scanning, and template-owned public CPack
  hook overrides; align its archive contract to a prepared checkout and its
  exact active binary directory.
- [ ] Preserve and align TensorRT only where the derived project already owns
  or requests that optional feature; use its local namespace and targets rather
  than mechanically copying template names.
- [ ] Do not import template-only recursive conformance tests into ordinary
  derived-project CTest suites.
- [ ] Review each derived diff for local ownership, behavior, formatting,
  comments, documentation, and unnecessary complexity.
- [ ] Run the smallest honest local configure/build/test/package acceptance for
  each affected repository and record environment-dependent skips.
- [ ] Leave every derived repository unstaged and uncommitted, then report the
  per-repository changes and verification for user review.

### Continuation Stage 7 - Final report

- [ ] Confirm no unauthorized commit, tag, push, or derived-repository staging
  occurred.
- [ ] Summarize the final architecture, exact repository SHAs, staged or
  unstaged state, validations, caveats, and remaining user actions.
- [ ] Mark the tracked goal complete only when all authorized work and review
  gates have genuinely finished.

## Stage 0 - Baseline and plan rebase

- [x] Inspect the current template and TestField branches, tags, indexes, and
  submodule state.
- [x] Inspect PR 28 review threads and map them to the owning contracts.
- [x] Complete one independent maintainability review with a second agent.
- [x] Rebase the v2 goal on v1.12.1 followed by the ownership migration.
- [x] Remove obsolete spdlog, broad cache-quota, action-version, and unrelated
  CI-modernization objectives from the active plan.
- [x] Establish this file as the only active tracker.
- [x] Seed the known discrepancy ledger.

### Stage 0 evidence

- Template branch: `bugfix/clean-wrapper-packaging-safety`.
- Template HEAD: `b277e4b84e2f1e501d6c2e73370efe0ecd101f23`,
  exactly signed tag `v1.12.0`.
- Template index at baseline: six staged files, `318` insertions and `16`
  deletions.
- TestField branch: `main`, one unpushed commit ahead of `origin/main`.
- TestField HEAD: `237eb7e67e709578a0e15e812e2a7568433eb017`.
- TestField index at baseline: ten staged files.
- TestField wrap submodule:
  `55f7cf30f47972a7055266bd4308614e8fe8aca2`.
- Toolchain: CMake 3.28.3, Python 3.12.3, GCC/G++ 13.3.0, CUDA 12.9.
- `ros2` was not initially on `PATH`; ROS 2 Jazzy was later located under
  `/opt/ros/jazzy` and the clean overlay acceptance completed.
- PR 28:
  - resolved/outdated interpreter-directory review is represented by
    `b277e4b`;
  - resolved runtime-collision review is superseded by the planned simplified
    staging design;
  - unresolved absolute-install-directory review is covered by the staged
    rejection;
  - unresolved nested-source review is covered by cache-ownership validation.
- Remote CI validates committed `v1.12.0`, not the staged v1.12.1 candidate.

## Stage 1 - Template v1.12.1 hardening

### Tests first

- [x] Change the collision fixture so configuration succeeds and wrapper
  staging fails before copying any colliding artifact.
- [x] Add runtime-versus-wrapper-extension collision coverage.
- [x] Add target-file-versus-SONAME collision coverage where the host platform
  produces distinct names.
- [x] Add generator-expression/configuration-specific output-name coverage.
- [x] Add active nested binary-tree and foreign-cache source-archive coverage.
- [x] Record each expected red result.

### Implementation

- [x] Split the wrapper module along the approved responsibility boundaries.
- [x] Remove the configure-time output-name analyzer.
- [x] Generate one configuration-specific resolved-artifact manifest.
- [x] Use one staging target that validates, copies, then writes metadata.
- [x] Batch runtime target properties and install rules.
- [x] Preserve exact runtime validation, RPATH, SONAME, wheel, install, and
  incremental-refresh contracts.
- [x] Reject absolute CMake Python install destinations.
- [x] Exclude only the active or cache-proven checkout-owned build trees from
  source archives.
- [x] Update tailoring fixtures so all production wrapper modules survive.
- [x] Update wrapper, usage, tailoring, testing, and callable/file
  documentation.

### Validation

- [x] Run focused wrapper packaging verification.
- [x] Run focused release/source-archive verification.
- [x] Run tailoring verification and a scratch tailored-wrapper acceptance.
- [x] Run a clean CPU build and full CTest suite.
- [x] Run documentation validation.
- [x] Run CUDA validation with the available toolchain.
- [x] Run ROS 2 validation when the installed distribution is available.
- [x] Run shell, Python, YAML/XML, conflict-marker, whitespace, and generated
  artifact checks.
- [x] Inspect the complete index under the staged-code quality gate.
- [x] Stage one coherent template batch.

### Stage 1 evidence

- RED, runtime collision timing:
  `cmake -DTEST_TEMPLATE_SOURCE_DIR="$PWD"
  -DTEST_BINARY_ROOT=/tmp/cpp_cuda_template_tdd_runtime_collision
  -P tests/cmake/VerifyTemplateProjectPythonPackaging.cmake` exited `1`.
  The new configure-success assertion caught the old
  `_collect_python_runtime_destination_names()` path rejecting
  `colliding_runtime` during configuration, before build-time staging.
- RED, wrapper/runtime namespace: the wrapper-collision fixture configured and
  built successfully, allowing the runtime copy and extension linker to write
  `fixture_package.so` in the same staging directory.
- RED, target-file/SONAME namespace: the Linux fixture configured and built
  successfully even though one target file resolved to another target's
  `libsoname_collision.so.2` SONAME destination.
- RED, generator-expression output: configuration with
  `FIXTURE_GENERATOR_OUTPUT_NAME=ON` exited `1` because the manual analyzer
  rejected the generator expression before CMake could resolve the active
  configuration filename.
- RED, active nested source build:
  `cmake -DTEST_TEMPLATE_SOURCE_DIR="$PWD"
  -DTEST_BINARY_ROOT=/tmp/cpp_cuda_template_tdd_source_release
  -P tests/cmake/VerifyTemplateProjectReleaseTagSync.cmake` exited `1` because
  the canonical archive contained `generated/current_output`. The same fixture
  also requires foreign-cache and nested `install` source content to remain.
- GREEN, focused wrapper:
  `cmake -DTEST_TEMPLATE_SOURCE_DIR="$PWD"
  -DTEST_BINARY_ROOT=/tmp/cpp_cuda_template_focus_wrapper
  -P tests/cmake/VerifyTemplateProjectPythonPackaging.cmake` exited `0`.
- GREEN, focused release:
  `cmake -DTEST_TEMPLATE_SOURCE_DIR="$PWD"
  -DTEST_BINARY_ROOT=/tmp/cpp_cuda_template_focus_release
  -P tests/cmake/VerifyTemplateProjectReleaseTagSync.cmake` exited `0`.
- GREEN, tailoring:
  `cmake -DTEST_TEMPLATE_SOURCE_DIR="$PWD"
  -DTEST_BINARY_ROOT=/tmp/cpp_cuda_template_focus_tailoring
  -P tests/cmake/VerifyTemplateProjectTailoringScript.cmake` exited `0`.
- GREEN, tailored wrapper acceptance: a full scratch copy was tailored with
  `--project-namespace tailored_project`; the external Python packaging
  verifier then exited `0` against the tailored source.
- GREEN after ISSUE-007 repair, clean CPU:
  `./build_lib.sh --clean -j 4` exited `0`; CTest passed `28/28`.
- GREEN, documentation:
  `cmake --build build --target template_project_doc --parallel 4` exited `0`
  with Doxygen 1.9.8.
- GREEN, clean CUDA:
  `./build_lib.sh -B build_cuda_v112 --clean -DENABLE_CUDA=ON -j 4` exited
  `0`; CUDA 12.9.41 selected `sm_120` and CTest passed `31/31`.
- GREEN, clean ROS 2 Jazzy:
  `source /opt/ros/jazzy/setup.bash && ./build_ros2.sh --clean` exited `0`.
  Colcon built all four packages and reported `10` tests with `0` errors,
  `0` failures, and `0` skips.
- GREEN, static and repository hygiene:
  - Bash syntax passed for the root build, ROS, tailoring, version, and
    devcontainer helpers.
  - ShellCheck passed for `tailor_template_cleanup.sh`.
  - Python byte-compilation passed for every tracked Python file.
  - all workflow YAML and ROS package XML parsed successfully;
  - whitespace and conflict-marker checks passed;
  - the wrapper modules contain none of the CMake APIs forbidden by the 3.15
    compatibility floor.
- GREEN, post-review regression:
  `ctest --test-dir build --output-on-failure -j 4` exited `0`; CTest passed
  `28/28` after the final documentation and common-state simplification.
- CMake-floor audit: the host provides CMake 3.28.3 rather than a 3.15 binary.
  The staged wrapper and release constructs were checked against CMake 3.15
  documentation and the repository's forbidden-newer-API scan passed.
- Maintainability: the public facade fell from 1,410 to 579 lines. Python
  handling is isolated in 658 lines, MATLAB handling in 53 lines, and the
  build-time validator in 148 lines. The no-op direct-pybind entrypoint and its
  root-CMake call/status path were removed. Common Python-executable resolution
  is centralized in the facade rather than duplicated by both language
  frontends.

### Stage 1 review gate

Stop with the template staged and uncommitted. The user reviews the batch,
creates the release commit, and creates the annotated `v1.12.1` tag. Do not
push or mutate PR threads.

Proposed title:

`[BUGFIX] Simplify wrapper packaging and source release safety`

Proposed description:

- Resolve Python runtime filenames at build time and reject every flat-package
  collision before copying artifacts.
- Split Python, MATLAB, and runtime-staging responsibilities out of the common
  wrapper facade while preserving the documented wrapper options.
- Keep source archives precise by excluding only active or cache-proven build
  trees, including parallel-configure race coverage.
- Retain production wrapper modules through tailoring and document the updated
  packaging and test-ownership contracts.

## Stage 2 - TestField v1.12.1 alignment

- [ ] Verify the reviewed template tag and synchronized release metadata.
- [ ] Reconcile the existing TestField index with the exact v1.12.1 tag.
- [ ] Port production behavior while preserving TestField identity, APIs, ROS
  adaptations, and local tests.
- [ ] Keep template conformance external to normal TestField CTest.
- [ ] Maintain one combined v1.12.1 sync document, design first and plan second.
- [ ] Run CPU, docs, CUDA, ROS 2, wrapper, wheel, install/consumer, cleanup, and
  release-archive acceptance.
- [ ] Apply the complete staged-code quality gate.
- [ ] Amend the existing unpushed signed documentation commit into one coherent
  v1.12.1 alignment commit.
- [ ] Stop without pushing for user review and TestField v1.12.1 tagging.

Proposed title:

`[BUGFIX] Align TestField with template v1.12.1 packaging`

## Stage 3 - TestField-owned v2 harness

- [ ] Inventory every conformance test, label, timeout, prerequisite, resource
  lock, skip, and behavioral assertion.
- [ ] Create the standalone TestField harness and explicit profile inputs.
- [ ] Move template-system conformance implementations into TestField while
  their original template counterparts remain available for parity.
- [ ] Keep TestField local tests independent of the candidate template.
- [ ] Remove the main-project external-test facade and implicit sibling path.
- [ ] Compare old and new inventories and results against the same candidate.
- [ ] Resolve every unexplained lost or duplicated assertion.
- [ ] Update only CI wiring required for full-SHA sibling harness execution.

## Stage 4 - Template reduction and tailoring simplification

- [ ] Remove migrated template-conformance implementations and registrations
  only after Stage 3 parity is green.
- [ ] Retain all starter-project runtime tests and fixtures.
- [ ] Make `tests/CMakeLists.txt` stable for derived projects.
- [ ] Remove root- and test-CMake rewriting from tailoring.
- [ ] Preserve production wrapper modules and downstream custom tests.
- [ ] Run default and `--remove-ros2` tailoring twice for idempotence.
- [ ] Build and test both tailored results.
- [ ] Prove tailored projects contain no TestField or template-conformance
  dependency.

## Stage 5 - Integrated v2 validation and release preparation

- [ ] Run TestField local tests without a template checkout.
- [ ] Run all applicable standalone harness profiles.
- [ ] Run clean CPU, docs, CUDA/OptiX, ROS 2, wrapper, install/consumer,
  release, shell, Python, YAML, XML, and Git-hygiene gates.
- [ ] Verify source releases inside and outside an unrelated parent Git
  repository.
- [ ] Inspect both complete indexes under the staged-code quality gate.
- [ ] Re-run the highest-risk wrapper, harness, tailoring, and release gates.
- [ ] Prepare one functional ownership batch per repository and only an
  unavoidable later compatibility-pin batch.
- [ ] Stop before pushes or final v2.0.0 tags unless explicitly authorized.

## Discrepancy and issue ledger

Entries remain in this ledger after resolution.

### ISSUE-001 - Stale v2 baseline and bundled scope

- Stage: 0
- Severity: worthwhile
- Expected: an executable ownership-migration plan based on the current release.
- Observed: the old plan used v1.11.1, retained removed spdlog behavior, and
  bundled unrelated CI/cache modernization.
- Action: rebase on the v1.12.1 prerequisite and retain only work required by
  conformance ownership.
- Status: resolved by this plan revision.

### ISSUE-002 - Configure-time runtime-name approximation

- Stage: 1
- Severity: blocking
- Expected: validate the actual filenames staged for the active configuration.
- Observed: `_collect_python_runtime_destination_names()` manually approximates
  CMake naming across configurations, rejects generator expressions, adds more
  than one hundred lines, and does not cover the wrapper extension namespace.
- Action: replace it with generated resolved-artifact manifests and one
  build-time staging operation.
- Status: resolved. Resolved filenames are validated by the generated manifest
  during the wrapper build.

### ISSUE-003 - Multi-config checkout metadata

- Stage: 1
- Severity: blocking
- Expected: checkout metadata identifies the artifacts staged for the active
  configuration.
- Observed: configuration-time metadata can contain configuration-dependent
  target paths while all configurations share one package workspace.
- Action: write metadata from the serialized staging operation and document
  that one configuration populates the shared checkout package at a time.
- Status: resolved. The staging operation writes metadata only after the active
  configuration validates and copies successfully.

### ISSUE-004 - Active nested build archive exclusion

- Stage: 1
- Severity: worthwhile
- Expected: the active binary tree never enters the source archive.
- Observed: cache discovery during the first configure may not discover the
  active binary directory yet.
- Action: exclude an active binary directory below the source root explicitly;
  require exact cache ownership for every other nested directory.
- Status: resolved. The active nested binary directory is explicit; all other
  exclusions still require exact cache ownership.

### ISSUE-005 - TestField candidate is superseded

- Stage: 2
- Severity: blocking
- Expected: TestField aligns with the reviewed template v1.12.1 tag.
- Observed: its staged wrapper port and combined document still target
  v1.12.0 and the superseded configure-time analyzer.
- Action: reconcile, replace, and retest only after the Stage 1 release gate.
- Status: open.

### ISSUE-006 - Remote evidence does not cover the index

- Stage: 1
- Severity: environment
- Expected: validation evidence covers the exact candidate delivered for review.
- Observed: current successful GitHub checks cover only committed v1.12.0.
- Action: run fresh local acceptance against the complete staged candidate and
  report remote CI as pending until a push is authorized.
- Status: open.

### ISSUE-007 - Archive cache scan races parallel configure tests

- Stage: 1
- Severity: blocking
- Expected: source-package ownership discovery ignores build trees already
  excluded by stable top-level policy and remains safe during parallel CTest.
- Observed: the clean CPU run passed 27 of 28 tests. The version-side-effect
  configure failed when `file(STRINGS)` tried to read another test's transient
  `build/.../CMakeScratch/.../CMakeCache.txt` after that file disappeared.
- Evidence: `./build_lib.sh --clean -j 4` exited `8`; CTest reported
  `96% tests passed, 1 tests failed out of 28`.
- Root cause: recursive cache discovery descends into the conventional
  top-level `build*` tree even though that entire tree is already excluded from
  source archives.
- Action: add a deterministic dangling transient-cache regression under a
  top-level build tree, then filter already-ignored and already-owned trees
  before reading candidate caches.
- Verification:
  - the dangling-cache source-release regression exited `0`;
  - `ctest --test-dir build --output-on-failure
    -R '^template_project_version_no_source_side_effect$'` passed `1/1`.
- Status: resolved. Candidate caches already covered by stable top-level ignore
  rules or a known active build are filtered before any cache read.

### ISSUE-008 - CMake 3.15 runtime is unavailable locally

- Stage: 1
- Severity: environment
- Expected: execute the focused packaging and release verifiers with the
  declared minimum CMake version.
- Observed: this host provides CMake 3.28.3 and no separate 3.15 executable.
- Action: audit the staged constructs against the CMake 3.15 documentation,
  reject known newer APIs statically, and rely on authorized remote
  minimum-version CI for an exact-runtime check.
- Status: open as a conditional environment limitation; no staged construct
  was found outside the documented 3.15 API surface.

## Final Status Review and Report

### Stage 1 interim release gate - 2026-07-28

- State:
  - branch `bugfix/clean-wrapper-packaging-safety`;
  - unchanged HEAD `b277e4b84e2f1e501d6c2e73370efe0ecd101f23`,
    exactly tagged `v1.12.0`;
  - `16` related files staged with `1,852` insertions and `1,314` deletions,
    with no unstaged tracked files;
  - no template commit, new tag, push, PR mutation, or TestField change was
    made.
- Implemented behavior:
  - runtime names are resolved for the active configuration and validated as
    one flat namespace before any copy;
  - checkout metadata is written only by the serialized staging operation;
  - absolute CMake Python library destinations are now rejected;
  - active and cache-proven nested build trees are excluded from source
    archives without dropping legitimate similarly named sources;
  - public wrapper cache options remain intact. Private helper signatures and
    the no-op direct-pybind entrypoint are not retained.
- Review disposition:
  - the interpreter-directory and runtime-collision reviews are represented by
    the corrected implementation;
  - the absolute-install and nested-source review findings are implemented and
    locally verified;
  - GitHub review threads were intentionally not mutated.
- Validation:
  - first clean CPU attempt exposed ISSUE-007 at `27/28`; its deterministic
    regression, focused rerun, and clean rerun passed;
  - clean CPU passed `28/28`, clean CUDA passed `31/31`, and the final reviewed
    CPU rerun passed `28/28`;
  - ROS 2 Jazzy built four packages and reported `10` tests, `0` errors,
    `0` failures, and `0` skips;
  - documentation, focused packaging, source release, tailoring, tailored-copy
    packaging, shell, Python, YAML, XML, whitespace, conflict-marker, and
    generated-artifact checks passed.
- Maintainability:
  - the 1,410-line facade is now a 579-line common coordinator;
  - Python, MATLAB, and build-time staging have explicit module ownership;
  - common executable resolution is deduplicated;
  - new and substantially modified modules have file-level, callable, and
    non-obvious-block documentation;
  - wrapper, usage, testing, tailoring, and historical-plan documentation is
    aligned.
- Open or deferred:
  - ISSUE-005 remains blocked on the reviewed `v1.12.1` tag;
  - ISSUE-006 remains open because remote CI cannot cover an unpushed index;
  - ISSUE-008 records the unavailable local CMake 3.15 runtime;
  - Stages 2 through 5 intentionally remain pending.
- Readiness: the template Stage 1 batch is ready for user review. The remaining
  user actions are to review the index, create the release commit with the
  proposed title and bullets, create the annotated `v1.12.1` tag, and then
  authorize Stage 2 TestField alignment.

The final integrated v2.0.0 report remains pending until Stages 2 through 5
complete.
