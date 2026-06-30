"""Regression tests for the devcontainer JSON updater."""

from __future__ import annotations

import importlib.util
import json
import types
from pathlib import Path


def _LoadUpdateModule() -> types.ModuleType:
    """Load the devcontainer updater script as a Python module.

    Example:
        module_ = _LoadUpdateModule()
        print(hasattr(module_, "load_existing"))
        # Output:
        # True
    """
    repoRoot_ = Path(__file__).resolve().parents[2]
    modulePath_ = repoRoot_ / ".devcontainer" / "update_devcontainer_json.py"
    spec_ = importlib.util.spec_from_file_location("update_devcontainer_json", modulePath_)
    assert spec_ is not None
    assert spec_.loader is not None

    module_ = importlib.util.module_from_spec(spec_)
    spec_.loader.exec_module(module_)
    return module_


class TestDevcontainerJson:
    def test_load_existing_accepts_inline_jsonc_comments(self, tmp_path: Path) -> None:
        devcontainerJson_ = tmp_path / "devcontainer.json"
        devcontainerJson_.write_text(
            """
{
  // Existing hand-written comments should be tolerated.
  "name": "Existing", // Inline comments after properties should also work.
  "remoteEnv": {
    "DISPLAY": "unix:0", // Preserve unmanaged environment entries.
    "DOCS_URL": "https://example.invalid/docs"
  }
}
""",
            encoding="utf-8",
        )
        updateModule_ = _LoadUpdateModule()

        data_ = updateModule_.load_existing(str(devcontainerJson_))

        assert data_["name"] == "Existing"
        assert data_["remoteEnv"]["DISPLAY"] == "unix:0"
        assert data_["remoteEnv"]["DOCS_URL"] == "https://example.invalid/docs"
        json.dumps(data_)
