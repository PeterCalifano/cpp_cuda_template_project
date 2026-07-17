# ROS 2 Overlay Review Remediation Plan

## Goal

Close every open, worthwhile issue identified by
`doc/reports/ros2_overlay_implementation_review.md` without changing the ROS 2
overlay architecture. The work repairs nested install semantics, proves that a
real project CUDA translation unit is compiled, makes release tagging
reproducible, closes the remaining runtime/tailoring/documentation coverage
gaps, and bounds core-to-overlay CI drift.

## Scope and fixed decisions

- The colcon shim, four-package split, conversions seam, lifecycle-node model,
  metadata-flowdown design, and CMake-name/ROS-prefix split remain unchanged.
- `./build_lib.sh` remains ROS-free. `./build_ros2.sh` remains the only ROS build
  entry point. `add_ros2_support.sh` remains additive to target repositories.
- The strict package-manifest version check remains a hard failure. The release
  process must satisfy the invariant; the test will not be weakened to hide a
  stale release.
- The previously resolved bytecode, metadata, dependency, rename-boundary,
  selected-package, and `--verify` findings remain protected by their existing
  tests. Do not replace those fixes while addressing open items.
- This pass may edit `src/**/CMakeLists.txt` only for the two empirically proven
  core build-contract defects in Stages 1 and 2. It must not change C++/CUDA
  APIs or implementation sources. This is the explicit, narrow exception to
  the overlay plan's former frozen-`src/` rollout invariant.
- Root `CMakeLists.txt` and `python/` are not expected to change.
- Work red-green whenever a stage adds a guard: land the failing test or
  assertion first, record the expected failure, then apply the implementation
  fix and rerun the same command.
- Do not commit or push the main repository. Keep functional staging and commit
  ownership with the user.

## Traceability

| Review item | Current disposition | Owning stage |
|---|---|---|
| M1, P1, P2, A1 | Open; six nested-path sites | Stage 1 |
| M2, P3, A2 | Resolved; regression-preservation only | Stage 7 |
| M3, P4, A4 | Open; original tag sequence needs correction | Stage 3 |
| M4, P5, A3 | Partially validated; OptiX conditional | Stage 2 |
| N1 | Open; real `.cu` source is absent from build graph | Stage 2 |
| m1, m3, m4, m6, m7, m9, A6 | Resolved; no implementation work | Stage 7 |
| Housekeeping, m2, A5 | Open | Stage 5 |
| m5, A8 runtime portion | Status-topic coverage remains | Stage 4 |
| m8, m10, A7 remainder | Open | Stage 5 |
| m11, A8 drift portion | Open | Stage 6 |

---

## Stage 0 - Baseline, evidence, and exception gate

### Baseline

- [x] Confirm the branch and capture `git status --short --branch` before any
  edit; preserve unrelated local files and generated ROS build output.
- [x] Record the reviewed baseline commit and toolchain in the stage-output log:
  CMake, compiler, ROS distro, CUDA toolkit/driver, visible GPUs, and whether an
  OptiX SDK/header is available.
- [x] Run the current non-CUDA baseline and retain the exact output:
  `./build_lib.sh -B build_review_baseline --clean` followed by
  `ctest --test-dir build_review_baseline --output-on-failure`.
- [x] Run `./build_ros2.sh --clean` and record the package/test totals.
- [x] Reconfirm that the current rollout-bytecode fixtures, metadata sync tests,
  launch tests, and shell checks are green before changing their surroundings.

### Explicit invariant exception

- [x] Add a dated follow-up subsection to
  `doc/developments/ros2_overlay_upgrade_plan.md` that authorizes only:
  `CMAKE_SOURCE_DIR` correction in six `src/**/CMakeLists.txt` files and CUDA
  source-discovery correction in seven `src/**/CMakeLists.txt` files.
- [x] State in that subsection that the exception was triggered by empirical
  installed-consumer and compile-graph evidence, not by a change in overlay
  architecture.
- [x] Add the stage-output log path and red-green evidence convention to the
  subsection so later reviewers can reconstruct each decision.

### Stage gate

- [x] `git diff --check` passes.
- [x] `git diff --stat -- CMakeLists.txt python/` is empty.
- [x] No implementation file under `src/` has changed yet.

---

## Stage 1 - Correct nested header installation and prove installed consumption

### Red test first

