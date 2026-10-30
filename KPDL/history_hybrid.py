"""Runtime adapters for the frozen v15 Tour x Place artifact.

These helpers do not retrain a model. Association Rules are derived from the
positive training-tour baskets and SVD uses the stored Tour x Place item
embeddings. The caller must report both availability and provenance because
neither component is a User x Place model.
"""

from __future__ import annotations

from collections import Counter
from itertools import combinations
from typing import Any, Mapping, Sequence

import numpy as np


def build_pair_rule_index(rows: Sequence[tuple[str, str]]) -> dict[str, Any]:
    """Build deterministic pairwise rules from (tour, external_id) positives."""
    baskets: dict[str, set[str]] = {}
    for tour_id, external_id in rows:
        tour = str(tour_id).strip()
        item = str(external_id).strip()
        if tour and item:
            baskets.setdefault(tour, set()).add(item)

    item_counts: Counter[str] = Counter()
    pair_counts: Counter[tuple[str, str]] = Counter()
    for basket in baskets.values():
        item_counts.update(basket)
        for left, right in combinations(sorted(basket), 2):
            pair_counts[(left, right)] += 1
            pair_counts[(right, left)] += 1

    return {
        "transaction_count": len(baskets),
        "item_counts": dict(item_counts),
        "pair_counts": {"\u001f".join(key): value for key, value in pair_counts.items()},
    }


def _pair_count(index: Mapping[str, Any], left: str, right: str) -> int:
    return int(index.get("pair_counts", {}).get(f"{left}\u001f{right}", 0))


def _minmax(value: float, bounds: Sequence[float]) -> float:
    low, high = float(bounds[0]), float(bounds[1])
    if high <= low:
        return 0.0
    return float(np.clip((value - low) / (high - low), 0.0, 1.0))


def score_association_rules(
    candidate_ids: Sequence[str],
    history_ids: Sequence[str],
    rule_index: Mapping[str, Any] | None,
    rule_stats: Mapping[str, Sequence[float]] | None,
) -> tuple[dict[str, float], bool, str]:
    """Score candidates from pairwise rules and return query availability.

    The v15 trainer marks Association Rules available for the whole query when
    any candidate has a matching rule. This adapter follows that behavior, but
    each candidate still receives zero when no rule points to it.
    """
    scores = {str(candidate): 0.0 for candidate in candidate_ids}
    if not rule_index or not rule_stats:
        return scores, False, "association_rule_source_unavailable"

    total = int(rule_index.get("transaction_count", 0))
    item_counts = rule_index.get("item_counts", {})
    if total <= 0:
        return scores, False, "association_rule_source_empty"

    history = list(dict.fromkeys(str(value).strip() for value in history_ids if str(value).strip()))
    known_history = [value for value in history if int(item_counts.get(value, 0)) > 0]
    if not known_history:
        return scores, False, "no_history_place_in_rule_source"

    any_signal = False
    for candidate in scores:
        best = 0.0
        for previous in known_history:
            co_count = _pair_count(rule_index, previous, candidate)
            previous_count = int(item_counts.get(previous, 0))
            candidate_count = int(item_counts.get(candidate, 0))
            if co_count <= 0 or previous_count <= 0 or candidate_count <= 0:
                continue
            support = co_count / total
            confidence = co_count / previous_count
            candidate_support = candidate_count / total
            lift = confidence / candidate_support if candidate_support > 0 else 0.0
            score = (
                0.20 * _minmax(support, rule_stats["max_support"])
                + 0.35 * _minmax(confidence, rule_stats["max_confidence"])
                + 0.25 * _minmax(lift, rule_stats["max_lift"])
                + 0.20
            )
            best = max(best, float(np.clip(score, 0.0, 1.0)))
        scores[candidate] = best
        any_signal = any_signal or best > 0.0

    if not any_signal:
        return scores, False, "no_matching_place_rule"
    return scores, True, "pairwise_rules_from_frozen_train_tours"


def score_svd_history(
    candidate_ids: Sequence[str],
    history_ids: Sequence[str],
    item_embeddings: Mapping[str, Any] | None,
) -> tuple[dict[str, float], dict[str, bool], str]:
    """Score a user history against frozen Tour x Place item embeddings."""
    scores = {str(candidate): 0.0 for candidate in candidate_ids}
    available = {str(candidate): False for candidate in candidate_ids}
    if not item_embeddings:
        return scores, available, "svd_artifact_unavailable"

    vectors = []
    for value in dict.fromkeys(str(item).strip() for item in history_ids if str(item).strip()):
        vector = item_embeddings.get(value)
        if vector is not None:
            array = np.asarray(vector, dtype=float)
            if array.ndim == 1 and np.linalg.norm(array) > 0:
                vectors.append(array)
    if not vectors:
        return scores, available, "no_history_place_in_svd_artifact"

    profile = np.mean(vectors, axis=0)
    profile_norm = float(np.linalg.norm(profile))
    if profile_norm <= 0:
        return scores, available, "history_profile_zero"

    matched = 0
    for candidate in scores:
        vector = item_embeddings.get(candidate)
        if vector is None:
            continue
        array = np.asarray(vector, dtype=float)
        denominator = float(np.linalg.norm(array) * profile_norm)
        if array.ndim != 1 or denominator <= 0:
            continue
        cosine = float(array @ profile / denominator)
        scores[candidate] = float(np.clip((cosine + 1.0) / 2.0, 0.0, 1.0))
        available[candidate] = True
        matched += 1

    if matched == 0:
        return scores, available, "no_candidate_vector_in_svd_artifact"
    return scores, available, "frozen_tour_place_svd_adapter"


def apply_hybrid(
    scores,
    association_scores: Mapping[str, float],
    association_available: bool,
    svd_scores: Mapping[str, float],
    svd_available: Mapping[str, bool],
    content_weight: float,
    association_weight: float,
    svd_weight: float,
):
    """Apply v15 availability-aware Hybrid without inventing missing signals."""
    output = scores.copy()
    output["association_rule_score"] = output["external_id"].map(association_scores).fillna(0.0)
    output["association_rule_available"] = bool(association_available)
    output["svd_score"] = output["external_id"].map(svd_scores).fillna(0.0)
    output["svd_available"] = output["external_id"].map(svd_available).fillna(False).astype(bool)
    content = output["semantic_score"].astype(float).fillna(0.0).clip(0.0, 1.0)
    coverage = output["semantic_coverage"].astype(float).fillna(0.0).clip(0.0, 1.0)
    content_available = output["semantic_signal_available"].astype(bool)
    effective_content_weight = content_weight * coverage * content_available.astype(float)
    denominator = (
        association_weight * association_available
        + svd_weight * output["svd_available"].astype(float)
        + effective_content_weight
    )
    numerator = (
        association_weight * output["association_rule_score"] * association_available
        + svd_weight * output["svd_score"] * output["svd_available"].astype(float)
        + content_weight * content * coverage * content_available.astype(float)
    )
    output["hybrid_available_weight"] = denominator
    output["hybrid_score"] = np.divide(
        numerator,
        denominator,
        out=np.zeros(len(output), dtype=float),
        where=denominator > 0,
    ).clip(0.0, 1.0)
    return output.sort_values(
        ["hybrid_score", "external_id"],
        ascending=[False, True],
        kind="stable",
    ).reset_index(drop=True)
