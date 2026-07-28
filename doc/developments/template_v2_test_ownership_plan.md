# Template v1.12.1 Hardening and v2 Test-Ownership Migration

## Status

- Authoritative execution tracker for the v1.12.1 prerequisite and the
  subsequent v2.0.0 test-ownership migration.
- Tracking started: 2026-07-28.
- Current stage: Stage 5 integrated local validation is complete; final index
  review, commits, TestField pin alignment, pushes, and remote CI inspection are
  in progress. The v1.12.1 release baseline remains immutable.
- Template release baseline: signed `v1.12.1` tag at
  `480d10a692836040bcae2023e763c553acfcc64d`.
- TestField release baseline: signed commit and signed annotated tag `v1.12.1`
  at `f632290ce1bfb1f80baeeb3da2ea6db28a998037`.
- Final commits and pushes require the review gates stated below. The user has
  authorized branch pushes after local success; final v2.0.0 release tags still
  require separate explicit authorization.

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
- The template carries only generic derived-project workflows; tailoring
  preserves them directly and removes only the ROS workflow with the overlay.
- TestField-owned workflow conformance remains external to both template and
  derived-project CTest.

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

Completed release outcome:

- the implementation was committed as signed commit `d398c20` with the
  approved title and bulleted description;
- the four ROS 2 manifest versions were completed in signed follow-up
  `480d10a`;
- signed annotated tag `v1.12.1`, the remote branch, and the remote tag all
  dereference to `480d10a`;
- PR 28 and tag-triggered native, ROS 2, documentation, tailoring, and rollout
  checks completed successfully;
- remote CUDA remained policy-skipped because `CI_USE_SELF_HOSTED` was not
  enabled, and was covered by Stage 2 local accelerator acceptance.

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

- [x] Verify the reviewed template tag and synchronized release metadata.
- [x] Reconcile the existing TestField index with the exact v1.12.1 tag.
- [x] Port production behavior while preserving TestField identity, APIs, ROS
  adaptations, and local tests.
- [x] Keep template conformance external to normal TestField CTest.
- [x] Maintain one combined v1.12.1 sync document, design first and plan second.
- [x] Run CPU, docs, CUDA, ROS 2, wrapper, wheel, install/consumer, cleanup, and
  release-archive acceptance.
- [x] Apply the complete staged-code quality gate.
- [x] Amend the existing unpushed signed documentation commit into one coherent
  v1.12.1 alignment commit.
- [x] Create and verify the signed annotated local TestField `v1.12.1` tag,
  then stop without pushing.

Proposed title:

`[BUGFIX] Align TestField with template v1.12.1 packaging`

### Stage 2 evidence

- Source release:
  - signed local and remote `v1.12.1` dereference to `480d10a`;
  - all four template ROS 2 manifests contain `1.12.1`;
  - all terminal PR/tag checks passed except the documented self-hosted CUDA
    policy skip.
- RED, released wrapper contract: the exact v1.12.1 Python-packaging verifier
  exited `1` against the old TestField candidate because the configure-time
  analyzer rejected the collision fixture before resolved-name staging.
- GREEN, released wrapper contract: after the production-module port, the same
  external verifier exited `0`.
- RED, release-cache race: the extended TestField release fixture exited `1`
  when the old archive scan read a deliberately disappearing
  `build_transient/CMakeCache.txt`.
- GREEN, release-cache race: active and already-owned build paths are filtered
  before cache reads, and the extended release fixture exited `0`.
- RED, TestField static mode: the external installed-consumer verifier exited
  `1` because the TestField target hardcoded `SHARED` and produced no
  `libtemplate_project.a`.
- GREEN, TestField build modes: independent shared and static install/consumer
  checks each configured, built, linked, and ran successfully.
- GREEN, final fresh CPU:
  `./build_lib.sh -B build_v112_cpu --clean ...` exited `0`; CTest passed
  `40/40`.
- GREEN, documentation: `template_project_doc` completed with Doxygen 1.9.8.
- GREEN, real wrapper and installs:
  - `--gtwrap-root lib/wrap` built the Python wrapper successfully;
  - isolated wheel and CMake-prefix imports passed without checkout loader
    paths;
  - the wheel excluded `_wrapper_build.py`, contained only declared native
    artifacts, and both artifacts used loader-relative runtime paths.
- GREEN, accelerators:
  - CUDA 12.9.41 selected `sm_120` and passed `41/41`;
  - the explicit OptiX SDK build passed `17/17`.
- GREEN, ROS 2 Jazzy:
  `./build_ros2.sh --clean --no-version-sync` built all four packages and
  reported `10` tests, `0` errors, `0` failures, and `0` skips.
- GREEN, final focused checks: released Python packaging, clean ownership,
  TestField source release, shared consumer, and static consumer verifiers each
  exited `0`.
- GREEN, static hygiene: Bash syntax, ShellCheck, Python compilation, YAML/XML
  parsing, whitespace, conflict-marker, and forbidden-newer-CMake-API scans
  passed. The host does not provide the exact CMake 3.15 runtime.
