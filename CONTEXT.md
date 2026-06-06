## Current Context

- Main repo: `/home/peterc/devDir/dev-tools/cpp_cuda_template_project`
- Test harness repo: `/home/peterc/devDir/dev-tools/cpp_cuda_template_testfield`
- Date: 2026-05-22

### 2026-05-30 documentation workflow, Pages, and tailoring cleanup

- Implemented a generalized top-level-only Doxygen workflow in the template:
  - new `cmake/HandleDoxygenDocs.cmake`;
  - `doc/CMakeLists.txt` now configures docs through a reusable helper;
  - root `CMakeLists.txt` adds docs only for `BUILD_AS_MAIN_PROJECT`;
  - generated wrapper docstrings use build-tree XML and depend on the docs target when `BUILD_DOC_XML=ON`.
- Source `VERSION` generation is now guarded by `WRITE_SOURCE_VERSION_FILE=OFF` by default; builds still generate/install the build-tree `VERSION`.
- `VERSION` was verified already ignored in both template and testfield with `.gitignore:5` and `git check-ignore -v VERSION`.
- Added docs preset/workflow support:
  - `CMakePresets.json` with `docs` configure/build presets;
  - `.github/workflows/docs_pages.yml` for GitHub Pages custom workflow publication;
  - Doxygen input includes README, `src`, and `doc`, while nested `lib` content is excluded.
- Replaced markdown issue templates with GitHub issue forms in `.github/ISSUE_TEMPLATE`.
- Added usage docs covering template usage, C++/CUDA setup, wrappers, versioning, documentation/Pages, tests, and CI.
- Added rollout notes in both repos under `doc/developments/docs_workflow_rollout.md`.
- Added `tailor_template_cleanup.sh` in the template. `--list` reports the template-development-only files/directories, and `--apply --yes` removes them and patches starter CMake test registration.
- Template validation passed:
  - `cmake --preset docs`;
  - `cmake --build --preset docs`;
  - `ctest --test-dir /tmp/cpp_cuda_template_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 6/6 passed;
  - direct static/docs/version/nested/tailoring CMake script checks passed;
  - generated `build_docs/doc/html/index.html` contains the expected documentation pages.
- Testfield mirrors the workflow/docs/test updates and validates the sibling template too:
  - `cmake --preset docs`;
  - `cmake --build --preset docs`;
  - `ctest --test-dir /tmp/cpp_cuda_template_testfield_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 10/10 passed;
  - generated `build_docs/doc/html/index.html` contains the expected documentation pages.
- `git diff --check` passes in both repos after whitespace cleanup.
- Real GitHub Pages publication was not executed:
  - `command -v gh` exits 1, so GitHub CLI is not available;
  - the new workflow/docs are still uncommitted local changes;
  - publishing would require an explicit commit/push step or an authenticated GitHub publication path.
- Pre-existing testfield `lib/wrap` submodule modification remains untouched.

### 2026-05-30 continuation: post-deploy Pages verification

- Strengthened `.github/workflows/docs_pages.yml` in both repos:
  - after `actions/deploy-pages@v4`, the deploy job now fetches `${{ steps.deployment.outputs.page_url }}`;
  - it checks the served index for `Template usage`, `Documentation workflow`, and `Versioning`;
  - this closes the workflow-side gap where artifact upload could pass without checking the published site.
- Updated static CMake workflow checks in both repos so this post-deploy Pages URL check is required.
- Updated docs in both repos to describe the post-deploy URL verification.
- Re-ran focused validation:
  - template direct checks: `VerifyTemplateProjectDocsStatic.cmake` and `VerifyTemplateProjectDocsWorkflow.cmake` passed;
  - testfield direct checks: `VerifyTestfieldDocsStatic.cmake` and `VerifyTestfieldDocsWorkflow.cmake` passed;
  - `cmake --preset docs` and `cmake --build --preset docs` passed in both repos;
  - `ctest --test-dir /tmp/cpp_cuda_template_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 6/6 passed;
  - `ctest --test-dir /tmp/cpp_cuda_template_testfield_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 10/10 passed;
  - `git diff --check` passed in both repos.