- [ ] Add `tests/cmake/VerifyTemplateProjectNestedInstallHeaders.cmake` and
  register `template_project_nested_install_headers` in `tests/CMakeLists.txt`
  with labels `nested;install;template`.
- [ ] In the verifier, create a scratch parent CMake project that consumes the
  template through `add_subdirectory()`, configures with CUDA/tests/wrappers
  disabled, builds, and installs to an isolated prefix.
- [ ] Assert that representative public headers exist at these installed paths:
  `include/template_project/wrapped_impl/CWrapperPlaceholder.h`,
  `include/template_project/template_src/placeholder.h`,
  `include/template_project/utils/logging/SpdlogUtils.h`, and
  `include/template_project/utils/wrap_adapters/GtsamAliases.h`.
- [ ] Assert that no top-level `wrapped_impl/`, `template_src/`, or `utils/`
  header directory appears directly under the install prefix.
- [ ] Have the verifier configure and build a second, installed-only consumer
  using `find_package(template_project CONFIG REQUIRED)`,
  `target_link_libraries(... template_project::template_project)`, and
  `#include "wrapped_impl/CWrapperPlaceholder.h"`. Do not add a source-tree
  include path to this consumer.
- [ ] Run only the new verifier and record the expected red failure showing the
  misplaced install path or missing installed include.
- [ ] Extend `VerifyTemplateProjectRos2Overlay.cmake` with a static guard that
  rejects `CMAKE_SOURCE_DIR` in module-level `src/**/CMakeLists.txt`; record that
  expected red result too.

### Root-cause fix

- [ ] Replace `CMAKE_SOURCE_DIR` with `PROJECT_SOURCE_DIR` in all six affected
  files, preserving the existing standalone path calculation:
  `src/wrapped_impl/CMakeLists.txt`, `src/utils/CMakeLists.txt`,
  `src/utils/logging/CMakeLists.txt`, `src/utils/wrap_adapters/CMakeLists.txt`,
  `src/template_src/CMakeLists.txt`, and
  `src/template_src_kernels/CMakeLists.txt`.
- [ ] Quote the path operands touched by this change if needed for paths with
  spaces, but do not otherwise refactor module ownership or installation rules.
- [ ] Remove the now-obsolete private core-source include from
  `template_project_ros_component`, which no longer contains the core-call seam.
- [ ] Keep the private core-source include on
  `template_project_ros_conversions` only for additive-rollout compatibility
  with older derived projects that adapt against non-installed headers; revise
  its comment so it does not claim to be the primary template consumption path.
- [ ] Add a workflow-side install-layout assertion after the main ROS build so a
  real colcon install also proves the header path and absence of prefix-root
  leakage.

### Green validation

- [ ] Run the new nested install verifier directly and through CTest.
- [ ] Run `./build_lib.sh -B build_review_nested --clean` and its full CTest.
- [ ] Run `./build_ros2.sh --clean`; inspect the install tree and installed
  `template_projectTarget.cmake` include directories.
- [ ] Compile the installed-only probe against the colcon install prefix as a
  second independent check.
- [ ] Confirm standalone installation layout is unchanged from its intended
  `include/template_project/...` contract.

---

## Stage 2 - Compile real CUDA sources and make GPU evidence truthful

### Red test first

- [ ] Add `tests/cmake/VerifyTemplateProjectCudaSources.cmake`, registered only
  when `ENABLE_CUDA=ON`, with labels `cuda;sources;template`.
- [ ] Make the verifier configure an isolated CUDA build with
  `CMAKE_EXPORT_COMPILE_COMMANDS=ON`, build the core target, and assert that
  `src/template_src_kernels/placeholder.cu` appears in `compile_commands.json`.
- [ ] Assert that `placeholder_to_ptx.ptx.cu` does not appear as an ordinary
  library translation unit when `ENABLE_OPTIX=OFF`; PTX inputs remain owned by
  the existing PTX embedding path.
- [ ] Record the expected red result from the current tree: CUDA compiler
  activation succeeds, but `placeholder.cu` is absent from the compile graph.
- [ ] Add a cheap static check to the existing overlay verifier that rejects the
  malformed quoted source pattern `"*.cpp; *.cu"` in all source CMake files.

### Source-discovery fix

- [ ] Replace the malformed source pattern with separate CMake list entries
  (`"*.cpp"` and `"*.cu"`) in all seven affected files:
  `src/CMakeLists.txt` plus the six module files listed in Stage 1.