- Signed release preparation:
  - commit `f632290ce1bfb1f80baeeb3da2ea6db28a998037` uses the approved
    `[BUGFIX]` title and four-paragraph bulleted body;
  - signed annotated tag `v1.12.1` dereferences to the same commit and uses the
    established `Release v1.12.1 testfield` message;
  - exact-tag `generate_version.sh --sync-ros2` derived `1.12.1`, left the four
    tracked manifests unchanged, and wrote only the ignored `VERSION`;
  - TestField `main` and remote `v1.12.1^{}` now both resolve to `f632290`;
  - branch and tag native CI runs `30355250583` and `30355250624` passed
    `35/35` applicable hosted-runner tests each;
  - branch and tag ROS 2 runs `30355250665` and `30355250725` each built four
    packages and reported `10` tests, `0` errors, `0` failures, and `0` skips;
  - documentation run `30355250590` passed with Doxygen 1.9.8;
  - tag CUDA run `30355250623` was policy-skipped because self-hosted CI is
    disabled, matching the recorded local-accelerator substitution.

## Stage 3 - TestField-owned v2 harness

- [x] Inventory every conformance test, label, timeout, prerequisite, resource
  lock, skip, and behavioral assertion.
- [x] Create the standalone TestField harness and explicit profile inputs.
- [x] Move template-system conformance implementations into TestField while
  their original template counterparts remain available for parity.
- [x] Keep TestField local tests independent of the candidate template.
- [x] Remove the main-project external-test facade and implicit sibling path.
- [x] Compare old and new inventories and results against the same candidate.
- [x] Resolve every unexplained lost or duplicated assertion.
- [x] Update only CI wiring required for full-SHA sibling harness execution.

### Stage 3 conformance inventory

The inventory baseline is the exact template and TestField `v1.12.1` source,
their generated CTest JSON, and the successful Stage 1 and Stage 2 build trees.
The template currently exposes `21` CPU-applicable conformance entries:
`18` CMake-script entries and `3` pytest-file entries. CUDA adds one
template-system verifier plus the two retained CUDA runtime entries. OptiX adds
one conditional template-system verifier. TestField's transitional external
block contributes up to `24` entries, four of which invoke the candidate's
existing verifier rather than a TestField-owned implementation.

Template-system assertions to migrate:

