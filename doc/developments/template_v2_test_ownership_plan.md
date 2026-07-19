# Template v2 Test Ownership Separation and CI Consolidation Plan

## Status

- `v1.11.1` consolidation baseline: complete and tagged in both repositories.
- `v2.0.0` ownership-separation implementation: not started.
- Target release: `v2.0.0` for both `cpp_cuda_template_project` and
  `cpp_cuda_template_testfield`.
- Baseline template tag: signed `v1.11.1` at
  `ed11d837fc9e107f00ca462fefd47e7da73c5d2a`.
- Baseline testfield tag: signed `v1.11.1` at
  `909ed165fc0637cbbbcdeccf3bf641677bd3d701`.
- Main repository branch: `main` in both repositories.
- Last rebaselined against repository and GitHub state: 2026-07-19.
- This document is the source of truth for the v2 test-ownership and CI pass.
- Final commits, pushes, and release tags require explicit user approval.

## Goal

Move tests that verify the template system itself out of
`cpp_cuda_template_project` and into a standalone harness owned by
`cpp_cuda_template_testfield`. Keep tests that are intended to be tailored into
a derived project in the template repository. Link the two repositories through
deterministic CI without making a tailored project depend on the testfield.

At the same time, preserve the green `v1.11.1` contracts, close the remaining
source-tree and checkout-layout risks, eliminate build-tree artifact transfers,
bound cache usage, make source-release and version detection independent of
checkout layout, and prepare both repositories for `v2.0.0`.

`v1.11.1` is the immutable consolidation input, not the target of this plan.
The move of template-conformance ownership into a separate repository is the
large compatibility and maintenance boundary that justifies `v2.0.0`.

The implementation goal ends at a reviewed, staged, release-ready state. It
does not include committing, pushing, merging, or creating final `v2.0.0` tags.

## Fixed decisions

- The signed `v1.11.1` tags are the last consolidated baseline. Do not move,
  recreate, or repurpose them during v2 implementation.
- `cpp_cuda_template_testfield` has two roles: a representative derived project
  and the owner of the external template-conformance harness.
- Active workflows in `cpp_cuda_template_project` verify the template itself.
  Dormant `.yml.tpl` workflows remain generic derived-project workflows.
- A tailored project must contain no testfield checkout, harness path, template
  verifier, or template-repository-only assertion.
- Template CI consumes a testfield checkout pinned by full 40-character commit
  SHA. Testfield CI uses an explicitly pinned compatible functional template
  SHA; the final template commit that only updates the testfield pin does not
  need to be mirrored back into the testfield pin.
- The harness uses sibling checkouts and explicit CMake inputs. It must not infer
  dependencies from machine-specific absolute paths or accidental directory
  adjacency.
- Existing repository-specific tailoring and tests in derived projects are
  preserved. Migration guidance must never instruct agents to delete custom
  tests merely because the original template harness moved.
- ROS workflows are event-driven only. Neither active template workflows nor
  generic derived-project workflow templates gain a scheduled trigger.
- Workflow contracts verify parsed structure and observable behavior. They do
  not grep helper implementation text for capability markers.
- The dependency-free `CLogger` is retained project infrastructure. Its runtime
  behavior tests remain starter tests, while namespace-tailoring verification
  moves to the external harness.
- The optional legacy spdlog adapter remains supported unless a separately
  approved compatibility change removes it. Its acquisition must be
  source-tree clean and its runtime tests remain with the starter project.
- Work red-green whenever a regression guard is added: record the expected
  failure, apply the smallest owning fix, and rerun the same command.
- The final review is a mandatory terminal stage. Passing implementation-stage
  tests does not complete the goal.

## Ownership after migration

### Tests retained in `cpp_cuda_template_project`

- C++ placeholder, dependency-free `CLogger`, and optional spdlog adapter
  behavior tests.