- Action tag recency/existence was checked with `git ls-remote`; current workflow tags exist:
  - `actions/checkout@v6`;
  - `actions/configure-pages@v5`;
  - `actions/upload-pages-artifact@v4`;
  - `actions/deploy-pages@v4`.
- Remaining gate: a real remote Pages deployment still requires commit/push or another authenticated GitHub publication path. No commits were made.
- Expected public Pages URLs were checked for context and both returned HTTP 404:
  - `https://petercalifano.github.io/cpp_cuda_template_project/`;
  - `https://petercalifano.github.io/cpp_cuda_template_testfield/`.

### 2026-05-30 continuation: blocker recheck

- Re-read `AGENTS.md` and `CONTEXT.md` before continuing.
- Re-ran the current focused gates after the previous rollout-doc updates:
  - `ctest --test-dir /tmp/cpp_cuda_template_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 6/6 passed.
  - `ctest --test-dir /tmp/cpp_cuda_template_testfield_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 10/10 passed.
  - `git diff --check` passed in both repos.
- Rechecked publication capability:
  - `command -v gh` exits 1.
  - `https://petercalifano.github.io/cpp_cuda_template_project/` returns HTTP 404.
  - `https://petercalifano.github.io/cpp_cuda_template_testfield/` returns HTTP 404.
- This is the same remaining gate: remote Pages publication cannot be proven without committing/pushing the local workflow/docs or using another authenticated GitHub publication path. No commits were made.

### 2026-05-30 continuation: manual docs stage behavior

- User observed that docs build works but deploy is skipped.
- Updated `.github/workflows/docs_pages.yml` in both template and testfield:
  - `workflow_dispatch` now has a boolean `deploy_pages` input with default `false`.
  - Manual runs are build-only by default; deploy runs only when `deploy_pages=true`.
  - Push events still deploy automatically.
  - Pull requests still build and upload the artifact but never deploy.
  - `actions/configure-pages@v5` moved from `build-docs` to `deploy`, so build-only/manual/pre-merge checks no longer fail when Pages has not been enabled.
- Updated docs and static CMake workflow checks to enforce the new manual-deploy contract.
- Validation after this change:
  - `VerifyTemplateProjectDocsStatic.cmake`: passed.
  - `VerifyTestfieldDocsStatic.cmake`: passed.
  - `VerifyTemplateProjectDocsWorkflow.cmake`: passed.
  - `VerifyTestfieldDocsWorkflow.cmake`: passed.
  - `ctest --test-dir /tmp/cpp_cuda_template_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 6/6 passed.
  - `ctest --test-dir /tmp/cpp_cuda_template_testfield_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 10/10 passed.
  - `git diff --check`: passed in both repos.

### 2026-05-30 continuation: profiling cleanup option

- Updated `tailor_template_cleanup.sh` so `profiling/` is removed by default.
- Added `--keep-profiling` to preserve `profiling/` when a downstream project wants the Valgrind/perf helper scripts.
- Updated `--list`, README, and `doc/template_usage.md` to describe the default removal and opt-in keep behavior.
- Extended `VerifyTemplateProjectTailoringScript.cmake`:
  - default cleanup must remove `profiling/`;
  - cleanup with `--keep-profiling` must preserve `profiling/run_ops_profiling.sh`;
  - existing CMake hook/test-registration cleanup assertions still run for both fake projects.
