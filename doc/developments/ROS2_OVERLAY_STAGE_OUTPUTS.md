# ROS 2 Overlay Stage Outputs

Temporary repo-local log requested on 2026-07-07. This file backfills the stage closeouts already recorded in `CONTEXT.md` and will be appended at each remaining stage closeout. No commits or pushes are made by Codex.

## Stage 0 - Plan doc + colcon hygiene

Summary:
- Wrote `doc/developments/ros2_overlay_upgrade_plan.md` as the source of truth.
- Added colcon ignore markers for `python/`, `lib/`, `examples/`, and `tests/`.
- Added `ros2/build`, `ros2/install`, and `ros2/log` ignore coverage.

Validation:
- `./build_lib.sh -B build_stage0 --skip-tests`
- `git status --short` reviewed for intended additions.

Proposed commit message:

```text
Document ROS 2 overlay plan and colcon hygiene
```

## Stage 1 - `ros2/` workspace shim and `build_ros2.sh`

Summary:
- Added `ros2/template_project/` as the colcon shim package.
- Added `ros2/template_project_interfaces/` with `AlgorithmStatus.msg` and `RunAlgorithm.srv`.
- Added root `build_ros2.sh` with ROS environment guard, colcon build/test flow, CUDA/OptiX facade flags, clean mode, and generated-directory `COLCON_IGNORE` handling.
- Kept the root CMake, `src/`, and `python/` trees untouched.

Validation:
- `bash -n build_ros2.sh`
- `./build_ros2.sh --clean`
- `grep -R "^ENABLE_CUDA:BOOL=OFF$" ros2/build/template_project/CMakeCache.txt`
- Installed config files checked under `ros2/install/template_project/lib/cmake/template_project/`.
- `./build_lib.sh -B build_stage1 --skip-tests`
- `git diff --stat CMakeLists.txt src/ python/`
- `git diff --check`

Proposed commit message:

```text
Add ROS 2 overlay workspace shim and build script
```

## Stage 2 - `template_project_ros` bridge and spinup packages

Summary:
- Added `ros2/template_project_ros/` with node-free conversions, lifecycle component, executable, and ROS tests.
- Added `ros2/template_project_spinup/` with standalone and composition launch files plus default config.
- Kept conversions free of `rclcpp` and confined the template core API touchpoint to the fenced lifecycle-node block.
- Kept the root CMake, `src/`, and `python/` trees untouched.

Validation:
- Initial red run: `./build_ros2.sh --clean` failed on missing `template_project_ros` headers.
- Green run: `./build_ros2.sh --clean` built all four packages and colcon reported `5 tests, 0 errors, 0 failures, 0 skipped`.
- Standalone launch smoke: `source ros2/install/setup.bash && ros2 launch template_project_spinup template_project.launch.py`.
- Composition launch smoke loaded `template_project_ros::CTemplateLifecycleNode`.
- `./build_lib.sh -B build_stage2 --skip-tests`
- `ctest --test-dir build_stage2 -R tailoring --output-on-failure`
- `git diff --stat CMakeLists.txt src/ python/`
- `git diff --check`

Proposed commit message:

```text
Add ROS 2 bridge and spinup packages
```

## Stage 3 - Version sync and static validation

Summary:
- Added `generate_version.sh --sync-ros2` while preserving default `VERSION` behavior.
- Enforced `build_ros2.sh` automatic guarded `./generate_version.sh --sync-ros2` invocation.
- Added `tests/cmake/VerifyTemplateProjectRos2Overlay.cmake`.
- Added auto-registered pytest coverage in `tests/template_test/testRos2OverlayStatic.py`.

Validation:
- Initial red CMake verifier failed because `generate_version.sh` did not advertise `--sync-ros2`.
- Initial red pytest failed because `VERSION` was stale and copied ROS manifests were not rewritten.
- `./generate_version.sh --sync-ros2`
- `./build_lib.sh -B build_stage3`
- `ctest --test-dir build_stage3 -R "ros2" --output-on-failure`
- `git diff --stat CMakeLists.txt src/ python/`
- `git diff --check`
- `bash -n generate_version.sh build_ros2.sh`

Proposed commit message:

```text
Add ROS 2 overlay version sync validation
```

## Stage 4 - Tailoring keep/remove policy

Summary:
- Extended `tailor_template_cleanup.sh` so the ROS overlay is kept by default.
- Added `--remove-ros2` to remove `ros2/`, root overlay entry points, markers, future workflow/doc paths, and static pytest coverage.
- Added fence stripping for future ROS doc sections while keeping `generate_version.sh` untouched.
- Extended the tailoring verifier with fake ROS overlay fixtures.

Validation:
- Initial red CMake verifier failed because cleanup did not mention `tests/cmake/VerifyTemplateProjectRos2Overlay.cmake`.
- `./build_lib.sh -B build_stage4 --skip-tests`
- `ctest --test-dir build_stage4 -R tailoring --output-on-failure`
- Scratch copy `/tmp/cpp_cuda_template_stage4_remove_t7GiKn`: `./tailor_template_cleanup.sh --apply --yes --remove-ros2` then `./build_lib.sh --skip-tests`.
- `git diff --stat CMakeLists.txt src/ python/`
- `git diff --check`
- `bash -n tailor_template_cleanup.sh generate_version.sh build_ros2.sh`

Proposed commit message:

```text
Add ROS 2 overlay tailoring removal path
```

## Stage 5 - Additive rollout script

Summary:
- Added root `add_ros2_support.sh`.
- Implemented `--list`, `--apply [--yes]`, `--root <dir>`, `--verify`, and `--no-ci`.
- Made rollout source validation require `ros2/` and `build_ros2.sh`.
- Made target validation scrape `set(project_name "<name>")`, enforce `[a-z][a-z0-9_]*`, and refuse targets that already contain `ros2/` or `build_ros2.sh`.
- Kept rollout purely additive: no existing target file edits, no self-copy, no template verifier copy, no generated colcon directory copy.
- Added identifier-aware rename behavior and CMake configure-only verification.
- Extended the ROS overlay verifier with fake target rollout coverage.

Validation:
- Initial red CMake verifier failed because `add_ros2_support.sh` was missing.
- `./build_lib.sh -B build_stage5 --skip-tests`
- `ctest --test-dir build_stage5 -R ros2_overlay --output-on-failure`
- Temporary scratch copy: remove overlay, re-add with `add_ros2_support.sh --apply --yes --verify`, then `./build_ros2.sh --clean`.
- Scratch overlay build reported `5 tests, 0 errors, 0 failures, 0 skipped`.
- `git diff --stat CMakeLists.txt src/ python/`
- `git diff --check`
- `bash -n add_ros2_support.sh tailor_template_cleanup.sh generate_version.sh build_ros2.sh`

Proposed commit message:

```text
Add additive ROS 2 overlay rollout script
```

## Stage 6 - ROS 2 overlay CI workflow

Summary:
- Added `.github/workflows/build_ros2_overlay.yml`.
- Added the `overlay-build` job for Jazzy container CI: full-depth checkout, ROS dependency install, `./build_ros2.sh --clean`, and static pytest coverage.
- Added the `rollout-rehearsal` job: copy checkout, remove overlay, re-add with `add_ros2_support.sh --verify`, rebuild the ROS overlay, then run a plain standalone CMake build.
- Added a minimal `doc/ros2_overlay.md` CUDA/CI note: overlay CI is CPU-only; local CUDA/OptiX checks use `./build_ros2.sh --cuda` or `./build_ros2.sh --cuda --optix`.
- Extended the ROS overlay static verifier for the workflow contract, no `src/**` trigger, checkout depth, dependency commands, no CUDA CI command, and minimal CUDA documentation.
- Left `build_linux.yml`, `build_linux_cuda.yml`, and `docs_pages.yml` untouched.

Validation:
- Initial red verifier failed because `.github/workflows/build_ros2_overlay.yml` was missing.
- Direct Stage 6 CMake verifier passed.
- `./build_lib.sh -B build_stage6 --skip-tests`
- `ctest --test-dir build_stage6 -R ros2_overlay --output-on-failure`
- YAML sanity parse with Python `yaml.safe_load`.
- `bash -n add_ros2_support.sh tailor_template_cleanup.sh generate_version.sh build_ros2.sh`
- Docker `ros:jazzy` overlay-build rehearsal: dependency install, `rosdep install`, `./build_ros2.sh --clean`, and pytest; colcon reported `5 tests, 0 errors, 0 failures, 0 skipped`, pytest reported `5 passed`.
- Docker `ros:jazzy` rollout rehearsal: remove overlay, re-add overlay with `--verify`, `./build_ros2.sh --clean`, and plain `cmake -S . -B build_plain -DENABLE_TESTS=OFF && cmake --build build_plain -j2`.
- `git diff --stat CMakeLists.txt src/ python/`
- `git diff -- .github/workflows/build_linux.yml .github/workflows/build_linux_cuda.yml .github/workflows/docs_pages.yml`
- `git diff --check`

Proposed commit message:

```text
Add ROS 2 overlay CI and rollout rehearsal workflow
```

## Stage 7 - Documentation and rollout instructions

Summary:
- Expanded `doc/ros2_overlay.md` with the architecture, shim/export contract, conversions-vs-node split, build usage, CUDA option flow, `COLCON_IGNORE` policy, version sync, rollout, removal, CI, and Python-boundary notes.
- Added removable ROS overlay fences to `README.md`, `AGENTS.md`, `CLAUDE.md`, `doc/bootstrap_prompts.md`, and `doc/template_usage.md`.
- Added the ROS 2 Overlay Rollout Prompt and the ROS package rename map.
- Moved the README ROS 2 devcontainer example into a removable fence so `--remove-ros2` leaves no README ROS 2 references.
- Extended the ROS overlay static verifier to enforce the Stage 7 doc content and fence coverage.

