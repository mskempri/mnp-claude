"use strict";

const STAGES = ["RECEIVED", "VALIDATING", "APPROVED", "SCHEDULED", "CUTOVER", "COMPLETED"];

const NEXT_ACTIONS = {
  RECEIVED: [{ event: "CANCEL", label: "Cancel request", danger: true }],
  VALIDATING: [{ event: "CANCEL", label: "Cancel request", danger: true }],
  APPROVED: [
    { event: "SCHEDULE", label: "Schedule cutover" },
    { event: "CANCEL", label: "Cancel request", danger: true }
  ],
  SCHEDULED: [
    { event: "TIMER_EXPIRED", context: "CUTOVER_WINDOW", label: "Simulate cutover-window timer expiry" },
    { event: "CANCEL", label: "Cancel request", danger: true }
  ],
  CUTOVER: [{ event: "CUTOVER_COMPLETE", label: "Complete cutover" }]
};

const AUDIENCE_LABEL = {
  DonorNetwork: "Donor network",
  RecipientNetwork: "Recipient network",
  Customer: "Customer",
  Operations: "Operations"
};

const OUTBOX_STATUS_BADGE = {
  Pending: ["badge-warning", "Pending"],
  Claimed: ["badge-info", "Claimed"],
  Published: ["badge-good", "Published"],
  Failed: ["badge-serious", "Failed"],
  DeadLetter: ["badge-critical", "Dead letter"]
};

const REQUEST_STATUS_BADGE = {
  RECEIVED: ["badge-info", "Received"],
  VALIDATING: ["badge-info", "Validating"],
  APPROVED: ["badge-good", "Approved"],
  REJECTED: ["badge-critical", "Rejected"],
  SCHEDULED: ["badge-info", "Scheduled"],
  CUTOVER: ["badge-info", "Cutover"],
  COMPLETED: ["badge-good", "Completed"],
  CANCELLED: ["badge-warning", "Cancelled"]
};

const state = {
  currentRequestId: null,
  logEntries: [],
  logSeq: 0
};

async function apiCall(method, path, body) {
  const id = ++state.logSeq;
  const entry = {
    id,
    method,
    path,
    requestBody: body ?? null,
    startedAt: new Date(),
    status: null,
    durationMs: null,
    responseBody: null,
    errorMessage: null,
    expanded: false
  };
  state.logEntries.unshift(entry);
  if (state.logEntries.length > 50) state.logEntries.pop();
  renderLog();

  const t0 = performance.now();
  try {
    const res = await fetch(path, {
      method,
      headers: body !== undefined ? { "Content-Type": "application/json" } : undefined,
      body: body !== undefined ? JSON.stringify(body) : undefined
    });
    entry.status = res.status;
    entry.durationMs = Math.round(performance.now() - t0);
    const text = await res.text();
    try {
      entry.responseBody = text ? JSON.parse(text) : null;
    } catch {
      entry.responseBody = text;
    }
    renderLog();
    return { ok: res.ok, status: res.status, data: entry.responseBody };
  } catch (err) {
    entry.errorMessage = String(err);
    entry.durationMs = Math.round(performance.now() - t0);
    renderLog();
    return { ok: false, status: 0, data: null, error: err };
  }
}

function statusClassForHttp(status) {
  if (status === 0) return "badge-critical";
  if (status >= 500) return "badge-critical";
  if (status >= 400) return "badge-warning";
  if (status >= 200) return "badge-good";
  return "badge-neutral";
}

