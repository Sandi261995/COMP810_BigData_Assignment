#!/usr/bin/env python3
"""
Serialise Hive-cleaned Elasticsearch export rows as bulk NDJSON.

Hive/HQL performs the cleaning and join in 03_export_elasticsearch_docs.hql. This
script only reads the exported TSV part files and writes Elasticsearch bulk
action/document pairs.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[2]
EXPORT_DIR = ROOT / "processed" / "elasticsearch" / "hive_export" / "skincare_reviews_docs"
BULK_PATH = ROOT / "processed" / "elasticsearch" / "skincare_reviews_bulk.ndjson"

FIELDS = [
    "review_id",
    "product_id",
    "product_name",
    "brand_name",
    "primary_category",
    "secondary_category",
    "tertiary_category",
    "price_usd",
    "rating",
    "is_recommended",
    "helpfulness",
    "total_feedback_count",
    "total_neg_feedback_count",
    "total_pos_feedback_count",
    "submission_time",
    "review_text",
    "review_title",
    "skin_tone",
    "eye_color",
    "skin_type",
    "hair_color",
]

INTEGER_FIELDS = {
    "review_id",
    "rating",
    "is_recommended",
    "total_feedback_count",
    "total_neg_feedback_count",
    "total_pos_feedback_count",
}
FLOAT_FIELDS = {"price_usd", "helpfulness"}
ZERO_DEFAULT_INTEGER_FIELDS = {
    "total_feedback_count",
    "total_neg_feedback_count",
    "total_pos_feedback_count",
}
NULL_MARKERS = {"", r"\N"}


def parse_int(value: str, default: int | None = None) -> int | None:
    if value in NULL_MARKERS:
        return default
    return int(float(value))


def parse_float(value: str) -> float | None:
    if value in NULL_MARKERS:
        return None
    return float(value)


def part_files() -> Iterable[Path]:
    if not EXPORT_DIR.exists():
        raise FileNotFoundError(f"Hive export directory not found: {EXPORT_DIR}")
    return sorted(path for path in EXPORT_DIR.iterdir() if path.is_file() and not path.name.startswith("_"))


def convert_value(field: str, value: str) -> object:
    if field in INTEGER_FIELDS:
        default = 0 if field in ZERO_DEFAULT_INTEGER_FIELDS else None
        return parse_int(value, default)
    if field in FLOAT_FIELDS:
        return parse_float(value)
    return value if value not in NULL_MARKERS else None


def main() -> None:
    BULK_PATH.parent.mkdir(parents=True, exist_ok=True)
    count = 0

    with BULK_PATH.open("w", encoding="utf-8") as out:
        for path in part_files():
            with path.open(encoding="utf-8") as f:
                for line in f:
                    values = line.rstrip("\n").split("\t")
                    if len(values) != len(FIELDS):
                        continue
                    doc = {
                        field: convert_value(field, value)
                        for field, value in zip(FIELDS, values)
                    }
                    review_id = doc["review_id"]
                    if review_id is None:
                        continue
                    out.write(json.dumps({"index": {"_index": "skincare_reviews", "_id": review_id}}) + "\n")
                    out.write(json.dumps(doc, ensure_ascii=False) + "\n")
                    count += 1

    print(f"Wrote {count:,} Elasticsearch documents to {BULK_PATH}")


if __name__ == "__main__":
    main()
