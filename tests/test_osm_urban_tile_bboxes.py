import sys, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.geodata.build_osm_urban_tile_bboxes import build_bboxes

class UrbanTileBboxTests(unittest.TestCase):
    def test_places_become_clipped_detailed_tile_bounds(self):
        features = [
            {"properties": {"tags": {"place": "city", "population": "2000000"}},
             "geometry": {"type": "Point", "coordinates": [69.0, 34.0]}},
            {"properties": {"place": "town", "population": "20000"},
             "geometry": {"type": "Polygon", "coordinates": [[[70,35],[70.1,35],[70.1,35.1],[70,35.1],[70,35]]]}},
            {"properties": {"place": "village"},
             "geometry": {"type": "Point", "coordinates": [71.0, 36.0]}},
            {"properties": {"place": "city", "population": "9000000"},
             "geometry": {"type": "Point", "coordinates": [100.0, 0.0]}},
        ]
        boxes, counts = build_bboxes(features, [[60.0, 29.0, 75.0, 38.0]])
        self.assertEqual(counts["city"], 1)
        self.assertEqual(counts["town"], 1)
        self.assertEqual(counts["village"], 1)
        self.assertEqual(len(boxes), 3)
        for west, south, east, north in boxes:
            self.assertGreaterEqual(west, 60.0)
            self.assertLessEqual(east, 75.0)
            self.assertGreaterEqual(south, 29.0)
            self.assertLessEqual(north, 38.0)

    def test_empty_region_gets_small_fallback_sample(self):
        boxes, counts = build_bboxes([], [[10.0, 20.0, 10.4, 20.4]])
        self.assertEqual(len(boxes), 1)
        self.assertEqual(counts["fallback"], 1)
        self.assertLess(boxes[0][2] - boxes[0][0], 0.1)

if __name__ == "__main__":
    unittest.main()
