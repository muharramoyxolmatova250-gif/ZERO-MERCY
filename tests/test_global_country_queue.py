import unittest
from tools.geodata.build_global_country_queue import build_queue

class GlobalCountryQueueTests(unittest.TestCase):
    def test_country_and_combined_extracts(self):
        catalog = {"regions": [
            {"id": "germany", "name": "Germany", "iso3166_1": ["DE"], "bboxes": [[5,47,15,55]]},
            {"id": "israel-and-palestine", "name": "Israel and Palestine",
             "iso3166_1": ["PS","IL"], "bboxes": [[34,29,36,34]]},
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

if __name__ == "__main__":
    unittest.main()
