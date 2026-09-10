# COMP810 Assignment Runnable Steps

This project contains a big data pipeline for preparing review data, running Hive analysis, exporting documents for Elasticsearch, ingesting those documents, and generating visual outputs.

## Folder Structure

```text
data/
pipeline/
  elasticsearch/
    01_create_index_and_ingest.http
    02_queries_and_aggregations.http
    bulk_ingest_chunks.sh
  hive/
    Results_from_Hive/
    01_create_tables.hql
    02_statistics_and_aggregations.hql
    03_export_elasticsearch_docs.hql
  python/
    generate_recommendation_heatmap.ipynb
    hive_es_export_to_bulk.py
    prepare_hive_raw_inputs.py
processed/
```

## Prerequisites

Make sure the following tools are available before running the pipeline:

- Python
- Apache Hive
- Elasticsearch
- A REST client or editor extension that can run `.http` files
- Jupyter Notebook, if regenerating the heatmap notebook output

## Runnable Steps

### 1. Prepare Raw Input Files

Run the Python preparation script first. This prepares the raw data from `data/` for the Hive pipeline.

```bash
python pipeline/python/prepare_hive_raw_inputs.py
```

### 2. Create Hive Tables

Run the Hive table creation script.

```bash
hive -f pipeline/hive/01_create_tables.hql
```

### 3. Run Hive Statistics and Aggregations

Run the main Hive analysis script.

```bash
hive -f pipeline/hive/02_statistics_and_aggregations.hql
```

The Hive result files are stored in:

```text
pipeline/hive/Results_from_Hive/
```

### 4. Export Hive Data for Elasticsearch

Run the Hive export script.

```bash
hive -f pipeline/hive/03_export_elasticsearch_docs.hql
```

### 5. Convert Hive Export to Elasticsearch Bulk Format

Run the Python conversion script.

```bash
python pipeline/python/hive_es_export_to_bulk.py
```

### 6. Create Elasticsearch Index and Ingest Data

Use the HTTP requests in:

```text
pipeline/elasticsearch/01_create_index_and_ingest.http
```

Then run the bulk ingest script:

```bash
bash pipeline/elasticsearch/bulk_ingest_chunks.sh
```

### 7. Run Elasticsearch Queries and Aggregations

Use the HTTP requests in:

```text
pipeline/elasticsearch/02_queries_and_aggregations.http
```

These queries support Elasticsearch aggregation and dashboard evidence.

### 8. Generate Recommendation Heatmap

Open and run the notebook:

```text
pipeline/python/generate_recommendation_heatmap.ipynb
```

## Recommended Run Order

```text
1. python pipeline/python/prepare_hive_raw_inputs.py
2. hive -f pipeline/hive/01_create_tables.hql
3. hive -f pipeline/hive/02_statistics_and_aggregations.hql
4. hive -f pipeline/hive/03_export_elasticsearch_docs.hql
5. python pipeline/python/hive_es_export_to_bulk.py
6. Run pipeline/elasticsearch/01_create_index_and_ingest.http
7. Run pipeline/elasticsearch/02_queries_and_aggregations.http
8. bash pipeline/elasticsearch/bulk_ingest_chunks.sh
9. Run pipeline/python/generate_recommendation_heatmap.ipynb
```

## Notes

- Keep the `data/` folder in place before running the pipeline.
- The `processed/` folder is used for generated intermediate files.
- Hive outputs are collected under `pipeline/hive/Results_from_Hive/`.
- The `.http` files are intended to be executed against a running Elasticsearch instance.