- [ ] In each discovery site, explicitly filter `*.ptx.cu` out of the ordinary
  library source list so OptiX kernels are not compiled twice or with the wrong
  tool path.
- [ ] Preserve the existing `srcCudaFilesToPTX`/
  `srcCudaFilesToPTX_local` flow for dedicated PTX sources.
- [ ] Avoid adding a helper abstraction solely for these seven short, local
  discovery rules; use the same clear idiom consistently in each file.

### CUDA and OptiX validation

- [ ] Run
  `./build_lib.sh -B build_review_cuda --clean -DENABLE_CUDA=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
  and run its CUDA-labeled tests.
- [ ] Verify the real project object or compile-command entry for
  `placeholder.cu`; compiler-ID `.o`, `.ptx`, or `.fatbin` files do not count as
  evidence.
- [ ] Run
  `./build_ros2.sh --clean --cuda --cmake-arg -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
  and verify the same real project source in the nested core build graph.
- [ ] Record CUDA toolkit, driver, GPU models/architectures, date, package totals,
  test totals, and the exact project CUDA artifact in the stage-output log.
- [ ] Probe for the OptiX SDK/header. If present, run
  `./build_ros2.sh --clean --cuda --optix` and record the generated PTX/embed
  artifact. If absent, record the external prerequisite explicitly and leave no
  statement implying OptiX was validated.
- [ ] Update `doc/ros2_overlay.md` with the last validated CUDA date/toolchain
  and a truthful OptiX status; retain the statement that GitHub ROS CI is CPU
  only.

---

## Stage 3 - Define and test a tag-safe ROS metadata release process

### Documentation contract

- [ ] Add a `Release tagging with the ROS 2 overlay` subsection to
  `doc/versioning.md` and cross-link it from the version-sync section in
  `doc/ros2_overlay.md`.
- [ ] Document why a release tag must reference a commit whose four
  `package.xml` files already contain that exact release version.
- [ ] Document this release-preparation sequence without publishing the
  temporary tag:
  create a temporary local lightweight `vX.Y.Z` tag on the release-prep HEAD;
  run `./generate_version.sh --sync-ros2`; delete the temporary tag; review and
  commit synchronized manifests/metadata; create the final annotated tag on
  that commit; run all release gates with the final local tag present; then push
  the branch and tag atomically with `git push --atomic`.
- [ ] State that creating the final tag first in the GitHub UI and synchronizing
  afterward is invalid because it leaves the tagged source stale permanently.
- [ ] State that the synchronized release-preparation commit is expected to fail
  the strict version check until the final local tag is created on that commit;
  do not publish that intermediate state without the final tag. Run release
  gates only after the final local tag exists, then push branch and tag together.
- [ ] Clarify that a release source archive must include the synchronized
  manifests and resolved release metadata; an arbitrary no-Git tree without
  either is not a valid release input.

### Red-green process test

- [ ] Add `tests/cmake/VerifyTemplateProjectReleaseTagSync.cmake`, using a local
  scratch clone so it never creates, moves, or deletes tags in the working
  repository.
- [ ] In the scratch clone, create an isolated synthetic release tag, demonstrate
  that the existing strict verifier rejects stale manifests, then run the
  documented temporary-tag sync sequence.
- [ ] Commit the synchronized manifests in the scratch clone, create the final
  annotated tag on that commit, and assert with `git show <tag>:<path>` that all
  four tagged manifests contain the synthetic version.
- [ ] Run `VerifyTemplateProjectRos2Overlay.cmake` against the final tagged
  scratch tree with the synthetic version as `EXPECTED_VERSION` and require it
  to pass.
- [ ] Register the test with labels `release;version;ros2`; configure local Git
  identity inside the scratch clone and require no network access.
- [ ] Extend `VerifyTemplateProjectDocsStatic.cmake` or the ROS overlay verifier
  to require the temporary-tag, synchronized-commit, final annotated-tag, and
  atomic-push concepts in the release documentation.

---

## Stage 4 - Assert lifecycle status publication end to end

### Launch-test extension

- [ ] Extend
  `ros2/template_project_spinup/test/test_spinup_launch.py` instead of adding a
  second launch harness; preserve its standalone/composition and root/namespaced
  parameterization.
- [ ] Import `template_project_interfaces.msg.AlgorithmStatus` and create a
  subscription to `<node_path>/status` before sending the service request so a
  non-transient publication cannot be missed.
