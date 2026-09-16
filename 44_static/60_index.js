let slides = [];
let slideIndex = 0;

function setActiveTab(tabId) {
   document.querySelectorAll(".tab-button").forEach((button) => button.classList.toggle("active", button.dataset.tab === tabId));
   document.querySelectorAll(".tab-content").forEach((panel) => panel.classList.toggle("active", panel.id === tabId));
   if (tabId === "tab3") loadQpm();
}

function updateSlide() {
   const image = document.getElementById("slideImage");
   const label = document.getElementById("slideLabel");
   if (!slides.length) {
      image.removeAttribute("src");
      image.alt = "No slides found";
      label.textContent = "Page 0 of 0";
      return;
   }
   slideIndex = (slideIndex + slides.length) % slides.length;
   image.src = "/slides/" + encodeURIComponent(slides[slideIndex]);
   label.textContent = `Page ${slideIndex + 1} of ${slides.length}`;
}

async function loadSlides() {
   try {
      const response = await fetch("/api/slides");
      const data = await response.json();
      slides = data.files || [];
      updateSlide();
   } catch (_) {
      document.getElementById("slideLabel").textContent = "Slides are not available";
   }
}

function formatMs(value) { return value == null ? "—" : `${Number(value).toFixed(2)} ms`; }

function renderResults(data) {
   document.getElementById("resultStats").textContent =
      `${data.customer_type} customer (id ${data.customer_id}) · ${data.total_rows.toLocaleString()} rows · ` +
      `round trip ${formatMs(data.elapsed_ms)} · server execution ${formatMs(data.execution_time_ms)}`;

   const body = document.getElementById("resultsBody");
   body.replaceChildren();
   if (!data.sample_rows.length) {
      const row = document.createElement("tr");
      row.innerHTML = '<td colspan="3" class="empty-row">No rows returned.</td>';
      body.appendChild(row);
   } else {
      data.sample_rows.forEach((sample) => {
         const row = document.createElement("tr");
         row.innerHTML = `<td>${sample.id}</td><td>${sample.customer_id}</td><td>${sample.payload}</td>`;
         body.appendChild(row);
      });
   }

   document.getElementById("planText").textContent = data.plan_text;
   setPlanCacheModeDisplay(data.plan_cache_mode);
   updateLastResultCell(data.customer_type, data.plan_cache_mode, { elapsed_ms: data.elapsed_ms, execution_time_ms: data.execution_time_ms });
}

const LAST_RESULT_ELEMENT_IDS = {
   typical: { auto: "lastTypicalAuto", force_custom_plan: "lastTypicalCustom", force_generic_plan: "lastTypicalGeneric" },
   mega: { auto: "lastMegaAuto", force_custom_plan: "lastMegaCustom", force_generic_plan: "lastMegaGeneric" },
};

function updateLastResultCell(customerType, mode, result) {
   const elementId = (LAST_RESULT_ELEMENT_IDS[customerType] || {})[mode];
   if (!elementId) return;
   const element = document.getElementById(elementId);
   element.textContent = result && result.execution_time_ms != null ? formatMs(result.execution_time_ms) : "0.00 ms";
}

function renderLastResults(lastResults) {
   Object.entries(LAST_RESULT_ELEMENT_IDS).forEach(([customerType, modes]) => {
      Object.keys(modes).forEach((mode) => {
         const result = lastResults && lastResults[customerType] ? lastResults[customerType][mode] : null;
         updateLastResultCell(customerType, mode, result);
      });
   });
}

function setPlanCacheModeDisplay(mode) {
   document.getElementById("currentPlanCacheMode").textContent = mode || "—";
   document.querySelectorAll('input[name="planCacheMode"]').forEach((radio) => {
      radio.checked = radio.value === mode;
   });
}

async function runQuery() {
   const selected = document.querySelector('input[name="customerType"]:checked');
   const button = document.getElementById("runQuery");
   button.disabled = true;
   try {
      const response = await fetch("/api/query", {
         method: "POST",
         headers: { "Content-Type": "application/json" },
         body: JSON.stringify({ customer_type: selected ? selected.value : "typical" }),
      });
      const data = await response.json();
      if (data.ok) {
         renderResults(data);
      } else {
         document.getElementById("resultStats").textContent = data.message || "Query failed";
      }
   } catch (_) {
      document.getElementById("resultStats").textContent = "Could not reach the demo service.";
   } finally {
      button.disabled = false;
   }
}

