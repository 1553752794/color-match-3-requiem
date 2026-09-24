from __future__ import annotations

import importlib.util
import os
from pathlib import Path


RENDERER = (
    Path.home()
    / ".codex/plugins/cache/openai-primary-runtime/documents/26.730.11710/skills/documents/render_docx.py"
)


def main() -> None:
    poppler_bin = (
        Path.home()
        / ".cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/Library/bin"
    )
    os.environ["PATH"] = str(poppler_bin) + os.pathsep + os.environ.get("PATH", "")

    spec = importlib.util.spec_from_file_location("codex_render_docx", RENDERER)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load renderer: {RENDERER}")
    renderer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(renderer)

    original_run_cmd = renderer._run_cmd

    def run_cmd(cmd, env, verbose):
        fixed = []
        for arg in cmd:
            prefix = "-env:UserInstallation=file://"
            if arg.startswith(prefix):
                profile = arg[len(prefix) :].replace("\\", "/")
                arg = prefix + "/" + profile
            fixed.append(arg)
        return original_run_cmd(fixed, env, verbose)

    renderer._run_cmd = run_cmd
    renderer.main()


if __name__ == "__main__":
    main()
