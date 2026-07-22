# Agents instructions

Write to CONTEXT.md the context before compaction to prevent data loss.
After auto-compaction, read again AGENTS.md and CONTEXT.md before restarting.
<!-- ros2-overlay-begin -->
## Optional ROS 2 Overlay

See `doc/ros2_overlay.md` before changing the optional ROS 2 overlay. `./build_lib.sh` is the C++-first library entry point and never needs ROS. `./build_ros2.sh` is the optional ROS 2 overlay build and test entry point.

Keep ROS-related changes confined to `ros2/` plus the documented root helpers, docs, tests, markers, and the single ROS overlay workflow.
<!-- ros2-overlay-end -->
For python: Use python standard >= 3.12, matplotlib is the backend for most plots, but for images PIL and opencv are also used. For any statistics-like plot prefer seaborn, my default choice. Use pytorch for machine learning applications, supported by sklearn. Function names beings with Capital letter, snake case, methods not. Classes Similarly. Internal methods (not public API) must start with _, local scope variables end with _. All methods of classes shall start with small letter. Prefer dataclasses instead of dicts and enums instead of Literals if more than two entries. Type Hints Must Always Be Present. Onnx Export Compatibility Is Generally Required. When Writing New Classes Or Functions, A Runnable Example Should Always Be Present With Output To Show Results.
For C++/CUDA: C++17 and C++20 are the core standards. CUDA mainly >12.6. Answers should be on point without too many digressions, technical (for intermediate and advanced users) but simple enough to explain the concepts. Prefer using concepts over SFINAE. Unit tests using Catch2. Check files to see convention of names. Prefer Classes over structs.
For MATLAB: Use classes a lot also in MATLAB, with a python style, but do it only when it makes sense. Functions in MATLAB are often more efficient. Evaluate whether it makes sense to have stateful implementation. Use "self" instead of "obj". All variables names must specify the datatype of the variable since MATLAB does not (hungarian notation). The following list applies: d for double, f for float, b for bool, str for struct and not for strings, char for strings and chars, ui8 for uint8, i8 for int8.  All the other integers are similar to the latter. Specify "obj" as prefix if an object, cell if a cell, table if a table; "bus_" if a Simulink bus. The names are always in Pascal case including the prefix, for instance ui8MyVariable. Never nest functions definitions within other functions, always do them separate or at most in the same file (after the main function implementation). Add them as local in the same function file only when not re-used elsewhere, otherwise prefer a single implementation. Function names and static methods of classes starts with Capital letter. Local functions names ends with underscore meaning "private". Names of variables must be explicative and tell what the variable does. Short names are not allowed unless "very local in scope". Use underscore for those variables and preferably Tmp within the name. For codes that are intended to be algorithms of some kind (e.g. not plots or things to run on the host PC), make them always MATLAB codegen safe (especially if codegen directive is used). In that case names should be limited to 31 chars. Add the same template of doc to functions as below and always specify arguments-end block for input and output:
%% SIGNATURE
%
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% DD-MM-YYYY  Pietro Califano     First prototype.
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
%
% -------------------------------------------------------------------------------------------------------------

%% Function code

## Staged-Code Review Quality Gate

Before handing staged changes to the user for commit review, inspect the complete
Git index with `git diff --cached`. Apply this gate to files staged by either the
user or the agent. This review does not authorize staging, committing, or
rewriting unrelated code.

For every staged source file that is new or substantially modified:

- Add or update both levels of applicable documentation: the file/module-level
  header and the public class/function/method documentation. Follow the
  established consolidated files for the relevant language and component.
- Organize related statements into visually separated blocks. Each block must
  implement one immediate objective or implementation step, not an entire broad
  feature.
- Introduce each non-obvious block with a concise comment explaining what it
  accomplishes and, when relevant, why that approach is required.
- Prefer purpose-, invariant-, and contract-oriented comments. Do not add
  comments that merely translate individual statements into prose.
- Preserve useful existing comments and documentation unless the staged change
  makes them incorrect.
- Review the staged result as a reader will receive it, rather than reviewing
  only the individual lines edited during implementation.

Limit cleanup to the intended scope of the staged work. Do not rewrite unrelated
legacy code merely because the same file is staged. Do not report the changes as
ready for review until this pass is complete; summarize any documentation or
readability cleanup performed during the pass.

### C++ and CUDA pattern

Use Doxygen for both the file header and public API documentation:

```cpp
/// @file observation_loader.cpp
/// @brief Loads validated observations from a delimited input file.
/// @details Owns parsing and validation; filtering policy remains with the
///          caller.

/// @brief Load and validate observations from disk.
/// @param inputPath Path to the delimited observation file.
/// @return Valid observations in input order.
/// @throws std::runtime_error When the file cannot be parsed.
std::vector<CObservation> LoadValidObservations(
    const std::filesystem::path& inputPath)
{
    // Parse the complete file first so malformed rows produce one consistent
    // diagnostic path.
    const std::vector<CObservation> parsedObservations =
        ParseObservations(inputPath);

    // Retain only observations satisfying the domain validity contract while
    // preserving their original order.
    std::vector<CObservation> validObservations;
    validObservations.reserve(parsedObservations.size());
    std::ranges::copy_if(parsedObservations,
                         std::back_inserter(validObservations),
                         IsObservationValid);

    return validObservations;
}
```

### Python pattern

Use Google-style module, class, method, and function docstrings. Keep type hints
on every callable and follow the repository naming conventions:

```python
"""Load and validate observation records.

This module owns file parsing and domain validation. Selection policy remains
with the caller.

Example:
    observations_ = Load_valid_observations(Path("observations.csv"))
    print(len(observations_))

Output:
    3
"""


def Load_valid_observations(input_path_: Path) -> list[Observation]:
    """Load valid observations while preserving their input order.

    Args:
        input_path_: Path to the delimited observation file.

    Returns:
        Valid observations in input order.

    Raises:
        ValueError: If an input row cannot be parsed.

    Example:
        observations_ = Load_valid_observations(Path("observations.csv"))
        print(len(observations_))

    Output:
        3
    """
    # Parse all rows through one path so malformed input produces consistent
    # diagnostics.
    parsed_observations_ = Parse_observations(input_path_)

    # Enforce the domain validity contract without changing source ordering.
    valid_observations_ = [
        observation_
        for observation_ in parsed_observations_
        if observation_.isValid()
    ]

    return valid_observations_
```

### MATLAB pattern

For a primary MATLAB function file, the leading sectioned function
documentation is also the file-level entry documentation. Scripts require an
opening sectioned description, while class files require class help text plus
the same sectioned documentation on public methods. Keep the existing
`SIGNATURE`, `DESCRIPTION`, `INPUT`, `OUTPUT`, `CHANGELOG`, and `DEPENDENCIES`
template:

```matlab
function tableValidObservations = LoadValidObservations(charInputPath)
%% SIGNATURE
% tableValidObservations = LoadValidObservations(charInputPath)
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Load and validate observations while preserving their input order.
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% charInputPath             Path to the delimited observation file.
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% tableValidObservations    Valid observations in input order.
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% DD-MM-YYYY  Pietro Califano     First prototype.
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% ParseObservations
% -------------------------------------------------------------------------------------------------------------

arguments
    charInputPath (1, :) char
end

arguments (Output)
    tableValidObservations table
end

% Parse all rows through one path so malformed input produces consistent
% diagnostics.
tableParsedObservations = ParseObservations(charInputPath);

% Enforce the domain validity contract without changing source ordering.
bValidObservation = tableParsedObservations.bIsValid;
tableValidObservations = tableParsedObservations(bValidObservation, :);

end
```
