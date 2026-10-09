"""Offline regression tests for failures before any site files are created."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "utils/bootstrap.sh"


class BootstrapFailureTests(unittest.TestCase):
    def run_failure(self, failure, expected, **overrides):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            gh = root / "gh"
            gh.write_text('''#!/usr/bin/env bash
case "$*" in
  *releases/latest*) stage=release; value=v1.0.0 ;;
  *commits/*) stage=commit; value=abcdef ;;
  *) stage=access; value=repository ;;
esac
if [[ "$stage" == "$FAIL_STAGE" ]]; then
  echo "gh: fixture HTTP 404 or authentication error ($stage)" >&2
  exit 1
fi
printf '%s\\n' "$value"
''')
            gh.chmod(0o755)
            env = os.environ.copy()
            env.update(PATH=f"{root}:{env['PATH']}", FAIL_STAGE=failure,
                       STARTER_REF="main", TOOLING_TAG="", ORG="fixture",
                       STARTER_REPO="starter", CORE_TOOLING_REPO="tooling")
            env.update(overrides)
            target = root / "site"
            # Feed the script on stdin, as in the documented curl | bash command.
            result = subprocess.run(["bash", "-s", "--", str(target)],
                                    input=SCRIPT.read_text(), env=env,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(expected, result.stderr)
            self.assertIn("fixture HTTP 404", result.stderr)
            self.assertFalse(target.exists())
            self.assertNotIn("✅ Created", result.stdout)

    def test_private_repository_access_error_is_actionable(self):
        self.run_failure("access", "gh auth login")

    def test_release_lookup_failure_is_not_silent(self):
        self.run_failure("release", "Cannot resolve a core-tooling release")

    def test_invalid_tooling_ref_stops_before_creating_target(self):
        self.run_failure("commit", "Bootstrap failed", TOOLING_TAG="missing-tag")


if __name__ == "__main__":
    unittest.main()
