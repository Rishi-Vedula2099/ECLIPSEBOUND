# tests/test_godot_headless.py
"""Automated engine validation launching Godot 4 headlessly to verify zero runtime or parse errors."""
import os
import shutil
import subprocess
import pytest


def get_godot_executable() -> str | None:
    # 1. Check PATH
    cmd = shutil.which("godot_console") or shutil.which("godot")
    if cmd:
        return cmd

    # 2. Check WinGet standard install path on Windows
    local_app_data = os.environ.get("LOCALAPPDATA", "")
    if local_app_data:
        winget_pkg = os.path.join(
            local_app_data,
            "Microsoft",
            "WinGet",
            "Packages",
            "GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe",
            "Godot_v4.7.2-stable_win64_console.exe",
        )
        if os.path.isfile(winget_pkg):
            return winget_pkg

    return None


def test_godot_engine_headless_execution():
    godot_bin = get_godot_executable()
    if not godot_bin:
        pytest.skip("Godot executable not found on system PATH or WinGet directory")

    game_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "game"))
    assert os.path.isdir(game_dir), f"Game directory not found at {game_dir}"

    result = subprocess.run(
        [godot_bin, "--headless", "--path", game_dir, "--quit"],
        capture_output=True,
        text=True,
        timeout=15,
    )

    assert result.returncode == 0, f"Godot exited with code {result.returncode}. Output:\n{result.stderr or result.stdout}"
    assert "SCRIPT ERROR" not in result.stderr
    assert "Parse error" not in result.stderr
    assert "Failed to load script" not in result.stderr
