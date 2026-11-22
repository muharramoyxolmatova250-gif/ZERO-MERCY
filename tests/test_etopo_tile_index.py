import sys, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.geodata.download_etopo_tile import source_tile_name

class EtopoTileIndexTests(unittest.TestCase):
    def test_northern_eastern_tile(self):
        self.assertEqual(source_tile_name(60.0, 44.9, 60.1, 45.0),
                         "ETOPO_2022_v1_15s_N45E060_surface.tif")

    def test_southern_western_tile(self):
        self.assertEqual(source_tile_name(-15.0, -30.0, -14.9, -29.9),
                         "ETOPO_2022_v1_15s_S15W015_surface.tif")

    def test_antimeridian_east_tile(self):
        self.assertEqual(source_tile_name(179.9, -1.0, 180.0, 0.0),
                         "ETOPO_2022_v1_15s_N00E165_surface.tif")

    def test_antimeridian_west_tile(self):
        self.assertEqual(source_tile_name(-180.0, 0.0, -179.9, 0.1),
                         "ETOPO_2022_v1_15s_N15W180_surface.tif")

    def test_rejects_invalid_bbox(self):
        with self.assertRaises(ValueError):
            source_tile_name(10, 20, 5, 30)

if __name__ == "__main__":
    unittest.main()
