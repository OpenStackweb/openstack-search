"""Exercise the real shell script with no network, Nutch, Solr or index writes."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "conf/nutch/crawler.sh"


class CrawlerControlFlowTest(unittest.TestCase):
    def run_crawler(self, generate_status=0, fail_command=""):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binaries = root / "bin"
            binaries.mkdir()
            nutch = root / "runtime/local/bin/nutch"
            nutch.parent.mkdir(parents=True)
            nutch.write_text('''#!/bin/bash
echo "nutch:$1" >> "$CALL_LOG"
if [ "$1" = generate ]; then exit "$GENERATE_STATUS"; fi
if [ "$1" = "$FAIL_COMMAND" ]; then exit 7; fi
''')
            curl = binaries / "curl"
            curl.write_text('''#!/bin/bash
echo "curl:$1" >> "$CALL_LOG"
''')
            nutch.chmod(0o700)
            curl.chmod(0o700)
            log = root / "calls"
            env = dict(os.environ, PATH=f"{binaries}:{os.environ['PATH']}",
                       NUTCH_HOME=str(root), SOLR_PORT="8983", CALL_LOG=str(log),
                       GENERATE_STATUS=str(generate_status), FAIL_COMMAND=fail_command)
            result = subprocess.run(
                ["bash", str(SCRIPT), "isolated", "1", str(root / "seeds"),
                 "2", "", "10", str(root / "conf")],
                env=env, capture_output=True, text=True, timeout=10)
            return result, log.read_text().splitlines()

    def test_success_runs_both_batches_then_finishes_index(self):
        result, calls = self.run_crawler()
        self.assertEqual(result.returncode, 0, result.stderr)
        batch = [f"nutch:{command}" for command in
                 ("generate", "fetch", "parse", "updatedb", "solrindex", "solrdedup")]
        self.assertEqual(calls[:13], ["nutch:inject"] + batch * 2)
        self.assertEqual(len(calls), 15)
        self.assertIn("/update?", calls[-2])
        self.assertIn("/suggest?", calls[-1])

    def test_empty_fetch_list_skips_fetch_but_finishes_index(self):
        result, calls = self.run_crawler(generate_status=1)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no more URLs", result.stdout)
        self.assertEqual(calls[:2], ["nutch:inject", "nutch:generate"])
        self.assertEqual(len(calls), 4)
        self.assertIn("/update?", calls[-2])
        self.assertIn("/suggest?", calls[-1])

    def test_unexpected_generate_error_preserves_status_and_stops(self):
        result, calls = self.run_crawler(generate_status=3)
        self.assertEqual(result.returncode, 3)
        self.assertIn("Failed with exit value 3", result.stdout)
        self.assertEqual(calls, ["nutch:inject", "nutch:generate"])

    def test_other_pipeline_errors_still_stop_immediately(self):
        for command in ("inject", "fetch", "parse", "updatedb", "solrindex", "solrdedup"):
            with self.subTest(command=command):
                result, calls = self.run_crawler(fail_command=command)
                self.assertEqual(result.returncode, 7)
                self.assertEqual(calls[-1], f"nutch:{command}")
                self.assertFalse(any(call.startswith("curl:") for call in calls))


if __name__ == "__main__":
    unittest.main()