- Python import smoke test.
- CUDA runtime initialization gate and CUDA placeholder test.
- ROS conversion, node, lifecycle, service, publication, and launch tests.
- Starter fixtures used by project tests.
- MATLAB wrapper placeholder registration, executable smoke behavior, and
  tcmalloc dependency check. These remain available after tailoring.

### Tests owned by `cpp_cuda_template_testfield`

- Every `VerifyTemplateProject*` CMake verifier.
- Template source-release and release-tag synchronization verification.
- Template workflow, workflow-template, ROS static, and devcontainer checks.
- Template build/install/consume, nested-build, package-export, flag, version,
  cross-compilation, CUDA, and OptiX conformance checks.
- External Python and MATLAB wrapper conformance checks.
- Tailoring and generated-workflow materialization verification.
- Logger namespace-tailoring and retained-file conformance checks.

### Testfield-local tests

Testfield implementation tests remain independent from candidate-template
conformance. A normal testfield build can run its local tests without requiring
a template checkout. External conformance is enabled explicitly.

## Public configuration contracts

- `TEMPLATE_PROJECT_SOURCE_DIR`: required candidate template source path for
  external conformance.
- `TEMPLATE_PROJECT_GTWRAP_SOURCE_DIR`: required wrap source path when wrapper
  conformance is enabled. CI uses the testfield's pinned `lib/wrap` submodule.
- `TEMPLATE_HARNESS_PROFILE`: cache string with values `cpu`, `docs`, `cuda`,
  `ros2`, or `all`; default `cpu`.
- `ENABLE_TEMPLATE_PROJECT_BUILD_TESTS`: retained in testfield as a compatibility
  facade, default `OFF`. When enabled, it requires an explicit candidate path
  and delegates registration to the standalone harness.
- Primary CTest labels: `template_cpu`, `template_docs`, `template_cuda`, and
  `template_ros2`. Secondary labels describe release, tailoring, wrapper,
  package, cross-compilation, and other focused contracts.
- Workflow-dispatch input `runner`: `auto`, `github-hosted`, or `self-hosted`;
  default `auto`.
- Workflow-dispatch input `run_tests`: boolean, default `true`. Push and pull
  request runs always build and test.
- Repository variables: `CI_USE_SELF_HOSTED`, `CI_CPU_RUNNER_LABELS`, and
  `CI_CUDA_RUNNER_LABELS`. Runner-label variables contain JSON arrays and have
  documented defaults.

## Goal execution and exit rules

### Continue conditions

The goal remains active when any of the following is true:

- [ ] Any implementation or exit-condition checkbox in Stages 0-6 is unchecked.
- [ ] A required test is failing, unexecuted without an accepted reason, or has
  only been inferred from static inspection.
- [ ] Validation evidence has not been appended to the stage-output log.
- [ ] The mandatory final review has not run against the complete integrated
  diff in both repositories.
- [ ] A final-review finding requiring intervention remains open.

### Successful goal exit

The implementation goal may be marked complete only when all conditions hold:

- [ ] Every applicable Stage 0-6 checkbox is complete.
- [ ] Every stage exit condition is satisfied in order.
- [ ] Stage 6 reports no unresolved major or worthwhile minor finding.
- [ ] All required clean-build, harness, tailoring, release, workflow, shell,
  YAML, metadata, CUDA/OptiX-when-available, and ROS gates pass.
- [ ] Both worktrees contain only understood changes and generated outputs are
  excluded from Git.
- [ ] The proposed commit split and release-tag procedure are ready for user
  review.
- [ ] No commit, push, merge, or final tag has been performed by the agent.

Waiting for user review, commit creation, push, merge, or tag authorization is
the successful handoff state, not an implementation failure.

### Blocked goal exit

- Do not mark the goal blocked because work is difficult, slow, or awaiting a
  normal stage rerun.
- Exhaust independent work and practical local alternatives first.
- A blocker is terminal only when the same external condition prevents
  meaningful progress across three consecutive goal turns and no independent
  stage work remains.
- Missing optional hardware is recorded as an explicit conditional skip unless
  that hardware is required to validate a changed contract. It does not by
  itself block CPU, docs, release, tailoring, or ROS work.
