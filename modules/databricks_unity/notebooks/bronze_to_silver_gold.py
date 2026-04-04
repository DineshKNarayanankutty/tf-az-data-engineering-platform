# Databricks notebook: bronze_to_silver_gold
# Accepts base_parameters from job or ADF activity:
#   env            - deployment environment (dev / staging / prod)
#   catalog        - Unity Catalog catalog name (e.g. dataplatform_dev)
#   storage_account - ADLS Gen2 storage account name

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, current_timestamp, lit, trim, upper
from delta.tables import DeltaTable

# ---------------------------------------------------------------------------
# Parameters
# ---------------------------------------------------------------------------
dbutils.widgets.text("env", "dev")
dbutils.widgets.text("catalog", "dataplatform_dev")
dbutils.widgets.text("storage_account", "")

env             = dbutils.widgets.get("env")
catalog_name    = dbutils.widgets.get("catalog")
storage_account = dbutils.widgets.get("storage_account")

if not storage_account:
    # Fallback: read from Key Vault secret scope if not passed directly
    try:
        storage_account = dbutils.secrets.get(scope="kv-learning-scope", key="storage-account-name")
    except Exception as e:
        raise ValueError(f"storage_account parameter not provided and secret retrieval failed: {e}")

print(f"[INFO] env={env}, catalog={catalog_name}, storage_account={storage_account}")

# ---------------------------------------------------------------------------
# Path helpers (abfss:// via Unity Catalog external locations)
# ---------------------------------------------------------------------------
def layer_path(layer: str, path: str = "") -> str:
    return f"abfss://{layer}@{storage_account}.dfs.core.windows.net/{path}"

bronze_path = layer_path("bronze")
silver_path = layer_path("silver")
gold_path   = layer_path("gold")

# ---------------------------------------------------------------------------
# Stage 1: Bronze → Silver
# Read raw Delta from bronze, apply basic cleansing, write to silver
# ---------------------------------------------------------------------------
print("[INFO] Stage 1: Bronze → Silver")

bronze_table = f"`{catalog_name}`.bronze.transactions"

try:
    df_bronze = spark.read.format("delta").load(f"{bronze_path}transactions/")
except Exception:
    # Fallback: read from Unity Catalog table if external path not available
    df_bronze = spark.table(bronze_table)

print(f"[INFO] Bronze row count: {df_bronze.count()}")

df_silver = (
    df_bronze
    .filter(col("amount").isNotNull() & (col("amount") > 0))
    .withColumn("name_upper", upper(trim(col("name"))))
    .withColumn("processed_at", current_timestamp())
    .withColumn("env", lit(env))
    .dropDuplicates(["id"])
)

# Write to silver as Delta (merge if table exists, overwrite on first run)
silver_output_path = f"{silver_path}transactions/"

if DeltaTable.isDeltaTable(spark, silver_output_path):
    delta_silver = DeltaTable.forPath(spark, silver_output_path)
    (delta_silver.alias("target")
        .merge(df_silver.alias("source"), "target.id = source.id")
        .whenMatchedUpdateAll()
        .whenNotMatchedInsertAll()
        .execute())
    print("[INFO] Silver: merge complete")
else:
    (df_silver.write
        .format("delta")
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .save(silver_output_path))
    print("[INFO] Silver: initial write complete")

print(f"[INFO] Silver row count: {df_silver.count()}")

# ---------------------------------------------------------------------------
# Stage 2: Silver → Gold
# Aggregate to business-level summary
# ---------------------------------------------------------------------------
print("[INFO] Stage 2: Silver → Gold")

df_silver_read = spark.read.format("delta").load(silver_output_path)

df_gold = (
    df_silver_read
    .groupBy("name_upper", "env")
    .agg(
        {"amount": "sum", "id": "count"}
    )
    .withColumnRenamed("sum(amount)", "total_amount")
    .withColumnRenamed("count(id)", "transaction_count")
    .withColumn("aggregated_at", current_timestamp())
)

gold_output_path = f"{gold_path}transactions_summary/"
(df_gold.write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .save(gold_output_path))

print(f"[INFO] Gold row count: {df_gold.count()}")
print("[INFO] Pipeline complete: bronze → silver → gold")
