# Documentation Workflow

The documentation workflow is Doxygen-first and CMake-driven. It is intentionally scoped to the main project so nested template-derived dependencies do not publish duplicate `doc` targets or appear in the generated pages.

## Local Build

```bash
cmake -S . -B build_docs \
  -D ENABLE_TESTS=OFF \
  -D ENABLE_CUDA=OFF \
  -D ENABLE_OPTIX=OFF \
  -D BUILD_DOC_HTML=ON \
  -D BUILD_DOC_XML=ON
cmake --build build_docs --target doc
```

HTML output is written to:

```text
build_docs/doc/html/index.html
```

XML output is written to:

```text
build_docs/doc/xml/
```

Use the preset when your CMake version supports presets:

```bash
cmake --preset docs
cmake --build --preset docs
```

## CMake Targets

`HandleDoxygenDocs.cmake` creates namespaced targets first:

```text
<LIB_NAMESPACE>_doc
<LIB_NAMESPACE>_doc_clean
```

When the project is the top-level build, it also creates the conventional aliases:

```text
doc
doc_clean
```

Nested builds do not create these generic aliases.

## Input Scope

Doxygen input is explicit:

```text
src/
doc/
```

The generated Doxyfile excludes `lib/`, build directories, and `_deps/`. Do not point `INPUT` at the repository root; that would include nested dependencies, vendored code, and generated artifacts.

## GitHub Pages

`.github/workflows/docs_pages.yml` builds the Doxygen HTML site, uploads `build_docs/doc/html` as a Pages artifact, and deploys it from the default branch or manual dispatch.

Pull requests build and upload the artifact for inspection but do not deploy. Default-branch pushes and manual dispatches deploy to the `github-pages` environment.

After deployment, the workflow fetches the published Pages URL and checks that the served index contains the expected documentation links. This guards against successful artifact upload with a broken or stale deployed site.

Required repository setting:

```text
Settings > Pages > Build and deployment > Source: GitHub Actions
```

## Verification

Run the docs CTest gates before publishing:

```bash
ctest --test-dir build --output-on-failure -R "docs|pages|issue_templates|version"
```

After a Pages deployment, check:

1. The workflow run passed.
2. The uploaded artifact contains `index.html`.
3. The deployment URL serves the project title and expected docs headings.

If the Pages setting, authentication, network, or deployment state blocks verification, stop and record the exact command, error excerpt, and next action in `doc/developments/docs_workflow_rollout.md`.