- When blocked, append the exact command, output, prerequisite, completed work,
  and safe resume point to the stage-output log before returning control.
- Never mark the goal complete because a token, time, or execution budget is
  nearly exhausted.

## Evidence and staging discipline

- [ ] Create `doc/developments/TEMPLATE_V2_STAGE_OUTPUTS.md` at Stage 0.
- [ ] Seed it with the signed `v1.11.1` tag objects and commits, current local
  baselines, and the green GitHub run IDs recorded below. Do not recreate or
  depend on the intentionally removed `ROS2_OVERLAY_STAGE_OUTPUTS.md`.
- [ ] Append red and green commands, relevant output, test totals, skips,
  warnings, and blockers immediately after each stage.
- [ ] Keep each stage reviewable as one functional batch. Stage only files that
  belong to the approved batch and report the exact staged file list.
- [ ] Do not commit or push either repository unless the user gives a new,
  explicit instruction for that operation.

---

## Stage 0 - Freeze the v1.11.1 baseline and close residual prerequisites

### Verified baseline on 2026-07-19

- [x] Template `main`, signed tag `v1.11.1`, and `origin/main` resolve to
  `ed11d837fc9e107f00ca462fefd47e7da73c5d2a`; tag-resolved CMake/CPack metadata,
  committed `VERSION`, and all four ROS manifests report `1.11.1`.
- [x] Testfield `main`, signed tag `v1.11.1`, and `origin/main` resolve to
  `909ed165fc0637cbbbcdeccf3bf641677bd3d701`; tag-resolved CMake/CPack metadata,
  committed `VERSION`, and all four ROS manifests report `1.11.1`.
- [x] Template branch and tag gates are green at the baseline SHA: CPU
  `29687029686` and `29687032003`, docs `29687029677`, and ROS
  `29687029683` and `29687031996`. CUDA run `29687031981` is intentionally
  skipped because self-hosted execution was not enabled.
- [x] Testfield branch and tag gates are green at the baseline SHA: CPU
  `29687287479` and `29687289696`, docs `29687287459`, and ROS
  `29687287456` and `29687289744`. CUDA run `29687289718` is intentionally
  skipped for the same explicit runner opt-in contract.
- [x] Both repositories use parser-backed semantic workflow checks. ROS metadata
  synchronization is executed and its result observed; workflow code no longer
  searches `generate_version.sh` implementation text for capability markers.
- [x] ROS workflows have no scheduled trigger. This is an intentional quota and
  runner-availability contract, not a missing workflow feature.
- [x] The prior release-snapshot directory-copy failure, nested candidate-path
  loss, missing wrap propagation, and CPU registration of OptiX preflight cases
  have been repaired and their latest remote CPU gates are green.
- [x] The dependency-free `CLogger`, logger namespace tailoring, nested installed
  header fix, project metadata flowdown, and semantic CI contract tests are part
  of the baseline and must not regress during ownership migration.

### Inventory and red guards

- [ ] Record current status, branches, exact tags, submodule SHAs, toolchain
  versions, complete CTest names/labels, conditional skips, and relevant pytest
  inventories for both repositories in `TEMPLATE_V2_STAGE_OUTPUTS.md`.
- [ ] Capture a machine-readable before-migration ownership inventory that Stage
  1 can compare against the standalone harness.
- [ ] Add a version regression that places an extracted no-Git source tree below
  a differently tagged parent Git repository. The child must use its own
  `VERSION` file.
- [ ] Add a spdlog regression proving automatic acquisition creates no path
  under the source tree.
- [ ] Add a testfield repository-topology check that reports `.gitmodules`
  entries without a matching Git link and rejects candidate-template checkouts
  nested inside the testfield repository.

### Residual fixes

- [ ] Remove the orphaned `lib/cpp_cuda_template_project` section from the
  testfield `.gitmodules`; verify no matching Git link exists.