async function changePlanCacheMode(mode) {
   try {
      const response = await fetch("/api/plan_cache_mode", {
         method: "POST",
         headers: { "Content-Type": "application/json" },
         body: JSON.stringify({ mode }),
      });
      const data = await response.json();
      if (data.ok) setPlanCacheModeDisplay(data.plan_cache_mode);
   } catch (_) {
      /* leave display as-is; next query will refresh it */
   }
}

async function refreshState() {
   try {
      const response = await fetch("/api/state", { cache: "no-store" });
      const data = await response.json();
      const badge = document.getElementById("readyBadge");
      const ready = data.setup.ready;
      badge.className = `badge ${ready ? "ready" : "waiting"}`;
      badge.textContent = ready ? "Ready" : "Preparing";
      document.getElementById("runQuery").disabled = !ready;

      if (data.plan_cache_mode) setPlanCacheModeDisplay(data.plan_cache_mode);

      renderLastResults(data.last_results);
      return ready;
   } catch (_) {
      return false;
   }
}

function pill(text, kind) {
   return `<span class="pill ${kind}">${text}</span>`;
}

function renderQpmRow(plan) {
   const needsReview = plan.plan_require_evaluation === "Yes";
   const row = document.createElement("tr");
   if (needsReview) row.className = "needs-review";
   const fastest = plan.plan_min_exec_time === "Yes"
      ? pill("Yes", "yes-good")
      : pill(plan.plan_min_exec_time || "No", "no");
   const review = needsReview ? pill("Yes", "yes-bad") : pill("No", "no");
   row.innerHTML =
      `<td>${plan.plan_summary}</td>` +
      `<td>${plan.calls}</td>` +
      `<td>${formatMs(plan.avg_exec_time)}</td>` +
      `<td>${formatMs(plan.max_exec_time)}</td>` +
      `<td>${formatMs(plan.min_avg_exec_time)}</td>` +
      `<td>${fastest}</td>` +
      `<td>${review}</td>` +
      `<td>${plan.last_used ? new Date(plan.last_used).toLocaleTimeString() : "—"}</td>`;
   return row;
}

async function loadQpm() {
   const status = document.getElementById("qpmStatus");
   const card = document.getElementById("qpmCard");
   try {
      const response = await fetch("/api/qpm", { cache: "no-store" });
      const data = await response.json();
      if (!data.ok) {
         status.textContent = data.message || "Could not load QPM data.";
         card.style.display = "none";
         return;
      }
      if (!data.available) {
         status.textContent =
            "Not available on this cluster yet. Query Plan Management requires " +
            "YugabyteDB v2025.2.3.0 or later (Early Access).";
         card.style.display = "none";
         return;
      }
      if (!data.query_id) {
         status.textContent = "QPM is available, but no query has run yet — visit the Query tab first.";
         card.style.display = "none";
         return;
      }
      if (!data.plans.length) {
         status.textContent = `QPM is tracking query ${data.query_id}, but has no recorded plans yet.`;
         card.style.display = "none";
         return;
      }
      status.textContent = `Tracking query ${data.query_id} — ${data.plans.length} distinct plan(s) recorded.`;
      const body = document.getElementById("qpmBody");
      body.replaceChildren();
      data.plans.forEach((plan) => body.appendChild(renderQpmRow(plan)));
      card.style.display = "";
   } catch (_) {
      status.textContent = "Could not reach the demo service.";
      card.style.display = "none";
   }
}

document.addEventListener("DOMContentLoaded", () => {
   document.querySelectorAll(".tab-button").forEach((button) => button.addEventListener("click", () => setActiveTab(button.dataset.tab)));
   document.getElementById("btnSlideUp").addEventListener("click", () => { slideIndex -= 1; updateSlide(); });
   document.getElementById("btnSlideDown").addEventListener("click", () => { slideIndex += 1; updateSlide(); });
   document.getElementById("runQuery").addEventListener("click", runQuery);
   document.getElementById("refreshQpm").addEventListener("click", loadQpm);
   document.querySelectorAll('input[name="planCacheMode"]').forEach((radio) =>
      radio.addEventListener("change", () => changePlanCacheMode(radio.value))
   );
   loadSlides();

   refreshState().then((ready) => {
      if (ready) return;
      const poll = setInterval(() => {
         refreshState().then((nowReady) => { if (nowReady) clearInterval(poll); });
      }, 1500);
   });
});