function renderLog() {
  const el = document.getElementById("log");
  if (state.logEntries.length === 0) {
    el.innerHTML = '<p class="empty-state" style="padding:12px;">No API calls yet — submit a request or run a lookup to see activity here.</p>';
    return;
  }

  el.innerHTML = state.logEntries
    .map((e) => {
      const time = e.startedAt.toLocaleTimeString();
      const statusBadge =
        e.status === null
          ? '<span class="badge badge-neutral"><span class="dot"></span>…</span>'
          : `<span class="badge ${statusClassForHttp(e.status)}"><span class="dot"></span>${e.status === 0 ? "ERR" : e.status}</span>`;
      const reqJson = e.requestBody !== null ? JSON.stringify(e.requestBody, null, 2) : null;
      const resJson =
        e.responseBody !== null && e.responseBody !== undefined
          ? typeof e.responseBody === "string"
            ? e.responseBody
            : JSON.stringify(e.responseBody, null, 2)
          : e.errorMessage ?? "(empty body)";
      return `
        <div class="log-entry${e.expanded ? " expanded" : ""}" data-id="${e.id}">
          <div class="log-head" onclick="toggleLogEntry(${e.id})">
            ${statusBadge}
            <span class="log-method">${e.method}</span>
            <span class="log-path">${escapeHtml(e.path)}</span>
            <span class="log-time">${time}</span>
            <span class="log-duration">${e.durationMs ?? "…"}${e.durationMs !== null ? "ms" : ""}</span>
          </div>
          <div class="log-body">
            ${reqJson ? `<h4>Request body</h4><pre>${escapeHtml(reqJson)}</pre>` : ""}
            <h4>Response</h4><pre>${escapeHtml(resJson)}</pre>
          </div>
        </div>`;
    })
    .join("");
}

function toggleLogEntry(id) {
  const entry = state.logEntries.find((e) => e.id === id);
  if (entry) entry.expanded = !entry.expanded;
  renderLog();
}
window.toggleLogEntry = toggleLogEntry;

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function renderStepper(status) {
  const isBad = status === "REJECTED" || status === "CANCELLED";
  const currentIndex = isBad || !status ? -1 : STAGES.indexOf(status);

  let html = STAGES.map((stage, i) => {
    let cls = "";
    if (currentIndex >= 0) {
      if (i < currentIndex) cls = "is-done";
      else if (i === currentIndex) cls = "is-current";
    }
    const dot = cls === "is-done" ? "✓" : String(i + 1);
    return `<div class="step ${cls}"><div class="step-dot">${dot}</div><div class="step-label">${stage}</div></div>`;
  }).join("");

  if (isBad) {
    html += `<div class="step is-terminal-bad"><div class="step-dot">✕</div><div class="step-label">${status}</div></div>`;
  }

  document.getElementById("stepper").innerHTML = html;
}

function renderRequestDetail(request) {
  const el = document.getElementById("request-detail");
  if (!request) {
    el.innerHTML = '<p class="empty-state">Submit or load a request to see it here.</p>';
    renderStepper(null);
    return;
  }

  // The API serializes the PortingStatus enum in its C# casing (e.g.
  // "Approved"); this page's lookup tables key off the DB's own
  // ALL_CAPS status codes, so normalize once here.
  const status = request.status.toUpperCase();

  state.currentRequestId = request.id;
  renderStepper(status);

  const [badgeClass, badgeLabel] = REQUEST_STATUS_BADGE[status] ?? ["badge-neutral", status];
  const actions = NEXT_ACTIONS[status] ?? [];

  el.innerHTML = `
    <dl class="kv">
      <dt>ID</dt><dd>#${request.id}</dd>
      <dt>Status</dt><dd><span class="badge ${badgeClass}"><span class="dot"></span>${badgeLabel}</span></dd>
      <dt>MSISDN</dt><dd>${escapeHtml(request.msisdn)}</dd>
      <dt>Donor → Recipient</dt><dd>${escapeHtml(request.donorNetworkCode)} → ${escapeHtml(request.recipientNetworkCode)}</dd>
      <dt>Requested porting date</dt><dd>${escapeHtml(request.requestedPortingDate)}</dd>
      ${request.rejectionReason ? `<dt>Rejection reason</dt><dd>${escapeHtml(request.rejectionReason)}</dd>` : ""}
      <dt>Updated</dt><dd>${new Date(request.updatedAt).toLocaleString()}</dd>
    </dl>
    <div class="btn-row" id="action-buttons">
      <button class="btn" id="refresh-request-btn" type="button">↻ Refresh</button>
      ${actions
        .map(
          (a, i) =>
            `<button class="btn${a.danger ? " btn-danger" : ""}" data-action-index="${i}" type="button">${a.label}</button>`
        )
        .join("")}
    </div>
    ${actions.length === 0 ? '<p class="muted">Terminal status — no further events can be raised.</p>' : ""}
  `;

  document.getElementById("refresh-request-btn").addEventListener("click", () => loadRequest(request.id));
  actions.forEach((a, i) => {
    const btn = el.querySelector(`[data-action-index="${i}"]`);
    btn.addEventListener("click", () => raiseEvent(request.id, a.event, a.context ?? null));
  });
}

