# Testing, CI, and Issue Workflow

## Local Gates

Use CTest for both compiled tests and workflow-level regressions:

```bash
cmake -S . -B build -DENABLE_TESTS=ON
cmake --build build --parallel 4
ctest --test-dir build --output-on-failure
```

Focused documentation checks:

```bash
ctest --test-dir build --output-on-failure -R "docs|pages|issue_templates|version"
```

## CI Workflows

The Linux workflows keep CPU tuning portable because build artifacts are tested in a separate job. Do not re-enable `CPU_ENABLE_NATIVE_TUNING=ON` in GitHub Actions unless build and test run on the same pinned CPU family.

The Pages workflow is separate from the C++ build workflow. It has these stages:

1. Configure docs with CUDA, OptiX, and tests disabled.
2. Build Doxygen HTML and XML.
3. Verify `index.html` exists before upload.
4. Upload the Pages artifact.
5. Deploy only for default-branch pushes or manual dispatch.
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
- suspected owner
- next action

Use `doc/developments/docs_workflow_rollout.md` as the rollout log.