- Validation:
  - `bash -n tailor_template_cleanup.sh`: passed.
  - `tailor_template_cleanup.sh --list`: shows `profiling` removed by default.
  - `tailor_template_cleanup.sh --list --keep-profiling`: shows `profiling` kept.
  - `VerifyTemplateProjectTailoringScript.cmake`: passed.
  - `VerifyTemplateProjectDocsStatic.cmake`: passed.
  - `VerifyTemplateProjectDocsWorkflow.cmake`: passed.
  - `ctest --test-dir /tmp/cpp_cuda_template_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 6/6 passed.
  - `git diff --check`: passed.

### 2026-05-30 continuation: Node 24 Pages action versions

- User reported GitHub Actions warning that `actions/upload-artifact@v4.6.2` runs on deprecated Node.js 20.
- Determined the warning is owned by our workflow indirectly:
  - `.github/workflows/docs_pages.yml` used `actions/upload-pages-artifact@v4`.
  - `actions/upload-pages-artifact@v4` internally uses `actions/upload-artifact@v4.6.2`.
  - `actions/upload-pages-artifact@v5` internally uses `actions/upload-artifact@v7.0.0`.
- Updated template and testfield docs workflows:
  - `actions/upload-pages-artifact@v5`;
  - `actions/configure-pages@v6`;
  - `actions/deploy-pages@v5`.
- Updated static workflow checks in both repos to require these newer major versions and reject older Pages action majors.
- Validation:
  - `VerifyTemplateProjectDocsStatic.cmake`: passed.
  - `VerifyTestfieldDocsStatic.cmake`: passed.
  - `ctest --test-dir /tmp/cpp_cuda_template_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 6/6 passed.
  - `ctest --test-dir /tmp/cpp_cuda_template_testfield_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 10/10 passed.
  - `git diff --check`: passed in both repos.

### 2026-05-30 continuation: docs CTest CI dependencies and default-branch Pages deploy

- User reported CI CTest failure: `gmake: *** No rule to make target 'doc'. Stop.` from `template_project_docs_build_output`.
- Verified a fresh local CMake configure/build with Doxygen present exposes the `doc` target and passes `template_project_docs_build_output`; stale/incomplete build trees can reproduce the missing-target symptom.
- Found a real CI dependency gap:
  - `build_linux.yml` installed CMake/Ninja/Eigen/TBB/Python but not `doxygen` or `graphviz`;
  - docs CTest configures a fresh build and builds the `doc` target;
  - self-hosted/CUDA workflows also need explicit `doxygen` and `dot` prerequisite checks.
- Updated `build_linux.yml`:
  - GitHub-hosted build and test dependency installs now include `doxygen graphviz`;
  - self-hosted build/test prerequisite checks now include `command -v doxygen` and `command -v dot`.
- Updated `build_linux_cuda.yml`:
  - CUDA build/test prerequisite checks now include `command -v doxygen` and `command -v dot`.
- Updated `VerifyTemplateProjectCiWorkflowFlags.cmake` to require Doxygen/Graphviz validation and Linux hosted package installation.
- User also flagged that Pages deploy would publish every docs-affecting push to `develop`.
- Updated docs Pages deploy condition in template and testfield:
  - push deploys only when `github.ref` equals the repository default branch;
  - manual deploy remains available through `workflow_dispatch` with `deploy_pages=true`.
- Updated template/testfield docs static checks to require the default-branch deploy guard.
- Validation:
  - `VerifyTemplateProjectDocsStatic.cmake`: passed.
  - `VerifyTemplateProjectCiWorkflowFlags.cmake`: passed.
  - `VerifyTestfieldDocsStatic.cmake`: passed.
  - Fresh full CI-like run in `/tmp/cpp_cuda_template_ci_fresh_docs`: configure, build, and `ctest --no-tests=error` passed 12/12.
  - `git diff --check`: passed in both repos.
- Interpreting GitHub run results:
  - deploy skipped on PRs is expected;
  - deploy skipped on manual run with `deploy_pages=false` is expected;
  - deploy skipped on push or manual `deploy_pages=true` is not expected and should be checked from the job condition/logs.

### 2026-05-30 continuation: README path filters and tailoring proof

- Addressed review note that Doxygen uses `README.md` but docs workflow path filters did not include it.
- Added `README.md` to both `push.paths` and `pull_request.paths` in `.github/workflows/docs_pages.yml` for template and testfield.
- Strengthened static workflow checks in both repos:
  - they now count `README.md` path-filter entries and require exactly two, one for push and one for pull request.
- Reverified tailoring script availability and behavior:
  - `git ls-files --stage tailor_template_cleanup.sh` shows mode `100755`;
  - `git ls-tree -r HEAD --name-only | rg '^tailor_template_cleanup\.sh$'` finds the script in the current commit;
  - `VerifyTemplateProjectTailoringScript.cmake` passed directly.
- Validation after this change:
  - `VerifyTemplateProjectDocsStatic.cmake`: passed.
  - `VerifyTestfieldDocsStatic.cmake`: passed.
  - `VerifyTemplateProjectDocsWorkflow.cmake`: passed.
  - `VerifyTestfieldDocsWorkflow.cmake`: passed.
  - `ctest --test-dir /tmp/cpp_cuda_template_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 6/6 passed.
  - `ctest --test-dir /tmp/cpp_cuda_template_testfield_docs_gate --output-on-failure -R "docs|version|nested|tailoring"`: 10/10 passed.
  - `git diff --check`: passed in both repos.

