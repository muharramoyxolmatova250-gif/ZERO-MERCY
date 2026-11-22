import unittest, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.geodata.build_global_country_queue import build_queue
from tools.geodata.build_global_manifest import _geometry_bboxes, build_offline_catalog, ROOT

class GlobalCountryQueueTests(unittest.TestCase):
    def test_country_and_combined_extracts(self):
        catalog = {"regions": [
            {"id": "germany", "name": "Germany", "iso3166_1": "DE", "bboxes": [[5,47,15,55]]},
            {"id": "israel-and-palestine", "name": "Israel and Palestine",
             "iso3166_1": "PS,IL", "bboxes": [[34,29,36,34]]},
            {"id": "california", "name": "California", "iso3166_1": [],
             "iso3166_2": ["US-CA"], "bboxes": [[-125,32,-114,42]]},
            {"id": "missing-bounds", "name": "No bounds", "iso3166_1": ["XX"]},
        ]}
        queue = build_queue(catalog)
        self.assertEqual([x["id"] for x in queue], ["germany", "israel-and-palestine"])
        self.assertEqual(queue[1]["iso3166_1"], ["IL", "PS"])

    def test_antimeridian_parts_are_preserved(self):
        queue = build_queue({"regions": [{
            "id": "fiji", "name": "Fiji", "iso3166_1": ["FJ"],
            "bboxes": [[170,-20,180,-10],[-180,-20,-175,-10]]
        }]})
        self.assertEqual(len(queue[0]["bboxes"]), 2)

    def test_geometry_bounds_split_at_antimeridian(self):
        geometry = {"type": "MultiPolygon", "coordinates": [
            [[[179,-20],[180,-20],[180,-10],[179,-10],[179,-20]]],
            [[[-180,-20],[-179,-20],[-179,-10],[-180,-10],[-180,-20]]],
        ]}
        boxes = _geometry_bboxes(geometry)
        self.assertEqual(len(boxes), 2)
        self.assertEqual(boxes[0][0], 179.0)
        self.assertEqual(boxes[1][0], -180.0)

    def test_missing_country_uses_continent_parent_extract(self):
        import json, tempfile
        from pathlib import Path
        catalog = {"regions": [
            {"id": "asia", "name": "Asia", "pbf_url": "https://example.invalid/asia.osm.pbf"}
        ]}
        feature = {"type": "Feature", "properties": {"ISO_A2": "SA", "ADMIN": "Saudi Arabia"},
                   "geometry": {"type": "Polygon", "coordinates": [[[42,16],[55,16],[55,33],[42,33],[42,16]]]}}
        with tempfile.TemporaryDirectory() as temp:
            ne = Path(temp) / "world.geojson"
            ne.write_text(json.dumps({"type": "FeatureCollection", "features": [feature]}))
            queue = build_queue(catalog, ne)
        self.assertEqual(len(queue), 1)
        self.assertEqual(queue[0]["id"], "asia")
        self.assertEqual(queue[0]["iso3166_1"], ["SA"])
        self.assertEqual(queue[0]["extract_kind"], "supplemental_parent")

    def test_offline_catalogue_has_usable_country_bounds(self):
        catalog = build_offline_catalog(ROOT / "data/world/global_regions.json")
        queue = build_queue(catalog)
        self.assertGreater(len(queue), 100)

if __name__ == "__main__":
    unittest.main()
