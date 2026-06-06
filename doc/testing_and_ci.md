# Testing, CI, and Issue Workflow

## Local Gates

Use CTest for compiled tests, Python tests, and workflow-level regressions.
`ctest --test-dir <build>` is the preferred form because it works from the
repository root, from scripts, and from CI jobs without changing directories:

```bash
cmake -S . -B build -DENABLE_TESTS=ON
cmake --build build --parallel 4
ctest --test-dir build --output-on-failure
```

Compiled tests are discovered from `test*.cpp` and `test*.cu` files and run with
Catch2. Python tests are discovered from `test*.py` files and registered as
normal CTest entries that execute `python -m pytest -q <test-file>`.

The discovery helper is shared by starter projects and downstream projects:

- `test*.cpp` and `test*.cu`: compiled only when Catch2 is available.
- `test*.py`: registered when `ENABLE_TESTS=ON` and `ENABLE_PYTHON_TESTS=ON`.
- `EXCLUDED_LIST`: accepts either full filenames such as `testSlow.py` or stems
  such as `testSlow`.
- Catch2 tests get the default `catch2` label.
- Python tests get the `python` and `pytest` labels.

Useful local filters:

```bash
ctest --test-dir build --output-on-failure -L catch2
ctest --test-dir build --output-on-failure -L python
ctest --test-dir build --output-on-failure -R testPythonSmoke
```

Catch2 output and properties are controlled through CMake cache values:

```bash
cmake -S . -B build \
  -DCATCH2_TEST_REPORTER=compact \
  -DCATCH2_TEST_PROPERTIES="LABELS;catch2"
```

Keep CTest command-line switches such as `--output-on-failure`, `-R`, `-L`, and
`--parallel` on the `ctest` invocation. Do not put them in
`CATCH2_TEST_PROPERTIES`; that variable is only for CTest property name/value
pairs passed to `catch_discover_tests`.

Local development filters can be passed through the build helper:

```bash
./build_lib.sh --ctest-extra-args "-L python"
```

`--ctest-extra-args` is for local development only. It is useful for quickly
reusing an existing build tree through `build_lib.sh`, but CI workflows should
spell out their own `ctest` command and filters directly. The value is split on
whitespace; run `ctest` directly for filters or arguments that need shell
quoting.

Use a conda environment for Python tests without wrapping the full CTest run.
This keeps C++ tests native while Python test files run inside the requested
environment:

```bash
cmake -S . -B build -DENABLE_TESTS=ON -DPYTHON_TEST_CONDA_ENV=my_env
cmake -S . -B build -DENABLE_TESTS=ON -DPYTHON_TEST_CONDA_PREFIX=/path/to/conda/env
ctest --test-dir build --output-on-failure -L python
```

Use `PYTHON_TEST_CONDA_ENV` for a named environment and
`PYTHON_TEST_CONDA_PREFIX` for a specific environment directory. Set only one of
them. If neither is set, Python tests use `PYTHON_TEST_EXECUTABLE` when provided,
then the configured `Python3` interpreter, then `python3`/`python` from `PATH`.
The selected interpreter must have `pytest` installed, and the validation happens
during CMake configure only when at least one `test*.py` file is actually being
registered.

To disable Python tests while keeping Catch2 tests:

```bash
cmake -S . -B build -DENABLE_TESTS=ON -DENABLE_PYTHON_TESTS=OFF
```

Focused documentation checks:

```bash
ctest --test-dir build --output-on-failure -R "docs|pages|issue_templates|version"
```

## CI Workflows

The Linux workflows keep CPU tuning portable because build artifacts are tested in a separate job. Do not re-enable `CPU_ENABLE_NATIVE_TUNING=ON` in GitHub Actions unless build and test run on the same pinned CPU family.

GitHub-hosted Linux jobs install `python3-pytest`, Doxygen, and Graphviz because
the default CTest suite can include pytest-backed `test*.py` files and
documentation CTests. Self-hosted and CUDA workflows validate the same tools with
`python3 -m pytest --version`, `command -v doxygen`, and `command -v dot` before
configuring or running tests.

The Pages workflow is separate from the C++ build workflow. It has these stages:

1. Configure docs with CUDA, OptiX, and tests disabled.
2. Build Doxygen HTML and XML.
3. Verify `index.html` exists before upload.
4. Upload the Pages artifact.
5. Deploy only for default-branch pushes, or manual dispatch when `deploy_pages=true`.
6. Fetch the deployed Pages URL and check that the published index contains the expected documentation links.

## Issue Templates

Issue forms are structured so bug reports capture:

- build mode and compiler
- operating system and runner type
- CUDA/OptiX/wrapper settings
- failing command and output excerpt
- whether the problem affects docs or Pages
- whether the project is top-level or nested through `add_subdirectory`

Feature requests should state the owning surface: C++ library, CUDA/OptiX, wrappers, versioning, docs/Pages, CI, packaging, or testfield validation.

## Stop Rule

For staged workflow changes, stop on the first critical blocker that prevents trustworthy validation. Record:

- stage name
- command
- exit code
- short output excerpt
- likely owner
- next action