### 2026-05-30 completion audit: docs workflow and versioned CI checkout

- Reverted the temporary `DOXYGEN_PROJECT_NUMBER` clarification experiment; Doxygen again receives the resolved project version through `PROJECT_NUMBER = @FULL_VERSION@`.
- Fixed CI version resolution by requiring full-history checkouts:
  - all `actions/checkout` steps in template `build_linux.yml`, `build_linux_cuda.yml`, `docs_pages.yml`, and their `.templ0`/`.templ1` variants now use `fetch-depth: 0`;
  - the same checkout setting was mirrored into testfield workflows and workflow templates.
- Added static guards so shallow checkouts cannot silently return:
  - `VerifyTemplateProjectCiWorkflowFlags.cmake` and `VerifyTestfieldCiWorkflowFlags.cmake` require `fetch-depth: 0` for every checkout step in build/test workflow files and templates;
  - `VerifyTemplateProjectDocsStatic.cmake` and `VerifyTestfieldDocsStatic.cmake` require `fetch-depth: 0` in the Pages workflow checkout.
- Local CMake configure evidence shows version resolution now sees tags:
  - template audit configure printed `Version from git describe: 1.8.0+19.g9a5b396`;
  - testfield audit configure printed `Version from git tag: 0.3.0+222b60a`.
- Completion audit validation:
  - template direct checks passed: docs static, docs build/content, nested docs isolation, CI workflow flags;
  - testfield direct checks passed: docs static, docs build/content, nested docs isolation, CI workflow flags;
  - template focused CTest gate passed 7/7 for docs, version, nested, tailoring, CI, and cross nested consumer checks;
  - testfield focused CTest gate passed 6/6 for docs, version, nested, CI, and cross nested consumer checks;
  - template full audit build and `ctest --no-tests=error` passed 16/16 in `/tmp/cpp_cuda_template_finish_audit`;
  - testfield full audit build and `ctest --no-tests=error` passed 12/12 in `/tmp/cpp_cuda_template_testfield_finish_audit`;
  - `git diff --check` passed in both repos;
  - public Pages smoke check passed for `https://petercalifano.github.io/cpp_cuda_template_project/`, including `Template usage`, `Documentation workflow`, and `Versioning`.
- Current state notes:
  - template implementation/workflow files are clean at commit `9a5b396 Specify fetch depth in CI configs`; this `CONTEXT.md` update is local bookkeeping for compaction safety;
  - testfield remains locally dirty with the staged documentation/testfield rollout changes and the pre-existing `lib/wrap` modification, which was not touched.

### 2026-05-30 continuation: template usage guide clarification

- Reviewed `doc/template_usage.md` as an agent-facing fresh-library tailoring guide.
- Added an explicit "Fresh Library Tailoring Sequence":
  - choose names first;
  - run `tailor_template_cleanup.sh --list` and `--apply --yes` before broad placeholder replacement;
  - use `--keep-profiling` only when the downstream project should keep Valgrind/perf helpers;
  - rename only tracked source files and exclude generated artifacts;
  - delete or exclude `tailor_template_cleanup.sh` after cleanup because it is a one-shot helper;
  - remove optional skeletons such as CUDA modules together with their `src/CMakeLists.txt` entries;
  - configure/build/test and search for remaining template identifiers.
- Fixed the nested consumer example to link against `nested_my_project::my_project` after renaming rather than `nested_my_project::template_project`.
- Updated README tailoring notes to match the cleanup-before-rename sequence.
- Validation:
  - `VerifyTemplateProjectDocsStatic.cmake`: passed.
  - `VerifyTemplateProjectDocsWorkflow.cmake`: passed.
  - `git diff --check`: passed.

### 2026-05-30 continuation: removed bootstrap prompt artifact