| Owner file | Profile | Existing CTest contract | Behavioral assertions |
|---|---|---|---|
| `VerifyTemplateProjectNoOptimization.cmake` | `cpu` | `flags;noopt`, 180 s | `RelWithDebInfo` emits all required no-optimization/debug flags, emits none of the optimized/native/`NDEBUG` flags, and builds. |
| `VerifyTemplateProjectOptimizedFlags.cmake` | `cpu` | `flags;optimized`, 180 s | `Release` and `RelWithDebInfo` emit their required optimization/debug definitions, reject profiling/no-opt/sanitizer flags, and build. |
| `VerifyTemplateProjectDocsWorkflow.cmake` | `docs` | `docs;doxygen`, 240 s | strict docs configure/build succeeds; HTML/XML and Doxyfile exist; public inputs, exclusions, main page, and documented topics are present; internal development/report content is absent. |
| `VerifyTemplateProjectNestedDocsIsolation.cmake` | `docs` | `docs;nested`, 180 s | a nested consumer configures/builds while the nested template contributes neither a parent-visible `doc` target nor a Doxyfile. |
| `VerifyTemplateProjectNestedInstallHeaders.cmake` | `cpu` | `install;nested;template`, 240 s | nested install destinations cannot escape the advertised include root; the exact public and logger headers install without root leaks; an installed-only consumer resolves only the scratch package and builds. |
| `VerifyTemplateProjectVersionSideEffects.cmake` | `cpu` | `configure;version`, 180 s | configure writes build-tree `VERSION` while `WRITE_SOURCE_VERSION_FILE=OFF` neither creates nor changes source `VERSION`. |
| `VerifyTemplateProjectPythonTestOptions.cmake` | `cpu` | `tests;python`, 180 s | disabled tests ignore invalid Python runner/conda settings; disabled Python tests do the same; enabled Python tests reject conflicting conda name/prefix settings. |
| `VerifyTemplateProjectBuildLibCleanSafety.cmake` | `cpu` | `build;clean;safety`, 60 s | `--clean` rejects external, missing-cache, and foreign-cache targets with the intended diagnostic; an owned conventional build is removed and recreated; `--rebuild-only` ignores clean without deleting an external build. |
| `VerifyTemplateProjectPythonPackaging.cmake` | `cpu` | `install;package;python;wrapper`, 180 s | absolute Python install roots are rejected; resolved runtime/runtime, runtime/extension, and target/SONAME collisions fail before partial staging; generator-expression names work; declared unlinked runtimes refresh; wheel and CMake installs contain exactly the declared native artifacts, exclude checkout metadata/cache files, import without checkout loader paths, and use loader-relative paths without scratch paths. |
| `VerifyTemplateProjectBuildTreePackage.cmake` | `cpu` | `package;template`, 180 s | build-tree package/config exports are colocated, source config is not polluted, the namespaced target and `cxx_std_20` propagate, and a build-tree consumer configures/builds. |
| `VerifyTemplateProjectTailoringScript.cmake` | `cpu` | `tailoring;template`, 60 s | list mode is non-mutating; template-only/profiling removal and retention are exact; scripts/workflows preserve modes; logger files survive with namespace tailoring; production wrapper modules survive; default and ROS-removed outputs are correct; malformed fences, namespaces, and missing workflow templates fail without any tree mutation. |
| `VerifyTemplateProjectAddTestsProperties.cmake` | `cpu` | `tests;cmake_utils`, 60 s | Catch2 property resolution accepts a literal list, an indirect variable, empty input, and a single-token literal without changing values. |
| `VerifyTemplateProjectRos2Overlay.cmake` | `ros2` | `ros2;template`, 60 s | required overlay inputs/fences and metadata-only configure are valid; rollout list/collision/no-CI paths are non-destructive; generated paths, placeholder replacement, one active workflow, identifier-boundary renaming, split names, explicit ROS prefix, and cache/unrelated-path exclusions are exact. |
| `VerifyTemplateProjectReleaseTagSync.cmake` | `cpu` | `release;ros2;version`, 180 s | a disposable Git release moves from preparation to one exact final tag; metadata sync changes only four ROS manifests; tag/manifests/package names agree; the canonical archive excludes owned active/generated builds while retaining foreign caches and legitimate `install`/source paths; extracted validation succeeds; the source checkout and tags remain unchanged. |
| `VerifyTemplateProjectCudaSources.cmake` | `cuda` | `cuda;sources;template`, 240 s; `ENABLE_CUDA` | isolated CUDA target builds, the CUDA placeholder belongs to its compile graph, and the OptiX PTX input does not compile as an ordinary source when OptiX is off. |
| `VerifyTemplateProjectOptixInstallExport.cmake` | `cuda` | `optix;install;package;template`, 360 s; `ENABLE_OPTIX` and SDK | the OptiX target builds/installs; exactly one target export exists; it leaks neither the build-machine SDK root nor a nonexistent package-local SDK; an installed consumer finds OptiX explicitly and builds. |
| `VerifyTemplateProjectCudaWithoutCatch2.cmake` | `cuda` | `cuda;catch2;configure`, 180 s; `nvcc` | CUDA configures and builds successfully with tests/Catch2 disabled. |
| `VerifyTemplateProjectCrossCompile.cmake` | `cpu` | three `cross;aarch64` entries, 180 s each; GNU aarch64 toolchain | cross compile commands reject host-native flags and require cross/aarch64/Linux definitions; the core target, installed consumer, and nested consumer each configure/build through the selected toolchain. |
| `testDevcontainerJson.py` | `cpu` | `pytest;python`, 120 s | JSONC comments and unmanaged values survive; Docker, Podman CDI, and disabled-CUDA GPU arguments normalize exactly; the shell configurator forwards the selected runtime. |
| `testWorkflowTemplates.py` | `cpu` | `pytest;python`, 120 s; PyYAML | active/dormant workflows parse; release tags, explicit CUDA opt-in, path ownership, job topology, full-history checkout, shell syntax, Pages actions, ROS ordering, drift rejection, marker-free metadata helper execution, and structured repository configuration satisfy their parser-backed contracts. |
| `testRos2OverlayStatic.py` | `ros2` | `pytest;python`, 120 s | metadata-only configure exports standard fields without enabling C++; manifests match root metadata; ignore markers exist; missing ROS environment fails before mutation; copied metadata synchronization preserves names, dependencies, URLs, modes, XML model instructions, and idempotence; `--no-sync-ros2` is non-mutating. |

Additional TestField-owned candidate-template assertions already present in the
transitional block:

| Owner file or case | Profile | Existing properties and prerequisites | Behavioral assertions |
|---|---|---|---|
| `VerifyTemplateProjectBuildMode.cmake`, shared/static | `cpu` | no labels/timeout | each selected library kind installs the exact artifact; an installed downstream consumer configures, builds, exists, and runs. |
| Candidate docs, nested-docs, version, and tailoring entries | mixed | shared `template_project;docs;version`, 240 s | exact duplicates of four template-owned entries above; migrate once, never duplicate them in the standalone union. |
| `VerifyTemplateProjectPythonPackage.cmake`, Python 3.12/3.11 | `cpu` | `template_project;python;wrapper`, 240 s, `template_project_python_wrapper` lock; interpreter and gtwrap | the wrapper builds and passes its checkout import test; generated interpreter metadata is exact; isolated pip install/import succeeds on 3.12 and is rejected on 3.11. |
| `VerifyMatlabWrapperSmoke.cmake`, candidate case | `cpu` | `matlab;wrapper;elf`, 600 s, `matlab` lock, skip regex `MATLAB executable not found`; MATLAB and gtwrap | the candidate MATLAB wrapper configures/builds, toolbox/MEX/core artifacts exist, tcmalloc linkage matches policy, and the MATLAB smoke executes. The two TestField-source cases remain TestField acceptance, not candidate conformance. |
| `VerifyTemplateProjectCudaArchDetection.cmake`, seven cases | `cuda` | 30 s each | valid x86 `nvidia-smi` and Xavier/Orin/Thor fixtures select exact architectures; missing/malformed x86 discovery and ambiguous aarch64 discovery fail. |
| `VerifyTemplateProjectOptixPreflight.cmake`, three cases | `cuda` | negative cases use the wrapper resource lock and 120 s; positive case requires `nvcc`, `nvidia-smi`, and SDK | header-only and missing-PTX sources fail before OptiX handling; an explicit positive SDK configure retains OptiX and architecture 87. |
| `VerifyTemplateProjectBuildLibWrapper.cmake`, three cases | `cpu` | wrapper resource lock, 120 s; gtwrap for success | `build_lib.sh --python-wrap` builds the module; a missing interface disables the wrapper cleanly; rebuild-only preserves the configured wrapper-off cache and produces no module. |

