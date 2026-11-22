import json, subprocess, sys, tempfile, unittest
from pathlib import Path

import numpy as np
import rasterio
from rasterio.transform import from_origin

ROOT = Path(__file__).resolve().parents[1]

class DemConversionTests(unittest.TestCase):
    def test_cropped_dem_uses_global_tile_coordinates(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            source = base / "source.tif"
            output = base / "tile.f32"
            metadata = base / "tile.json"
            values = (np.arange(10000, dtype=np.int16).reshape((100, 100)) - 100)
            with rasterio.open(source, "w", driver="GTiff", height=100, width=100,
                               count=1, dtype="int16", crs="EPSG:4326",
                               transform=from_origin(60.0, 45.0, 0.01, 0.01),
                               nodata=-32768) as dataset:
                dataset.write(values, 1)
            subprocess.run([
                sys.executable, str(ROOT / "tools/geodata/convert_dem.py"), str(source),
                "--bbox", "60.1", "44.8", "60.3", "45.0",
                "--anchor-lon", "72.3", "--anchor-lat", "40.7",
                "--global-grid", "--clamp-sea-level",
                "--output", str(output), "--metadata", str(metadata),
            ], check=True, cwd=ROOT)
            meta = json.loads(metadata.read_text())
            self.assertEqual((meta["width"], meta["height"]), (20, 20))
            self.assertEqual(meta["projection"], "global_equirectangular")
            self.assertAlmostEqual(meta["origin_x"], (60.2 - 72.3) * 111320.0, places=2)
            self.assertAlmostEqual(meta["origin_z"], -(44.9 - 40.7) * 111320.0, places=2)
            self.assertEqual(output.stat().st_size, 20 * 20 * 4)
            dem = np.fromfile(output, dtype="<f4")
            self.assertGreaterEqual(float(dem.min()), 0.0)

if __name__ == "__main__":
    unittest.main()