Validation:
- Initial red verifier failed because `doc/ros2_overlay.md` lacked `Encapsulation contract`.
- Direct Stage 7 CMake verifier passed.
- `./build_lib.sh -B build_stage7 --skip-tests`
- `ctest --test-dir build_stage7 -L "ros2|docs" --output-on-failure` passed `4/4`.
- `bash -n add_ros2_support.sh tailor_template_cleanup.sh generate_version.sh build_ros2.sh`
- Scratch copy `/tmp/cpp_cuda_template_stage7_remove_Z6MicP`: `./tailor_template_cleanup.sh --apply --yes --remove-ros2`, `./build_lib.sh --skip-tests`, and grep confirmed no ROS 2 overlay references remained in README; AGENTS/CLAUDE were removed by tailoring.
- `git diff --stat CMakeLists.txt src/ python/`
- `git diff --check`

Proposed commit message:

```text
Document ROS 2 overlay rollout and removal workflow
```

## Stage 8 - Testfield mirroring (in progress, blocked)

Summary:
- Applied the overlay to `../cpp_cuda_template_testfield` with `add_ros2_support.sh --apply --yes --verify`.
- Adapted the fenced testfield lifecycle-node core call to `cpp_playground::CWrapperPlaceholder::multiplyBy2(...)`.
- Updated the testfield ROS workflow to use its dependency checkout and `TEMPLATE_PROJECT_SOURCE_DIR` convention.
- Added source-overlay compatibility fixes for older derived repos: shim `VERSION` mirroring and lifecycle-component source include/core link support.
- Fixed the main docs workflow verifier to canonicalize `TEST_TEMPLATE_SOURCE_DIR` before assertions, so derived/testfield CTest runs that pass `../cpp_cuda_template_project` agree with Doxygen's normalized input paths.

Validation:
- Red: initial testfield `./build_ros2.sh --clean` failed on missing nested `template_project_core/VERSION`.
- Red: next testfield `./build_ros2.sh --clean` failed because the lifecycle component could not include `wrapped_impl/CWrapperPlaceholder.h`.
- Green: latest testfield `./build_ros2.sh --clean` built four packages and reported `5 tests, 0 errors, 0 failures, 0 skipped`.
- Green: testfield `./build_lib.sh --skip-tests` passed.
- Green: main direct ROS overlay verifier passed.
- Green: main `./build_lib.sh -B build_stage8 --skip-tests` passed.
- Green: main `ctest --test-dir build_stage8 -R ros2_overlay --output-on-failure` passed `1/1`.
- Green: main `./build_ros2.sh --clean` reported `5 tests, 0 errors, 0 failures, 0 skipped`.
- Green: workflow YAML parse and bash syntax checks passed.
- Green: `git diff --check` passed in both repos, and main protected diff `CMakeLists.txt src/ python/` is empty.
- Green: direct docs verifier reproduction with a `../cpp_cuda_template_project` source path passed after canonicalization.
- Green: focused testfield docs CTest `ctest --test-dir build -R 'template_project_docs_build_output|testfield_docs_build_output' --output-on-failure` passed `2/2`.
- Green: latest full testfield `./build_lib.sh` rerun passes both docs tests.
- Red: a later plain `./build_lib.sh` rerun without cleaning exited 8 with `80% tests passed, 8 tests failed out of 40`; two extra failures were stale-cache wrong-format objects (`EM: 183`) in `build/tests/testfield_subbuild` after cross tests.
- Red: clean `(cd ../cpp_cuda_template_testfield && ./build_lib.sh --clean)` exited 8 with `85% tests passed, 6 tests failed out of 39`; docs/nested/cross tests passed and the remaining failures were the same wrapper/Python-environment set.
- Blocked: persistent failing tests are `template_project_python_package_installs_and_imports`, `template_project_python_package_rejects_python311`, `template_project_matlab_wrapper_script_runs`, `testfield_matlab_wrapper_script_runs`, `testfield_matlab_wrapper_tcmalloc_present`, and `template_project_build_lib_python_wrap_succeeds_without_false_warning`.
- Blocker root causes shown in the fresh output: unresolved conflict markers in `/home/peterc/devDir/dev-tools/wrap/gtwrap/pybind_wrapper.py` and `/home/peterc/devDir/dev-tools/wrap/gtwrap/matlab_wrapper/wrapper.py`, plus missing `pytest` in `/home/peterc/miniconda3/envs/test_env/bin/python3.12`.

Proposed commit message:

```text
Validate ROS 2 overlay rollout in testfield
```

## Delta fix pass - 2026-07-07

Scope:
- Closed only the review-delta subsections for Stages 2, 5, 6, and 7.
- Did not start Stage 8 or Stage 9.
- Left root `CMakeLists.txt`, `src/`, and `python/` diffs empty.

Summary:
- Moved the editable core-call seam to `ros2/template_project_ros/src/conversions.cpp`: the wrapped implementation include and `EvaluateTemplateCore` body now carry the fenced EDIT-ME markers.
- Kept `CTemplateLifecycleNode.cpp` ROS-only, with a short cross-reference to `conversions.cpp`.
- Documented why `template_project_ros_conversions` and `template_project_ros_component` keep the private source include compatibility path.
- Hardened `add_ros2_support.sh`: empty/binary copied files no longer abort the rename pass, `target_is_clean()` replaces the inverted conflict helper name, and `--verify` scratch directories are cleaned by an EXIT trap.
- Updated the rollout checklist and `doc/ros2_overlay.md` to name `conversions.cpp` as the primary adaptation seam.
- Added `generate_version.sh` to both ROS overlay workflow path filters.
- Extended `VerifyTemplateProjectRos2Overlay.cmake` so the seam, checklist, helper naming, scratch cleanup, doc pointer, and workflow trigger cannot regress.

Red evidence:
- Focused verifier failed before the fixes because the Stage 2 guard expected the new compatibility/seam contract and `ros2/template_project_ros/CMakeLists.txt` did not yet contain the `older derived repo` rationale.
- Scratch reproduction with an empty file in a copied `ros2/` tree exited 1 before the `grep -Iq . "${file_path_}" || return 0` fix.

Green evidence:
- Direct verifier: `cmake -DTEST_TEMPLATE_SOURCE_DIR="$PWD" -DTEST_BINARY_ROOT="$PWD/build_delta_green/ros2_overlay" -DEXPECTED_VERSION=1.10.3 -P tests/cmake/VerifyTemplateProjectRos2Overlay.cmake`.
- Empty-file rollout reproduction after the fix passed in `/tmp/ros2_delta_empty_green_my18I3`.
- `./build_lib.sh -B build_deltas` passed `24/24`.
- `ctest --test-dir build_deltas -L "ros2|docs|tailoring" --output-on-failure` passed `5/5`.
- `./build_ros2.sh --clean` passed; colcon reported `5 tests, 0 errors, 0 failures, 0 skipped`.
- Current-state rollout validation passed in a temporary scratch copy: `tailor_template_cleanup.sh --apply --yes --remove-ros2`, `add_ros2_support.sh --apply --yes --verify`, `build_ros2.sh --clean`, and `build_lib.sh --skip-tests`.
- `bash -n build_ros2.sh add_ros2_support.sh` passed.
- `shellcheck build_ros2.sh add_ros2_support.sh` passed.
- YAML parse of `.github/workflows/build_ros2_overlay.yml` passed with Python `yaml.safe_load`.
- `git diff --stat CMakeLists.txt src/ python/` stayed empty.
- `git diff --check` passed.

Review pass:
- Searched for stale primary-node EDIT-ME pointers and the old `target_has_conflicts` helper. Only the intentional verifier guard string remains.
- Confirmed `generate_version.sh` appears exactly twice in `.github/workflows/build_ros2_overlay.yml`, once per path filter block.
- Confirmed the only remaining unchecked plan items are the explicitly out-of-scope Stage 8 and Stage 9 items.

Proposed commit message:

```text
Close ROS 2 overlay review deltas
```

## Stage 8 - Testfield mirroring closure

Summary:
- Rechecked the previous external blockers and cleared the remaining conflict-marker residue in tracked pybind11 test files:
  - `/home/peterc/devDir/dev-tools/wrap/pybind11/tests/test_eigen_matrix.cpp`;
  - `/home/peterc/devDir/dev-tools/cpp_cuda_template_testfield/lib/wrap/pybind11/tests/test_eigen_matrix.cpp`.
- Confirmed `/home/peterc/miniconda3/envs/test_env/bin/python3.12` now has `pytest`.
- Brought the testfield ROS overlay into line with the Stage 2 review-delta seam relocation:
  - `../cpp_cuda_template_testfield/ros2/template_project_ros/src/conversions.cpp` now carries the fenced EDIT-ME include/body seam and calls `cpp_playground::CWrapperPlaceholder::multiplyBy2(...)`;
  - `../cpp_cuda_template_testfield/ros2/template_project_ros/src/CTemplateLifecycleNode.cpp` delegates to `EvaluateTemplateCore` and stays ROS-only.
- Added the same source-include compatibility comments to the testfield ROS CMake.
- Updated the testfield ROS overlay workflow path filters to include `generate_version.sh` while preserving its `TEMPLATE_PROJECT_SOURCE_DIR` sibling-checkout convention.

Validation:
- Conflict-marker scan for `<<<<<<<`, `>>>>>>>`, and `|||||||` over the template, testfield, and wrap checkouts: no hits.
- `git -C ../cpp_cuda_template_testfield diff --check`: passed.
- `bash -n ../cpp_cuda_template_testfield/build_ros2.sh`: passed.
- YAML parse of `../cpp_cuda_template_testfield/.github/workflows/build_ros2_overlay.yml`: passed.
- `git -C ../cpp_cuda_template_testfield diff --stat CMakeLists.txt src/ python/`: empty.
- `(cd ../cpp_cuda_template_testfield && ./build_ros2.sh --clean)`: built four packages and reported `5 tests, 0 errors, 0 failures, 0 skipped`.
- `(cd ../cpp_cuda_template_testfield && ./build_lib.sh --clean)`: passed `39/39`.

Proposed commit message:

```text
Mirror ROS 2 overlay into testfield
```