- Deleted `doc/bootstrap_prompts.md` from the template.
- Removed `doc/bootstrap_prompts.md` from the tailoring cleanup script and its regression fixture, because the prompt artifact is no longer shipped in the template.
- Updated `doc/template_usage.md` so the cleanup script description no longer mentions prompt docs.

### 2026-05-30 continuation: restored bootstrap prompt as agent tailoring instructions

- Reintroduced `doc/bootstrap_prompts.md` as a reusable agent-facing interactive tailoring prompt, replacing the old ad hoc bootstrap note.
- The prompt tells agents to ask for project identity, source layout, optional CUDA/OptiX/TBB/OpenGL, wrappers, Python package policy, profiling, GitHub Pages/forms, versioning, and validation requirements before editing.
- Added execution order and stop conditions for fresh-library tailoring.
- Linked the prompt from `README.md`, `doc/main_page.md`, and `doc/template_usage.md`.
- Extended docs static/workflow checks so the prompt remains present and rendered in generated Doxygen output.

### 2026-05-30 continuation: public documentation cleanup

- Reviewed public documentation for historical/log-style wording.
- Rewrote `doc/build_script_doc.md` from a change-log style page into a stable `build_lib.sh` reference.
- Removed public references to rollout logs from docs workflow and CI docs.
- Kept `doc/developments/` in the repository as internal notes but excluded it from generated Doxygen output through `doc/CMakeLists.txt`.
- Added static/generated-doc checks so `doc/developments/` remains excluded and historical rollout pages do not appear in public HTML.

### 2026-05-22 cross-compilation and nested-library work

- Active branch in both repos: `feature/improve-cross-compiling`.
- Main repo now disables `CPU_ENABLE_NATIVE_TUNING` automatically under `CMAKE_CROSSCOMPILING`.
- `CPU_SIMD_LEVEL=native` now fails configure when cross-compiling with explicit SIMD enabled.
- Toolchain metadata is applied to the project compile interface target, so downstream compiles receive `CROSS_COMPILED`, architecture, and target-OS defines.
- Root-only program/example toggles are namespace-derived:
  - default names: `template_project_BUILD_PROGRAMS`, `template_project_BUILD_EXAMPLES`;
  - nested override examples: `nested_template_BUILD_PROGRAMS`, `nested_testfield_BUILD_PROGRAMS`.
- Nested consumers can override the concrete library target name with `LIB_TARGET_NAME_OVERRIDE`, while the exported/imported target remains `<namespace>::template_project`.
- `NO_OPTIMIZATION=ON` now overrides config-specific CMake flags so it produces profiler-friendly `-O0 -g3`, keeps assertions enabled, preserves frame pointers, disables inlining/sibling-call optimization, and omits `-O2`, `-O3`, and host-native CPU flags.
- `Release` and `RelWithDebInfo` now explicitly include `-DNDEBUG` and are guarded against profiler/debug-only flags such as `-O0`, `-Og`, `-g3`, frame-pointer forcing, no-inline flags, and sanitizer flags.
- Compiler flag policy now lives in `cmake/HandleCompilerFlags.cmake` instead of the root `CMakeLists.txt`.
- The build-type branch around `${LIB_COMPILE_TARGET}` was cleaned up: only no-optimization, debug sanitizer/frame-pointer handling, and invalid-build-type validation remain active.
- Main repo added `tests/cmake/VerifyTemplateProjectCrossCompile.cmake` and CTest coverage for:
  - configure flags for aarch64;
  - install + consume through `find_package(template_project)`;
  - nested `add_subdirectory` consume with namespace/target-name override.
