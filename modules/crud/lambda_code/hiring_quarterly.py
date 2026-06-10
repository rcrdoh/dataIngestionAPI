"""Report Lambda — quarterly hiring counts (2021) by department and job.

Implements the same logic as processingCode/hireJobDepartment.py:
  - Fetch raw tables into pandas DataFrames (SQL only for data retrieval)
  - Merge hired_employees + departments + jobs
  - Extract year/month from datetime, filter for 2021
  - Assign quarter labels (Q1–Q4), pivot counts by department / job
"""

import logging

import pandas as pd

from common import json_response, get_db_connection

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REQUIRED_TABLES = ["departments", "jobs", "hired_employees"]


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
    logger.info("hiring_quarterly invoked")

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

        df_departments = df_departments.rename(columns={"id":"department_id"})
        df_jobs = df_jobs.rename(columns={"id":"job_id"})
        
        # ── Merge (following processingCode procedure) ─────────
        df = df_hired.merge(df_departments, on="department_id", how="left")
        df = df.merge(df_jobs, on="job_id", how="left")

        # ── Extract year / month from datetime ─────────────────
        # PostgreSQL TIMESTAMP → pandas Timestamp → ISO string for splitting
        df["datetime_str"] = df["datetime"].dt.strftime("%Y-%m-%dT%H:%M:%S")
        df["year"] = (
            df["datetime_str"].str.split("T").str[0].str.split("-").str[0]
        )
        df["month"] = (
            df["datetime_str"].str.split("T").str[0].str.split("-").str[1]
        )

        # ── Filter for 2021 ────────────────────────────────────
        df = df[df["year"] == "2021"]

        # ── Assign quarter ─────────────────────────────────────
        df["quarter"] = ""
        df.loc[
            (df["month"] >= "01") & (df["month"] <= "03"), "quarter"
        ] = "Q1"
        df.loc[
            (df["month"] >= "04") & (df["month"] <= "06"), "quarter"
        ] = "Q2"
        df.loc[
            (df["month"] >= "07") & (df["month"] <= "09"), "quarter"
        ] = "Q3"
        df.loc[
            (df["month"] >= "10") & (df["month"] <= "12"), "quarter"
        ] = "Q4"

        # ── Pivot: department × job with quarter counts ────────
        df = df[["department", "job", "quarter"]]
        df_agg = (
            df.groupby(["department", "job", "quarter"])
            .size()
            .unstack(fill_value=0)
            .reset_index()
        )

        # Ensure all four quarter columns exist (even if zero)
        for q in ["Q1", "Q2", "Q3", "Q4"]:
            if q not in df_agg.columns:
                df_agg[q] = 0

        # Reorder columns: department, job, Q1, Q2, Q3, Q4
        df_agg = df_agg[["department", "job", "Q1", "Q2", "Q3", "Q4"]]

        cols = list(df_agg.columns)
        data = df_agg.to_dict(orient="records")

        return json_response(
            200,
            {
                "data": data,
                "columns": cols,
                "count": len(data),
            },
        )

    except Exception as exc:
        logger.error("hiring_quarterly error: %s", exc, exc_info=True)
        return json_response(500, {"error": str(exc)})
    finally:
        if conn:
            conn.close()