Retained starter/runtime entries are outside the migration union: five logger
Catch2 cases, the C++ placeholder, Python import smoke, CUDA initialization
fixture and buffer round-trip, target-owned MATLAB regression/ELF checks,
reusable fixtures, and ROS 2 package runtime tests. TestField's own two Catch2,
three pytest, and project-identity acceptance contracts also remain distinct
from candidate-template conformance.

Inventory findings:

- no existing entry uses `SKIP_RETURN_CODE`, `DEPENDS`, or CTest dependency
  fixtures for template-system conformance;
- the only conformance skip is the MATLAB
  `SKIP_REGULAR_EXPRESSION`; CUDA, OptiX, cross, and interpreter prerequisites
  currently omit tests at configure time;
- four transitional entries execute verifier implementations from the
  candidate checkout, so TestField does not yet own them;
- build-mode, CUDA-architecture, OptiX-preflight, build-helper-wrapper, and
  positive OptiX entries have incomplete labels; the standalone registry must
  assign one consistent `template_harness` label plus profile/contract labels;
- the wrapper resource lock currently serializes Python package, negative
  OptiX preflight, and build-helper wrapper checks; retain it through parity,
  then remove it only if source/build isolation proves concurrent safety;
- normal TestField CTest currently registers recursive TestField
  configure/build/install checks. They are not candidate-template conformance;
  their ownership must be reconciled with the derived-project acceptance
  policy before the Stage 5 handoff.

### Stage 3 execution evidence

- Baseline:
  - isolated branch `major/refactor-tests-ownership` starts at exact TestField
    `v1.12.1`, `f632290ce1bfb1f80baeeb3da2ea6db28a998037`;
  - the unchanged baseline build passed `40/40`.
- Harness TDD:
  - RED: the first public configure test failed because
    `template_harness/CMakeLists.txt` did not exist;
  - RED: exact profile assertions reported incomplete CPU and empty docs,
    CUDA, and ROS 2 inventories;
  - GREEN: `tests/harness/testTemplateHarness.py` passed `11/11`, covering
    required inputs, semantic diagnostics, exact disjoint inventories, the
    duplicate-free `41`-test union, explicit candidate propagation, and
    TestField-owned nested release verifiers.
- Candidate parity against template v1.12.1:
  - CPU passed `24/24` in `75.82` seconds;
  - docs passed `2/2`;
  - CUDA/OptiX passed `13/13` with CUDA architecture `120`;
  - ROS 2 static conformance passed `2/2`;
  - the release verifier passed again after its nested ROS/source-archive
    paths were redirected to TestField-owned implementations;
  - candidate MATLAB and release checks passed after shared verifier
    deduplication.
- TestField independence:
  - RED: an isolated TestField source copy failed configure because the
    transitional facade required `../cpp_cuda_template_project`;
  - GREEN: the same isolated configure passed with no candidate checkout,
    candidate CTest entries, or facade cache variables;
  - the local Python option verifier passed after its external-only case and
    input were removed.
- TestField acceptance ownership:
  - RED: ordinary CTest still exposed `testfield_*` recursive acceptance and no
    standalone acceptance source existed;
  - GREEN: exact standalone inventories contain `11` CPU, `2` docs, and `1`
    CUDA entry; ordinary CTest contains no `testfield_*` acceptance entries;
  - full TestField acceptance passed `14/14` in `23.49` seconds.
- Documentation discrepancy:
  - RED: strict Doxygen rejected the new harness README link because that file
    was not an input;
  - GREEN: the guide is an explicit single-file input;
  - RED: the docs verifier then proved Doxygen enumerated non-input `lib/` and
    binary trees through unnecessary `EXCLUDE` directories;
  - GREEN: removing those directories retained the narrow allow-list and
    stopped both traversals.
- CI and dependency wiring:
  - parser-backed workflow contracts passed `16/16`;
  - native, docs, CUDA, and ROS workflows pin template commit
    `480d10a692836040bcae2023e763c553acfcc64d` and run their owning candidate
    profile;
  - native, docs, and CUDA workflows explicitly run TestField acceptance;
  - the stale non-gitlink template submodule declaration is removed.
- Deduplication:
  - transitional candidate registrations and their old TestField fixtures are
    deleted;
  - MATLAB/tcmalloc and extracted-source validation reuse one shared
    TestField-owned implementation;
  - exact inventory and behavioral parity show no unexplained lost or
    duplicated assertion.