- Main repo added `tests/cmake/VerifyTemplateProjectNoOptimization.cmake` to guard `NO_OPTIMIZATION=ON`.
- Main repo added `tests/cmake/VerifyTemplateProjectOptimizedFlags.cmake` to guard Release/RelWithDebInfo flags.
- Testfield repo mirrors the cross/nesting changes and added `tests/cmake/VerifyTestfieldCrossCompile.cmake`.
- Testfield repo added `tests/cmake/VerifyTestfieldNoOptimization.cmake` to guard its `NO_OPTIMIZATION=ON` path.
- Testfield repo added `tests/cmake/VerifyTestfieldOptimizedFlags.cmake` to guard Release/RelWithDebInfo flags.
- Validation completed:
  - main repo `ctest --test-dir /tmp/cpp_cuda_template_stage_check --output-on-failure -R "template_project_(optimized_config_flags|no_optimization_flags|aarch64_cross)"`: 5/5 passed;
  - testfield `ctest --test-dir /tmp/cpp_cuda_template_testfield_stage --output-on-failure -R "testfield_(optimized_config_flags|no_optimization_flags|aarch64_cross)|template_project_builds_(shared|static)_and_is_consumable"`: 7/7 passed;
  - main repo `build_lib.sh` aarch64 smoke built `/tmp/cpp_cuda_template_buildlib_aarch64/src/libtemplate_project.so`;
  - testfield `build_lib.sh` aarch64 smoke built `/tmp/cpp_cuda_template_testfield_aarch64_buildlib/src/libtemplate_project.so`;
  - main repo `build_lib.sh --no-optim` smoke built `/tmp/cpp_cuda_template_buildlib_noopt/src/libtemplate_project.so`;
  - testfield `build_lib.sh --no-optim` smoke built `/tmp/cpp_cuda_template_testfield_buildlib_noopt/src/libtemplate_project.so`;
  - both produced shared libraries are `ELF 64-bit ... ARM aarch64`;
  - both compile command databases have no `-march=native` or `-mtune=native`;
  - both no-optimization compile command databases contain `-O0`, `-g3`, `-fno-omit-frame-pointer`, `-fno-inline`, and `-fno-optimize-sibling-calls`, with no `-O2`, `-O3`, `-march=native`, `-mtune=native`, or `-DNDEBUG`;
  - optimized config compile command databases contain `-O3 -DNDEBUG` for Release and `-O2 -g -DNDEBUG` for RelWithDebInfo, with no no-optimization/profiler/sanitizer flags;
  - stale `BUILD_TEMPLATE_PROGRAMS` / `BUILD_TEMPLATE_EXAMPLES` names were removed from both repos.

### Unified Python package/wrapper work

- The top-level Python package now owns the public import contract.
- `python/template_project/__init__.py` imports the compiled wrapper from the same package when available and exposes `HAS_WRAPPER` plus `WRAPPER_IMPORT_ERROR`.
- `python/setup.py.in` is only a binary-wheel helper; package naming and versioning stay in `pyproject.toml.in`.
- `cmake/HandleWrapper.cmake` assembles a single installable Python package, generates a fallback `__init__.py` when needed, and tightens the wrapper import test so it checks `HAS_WRAPPER` and a wrapped symbol.
- Main repo Python version policy is aligned to 3.12 in both `CMakeLists.txt` and `python/pyproject.toml.in`.

### Main repo verification already completed

- Configured and built a Python-wrapper build in `build_py312`.
- `ctest -R template_project_python_import` passed there.
- Offline pip install from the generated Python package succeeded in Python 3.12 with `HAS_WRAPPER=True`.
- Offline pip install with Python 3.11 failed at install time because `requires-python >=3.12`.

### Testfield repo updates

- Synced package/wrapper integration changes into testfield:
  - `cmake/HandleWrapper.cmake`
  - `python/template_project/__init__.py`
  - `python/setup.py.in`
  - docs
- Updated testfield Python policy:
  - `CMakeLists.txt`: `PROJECT_PYTHON_VERSION 3.12`
  - `python/pyproject.toml.in`: `requires-python = ">=3.12"`
- Added package-install regression tests in `tests/CMakeLists.txt`:
  - `template_project_python_package_installs_and_imports`
  - `template_project_python_package_rejects_python311`
- Added `tests/cmake/VerifyTemplateProjectPythonPackage.cmake` to:
  - configure/build the sibling template repo with Python wrapping enabled,
  - run the template repo build-tree wrapper import CTest,
  - create a venv,
  - pip install from the generated package,
  - assert success and wrapper availability on Python 3.12,
  - assert install-time rejection on Python 3.11.

### Latest testfield verification

- Built testfield harness in `/tmp/cpp_cuda_template_testfield_harness`.
- Ran:
  - `template_project_python_package_installs_and_imports`
  - `template_project_python_package_rejects_python311`
