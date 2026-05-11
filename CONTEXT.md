## Current Context

- Main repo: `/home/peterc/devDir/dev-tools/cpp_cuda_template_project`
- Test harness repo: `/home/peterc/devDir/dev-tools/cpp_cuda_template_testfield`
- Date: 2026-03-18

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