- [ ] Move automatic spdlog acquisition from `PROJECT_SOURCE_DIR/lib/spdlog` to
  a build-local dependency directory while preserving installed-package and
  intentional local-source precedence.
- [ ] In both repositories' `HandleGitVersion.cmake`, normalize
  `git rev-parse --show-toplevel` and use Git metadata only when that path equals
  the owning project root. Otherwise continue to the owned `VERSION` file.
- [ ] Preserve any user changes that appear during implementation. Never reset,
  overwrite, or absorb unrelated concurrent work into a stage batch.

### Exit condition

- [ ] Record the expected red result for every new Stage 0 guard before its fix,
  then record the corresponding green rerun.
- [ ] The remote-equivalent template CPU, docs, and ROS command sequences pass
  locally from clean build directories.
- [ ] The remote-equivalent testfield CPU, docs, and ROS sequences pass with no
  unexpected skip; MATLAB remains conditionally skipped when unavailable.
- [ ] Source configuration and dependency acquisition leave no generated
  dependency checkout in either source tree.
- [ ] `git diff --check` passes in both repositories.

---

## Stage 1 - Establish the standalone testfield harness

### Harness structure

- [ ] Create `tests/template_harness/CMakeLists.txt` in testfield as a project
  that can be configured independently of the testfield implementation.
- [ ] Validate all explicit source inputs before registering tests and report
  actionable errors for missing candidate or wrap roots.
- [ ] Implement profile registration so CPU/docs/ROS profiles do not initialize
  CUDA and the CUDA profile fails early when its required toolchain is absent.
- [ ] Keep CPU-only CUDA architecture parsing cases hermetic, but register OptiX
  configure/preflight cases only for the CUDA profile when `nvcc` is available.
- [ ] Keep all harness build and scratch paths below its binary root or caller
  supplied temporary roots.

### Ownership migration

- [ ] Move all template-conformance CMake verifiers from the template repository
  into the testfield harness.
- [ ] Move testfield's existing external candidate verifiers into the same
  harness and remove duplicate implementations.
- [ ] Move template workflow, ROS static, workflow-template, and devcontainer
  Python checks into the harness with explicit candidate-root fixtures. Preserve
  the `v1.11.1` parser-backed and executable behavior checks, including
  marker-free metadata-helper execution; do not restore source-text probes.
- [ ] Move external Python/MATLAB wrapper, install/consume, release, CUDA
  architecture, and OptiX checks into their appropriate profiles.
- [ ] Keep testfield-local implementation tests in the existing local test tree.

### Parity gate

- [ ] Before deleting any old registration, capture its test name, labels,
  prerequisites, timeout, resource locks, and expected skip behavior.
- [ ] Configure old and new registrations against the same candidate and compare
  `ctest -N` inventories by behavior, allowing only documented renames and
  profile separation.
- [ ] Run every new profile available on the host and compare results with the
  old owning tests.
- [ ] Record every intentionally consolidated duplicate and prove no behavioral
  assertion was lost.
- [ ] Separate runtime starter behavior from conformance assertions in mixed
  files, notably retaining `CLogger` and optional spdlog runtime tests while
  moving logger namespace-tailoring verification into the harness.

### Exit condition

- [ ] The standalone CPU, docs, and ROS profiles pass.
- [ ] The CUDA profile passes when the local CUDA/OptiX prerequisites are
  available; otherwise its registration and prerequisite diagnostic are tested.
- [ ] Testfield local tests pass with external conformance disabled.
- [ ] No harness test reads a verifier from the candidate's `tests/cmake` tree.
- [ ] The parity inventory contains no unexplained lost test or assertion.

---

## Stage 2 - Reduce template-owned tests and simplify tailoring

### Template test tree

- [ ] Remove migrated template-conformance verifiers only after Stage 1 parity is
  green.
- [ ] Retain the starter C++, `CLogger`, optional spdlog adapter, Python, CUDA
  runtime, ROS, fixture, and MATLAB tests listed in the ownership contract.