## Stage 9 - Final audit and verification closure - 2026-07-07

Scope:
- Closed the final audit/minimization pass after the Stage 2/5/6/7 review deltas and Stage 8 testfield mirror were complete.
- Left root `CMakeLists.txt`, `src/`, and `python/` diffs empty.
- Made one final lint-only correction in `generate_version.sh`: quoted the `SCRIPT_DIR` prefix inside parameter expansion so the version-sync path trimming passes shellcheck `SC2295`.
- No commits or pushes were made.

Review evidence:
- `rg -n "template_project_nodes|bringup|PROFILE_CORE|dummy" ros2/ doc/ --glob '!doc/developments/ros2_overlay_upgrade_plan.md'`: no matches.
- `rg -n "rclcpp" ros2/template_project_ros/include/template_project_ros/conversions.h ros2/template_project_ros/src/conversions.cpp`: no matches.
- `git diff --stat CMakeLists.txt src/ python/`: empty.
- `bash -n build_ros2.sh add_ros2_support.sh tailor_template_cleanup.sh generate_version.sh`: passed.
- `shellcheck build_ros2.sh add_ros2_support.sh tailor_template_cleanup.sh generate_version.sh`: passed after the `generate_version.sh` quoting fix.
- YAML parse of `.github/workflows/build_ros2_overlay.yml` with Python `yaml.safe_load`: passed.
- Scratch tailoring both ways passed in `/tmp/ros2_stage9_tailoring_quiet_werRGa`: default cleanup kept `ros2/` and `build_ros2.sh`, `--remove-ros2` removed the overlay files, and both resulting trees built with `./build_lib.sh --skip-tests`.

Fresh local test evidence:
- `./build_lib.sh --clean`: passed.
- `ctest --test-dir build --output-on-failure`: passed `24/24`.
- After the shellcheck quoting fix, `ctest --test-dir build --output-on-failure` was rerun and passed `24/24`.
- `./build_ros2.sh --clean`: passed.
- After the shellcheck quoting fix, `./build_ros2.sh --clean` was rerun and colcon reported `5 tests, 0 errors, 0 failures, 0 skipped`.

Docker CI rehearsal evidence:
- Docker version: `29.6.1`.
- Overlay-build rehearsal in `ros:jazzy` passed in scratch copy `/tmp/ros2_stage9_docker_overlay_ehkFzn`; colcon reported `5 tests, 0 errors, 0 failures, 0 skipped`, and `python3 -m pytest -q tests/template_test/testRos2OverlayStatic.py` reported `5 passed`.
- Rollout rehearsal in `ros:jazzy` passed in a temporary scratch copy; the stripped target re-added the overlay with `add_ros2_support.sh --apply --yes --verify`, `./build_ros2.sh --clean` reported `5 tests, 0 errors, 0 failures, 0 skipped`, and the plain `cmake -S . -B build_plain -DENABLE_TESTS=OFF && cmake --build build_plain -j2` build completed.
- One earlier rollout rehearsal failed because the local rehearsal harness used an over-broad tar exclude that removed `build_lib.sh`; rerunning with the workflow's narrower excludes passed.

Detailed temporary command logs:
- `/tmp/ros2_overlay_verify_20260707_175226`

Final sanity checks:
- `git diff --check`: passed.
- `git diff --stat CMakeLists.txt src/ python/`: empty.
- `rg -n "^- \[ \]" doc/developments/ros2_overlay_upgrade_plan.md`: no unchecked plan boxes.
- Conflict marker scan over the template, testfield, and wrap checkouts for `<<<<<<<`, `>>>>>>>`, and `|||||||`: no matches.

Known non-fatal warning:
- The standalone and Docker builds can still print the existing GCC/spdlog `-Warray-bounds` warning from the core build path; it did not fail any gate.

Proposed commit message:

```text
Complete optional ROS 2 overlay upgrade
```

## Delta follow-up fix pass - 2026-07-08

Scope:
- Fixed the stale rollout EDIT-ME seam pointers that still named `CTemplateLifecycleNode.cpp` in `doc/bootstrap_prompts.md`, `doc/template_usage.md`, and the testfield `doc/ros2_overlay.md`; all now name `ros2/<project>_ros/src/conversions.cpp` as the primary core-call seam.
- Extended `add_ros2_support.sh` to split the target CMake package name from the copied ROS package prefix:
  - `space-nav-frontend` now rolls out to ROS package paths such as `ros2/space_nav_frontend_ros`;
  - bridge CMake still preserves core `find_package(space-nav-frontend REQUIRED)` and `space-nav-frontend::space-nav-frontend` links;
  - `--ros-prefix <name>` can override the derived ROS prefix.
- Added static guard coverage so stale seam docs, missing workflow path filters, and the split-name rollout case fail the ROS overlay verifier.
- Documented the manual tailoring path for derived repos that remove optional CUDA, OptiX, or spdlog support.
- Ticked the follow-up item in `doc/developments/ros2_overlay_upgrade_plan.md`.
- No commits or pushes were made.

Red/green evidence:
- Initial `python3 -m pytest -q tests/template_test/testRos2OverlayStatic.py` failed because `doc/bootstrap_prompts.md` did not mention `conversions.cpp`; after the doc fixes it passed `6 passed`.
- Initial direct CMake verifier failed because `add_ros2_support.sh` did not support `--ros-prefix`; after the rollout-script fix it passed.
- The first full docs gate exposed a Doxygen warning on the inline hyphenated CMake target example; moving the example into a fenced CMake block fixed `template_project_docs_build_output`.

Validation:
- `./build_lib.sh -B build_deltas && ctest --test-dir build_deltas -L "ros2|docs|tailoring" --output-on-failure`: passed; the focused CTest subset passed `5/5`.
- `./build_ros2.sh --clean`: passed; colcon reported `5 tests, 0 errors, 0 failures, 0 skipped`.
- Local rollout validation in a temporary scratch target: `tailor_template_cleanup.sh --apply --yes --remove-ros2`, `add_ros2_support.sh --apply --yes --verify`, `./build_ros2.sh --clean`, and `./build_lib.sh --skip-tests` all passed. One earlier harness attempt failed because an over-broad tar exclude removed `build_lib.sh`; rerunning with explicit build-directory excludes passed.
- `bash -n build_ros2.sh add_ros2_support.sh` and `shellcheck build_ros2.sh add_ros2_support.sh`: passed.
- YAML parse of `.github/workflows/build_ros2_overlay.yml` with Python `yaml.safe_load`: passed.
- `git diff --stat CMakeLists.txt src/ python/`: empty.
- `git diff --check`: passed.
- Exact conflict-marker scan over the template, testfield, and wrap checkouts for `<<<<<<< `, `>>>>>>> `, and `||||||| `: no matches.
- Testfield: `git diff --check` passed, stale seam grep was clean, and `(cd ../cpp_cuda_template_testfield && ./build_ros2.sh --clean)` reported `5 tests, 0 errors, 0 failures, 0 skipped`.
- Donor `/home/peterc/devDir/dev-tools/ros2_cpp_cuda_template_project`: clean at `9097f9a` (`Update name to spinup; fix issue with install of rviz`), and `python3 -m pytest -q tests/template_checks` passed `9 passed`.

Known non-fatal warning:
- The ROS and scratch standalone builds still print the existing GCC/spdlog `-Warray-bounds` warning from the core build path; it did not fail any gate.

Proposed commit message:

```text
Fix ROS 2 overlay rollout seam guards
```

## Post-review hardening pass - 2026-07-16

Scope:
- Made both supplied launch paths operational by autostarting the lifecycle node while retaining complete commented `Node` and `ComposableNode` alternatives for externally managed deployments.
- Added one parameterized launch integration test covering standalone and composed startup, active-state convergence, and `run_algorithm(3.0) -> 14.0, "ok"`.
- Added a narrow Jazzy composition compatibility adapter for the fully qualified lifecycle-event identity; the adapter can be removed after the upstream `launch_ros` name-resolution fix is available in the supported distro.
- Made rollout destination conflicts fail before any copy, preserved `package.xml` mode bits during version synchronization, and expanded workflow ownership/static verification.
- Mirrored the operational changes into `cpp_cuda_template_testfield` without modifying its adapted `conversions.cpp` core seam.

Red evidence:
- The first static verifier run failed because the standalone launch still used `Node` and did not declare lifecycle autostart.
- After registering the launch test but before fixing the launch files, both parameterizations remained in lifecycle state `1` (unconfigured).
- Native `ComposableLifecycleNode(..., autostart=True)` fixed standalone startup but left the Jazzy composition path unconfigured; inspection traced this to the relative-versus-fully-qualified name mismatch tracked by `ros2/launch_ros#481`.
- The rollout collision fixture initially left a partially copied `ros2/` tree when `doc/ros2_overlay.md` already existed.
- The manifest permission fixture initially changed a `0664` package manifest to `0600` after temporary-file replacement.
- The workflow verifier initially failed because the static step did not derive and pass `EXPECTED_VERSION` to `VerifyTemplateProjectRos2Overlay.cmake`.
- The testfield launch test reproduced the same two unconfigured launch paths before its mirror was applied.