## Stage 4 - Template reduction and tailoring simplification

- [x] Remove migrated template-conformance implementations and registrations
  only after Stage 3 parity is green.
- [x] Retain all starter-project runtime tests and fixtures.
- [x] Make `tests/CMakeLists.txt` stable for derived projects.
- [x] Remove root- and test-CMake rewriting from tailoring.
- [x] Preserve production wrapper modules and downstream custom tests.
- [x] Run default and `--remove-ros2` tailoring twice for idempotence.
- [x] Build and test both tailored results.
- [x] Prove tailored projects contain no TestField or template-conformance
  dependency.

### Stage 4 execution evidence

- Ownership TDD:
  - RED: the expanded TestField tailoring verifier exited `1` before cleanup
    and enumerated all `18` candidate-owned `VerifyTemplateProject*` files;
  - GREEN: the same verifier passed after the migrated CMake verifiers,
    source-release verifier, devcontainer contract, workflow contract, and
    static ROS contract were removed from the template.
- Stable starter suite:
  - `tests/CMakeLists.txt` now contains only inherited runtime registration;
  - fresh untailored CPU configure/build passed `7/7`: five logger cases, one
    C++ starter case, and one Python import smoke;
  - C++/Python/CUDA starter files, reusable fixtures, MATLAB wrapper smoke, and
    target-owned dependency checks remain in the template.
- Tailoring simplification:
  - root- and test-CMake patch functions and calls were deleted;
  - the TestField fake project proves both CMake files remain byte-for-byte
    stable, production wrapper modules survive, and even a downstream custom
    `VerifyTemplateProjectCustomBehavior.cmake` file is preserved;
  - unreachable non-apply mutation branches were removed from the cleanup
    implementation.
- Workflow single source:
  - RED: the v2 tailoring contract rejected four dormant `.yml.tpl` workflow
    copies;
  - GREEN: generic CPU, CUDA, ROS, and Pages workflows are the only runnable
    definitions and parse successfully;
  - TestField's parser-backed workflow suite passed `11/11`;
  - ROS rollout RED identified its obsolete `.tpl` dependency, then GREEN
    passed after it copied the canonical active workflow directly.
- Wrapper follow-ups:
  - RED: a configure fixture resolved a valid source-relative gtwrap checkout
    to an empty path;
  - GREEN: the resolver canonicalizes the spelling against
    `PROJECT_SOURCE_DIR`, and the existing shell-wrapper verifier passed;
  - fallback Python package metadata now requires `>=3.12`.
- Real tailored copies:
  - default and `--remove-ros2` copies each produced identical complete
    path/mode inventories and file hashes between first and second cleanup;
  - root and test CMake SHA-256 values were unchanged across cleanup;
  - both copies configured, built, and passed `7/7`;
  - the default copy retained `ros2/` and its workflow, while the ROS-removed
    copy retained neither;
  - root CMake, production modules, tests, workflows, and shell helpers contain
    no TestField, standalone-harness, or `VerifyTemplateProject` dependency.

## Stage 5 - Integrated v2 validation and release preparation

- [x] Run TestField local tests without a template checkout.
- [x] Run all applicable standalone harness profiles.
- [x] Run clean CPU, docs, CUDA/OptiX, ROS 2, wrapper, install/consumer,
  release, shell, Python, YAML, XML, and Git-hygiene gates.
- [x] Verify source releases inside and outside an unrelated parent Git
  repository.
- [ ] Inspect both complete indexes under the staged-code quality gate.
- [x] Re-run the highest-risk wrapper, harness, tailoring, and release gates.
- [ ] Prepare one functional ownership batch per repository and only an
  unavoidable later compatibility-pin batch.
- [ ] Stop before pushes or final v2.0.0 tags unless explicitly authorized.

### Stage 5 local execution evidence

- Candidate-independent TestField:
  - normal configure/build/CTest passed `5/5` and its cache contains neither
    `TEMPLATE_PROJECT_SOURCE_DIR` nor
    `ENABLE_TEMPLATE_PROJECT_BUILD_TESTS`;
  - candidate-independent harness/workflow pytest passed `18/18`;
  - the standalone TestField acceptance union passed `14/14`, containing
    `11` CPU, `2` docs, and `1` CUDA entry.
- Explicit candidate harness:
  - CPU passed `24/24`, including shared/static installed consumers, Python
    3.12 install/import, Python 3.11 rejection, MATLAB, packaging, wrapper,
    tailoring, release, workflow, devcontainer, and cross-compilation
    contracts;
  - docs passed `2/2`;
  - CUDA/OptiX passed `13/13` with CUDA architecture `120` and the explicit
    OptiX SDK;
  - ROS 2 static/metadata passed `2/2`;
  - exact profile inventories remain disjoint and their `all` union contains
    `41` tests.
- Template runtime:
  - the refreshed CPU build passed `7/7`;
  - the refreshed CUDA/OptiX build passed `9/9`, including the initialization
    gate and device-memory round trip;
  - a clean ROS 2 Jazzy overlay built all four packages and reported `10`
    tests, `0` errors, `0` failures, and `0` skips.
