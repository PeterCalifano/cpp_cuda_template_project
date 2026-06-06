# Agent Tailoring Prompt

Use this prompt when an agent is asked to turn this template into a fresh C++ library. Work as an interactive configuration session: gather the project choices first, summarize the proposed edits, then make the changes after the user confirms or explicitly asks you to proceed.

## Questions To Ask

Ask only for values that cannot be inferred from the user request or repository context.

1. Project identity:
   - Project/package name in snake_case.
   - Public display name for README, docs, and workflow titles.
   - C++ namespace for library and wrapper-facing APIs.
2. Source layout:
   - Main C++ module directory replacing `src/template_src/`.
   - Whether CUDA is needed. If yes, CUDA module directory replacing `src/template_src_kernels/`; if no, remove the CUDA skeleton and matching `src/CMakeLists.txt` entry.
   - Whether OptiX, oneTBB, OpenGL, examples, and standalone programs should stay enabled as project options.
3. Wrappers and Python:
   - Whether to keep Python wrappers, MATLAB wrappers, both, or neither.
   - Python package name and minimum Python version if different from the template default.
   - gtwrap root or submodule/update policy if wrappers are enabled.
4. Development infrastructure:
   - Keep or remove profiling helpers. Default is remove; keep only when Valgrind/perf helper scripts are wanted.
   - Keep GitHub Pages workflow and issue forms. Default is keep and rename.
   - Initial versioning policy: git tags only, or include an ignored source `VERSION` fallback for source archives.
5. Validation:
   - Required local build matrix: shared/static, CUDA on/off, wrappers on/off, cross-compile smoke, docs build, package install.
   - Whether CI must be updated immediately or only after local validation passes.

## Execution Order

1. Run `./tailor_template_cleanup.sh --list` and show the removal list.
2. Apply cleanup before broad renaming:

   ```bash
   ./tailor_template_cleanup.sh --apply --yes
   ```

   Use `--keep-profiling` only when requested.
3. Rename tracked source files only. Exclude build trees, install trees, virtual environments, generated Python build metadata, and generated Doxygen output.
4. Update these anchor points:
   - `CMakeLists.txt`: `project_name`, wrapper namespace default, root options that mention the old project.
   - `src/CMakeLists.txt`: module `add_subdirectory()` entries and messages.
   - `src/cmake/*Config.cmake.in`: package file name and package references.
   - `src/bin/`, `examples/`, and `tests/`: include paths, starter class names, and executable/test names.
   - `python/pyproject.toml.in` and `python/<package>/`: package metadata and import package.
   - `.github/workflows/*.yml`: workflow names, artifact names, Pages text checks, and renamed CMake option prefixes.
   - `README.md`, `doc/main_page.md`, and public docs pages.
5. Remove skeletons that are not part of the requested project. When removing a directory, remove the matching CMake registration in the same change.
6. Search for stale template identifiers:

   ```bash
   rg "template_project|template_src|template_src_kernels|cpp_playground"
   ```

   Keep only intentional references in examples or documentation.
7. Validate from a clean build directory:

   ```bash
   cmake -S . -B build -DENABLE_TESTS=ON
   cmake --build build --parallel 4
   ctest --test-dir build --output-on-failure
   ```

8. If docs are kept, also validate:

   ```bash
   cmake --preset docs
   cmake --build --preset docs
   ```

## Stop Conditions

Stop and report instead of continuing when:

- CMake configure fails for a missing dependency or unclear feature decision.
- Cleanup cannot patch `tests/CMakeLists.txt` because the expected marker is missing.
- Broad rename would touch generated artifacts, vendored dependencies, or unrelated user changes.
- Wrapper generation fails in a way that depends on an external gtwrap checkout or MATLAB/Python environment not available locally.
- Pages publication cannot be checked because repository Pages settings or authentication are missing.

The report should include the command that failed, the relevant error excerpt, files already changed, and the next concrete action.
