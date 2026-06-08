-- ==========================================================================
-- PostgreSQL DDL — CRUD application database and tables
-- Run this against your RDS instance to set up the schema.
-- ==========================================================================

-- Create the database (skip if your RDS instance already has one configured)
-- CREATE DATABASE crud_db;

-- Connect to the database
-- \c crud_db

-- --------------------------------------------------------------------------
-- Departments table
-- CSV columns: id, department
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
    id          INTEGER       PRIMARY KEY,
    department  VARCHAR(255)  NOT NULL
);

-- --------------------------------------------------------------------------
-- Jobs table
-- CSV columns: id, job
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS jobs (
    id   INTEGER       PRIMARY KEY,
    job  VARCHAR(255)  NOT NULL
);

-- --------------------------------------------------------------------------
-- Hired Employees table
-- CSV columns: id, name, datetime, department_id, job_id
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hired_employees (
    id              INTEGER       PRIMARY KEY,
    name            VARCHAR(255)  NOT NULL,
    datetime        TIMESTAMP     NOT NULL,
    department_id   INTEGER       NOT NULL REFERENCES departments(id),
    job_id          INTEGER       NOT NULL REFERENCES jobs(id)
);

-- --------------------------------------------------------------------------
-- Indexes for faster lookups
-- --------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_hired_employees_department_id ON hired_employees(department_id);
CREATE INDEX IF NOT EXISTS idx_hired_employees_job_id        ON hired_employees(job_id);
CREATE INDEX IF NOT EXISTS idx_hired_employees_datetime      ON hired_employees(datetime);
