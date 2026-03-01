# cpp_cuda_template_project

A CMake template for building GPU-accelerated C++ shared libraries with optional CUDA/OptiX, Python/MATLAB bindings, and profiling support. Designed to be cloned and renamed into a real project.

## Requirements

| Dependency | Version | Notes |
|---|---|---|
| CMake | ≥ 3.15 | |
| C++ compiler | C++20 | GCC 11+, Clang 13+ |
| Eigen3 | ≥ 3.4 | Required |
| CUDA Toolkit | ≥ 12.0 | Optional (`-DENABLE_CUDA=ON`) |
| OptiX SDK | any | Optional (`-DENABLE_OPTIX=ON`), requires CUDA |
| Catch2 | 3.x | Auto-fetched from GitHub if not found |
| Valgrind / perf | any | Optional, for profiling scripts |
| libgoogle-perftools-dev | any | Optional (`-DENABLE_PROFILING=ON`) |

---

## Quick Start

```bash
git clone <repo-url> my_project && cd my_project

# Default build (RelWithDebInfo) + run tests
./build_lib.sh

# Debug build, Ninja generator, 8 jobs
./build_lib.sh -t debug -N -j 8

# Build + install to ./install
./build_lib.sh -t release -i
```

Run tests manually after a build:

```bash
cd build && ctest --output-on-failure
# Run a single test by name
ctest --output-on-failure -R <test_name>
```

---

## Using as a Template

