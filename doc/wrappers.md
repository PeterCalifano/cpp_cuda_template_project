# Python and MATLAB Wrapper Guide

Wrappers are generated from gtwrap interface files. The default top-level interface is `src/wrap_interface.i`; implementation classes intended for binding live under `src/wrapped_impl/`.

## Wrapper Options

Wrapper options are namespaced by `LIB_NAMESPACE`, which prevents nested template-derived projects from colliding.

| Option | Purpose |
|---|---|
| `<namespace>_BUILD_PYTHON_WRAPPER` | Build the pybind11 wrapper |
| `<namespace>_BUILD_MATLAB_WRAPPER` | Build the MATLAB MEX wrapper |
| `<namespace>_WRAPPER_INTERFACE_FILES` | Ordered list of `.i` files; first is the top module |
| `<namespace>_GTWRAP_TOP_NAMESPACE` | C++ namespace exposed at the Python/MATLAB module root |
| `<namespace>_GTWRAP_ROOT_DIR` | Local `wrap` checkout override |

`build_lib.sh -p` and `build_lib.sh -m` set the Python and MATLAB wrapper options for the main project.

## gtwrap Resolution

The wrapper resolver checks, in order:

1. An explicit `--gtwrap-root <dir>` or `<namespace>_GTWRAP_ROOT_DIR`.
2. Local `./wrap`, `./lib/wrap`, or adjacent checkout candidates.
3. An installed `gtwrap` CMake package.
4. A declared `wrap` or `lib/wrap` submodule when submodule initialization is enabled.

Disable automatic update with:

```bash
./build_lib.sh -p --no-wrap-update
```

Disable submodule initialization fallback with:

```bash
./build_lib.sh -p --no-wrap-submodule-init
```

## Python Package

The source package under `python/<project>/` is the supported import and install entrypoint. CMake configures `python/pyproject.toml`, `python/setup.py`, and `_wrapper_build.py` when Python wrapping is enabled.

```bash
./build_lib.sh -p
cd python
python -m pip install .
python -c "import template_project; assert template_project.HAS_WRAPPER"
```

The package requires Python 3.12 or newer by default. Adjust `PROJECT_PYTHON_VERSION` in the root `CMakeLists.txt` and `requires-python` in `python/pyproject.toml.in` together.

## MATLAB Wrapper

The MATLAB wrapper needs a MATLAB installation visible to CMake. Use the same local `wrap` checkout as Python when validating both wrapper types.

```bash
./build_lib.sh -m --gtwrap-root /path/to/wrap
```

MATLAB wrapper tests should include construction, method dispatch, caught error recovery, and teardown through `clear classes` and `clear mex`.

## Docstrings

Set `GTWRAP_ADD_DOCSTRINGS=ON` together with `BUILD_DOC_XML=ON` to generate Python docstrings from the top project Doxygen XML.

```bash
cmake -S . -B build_wrap_docs \
  -D template_project_BUILD_PYTHON_WRAPPER=ON \
  -D GTWRAP_ADD_DOCSTRINGS=ON \
  -D BUILD_DOC_XML=ON
cmake --build build_wrap_docs --target template_project_py
```

The XML source is the build-tree `doc/xml` directory for the project being built. It does not use `${CMAKE_SOURCE_DIR}/xml`, so nested template-derived libraries cannot leak their docs into the top project wrapper generation.
