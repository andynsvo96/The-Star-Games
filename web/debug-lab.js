(() => {
  "use strict";
  const $ = id => document.getElementById(id);
  const frame = $("controller"), stage = $("stage"), device = $("device-frame");
  const params = new URLSearchParams(location.search);
  const dimension = (value, fallback, maximum) => Number.isInteger(Number(value)) && Number(value) >= 200 && Number(value) <= maximum ? Number(value) : fallback;
  let width = dimension(params.get("width"), 390, 1920), height = dimension(params.get("height"), 844, 2160);
  let client = null, currentDocument = null, observer = null, scanTimer = 0;
  let readOnly = false, overrides = [], elements = [], scenarios = [], history = [], historyBytes = 0;
  let queued = [], queueOverflow = false, baseline = null, sequence = 0, nextElementId = 0;
  let elementIds = new WeakMap(), checked = new Set();
  let scrollPositions = new Map(), previewGeneration = 0;
  const MAX_HISTORY = 48, MAX_BYTES = 4 * 1024 * 1024, MAX_PACKET = 256 * 1024;
  const clone = value => JSON.parse(JSON.stringify(value));
  const notice = text => { $("notice").textContent = text; };
  const option = (value, label) => { const item = document.createElement("option"); item.value = value; item.textContent = label; return item; };

  function activity(text) {
    const row = document.createElement("li");
    row.textContent = new Date().toLocaleTimeString() + " · " + text;
    $("activity-list").prepend(row);
    while ($("activity-list").children.length > 80) $("activity-list").lastElementChild.remove();
  }

  function fit() {
    const room = Math.max(0, stage.clientHeight - (readOnly ? $("preview-status").offsetHeight + 18 : 0));
    const scale = Math.min(1, Math.max(0, stage.clientWidth - 12) / width, Math.max(0, room - 12) / height);
    device.style.width = width + "px"; device.style.height = height + "px";
    device.style.top = (room / 2) + "px";
    device.style.transform = `translate(-50%, -50%) scale(${scale})`;
    $("size").textContent = `${width} × ${height} · ${Math.round(scale * 100)}%`;
  }

  function resize() {
    width = dimension($("width").value, width, 1920); height = dimension($("height").value, height, 2160);
    $("width").value = width; $("height").value = height;
    const preset = `${width},${height}`;
    $("device").value = [...$("device").options].some(item => item.value === preset) ? preset : "custom";
    fit();
  }

  function previewMode(value) {
    readOnly = value;
    frame.inert = value;
    $("preview-status").hidden = !value;
    $("hold").setAttribute("aria-pressed", String(value));
    $("hold").textContent = value ? "Return to live" : "Hold view";
    $("restore").disabled = !value;
    fit();
  }

  function beginPreview() {
    if (!readOnly) {
      baseline = history.at(-1)?.payload || null;
      queued = []; queueOverflow = false;
    }
    previewMode(true);
  }

  function restoreElements() {
    previewGeneration++;
    // Restore only properties changed by this tool, preserving unrelated module styles.
    for (const saved of overrides.reverse()) {
      if (!saved.element.isConnected) continue;
      for (const [name, value, priority] of saved.styles) {
        if (value) saved.element.style.setProperty(name, value, priority);
        else saved.element.style.removeProperty(name);
      }
      for (const [name, value] of saved.attributes) {
        if (value === null) saved.element.removeAttribute(name);
        else saved.element.setAttribute(name, value);
      }
    }
    overrides = [];
    for (const [element, position] of scrollPositions) if (element.isConnected) element.scrollTo({left: position.left, top: position.top, behavior: "instant"});
    scrollPositions.clear();
  }

  function returnToLive(render = true) {
    restoreElements();
    const wasReadOnly = readOnly;
    if (render && client && wasReadOnly) {
      // Rebuild the displayed view, then replay held packets in order. Sync also
      // restores games whose protocol uses deltas or whose bounded queue overflowed.
      try {
        if (baseline) client.deliver(clone(baseline));
        if (!queueOverflow) for (const payload of queued) client.deliver(clone(payload));
      } catch (_) { notice("Requesting a fresh host snapshot."); }
      previewMode(false);
      client.sync();
    } else previewMode(false);
    queued = []; baseline = null; queueOverflow = false;
    if (wasReadOnly) activity("Returned to live view");
    scheduleScan();
  }

  function hiddenReason(element) {
    const view = element.ownerDocument.defaultView;
    for (let node = element; node && node !== element.ownerDocument.documentElement; node = node.parentElement) {
      const style = view.getComputedStyle(node);
      if (node.hasAttribute("hidden")) return "hidden attribute";
      if (node.tagName === "DIALOG" && !node.open) return "closed dialog";
      if (style.display === "none") return "display: none";
      if (style.visibility !== "visible") return "visibility: " + style.visibility;
      if (Number(style.opacity) === 0) return "opacity: 0";
      if (style.contentVisibility === "hidden") return "content-visibility: hidden";
    }
    return element.getClientRects().length ? "" : "no rendered bounds / collapsed ancestor";
  }

  function caption(element) {
    const text = element.getAttribute("aria-label") || element.getAttribute("alt") || element.textContent || "";
    return element.tagName.toLowerCase() + (element.id ? "#" + element.id : "") + " " + text.replace(/\s+/g, " ").trim().slice(0, 80);
  }

  function elementKey(element) {
    if (!elementIds.has(element)) elementIds.set(element, String(++nextElementId));
    return elementIds.get(element);
  }

  function selectedElement() { return elements.find(item => item.key === $("element-list").value)?.element; }

  function inspect() {
    const element = selectedElement();
    $("reveal").disabled = $("mark").disabled = !element;
    if (!element) { $("element-info").textContent = "Select an element."; return; }
    const bounds = element.getBoundingClientRect(), style = element.ownerDocument.defaultView.getComputedStyle(element);
    $("element-info").textContent = `${caption(element)}\n${hiddenReason(element) || "Visible"}\nPosition: ${Math.round(bounds.x)}, ${Math.round(bounds.y)}\nSize: ${Math.round(bounds.width)} × ${Math.round(bounds.height)}\nDisplay: ${style.display}\nDisabled: ${Boolean(element.disabled)}\nChecked: ${checked.has(elementKey(element)) ? "yes" : "no"}`;
  }

  function scan() {
    scanTimer = 0;
    const doc = frame.contentDocument;
    if (!doc?.body) return;
    const previous = $("element-list").value, filter = $("filter").value.toLowerCase();
    elements = [...doc.body.querySelectorAll("*")].filter(element => !["SCRIPT", "STYLE", "LINK", "TEMPLATE", "OPTION", "SOURCE"].includes(element.tagName)).slice(0, 5000).map(element => ({element, key: elementKey(element), label: caption(element), hidden: hiddenReason(element)}));
    const visible = elements.filter(item => (!$("hidden-only").checked || item.hidden) && item.label.toLowerCase().includes(filter));
    $("element-list").replaceChildren(...visible.map(item => option(item.key, `${checked.has(item.key) ? "✓ " : ""}${item.hidden ? "[hidden] " : ""}${item.label}`)));
    if (visible.some(item => item.key === previous)) $("element-list").value = previous;
    $("coverage").textContent = `${elements.length} loaded · ${elements.filter(item => item.hidden).length} hidden · ${elements.filter(item => checked.has(item.key)).length} marked checked`;
    inspect();
    scanScenarios();
  }

  function scheduleScan() {
    if (!scanTimer) scanTimer = setTimeout(scan, 250);
  }

  function change(element, styles = {}, attributes = {}) {
    const saved = {element, styles: [], attributes: []};
    for (const [name, value] of Object.entries(styles)) {
      saved.styles.push([name, element.style.getPropertyValue(name), element.style.getPropertyPriority(name)]);
      element.style.setProperty(name, value, "important");
    }
    for (const [name, value] of Object.entries(attributes)) {
      saved.attributes.push([name, element.getAttribute(name)]);
      if (value === null) element.removeAttribute(name); else element.setAttribute(name, value);
    }
    overrides.push(saved);
  }

  function reveal(element) {
    if (!element?.isConnected) return;
    const isolatedPanel = element.tagName === "DIALOG" || element.hasAttribute("hidden") && ["SECTION", "ASIDE", "DIV", "MAIN"].includes(element.tagName);
    beginPreview();
    const view = element.ownerDocument.defaultView;
    const chain = [];
    for (let node = element; node && node !== element.ownerDocument.documentElement; node = node.parentElement) chain.unshift(node);
    for (const node of [...chain, element.ownerDocument.scrollingElement]) if (node && !scrollPositions.has(node)) scrollPositions.set(node, {left: node.scrollLeft, top: node.scrollTop});
    for (const node of chain) {
      const style = view.getComputedStyle(node), styles = {}, attributes = {};
      if (node.hasAttribute("hidden")) attributes.hidden = null;
      if (["DIALOG", "DETAILS"].includes(node.tagName) && !node.open) attributes.open = "";
      if (style.display === "none") styles.display = node.tagName === "SPAN" ? "inline-block" : "block";
      if (style.visibility !== "visible") styles.visibility = "visible";
      if (Number(style.opacity) === 0) styles.opacity = "1";
      if (style.contentVisibility === "hidden") styles["content-visibility"] = "visible";
      if (Object.keys(styles).length || Object.keys(attributes).length) change(node, styles, attributes);
    }
    // A non-modal open attribute avoids close/submit events and game callbacks.
    if (isolatedPanel) change(element, {position: "fixed", inset: "12px 12px auto", width: "auto", height: "auto", transform: "none", margin: "0 auto", "max-width": "calc(100% - 24px)", "max-height": "calc(100% - 24px)", overflow: "auto", "z-index": "2147483646"});
    change(element, {outline: "3px solid #ffbf47", "outline-offset": "2px"});
    element.scrollIntoView({block: "center", inline: "nearest", behavior: "instant"});
    // Shared readers and card layouts refit after becoming visible. Scroll again
    // once those measurements settle, so a previously hidden panel is reachable.
    const generation = previewGeneration;
    requestAnimationFrame(() => requestAnimationFrame(() => {
      if (readOnly && generation === previewGeneration && element.isConnected) element.scrollIntoView({block: "center", inline: "nearest", behavior: "instant"});
    }));
    notice("Visual preview only. Return to live restores visibility and requests current host state.");
    scheduleScan();
  }

  function scanScenarios() {
    const previous = $("scenario-list").value;
    scenarios = [];
    try {
      const registered = client?.scenarios() || [];
      if (Array.isArray(registered)) for (const item of registered.slice(0, 100)) {
        if (item && typeof item.id === "string" && typeof item.label === "string" && (item.payload && typeof item.payload === "object" || Array.isArray(item.selectors))) scenarios.push({...item, key: "module:" + item.id});
      }
    } catch (_) { notice("This game's scenario provider failed. Element inspection is still available."); }
    for (const item of elements) if (item.element.tagName === "DIALOG" || item.element.hasAttribute("hidden") && item.element.children.length) {
      scenarios.push({key: "element:" + item.key, label: caption(item.element), element: item.element, description: "Preview an existing UI element without submitting a game action."});
      if (scenarios.length >= 200) break;
    }
    $("scenario-list").replaceChildren(...scenarios.map(item => option(item.key, item.label)));
    if (scenarios.some(item => item.key === previous)) $("scenario-list").value = previous;
    scenarioInfo();
  }

  function scenarioInfo() {
    const item = scenarios.find(item => item.key === $("scenario-list").value);
    $("scenario-preview").disabled = !item;
    $("scenario-info").textContent = item?.description || (item ? item.label : "No scenarios loaded. Inspect existing elements or register debugScenarios in the game controller.");
  }

  function record(payload) {
    const encoded = JSON.stringify(payload);
    if (encoded === history.at(-1)?.encoded) return;
    const number = ++sequence;
    activity(`State ${number}${Number.isFinite(payload?.revision) ? " · revision " + payload.revision : ""}`);
    if (encoded.length > MAX_PACKET) return;
    history.push({number, payload: JSON.parse(encoded), encoded}); historyBytes += encoded.length;
    while (history.length > MAX_HISTORY || historyBytes > MAX_BYTES) historyBytes -= history.shift().encoded.length;
    const previous = $("snapshot-list").value;
    $("snapshot-list").replaceChildren(...history.slice().reverse().map(item => option(String(item.number), `State ${item.number}${Number.isFinite(item.payload?.revision) ? " · revision " + item.payload.revision : ""}`)));
    if (history.some(item => String(item.number) === previous)) $("snapshot-list").value = previous;
    else $("snapshot-list").selectedIndex = 0;
    snapshotInfo();
  }

  function snapshotInfo() {
    const item = history.find(item => String(item.number) === $("snapshot-list").value);
    $("snapshot-preview").disabled = !item || !client;
    $("snapshot-info").textContent = item ? JSON.stringify(item.payload, null, 2).slice(0, 64000) : "Waiting for game state.";
  }

  function clearHistory() {
    history = []; historyBytes = 0; sequence = 0;
    $("snapshot-list").replaceChildren(); snapshotInfo();
  }

  function attach(adapter) {
    if (adapter.document !== frame.contentDocument) return null;
    returnToLive(false); clearHistory();
    client = adapter;
    $("hold").disabled = false;
    $("connection").textContent = `Game: ${adapter.gameId}`;
    activity("Controller attached: " + adapter.gameId);
    scheduleScan();
    return {
      receive(payload) {
        if (client !== adapter) return true;
        record(payload);
        if (!readOnly) return true;
        if (!queueOverflow) {
          queued.push(clone(payload));
          if (queued.length > MAX_HISTORY || queued.reduce((sum, item) => sum + JSON.stringify(item).length, 0) > MAX_BYTES) { queued = []; queueOverflow = true; }
        }
        return false;
      },
      input(payload) {
        if (client !== adapter) return true;
        const name = typeof payload?.action === "string" ? payload.action.slice(0, 64) : "input";
        activity((readOnly ? "Blocked preview input: " : "Input: ") + name);
        return !readOnly;
      },
      connection(text) { if (client === adapter) { $("connection").textContent = text; activity(text); } }
    };
  }

  // Only the same-origin preview frame can attach; ordinary phones have no bridge.
  window.StarGamesDebugLab = Object.freeze({version: 1, attach});
  frame.addEventListener("load", () => {
    const doc = frame.contentDocument;
    if (!doc) return;
    if (doc !== currentDocument) {
      observer?.disconnect(); clearTimeout(scanTimer); scanTimer = 0;
      returnToLive(false);
      if (client?.document !== doc) { client = null; clearHistory(); $("hold").disabled = true; $("connection").textContent = "Join through the controller below."; }
      currentDocument = doc; checked = new Set(); elementIds = new WeakMap(); nextElementId = 0;
      observer = new MutationObserver(scheduleScan);
      observer.observe(doc.body, {subtree: true, childList: true, attributes: true, attributeFilter: ["hidden", "open", "class", "style", "disabled"]});
      activity("Controller page loaded: " + doc.location.pathname);
      // Block pointer and keyboard events while inspecting, including programmatic clicks.
      for (const event of ["click", "pointerdown", "pointerup", "keydown", "submit"]) doc.addEventListener(event, input => { if (readOnly) { input.preventDefault(); input.stopImmediatePropagation(); } }, true);
    }
    scan();
  });

  $("tools").addEventListener("click", () => { $("inspector").hidden = !$("inspector").hidden; $("tools").setAttribute("aria-expanded", String(!$("inspector").hidden)); fit(); });
  for (const button of document.querySelectorAll("[data-tab]")) button.addEventListener("click", () => {
    for (const tab of document.querySelectorAll("[data-tab]")) tab.setAttribute("aria-pressed", String(tab === button));
    for (const panel of document.querySelectorAll(".tool-panel")) panel.hidden = panel.id !== button.dataset.tab;
    scan();
  });
  $("device").addEventListener("change", () => { if ($("device").value !== "custom") { [$("width").value, $("height").value] = $("device").value.split(","); resize(); } });
  for (const id of ["width", "height"]) $(id).addEventListener("change", resize);
  $("rotate").addEventListener("click", () => { [$("width").value, $("height").value] = [height, width]; resize(); });
  $("reload").addEventListener("click", () => { returnToLive(false); frame.contentWindow.location.reload(); });
  $("hold").addEventListener("click", () => { if (readOnly) returnToLive(); else { beginPreview(); activity("Holding displayed view; host continues"); } });
  $("restore").addEventListener("click", () => returnToLive());
  $("scan").addEventListener("click", scan);
  $("filter").addEventListener("input", scan);
  $("hidden-only").addEventListener("change", scan);
  $("element-list").addEventListener("change", inspect);
  $("mark").addEventListener("click", () => { const element = selectedElement(); if (element) { checked.add(elementKey(element)); scan(); } });
  $("reveal").addEventListener("click", () => { const element = selectedElement(); restoreElements(); reveal(element); });
  $("scenario-list").addEventListener("change", scenarioInfo);
  $("scenario-preview").addEventListener("click", () => {
    const item = scenarios.find(item => item.key === $("scenario-list").value);
    if (!item) return;
    beginPreview(); restoreElements();
    try {
      if (item.payload && client) client.deliver(clone(item.payload));
      if (item.element) reveal(item.element);
      for (const selector of (item.selectors || []).slice(0, 32)) if (typeof selector === "string") for (const element of frame.contentDocument.querySelectorAll(selector)) reveal(element);
      activity("Preview scenario: " + item.label); notice("Read-only scenario. Return to live to restore current host state.");
    } catch (_) { notice("This scenario could not be displayed. Return to live to restore host state."); }
    scheduleScan();
  });
  $("snapshot-list").addEventListener("change", snapshotInfo);
  $("snapshot-preview").addEventListener("click", () => { const item = history.find(item => String(item.number) === $("snapshot-list").value); if (item && client) { beginPreview(); restoreElements(); client.deliver(clone(item.payload)); activity("Preview state " + item.number); } });
  $("clear-snapshots").addEventListener("click", clearHistory);
  $("clear-activity").addEventListener("click", () => $("activity-list").replaceChildren());
  addEventListener("resize", fit);
  new ResizeObserver(fit).observe(stage);
  addEventListener("pagehide", () => { observer?.disconnect(); clearTimeout(scanTimer); returnToLive(false); }, {once: true});
  $("width").value = width; $("height").value = height; resize();
  frame.src = "/";
})();