Green evidence:
- `python3 -m pytest -q tests/template_test/testRos2OverlayStatic.py`: passed `6/6`.
- Direct `VerifyTemplateProjectRos2Overlay.cmake`: passed, including documentation/workflow collision atomicity, `--no-ci`, mode preservation, launch guards, and workflow ownership fixtures.
- `./build_lib.sh -B build_review_fixes`: passed `24/24`.
- `ctest --test-dir build_review_fixes -L "ros2|docs|tailoring" --output-on-failure`: passed `5/5`.
- `./build_ros2.sh --clean`: built four packages and reported `8 tests, 0 errors, 0 failures, 0 skipped`; both launch variants configured, activated, and served the algorithm request.
- Local rollout validation in a temporary scratch target: remove overlay, additive reapply with `--verify`, ROS build/tests `8/8`, and plain `./build_lib.sh --skip-tests` all passed.
- `bash -n` and `shellcheck` passed for `build_ros2.sh`, `add_ros2_support.sh`, `tailor_template_cleanup.sh`, and `generate_version.sh`.
- Workflow YAML, all four package manifests, and all changed launch/test Python files parsed or compiled successfully.
- Docker `ros:jazzy` rehearsal passed both workflow behaviors; overlay tests reported `8/8`, pytest reported `6/6`, the direct CMake verifier passed, rollout reapplication passed, and the downstream plain CMake build completed. Full temporary log: `/tmp/ros2_post_review_docker_ky8Ckw/docker_rehearsal.log`.
- Testfield `./build_ros2.sh --clean --cmake-arg -DTEMPLATE_PROJECT_SOURCE_DIR=/home/peterc/devDir/dev-tools/cpp_cuda_template_project`: passed `8/8`.
- Testfield `./build_lib.sh --clean`: passed `39/39`, including the previously blocked wrapper and Python cases.
- Testfield shell syntax/lint, workflow YAML, package XML, Python compilation, conflict scan, and `git diff --check` passed; its adapted `conversions.cpp` remained unchanged.
- Testfield commits created without pushing: `aaf484b` (`Make testfield ROS 2 launch paths operational`) and `282beec` (`Align testfield ROS 2 overlay workflow`).
- Main `git diff --stat CMakeLists.txt src/ python/` remained empty, `git diff --check` passed, and the main index remained empty.

Review closeout:
- The review found and fixed one additional type-contract issue: `prefix_namespace()` is typed as optional, so both adapters now fall back to the already resolved node name before calling `.startswith()`.
- No further relevant correctness, dependency, rollout, workflow, or donor-drift issues were found.
- The existing GCC/fmt `-Warray-bounds` warning remains non-fatal and is outside the ROS overlay change surface.
- Main repository changes remain uncommitted and unstaged; no pushes were made.

## Runtime staging review - 2026-07-16

Scope:
- Reviewed and staged the first functional batch only: the optional ROS 2 workspace, lifecycle bridge and interfaces, standalone/composed launch paths, ROS build helper, package-version synchronization, colcon ignore markers, and overlay output ignores.
- Kept rollout/tailoring scripts, CI workflow, static verifiers, docs, development plan, review report, editor files, `CONTEXT.md`, and this evidence log unstaged.
- Added launch coverage for both root and `integration` namespaces after the staging review found that pushed namespaces were not covered.
- Kept `ComposableLifecycleNode(..., autostart=True)` as the template-facing composition API and retained the complete commented `ComposableNode` alternative for externally managed lifecycle deployments.

Red evidence:
- The first four-case launch run failed `2/4` cases: standalone under `integration` loaded default gain/bias, and composed autostart targeted `/integrationtemplate_algorithm` while the loaded component was `/integration/template_algorithm`.
- Inspection of Jazzy `LoadComposableNodes.execute()` confirmed that its autostart path concatenates `request.node_namespace + request.node_name` without a separator.
- After switching the parameter selector to `/**/template_algorithm`, standalone namespace loading passed but composed loading used default parameters because Jazzy's composable parameter normalizer recognizes `**` and exact node paths, not that selector.

Green evidence:
- The local composition compatibility action now replaces only Jazzy's malformed built-in transition target, joins the launch-context and component namespaces with `prefix_namespace()`, and emits configure/activate transitions for the exact fully qualified name.
- The parameter file uses `/**`, which works for both standalone and composed nodes at root and pushed namespaces.
- Focused `./build_ros2.sh --packages-select template_project_spinup --no-version-sync`: passed all four launch parameterizations and reported `5 tests, 0 errors, 0 failures, 0 skipped`.
- Fresh `./build_ros2.sh --clean`: built all four packages and reported `10 tests, 0 errors, 0 failures, 0 skipped`.
- `bash -n` and `shellcheck` passed for `build_ros2.sh` and `generate_version.sh`.
- Launch/test Python compilation, all four package XML parses, the direct ROS overlay verifier, cached whitespace checks, and root CMake/core-source invariant checks passed.
- `env -u ROS_DISTRO -u AMENT_PREFIX_PATH -u COLCON_PREFIX_PATH ./build_lib.sh -B build_runtime_batch --skip-tests`: passed, confirming the standalone library path remains ROS-independent.

Known non-fatal warning:
- The existing GCC/fmt/spdlog `-Warray-bounds` warning remains visible in core builds and is outside the ROS overlay change surface.

## Rollout and tailoring staging review - 2026-07-16

Scope:
- Staged the additive `add_ros2_support.sh` rollout tool, reversible `tailor_template_cleanup.sh --remove-ros2` behavior, and the focused tailoring regression.
- Kept the ROS static verifier, workflow, general test registration, documentation, agent guidance, reports, context, and evidence unstaged for later functional batches.
- Hardened rollout during review so `--verify` requires `--apply`, generated Python bytecode is never copied, and placeholder replacement respects token boundaries in path components.

Red/green evidence:
- The new verifier guard first failed because `add_ros2_support.sh --verify` silently printed list mode and exited successfully; after explicit mode validation it failed as required with `--verify requires --apply`.
- The synthetic rollout source then failed because `__pycache__` and `*.pyc` artifacts were copied; after filtering interpreter-generated cache artifacts, the fixture passed.
- The same synthetic source proves `nottemplate_projectile.txt` remains unchanged while real `template_project` package paths are renamed.
- Direct `VerifyTemplateProjectRos2Overlay.cmake`: passed after the rollout fixes.
- Direct `VerifyTemplateProjectTailoringScript.cmake`: passed for default overlay retention, profiling retention, and explicit ROS overlay removal.
- `bash -n` and `shellcheck`: passed for `add_ros2_support.sh` and `tailor_template_cleanup.sh`.
- Scratch target `/tmp/ros2_rollout_batch2_3QVBFe/target`: template cleanup with `--remove-ros2`, additive reapplication with `--verify --no-ci`, generated-cache scan, and a standalone build from inside the target all passed.
- Cached whitespace and staged/unstaged overlap checks passed.

Known non-fatal warning:
- The scratch standalone build emitted the existing GCC/fmt/spdlog `-Warray-bounds` warning from the core path.

## Documentation and agent-guidance staging review - 2026-07-16

Scope:
- Staged only the ROS overlay architecture/rollout documentation, removable guidance fences in the repository entry points, and the completed implementation plan.
- Kept the ROS CI workflow, static verifiers, test registration, reports, editor files, `CONTEXT.md`, and this evidence log unstaged.
- Clarified that the bridge is source-adjacent, that an installed-only bridge needs an exported core header, and that derived repositories use the reported `<ros_prefix>` for ROS package paths while retaining their CMake package identity.

Validation evidence:
- Direct `VerifyTemplateProjectDocsStatic.cmake`: passed.
- Direct `VerifyTemplateProjectRos2Overlay.cmake`: passed, including the `conversions.cpp` adaptation-seam, source-adjacent boundary, hermetic spdlog, and `<ros_prefix>` documentation guards.
- `git diff --cached --check`: passed.
- The staged set contains exactly seven files and has no overlap with the unstaged working-tree diff.
- A clean `/tmp/ros2_docs_batch_S3iBs7` snapshot assembled from `HEAD` plus the staged patch passed the docs static verifier, `cmake --preset docs`, and `cmake --build --preset docs`; Doxygen discovered and rendered `doc/ros2_overlay.md`.
- The archive snapshot has no `.git` metadata or `VERSION`, so configure emitted the expected version fallback warning and used `0.0.0`; normal repository checkouts retain Git metadata.

Proposed commit message:

```text
Document optional ROS 2 overlay workflow
```

## Static verification and ROS CI staging review - 2026-07-16

Scope:
- Staged the ROS-free CMake overlay contract, the auto-discovered pytest contract, their CTest registration, the Jazzy overlay workflow, and the docs verifier path-canonicalization fix.
- Kept editor state, reports, `CONTEXT.md`, and this evidence log unstaged.
- Hardened the workflow copied by `add_ros2_support.sh`: template-only pytest/CMake checks now run only when their files exist, and the rollout-rehearsal job skips dependency installation and rehearsal when the template rollout helpers are absent.

Red evidence:
- A real fake derived target created by `add_ros2_support.sh` reproduced the copied-workflow defects: `python3 -m pytest -q tests/template_test/testRos2OverlayStatic.py` exited `4` because the template-only test is intentionally not copied, and `./tailor_template_cleanup.sh --apply --yes --remove-ros2` exited `127` because rollout helpers are intentionally not shipped.
- After extending `VerifyTemplateProjectRos2Overlay.cmake` first, the direct verifier failed on the missing pytest existence guard.

Green evidence:
- Direct `VerifyTemplateProjectRos2Overlay.cmake`: passed after the workflow guards were added.
- Executing the source workflow's parsed static shell block ran pytest `6/6` and the CMake verifier successfully.
- A copied additive-rollout workflow executed both static skip branches and exported `available=false` from its rollout-tooling detector.
- A default-tailored template executed pytest `6/6`, skipped only the removed CMake verifier, and exported `available=true` while both rollout helpers remained.
- `./build_lib.sh -B build_static_ci`: passed `24/24` tests.
- `ctest --test-dir build_static_ci -L "ros2|docs|tailoring" --output-on-failure`: passed `5/5` tests.
- `./build_ros2.sh --clean`: passed with `10 tests, 0 errors, 0 failures, 0 skipped`.
- Full scratch rollout validation: remove overlay, additive reapply with `--verify`, copied-workflow skip checks, ROS build/tests `10/10`, and `./build_lib.sh --skip-tests` all passed.
- `ros:jazzy` static workflow rehearsal at `/tmp/ros2_static_ci_docker_NvoyJL/source`: workflow dependency installation, pytest `6/6`, and the direct CMake verifier passed.
- Direct docs workflow verification with a non-canonical `../cpp_cuda_template_project` source path passed after canonicalization.
- YAML/package XML/Python parsing, `bash -n`, `shellcheck`, conflict scan, cached whitespace, and root CMake/core-source invariants passed.

