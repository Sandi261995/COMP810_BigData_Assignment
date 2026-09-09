#!/usr/bin/env python3
"""
Prepare raw, load-safe TSV files for Hive.

This script does not perform analytical cleaning. It only uses Python's CSV
parser to preserve quoted fields and convert the raw CSV files into tab-delimited
text that Hive can load reliably. Cleaning decisions such as dropping index
columns, casting types, handling missing values, and creating joined analysis
tables are performed in HQL.
"""

from __future__ import annotations

import csv
import glob
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data"
HIVE_DIR = ROOT / "processed" / "hive"

RAW_REVIEW_COLUMNS = [
    "source_file",
    "source_row_number",
    "loaded_index",
    "unnamed_index",
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
    "product_id",
    "product_name",
    "brand_name",
    "price_usd",
]

RAW_PRODUCT_COLUMNS = [
    "product_id",
    "product_name",
    "brand_id",
    "brand_name",
    "loves_count",
    "rating",
    "reviews",
    "size",
    "variation_type",
    "variation_value",
    "variation_desc",
    "ingredients",
    "price_usd",
    "value_price_usd",
    "sale_price_usd",
    "limited_edition",
    "new",
    "online_only",
    "out_of_stock",
    "sephora_exclusive",
    "highlights",
    "primary_category",
    "secondary_category",
    "tertiary_category",
    "child_count",
    "child_max_price",
    "child_min_price",
]


def load_safe(value: object) -> str:
    if value is None:
        return ""
    return str(value).replace("\t", " ").replace("\r", " ").replace("\n", " ").strip()


def write_row(handle, values: list[object]) -> None:
    handle.write("\t".join(load_safe(value) for value in values) + "\n")


def create_raw_reviews() -> int:
    out_path = HIVE_DIR / "raw_reviews" / "data.tsv"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    row_count = 0

    with out_path.open("w", encoding="utf-8", newline="") as out:
        for path_text in sorted(glob.glob(str(DATA_DIR / "reviews_*_masked.csv"))):
            path = Path(path_text)
            with path.open(newline="", encoding="utf-8-sig") as f:
                reader = csv.DictReader(f)
                for source_row_number, row in enumerate(reader, start=1):
                    write_row(
                        out,
                        [
                            path.name,
                            source_row_number,
                            row.get(""),
                            row.get("Unnamed: 0"),
                            row.get("rating"),
                            row.get("is_recommended"),
                            row.get("helpfulness"),
                            row.get("total_feedback_count"),
                            row.get("total_neg_feedback_count"),
                            row.get("total_pos_feedback_count"),
                            row.get("submission_time"),
                            row.get("review_text"),
                            row.get("review_title"),
                            row.get("skin_tone"),
                            row.get("eye_color"),
                            row.get("skin_type"),
                            row.get("hair_color"),
                            row.get("product_id"),
                            row.get("product_name"),
                            row.get("brand_name"),
                            row.get("price_usd"),
                        ],
                    )
                    row_count += 1

    return row_count


def create_raw_product_info() -> int:
    out_path = HIVE_DIR / "raw_product_info" / "data.tsv"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    row_count = 0

    with (DATA_DIR / "product_info.csv").open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        with out_path.open("w", encoding="utf-8", newline="") as out:
            for row in reader:
                write_row(out, [row.get(column) for column in RAW_PRODUCT_COLUMNS])
                row_count += 1

    return row_count


def main() -> None:
    review_count = create_raw_reviews()
    product_count = create_raw_product_info()
    print(f"Wrote {review_count:,} raw review rows to {HIVE_DIR / 'raw_reviews' / 'data.tsv'}")
    print(f"Wrote {product_count:,} raw product rows to {HIVE_DIR / 'raw_product_info' / 'data.tsv'}")


if __name__ == "__main__":
    main()