- Both passed on 2026-03-18.

### Remaining known risk

- Testfield still calls `write_source_VERSION_file()` in its root `CMakeLists.txt`, which mutates tracked source state during configure. This is the main remaining issue for using testfield as a robust CI/sandbox harness.

### 2026-05-22 CI illegal-instruction blocker

- GitHub Actions Linux and CUDA workflows were forcing `-DCPU_ENABLE_NATIVE_TUNING=ON`.
- Those workflows upload the build tree from a build job and execute downloaded test binaries in a separate test job, so host-native CPU tuning can produce non-portable binaries and fail as `Illegal`/`SIGILL` on a different runner CPU.
- Both `.github/workflows/build_linux.yml` and `.github/workflows/build_linux_cuda.yml` now force `-DCPU_ENABLE_NATIVE_TUNING=OFF`.
- Added CTest guard `template_project_ci_workflow_cpu_flags` through `tests/cmake/VerifyTemplateProjectCiWorkflowFlags.cmake` so future workflow edits fail if CI re-enables native CPU tuning.
- Mirrored the same workflow policy and guard in testfield as `testfield_ci_workflow_cpu_flags`; the pre-existing testfield `lib/wrap` submodule pointer change was left untouched.
- Validation completed in `/tmp/cpp_cuda_template_ci_blocker`:
  - CI-style configure with `RelWithDebInfo`, tests enabled, CUDA/OptiX/OpenGL off, and `CPU_ENABLE_NATIVE_TUNING=OFF`;
  - `cmake --build /tmp/cpp_cuda_template_ci_blocker --parallel 4`;
  - `ctest --test-dir /tmp/cpp_cuda_template_ci_blocker --output-on-failure --parallel 2 --no-tests=error`: 11/11 passed, including the logging and template Catch2 tests that failed as `Illegal` in CI;
  - generated `build.ninja` has no `-march=native` or `-mtune=native` compile flags; `CMakeCache.txt` keeps `CPU_ENABLE_NATIVE_TUNING:BOOL=OFF`.
- Testfield guard validation used direct CMake script execution to avoid its known source-`VERSION` configure mutation:
  - `cmake -DTEST_SOURCE_DIR=/home/peterc/devDir/dev-tools/cpp_cuda_template_testfield -P tests/cmake/VerifyTestfieldCiWorkflowFlags.cmake`.

## 2026-05-10 MATLAB wrap lifecycle work

- Active implementation spans:
  - `/home/peterc/devDir/dev-tools/wrap`
  - `/home/peterc/devDir/dev-tools/cpp_cuda_template_project`
- The wrap generator now treats `string`/`std::string` and fixed-width integers as scalar MATLAB types, including `const string&`.
- The wrap MATLAB runtime header now has fixed-width integer scalar support, null checks in pointer unwrap helpers, and stdout restoration helpers before MATLAB error throws.
- The generated MATLAB wrapper no longer leaves `std::cout` redirected across `mexErrMsg*` paths, including `_deleteAllObjects`.
- Template profiling policy now separates `ENABLE_GPERFTOOLS` from `ENABLE_TCMALLOC`; default builds do not link tcmalloc, while `-DENABLE_TCMALLOC=ON` preserves opt-in behavior.
- Template MATLAB regression CTests were added under `tests/cmake` and `tests/matlab` for construct/clear, live exit, string value/const-ref, `uint32_t`, bad-input recovery, stdout/error recovery, `clear all`, and the tcmalloc ELF gate.

### Verification completed

- Wrap repo: `pytest -q tests` passed with `97 passed`.
- Wrap root plain `pytest -q` still collects vendored `pybind11/tests` and fails before project tests because `pybind11_tests` is not built; use `pytest -q tests` for the project suite.
- Template default MATLAB wrapper build in `/tmp/cpp_cuda_template_wrap_default` passed `ctest --test-dir /tmp/cpp_cuda_template_wrap_default --output-on-failure` with `14/14` tests.
- Default ELF checks found no `libtcmalloc` or profiler dependency on the MEX or project shared library.
- Opt-in tcmalloc build in `/tmp/cpp_cuda_template_wrap_tcmalloc` linked `libtcmalloc.so.4`, and the `template_project_matlab_wrapper_tcmalloc_present` CTest passed.
- Python wrapper build in `/tmp/cpp_cuda_template_wrap_python` passed `ctest --test-dir /tmp/cpp_cuda_template_wrap_python --output-on-failure` with `6/6` tests, including `template_project_python_import`.