- [ ] Rewrite the template `tests/CMakeLists.txt` as a stable project-test file,
  not a file that tailoring later replaces.
- [ ] Ensure starter tests continue to use project metadata and target names that
  the tailoring/renaming process can adapt.
- [ ] Keep `src/utils/logging/CLogger.*` and `doc/logging.md` as tailored project
  infrastructure, with the namespace derived from the requested project
  namespace and no remaining template namespace.

### Tailoring behavior

- [ ] Remove root- and test-CMake patching from
  `tailor_template_cleanup.sh`.
- [ ] Remove migrated verifier paths from its cleanup inventory.
- [ ] Preserve MATLAB wrapper tests and registration after tailoring.
- [ ] Continue removing internal development reports/guidance and materializing
  generic workflows.
- [ ] Preserve every pre-existing custom test and repository-specific tailoring
  in scratch derived-project fixtures.
- [ ] Update derived-project agent guidance to state that donor harness removal
  never authorizes deletion of downstream tests.

### Exit condition

- [ ] Default and `--remove-ros2` scratch tailoring runs pass and are idempotent.
- [ ] Starter and injected custom tests are byte-identical before and after
  tailoring except for intentional project metadata renaming.
- [ ] Tailoring performs no edit to root `CMakeLists.txt` or
  `tests/CMakeLists.txt`.
- [ ] A tailored tree contains no testfield reference, `VerifyTemplateProject*`
  file, or template-only static test.
- [ ] The tailored project builds and runs its retained tests independently.
- [ ] Tailored logger runtime tests pass under the derived namespace, while the
  external harness owns the assertion that the renaming operation was complete.

---

## Stage 3 - Cross-repository CI and quota controls

### Active template CI

- [ ] Check out the current template and pinned testfield harness as sibling
  worktrees with full Git history; initialize the testfield wrap submodule. Pin
  the harness by a full commit SHA, not a moving branch or release tag.
- [ ] Run candidate starter tests and the relevant external harness profile in
  the same job and workspace.
- [ ] Update active CPU, docs, CUDA, and ROS path filters to include the pinned
  harness contract and the candidate files each profile owns.

### Testfield CI

- [ ] Build and test the testfield implementation independently.
- [ ] Check out a pinned compatible template SHA as a sibling and run the
  external harness explicitly. Do not rely on the current default branch.
- [ ] Keep release-snapshot, nested-build, and metadata tests independent of the
  Actions checkout directory name.

### Generic workflow templates

- [ ] Keep `.yml.tpl` workflows free of testfield references and template-only
  verifier names.
- [ ] Add `run_tests` to CPU and CUDA templates. A false manual value configures
  with tests disabled and executes no test command; push and pull requests always
  test.
- [ ] Keep generic workflows buildable immediately after materialization.
- [ ] Keep active and generic ROS workflows free of scheduled triggers.
- [ ] Have active template CI materialize every `.tpl`, parse the resulting YAML,
  and execute the represented project build, docs, CUDA-when-available, and ROS
  entry points rather than relying on text checks alone.

### Artifact, cache, and runner policy

- [ ] Merge each native build/test pair into one job. Remove build-tree
  `upload-artifact` and `download-artifact` steps from active workflows,
  testfield workflows, and `.tpl` workflows.
- [ ] On GitHub-hosted CPU jobs, use a bounded 512 MiB ccache through
  `actions/cache@v5`.
- [ ] On self-hosted jobs, use local ccache only; cap CUDA caches at 1 GiB and do
  not upload them to GitHub.
- [ ] Use `actions/checkout@v6` and Node-24-compatible action versions.
- [ ] Resolve `runner=auto` from `CI_USE_SELF_HOSTED`; retain explicit manual CPU
  overrides.
- [ ] Run CUDA only on the configured self-hosted GPU label set and skip the job
  unless `CI_USE_SELF_HOSTED=true`. Do not emulate CUDA or probe runner
  availability from another job. Preserve and generalize the `v1.11.1` explicit
  opt-in guard rather than weakening it during runner selection refactoring.