Known non-fatal output:
- The standalone and ROS builds retain the existing GCC/fmt/spdlog `-Warray-bounds` warning.
- Git-free scratch copies report expected version-control lookup warnings and use their copied `VERSION` file.

Proposed commit message:

```text
Add static verification and CI for ROS 2 overlay
```

## Root workspace-file cleanup - 2026-07-16

Scope:
- Staged removal of `cpp_cuda_template_project.code-workspace` from Git tracking while preserving the local file.
- Added the root-scoped `/*.code-workspace` ignore rule.
- Left `.vscode/c_cpp_properties.json`, reports, context, and this evidence log unstaged.

Validation evidence:
- Local file checksum before and after `git rm --cached`: `b1a34db06f0d134d4bdb9368fa458a7a592d8081d025354db6ada8628c9acd98`.
- `git check-ignore -v cpp_cuda_template_project.code-workspace`: matched `.gitignore:29:/*.code-workspace`.
- `git ls-files --error-unmatch cpp_cuda_template_project.code-workspace`: exited `1`, confirming the staged index no longer tracks the file.
- `git diff --cached --check`: passed.
- Cached scope contains exactly `.gitignore` and the tracked workspace-file deletion.

Proposed commit message:

```text
Ignore local VS Code workspace files
```

## Project metadata flowdown - 2026-07-16

Scope:
- Made the root CMake project the source of truth for standard description and homepage fields plus cache-backed maintainer, contact, and SPDX license metadata.
- Added `PROJECT_METADATA_ONLY=ON`, which resolves project identity and version with `LANGUAGES NONE` and returns before dependencies, targets, wrappers, tests, docs, or packaging.
- Added structured `xml.etree.ElementTree` synchronization for all immediate ROS package manifests while preserving package names, dependencies, non-website URLs, XML processing instructions, and modes.
- Kept package identity as a one-time rollout decision; recurring synchronization updates only version, role-specific description, maintainer, license, and website.
- Reused the same project metadata for CPack and added guarded pre-`rosdep` synchronization to both ROS workflow jobs.

Red/green evidence:
- The first extended pytest run failed on the absent root metadata contract, helper, and workflow ordering; the direct CMake verifier also failed on the missing helper.
- A review guard exposed that checking only for `--sync-ros2` misclassified the older version-only generator as full-metadata capable. `ROS2_PROJECT_METADATA_SYNC=1` now distinguishes the expanded contract in local builds and copied workflows.
- A fresh configure exposed a root install-prefix regression to `/usr/local` after moving `project()`. Restoring the repository-local prefix default before `project()` returned the default to `<repo>/install`; the verifier now enforces that ordering.
- The in-tree CTest fixture initially inherited the parent repository Git version instead of its synthetic `VERSION`. `GIT_CEILING_DIRECTORIES` now keeps the fake target hermetic, and the focused failing CTest passed.
- Final review added a failing guard for an incomplete rollout checklist, then updated the checklist to require the root CMake metadata contract, including `PROJECT_METADATA_ONLY`, before upgrading the sync helper.

Validation evidence:
- `python3 -m pytest -q tests/template_test/testRos2OverlayStatic.py`: passed `8/8`.
- Direct `VerifyTemplateProjectRos2Overlay.cmake`: passed, including metadata-only configure, exact manifest comparison, rollout synchronization, workflow ordering, and install-prefix guards.
- `./build_lib.sh -B build_metadata_flowdown`: built successfully; fresh `ctest --test-dir build_metadata_flowdown --output-on-failure` passed `24/24`.
- `ctest --test-dir build_metadata_flowdown -L "ros2|docs|tailoring" --output-on-failure`: passed `5/5`.
- `./build_ros2.sh --clean`: built all four packages and reported `10 tests, 0 errors, 0 failures, 0 skipped`; metadata synchronization ran before colcon.
- Scratch metadata validation passed cleanup with `--remove-ros2`, additive reapplication with `--verify`, clean ROS build/tests, and ROS-free `./build_lib.sh --skip-tests`.
- The scratch target used CMake name `space-nav-frontend`, ROS prefix `space_nav_frontend`, description `Non-default navigation frontend metadata validation project`, homepage `https://example.test/space-nav-frontend`, maintainer `Validation Maintainer <validation@example.test>`, and license `Apache-2.0`; all four package names and adapted core CMake links remained correct.
- `bash -n` and `shellcheck` passed for `build_ros2.sh`, `add_ros2_support.sh`, and `generate_version.sh`.
- Strict mypy, Python bytecode compilation, workflow YAML parsing, and all four package XML parses passed.
- Repeated synchronization was byte-idempotent; manifest SHA-256 hashes and modes were unchanged on the second run. Source modes remained `0664`, while Git records the expected non-executable `100644` mode.
- Exact conflict-marker scan and `git diff --check` passed. `src/` and `python/` have no diff; the root `CMakeLists.txt` diff is limited to the approved metadata-only project contract and CPack reuse.

Known non-fatal output:
- Standalone and ROS builds retain the existing GCC/fmt/spdlog `-Warray-bounds` warning.
- Git-free scratch builds emit expected version lookup warnings and use the copied `VERSION` file.

Proposed commit message:

```text
Flow project metadata into the ROS 2 overlay
- Export root metadata through standard CMake fields and CPack.

- Synchronize ROS manifests without changing package identity.

- Guard derived-project rollout and CI compatibility.
```

## Review remediation Stage 0 baseline - 2026-07-17

Scope:
- Established the pre-fix control baseline for
  `doc/developments/ros2_overlay_review_remediation_plan.md`.
- Added the narrow, evidence-driven exception for the Stage 1 nested-install and
  Stage 2 CUDA source-discovery CMake fixes. No implementation file changed in
  this stage.
- Baseline branch was `feature/ros2-overlay`, commit `fc5478a`
  (`v1.10.3-10-gfc5478a`), with a clean index and working tree before the
  Stage 0 documentation edits.

Environment:
- CMake `3.28.3`; GNU C++ `13.3.0`.
- ROS 2 Jazzy installed at `/opt/ros/jazzy`; `ROS_DISTRO` was initially unset,
  and `build_ros2.sh` selected Jazzy through its documented default.
- CUDA toolkit `12.9` (`nvcc 12.9.41`), NVIDIA driver `580.105.08`.
- GPUs: NVIDIA GeForce RTX 5090, compute capability 12.0; NVIDIA GeForce RTX
  4070 Ti SUPER, compute capability 8.9.
- No `optix.h` was found under `/usr/local`, `/opt`, or `/usr/include`; OptiX
  validation remains conditional on an SDK-equipped host.

Validation evidence:
- `./build_lib.sh -B build_review_baseline --clean`: configured and built the
  standalone project, then passed `24/24` tests.
- `ctest --test-dir build_review_baseline --output-on-failure`: independent
  rerun passed `24/24` tests.
- `./build_ros2.sh --clean`: built all four packages and reported `10 tests, 0
  errors, 0 failures, 0 skipped`. The launch suite covered standalone and
  composition modes at root and under the `integration` namespace.
- `ctest --test-dir build_review_baseline -L "ros2|tailoring"
  --output-on-failure`: passed `2/2`, independently exercising the rollout,
  bytecode-pruning, metadata-sync, and tailoring fixtures.
- `python3 -m pytest -q tests/template_test/testRos2OverlayStatic.py`: passed
  `8/8`.
- `bash -n` and `shellcheck` passed for `build_ros2.sh`,
  `add_ros2_support.sh`, `tailor_template_cleanup.sh`, and
  `generate_version.sh`.
- `git diff --check` passed. Root `CMakeLists.txt`, `src/`, and `python/` had no
  Stage 0 diff.

Full temporary command logs:
- `/tmp/ros2_review_stage0_build_lib.log`
- `/tmp/ros2_review_stage0_ctest.log`
- `/tmp/ros2_review_stage0_build_ros2.log`
- `/tmp/ros2_review_stage0_contracts.log`
- `/tmp/ros2_review_stage0_shell_pytest.log`

Known non-fatal baseline output:
- Standalone and colcon builds emit the existing GCC 13/fmt/spdlog
  `-Warray-bounds` warning. This predates the remediation implementation and is
  outside the Stage 1/2 change surface.

## Review remediation Stage 1 nested installation - 2026-07-17

Scope:
- Corrected nested public-header destinations in the six approved module
  `CMakeLists.txt` files by deriving their relative paths from
  `PROJECT_SOURCE_DIR` instead of the outermost `CMAKE_SOURCE_DIR`.
- Added a scratch nested install regression, prefix-leak checks, an
  installed-only consumer, and a dependency-independent probe of the optional
  logging module's real install rule.
- Removed the obsolete repository-source include from the lifecycle component.
  The conversions target retains that include only for additive rollout to
  older derived cores whose adapted seam still uses a non-installed header.
- Added static guards for those ownership rules and a workflow check of the
  actual colcon-installed core header layout.

Red evidence:
- The first direct nested verifier run failed before installation with
  `Nested header install destination escapes include/template_project` in the
  generated `template_src/cmake_install.cmake`.
- The extended ROS overlay verifier then failed because
  `src/wrapped_impl/CMakeLists.txt` did not contain `PROJECT_SOURCE_DIR`.
- The bridge-ownership guard failed on the old compatibility comment before the
  component source include was removed, and the workflow guard failed before
  the installed-layout step was added.
- The first post-review package-resolution assertion failed because CMake had
  stored an untyped command-line `template_project_DIR` cache entry as
  `UNINITIALIZED`. Declaring the test input as `:PATH` made the cache assertion
  exact without weakening it.

Green evidence:
- The direct nested verifier passed, including the hermetic logging-header
  install probe, absence of prefix-root header directories, and compilation of
  a consumer with only the installed package on `CMAKE_PREFIX_PATH`.
- `./build_lib.sh -B build_review_nested --clean` configured and built the
  normal standalone project, then passed `25/25` tests. The new nested install
  test passed through CTest in `4.73 s`.
