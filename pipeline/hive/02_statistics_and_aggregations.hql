-- Dataset profile.
SELECT COUNT(*) AS review_rows FROM cleaned_reviews;
SELECT COUNT(DISTINCT product_id) AS reviewed_products FROM cleaned_reviews;
SELECT COUNT(*) AS catalogue_product_rows FROM product_info;
SELECT COUNT(*) AS catalogue_skincare_product_rows FROM product_info WHERE primary_category = 'Skincare';
SELECT COUNT(DISTINCT r.product_id) AS reviewed_skincare_products
FROM cleaned_reviews r
JOIN product_info p ON r.product_id = p.product_id
WHERE p.primary_category = 'Skincare';
SELECT COUNT(DISTINCT brand_name) AS brand_count FROM product_info;
SELECT MIN(submission_time) AS first_review_date, MAX(submission_time) AS last_review_date
FROM cleaned_reviews;

SELECT
  SUM(CASE WHEN primary_category = 'Skincare' AND (ingredients IS NULL OR ingredients = '') THEN 1 ELSE 0 END) AS skincare_products_missing_ingredients,
  SUM(CASE WHEN primary_category = 'Skincare' THEN 1 ELSE 0 END) AS skincare_products
FROM product_info;

-- Duplicate check. A zero result confirms no exact duplicate cleaned review rows.
SELECT COALESCE(SUM(duplicate_rows), 0) AS exact_duplicate_review_rows
FROM (
  SELECT COUNT(*) - 1 AS duplicate_rows
  FROM cleaned_reviews
  GROUP BY rating, is_recommended, helpfulness, total_feedback_count,
    total_neg_feedback_count, total_pos_feedback_count, submission_time,
    review_text, review_title, skin_tone, eye_color, skin_type, hair_color, product_id
  HAVING COUNT(*) > 1
) duplicates;

-- Rating distribution and descriptive statistics.
SELECT rating, COUNT(*) AS review_count
FROM cleaned_reviews
GROUP BY rating
ORDER BY rating;

SELECT
  COUNT(*) AS review_count,
  AVG(rating) AS mean_rating,
  percentile_approx(rating, 0.5) AS median_rating,
  STDDEV_POP(rating) AS rating_stddev,
  VAR_POP(rating) AS rating_variance,
  AVG(is_recommended) AS recommendation_rate,
  AVG(total_feedback_count) AS mean_feedback_count
FROM cleaned_reviews;

-- Rating inflation and review-noise indicators for data-quality discussion.
SELECT
  COUNT(*) AS review_count,
  SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) AS five_star_reviews,
  SUM(CASE WHEN rating >= 4 THEN 1 ELSE 0 END) AS four_or_five_star_reviews,
  SUM(CASE WHEN rating <= 2 THEN 1 ELSE 0 END) AS one_or_two_star_reviews,
  SUM(CASE WHEN is_recommended = 0 AND rating >= 4 THEN 1 ELSE 0 END) AS high_rating_not_recommended_rows,
  SUM(CASE WHEN is_recommended = 1 AND rating <= 2 THEN 1 ELSE 0 END) AS low_rating_recommended_rows
FROM cleaned_reviews;

-- Missingness summary for data quality/veracity.
SELECT 'helpfulness' AS field_name, SUM(CASE WHEN helpfulness IS NULL THEN 1 ELSE 0 END) AS missing_count, COUNT(*) AS total_rows FROM cleaned_reviews
UNION ALL
SELECT 'review_title', SUM(CASE WHEN review_title IS NULL OR review_title = '' THEN 1 ELSE 0 END), COUNT(*) FROM cleaned_reviews
UNION ALL
SELECT 'hair_color', SUM(CASE WHEN hair_color IS NULL OR hair_color = '' THEN 1 ELSE 0 END), COUNT(*) FROM cleaned_reviews
UNION ALL
SELECT 'eye_color', SUM(CASE WHEN eye_color IS NULL OR eye_color = '' THEN 1 ELSE 0 END), COUNT(*) FROM cleaned_reviews
UNION ALL
SELECT 'is_recommended', SUM(CASE WHEN is_recommended IS NULL THEN 1 ELSE 0 END), COUNT(*) FROM cleaned_reviews
UNION ALL
SELECT 'skin_tone', SUM(CASE WHEN skin_tone IS NULL OR skin_tone = '' THEN 1 ELSE 0 END), COUNT(*) FROM cleaned_reviews
UNION ALL
SELECT 'skin_type', SUM(CASE WHEN skin_type IS NULL OR skin_type = '' OR skin_type = 'unknown' THEN 1 ELSE 0 END), COUNT(*) FROM cleaned_reviews;

SELECT skin_type, COUNT(*) AS review_count
FROM cleaned_reviews
GROUP BY skin_type
ORDER BY review_count DESC;

-- Profile-aware aggregation for recommendation-oriented analysis.
SELECT
  r.skin_type,
  p.secondary_category,
  COUNT(*) AS review_count,
  AVG(r.rating) AS mean_rating,
  AVG(r.is_recommended) AS recommendation_rate,
  CASE
    WHEN SUM(r.total_feedback_count) = 0 THEN NULL
    ELSE SUM(r.total_pos_feedback_count) / SUM(r.total_feedback_count)
  END AS positive_feedback_ratio
FROM cleaned_reviews r
JOIN product_info p ON r.product_id = p.product_id
GROUP BY r.skin_type, p.secondary_category
HAVING COUNT(*) >= 100
ORDER BY skin_type, mean_rating DESC;

-- Top products with a simple reliability-adjusted score.
SELECT
  p.product_id,
  p.product_name,
  p.brand_name,
  p.secondary_category,
  COUNT(*) AS review_count,
  AVG(r.rating) AS mean_rating,
  AVG(r.is_recommended) AS recommendation_rate,
  (AVG(r.rating) * LOG10(COUNT(*) + 1)) AS reliability_score
FROM cleaned_reviews r
JOIN product_info p ON r.product_id = p.product_id
GROUP BY p.product_id, p.product_name, p.brand_name, p.secondary_category
HAVING COUNT(*) >= 50
ORDER BY reliability_score DESC
LIMIT 25;

-- Ingredient explainability aggregations.
SELECT ingredient, COUNT(DISTINCT product_id) AS product_count
FROM ingredient_terms
GROUP BY ingredient
ORDER BY product_count DESC
LIMIT 30;

SELECT
  i.ingredient,
  COUNT(DISTINCT i.product_id) AS reviewed_product_count,
  COUNT(*) AS review_count,
  AVG(r.rating) AS mean_review_rating,
  AVG(r.is_recommended) AS recommendation_rate,
  SUM(CASE WHEN r.rating >= 4 THEN 1 ELSE 0 END) AS high_rating_review_count,
  SUM(CASE WHEN r.rating <= 2 THEN 1 ELSE 0 END) AS low_rating_review_count
FROM ingredient_terms i
JOIN cleaned_reviews r ON i.product_id = r.product_id
GROUP BY i.ingredient
HAVING COUNT(*) >= 100
ORDER BY review_count DESC
LIMIT 30;