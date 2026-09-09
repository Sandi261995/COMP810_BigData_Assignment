USE comp810_skincare;

DROP TABLE IF EXISTS skincare_reviews_es_export;

-- Export one cleaned, joined review document per row for Elasticsearch. Hive is
-- the cleaning authority; the downstream Python step only serialises these rows
-- as Elasticsearch bulk NDJSON.
CREATE TABLE skincare_reviews_es_export AS
SELECT
  r.review_id,
  r.product_id,
  p.product_name,
  p.brand_name,
  p.primary_category,
  p.secondary_category,
  p.tertiary_category,
  p.price_usd,
  r.rating,
  r.is_recommended,
  r.helpfulness,
  r.total_feedback_count,
  r.total_neg_feedback_count,
  r.total_pos_feedback_count,
  r.submission_time,
  r.review_text,
  r.review_title,
  r.skin_tone,
  r.eye_color,
  r.skin_type,
  r.hair_color
FROM cleaned_reviews r
JOIN product_info p ON r.product_id = p.product_id;

SET hiveconf:ES_EXPORT_ROOT=s3://nso-test-hive/processed/export;

INSERT OVERWRITE DIRECTORY '${hiveconf:ES_EXPORT_ROOT}/skincare_reviews_docs'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
SELECT
  review_id,
  product_id,
  product_name,
  brand_name,
  primary_category,
  secondary_category,
  tertiary_category,
  price_usd,
  rating,
  is_recommended,
  helpfulness,
  total_feedback_count,
  total_neg_feedback_count,
  total_pos_feedback_count,
  submission_time,
  review_text,
  review_title,
  skin_tone,
  eye_color,
  skin_type,
  hair_color
FROM skincare_reviews_es_export;
