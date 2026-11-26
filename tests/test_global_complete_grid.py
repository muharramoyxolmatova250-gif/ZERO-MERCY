import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / "tools/geodata/build_global_tile_grid.py"

class GlobalCompleteGridTests(unittest.TestCase):
    def test_indexes_all_cells_and_marks_only_existing_sources(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            (base / "data/osm/tiles/test").mkdir(parents=True)
            (base / "data/terrain/tiles/global").mkdir(parents=True)
            (base / "data/osm/tiles/test/0_0.geojson").write_text('{"type":"FeatureCollection","features":[]}' + " " * 100)
            (base / "data/terrain/tiles/global/0_0.f32").write_bytes(b"dem")
            runtime = base / "region_tiles.json"
            runtime.write_text(json.dumps({
                "0,0": {
                    "center_lon": 0.05, "center_lat": 0.05,
                    "geojson_paths": ["res://data/osm/tiles/test/0_0.geojson"],
                    "dem_height_path": "res://data/terrain/tiles/global/0_0.f32"
                },
                "_tile_size_m": 11132
            }))
            metadata, bitmap = base / "global_tile_grid.json", base / "presence.bin"
            subprocess.run([
                sys.executable, str(BUILDER), "--runtime-index", str(runtime),
                "--metadata", str(metadata), "--bitmap", str(bitmap), "--root", str(base)
            ], check=True, cwd=ROOT)
            data = json.loads(metadata.read_text())
            self.assertEqual(data["tile_count"], 6_480_000)
            self.assertEqual(data["columns"], 3600)
            self.assertEqual(data["rows"], 1800)
            self.assertEqual(data["osm_cells_with_files"], 1)
            self.assertEqual(data["dem_cells_with_files"], 1)
            self.assertEqual(bitmap.stat().st_size, 2 * 810_000)

if __name__ == "__main__":
    unittest.main()
