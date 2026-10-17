"""Exercise the real shell script with no network, Nutch, Solr or index writes."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "conf/nutch/crawler.sh"


class CrawlerControlFlowTest(unittest.TestCase):
    def run_crawler(self, generate_status=0, fail_command="", domain="",
                    sitemap_status=0, sitemap_body="<loc>https://example.test/page</loc>\n"):
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
if [ "$1" = --fail ]; then
  cat "$SITEMAP_BODY"
  exit "$SITEMAP_STATUS"
fi
''')
            nutch.chmod(0o700)
            curl.chmod(0o700)
            log = root / "calls"
            seeds = root / "seeds"
            seeds.mkdir()
            (seeds / "sitemap.txt").write_text("https://example.test/previous\n")
            (root / "sitemap-body").write_text(sitemap_body)
            env = dict(os.environ, PATH=f"{binaries}:{os.environ['PATH']}",
                       NUTCH_HOME=str(root), SOLR_PORT="8983", CALL_LOG=str(log),
                       GENERATE_STATUS=str(generate_status), FAIL_COMMAND=fail_command,
                       SITEMAP_STATUS=str(sitemap_status), SITEMAP_BODY=str(root / "sitemap-body"))
            result = subprocess.run(
                ["bash", str(SCRIPT), "isolated", "1", str(root / "seeds"),
                 "2", domain, "10", str(root / "conf")],
                env=env, capture_output=True, text=True, timeout=10)
            self.seeds_after = (seeds / "sitemap.txt").read_text()
            self.seed_files_after = sorted(p.name for p in seeds.iterdir())
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

    def test_sitemap_replacement_happens_before_injection(self):
        result, calls = self.run_crawler(domain="https://example.test")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls[:2], ["curl:--fail", "nutch:inject"])
        self.assertEqual(self.seeds_after, "https://example.test/page\n")
        self.assertEqual(self.seed_files_after, ["sitemap.txt"])

    def test_failed_sitemap_preserves_seeds_and_prevents_injection(self):
        for status in (22, 28):
            with self.subTest(status=status):
                result, calls = self.run_crawler(
                    domain="https://example.test", sitemap_status=status)
                self.assertEqual(result.returncode, status)
                self.assertEqual(calls, ["curl:--fail"])
                self.assertEqual(self.seeds_after, "https://example.test/previous\n")
                self.assertEqual(self.seed_files_after, ["sitemap.txt"])

    def test_empty_or_non_sitemap_response_preserves_seeds(self):
        for body in ("", "<html>Temporarily unavailable</html>\n",
                     "<url><loc>https://example.test/page</loc></url>\n"):
            with self.subTest(body=body):
                result, calls = self.run_crawler(domain="https://example.test", sitemap_body=body)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls, ["curl:--fail"])
                self.assertEqual(self.seeds_after, "https://example.test/previous\n")
                self.assertEqual(self.seed_files_after, ["sitemap.txt"])


if __name__ == "__main__":
    unittest.main()