- High-risk reruns:
  - the complete CPU harness reran wrapper packaging, runtime staging,
    build-helper wrapper modes, tailoring idempotence, release metadata/source
    archives, and installed consumers successfully;
  - the release verifier passed once with its binary root inside TestField's
    unrelated parent Git checkout and again from
    `/tmp/cpp_cuda_template_v2_release_outside_git_final`.
- Static and repository hygiene:
  - every current shell file passed `bash -n`;
  - every changed or new shell file passed ShellCheck;
  - all current Python files byte-compiled;
  - `8` YAML and `4` XML files in each repository parsed successfully;
  - whitespace, exact conflict-marker, generated-manifest, and CMake 3.15
    forbidden-API checks passed in both repositories;
  - all six changed/new TestField Python modules have module, class, and
    callable documentation.

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
- Status: resolved. The TestField candidate now targets exact template
  `v1.12.1` and uses the released build-time resolved-artifact staging design.

### ISSUE-006 - Remote evidence does not cover the index

- Stage: 1
- Severity: environment
- Expected: validation evidence covers the exact candidate delivered for review.
- Observed: current successful GitHub checks cover only committed v1.12.0.
- Action: run fresh local acceptance against the complete staged candidate and
  report remote CI as pending until a push is authorized.
- Status: resolved for the template release. The pushed v1.12.1 branch/tag
  checks completed successfully; the unpushed TestField candidate is covered by
  its fresh local Stage 2 matrix.

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

### ISSUE-009 - TestField library ignored static selection

- Stage: 2
- Severity: blocking
- Expected: `BUILD_SHARED_LIBS=OFF` produces an installed static library usable
  by a downstream consumer.
- Observed: TestField hardcoded `add_library(... SHARED ...)`, even though its
  documentation advertised both modes.
- Action: declare the standard option with the existing shared default, select
  the target kind explicitly, and run both installed-consumer modes.
- Status: resolved. Shared and static disposable consumers both passed.

### ISSUE-010 - Explicit relative gtwrap root in released template

- Stage: 2, deferred template follow-up
- Severity: worthwhile
- Expected: a valid explicit `--gtwrap-root lib/wrap` is resolved relative to
  the source checkout before generated commands use it.
- Observed: the released common resolver preserves the relative cache spelling,
  so generated commands may reinterpret it relative to the binary tree.
- Action: TestField canonicalizes the explicit root at its common resolver
  boundary. Apply and verify the same small correction when template
  development resumes after the v1.12.1 release baseline.
- Status: resolved in both repositories. The Stage 4 configure fixture proves
  the template resolver returns the canonical source-absolute path.

### ISSUE-011 - TestField wrapper target-help pipeline was generator-sensitive

- Stage: 2
- Severity: worthwhile
- Expected: the shell helper confirms the actual wrapper target without false
  warnings.
- Observed: under `set -o pipefail`, `rg -q` could close the target-help pipe
  after its first match and make the upstream CMake process fail with a broken
  pipe.
- Action: read the wrapper target name published in `CMakeCache.txt` instead of
  parsing generator-specific help output.
- Status: resolved. The real relative-root wrapper build completed without the
  false warning.

### ISSUE-012 - Fallback Python metadata retains the obsolete interpreter floor

- Stage: 2, deferred template follow-up
- Severity: worthwhile
- Expected: the missing-`pyproject.toml.in` fallback preserves the project-wide
  Python 3.12 minimum.
- Observed: released `HandlePythonWrapper.cmake` writes
  `requires-python = ">=3.8"` while normal template and TestField metadata
  require `>=3.12`.
- Action: TestField aligns the fallback with 3.12 now. Apply the same literal
  correction to the template in its next maintenance or v2 reduction batch.
- Status: resolved in both repositories. The template fallback now requires
  Python 3.12 and the TestField wrapper preflight enforces that contract.

### ISSUE-013 - TestField root target-option setup is duplicated

- Stage: 2, deferred v2 cleanup
- Severity: cosmetic
- Expected: one assignment block owns each target and namespaced option name.
- Observed: TestField's pre-existing root CMake file repeats
  `LIB_TARGET_NAME`, `BUILD_PROGRAMS_OPTION_NAME`, and
  `BUILD_EXAMPLES_OPTION_NAME` setup verbatim.
- Action: remove the duplicate with the Stage 3 root-CMake harness migration,
  where the adjacent transitional external-test facade is already changing.
- Status: resolved in Stage 3; the repeated assignment block was removed with
  the adjacent facade.

### ISSUE-014 - TestField Doxygen discovery traverses generated builds

- Stage: 2, deferred v2 cleanup
- Severity: worthwhile
- Expected: Doxygen discovery remains limited to owned source and documentation
  inputs.
- Observed: the successful documentation target traversed ignored CPU, release,
  wrapper, and MATLAB fixture build products, creating excessive output and
  unnecessary work.
- Action: narrow documentation discovery during Stage 5 integrated v2
  validation and prove generated products remain excluded.
- Status: resolved in Stage 3; the strict verifier now rejects traversal of
  both `lib/` and the active binary tree.

### ISSUE-015 - Transitional conformance is not fully TestField-owned

- Stage: 3
- Severity: blocking
- Expected: every standalone candidate-template assertion executes an
  implementation versioned by TestField.