- `./build_ros2.sh --clean` built all four packages and reported `10 tests, 0
  errors, 0 failures, 0 skipped`, including all standalone/composition launch
  variants.
- The colcon install contains the five checked header families below
  `ros2/install/template_project/include/template_project/` and no
  `wrapped_impl/`, `template_src/`, `template_src_kernels/`, or `utils/`
  directory at the package prefix root.
- The installed target exports `${_IMPORT_PREFIX}/include/template_project`
  and `${_IMPORT_PREFIX}/include`. A separate consumer configured and built
  successfully against only the colcon install prefix.
- The parsed workflow install-layout block executed successfully against the
  local colcon install. The direct ROS static verifier also passed after each
  implementation fix.
- An independent read-only review found no substantive Stage 1 issue. Its
  package-resolution masking note was closed by pinning the installed-only
  consumer to the scratch `template_project_DIR` and asserting the resolved
  cache entry; its remaining low-risk notes are deliberate derived-workflow
  portability behavior or are already assigned to Stage 6.
- Root `CMakeLists.txt` and `python/` remain unchanged. Under `src/`, only the
  six authorized module CMake files changed; no C++ or CUDA implementation file
  changed.

Full temporary command logs:
- `/tmp/ros2_review_stage1_nested_red.log`
- `/tmp/ros2_review_stage1_static_red.log`
- `/tmp/ros2_review_stage1_nested_green.log`
- `/tmp/ros2_review_stage1_static_core_green.log`
- `/tmp/ros2_review_stage1_bridge_red.log`
- `/tmp/ros2_review_stage1_bridge_green.log`
- `/tmp/ros2_review_stage1_workflow_red.log`
- `/tmp/ros2_review_stage1_workflow_green.log`
- `/tmp/ros2_review_stage1_build_review_nested.log`
- `/tmp/ros2_review_stage1_build_ros2.log`
- `/tmp/ros2_review_stage1_nested_final.log`
- `/tmp/ros2_review_stage1_static_final.log`
- `/tmp/ros2_review_stage1_build_ros2_final.log`
- `/tmp/ros2_review_stage1_ctest_final.log`

Known non-fatal output:
- The existing GCC 13/fmt/spdlog `-Warray-bounds` warning remains visible in
  standalone and colcon builds. It predates this stage and did not fail any
  gate.

## Review remediation Stage 1A workflow ownership - 2026-07-17

Scope:
- Split all four CI surfaces into active template-validation workflows and
  dormant generic project workflows: Linux CPU, Linux CUDA, Doxygen/Pages, and
  the optional ROS 2 overlay.
- Made `tailor_template_cleanup.sh` atomically materialize generic `.yml.tpl`
  sources as runnable `.yml` files, remove dormant files, preserve modes, and
  safely accept repeated keep-ROS or remove-ROS cleanup runs.
- Added the `# project-ci-template: generic` ownership marker so cleanup can
  distinguish an already materialized workflow from an active template
  verifier whose dormant source was lost.
- Made `add_ros2_support.sh` require that marker and copy only the dormant
  generic ROS workflow into derived projects.
- Made active CPU/docs and ROS end-to-end checks use full-history clones of the exact CI
  revision. CUDA build and test jobs now materialize the tailored project
  before configuring or testing it.

Red evidence:
- `testWorkflowTemplates.py` first failed because
  `.github/workflows/build_linux.yml.tpl` did not exist.
- The tailoring verifier first failed because cleanup did not advertise or
  perform workflow materialization.
- The ROS verifier first failed because
  `.github/workflows/build_ros2_overlay.yml.tpl` did not exist and rollout
  still sourced the active workflow.
- The active-workflow ownership test first failed because Linux CI had no
  `tailored-project-validation` job.
- A new archive guard failed on `--exclude='./build*'`, which could exclude
  `build_lib.sh`; a second clean-source audit found that excluding `.git` also
  allowed a clean runner to lose version provenance. Both active validation jobs
  now use local full-history clones instead of archives.
- The CUDA ownership test failed before its build and test jobs materialized
  the project source tree.
- Reapplying cleanup failed on the consumed
  `.github/workflows/build_linux.yml.tpl`; the idempotency fixture now runs both
  keep-ROS and remove-ROS cleanup twice.
- A missing-template fixture showed that active-only state was ambiguous and
  initially accepted. Explicit ownership markers now reject an unmaterialized
  active verifier without its generic source.
- The ROS verifier failed before additive rollout validated the generic
  ownership marker.
- The docs verifier failed before the active-versus-derived ownership and
  materialization contract was documented.
- A final docs guard failed before `python3-yaml` was documented as a
  template-validation dependency rather than a tailored-project dependency.
- Compatibility review found and removed a test-only
  `COMMAND_ERROR_IS_FATAL` use newer than the CMake 3.15 project floor; the
  mode fixture now checks `RESULT_VARIABLE` explicitly.

Validation evidence:
- `python3 -m pytest -q tests/template_test/testWorkflowTemplates.py
  tests/template_test/testRos2OverlayStatic.py`: passed `11/11`.
- Direct `VerifyTemplateProjectTailoringScript.cmake` passed byte-equivalent
  materialization, mode `0640` preservation, idempotent reapplication, missing
  generic-source rejection, both ROS retention modes, and the CMake 3.15-safe
  error-checking path.
- Direct `VerifyTemplateProjectRos2Overlay.cmake` passed generic-marker
  validation, additive workflow materialization, target-content guards, and
  the existing overlay contracts.
- Direct docs and CI workflow CMake verifiers passed.
- `./build_lib.sh -B build_workflow_split --clean` passed `26/26`; a final
  source-state `ctest --test-dir build_workflow_split --output-on-failure
  --parallel 6 --no-tests=error` also passed `26/26`.
- Normal tailoring scratch at
  `/tmp/cpp_cuda_template_tailored.W3hpQn/target` produced four runnable YAML
  workflows, no `.tpl` or template-only workflow checks, passed standalone
  CTest `7/7`, and built Doxygen HTML/XML.
- The same tailored scratch configured with CUDA `12.9.41` for `sm_120`, built
  successfully, and passed `9/9` tests including CUDA initialization and the
  device-memory round trip.
- `./build_ros2.sh --clean` built all four packages and reported `10 tests, 0
  errors, 0 failures, 0 skipped`.
- Remove/re-add rollout scratch at
  `/tmp/cpp_cuda_template_rollout.fnHQZP/target` first produced exactly three
  non-ROS workflows, then restored the generic ROS workflow byte-for-byte from
  `.yml.tpl`; clean ROS tests passed `10/10` and the standalone build passed.
- `bash -n`, `shellcheck`, `git diff --check`, exact conflict-marker scan, and
  parsing all eight workflow files passed. Exactly four workflow files carry
  the generic marker.
- Root `CMakeLists.txt`, `src/`, and `python/` have no Stage 1A diff.

Full temporary red command logs recovered from the implementation pass:
- `/tmp/workflow_split_pytest_red.log`
- `/tmp/workflow_split_tailoring_red.log`
- `/tmp/workflow_split_ros_red.log`
- `/tmp/workflow_split_active_red.log`

Known non-fatal output and deferred scope:
- Standalone, CUDA, and ROS builds retain the existing GCC 13/fmt/spdlog
  `-Warray-bounds` warning.
- The tailored CUDA configure still reports no ordinary CUDA source in the
  core library. This is the pre-existing compile-graph defect explicitly owned
  by remediation Stage 2; Stage 1A proves the materialized CUDA CI path without
  claiming that Stage 2 is complete.

Proposed commit message:

```text
Separate template and project CI workflows
- Materialize generic workflows during project tailoring.

- Validate tailored CPU, CUDA, docs, and ROS paths.

- Guard workflow ownership and cleanup idempotency.
```

## Review remediation Stage 2 CUDA and OptiX - 2026-07-17

Scope:
- Corrected ordinary C++/CUDA discovery in the seven approved source CMake
  files. Dedicated `*.ptx.cu` inputs remain in `srcCudaFilesToPTX*` and are
  explicitly filtered out of ordinary target sources.
- Added a CUDA-only compile-database regression for the real project
  `placeholder.cu` and a static malformed-glob guard.
- Added an OptiX-only install-consumer regression after the first end-to-end
  OptiX run exposed a non-relocatable installed interface.
- Made installed OptiX consumption resolve the external SDK through
  `OPTIX_ROOT`, `OptiX_ROOT`, `OptiX_INSTALL_DIR`, or `OPTIX_HOME`. Installed
  exports contain neither a build-machine SDK path nor a fictitious
  package-local `include/optix` path.

Red evidence:
- The static overlay verifier rejected `"*.cpp; *.cu"` in
  `src/CMakeLists.txt`.
- The isolated CUDA verifier configured and built successfully, then failed
  because `src/template_src_kernels/placeholder.cu` was absent from
  `compile_commands.json`.
- The first ROS CUDA+OptiX run generated PTX in the core package, then failed
  while configuring `template_project_ros`: the imported core target required
  a non-existent install-prefix `include/optix` directory.
- The new OptiX install-consumer verifier reproduced the same package-local
  include defect before the export fix.
- The documentation guard failed before the dated GPU validation and
  variable-based SDK contract were documented.
- The tailoring verifier failed before the two new template-only GPU verifier
  paths were added to the cleanup contract.
- The active CUDA workflow guards failed before the post-materialization
  compile-database assertion was added.

Validation evidence:
- `./build_lib.sh -B build_review_cuda --clean -DENABLE_CUDA=ON
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`: built the project and passed `29/29`
  tests. `ctest --test-dir build_review_cuda -L cuda --output-on-failure`
  independently passed `3/3` CUDA-labeled tests.
- The standalone compile database contains an `nvcc` command for
  `src/template_src_kernels/placeholder.cu`, and the real object exists at
  `build_review_cuda/src/CMakeFiles/template_project.dir/template_src_kernels/placeholder.cu.o`.
  No ordinary compile entry exists for `placeholder_to_ptx.ptx.cu`.
