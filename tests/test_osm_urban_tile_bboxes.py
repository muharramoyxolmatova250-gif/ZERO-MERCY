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
        boxes, counts, settlements = build_bboxes(features, [[60.0, 29.0, 75.0, 38.0]])
        self.assertEqual(counts["city"], 1)
        self.assertEqual(counts["town"], 1)
        self.assertEqual(counts["village"], 1)
        self.assertGreater(len(boxes), 3)
        self.assertEqual(len(settlements), 3)
        self.assertTrue(all(item.get('home_tile_id') for item in settlements))
        for west, south, east, north in boxes:
            self.assertGreaterEqual(west, 60.0)
            self.assertLessEqual(east, 75.0)
            self.assertGreaterEqual(south, 29.0)
            self.assertLessEqual(north, 38.0)

    def test_nearby_villages_share_one_grid_cell(self):
        features = [
            {"properties": {"place": "village"}, "geometry": {"type": "Point", "coordinates": [10.02, 20.02]}},
            {"properties": {"place": "village"}, "geometry": {"type": "Point", "coordinates": [10.04, 20.04]}},
        ]
        boxes, counts, settlements = build_bboxes(features, [[10.0, 20.0, 10.2, 20.2]])
        self.assertEqual(counts["village"], 2)
        self.assertEqual(len(boxes), 1)

    def test_andijan_starting_cell_is_first(self):
        features = [
            {"properties": {"place": "city", "population": "1000000"},
             "geometry": {"type": "Point", "coordinates": [10.0, 20.0]}},
            {"properties": {"place": "village"},
             "geometry": {"type": "Point", "coordinates": [72.32, 40.65]}},
        ]
        boxes, counts, settlements = build_bboxes(features, [[0.0, 0.0, 100.0, 90.0]])
        self.assertAlmostEqual(boxes[0][0], 72.3, places=6)
        self.assertAlmostEqual(boxes[0][1], 40.6, places=6)
        self.assertAlmostEqual(boxes[0][2], 72.4, places=6)
        self.assertAlmostEqual(boxes[0][3], 40.7, places=6)

    def test_empty_region_gets_small_fallback_sample(self):
        boxes, counts, settlements = build_bboxes([], [[10.0, 20.0, 10.4, 20.4]])
        self.assertEqual(len(boxes), 1)
        self.assertEqual(counts["fallback"], 1)
        self.assertAlmostEqual(boxes[0][2] - boxes[0][0], 0.1, places=6)

if __name__ == "__main__":
    unittest.main()