- Observed: docs, nested-docs, version-side-effect, and tailoring entries invoke
  scripts from `TEMPLATE_PROJECT_SOURCE_DIR`; build-mode, CUDA-architecture,
  OptiX-preflight, build-helper-wrapper, and positive OptiX entries also have
  incomplete labels.
- Action: migrate one TestField-owned copy of every verifier, deduplicate the
  four reused entries in the standalone registry, and assign consistent
  harness/profile/contract labels while preserving timeouts and resource locks
  through parity.
- Status: resolved in Stage 3; all `41` candidate entries execute
  TestField-owned implementations with normalized profile and contract
  properties.

### ISSUE-016 - TestField advertises an untracked template submodule

- Stage: 3
- Severity: worthwhile
- Expected: dependency declarations describe paths represented by Git links or
  by explicit workflow checkouts.
- Observed: `.gitmodules` contains `lib/cpp_cuda_template_project` and an old
  branch hint, but the index has no gitlink at that path. CI independently
  checks out the candidate into a workspace sibling without an exact ref.
- Action: remove the stale submodule stanza and make the standalone workflow
  checkout an explicit full commit SHA.
- Status: resolved in Stage 3; the stale stanza is removed and each CI
  candidate checkout uses the full v1.12.1 commit SHA.

### ISSUE-017 - A local TestField option test depends on the external facade

- Stage: 3
- Severity: blocking
- Expected: TestField-local CTest configures and runs without any candidate
  template path.
- Observed: `VerifyTestfieldPythonTestOptions.cmake` receives
  `TEST_TEMPLATE_SOURCE_DIR` and asserts that
  `ENABLE_TEMPLATE_PROJECT_BUILD_TESTS=ON` registers tests even when
  `ENABLE_TESTS=OFF`.
- Action: remove the external-only case and candidate input; retain only the
  local Python-runner/conda option contracts after the facade is deleted.
- Status: resolved in Stage 3; the local verifier has no candidate input or
  external-only case.

### ISSUE-018 - Recursive TestField acceptance remains in ordinary CTest

- Stage: 3 and 5
- Severity: worthwhile
- Expected: normal derived-project CTest contains runtime Catch2/pytest behavior,
  while fresh configure/build/install/consumer acceptance is invoked explicitly
  by local CI.
- Observed: TestField currently registers flags, docs, nested install,
  release, cross, CUDA-source, and related self-reconfigure scripts in its
  ordinary CTest graph.
- Action: do not mix this cleanup with candidate-harness parity. Before the
  Stage 5 handoff, relocate the still-unique TestField acceptance invocations
  to an explicit out-of-tree CI-owned entry point and leave normal CTest with
  runtime behavior only.
- Status: resolved after candidate parity; the explicit TestField acceptance
  project owns `14` entries and normal CTest is project-runtime-only.

### ISSUE-019 - Dormant workflow copies preserve tailoring-only complexity

- Stage: 4
- Severity: worthwhile
- Expected: moving template-system conformance to TestField reduces the
  template and the effort required to tailor it.
- Observed: retaining active template-validation workflows beside dormant
  generic `.yml.tpl` copies would require pair validation, marker checks,
  materialization, and additive-ROS special handling after their conformance
  jobs had moved.
- Action: promote the generic workflows as the template's only active
  definitions, remove all dormant copies and materialization code, and keep
  their semantic contracts in TestField.
- Status: resolved. The template and derived projects share four direct
  workflows; `--remove-ros2` deletes only the ROS workflow.

### ISSUE-020 - Repository-wide ShellCheck includes unrelated legacy warnings

- Stage: 5
- Severity: cosmetic
- Expected: distinguish migration regressions from pre-existing shell-helper
  debt during the final hygiene gate.
- Observed: an all-file ShellCheck invocation reports existing warnings in
  unchanged devcontainer, VS Code, and profiling helpers.
- Action: require `bash -n` for every current shell file and ShellCheck every
  changed or new shell file. Do not expand the v2 ownership migration into
  unrelated legacy cleanup.
- Status: open as non-blocking pre-existing maintenance debt; no changed or new
  shell file has a ShellCheck finding.

### ISSUE-021 - Migrated workflow verifier retained dormant-template naming

- Stage: 5
- Severity: cosmetic
- Expected: TestField terminology describes the direct reusable workflows
  introduced by the v2 architecture.
- Observed: the migrated live parser module and test class still used
  `testWorkflowTemplates` even though dormant `.yml.tpl` files no longer exist.
- Action: rename the live module and class to
  `testTemplateProjectWorkflows` while retaining the old path only in the
  tailoring verifier's forbidden-legacy inventory.
- Status: resolved; direct pytest passed `11/11` and the stable harness CTest
  entry passed.

### ISSUE-022 - Integrated-test residue remained in TestField review surfaces

- Stage: 5
- Severity: worthwhile
- Expected: ordinary TestField CTest and native CI express only their current
  runtime responsibilities.
- Observed: the reduced `tests/CMakeLists.txt` retained obsolete scaffolding,
  the native workflow repeated a path already covered by `tests/**`, and native
  test jobs still required Doxygen/Graphviz after docs acceptance moved out.
