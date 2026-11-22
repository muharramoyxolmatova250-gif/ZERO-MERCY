import unittest, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.geodata.select_global_country_batch import select_batch
from tools.geodata.advance_global_country_batch import advance_state

class GlobalBuildStateTests(unittest.TestCase):
    def test_batch_progresses_and_moves_to_next_country(self):
        queue = {"countries": [{"id": "country_a"}, {"id": "country_b"}]}
        state = {"current_region_id": None, "next_tile_by_region": {}, "completed_regions": []}
        first = select_batch(queue, state, tile_count=2)
        self.assertEqual((first["region_id"], first["tile_start"]), ("country_a", 0))
        state = advance_state(state, "country_a", 0, 2, 5)
        next_a = select_batch(queue, state, tile_count=2)
        self.assertEqual((next_a["region_id"], next_a["tile_start"]), ("country_a", 2))
        state = advance_state(state, "country_a", 2, 3, 5)
        next_b = select_batch(queue, state, tile_count=2)
        self.assertEqual((next_b["region_id"], next_b["tile_start"]), ("country_b", 0))

    def test_finished_queue_returns_no_work(self):
        queue = {"countries": [{"id": "country_a"}]}
        state = {"current_region_id": None, "next_tile_by_region": {}, "completed_regions": ["country_a"]}
        self.assertFalse(select_batch(queue, state)["has_work"])

if __name__ == "__main__":
    unittest.main()