- [ ] Build and verify docs on ordinary events without uploading. Upload and
  deploy a Pages artifact only for an explicit manual deployment request.

### Exit condition

- [ ] Static workflow tests parse every active and dormant workflow and assert
  the runner, cache, test, action-version, checkout, artifact, and no-schedule
  contracts.
- [ ] No native workflow contains build-tree upload/download actions.
- [ ] No ordinary docs event contains a reachable artifact upload or Pages
  deployment.
- [ ] Materialized workflows pass their local execution rehearsals.
- [ ] Template workflows contain the pinned full testfield SHA; generic
  workflows contain no testfield identifier.

---

## Stage 4 - Documentation and v2 release preparation

### Documentation

- [ ] Update testing and CI documentation with the new ownership boundary,
  harness profiles, explicit paths, runner variables, test switch, and cache
  policy.
- [ ] Update template usage and tailoring documentation to identify retained
  starter tests and preserved downstream customization.
- [ ] Document the two-repository compatibility-pin update procedure without
  requiring derived repositories to adopt the testfield harness.
- [ ] Update release documentation with the pre-tag synchronization order for
  both repositories.
- [ ] Document `v1.11.1` as the immutable consolidation baseline and explain
  that `v2.0.0` is major because template-conformance ownership and CI topology
  move across repository boundaries, not because starter project APIs are
  intentionally redesigned.

### Metadata preparation

- [ ] Prepare both repositories' CMake, CPack, ROS manifests, and generated
  release metadata for core version `2.0.0` using the documented temporary-tag
  synchronization procedure.
- [ ] Delete only temporary v2 preparation tags after synchronization and before
  review. Preserve the signed `v1.11.1` baseline tags unchanged.
- [ ] Build canonical CPack source archives and verify them after extraction in
  directories both inside and outside an unrelated parent Git repository.
- [ ] Confirm no final `v2.0.0` tag exists or is created during implementation.

### Proposed functional split

- [ ] Prepare a testfield CI-stabilization batch.
- [ ] Prepare a testfield standalone-harness batch.
- [ ] Prepare a template test-ownership and tailoring batch.
- [ ] Prepare a cross-repository CI/quota batch.
- [ ] Prepare a documentation and v2 metadata batch.
- [ ] Report exact titles and bullet descriptions in the user's commit style,
  but do not create the commits.

### Exit condition

- [ ] Documentation names only interfaces and paths that exist in the integrated
  implementation.
- [ ] Both source archives report `2.0.0`, contain synchronized ROS metadata,
  and configure without Git.
- [ ] No temporary v2 tag or final `v2.0.0` tag remains locally unless the user
  explicitly authorized it; both signed `v1.11.1` baseline tags remain intact.
- [ ] The proposed commit split is dependency ordered and independently
  reviewable.

---

## Stage 5 - Integrated validation

### Main template gates

- [ ] Run a clean native build and full starter CTest suite, including
  dependency-free `CLogger` behavior and the optional spdlog adapter when
  enabled.
- [ ] Configure and run standalone harness profiles `cpu`, `docs`, and `ros2`
  against the main template candidate.
- [ ] Run clean ROS overlay build/test plus installed-header and metadata checks.
- [ ] Run CUDA and OptiX profiles on the available toolchain, including real
  CUDA source ownership, PTX generation, install/export, and negative preflight
  cases.
- [ ] Run default and remove-ROS tailoring, followed by native build/test and
  generated-workflow validation in each materialized tree.

### Testfield gates

- [ ] Run a clean native testfield build and all local tests with external
  conformance disabled.
- [ ] Run all applicable standalone harness profiles against the candidate.
- [ ] Run clean testfield ROS build/test and docs generation.
- [ ] Verify the testfield's adapted ROS conversion call and pinned `lib/wrap`
  remain intentionally unchanged unless an approved stage explicitly owns a
  change.

### Repository-wide gates