- `./build_ros2.sh --clean --cuda --cmake-arg
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`: built four packages and reported
  `10 tests, 0 errors, 0 failures, 0 skipped`. The nested core compile database
  and target object contain the same real project CUDA source.
- `OPTIX_HOME=<sdk-root> ./build_lib.sh -B build_review_optix_final --clean
  -DENABLE_CUDA=ON -DENABLE_OPTIX=ON -DOPTIX_AUTO_INSTALL=OFF
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`: discovered the official OptiX 8.0 SDK
  from the environment alone and passed `30/30`, including the install-consumer
  regression.
- `OPTIX_HOME=<sdk-root> ./build_ros2.sh --clean --cuda --optix`: built four
  packages and reported `10 tests, 0 errors, 0 failures, 0 skipped`.
- The ROS OptiX core generated
  `ros2/build/template_project/template_project_core/src/placeholder_to_ptx.ptx`,
  `placeholder_to_ptx_embedded.c`, and `placeholder_to_ptx_embedded.o`. Its
  installed target export contains no home-directory path and no
  `include/optix` claim.
- Local toolchain: ROS 2 Jazzy, CMake 3.28.3, GCC 13.3.0, CUDA 12.9.41,
  NVIDIA driver 580.105.08, OptiX 8.0.0. The host GPUs were an RTX 5090
  (`sm_120`) and RTX 4070 Ti SUPER (`sm_89`); the default single-architecture
  policy selected `sm_120`.
- The direct static, CUDA-source, OptiX install-consumer, and documentation
  verifiers all passed after their matching red runs.
- The tailoring fixture now proves both template-only GPU verifiers are listed
  and removed. A scratch default tailoring then materialized the generic CUDA
  workflow, compiled `placeholder.cu`, rejected an ordinary
  `placeholder_to_ptx.ptx.cu` entry, and passed `9/9` project tests.
- A final clean `OPTIX_HOME=<sdk-root> ./build_ros2.sh --clean --cuda --optix
  --cmake-arg -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` rerun built four packages and
  reported `10 tests, 0 errors, 0 failures, 0 skipped`.
- The final focused CTest gate passed `9/9` tests across
  `cuda|optix|ros2|docs|tailoring`; the two static pytest modules passed
  `11/11`. Shell syntax/lint, eight-workflow YAML parsing, four-manifest XML
  parsing, conflict-marker scanning, diff whitespace, authorized-source-surface,
  and machine-local-path checks all passed.
- The extensive diff review found no unresolved critical or major issue. It
  produced the two additional red-green fixes above for tailoring ownership and
  active CUDA CI coverage.

Full temporary command logs:
- `/tmp/ros2_review_stage2_static_red.log`
- `/tmp/ros2_review_stage2_cuda_red.log`
- `/tmp/ros2_review_stage2_build_lib_cuda.log`
- `/tmp/ros2_review_stage2_ctest_cuda.log`
- `/tmp/ros2_review_stage2_build_ros2_cuda.log`
- `/tmp/ros2_review_stage2_build_ros2_optix.log`
- `/tmp/ros2_review_stage2_optix_export_red.log`
- `/tmp/ros2_review_stage2_optix_export_green.log`
- `/tmp/ros2_review_stage2_build_ros2_optix_green.log`
- `/tmp/ros2_review_stage2_build_lib_optix.log`
- `/tmp/ros2_review_stage2_docs_red.log`
- `/tmp/ros2_review_stage2_docs_green.log`
- `/tmp/ros2_review_stage2_tailoring_red.log`
- `/tmp/ros2_review_stage2_tailoring_green.log`
- `/tmp/ros2_review_stage2_cuda_workflow_red.log`
- `/tmp/ros2_review_stage2_cuda_workflow_green.log`
- `/tmp/ros2_review_stage2_cuda_workflow_pytest_red.log`
- `/tmp/ros2_review_stage2_cuda_workflow_pytest_green.log`
- `/tmp/ros2_review_stage2_tailored_cuda_ci.log`
- `/tmp/ros2_review_stage2_build_lib_optix_final.log`
- `/tmp/ros2_review_stage2_build_ros2_optix_final.log`
- `/tmp/ros2_review_stage2_ctest_final.log`
- `/tmp/ros2_review_stage2_pytest_final.log`
- `/tmp/ros2_review_stage2_shell_final.log`
- `/tmp/ros2_review_stage2_structured_final.log`
- `/tmp/ros2_review_stage2_invariants_final.log`

Known non-fatal output:
- GCC 13 still emits the pre-existing fmt/spdlog `-Warray-bounds` warning.
- Colcon reports that `CMAKE_EXPORT_COMPILE_COMMANDS` is unused by the spinup
  package; the variable is consumed by the core package where compile-graph
  evidence is required.

Proposed commit message:

```text
Compile CUDA sources and fix OptiX package exports
- Separate ordinary CUDA sources from OptiX PTX inputs.

- Resolve installed OptiX headers without machine-local paths.

- Verify CUDA and OptiX compile and install contracts.
```

## 2026-07-17 - Review remediation Stages 3-5

Scope:
- Stage 3: define and test a tag-safe ROS package-metadata release process.
- Stage 4: assert lifecycle status publication through all four launch cases.
- Stage 5: reject malformed documentation fences and make reports/evidence
  internal to template development.
- Stage 6 and later stages were not started.

Red evidence:
- The docs static verifier rejected the missing
  `Release tagging with the ROS 2 overlay` contract.
- The ROS static verifier rejected the launch test before it imported and
  subscribed to `AlgorithmStatus`.
- The tailoring verifier demonstrated that both orphan end markers and nested
  begin markers were accepted by the old awk state handling. The existing
  unclosed-begin failure was retained as the third regression case.
- The docs build verifier rejected the Doxyfile before `doc/reports` was
  excluded.
- After initial green launch runs, a repeated direct run reproduced a real
  composition-plus-namespace discovery race: the service completed but the
  single volatile status publication was missed. A new static guard failed
  before the bounded post-discovery settle interval was added.

Implemented contracts:
- Added a local-only release rehearsal that clones without local object sharing,
  removes its remote, configures isolated Git identity/signing behavior, creates
  a synthetic preparation commit and temporary lightweight tag, proves stale
  manifests fail, synchronizes and commits all four manifests, creates a final
  annotated tag, inspects every tagged manifest with `git show`, and runs the
  complete ROS overlay verifier against the tagged tree. Source tag refs are
  compared before and after.
- Documented the temporary-tag/synchronized-commit/final-tag sequence, final
  local release gates, atomic branch-and-tag push, invalid GitHub-UI-first flow,
  and no-Git source-archive `VERSION` requirement. The section is fenced so a
  non-ROS tailored project does not retain ROS release instructions.
- Extended the existing launch test without changing lifecycle architecture.
  Every standalone/composition and root/namespaced case now subscribes before
  the request, waits for discovery to settle, and asserts response plus all
  `AlgorithmStatus` fields and timestamp with case-specific diagnostics.
- Hardened fence stripping to reject nested begin, orphan end, and unclosed
  begin markers. Documented manual overlay removal and stable CUDA/OptiX facade
  semantics, including rejection of direct core-option overrides.
- Moved this log under `doc/developments`, excluded `doc/reports` from Doxygen,
  and removed reports plus the new release verifier during project tailoring.

Validation evidence:
- `./build_lib.sh -B build_review_remediation --clean`: passed `27/27` tests,
  including the new `release;version;ros2` test.
- Final focused CTest gate for `release|version|ros2|docs|tailoring`: passed
  `7/7` tests.
- Final `./build_ros2.sh --clean`: built four packages and reported `10 tests,
  0 errors, 0 failures, 0 skipped`; all four status-observing launch cases
  passed.
- The direct launch target passed five consecutive full parameterized runs
  after the discovery-settle fix, for 20 additional case executions.
- The direct release, docs-static, docs-build, tailoring, and ROS overlay
  verifiers passed. Static ROS/workflow pytest passed `11/11`.
- Default tailoring removed development plans/reports while retaining the
  overlay and fenced release guidance. `--remove-ros2` also removed the overlay,
  workflow, overlay docs, and fenced release guidance while preserving general
  user documentation.
- `bash -n` and `shellcheck` passed on all four root scripts. Eight workflows
  parsed as YAML and four manifests parsed as XML.
- Root `CMakeLists.txt`, `src/`, and `python/` remained unchanged. Conflict
  markers, ROS source-tree bytecode, machine-local added paths, whitespace
  errors, and lingering release-test processes were absent in the final audit.

Extensive review corrections:
- Made the synthetic release preparation one commit newer than inherited tags,
  preventing ambiguous `git describe` selection on release-tag checkouts.
- Replaced a shell-invalid branch placeholder with the current branch variable.
- Added `doc/versioning.md` to the overlay fence-removal contract.
- Added case context to lifecycle-state timeout failures.
- Reproduced and fixed the asymmetric DDS discovery race without changing QoS,
  service availability, launch autostart, or component architecture.

Full temporary command logs:
- `/tmp/ros2_review_stage3_docs_red.log`
- `/tmp/ros2_review_stage3_docs_green.log`
- `/tmp/ros2_review_stage3_release_process_green.log`
- `/tmp/ros2_review_stage4_status_red.log`
- `/tmp/ros2_review_stage4_discovery_settle_red.log`
- `/tmp/ros2_review_stage4_discovery_settle_green.log`
- `/tmp/ros2_review_stage4_build_ros2_final.log`
- `/tmp/ros2_review_stage4_launch_stress.log`
- `/tmp/ros2_review_stage5_orphan_fence_red.log`
- `/tmp/ros2_review_stage5_nested_fence_red.log`
- `/tmp/ros2_review_stage5_tailoring_green.log`
- `/tmp/ros2_review_stage5_docs_red.log`
- `/tmp/ros2_review_stage5_docs_green.log`
- `/tmp/ros2_review_stage5_tailor_default.log`
- `/tmp/ros2_review_stage5_tailor_remove_ros2.log`
- `/tmp/ros2_review_stages3_5_build_lib.log`
- `/tmp/ros2_review_stages3_5_ctest_focused_final.log`
- `/tmp/ros2_review_stages3_5_pytest_final.log`