- [ ] Spin until both the service future completes and a status message arrives,
  using bounded deadlines and failure messages that identify launch mode and
  namespace.
- [ ] Assert response output `14.0` and status `ok`, then assert status-message
  fields `last_input == 3.0`, `last_output == 14.0`,
  `evaluation_count == 1`, `state == "ok"`, and a populated timestamp.
- [ ] Destroy the subscription or isolate callback state per parameterized test
  so messages cannot leak between cases.
- [ ] Do not change service availability by lifecycle state in this pass. That
  is an architecture policy choice; the requested improvement is observation of
  the existing active-state publish contract.

### Validation

- [ ] Run the launch test directly for all four cases and confirm each actually
  observes a status message rather than passing only on the service response.
- [ ] Run `./build_ros2.sh --clean` and require all ROS tests to pass without
  skips or namespace-specific flakes.
- [ ] Confirm both launch files still use lifecycle autostart and retain the
  commented externally managed alternatives intended for template tailoring.

---

## Stage 5 - Harden tailoring and documentation/evidence hygiene

### Orphan fence regression

- [ ] Extend `VerifyTemplateProjectTailoringScript.cmake` with a scratch document
  containing an orphan `<!-- ros2-overlay-end -->` marker and require
  `--apply --yes --remove-ros2` to fail nonzero.
- [ ] Record the expected red result, then update the awk end-marker branch in
  `strip_ros2_overlay_doc_fences()` to fail when it is not inside a fence.
- [ ] Retain the existing nested-begin and unclosed-begin behavior and rerun all
  three malformed-fence cases.

### Documentation precision

- [ ] Update `doc/ros2_overlay.md` to explain manual removal paths for a derived
  repository that already removed `tailor_template_cleanup.sh`.
- [ ] State that `TEMPLATE_PROJECT_ENABLE_CUDA` and
  `TEMPLATE_PROJECT_ENABLE_OPTIX` are stable overlay-facade names and
  intentionally survive project/package renaming.
- [ ] Warn that direct `--cmake-arg -DENABLE_CUDA=ON` or
  `-DENABLE_OPTIX=ON` is overwritten by the shim; users must select `--cuda`,
  `--optix`, or the documented facade variables.
- [ ] Extend `VerifyTemplateProjectRos2Overlay.cmake` with exact semantic guards
  for all three clarifications.

### Reports and stage-output ownership

- [ ] Move `ROS2_OVERLAY_STAGE_OUTPUTS.md` to
  `doc/developments/ROS2_OVERLAY_STAGE_OUTPUTS.md` with `git mv`; update every
  tracked reference and continue appending validation evidence there.
- [ ] Add `doc/reports` to both `EXCLUDE_DIRS` and `EXCLUDE_PATTERNS` in
  `doc/CMakeLists.txt` so implementation audits do not become public API pages.
- [ ] Add `doc/reports` to `template_development_paths` in
  `tailor_template_cleanup.sh` so reports do not ship in instantiated projects.
- [ ] Extend `VerifyTemplateProjectDocsStatic.cmake` to require both Doxygen
  exclusions and the tailoring ownership entry.
- [ ] Extend the tailoring fixture with a fake report and assert that default
  tailoring removes it through the template-development cleanup set.
- [ ] Build the Doxygen output and assert that the report title/file is absent
  while normal user documentation remains present.

### Stage validation

- [ ] Run `bash -n` and `shellcheck` on `tailor_template_cleanup.sh`,
  `add_ros2_support.sh`, `build_ros2.sh`, and `generate_version.sh`.
- [ ] Run the tailoring, docs-static, docs-build, and ROS overlay verifiers
  directly and through CTest.
- [ ] Re-run a default-tailoring scratch and a `--remove-ros2` scratch; confirm
  reports/development evidence are absent and user-facing docs remain coherent.

---

## Stage 6 - Bound core-to-overlay CI drift

### Workflow triggers

- [ ] Add `src/**` and `cmake/**` to both push and pull-request path filters in
  `.github/workflows/build_ros2_overlay.yml`; keep the existing root
  `CMakeLists.txt` trigger.
- [ ] Add a weekly `schedule` trigger at a low-contention UTC time so ROS/toolchain
  drift is detected even without repository changes.
- [ ] Keep `workflow_dispatch` for deliberate rehearsals and preserve the
  rollout-tooling guards that make the copied workflow valid in derived repos.
