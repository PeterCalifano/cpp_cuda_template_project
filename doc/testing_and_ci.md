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

Template-validation workflows are the active `.github/workflows/*.yml` files in
this repository. They verify template-owned contracts such as cleanup,
rollout, static CMake checks, and fixture builds; they are not the workflows
delivered unchanged to a derived project.

Derived-project workflow templates are stored as dormant matching
`.github/workflows/*.yml.tpl` files. `tailor_template_cleanup.sh` materializes
them as the runnable `.yml` files and removes the `.tpl` sources. The
`testWorkflowTemplates.py` contract parses every active/dormant pair, rejects
template-only checks from the dormant definitions, and requires the generic
CPU, CUDA, docs, and ROS gates.

Dormant workflow templates must not rely on parse-only coverage. The active
Linux `tailored-project-dogfood` job applies cleanup in a full-history scratch
clone of the exact CI revision,
parses the materialized workflows, builds/tests the tailored C++ fixture, and
builds its docs. The active ROS workflow separately removes and re-adds the
overlay in scratch, materializes the generic ROS workflow, and exercises the
resulting ROS and standalone builds. The active CUDA workflow runs the common
workflow-template contract, materializes the project in both jobs, and then
builds/tests that tailored source tree on the GPU runner.

The Linux workflows keep CPU tuning portable because build artifacts are tested in a separate job. Do not re-enable `CPU_ENABLE_NATIVE_TUNING=ON` in GitHub Actions unless build and test run on the same pinned CPU family.

Template-validation Linux and ROS jobs install `python3-pytest` and
`python3-yaml`; PyYAML parses the active/dormant workflow pairs. Jobs that run
documentation CTests also install Doxygen and Graphviz. Self-hosted and CUDA
template workflows validate the same requirements with
`python3 -m pytest --version`, `python3 -c 'import yaml'`,
`command -v doxygen`, and `command -v dot` before configuring or running tests.
Cleanup removes the workflow-template
pytest, so generic tailored-project CI does not inherit the PyYAML dependency
unless the project adds its own YAML-backed tests.

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