async function loadRequest(id) {
  const { ok, data } = await apiCall("GET", `/api/porting-requests/${id}`);
  if (ok) {
    renderRequestDetail(data);
  } else {
    document.getElementById("request-detail").innerHTML =
      `<p class="empty-state">Request #${id} not found.</p>`;
  }
}

async function raiseEvent(id, eventType, context) {
  const { ok, data } = await apiCall("POST", `/api/porting-requests/${id}/events`, {
    eventType,
    context
  });
  if (ok) {
    renderRequestDetail(data);
  } else {
    alert(`Event ${eventType} was rejected by the API (see Activity Log for details). This usually means the current status has no branch for this event.`);
    loadRequest(id);
  }
}

function randomMsisdn(ineligible) {
  const base = "3069" + String(Math.floor(1000000 + Math.random() * 8999999));
  return ineligible ? "+" + base.slice(0, -4) + "0000" : "+" + base;
}

function randomPac() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let out = "";
  for (let i = 0; i < 8; i++) out += chars[Math.floor(Math.random() * chars.length)];
  return out;
}

function toDateInputValue(date) {
  return date.toISOString().slice(0, 10);
}

function fillDemoForm(ineligible) {
  const form = document.getElementById("submit-form");
  form.msisdn.value = randomMsisdn(ineligible);
  form.donorNetworkCode.value = "COSMOTE";
  form.recipientNetworkCode.value = "VODAFONE";
  form.pacCode.value = randomPac();
  form.pacIssuedDate.value = toDateInputValue(new Date());
  const porting = new Date();
  porting.setDate(porting.getDate() + 10);
  form.requestedPortingDate.value = toDateInputValue(porting);
}

async function lookupOwnership(msisdn) {
  const el = document.getElementById("ownership-result");
  const { ok, status, data } = await apiCall("GET", `/api/number-ownership/${encodeURIComponent(msisdn)}`);
  if (ok) {
    el.innerHTML = `
      <dl class="kv">
        <dt>MSISDN</dt><dd>${escapeHtml(data.msisdn)}</dd>
        <dt>Current network</dt><dd>${escapeHtml(data.currentNetworkCode)}</dd>
        <dt>Last ported</dt><dd>${new Date(data.lastPortedAt).toLocaleString()}</dd>
        <dt>Via request</dt><dd>#${data.lastPortingRequestId}</dd>
      </dl>`;
  } else if (status === 404) {
    el.innerHTML = '<p class="empty-state">Not tracked — this MSISDN has never completed a port through this system.</p>';
  } else {
    el.innerHTML = '<p class="empty-state">Lookup failed — see Activity Log.</p>';
  }
}

function renderOutbox(events) {
  const body = document.getElementById("outbox-body");
  if (!events || events.length === 0) {
    body.innerHTML = '<tr><td colspan="8" class="empty-state">No outbox events yet.</td></tr>';
    return;
  }
  body.innerHTML = events
    .map((e) => {
      const [cls, label] = OUTBOX_STATUS_BADGE[e.status] ?? ["badge-neutral", e.status];
      return `<tr>
        <td>${e.id}</td>
        <td>#${e.requestId}</td>
        <td>${escapeHtml(e.eventType)}</td>
        <td>${e.audience ? escapeHtml(AUDIENCE_LABEL[e.audience] ?? e.audience) : '<span class="muted">—</span>'}</td>
        <td><span class="badge ${cls}"><span class="dot"></span>${label}</span></td>
        <td>${e.attemptCount}</td>
        <td>${new Date(e.createdAt).toLocaleTimeString()}</td>
        <td>${e.publishedAt ? new Date(e.publishedAt).toLocaleTimeString() : "—"}</td>
      </tr>`;
    })
    .join("");
}

