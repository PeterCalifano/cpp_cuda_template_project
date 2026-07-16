# ROS 2 Overlay

The optional ROS 2 overlay is a colcon workspace layered on top of the C++-first template. The normal library entry point is still `./build_lib.sh`; it never needs ROS and never reads `ros2/`.

## Encapsulation contract

ROS integration lives in `ros2/` plus the root overlay helpers:

- `build_ros2.sh`
- `add_ros2_support.sh`
- the four root `COLCON_IGNORE` markers
- `.github/workflows/build_ros2_overlay.yml`
- this documentation and the template-development checks

There is no root `package.xml` and no `ENABLE_ROS2` CMake option. The shim package at `ros2/template_project/` is the only package that includes the core library. Its `CMakeLists.txt` preloads the real root `cmake/` directory, then calls `add_subdirectory()` on the repository root so the usual install/export rules publish `template_project::template_project` into the colcon install prefix.

Downstream ament packages depend on the shim package named `template_project`. After colcon builds the shim, its install prefix is on `CMAKE_PREFIX_PATH`, so `template_project_ros` can use:

```cmake
find_package(template_project REQUIRED)
target_link_libraries(my_target PRIVATE template_project::template_project)
```

## Package layout

The overlay packages are:

| Package | Role |
|---|---|
| `template_project` | Plain CMake shim around the core library. |
| `template_project_interfaces` | ROS messages and services. |
| `template_project_ros` | Bridge package with conversions, lifecycle node, component, executable, and tests. |
| `template_project_spinup` | Launch files and default node configuration. |

The `template_project_ros` package keeps a conversions-vs-node split. `template_project_ros_conversions` links the core library and interfaces but does not depend on `rclcpp`; it is safe to test without a ROS executor. `template_project_ros_component` owns lifecycle, parameters, publishers, services, and component registration.

The bridge is intentionally source-adjacent: its private include path can reach core headers under the repository `src/` tree without making those headers part of the installed public API. A derived project should adapt `conversions.cpp` to use an exported public core header whenever one exists. An installed-only bridge consumer requires the core project to install/export that header first; the overlay does not turn private source headers into a public SDK.

## Build usage

Source a ROS 2 environment, or let `build_ros2.sh` source `/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash`:

```bash
./build_ros2.sh --clean
./build_ros2.sh --skip-tests
./build_ros2.sh --packages-select template_project_ros
./build_ros2.sh --debug
./build_ros2.sh --cmake-arg -DCMAKE_VERBOSE_MAKEFILE=ON
```

The script defaults `ROS_DISTRO` to `jazzy`, but it is otherwise distro-agnostic when the requested distro is installed.

The supplied standalone and composition launch files autostart the lifecycle node through `launch_ros`: they request configure, wait for the inactive state, then request activate. The service is therefore ready when either launch path finishes starting. Each launch file retains the equivalent plain `Node` or `ComposableNode` description as a commented template alternative. Uncomment that form only when an external lifecycle manager owns transitions; launching the raw executable, loading the raw component, or using those alternatives intentionally leaves the node unconfigured.

Jazzy's current `ComposableLifecycleNode` implementation resolves the loaded component's fully qualified name inconsistently during autostart. The composition launch file supplies that identity to the lifecycle event manager locally; remove the compatibility adapter after the upstream `launch_ros` fix is available in the supported ROS distro.

CUDA and OptiX flow through a workspace option facade:

| User flag | Colcon CMake argument | Shim mapping | Core CMake option |
|---|---|---|---|
| `--cuda` | `-DTEMPLATE_PROJECT_ENABLE_CUDA=ON` | cache-forces `ENABLE_CUDA` | `ENABLE_CUDA=ON` |
| `--optix` | `-DTEMPLATE_PROJECT_ENABLE_OPTIX=ON` and CUDA ON | cache-forces `ENABLE_OPTIX` | `ENABLE_OPTIX=ON` |

For a hermetic build that must not fetch spdlog, pass `--cmake-arg -DENABLE_FETCH_SPDLOG=OFF` and provide a discoverable system/package-manager spdlog installation when logging support is required. If spdlog is unavailable with fetching disabled, the core template disables its logging utilities.

Use a ROS 2 Jazzy environment or the ROS devcontainer for local GPU checks:

```bash
./build_ros2.sh --cuda
./build_ros2.sh --cuda --optix
```

## COLCON_IGNORE policy

`COLCON_IGNORE` markers keep colcon from crawling template support trees that are not ROS packages:

- `python/COLCON_IGNORE`: required because generated `setup.py` files can be misdetected as Python packages.
- `lib/COLCON_IGNORE`: protects vendored submodules if they contain manifests.
- `examples/COLCON_IGNORE` and `tests/COLCON_IGNORE`: avoid accidental package discovery in starter project code.

