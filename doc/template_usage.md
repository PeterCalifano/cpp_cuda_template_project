# Template Usage Guide

This repository is meant to be renamed into a real C++ library while keeping the build, wrapper, documentation, packaging, and CI machinery reusable.

## Rename Checklist

Use one global replacement pass for the project name, then inspect the changed CMake package files.

| Template item | Replace with |
|---|---|
| `template_project` | Project/package name in snake_case |
| `template_src` | Primary C++ module directory |
| `template_src_kernels` | CUDA kernel module directory, or delete if CUDA is not used |
| `cpp_playground` | Top C++ namespace exposed to wrappers |

Update these files first:

- `CMakeLists.txt`: `set(project_name "...")`
- `src/cmake/template_projectConfig.cmake.in`: rename file and package references
- `python/pyproject.toml.in`: package metadata
- `python/template_project/`: package directory name
- `.github/workflows/*.yml`: workflow names and artifact names when useful
- `README.md` and `doc/main_page.md`: public project name and usage notes

## Adding C++ Code

Put public headers and compiled library sources under `src/<module>/`. The default library target exports `${PROJECT_NAME}::${PROJECT_NAME}` after installation and exposes headers from `include/<project_name>/`.

The expected pattern is:

```text
src/<module>/CMakeLists.txt
src/<module>/CMyClass.h
src/<module>/CMyClass.cpp
tests/<module>_test/testMyClass.cpp
examples/<module>_examples/exampleMyClass.cpp
```

Keep the wrapper-facing facade under `src/wrapped_impl/` when a stable Python/MATLAB API should differ from internal C++ classes.

## Library Consumers

Installed consumers should use the exported package:

```cmake
find_package(my_project REQUIRED)
target_link_libraries(my_target PRIVATE my_project::my_project)
```

Nested consumers should override the internal target namespace if they include multiple template-derived libraries:

```cmake
set(LIB_NAMESPACE_OVERRIDE nested_my_project CACHE STRING "" FORCE)
set(LIB_TARGET_NAME_OVERRIDE nested_my_project_library CACHE STRING "" FORCE)
add_subdirectory(path/to/my_project)
target_link_libraries(parent_target PRIVATE nested_my_project::template_project)
```

Only the main project configures documentation, tests, examples, wrappers, and generic `doc` targets. Nested projects keep their library target available without publishing documentation for the parent build.

## Tests

Use Catch2 for compiled tests and CTest for workflow-level checks. Add narrow CMake-script tests under `tests/cmake/` when the behavior is about configuration, installation, generated files, CI YAML, or documentation output rather than runtime C++ behavior.

Run focused checks during development:

```bash
cmake -S . -B build -DENABLE_TESTS=ON
cmake --build build --parallel 4
ctest --test-dir build --output-on-failure
```

## Tailoring Cleanup Script

After cloning and renaming the template, list template-development-only files:

```bash
./tailor_template_cleanup.sh --list
```

Apply the cleanup once the list is acceptable:

```bash
./tailor_template_cleanup.sh --apply --yes
```

The script removes agent/context notes, template-development prompt/history docs, workflow snapshot files, template-specific validation CTest scripts, and the workspace file tied to this template checkout. It keeps reusable project infrastructure such as `cmake/`, `build_lib.sh`, docs workflow files, issue forms, examples, profiling scripts, toolchains, starter unit tests, `.devcontainer/`, and `.vscode/`.

It also removes the root CMake hook for the template MATLAB regression helper and rewrites `tests/CMakeLists.txt` so only starter project unit tests remain registered.
