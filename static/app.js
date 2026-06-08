/* =========================================================================
   app.js — Login, token management, and CSV upload logic
   ========================================================================= */

(function () {
  "use strict";

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------
  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => document.querySelectorAll(sel);

  const TOKEN_KEY = "crud_access_token";
  const USER_KEY = "crud_username";

  function apiBase() {
    return (typeof APP_CONFIG !== "undefined" ? APP_CONFIG.API_BASE_URL : "")
      .replace(/\/+$/, "");
  }

  function getToken() {
    return localStorage.getItem(TOKEN_KEY);
  }

  function setToken(token, username) {
    localStorage.setItem(TOKEN_KEY, token);
    if (username) localStorage.setItem(USER_KEY, username);
  }

  function clearToken() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
  }

  function show(el) {
    el.hidden = false;
  }
  function hide(el) {
    el.hidden = true;
  }

  function showAlert(el, message) {
    el.textContent = message;
    show(el);
  }

  // -------------------------------------------------------------------
  // Global loading overlay
  // -------------------------------------------------------------------
  function showOverlay(msg) {
    const overlay = $("#loading-overlay");
    const msgEl = $("#loading-overlay-msg");
    if (overlay) {
      if (msgEl) msgEl.textContent = msg || "Processing...";
      overlay.hidden = false;
    }
  }
  function hideOverlay() {
    const overlay = $("#loading-overlay");
    if (overlay) overlay.hidden = true;
  }

  function setStatus(type, typeClass, message) {
    const el = $(`#status-${type}`);
    if (!el) return;
    el.className = `status ${typeClass}`;
    el.innerHTML = message;
  }

  // -----------------------------------------------------------------------
  // Screen switching
  // -----------------------------------------------------------------------
  function showLogin() {
    console.log("[SimpleCRUD] Showing login screen — user not authenticated");
    show($("#login-screen"));
    hide($("#dashboard-screen"));
    // Clear form fields
    $("#login-form").reset();
    hide($("#login-error"));
    hide($("#reset-section"));
  }

  function showDashboard(username) {
    const user = username || localStorage.getItem(USER_KEY) || "unknown";
    console.log(`[SimpleCRUD] Dashboard shown — authenticated as "${user}"`);
    hide($("#login-screen"));
    show($("#dashboard-screen"));
    $("#user-display").textContent = user;
    // Reset all upload cards
    ["departments", "jobs", "hired_employees"].forEach((t) => {
      $(`#file-${t}`).value = "";
      $(`#name-${t}`).textContent = "No file selected";
      $(`#status-${t}`).textContent = "";
      $(`#status-${t}`).className = "status";
      const btn = $(`.upload-btn[data-type="${t}"]`);
      if (btn) btn.disabled = true;
    });
    // Reset backup / restore status
    ["backup", "restore"].forEach((t) => {
      $(`#${t}-status`).textContent = "";
      $(`#${t}-status`).className = "status";
    });
    $("#backup-btn").disabled = false;
    $("#restore-btn").disabled = false;
  }

  // -----------------------------------------------------------------------
  // Login
  // -----------------------------------------------------------------------
  async function login(username, password) {
    console.log(`[SimpleCRUD] Login attempt for user "${username}"`);
    const loginError = $("#login-error");
    hide(loginError);
    const btn = $("#login-btn");
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Signing in...';

    try {
      const res = await fetch(`${apiBase()}/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password }),
      });

      // Read raw text first so we can log it even if JSON parsing fails
      const rawBody = await res.text();
      let data;
      try {
        data = JSON.parse(rawBody);
      } catch (parseErr) {
        console.error("[SimpleCRUD] Login response is not valid JSON", {
          status: res.status,
          contentType: res.headers.get("content-type"),
          bodyPreview: rawBody.substring(0, 500),
        });
        showAlert(loginError, `Unexpected server response (${res.status})`);
        return;
      }

      console.log(`[SimpleCRUD] Login response status=${res.status}`, data);

      if (!res.ok) {
        // Handle NEW_PASSWORD_REQUIRED challenge
        if (data.requires_new_password) {
          console.log("[SimpleCRUD] NEW_PASSWORD_REQUIRED challenge — showing reset section");
          $("#reset-section").dataset.username = username;
          $("#reset-section").dataset.session = data.session || "";
          show($("#reset-section"));
          hide(loginError);
          return;
        }
        // Gateway responses use "message", Lambda errors use "error" — try both
        const errMsg = data.error || data.message || `HTTP ${res.status}`;
        console.error(`[SimpleCRUD] Login failed: ${errMsg}`, { status: res.status, data });
        showAlert(loginError, errMsg);
        return;
      }

      // API Gateway Cognito authorizer validates the id_token, not access_token
      const authToken = data.id_token || data.access_token;
      if (authToken) {
        console.log("[SimpleCRUD] Login success — id_token stored, switching to dashboard");
        setToken(authToken, username);
        showDashboard(username);
      } else {
        console.error("[SimpleCRUD] Login response missing id_token and access_token", data);
        showAlert(loginError, "No token received from server");
      }
    } catch (err) {
      console.error(`[SimpleCRUD] Login network error: ${err.message}`);
      showAlert(loginError, `Network error: ${err.message}`);
    } finally {
      btn.disabled = false;
      btn.textContent = "Sign In";
    }
  }

  // -----------------------------------------------------------------------
  // Password reset (NEW_PASSWORD_REQUIRED)
  // -----------------------------------------------------------------------
  async function resetPassword(newPassword) {
    console.log("[SimpleCRUD] Password reset attempt");
    const resetError = $("#reset-error");
    hide(resetError);
    const btn = $("#reset-btn");
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Setting password...';

    const username = $("#reset-section").dataset.username;
    const session = $("#reset-section").dataset.session;

    try {
      const res = await fetch(`${apiBase()}/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          username,
          password: $("#password").value,
          new_password: newPassword,
          session,
        }),
      });

      const rawBody = await res.text();
      let data;
      try {
        data = JSON.parse(rawBody);
      } catch (parseErr) {
        console.error("[SimpleCRUD] Password reset response is not valid JSON", {
          status: res.status,
          bodyPreview: rawBody.substring(0, 500),
        });
        showAlert(resetError, `Unexpected server response (${res.status})`);
        return;
      }

      console.log(`[SimpleCRUD] Password reset response status=${res.status}`, data);

      if (!res.ok) {
        const errMsg = data.error || data.message || `HTTP ${res.status}`;
        console.error(`[SimpleCRUD] Password reset failed: ${errMsg}`, { status: res.status, data });
        showAlert(resetError, data.error || "Password reset failed");
        return;
      }

      const authToken = data.id_token || data.access_token;
      if (authToken) {
        console.log("[SimpleCRUD] Password reset success — switching to dashboard");
        setToken(authToken, username);
        showDashboard(username);
      } else {
        console.warn("[SimpleCRUD] Password reset succeeded but no token received");
        showAlert(resetError, "Password set, but no token received. Please sign in again.");
        hide($("#reset-section"));
      }
    } catch (err) {
      console.error(`[SimpleCRUD] Password reset network error: ${err.message}`);
      showAlert(resetError, `Network error: ${err.message}`);
    } finally {
      btn.disabled = false;
      btn.textContent = "Set Password";
    }
  }

  // -----------------------------------------------------------------------
  // CSV Upload
  // -----------------------------------------------------------------------
  async function uploadCSV(type, file) {
    const token = getToken();
    if (!token) {
      console.warn("[SimpleCRUD] Upload aborted — no auth token found");
      showLogin();
      return;
    }

    console.log(`[SimpleCRUD] Upload started — type="${type}", file="${file.name}", size=${file.size} bytes`);
    showOverlay(`Uploading ${type.replace(/_/g, " ")}...`);
    setStatus(type, "loading", '<span class="spinner"></span> Uploading...');
    const btn = $(`.upload-btn[data-type="${type}"]`);
    btn.disabled = true;

    try {
      const csvText = await file.text();

      // Quick client-side row count check
      const lines = csvText.split(/\r?\n/).filter((l) => l.trim() !== "");
      if (lines.length > 1001) {
        // 1 header + 1000 data rows
        const msg = `File has ${lines.length - 1} rows — max is 1 000.`;
        console.error(`[SimpleCRUD] Upload rejected (${type}): ${msg}`);
        setStatus(type, "error", msg);
        btn.disabled = false;
        hideOverlay();
        return;
      }

      console.log(`[SimpleCRUD] Upload sending ${lines.length} lines (incl. header) to /upload/${type}`);
      const res = await fetch(`${apiBase()}/upload/${type}`, {
        method: "POST",
        headers: {
          "Content-Type": "text/csv",
          Authorization: `Bearer ${token}`,
        },
        body: csvText,
      });

      const rawBody = await res.text();
      let data;
      try {
        data = JSON.parse(rawBody);
      } catch (parseErr) {
        console.error(`[SimpleCRUD] Upload response not valid JSON (${type})`, {
          status: res.status,
          bodyPreview: rawBody.substring(0, 500),
        });
        setStatus(type, "error", `Unexpected server response (${res.status})`);
        return;
      }

      console.log(`[SimpleCRUD] Upload response status=${res.status}`, data);

      if (res.status === 401 || res.status === 403) {
        console.warn("[SimpleCRUD] Upload returned 401/403 — clearing token, showing login");
        clearToken();
        showLogin();
        hideOverlay();
        return;
      }

      if (!res.ok) {
        const errMsg = data.error || data.message || `HTTP ${res.status}`;
        console.error(`[SimpleCRUD] Upload failed (${type}): ${errMsg}`, { status: res.status, data });
        setStatus(
          type,
          "error",
          `Error ${res.status}: ${data.error || "Upload failed"}`
        );
      } else {
        console.log(`[SimpleCRUD] Upload success (${type}): ${data.message || "ok"}, rows=${data.rows_processed}`);
        setStatus(
          type,
          "success",
          `${data.message || "Upload successful"}${data.rows_processed != null ? ` (${data.rows_processed} rows)` : ""}`
        );
        // Clear the file input so the same file can be re-uploaded
        $(`#file-${type}`).value = "";
        $(`#name-${type}`).textContent = "No file selected";
      }
    } catch (err) {
      console.error(`[SimpleCRUD] Upload network error (${type}): ${err.message}`);
      setStatus(type, "error", `Network error: ${err.message}`);
    } finally {
      hideOverlay();
      btn.disabled = !($(`#file-${type}`).files.length > 0);
    }
  }

  // -----------------------------------------------------------------------
  // Backup & Restore
  // -----------------------------------------------------------------------
  async function runBackup() {
    const token = getToken();
    if (!token) {
      console.warn("[SimpleCRUD] Backup aborted — no auth token found");
      showLogin();
      return;
    }

    console.log("[SimpleCRUD] Backup started");
    showOverlay("Generating AVRO backup...");
    const btn = $("#backup-btn");
    const status = $("#backup-status");
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Backing up...';
    status.className = "status loading";
    status.innerHTML = '<span class="spinner"></span> Generating AVRO backups...';

    try {
      const res = await fetch(`${apiBase()}/backup`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      });
      const rawBody = await res.text();
      let data;
      try {
        data = JSON.parse(rawBody);
      } catch (parseErr) {
        console.error("[SimpleCRUD] Backup response not valid JSON", { status: res.status, bodyPreview: rawBody.substring(0, 500) });
        status.className = "status error";
        status.textContent = `Unexpected server response (${res.status})`;
        return;
      }
      console.log(`[SimpleCRUD] Backup response status=${res.status}`, data);

      if (res.status === 401 || res.status === 403) {
        console.warn("[SimpleCRUD] Backup returned 401/403 — clearing token, showing login");
        clearToken(); showLogin(); hideOverlay(); return;
      }

      if (!res.ok) {
        const errMsg = data.error || data.message || `HTTP ${res.status}`;
        console.error(`[SimpleCRUD] Backup failed: ${errMsg}`, { status: res.status, data });
        status.className = "status error";
        status.textContent = `Error ${res.status}: ${data.error || "Backup failed"}`;
      } else {
        console.log(`[SimpleCRUD] Backup success — id=${data.backup_id}, tables=`, data.tables);
        let html = `<strong>${data.message}</strong><br>Backup ID: <code>${data.backup_id}</code><ul>`;
        for (const [tbl, info] of Object.entries(data.tables || {})) {
          if (info.status === "backed_up") {
            html += `<li>&#9989; ${tbl}: ${info.rows} rows</li>`;
          } else {
            html += `<li>&#9888; ${tbl}: ${info.reason || info.status}</li>`;
          }
        }
        html += "</ul>";
        status.className = "status success";
        status.innerHTML = html;
      }
    } catch (err) {
      console.error(`[SimpleCRUD] Backup network error: ${err.message}`);
      status.className = "status error";
      status.textContent = `Network error: ${err.message}`;
    } finally {
      hideOverlay();
      btn.disabled = false;
      btn.textContent = "Generate Backup";
    }
  }

  async function runRestore() {
    const token = getToken();
    if (!token) {
      console.warn("[SimpleCRUD] Restore aborted — no auth token found");
      showLogin();
      return;
    }

    if (!confirm("This will DELETE all current data and restore from the latest backup. Continue?")) {
      console.log("[SimpleCRUD] Restore cancelled by user");
      return;
    }

    console.log("[SimpleCRUD] Restore started");
    showOverlay("Restoring from latest backup...");
    const btn = $("#restore-btn");
    const status = $("#restore-status");
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Restoring...';
    status.className = "status loading";
    status.innerHTML = '<span class="spinner"></span> Restoring from latest AVRO backup...';

    try {
      const res = await fetch(`${apiBase()}/restore`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify({}),
      });
      const rawBody = await res.text();
      let data;
      try {
        data = JSON.parse(rawBody);
      } catch (parseErr) {
        console.error("[SimpleCRUD] Restore response not valid JSON", { status: res.status, bodyPreview: rawBody.substring(0, 500) });
        status.className = "status error";
        status.textContent = `Unexpected server response (${res.status})`;
        return;
      }
      console.log(`[SimpleCRUD] Restore response status=${res.status}`, data);

      if (res.status === 401 || res.status === 403) {
        console.warn("[SimpleCRUD] Restore returned 401/403 — clearing token, showing login");
        clearToken(); showLogin(); hideOverlay(); return;
      }

      if (!res.ok) {
        const errMsg = data.error || data.message || `HTTP ${res.status}`;
        console.error(`[SimpleCRUD] Restore failed: ${errMsg}`, { status: res.status, data });
        status.className = "status error";
        status.textContent = `Error ${res.status}: ${data.error || "Restore failed"}`;
      } else {
        console.log(`[SimpleCRUD] Restore success — id=${data.backup_id}, tables=`, data.tables);
        let html = `<strong>${data.message}</strong><br>Backup ID: <code>${data.backup_id}</code><ul>`;
        for (const [tbl, info] of Object.entries(data.tables || {})) {
          if (info.status === "restored") {
            html += `<li>&#9989; ${tbl}: ${info.rows} rows</li>`;
          } else {
            html += `<li>&#9888; ${tbl}: ${info.reason || info.status}</li>`;
          }
        }
        html += "</ul>";
        status.className = "status success";
        status.innerHTML = html;
      }
    } catch (err) {
      console.error(`[SimpleCRUD] Restore network error: ${err.message}`);
      status.className = "status error";
      status.textContent = `Network error: ${err.message}`;
    } finally {
      hideOverlay();
      btn.disabled = false;
      btn.textContent = "Restore Latest Backup";
    }
  }

  // -----------------------------------------------------------------------
  // Token validation — call the API to check whether the stored JWT is
  // still valid. If not, clear it and redirect to login.
  // -----------------------------------------------------------------------
  async function validateStoredToken() {
    const token = getToken();
    if (!token) {
      console.log("[SimpleCRUD] No stored token — showing login");
      return false;
    }

    console.log("[SimpleCRUD] Validating stored token against API", {
      endpoint: `${apiBase()}/items`,
      tokenPreview: token.substring(0, 20) + "…",
    });

    try {
      const res = await fetch(`${apiBase()}/items`, {
        method: "GET",
        headers: { Authorization: `Bearer ${token}` },
      });

      console.log("[SimpleCRUD] Token validation response", {
        status: res.status,
        ok: res.ok,
      });

      // Read and log response body for debugging
      try {
        const bodyText = await res.text();
        console.log("[SimpleCRUD] Token validation response body", {
          preview: bodyText.substring(0, 300),
        });
      } catch (_) {
        console.log("[SimpleCRUD] Could not read token validation response body");
      }

      if (res.ok) {
        console.log("[SimpleCRUD] Token is valid — showing dashboard");
        return true;
      }

      if (res.status === 401 || res.status === 403) {
        console.warn("[SimpleCRUD] Stored token is expired or invalid — clearing", {
          status: res.status,
        });
        clearToken();
        return false;
      }

      // Unexpected status — still assume valid (maybe Lambda error)
      console.warn("[SimpleCRUD] Unexpected status from token validation — assuming token is valid", {
        status: res.status,
      });
      return true;
    } catch (err) {
      // Network error — keep the token and show dashboard; user can
      // re-authenticate when they actually try an operation.
      console.warn("[SimpleCRUD] Network error during token validation — showing dashboard anyway", {
        error: err.message,
      });
      return true;
    }
  }

  // -----------------------------------------------------------------------
  // Event listeners
  // -----------------------------------------------------------------------
  async function init() {
    console.log("[SimpleCRUD] App initializing — checking for existing session…");
    console.log("[SimpleCRUD] Config", {
      apiBase: apiBase(),
      hasToken: !!getToken(),
    });

    // Validate stored token BEFORE showing dashboard
    if (getToken()) {
      const valid = await validateStoredToken();
      if (valid) {
        showDashboard();
      } else {
        showLogin();
      }
    } else {
      console.log("[SimpleCRUD] No stored token — showing login screen");
      showLogin();
    }

    // Login form
    $("#login-form").addEventListener("submit", (e) => {
      e.preventDefault();
      const u = $("#username").value.trim();
      const p = $("#password").value;
      if (u && p) login(u, p);
    });

    // Password reset form
    $("#reset-form").addEventListener("submit", (e) => {
      e.preventDefault();
      const np = $("#new-password").value;
      if (np) resetPassword(np);
    });

    // Logout
    $("#logout-btn").addEventListener("click", () => {
      console.log("[SimpleCRUD] User logged out — clearing token");
      clearToken();
      showLogin();
    });

    // Backup & Restore
    $("#backup-btn").addEventListener("click", runBackup);
    $("#restore-btn").addEventListener("click", runRestore);

    // File inputs — enable/disable upload buttons and show file names
    ["departments", "jobs", "hired_employees"].forEach((type) => {
      const fileInput = $(`#file-${type}`);
      const nameSpan = $(`#name-${type}`);
      const uploadBtn = $(`.upload-btn[data-type="${type}"]`);

      fileInput.addEventListener("change", () => {
        if (fileInput.files.length > 0) {
          const f = fileInput.files[0];
          nameSpan.textContent = f.name;
          uploadBtn.disabled = false;
        } else {
          nameSpan.textContent = "No file selected";
          uploadBtn.disabled = true;
        }
        // Clear previous status
        $(`#status-${type}`).textContent = "";
        $(`#status-${type}`).className = "status";
      });

      uploadBtn.addEventListener("click", () => {
        if (fileInput.files.length > 0) {
          uploadCSV(type, fileInput.files[0]);
        }
      });
    });
  }

  // Boot
  document.addEventListener("DOMContentLoaded", init);
})();
