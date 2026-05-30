# Versioning Guide

Version resolution is shared by CMake, CPack, generated C++ config headers, Python package metadata, and installed package metadata.

## Resolution Order

The template resolves version in this order:

1. `git describe --tags --long --dirty --always`
2. A source `VERSION` file
3. Hardcoded CMake defaults in the root `CMakeLists.txt`

Supported tags are semantic version tags:

```text
v1.2.3
v1.2.3-rc.1
```

Commits after a tag become build metadata, for example `1.2.3+4.gabc1234`. Dirty worktrees add `dirty` metadata.

## VERSION Files

CMake always writes `${PROJECT_BINARY_DIR}/VERSION` during configure and installs it to the package prefix. Source-tree writes are opt-in:

```bash
cmake -S . -B build -D WRITE_SOURCE_VERSION_FILE=ON
```

Use `generate_version.sh` when you explicitly want to refresh the ignored source `VERSION` file without building:

```bash
./generate_version.sh
```

Keeping source writes opt-in prevents CI and testfield configure runs from dirtying the checkout.

## C++ Access

Include the configured header:

```cpp
#include "config.h"

auto version = GetVersionString();
PrintVersion();
```

The header also exposes numeric macros such as `PROJECT_VERSION_MAJOR`.

## Python and Packages

`python/pyproject.toml.in` receives `@PROJECT_VERSION@`, while CPack package filenames use `FULL_VERSION` when available. Keep public release tags, package uploads, and generated docs aligned by building release artifacts from an exact `vMAJOR.MINOR.PATCH` tag.
