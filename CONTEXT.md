## Current Context

- Main repo: `/home/peterc/devDir/dev-tools/cpp_cuda_template_project`
- Test harness repo: `/home/peterc/devDir/dev-tools/cpp_cuda_template_testfield`
- Date: 2026-05-22

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
