"""Report Lambda — top 3 departments with the most hiring.

Implements the same logic as processingCode/aboveHiringDepartment.py:
  - Fetch raw tables into pandas DataFrames (SQL only for data retrieval)
  - Rename id columns to avoid collision, merge hired_employees + departments + jobs
  - Group by department, count, sort desc, head(3)
  - Merge back with departments to recover id, rename columns
"""

import logging

import pandas as pd

from common import json_response, get_db_connection

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REQUIRED_TABLES = ["departments", "hired_employees"]


def _check_tables(cur):
    """Return a list of required table names that are MISSING."""
    missing = []
    for tbl in REQUIRED_TABLES:
        cur.execute(
            "SELECT EXISTS ("
            "  SELECT FROM information_schema.tables "
            "  WHERE table_schema = 'public' AND table_name = %s"
            ")",
            (tbl,),
        )
        exists = cur.fetchone()[0]
        if not exists:
            missing.append(tbl)
    return missing


def lambda_handler(event, context):
    logger.info("top_departments invoked")

    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # Check that all required tables exist
        missing = _check_tables(cur)
        if missing:
            return json_response(
                200,
                {
                    "warning": (
                        f"Missing table(s): {', '.join(missing)}. "
                        "Upload CSV data for these tables first."
                    ),
                    "data": [],
                    "columns": [],
                },
            )

        # ── Fetch raw tables into pandas DataFrames ──────────────
        cur.execute("SELECT * FROM departments")
        departments_rows = cur.fetchall()
        departments_cols = [desc[0] for desc in cur.description]
        df_departments = pd.DataFrame(
            departments_rows, columns=departments_cols
        )

        cur.execute("SELECT * FROM hired_employees")
        hired_rows = cur.fetchall()
        hired_cols = [desc[0] for desc in cur.description]
        df_hired = pd.DataFrame(hired_rows, columns=hired_cols)

        cur.execute("SELECT * FROM jobs")
        jobs_rows = cur.fetchall()
        jobs_cols = [desc[0] for desc in cur.description]
        df_jobs = pd.DataFrame(jobs_rows, columns=jobs_cols)

        # ── Rename id columns (following processingCode procedure)
        df_departments = df_departments.rename(
            columns={"id": "department_id"}
        )
        df_jobs = df_jobs.rename(columns={"id": "job_id"})

        # ── Merge ───────────────────────────────────────────────
        df = df_hired.merge(df_departments, on="department_id", how="left")
        df = df.merge(df_jobs, on="job_id", how="left")

        # ── Group by department, count, top 3 ───────────────────
        df = (
            df.groupby("department")
            .size()
            .reset_index(name="count")
            .sort_values(by="count", ascending=False)
            .head(3)
        )

        # Cast to string before merging (matching processingCode)
        df_departments["department"] = df_departments["department"].astype(
            str
        )
        df["department"] = df["department"].astype(str)

        # ── Merge back with departments to recover id ───────────
        df = df.merge(df_departments, on="department")

        # ── Rename and select columns ───────────────────────────
        df = df.rename(columns={"department_id": "id", "count": "hired"})
        df = df[["id", "department", "hired"]]

        cols = list(df.columns)
        data = df.to_dict(orient="records")

        return json_response(
            200,
            {
                "data": data,
                "columns": cols,
                "count": len(data),
            },
        )

    except Exception as exc:
        logger.error("top_departments error: %s", exc, exc_info=True)
        return json_response(500, {"error": str(exc)})
    finally:
        if conn:
            conn.close()