- [ ] Add the new nested-install and CUDA-source verifier paths to event filters
  if the chosen patterns do not already cover them.

### Static and runtime guards

- [ ] Extend `VerifyTemplateProjectRos2Overlay.cmake` to require each new core
  path filter in both event blocks and exactly one valid weekly schedule.
- [ ] Require the workflow's main overlay build to assert the corrected installed
  header path after `./build_ros2.sh --clean`.
- [ ] Parse the workflow with `yaml.safe_load` and inspect the trigger mapping
  through `parsed.get("on", parsed.get(True))` (PyYAML uses YAML 1.1 boolean
  coercion) so indentation or key coercion cannot silently invalidate the
  schedule.
- [ ] Rehearse both workflow jobs in `ros:jazzy`, including template mode,
  default-tailored mode, and additive-rollout mode where template-only helpers
  may be absent.

---

## Stage 7 - Derived-repo dogfood, full regression, and closeout

### Testfield update and dogfood

- [ ] Audit `../cpp_cuda_template_testfield` for the same nested-path and CUDA
  source-discovery patterns. Mirror applicable fixes without changing its real
  adapted `conversions.cpp` seam or unrelated `lib/wrap` state.
- [ ] Mirror the status-topic launch assertion, documentation clarifications,
  and workflow trigger improvements into the existing testfield overlay.
- [ ] Run testfield `./build_ros2.sh --clean` and `./build_lib.sh --clean`; record
  exact package and CTest totals.
- [ ] Do not commit the testfield changes as part of this plan unless the user
  separately approves the reviewed functional split.
- [ ] Run a fresh main-repo dogfood loop: scratch copy, default tailoring,
  `--remove-ros2`, additive re-rollout with `--verify`, clean ROS build, and
  standalone ROS-free build.

### Full main-repository gates

- [ ] Run `./build_lib.sh -B build_review_final --clean` and
  `ctest --test-dir build_review_final --output-on-failure`.
- [ ] Run
  `ctest --test-dir build_review_final -L "ros2|docs|tailoring|nested|release" --output-on-failure`
  as a focused, review-readable gate.
- [ ] Run `./build_ros2.sh --clean` and the CUDA command from Stage 2 again after
  all workflow/documentation changes.
- [ ] Run shell syntax/lint, strict Python type checks used by the metadata
  helper, Python compilation, XML parsing for every manifest, and YAML parsing
  for the workflow.
- [ ] Run exact conflict-marker and placeholder-leak scans over tracked source
  files; do not scan generated binary build trees as text.
- [ ] Run `git diff --check` and confirm the root `CMakeLists.txt` and `python/`
  remain unchanged. Review every `src/` diff against the narrow Stage 1/2
  exception list.

### Review and evidence closeout

- [ ] Append a dated `Review remediation pass` section to the relocated
  `doc/developments/ROS2_OVERLAY_STAGE_OUTPUTS.md` with red failures, green
  commands, package/test totals, CUDA artifact evidence, and any explicit OptiX
  prerequisite blocker.
- [ ] Update the addendum in
  `doc/reports/ros2_overlay_implementation_review.md` from open/partial to fixed
  only where fresh evidence supports the change; do not erase the original
  historical findings.
- [ ] Tick each item in this plan only when its implementation and named test
  are both complete.
- [ ] Perform a final code-review pass focused on install/export semantics,
  ordinary-CUDA-vs-PTX ownership, release-tag reproducibility, copied-workflow
  portability, and regressions in already-resolved findings.
- [ ] Present the user with a concise summary, validation evidence, residual
  external blockers, and a proposed functional commit split; wait for review
  and do not commit or push the main repository.

## Completion criteria

- [ ] An installed-only nested consumer resolves and compiles a public core
  header through `template_project::template_project`.
- [ ] CUDA-enabled standalone and ROS builds compile the project
  `placeholder.cu`; PTX-only input is not compiled as an ordinary source.
- [ ] A scratch final release tag contains synchronized ROS manifests and passes
  the strict overlay version verifier.
- [ ] All four launch-test variants observe and validate the lifecycle status
  message after the service call.
- [ ] Malformed fences fail, reports/evidence follow development-only policy,
  and remaining rollout docs are unambiguous.
- [ ] Core source/CMake changes and weekly scheduling trigger ROS overlay CI.
- [ ] Main and testfield native/ROS gates pass, or any external OptiX-only
  prerequisite is recorded without an unsupported success claim.
