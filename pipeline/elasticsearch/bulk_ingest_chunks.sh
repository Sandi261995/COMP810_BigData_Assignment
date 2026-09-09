#!/usr/bin/env bash
set -euo pipefail

BULK_FILE="processed/elasticsearch/skincare_reviews_bulk.ndjson"
CHUNK_DIR="processed/elasticsearch/bulk_chunks"
ES_URL="${ES_URL:-http://localhost:9200}"
EXPECTED_COUNT="${EXPECTED_COUNT:-285412}"

mkdir -p "$CHUNK_DIR"
find "$CHUNK_DIR" -type f -name 'chunk_*' -delete

split -l 20000 "$BULK_FILE" "$CHUNK_DIR/chunk_"

for chunk in "$CHUNK_DIR"/chunk_*; do
  line_count="$(wc -l < "$chunk" | tr -d ' ')"
  if [ $((line_count % 2)) -ne 0 ]; then
    echo "Refusing to ingest $chunk because it has an odd number of lines."
    exit 1
  fi

  echo "Ingesting $chunk ($line_count lines)"
  curl -sS -H "Content-Type: application/x-ndjson" \
    -XPOST "$ES_URL/_bulk" \
    --data-binary "@$chunk" \
    > "$chunk.response.json"
done

failed_responses="$(grep -l '"errors":true' "$CHUNK_DIR"/chunk_*.response.json || true)"
if [ -n "$failed_responses" ]; then
  echo "Elasticsearch reported item-level bulk errors in:"
  echo "$failed_responses"
  exit 1
fi

count_response="$(curl -sS "$ES_URL/skincare_reviews/_count")"
echo "$count_response"

actual_count="$(printf '%s\n' "$count_response" | sed -n 's/.*"count":[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
if [ "$actual_count" != "$EXPECTED_COUNT" ]; then
  echo "Expected $EXPECTED_COUNT indexed documents but found $actual_count."
  exit 1
fi

echo "Indexed document count matches expected count: $EXPECTED_COUNT"