- Action: collapse the runtime test registry, deduplicate the trigger, keep
  PyYAML as the real parser prerequisite, and leave documentation tools with
  the docs profile.
- Status: resolved; workflow pytest passed `16/16` and normal TestField CTest
  passed `5/5`.

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

### Stage 2 published TestField release gate - 2026-07-28

- State:
  - TestField branch `main`;
  - signed commit `f632290ce1bfb1f80baeeb3da2ea6db28a998037`;
  - signed annotated tag `v1.12.1` dereferences to that exact commit;
  - the final commit contains `19` related files with `1,878` insertions and
    `536` deletions;
  - TestField has no tracked or staged change and matches `origin/main`;
  - remote branch `main` and remote tag `v1.12.1^{}` both resolve to the signed
    release commit.
- Implemented behavior:
  - the 1,332-line candidate facade is replaced by a 579-line common
    coordinator plus focused Python, MATLAB, and runtime-staging modules;
  - Python runtime and wrapper filenames are resolved for the active
    configuration and validated as one namespace before copying;
  - clean paths, source archives, wheels, and CMake installs enforce their
    ownership boundaries;
  - relative explicit gtwrap roots are canonicalized;
  - TestField now honors shared and static library modes;
  - all four ROS 2 manifests contain `1.12.1`.
- Validation:
  - fresh CPU passed `40/40`;
  - CUDA 12.9.41 with `sm_120` passed `41/41`;
  - the explicit OptiX build passed `17/17`;
  - ROS 2 Jazzy built four packages and reported `10` tests, `0` errors,
    `0` failures, and `0` skips;
  - real wrapper, wheel, isolated pip import, CMake-prefix import, shared/static
    consumer, cleanup, source-release, Doxygen, shell, Python, YAML, XML,
    whitespace, conflict-marker, and CMake-floor API checks passed;
  - exact-tag metadata regeneration derived `1.12.1` and left tracked content
    clean;
  - branch/tag native CI passed `35/35` applicable hosted-runner tests per run;
  - branch/tag ROS 2 CI each passed `10` tests with no errors, failures, or
    skips;
  - documentation CI passed; CUDA remained the expected policy skip.
- Staged-code review:
  - all substantially modified modules have file/callable documentation and
    purpose-oriented block comments;
  - the fallback Python floor was corrected from 3.8 to 3.12;
  - the package entrypoint gained its module contract and runnable example;
  - inaccurate “atomic” wording was replaced with “serialized staging.”
- Open or deferred:
  - ISSUE-008 records the unavailable exact local CMake 3.15 runtime;
  - ISSUE-010 and ISSUE-012 are small template follow-ups after v1.12.1;
  - ISSUE-013 and ISSUE-014 remain non-blocking v2 TestField cleanup;
  - the remote CUDA skip remains expected while self-hosted CI is disabled.
- Readiness: Stage 2 is complete and published. The signed TestField commit and
  tag are remotely available and all enabled CI paths are green. Stop here
  until review or authorization to begin Stage 3.

### Integrated v2 local release-preparation gate - 2026-07-28

- Ownership outcome:
  - the template keeps only runtime tests and fixtures inherited by tailored
    projects;
  - TestField owns all generic candidate conformance through the explicit
    standalone harness;
  - TestField's ordinary build is candidate-independent and its own expensive
    acceptance is a separate CI-owned project;
  - tailoring no longer reconstructs CMake files or materializes workflows.
- Reduction:
  - the template batch removes approximately `6,700` lines while retaining
    production wrapper, CUDA, ROS, packaging, and tailoring behavior;
  - dormant workflow copies, pair validation, workflow materialization, and
    template self-conformance registrations are gone;
  - TestField contains one copy of every external verifier and stable
    CPU/docs/CUDA/ROS profile registries.
- Validation:
  - TestField runtime passed `5/5`, TestField acceptance passed `14/14`, and
    candidate conformance passed `24/24` CPU, `2/2` docs, `13/13` CUDA/OptiX,
    and `2/2` ROS 2;
  - template runtime passed `7/7` CPU and `9/9` CUDA/OptiX;
  - the clean Jazzy overlay passed all `10` reported tests;
  - source release, wrapper packaging, install/consumer, tailoring
    idempotence, shell, Python, YAML, XML, whitespace, Git, and CMake-floor
    gates passed.
- Maintainability:
  - root/test CMake and project workflows are stable across tailoring;
  - new harness modules have explicit file ownership, callable documentation,
    purpose-oriented comments, and stable named inventories;
  - live workflow terminology reflects direct project workflows rather than
    removed dormant templates;
  - design, execution evidence, discrepancies, and this report remain in this
    one tracker.
- Remaining gates:
  - inspect the complete staged index in both repositories;
  - create one related functional commit in the template;
  - pin TestField workflows to that exact template commit, then create one
    related TestField commit;
  - push the authorized branches and inspect remote CI;
  - do not create final `v2.0.0` tags without explicit user authorization.
- Known limitation: no CMake 3.15 executable is installed locally. Static API
  checks passed; the exact minimum-version runtime remains a remote CI gate.