There are no markers in `doc/`, `matlab/`, or `profiling/`. Runtime-generated top-level directories such as `build*`, `install`, and `template_subbuild` are handled best-effort by `build_ros2.sh` when they exist. This matters when the repository is placed inside a parent workspace: without the markers, a parent colcon crawl can discover unrelated template internals.

## Version sync

ROS package manifests require strict `X.Y.Z` versions. `build_ros2.sh` runs:

```bash
./generate_version.sh --sync-ros2
```

before colcon builds, unless `--no-version-sync` is passed. The command rewrites the first `<version>` tag in each immediate `ros2/*/package.xml` to the core semantic version. It no-ops when `ros2/` is absent, so keeping `generate_version.sh` in tailored non-ROS projects is safe.

Run the same command manually after changing tags or before packaging source archives.

## Rollout to derived repositories

Use `add_ros2_support.sh` from this template checkout when a derived repository does not already contain a ROS overlay:

```bash
./add_ros2_support.sh --root /path/to/derived_repo --apply --yes --verify
```

The rollout script is purely additive. It refuses targets that already have `ros2/` or `build_ros2.sh`, copies the overlay files, renames copied ROS package paths and copied file contents from `template_project` to a ROS package prefix, and leaves existing target files untouched.

By default, the ROS package prefix is derived from the target CMake package name in `set(project_name "...")`. If the CMake package name is already ROS-valid, the two names match. If the CMake package name is not ROS-valid, the script keeps core CMake references pointed at the original CMake package name while using a ROS-valid package prefix for ROS package names. For example, a target CMake package named `space-nav-frontend` keeps this core CMake shape:

```cmake
find_package(space-nav-frontend REQUIRED)
target_link_libraries(my_target PRIVATE space-nav-frontend::space-nav-frontend)
```

The copied ROS packages use paths such as `ros2/space_nav_frontend_ros`. Pass `--ros-prefix <name>` when the derived repository needs an explicit ROS package prefix.

After the script runs, complete the EDIT-ME core-call step in the primary adaptation seam:

```text
ros2/<ros_prefix>_ros/src/conversions.cpp
```

Update the fenced include and `EvaluateTemplateCore` body to call the derived library API. Review `ros2/<ros_prefix>_ros/src/CTemplateLifecycleNode.cpp` only when ROS node wiring, parameters, publishers, or services also need to change. Here, `<ros_prefix>` is the ROS-valid prefix reported by `add_ros2_support.sh`, which may differ from the CMake project name. Then run `./build_ros2.sh --clean`.

Supported orders:

- rename-then-overlay: tailor and rename the C++ project first, then run `add_ros2_support.sh`.
- overlay-then-rename: add the overlay to a still-template-shaped checkout, then include the `ros2/` package names in the broad rename pass.

The script does not edit README, AGENTS, CLAUDE, or other existing target docs. Link this file from target docs manually when needed.

Derived repositories that intentionally removed optional template features need one manual tailoring pass after the copy. If CUDA, OptiX, or spdlog support is not present in the target, update the copied `build_ros2.sh` facade, shim CMake options, docs, and CI workflow so unsupported options are not advertised.

## Removal

The overlay is kept by default during template cleanup. Remove it explicitly:

```bash
./tailor_template_cleanup.sh --apply --yes --remove-ros2
```

`--remove-ros2` deletes `ros2/`, `build_ros2.sh`, `add_ros2_support.sh`, the colcon markers, the ROS overlay CI workflow, this file, and the ROS static pytest. It also strips `<!-- ros2-overlay-begin -->` / `<!-- ros2-overlay-end -->` fenced blocks from the template docs. `generate_version.sh` is left in place because `--sync-ros2` already no-ops without `ros2/`.

## CI

`.github/workflows/build_ros2_overlay.yml` runs the overlay in the `ros:jazzy` container. It has two jobs:

- `overlay-build`: installs dependencies, runs `rosdep install --from-paths ros2 -i -r -y --rosdistro jazzy`, builds/tests the overlay, then runs the static pytest.
- `rollout-dogfood`: strips the overlay from a copy, re-adds it with `add_ros2_support.sh --verify`, builds the overlay, and checks a plain standalone CMake build.

CUDA+ROS is local-only in this repository. The available self-hosted GPU runner does not provide the ROS environment, so CI intentionally avoids `build_ros2.sh --cuda`.

## Python boundary

`python/ bindings remain a separate ROS-free optional feature`. The overlay does not depend on Python bindings, and the static tests check that `python/` stays free of `rclcpp`, `ament`, and `rosidl` references.
