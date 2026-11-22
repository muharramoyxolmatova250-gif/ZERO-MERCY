import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLANNER = ROOT / "tools/geodata/plan_region_tiles.py"

class GlobalTileGridTests(unittest.TestCase):
    def test_country_sources_merge_into_same_global_cells(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            index = base / "region_tiles.json"
            first_plan = base / "first.json"
            second_plan = base / "second.json"
            common = [
                sys.executable, str(PLANNER),
                "--tile-deg", "0.1", "--tile-size-m", "11132",
                "--anchor", "72.3", "40.7", "--global-grid",
                "--index-output", str(index),
            ]
            subprocess.run(common + [
                "--region", "country_a", "--bbox", "72.2", "40.6", "72.4", "40.8",
                "--output", str(first_plan),
            ], check=True, cwd=ROOT)
            subprocess.run(common + [
                "--region", "country_b", "--bbox", "72.3", "40.6", "72.5", "40.8",
                "--output", str(second_plan), "--merge-index",
            ], check=True, cwd=ROOT)
            a = json.loads(first_plan.read_text())
            b = json.loads(second_plan.read_text())
            runtime = json.loads(index.read_text())
            self.assertEqual(a["tile_count"], 4)
            self.assertEqual(b["tile_count"], 4)
            shared = [entry for key, entry in runtime.items()
                      if not key.startswith("_") and "country_a" in entry.get("source_regions", [])
                      and "country_b" in entry.get("source_regions", [])]
            self.assertEqual(len(shared), 2)
            self.assertTrue(all(len(entry["geojson_paths"]) == 2 for entry in shared))

if __name__ == "__main__":
    unittest.main()