## 2026-05-11 wrap continuation before commit split

- Active local wrap checkout: `/home/peterc/devDir/dev-tools/wrap`.
- Fixed critical review findings:
  - `tests/test_matlab_wrapper.py` now appends the repo root to `sys.path` before importing `gtwrap`, so focused tests collect from repo root.
  - MATLAB expected fixtures were regenerated from current generator output.
  - `CoutRedirect` in `matlab.h` is nested/reentrant safe and `MexErrMsg*` restores all active redirects before MATLAB longjmp.
  - Generated MEX errors now say `Exception from wrapped C++ code`, not `Exception from gtsam`.
  - Runtime RTTI user-facing errors now say `wrap:`, not `gtsam wrap:`.
  - Generated MATLAB comments no longer hard-code `https://gtsam.org/doxygen/`.
  - `wrap/cmake/MatlabWrap.cmake` uses modern `find_package(Python ... COMPONENTS Interpreter)` instead of deprecated `FindPythonInterp` / `FindPythonLibs`.
- Wrap verification after these fixes:
  - `pytest -q tests/test_matlab_wrapper.py -p no:cacheprovider`: 12 passed.
  - `pytest -q tests/test_pybind_wrapper.py -p no:cacheprovider`: 9 passed.
  - `pytest -q tests -p no:cacheprovider`: 97 passed.
- Testfield focused automatic regression verification:
  - Build harness `/tmp/cpp_cuda_template_testfield_harness_Ee8SAn`.
  - `ctest --test-dir /tmp/cpp_cuda_template_testfield_harness_Ee8SAn -R "template_project_python_package_installs_and_imports|template_project_matlab_wrapper_script_runs|testfield_matlab_wrapper_script_runs|testfield_matlab_wrapper_tcmalloc_present" --output-on-failure`: 4/4 passed.
- Spectral raytracer downstream experiment:
  - Repo: `/home/peterc/devDir/rendering-sw/spectral_raytracer_dev`.
  - Build: `/tmp/spectral_raytracer_dev_wrap_fixed`.
  - Command used local fixed wrap with `--gtwrap-root /home/peterc/devDir/dev-tools/wrap --no-wrap-update`.
  - Build succeeded.
  - Generated wrapper uses scalar `unwrap< std::string >` / `unwrap< uint32_t >`, MATLAB proxy uses `isa(...,'uint32')`, and MEX error text is generic.
  - MATLAB smoke without preload failed to load MEX because `/usr/local/lib/libopencv_imgcodecs.so.410` needs OpenEXR 3.1 symbols hidden by MATLAB runtime library ordering.
  - MATLAB smoke with `LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libOpenEXR-3_1.so.30` passed: const-ref strings, by-value string, `uint32_t`, catchable bad call, valid call after catch, clear classes/MEX.
- TorchAutoForge downstream experiment:
  - Repo: `/home/peterc/devDir/ML-repos/torchAutoForge-deploy`.
  - Only deliberate source edit there: `src/wrap_interface.i` now exposes existing `placeholder::placeholder_fcn()`.
  - Python build: `/tmp/torch_autoforge_wrap_python_fixed`, with `autoforge_deploy_GTWRAP_TOP_NAMESPACE=placeholder` and local fixed wrap; build passed.
  - `ctest --test-dir /tmp/torch_autoforge_wrap_python_fixed --output-on-failure`: 7/7 passed.
  - Python smoke used `python3.11` because project currently configures Python 3.11; direct call to wrapped `placeholder_fcn()` passed.
  - MATLAB build: `/tmp/torch_autoforge_wrap_matlab_fixed`, same top namespace override and local fixed wrap; build passed.
  - `ctest --test-dir /tmp/torch_autoforge_wrap_matlab_fixed --output-on-failure`: 6/6 passed.
  - MATLAB smoke `placeholder.placeholder_fcn(); clear classes; clear mex;` passed.
- No commits were made.
