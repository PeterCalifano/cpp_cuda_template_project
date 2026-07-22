# Default ROS 2 Metadata Sync Implementation Plan

> **For agentic workers:** Execute this plan inline with TDD and fresh verification at each repository boundary. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `generate_version.sh` synchronize ROS 2 package metadata by default when the supported overlay helper is present, while retaining explicit compatibility and an opt-out.

**Architecture:** Use an automatic/default sync mode that activates only for repositories carrying `ros2/tools/sync_package_metadata.py`. Preserve `--sync-ros2` as an explicit request and add `--no-sync-ros2` to suppress synchronization. Establish the behavior in the template and testfield before copying the focused script change to canonical derived repositories.

**Tech Stack:** Bash, Python 3.12 pytest contracts, CMake/CTest, Git.

## Global Constraints

- Do not modify Git submodules, backup repositories, development copies, or temporary worktrees.
- Stop before editing any target with overlapping uncommitted changes in the files this rollout owns.
- Commit only in `cpp_cuda_template_testfield`, as explicitly requested.
- Preserve each derived repository's project-specific version defaults and unrelated script customizations.

---

### Task 1: Upgrade the template contract

- [ ] Change the existing copied-overlay regression to invoke `generate_version.sh` without `--sync-ros2` and observe the expected failure.
- [ ] Implement automatic helper-gated synchronization and verify the regression passes.
- [ ] Add a failing `--no-sync-ros2` regression, implement the opt-out, and verify it passes.
- [ ] Update the versioning and ROS overlay documentation to describe default, explicit, and disabled modes.
- [ ] Run the targeted Python contract and the full template test gate.

### Task 2: Update and commit testfield

- [ ] Repeat the default-sync and opt-out RED/GREEN regressions in testfield.
- [ ] Copy the verified focused script behavior and update testfield documentation.
- [ ] Run testfield's complete test gate.
- [ ] Review `git diff --cached` in full and commit the approved testfield changes using its imperative commit-message style.

### Task 3: Propagate to derived repositories

- [ ] Inventory every `generate_version.sh` under `devDir` and `$SCRATCH_PRO/devDir/event-based-repos`.
- [ ] Exclude submodules, backup/development/temporary copies, and any repository with overlapping dirty work.
- [ ] Apply only the automatic/default and opt-out behavior while preserving repository-specific script content.
- [ ] Validate every updated script with syntax, help, default-sync, and opt-out checks in isolated fixtures.
- [ ] Report the exact updated, excluded, and blocked repository lists without committing downstream changes.