- [ ] Run `bash -n` and shellcheck on all changed shell scripts in both
  repositories.
- [ ] Parse every workflow as YAML and every ROS manifest as XML.
- [ ] Run Python compilation, pytest, type checks where configured, metadata sync
  idempotence, and generated-bytecode scans.
- [ ] Verify Git-version isolation below an unrelated tagged parent repository
  and verify automatic dependency acquisition leaves both source trees clean.
- [ ] Run conflict-marker, whitespace, executable-mode, machine-local-path,
  stale-reference, source-side-effect, and ignored-artifact checks.
- [ ] Append exact commands, totals, skips, and artifact evidence to
  `TEMPLATE_V2_STAGE_OUTPUTS.md`.

### Exit condition

- [ ] Every applicable integrated gate is green from a clean build directory.
- [ ] Every conditional skip has an explicit unavailable prerequisite and is
  unrelated to a changed required contract.
- [ ] Both worktrees have no unexplained modification or generated tracked file.
- [ ] The complete diff is ready for the mandatory final review; the goal is not
  yet complete.

---

## Stage 6 - Mandatory final review and verification

This stage must run last, after all implementation, documentation, metadata,
and integrated validation changes are present. It cannot be waived or replaced
by earlier green tests.

### Independent review pass

- [ ] Re-read this plan, both repository diffs, the stage-output log, and every
  changed workflow and public CMake/shell interface from the final state.
- [ ] Compare both integrated diffs against their signed `v1.11.1` baseline
  commits and confirm the baseline tags themselves were not moved.
- [ ] Reconstruct the before/after test-ownership inventory and prove that every
  removed template test has either moved to the harness or was an intentionally
  consolidated duplicate.
- [ ] Review path ownership, Git/version boundaries, source-release behavior,
  dependency acquisition, wrapper provisioning, CUDA/OptiX prerequisites,
  ROS isolation, and tailoring preservation for latent regressions.
- [ ] Review CI expressions for push, pull request, schedule, manual build-only,
  hosted CPU, self-hosted CPU, disabled CUDA, enabled CUDA, ordinary docs, and
  manual Pages deployment events. For schedule, verify intentional absence from
  every active and generic workflow.
- [ ] Review the design against the core requirement: template conformance lives
  in testfield, starter tests live in the template, and tailored projects remain
  standalone.
- [ ] Search both repositories for stale verifier paths, duplicate test owners,
  hidden adjacency assumptions, local absolute paths, artifact uploads, tracked
  caches, conflict markers, implementation-text capability probes, and
  unintended terminology.

### Mandatory final verification

- [ ] Re-run the highest-risk clean gates independently of Stage 5: template CPU
  plus harness CPU, source release in a parent Git repository, scratch tailoring
  plus retained tests, testfield local tests, workflow YAML/semantic checks, and
  ROS static/build verification.
- [ ] Re-run CUDA/OptiX validation when its prerequisites are available; otherwise
  verify the final conditional registration and record the external requirement.
- [ ] Confirm `git diff --check`, final status, submodule SHAs, file modes, and
  the proposed staging split in both repositories.

### Finding loop

- [ ] Classify every finding as blocking, worthwhile, or deferred with explicit
  rationale.
- [ ] For every blocking or worthwhile finding, reopen its owning stage, add a
  regression first, implement the fix, rerun that stage's exit gate and Stage 5,
  then restart Stage 6 from the beginning.
- [ ] Deferred findings must be genuinely outside the v2 goal, carry no known
  correctness or release risk, and be written to the stage-output log.

### Final exit condition

- [ ] No unresolved blocking or worthwhile finding remains.
- [ ] The repeated mandatory gates are green and their fresh evidence is logged.
- [ ] Every checkbox required by the successful goal exit is complete.
- [ ] A concise final report identifies behavior changes, validation evidence,
  residual conditional risks, and the proposed commit split.
- [ ] Stop in the reviewed, staged, pre-commit and pre-tag state and ask the user
  for the next explicit operation.