To start a new project from this template, rename the following (all in one pass with your editor's global find-and-replace):

| Placeholder | Replace with |
|---|---|
| `template_project` | your project name (snake_case) |
| `template_src` | your library module name |
| `template_src_kernels` | your CUDA module name (or delete if no CUDA) |

**Files/directories to rename:**

```
src/template_src/            → src/<your_lib>/
src/template_src_kernels/    → src/<your_lib>_kernels/    (if using CUDA)
src/cmake/template_projectConfig.cmake.in  → src/cmake/<your_project>Config.cmake.in
```

**CMakeLists.txt** (root, line 11):
```cmake
set(project_name "your_project_name")
```

**What to keep as-is:** the entire `cmake/` module system, `build_lib.sh`, `configure_devcontainer.sh`, `generate_version.sh`, and the `profiling/` scripts — these are project-agnostic.

---

## Build Options

All options are passed via `build_lib.sh` flags or directly as `-D<VAR>=<VAL>` to CMake.

### `build_lib.sh` reference

```
-B, --buildpath <dir>     Build directory (default: ./build)
-t, --type <type>         debug | release | relwithdebinfo | minsizerel
-j, --jobs <N>            Parallel jobs (default: nproc or 4)
-r, --rebuild-only        Skip CMake configure; rebuild sources only
-N, --ninja-build         Use Ninja generator
-f, --flagsCXX "<flags>"  Extra compiler flags (e.g. "-march=native")
-D, --define <VAR=VAL>    Extra CMake cache definitions (repeatable)
    --clean               Delete build dir before configure
    --profile             Enable profiling build (see Profiling section)
    --skip-tests          Do not run tests after build
-i, --install             Run install target after tests
-p, --python-wrap         Enable Python wrappers
-m, --matlab-wrap         Enable MATLAB wrappers
    --toolchain <file>    CMake toolchain file
-h, --help                Show full help
```

See [`doc/build_script_doc.md`](doc/build_script_doc.md) for a detailed option reference.

### CMake feature flags

| Option | Default | Description |
|---|---|---|
| `ENABLE_CUDA` | OFF | CUDA GPU acceleration |
| `ENABLE_OPTIX` | OFF | NVIDIA OptiX (enables CUDA automatically) |
| `ENABLE_OPENGL` | OFF | OpenGL support |
| `ENABLE_TESTS` | ON | Build and run Catch2 tests |
| `ENABLE_PROFILING` | OFF | Profiling-friendly flags + optional gperftools |
| `SANITIZE_BUILD` | OFF | Enable sanitizers (see `SANITIZERS` variable) |
| `SANITIZERS` | `address,undefined,leak` | Comma-separated sanitizer list |
| `NO_OPTIMIZATION` | OFF | Force `-O0` regardless of build type |
| `WARNINGS_ARE_ERRORS` | OFF | Treat all warnings as errors (`-Werror`) |

### Build type compiler flags

| Build type | Flags | Notes |
|---|---|---|
| `Debug` | `-Og -g` + sanitizers | Max debug info |
| `RelWithDebInfo` | `-O2 -g` + stricter warnings | **Default** |
| `Release` | `-O3` | Tests forced on |
| `MinSizeRel` | `-Os` | |
| `NOPTIM` | `-O0 -g` | Stricter warnings, no optimization |

---

## Optional Features

### CUDA / OptiX

```bash
./build_lib.sh -D ENABLE_CUDA=ON
./build_lib.sh -D ENABLE_CUDA=ON -D ENABLE_OPTIX=ON
```

GPU architecture is auto-detected via `nvidia-smi`. CUDA kernels live in `src/template_src_kernels/`:
- `.cu` files — standard CUDA kernels
- `.ptx.cu` files — compiled to embedded `const char[]` arrays for OptiX modules

### Sanitizers

```bash
./build_lib.sh -t debug -D SANITIZE_BUILD=ON
# Custom sanitizer set:
./build_lib.sh -t debug -D SANITIZE_BUILD=ON -D SANITIZERS="address,undefined"
```

---

## Versioning

Version is resolved in order:

1. **Git tags** — tag format `vMAJOR.MINOR.PATCH` (e.g. `v1.2.0`)
2. **`VERSION` file** — parsed from `Project version: X.Y.Z` if git is unavailable
3. **CMake defaults** — `0.0.0` if neither source is available

The `VERSION` file is always written to the source and build directories during CMake configure. To write it without building:

```bash
./generate_version.sh
```

Version is available in C++ via the generated `config.h`:

```cpp
#include "config.h"
PrintVersion();          // prints to stdout
GetVersionString();      // returns std::string
PROJECT_VERSION_MAJOR    // integer macros
```

---

## Installation and Consuming as a Library

Install to the default prefix (`./install`) or a custom one:

```bash
./build_lib.sh -t release -i
# or with custom prefix:
./build_lib.sh -t release -i -D CMAKE_INSTALL_PREFIX=/opt/my_project
```

In a downstream CMake project:

```cmake
# Option 1: set the path explicitly
set(my_project_DIR "/path/to/install/lib/cmake/my_project")
find_package(my_project REQUIRED)

# Option 2: via CMAKE_PREFIX_PATH
cmake -DCMAKE_PREFIX_PATH=/path/to/install ...
```

Then link:

```cmake
target_link_libraries(my_target PRIVATE my_project::my_project)
```

See [`examples/template_consumer_project/`](examples/template_consumer_project/) for a complete working example.

---

## Profiling

### Profiling-friendly build

`--profile` adds `-fno-omit-frame-pointer -fno-inline-functions` to all build types — required for `perf` and `callgrind` to produce accurate call stacks even in optimized builds. Optionally links `gperftools` if found.

```bash
./build_lib.sh --profile -t relwithdebinfo
```

### Profiling scripts

Three wrapper scripts live in `profiling/`. All share common options:
`-e <executable>`, `-o <output_dir>`, `-a "<args>"`, `-t <trials>`, `-i <start_index>`.

```bash
# Call graph analysis (valgrind callgrind)
./profiling/run_call_profiling.sh -e ./build/my_exe -o prof_results -t 3

# Heap memory profiling (valgrind massif)
./profiling/run_mem_complexity.sh -e ./build/my_exe -o prof_results

# CPU cycles / instruction count (perf)
./profiling/run_ops_profiling.sh  -e ./build/my_exe -o prof_results
```

Scripts auto-detect whether `sudo` is needed (skipped when running as root, e.g. inside a devcontainer).

Output files are written to `<output_dir>/` and are gitignored by default.

---

## DevContainer

The project ships a VS Code DevContainer configuration. To reconfigure it (base image, ROS, CUDA):

```bash
# Interactive
./configure_devcontainer.sh

# Non-interactive
./configure_devcontainer.sh --cuda --base ubuntu-22.04 --ros2 humble
./configure_devcontainer.sh --base ubuntu-22.04 --ros noetic --ros-profile desktop
./configure_devcontainer.sh --non-interactive --base ubuntu-24.04
```

ROS 1 requires Ubuntu 18.04 (melodic) or 20.04 (noetic). ROS 2 requires Ubuntu 22.04+.

---

## Documentation

Doxygen documentation is auto-built when CMake finds `doxygen`:

```bash
cmake -B build && cmake --build build --target doc
```

Output goes to `build/doc/html/index.html`.

---

## Project Structure

```
├── src/
│   ├── template_src/            Core C++ library implementation
│   ├── template_src_kernels/    CUDA kernels (.cu) and PTX sources (.ptx.cu)
│   ├── wrapped_impl/            C wrapper layer for Python/MATLAB bindings
│   ├── config.h.in              CMake-configured header (version, feature flags)
│   └── global_includes.h        Shared utilities (ANSI colors, precision constants)
├── cmake/                       CMake module system (Handle*.cmake)
├── profiling/                   Valgrind/perf wrapper scripts
├── tests/                       Catch2 unit tests and fixtures
├── examples/
│   ├── template_consumer_project/   Using the library via find_package()
│   └── template_examples/           Standalone usage examples
├── doc/                         Doxygen configuration
├── build_lib.sh                 Primary build entry point
├── generate_version.sh          Write VERSION file without building
└── configure_devcontainer.sh    Reconfigure VS Code DevContainer
```
