
DROP TABLE IF EXISTS ingredient_terms;
DROP TABLE IF EXISTS cleaned_reviews;
DROP TABLE IF EXISTS product_info;
DROP TABLE IF EXISTS raw_reviews_staging;
DROP TABLE IF EXISTS raw_product_info_staging;

CREATE EXTERNAL TABLE raw_reviews_staging (
  source_file STRING,
  source_row_number STRING,
  loaded_index STRING,
  unnamed_index STRING,
  rating_raw STRING,
  is_recommended_raw STRING,
  helpfulness_raw STRING,
  total_feedback_count_raw STRING,
  total_neg_feedback_count_raw STRING,
  total_pos_feedback_count_raw STRING,
  submission_time_raw STRING,
  review_text_raw STRING,
  review_title_raw STRING,
  skin_tone_raw STRING,
  eye_color_raw STRING,
  skin_type_raw STRING,
  hair_color_raw STRING,
  product_id_raw STRING,
  product_name_raw STRING,
  brand_name_raw STRING,
  price_usd_raw STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
TBLPROPERTIES ('serialization.null.format' = '');

LOAD DATA INPATH 's3://nso-test-hive/processed/hive/raw_reviews/data.tsv' INTO TABLE raw_reviews_staging;

CREATE EXTERNAL TABLE raw_product_info_staging (
  product_id_raw STRING,
  product_name_raw STRING,
  brand_id_raw STRING,
  brand_name_raw STRING,
  loves_count_raw STRING,
  rating_raw STRING,
  reviews_raw STRING,
  size_raw STRING,
  variation_type_raw STRING,
  variation_value_raw STRING,
  variation_desc_raw STRING,
  ingredients_raw STRING,
  price_usd_raw STRING,
  value_price_usd_raw STRING,
  sale_price_usd_raw STRING,
  limited_edition_raw STRING,
  new_raw STRING,
  online_only_raw STRING,
  out_of_stock_raw STRING,
  sephora_exclusive_raw STRING,
  highlights_raw STRING,
  primary_category_raw STRING,
  secondary_category_raw STRING,
  tertiary_category_raw STRING,
  child_count_raw STRING,
  child_max_price_raw STRING,
  child_min_price_raw STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
TBLPROPERTIES ('serialization.null.format' = '');

LOAD DATA INPATH 's3://nso-test-hive/processed/hive/raw_product_info/data.tsv' INTO TABLE raw_product_info_staging;


CREATE TABLE cleaned_reviews AS
SELECT
  ROW_NUMBER() OVER (
    ORDER BY source_file, CAST(source_row_number AS INT)
  ) AS review_id,
  CAST(CAST(NULLIF(TRIM(rating_raw), '') AS DOUBLE) AS INT) AS rating,
  CAST(CAST(NULLIF(TRIM(is_recommended_raw), '') AS DOUBLE) AS INT) AS is_recommended,
  CAST(NULLIF(TRIM(helpfulness_raw), '') AS DOUBLE) AS helpfulness,
  CAST(CAST(NULLIF(TRIM(total_feedback_count_raw), '') AS DOUBLE) AS INT) AS total_feedback_count,
  CAST(CAST(NULLIF(TRIM(total_neg_feedback_count_raw), '') AS DOUBLE) AS INT) AS total_neg_feedback_count,
  CAST(CAST(NULLIF(TRIM(total_pos_feedback_count_raw), '') AS DOUBLE) AS INT) AS total_pos_feedback_count,
  NULLIF(TRIM(submission_time_raw), '') AS submission_time,
  NULLIF(TRIM(review_text_raw), '') AS review_text,
  NULLIF(TRIM(review_title_raw), '') AS review_title,
  NULLIF(TRIM(skin_tone_raw), '') AS skin_tone,
  NULLIF(TRIM(eye_color_raw), '') AS eye_color,
  COALESCE(NULLIF(LOWER(TRIM(skin_type_raw)), ''), 'unknown') AS skin_type,
  NULLIF(TRIM(hair_color_raw), '') AS hair_color,
  TRIM(product_id_raw) AS product_id
FROM raw_reviews_staging
WHERE product_id_raw IS NOT NULL
  AND TRIM(product_id_raw) <> '';


CREATE TABLE product_info AS
SELECT
  TRIM(product_id_raw) AS product_id,
  NULLIF(TRIM(product_name_raw), '') AS product_name,
  CAST(CAST(NULLIF(TRIM(brand_id_raw), '') AS DOUBLE) AS INT) AS brand_id,
  NULLIF(TRIM(brand_name_raw), '') AS brand_name,
  CAST(CAST(NULLIF(TRIM(loves_count_raw), '') AS DOUBLE) AS INT) AS loves_count,
  CAST(NULLIF(TRIM(rating_raw), '') AS DOUBLE) AS product_rating,
  CAST(CAST(NULLIF(TRIM(reviews_raw), '') AS DOUBLE) AS INT) AS product_review_count,
  NULLIF(TRIM(ingredients_raw), '') AS ingredients,
  CAST(NULLIF(TRIM(price_usd_raw), '') AS DOUBLE) AS price_usd,
  CAST(CAST(NULLIF(TRIM(limited_edition_raw), '') AS DOUBLE) AS INT) AS limited_edition,
  CAST(CAST(NULLIF(TRIM(new_raw), '') AS DOUBLE) AS INT) AS new_flag,
  CAST(CAST(NULLIF(TRIM(online_only_raw), '') AS DOUBLE) AS INT) AS online_only,
  CAST(CAST(NULLIF(TRIM(out_of_stock_raw), '') AS DOUBLE) AS INT) AS out_of_stock,
  CAST(CAST(NULLIF(TRIM(sephora_exclusive_raw), '') AS DOUBLE) AS INT) AS sephora_exclusive,
  NULLIF(TRIM(highlights_raw), '') AS highlights,
  NULLIF(TRIM(primary_category_raw), '') AS primary_category,
  NULLIF(TRIM(secondary_category_raw), '') AS secondary_category,
  NULLIF(TRIM(tertiary_category_raw), '') AS tertiary_category
FROM raw_product_info_staging
WHERE product_id_raw IS NOT NULL
  AND TRIM(product_id_raw) <> '';


CREATE TABLE ingredient_terms AS
SELECT
  product_id,
  brand_name,
  product_name,
  primary_category,
  secondary_category,
  ingredient
FROM (
  SELECT
    p.product_id,
    p.brand_name,
    p.product_name,
    p.primary_category,
    p.secondary_category,
    LOWER(TRIM(REGEXP_REPLACE(ingredient_raw, '[\\[\\]''"]', ''))) AS ingredient
  FROM product_info p
  LATERAL VIEW EXPLODE(SPLIT(p.ingredients, ',')) exploded AS ingredient_raw
  WHERE p.primary_category = 'Skincare'
    AND p.ingredients IS NOT NULL
    AND p.ingredients <> ''
) terms
WHERE ingredient <> '';