async function refreshOutbox() {
  const { ok, data } = await apiCall("GET", "/api/outbox?limit=20");
  if (ok) renderOutbox(data);
}

async function checkHealth() {
  const dot = document.getElementById("health-dot");
  const label = document.getElementById("health-label");
  try {
    const res = await fetch("/api/health");
    if (res.ok) {
      dot.className = "health-dot ok";
      label.textContent = "API online";
    } else {
      dot.className = "health-dot down";
      label.textContent = `API error (${res.status})`;
    }
  } catch {
    dot.className = "health-dot down";
    label.textContent = "API unreachable";
  }
}

function initTheme() {
  const saved = localStorage.getItem("mnp-theme");
  if (saved) document.documentElement.setAttribute("data-theme", saved);
  document.getElementById("theme-toggle").addEventListener("click", () => {
    const current = document.documentElement.getAttribute("data-theme");
    const next = current === "dark" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", next);
    localStorage.setItem("mnp-theme", next);
  });
}

function init() {
  renderStepper(null);
  renderLog();
  initTheme();

  document.getElementById("submit-form").addEventListener("submit", async (ev) => {
    ev.preventDefault();
    const form = ev.target;
    const body = {
      msisdn: form.msisdn.value.trim(),
      donorNetworkCode: form.donorNetworkCode.value.trim(),
      recipientNetworkCode: form.recipientNetworkCode.value.trim(),
      requestedPortingDate: form.requestedPortingDate.value,
      pacCode: form.pacCode.value.trim(),
      pacIssuedDate: form.pacIssuedDate.value
    };
    const btn = document.getElementById("submit-btn");
    btn.disabled = true;
    try {
      const { ok, data } = await apiCall("POST", "/api/porting-requests", body);
      if (ok) {
        renderRequestDetail(data);
        document.getElementById("ownership-msisdn").value = data.msisdn;
      } else {
        alert("Submission failed — see Activity Log for the error (common causes: malformed/expired PAC, or 4+ requests for the same MSISDN within 7 days).");
      }
    } finally {
      btn.disabled = false;
    }
  });

  document.getElementById("fill-demo").addEventListener("click", () => fillDemoForm(false));
  document.getElementById("fill-demo-bad").addEventListener("click", () => fillDemoForm(true));

  document.getElementById("load-id-btn").addEventListener("click", () => {
    const id = document.getElementById("load-id").value;
    if (id) loadRequest(id);
  });
  document.getElementById("load-msisdn-btn").addEventListener("click", async () => {
    const msisdn = document.getElementById("load-msisdn").value.trim();
    if (!msisdn) return;
    const { ok, data } = await apiCall("GET", `/api/porting-requests?msisdn=${encodeURIComponent(msisdn)}`);
    if (ok && data.length > 0) {
      renderRequestDetail(data[data.length - 1]);
    } else {
      document.getElementById("request-detail").innerHTML =
        '<p class="empty-state">No requests found for that MSISDN.</p>';
    }
  });

  document.getElementById("ownership-btn").addEventListener("click", () => {
    const msisdn = document.getElementById("ownership-msisdn").value.trim();
    if (msisdn) lookupOwnership(msisdn);
  });

  checkHealth();
  setInterval(checkHealth, 15000);

  refreshOutbox();
  setInterval(() => {
    if (document.getElementById("outbox-auto").checked) refreshOutbox();
  }, 4000);
}

document.addEventListener("DOMContentLoaded", init);
