import unittest

import numpy as np
import pandas as pd

try:
    from history_hybrid import (
        apply_hybrid,
        build_pair_rule_index,
        score_association_rules,
        score_svd_history,
    )
except ModuleNotFoundError:
    from KPDL.history_hybrid import (
        apply_hybrid,
        build_pair_rule_index,
        score_association_rules,
        score_svd_history,
    )


class HistoryHybridTest(unittest.TestCase):
    def test_association_rules_require_known_history_and_can_score_pair(self):
        index = build_pair_rule_index(
            [
                ("tour-1", "place-a"),
                ("tour-1", "place-b"),
                ("tour-2", "place-a"),
                ("tour-2", "place-c"),
            ]
        )
        scores, available, reason = score_association_rules(
            ["place-b", "place-c"],
            ["place-a"],
            index,
            {
                "max_support": [0.0, 1.0],
                "max_confidence": [0.0, 1.0],
                "max_lift": [0.0, 2.0],
            },
        )
        self.assertTrue(available)
        self.assertEqual(reason, "pairwise_rules_from_frozen_train_tours")
        self.assertGreater(scores["place-b"], 0.0)

        _, unavailable, unavailable_reason = score_association_rules(
            ["place-b"], ["unknown-place"], index, {
                "max_support": [0.0, 1.0],
                "max_confidence": [0.0, 1.0],
                "max_lift": [0.0, 2.0],
            }
        )
        self.assertFalse(unavailable)
        self.assertEqual(unavailable_reason, "no_history_place_in_rule_source")

        _, empty_available, empty_reason = score_association_rules(
            ["place-b"], [], index, {
                "max_support": [0.0, 1.0],
                "max_confidence": [0.0, 1.0],
                "max_lift": [0.0, 2.0],
            }
        )
        self.assertFalse(empty_available)
        self.assertEqual(empty_reason, "no_history_place_in_rule_source")

    def test_svd_adapter_uses_frozen_item_vectors_only(self):
        scores, available, reason = score_svd_history(
            ["place-b", "place-c"],
            ["place-a"],
            {
                "place-a": np.array([1.0, 0.0]),
                "place-b": np.array([1.0, 0.0]),
                "place-c": np.array([0.0, 1.0]),
            },
        )
        self.assertEqual(reason, "frozen_tour_place_svd_adapter")
        self.assertTrue(available["place-b"])
        self.assertAlmostEqual(scores["place-b"], 1.0)
        self.assertTrue(available["place-c"])
        self.assertAlmostEqual(scores["place-c"], 0.5)

    def test_hybrid_renormalizes_only_available_components(self):
        semantic = pd.DataFrame(
            [
                {
                    "external_id": "place-a",
                    "semantic_score": 0.8,
                    "semantic_coverage": 1.0,
                    "semantic_signal_available": True,
                },
                {
                    "external_id": "place-b",
                    "semantic_score": 0.2,
                    "semantic_coverage": 1.0,
                    "semantic_signal_available": True,
                },
            ]
        )
        result = apply_hybrid(
            semantic,
            {"place-a": 0.0, "place-b": 0.0},
            False,
            {"place-a": 1.0, "place-b": 0.0},
            {"place-a": True, "place-b": False},
            0.11,
            0.88,
            0.01,
        )
        self.assertAlmostEqual(float(result.iloc[0]["hybrid_score"]), 0.8166666667)
        self.assertAlmostEqual(float(result.iloc[1]["hybrid_score"]), 0.2)
        self.assertFalse(bool(result.iloc[1]["svd_available"]))


if __name__ == "__main__":
    unittest.main()
