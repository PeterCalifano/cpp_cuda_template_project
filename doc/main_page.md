# cpp_cuda_template_project {#mainpage}

See the [README](../../README.md) for full usage documentation, or read on for the condensed reference.

## Installation

```bash
git clone <repo-url> my_project && cd my_project
./build_lib.sh -t release -i      # build + install to ./install
```

## Example usage (assuming installation worked)

```cmake
set(my_project_DIR "/path/to/install/lib/cmake/my_project")
find_package(my_project REQUIRED)
target_link_libraries(my_target PRIVATE my_project::my_project)
```

See `examples/template_consumer_project/` for a complete downstream CMake project.

## Adapting to a new project

Replace all occurrences of `template_project` with your project name, rename
`src/template_src/` and `src/template_src_kernels/`, and update
`set(project_name ...)` in the root `CMakeLists.txt`.

Full details in `README.md`.