Known non-fatal output:
- GCC 13 still emits the pre-existing fmt/spdlog `-Warray-bounds` warning.

Proposed commit message:

```text
Harden ROS overlay tailoring and documentation hygiene
- Reject malformed ROS documentation fences during tailoring.

- Document stable CUDA and OptiX facade behavior and manual overlay removal.

- Keep implementation reports and stage evidence internal to template development.
```

## 2026-07-17 - Review remediation pass

Scope:
- Stage 6 bound core-to-overlay CI drift with core path filters, one weekly
  schedule, semantic YAML guards, and runtime validation of active-template,
  default-tailored, and additive-rollout modes.
- Stage 7 mirrored applicable fixes into the testfield, ran both repositories'
  native and ROS gates, and closed the implementation review without changing
  the overlay architecture.
- The testfield documentation workflow became build-only after a remote run
  exhausted artifact storage. Its prior Pages workflow was disabled remotely;
  the replacement checks generated HTML/XML without upload or deployment.

Red evidence:
- The Stage 6 CMake and semantic YAML guards failed before the active and
  generic ROS workflows carried the exact weekly schedule and watched all core
  ownership paths.
- Testfield nested-install verification failed while headers escaped
  `include/template_project`; the first corrected nested configure then exposed
  version-file ownership tied to the outer build.
- Testfield CUDA verification failed because the malformed source list omitted
  `placeholder.cu` from the real target.
- Expanded namespaced launch cases exposed parameter scoping and Jazzy composed
  lifecycle-autostart identity defects before the wildcard parameters and
  namespace-aware adapter were applied.
- The remote documentation run built its site successfully, then failed only
  when the Pages artifact action reported exhausted storage quota.

Validation evidence:
- Main `./build_lib.sh -B build_review_final --clean` and explicit full CTest
  passed `27/27`; the focused `ros2|docs|tailoring|nested|release` gate passed
  `7/7`.
- Main clean CPU and CUDA+OptiX ROS runs each built four packages and reported
  `10 tests, 0 errors, 0 failures, 0 skipped`. The CUDA compile database
  contains the real `placeholder.cu` object and excludes ordinary compilation
  of `placeholder_to_ptx.ptx.cu`; the OptiX path generated PTX and embedded-C
  artifacts.
- Container rehearsals passed active-template, default-tailored, and additive
  rollout modes. Each ROS mode built four packages and passed all 10 tests.
- A fresh local rollout validation applied default tailoring, separately
  removed and re-added the overlay with `--verify`, passed the clean ROS build,
  and passed the standalone ROS-free build.
- Testfield `./build_lib.sh --clean` passed `41/41`. Its clean ROS build built
  four packages and passed all 10 tests, including standalone/composition and
  root/namespaced lifecycle cases with response/status assertions.
- A fresh testfield documentation configure/build generated
  `build_docs/doc/html/index.html` and `build_docs/doc/xml`. The static verifier
  and semantic YAML check require a single `build-docs` job and reject artifact
  upload, Pages configuration, deployment actions, and publication permissions.
- Shell syntax and shellcheck passed the root helpers. Strict metadata-helper
  typing, Python compilation, workflow YAML parsing, manifest XML parsing,
  exact conflict-marker and placeholder scans, and diff whitespace checks
  passed.
- The main closeout diff leaves root `CMakeLists.txt`, `src/`, and `python/`
  unchanged. The testfield's adapted `conversions.cpp` and unrelated
  `lib/wrap` state remain untouched.
- Final review found stale publication guidance in the testfield usage guide,
  focused CTest command, and issue forms. A new static guard failed on the old
  wording, passed after correction, and the build-only documentation target was
  rebuilt successfully.
- A broad shellcheck sweep found the pre-existing unused
  `wrapper_interface_override` assignment in `build_lib.sh`. Removing only the
  dead assignments made all five main root helpers shellcheck-clean; the three
  wrapper-script behavior regressions passed afterward.

Review result:
- Install/export semantics, ordinary-CUDA versus PTX ownership, release-tag
  reproducibility, copied-workflow portability, and previously resolved review
  findings were re-audited. No unresolved critical or major issue was found in
  the reviewed scope.
- GCC 13 still emits the pre-existing non-fatal fmt/spdlog
  `-Warray-bounds` warning.

## 2026-07-18 - Atomic tailoring, release archives, and version-sync closeout

Scope:
- Stage 8 made template tailoring preflighted, atomic, and mode-preserving.
- Stage 9 gave the testfield a centralized prerelease-aware project/CPack/ROS
  metadata contract.
- Stage 10 established CPack source TGZ as the canonical release artifact for
  both repositories.
- Stage 11 narrowed CI correctness gaps around release tags, manifest drift,
  expected-version ownership, and documentation static checks.
- Stage 12 aligned public guidance and executed the final two-repository host
  and Jazzy-container regression.

Red evidence:
- New tailoring fixtures rejected the former rewrite path because it could
  change target modes and begin cleanup before discovering a later malformed
  documentation fence. Nested, orphaned, and unclosed fixtures established the
  required zero-mutation failure baseline.
- Testfield version/CPack regressions initially rejected legacy-only parsing,
  missing metadata-only configuration, and source package names that omitted
  the full prerelease-aware version. Copied-manifest tests rejected the absence
  of a structured full-metadata synchronizer.
- The initial release-archive tests stopped at tag verification and therefore
  could not prove no-Git consumption or rejection of a missing `VERSION` file.
- Workflow contract tests rejected missing release-tag triggers, sync paths
  without a post-sync Git drift check, manifest-derived expected versions, and
  docs workflows that did not run their owned static verifier directly.
- The first final native rerun exposed one stale ROS static assertion that
  still required the malformed inline-code wording. The assertion was reversed
  to require the corrected form; its two focused tests and the complete native
  suite then passed.

Green implementation evidence:
- `VerifyTemplateProjectTailoringScript.cmake` now checks original modes and
  complete tree immutability. Real default and `--remove-ros2` tailored clones
  each passed all seven native starter tests; the default-tailored ROS overlay
  built four packages and passed 10 tests.
- Both metadata helpers pass strict mypy and shellcheck. Two consecutive syncs
  in clean snapshots produced identical hashes for all four manifests and zero
  Git drift. The testfield manifests retain package names, dependencies, XML
  processing instructions, and modes while carrying its own description,
  maintainer, license, website, and version.
- Both synthetic release tests create CPack TGZ archives, extract them outside
  Git, verify required/excluded paths, configure metadata-only from the
  extraction, compare strict core/full versions, and reject an archive with no
  `VERSION`.
- Semantic workflow pytest passed `6/6`; active/dormant main workflows and all
  testfield workflows parse as YAML. Direct CMake workflow, docs, and ROS
  contracts pass, including a real temporary-repository stale-manifest failure.

Final host regression:
- Main clean native build and CTest: `27/27` passed.
- Main clean CPU ROS: four packages, `10 tests, 0 errors, 0 failures, 0 skipped`.
- Main standalone CUDA+OptiX: `31/31` passed. Build rules compile the real
  `placeholder.cu` for `sm_120`, compile `placeholder_to_ptx.ptx.cu` only via
  the dedicated PTX rule, and produce PTX, embedded C, and embedded object.
- Main clean ROS CUDA+OptiX: four packages and all 10 tests passed with the same
  real CUDA/PTX artifact ownership.
- Testfield clean native build and CTest: `43/43` passed. Its clean ROS build
  completed four packages and all 10 tests.
- Fresh Doxygen HTML/XML builds passed in both repositories. Strict Python 3.12
  compilation, mypy, shell syntax/lint, workflow YAML and manifest XML parsing,
  exact conflict-marker scans, and staged/unstaged whitespace checks passed.

Jazzy workflow rehearsal:
- One clean `ros:jazzy` environment executed the affected install, metadata
  capability, sync, drift, rosdep, build/test, installed-header, and static
  blocks against isolated active-template, tailored-generic, and testfield
  workspaces.
- Active template: four packages, 10 tests, static pytest `14/14`, and the full
  CMake ROS verifier passed.
- Tailored generic: four packages and 10 tests passed; the generic workflow was
  materialized, its dormant form removed, and no template-only verifier leaked.
- Testfield: four packages and 10 tests passed against an external template
  checkout; helper syntax and full metadata drift gates passed.

Preserved boundaries and known output:
- No C++, CUDA, ROS message/service, lifecycle-node, or wrapper API changed in
  Stages 8-12.
- Testfield `ros2/template_project_ros/src/conversions.cpp` retains SHA-256
  `9d19c20deb777a3f41305e9f977d08cda51741e419a2a382e40cc8ff04279255`;
  `lib/wrap` remains at `55f7cf30f47972a7055266bd4308614e8fe8aca2`.
- GCC 13 continues to emit the pre-existing non-fatal fmt/spdlog
  `-Warray-bounds` warning. Testfield's broad colcon CMake argument produces
  expected unused-variable warnings in packages that do not consume the
  external-template path.

Commit-split reconstruction:
- The main disposable clone applied and committed, in order, atomic tailoring,
  canonical source releases, ROS/docs CI contracts, and dead wrapper-state
  removal. Their focused gates passed the direct tailoring verifier and
  shellcheck; the full synthetic release/archive test; static pytest `14/14`,
  eight-workflow YAML parsing and both CMake static verifiers; and build-helper
  syntax/shellcheck/help behavior respectively.
- The testfield disposable clone then applied and committed centralized
  metadata, source-release/CI drift, and docs-CI contracts. Their focused gates
  passed strict mypy, metadata pytest `5/5`, version/CPack side effects and
  shellcheck; synthetic CPack archive plus native/ROS workflow contracts and
  clean post-sync manifests; and direct docs static plus fresh HTML/XML output.
- The final main closeout commit was reconstructed only after all seven prior
  gates. No commit was created in either source repository.
