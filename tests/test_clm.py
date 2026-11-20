"""Exercise CLM's process boundary without starting Claude or touching credentials.

Run with python3 nix/tests/test_clm.py --mirror /path/to/claude-toolkit/scripts/clm/clm.sh.
The executable doubles validate dispatch only.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


PARSER = argparse.ArgumentParser()
PARSER.add_argument("--mirror", type=Path, required=True)
OPTIONS, TEST_ARGS = PARSER.parse_known_args()
MIRROR_SOURCE = OPTIONS.mirror.resolve()
if not MIRROR_SOURCE.is_file():
    PARSER.error(f"CLM mirror not found: {MIRROR_SOURCE}")
FISH_SOURCE = Path(__file__).resolve().parents[1] / "home/mp/modules/fish/functions/clm.fish"
SHELLS = [(shutil.which("fish"), FISH_SOURCE), ("/bin/bash", MIRROR_SOURCE), ("/bin/zsh", MIRROR_SOURCE)]


class LauncherTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="clm-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.configs = self.root / "configs with spaces"
        for name, servers in [("context/repo-prompt-ce", {"RepoPrompt": {}}),
                              ("context/repo-prompt", {"RepoPrompt": {}}),
                              ("tools/example", {"Example": {}})]:
            path = self.configs / (name + ".json")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps({"mcpServers": servers}))
        # A bounded PATH keeps the tests independent of installed tools.
        for name in ["jq", "mkdir", "chmod", "date", "tee", "find", "sort", "basename", "cat", "tr", "sed", "uname"]:
            (self.bin / name).symlink_to(shutil.which(name))
        double = f"#!{sys.executable}\n" + '''import json, os, pathlib, sys
pathlib.Path(os.environ["CAPTURE"]).write_text(json.dumps({
    "tool": pathlib.Path(sys.argv[0]).name, "args": sys.argv[1:],
    "stdin": sys.stdin.read(), "cwd": os.getcwd(),
    "timeout": os.environ.get("MCP_TOOL_TIMEOUT")}))
sys.exit(int(os.environ.get("LAUNCH_EXIT", "0")))
'''
        path = self.bin / "claude"
        path.write_text(double)
        path.chmod(0o755)

    def run_clm(self, shell, source, args, code=0, extra_env=None, trace=False):
        capture = self.root / "capture.json"
        capture.unlink(missing_ok=True)
        env = {**os.environ, "PATH": str(self.bin), "CLM_MCP_CONFIG_DIR": str(self.configs),
               "XDG_STATE_HOME": str(self.root / "state"), "CAPTURE": str(capture),
               "MCP_TOOL_TIMEOUT": "76543", **(extra_env or {})}
        if Path(shell).name == "fish":
            command = [shell, "--no-config", "-c", 'set -p fish_function_path (path dirname "$argv[1]"); source "$argv[1]"; set -e argv[1]; clm $argv', str(source), *args]
            if trace:
                command[3] = 'set -g fish_trace 1; ' + command[3]
        else:
            command = [shell, "-c", 'source "$1"; shift; clm "$@"', "clm-test", str(source), *args]
            if trace:
                command.insert(1, "-x")
        result = subprocess.run(command, env=env, cwd=self.root, input="piped prompt\n",
                                text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, code, (shell, args, result.stdout, result.stderr))
        self.last_output = result.stdout
        self.last_trace = result.stderr
        return json.loads(capture.read_text()) if capture.exists() else None

    def expected(self, *extra, classic=False):
        configs = [str(self.configs / ("context/repo-prompt.json" if classic else "context/repo-prompt-ce.json"))]
        return ["--mcp-config", *configs, "--strict-mcp-config", *extra]

    def test_default_and_ordinary_flags(self):
        for shell, source in SHELLS:
            with self.subTest(shell=shell):
                capture = self.run_clm(shell, source, ["--model", "sonnet", "--resume", "chat id"])
                self.assertEqual(capture["tool"], "claude")
                self.assertEqual(capture["args"], self.expected("--model", "sonnet", "--resume", "chat id"))
                self.assertEqual(capture["stdin"], "piped prompt\n")
                self.assertEqual(capture["timeout"], "76543")
                bare = self.run_clm(shell, source, [])
                self.assertEqual(bare["tool"], "claude")
                self.assertEqual(bare["args"], self.expected())

    def test_composed_configs_after_claude_flags(self):
        for shell, source in SHELLS:
            with self.subTest(shell=shell):
                capture = self.run_clm(shell, source, ["--model", "sonnet", "tools/example"])
                self.assertEqual(capture["args"], ["--mcp-config", str(self.configs / "context/repo-prompt-ce.json"),
                                 str(self.configs / "tools/example.json"), "--strict-mcp-config", "--model", "sonnet"])

    def test_empty_suffix_and_literal_forwarding(self):
        for shell, source in SHELLS:
            with self.subTest(shell=shell):
                plain = self.run_clm(shell, source, ["--"])
                self.assertEqual(plain["args"], self.expected())
                args = ["-p", "tools/example", "", "--account", "work"]
                plain = self.run_clm(shell, source, ["--", *args], code=23, extra_env={"LAUNCH_EXIT": "23"})
                self.assertEqual(plain["tool"], "claude")
                self.assertEqual(plain["args"], self.expected(*args))

    def test_conflicting_repoprompt_configs_never_launch(self):
        for shell, source in SHELLS:
            with self.subTest(shell=shell):
                self.assertIsNone(self.run_clm(shell, source, ["context/repo-prompt", "context/repo-prompt-ce"], code=1))

    def test_fish_log_records_replayable_arguments(self):
        self.run_clm(*SHELLS[0], ["--", "-p", "tools/example", ""])
        path = self.root / "state/clm/launches.jsonl"
        entry = json.loads(path.read_text())
        self.assertEqual(entry["configs"], ["context/repo-prompt-ce"])
        self.assertEqual(entry["args"], ["-p", "tools/example", ""])
        self.assertNotIn("account", entry)
        self.assertEqual(path.parent.stat().st_mode & 0o777, 0o700)

    def test_fish_completion_respects_literal_boundary(self):
        shell, source = SHELLS[0]
        env = {**os.environ, "CLM_MCP_CONFIG_DIR": str(self.configs)}
        cases = [("clm tools/", "tools/example", True),
                 ("clm -- tools/", "tools/example", False),
                 ("clm --model sonnet tools/", "tools/example", True)]
        for commandline, suggestion, expected in cases:
            with self.subTest(commandline=commandline):
                result = subprocess.run([shell, "--no-config", "-c",
                                         'set -p fish_function_path (path dirname "$argv[1]"); source "$argv[1]"; complete -C "$argv[2]"',
                                         str(source), commandline], env=env, cwd=self.root,
                                        capture_output=True, text=True, check=True, timeout=15)
                self.assertEqual(suggestion in result.stdout, expected, result.stdout)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0], *TEST_ARGS])
