(() => {
  "use strict";
  const $ = id => document.getElementById(id);
  const paper = "#fff7e8";
  const inks = ["#263442", "#286ac2", "#d83e43", "#409348", "#efbd23", "#88512d", "#893fcc", paper];
  const widths = [4, 9, 18];
  const eraserWidths = [18, 36, 60];
  const canvas = $("drawing"), context = canvas.getContext("2d");
  let state = null, connected = false, currentInk = 0, brushWidth = 1, eraserWidth = 1, brushInk = 0;
  let strokes = [], version = 0, inkEpoch = -1, activeStroke = null, pointer = null;
  let counter = 0, flushTimer = null, editPending = false, syncPending = false;
  let deadline = 0, lastClock = 0, choiceTurn = -1, guessCooldown = 0;
  let soundCursor = -1, audioReady = false;
  const pending = new Map();
  const sounds = Object.fromEntries(["turn", "correct", "countdown", "time_up", "match"].map(kind => [kind, new Audio("audio/" + kind + ".wav")]));
  function stopSounds() { for (const audio of Object.values(sounds)) { audio.pause(); audio.currentTime = 0; } }
  function canDraw() { return connected && state?.phase === "drawing" && state.viewer === state.drawer && !state.paused && !state.drawing_limit && !editPending; }
  function canGuess() { return connected && state?.phase === "drawing" && state.viewer !== state.drawer && !state.paused && !state.guessed.includes(state.viewer); }
  function send(action, values = {}) {
    if (!state || !connected) return;
    controller.send({ action, revision: state.revision, turn_id: state.turn_id, ...values });
  }
  function sync() {
    if (syncPending || !connected) return;
    syncPending = true;
    controller.send({action:"sync"});
  }
  function draw() {
    context.clearRect(0, 0, 1000, 700);
    context.lineCap = "round"; context.lineJoin = "round";
    const all = strokes.filter(stroke => !pending.has(stroke.id)).concat([...pending.values()]);
    for (const stroke of all) {
      context.globalCompositeOperation = stroke.color === 7 ? "destination-out" : "source-over";
      context.strokeStyle = context.fillStyle = inks[stroke.color];
      const strokeWidth = (stroke.color === 7 ? eraserWidths : widths)[stroke.width];
      context.lineWidth = strokeWidth;
      context.beginPath();
      stroke.points.forEach((point,index) => index ? context.lineTo(point[0],point[1]) : context.moveTo(point[0],point[1]));
      context.stroke();
      if (stroke.points.length === 1) { context.beginPath(); context.arc(...stroke.points[0], strokeWidth / 2, 0, Math.PI * 2); context.fill(); }
    }
    context.globalCompositeOperation = "source-over";
  }
  function cancelStroke(dropPending = false) {
    clearTimeout(flushTimer); flushTimer = null;
    const captured = pointer; pointer = null; activeStroke = null;
    if (captured !== null && canvas.hasPointerCapture?.(captured)) canvas.releasePointerCapture(captured);
    if (dropPending) pending.clear();
  }
  function flush(end = false) {
    clearTimeout(flushTimer); flushTimer = null;
    const stroke = activeStroke;
    if (!stroke || !canDraw()) { cancelStroke(); return; }
    do {
      const points = stroke.unsent.splice(0, 32);
      const final = end && !stroke.unsent.length;
      if (points.length || final) {
        const sequence = ++stroke.sequence;
        send("ink", { epoch: inkEpoch, stroke_id: stroke.id, sequence, color: stroke.color, width: stroke.width, points, end: final });
        stroke.lastSent = sequence;
        if (final) stroke.endSent = true;
      }
    } while (stroke.unsent.length);
    if (end) cancelStroke();
  }
  function appendPoint(event) {
    if (!activeStroke || pointer !== event.pointerId) return;
    const box = canvas.getBoundingClientRect();
    const point = [Math.round(Math.max(0,Math.min(1000,(event.clientX - box.left) / box.width * 1000))), Math.round(Math.max(0,Math.min(700,(event.clientY - box.top) / box.height * 700)))];
    const previous = activeStroke.points.at(-1);
    if (previous && Math.abs(previous[0] - point[0]) + Math.abs(previous[1] - point[1]) < 2) return;
    if (activeStroke.points.length >= 2000) { flush(true); return; }
    activeStroke.points.push(point);
    activeStroke.unsent.push(point);
    draw();
    if (!flushTimer) flushTimer = setTimeout(() => flush(), 50);
  }
  canvas.addEventListener("pointerdown", event => {
    if (!canDraw() || pointer !== null || event.button !== 0) return;
    pointer = event.pointerId;
    activeStroke = {id: Date.now().toString(36) + "-" + (++counter), sequence: -1, lastSent: -1, color: currentInk, width: currentInk === 7 ? eraserWidth : brushWidth, points: [], unsent: [], endSent: false};
    pending.set(activeStroke.id, activeStroke);
    canvas.setPointerCapture(event.pointerId);
    appendPoint(event);
  });
  canvas.addEventListener("pointermove", event => {
    if (event.pointerId !== pointer || !canDraw()) return;
    const samples = event.getCoalescedEvents?.();
    for (const sample of samples?.length ? samples : [event]) appendPoint(sample);
  });
  canvas.addEventListener("pointerup", event => { if (event.pointerId === pointer) { appendPoint(event); flush(true); } });
  for (const kind of ["pointercancel","lostpointercapture"]) canvas.addEventListener(kind, event => { if (event.pointerId === pointer) flush(true); });
  function applyInk(packet) {
    if (!state || packet.turn_id !== state.turn_id || packet.revision !== state.revision || packet.epoch !== inkEpoch) return;
    if (packet.version <= version) return;
    if (packet.version !== version + 1) { sync(); return; }
    let stroke = strokes.find(item => item.id === packet.stroke_id);
    if (!stroke && packet.sequence === 0) { stroke = {id:packet.stroke_id, sequence:-1, color:packet.color, width:packet.width, points:[], end:false}; strokes.push(stroke); }
    if (!stroke || packet.sequence !== stroke.sequence + 1) { sync(); return; }
    stroke.points.push(...packet.points); stroke.sequence = packet.sequence; stroke.end = packet.end;
    version = packet.version;
    const local = pending.get(stroke.id);
    if (packet.end && local?.endSent && packet.sequence >= local.lastSent) pending.delete(stroke.id);
    draw();
  }
  function setClock(remaining) {
    deadline = performance.now() + remaining * 1000;
    lastClock = performance.now();
    renderClock();
  }
  function renderClock() {
    if (!state) return;
    const advancing = connected && !state.paused && state.phase !== "finished";
    const seconds = Math.ceil(Math.max(0, advancing ? (deadline - performance.now()) / 1000 : state.remaining));
    $("timer").textContent = String(Math.floor(seconds / 60)).padStart(2,"0") + ":" + String(seconds % 60).padStart(2,"0");
    const urgent = seconds > 0 && seconds <= 10 && state.phase === "drawing";
    $("timer").classList.toggle("game-danger-text", urgent);
    $("timer").classList.toggle("game-countdown-blink", urgent && connected && !state.paused && !document.hidden);
    $("guess-button").disabled = !canGuess() || performance.now() < guessCooldown;
  }
  function render() {
    if (!state) return;
    document.body.classList.toggle("has-reduced-motion", Boolean(state.reduced_motion));
    const drawer = state.players[state.drawer];
    const drawing = state.phase === "drawing", isDrawer = state.viewer === state.drawer;
	$("guess-input").readOnly = !canGuess();
	document.querySelector(".pictionary-controller").dataset.role = isDrawer ? "drawer" : "guesser";
    let status = state.paused ? "Paused · reconnecting" : state.phase === "choosing" ? (isDrawer ? "Choose a word" : drawer.display_name + " is choosing a word") : state.phase === "reveal" ? "Turn complete" : state.phase === "finished" ? "Match finished" : isDrawer ? "Your turn" : drawer.display_name + " is drawing";
    $("turn-status").textContent = status;
    $("hint").textContent = isDrawer && drawing ? "" : state.hint || "";
    const visible = connected && !document.hidden;
    const revealed = ["reveal","finished"].includes(state.phase);
    $("private-card").hidden = !(isDrawer && visible);
    $("secret").textContent = isDrawer && visible ? drawing ? state.secret || "" : revealed ? state.word || "" : "" : "";
    $("secret").hidden = state.phase === "choosing";
    $("private-heading").textContent = state.phase === "choosing" ? "CHOOSE A WORD" : revealed ? "THE WORD" : "YOUR WORD";
    $("word-choices").hidden = state.phase !== "choosing";
    if (state.phase === "choosing" && isDrawer && choiceTurn !== state.turn_id) {
      choiceTurn = state.turn_id;
      $("word-choices").replaceChildren(...(state.choices || []).map((word,index) => {
        const row = document.createElement("div"); row.className = "game-action-row";
        const button = document.createElement("button"); button.type = "button"; button.className = "game-primary"; button.textContent = word.toUpperCase();
        button.addEventListener("click", () => { if (!state.paused && connected && state.phase === "choosing") { send("choose",{choice:index}); for (const choice of $("word-choices").querySelectorAll("button")) choice.disabled = true; } });
        row.append(button); return row;
      }));
    }
    for (const choice of $("word-choices").querySelectorAll("button")) choice.disabled = state.paused || !connected;
    $("drawing-controls").hidden = !(drawing && isDrawer);
    $("guess-form").hidden = !(drawing && !isDrawer && !state.guessed.includes(state.viewer));
    for (const button of $("drawing-controls").querySelectorAll("button,select")) button.disabled = !canDraw();
    canvas.setAttribute("aria-label", canDraw() ? "Draw here" : "Shared drawing canvas");
    $("board-message").hidden = state.phase === "drawing" || state.phase === "reveal";
    if (state.phase === "choosing") $("board-message").textContent = isDrawer ? "Choose your word above" : "Waiting for " + drawer.display_name;
    if (state.phase === "finished") {
      const names = state.outcome.winners.map(seat => state.players[seat].display_name);
      $("board-message").textContent = state.outcome.draw ? "MATCH DRAW" : names.join(" & ") + (names.length === 1 ? " wins!" : " share the win!");
    }
    let feedback = "";
    let quality = "";
    const own = state.last_guess || [...state.feed].reverse().find(entry => entry.seat === state.viewer);
    if (state.paused) feedback = "Play resumes when everyone reconnects.";
    else if (state.drawing_limit && isDrawer && drawing) feedback = "Canvas limit reached. Undo or Clear to keep drawing.";
    else if (drawing && isDrawer) feedback = "";
    else if (drawing && state.guessed.includes(state.viewer)) { feedback = own ? "You guessed it in " + own.seconds.toFixed(1) + "s!" : "You guessed it!"; quality = "correct"; }
    else if (drawing) {
      if (own) { quality = own.quality; feedback = own.correct ? "You guessed it!" : own.quality === "close" ? "Close! Check the spelling." : "Not the word. Try again."; }
    } else if (state.phase === "finished") {
      const last = (state.guess_results || []).find(entry => entry.seat === state.viewer);
      if (last) { quality = last.quality; feedback = "Your last guess: " + (last.text || "No guess") + (last.correct ? " ✓" : " ×") + " · " + last.seconds.toFixed(1) + "s"; }
    }
    if ($("feedback").textContent !== feedback) $("feedback").textContent = feedback;
    for (const kind of ["correct","close","wrong"]) $("feedback").classList.toggle("game-guess-" + kind, quality === kind);
    renderClock();
  }
  function receive(packet) {
    if (packet.kind === "ink") { applyInk(packet); return; }
    if (packet.kind === "sound") {
      if (packet.sequence <= soundCursor) return;
      soundCursor = packet.sequence;
      if (!state || packet.turn_id !== state.turn_id || document.hidden || (packet.sound === "countdown" && state.phase !== "drawing")) return;
      if (audioReady && connected && !state.paused && sounds[packet.sound]) { sounds[packet.sound].currentTime = 0; sounds[packet.sound].play().catch(() => {}); }
      return;
    }
    if (packet.kind === "clock") {
      if (!state || packet.turn_id !== state.turn_id || packet.revision !== state.revision || packet.phase !== state.phase) return;
      state.remaining = packet.remaining; state.hint = packet.hint; state.paused = packet.paused;
      if (packet.paused || packet.phase !== "drawing") { sounds.countdown.pause(); sounds.countdown.currentTime = 0; }
      $("hint").textContent = state.viewer === state.drawer && state.phase === "drawing" ? "" : packet.hint || "";
      setClock(packet.remaining); return;
    }
    if (packet.viewer < 0 || packet.kind !== "state") return;
    if (state && packet.turn_id < state.turn_id) return;
    const boundary = !state || packet.turn_id !== state.turn_id || packet.epoch !== inkEpoch || packet.revision !== state.revision;
    const wasTurn = state?.turn_id;
    if (boundary || packet.ink_rejected) { cancelStroke(true); editPending = false; }
    state = packet; syncPending = false;
    if (packet.strokes) { strokes = packet.strokes; inkEpoch = packet.epoch; version = packet.drawing_version; draw(); }
    else if (inkEpoch !== packet.epoch) { strokes = []; inkEpoch = packet.epoch; version = packet.drawing_version; draw(); sync(); }
    if (wasTurn !== packet.turn_id) { $("guess-input").value = ""; guessCooldown = 0; }
    if (soundCursor < 0) soundCursor = packet.sound_sequence || 0;
    else soundCursor = Math.max(soundCursor, packet.sound_sequence || 0);
    if (packet.paused || wasTurn !== packet.turn_id) stopSounds();
    else if (packet.phase !== "drawing") { sounds.countdown.pause(); sounds.countdown.currentTime = 0; }
    setClock(packet.remaining); render();
  }
  const controller = new StarGamesController("pictionary", {
    connected(player) { connected = true; soundCursor = -1; $("connection").textContent = "Connected · " + player.display_name; $("connection").classList.add("sr-only"); controller.send({action:"sync"}); },
    disconnected() {
      if (state) state.remaining = Math.max(0,(deadline - performance.now()) / 1000);
      connected = false; cancelStroke(true); editPending = false; syncPending = false;
      stopSounds(); $("connection").textContent = "Reconnecting…"; $("connection").classList.remove("sr-only"); $("secret").textContent = ""; $("private-card").hidden = true;
      render();
    },
    message: receive,
    error(error) { $("connection").classList.remove("sr-only"); $("connection").textContent = error.message; }
  });
  document.addEventListener("pointerdown", () => { audioReady = true; }, {once:true});
  document.addEventListener("keydown", () => { audioReady = true; }, {once:true});
  function updateTools() {
    const names = ["Small", "Medium", "Large"];
    for (const [id, name, size, active] of [["brush-size", "Brush", brushWidth, currentInk !== 7], ["eraser", "Eraser", eraserWidth, currentInk === 7]]) {
      const button = $(id);
      button.dataset.size = names[size].toLowerCase();
      button.setAttribute("aria-pressed", String(active));
      button.setAttribute("aria-label", name + (active ? " size: " : ": ") + names[size] + (active ? ". Tap for " + names[(size + 1) % names.length] + "." : ". Activate " + name.toLowerCase() + "."));
      button.querySelector(".game-brush-dot").style.setProperty("--brush-dot-size", widths[size] + "px");
    }
  }
  $("brush-size").addEventListener("click", () => {
    if (!canDraw()) return;
    if (activeStroke) flush(true);
    if (currentInk !== 7) brushWidth = (brushWidth + 1) % widths.length;
    selectInk(brushInk);
  });
  function selectInk(color) {
    if (!canDraw()) return;
    if (activeStroke) flush(true);
    currentInk = color;
    if (color !== 7) brushInk = color;
    for (const button of document.querySelectorAll("[data-color]")) button.setAttribute("aria-pressed", String(Number(button.dataset.color) === color));
    updateTools();
  }
  for (const button of document.querySelectorAll("[data-color]")) button.addEventListener("click", () => selectInk(Number(button.dataset.color)));
  $("eraser").addEventListener("click", () => {
    if (!canDraw()) return;
    if (activeStroke) flush(true);
    if (currentInk === 7) eraserWidth = (eraserWidth + 1) % eraserWidths.length;
    selectInk(7);
  });
  for (const action of ["undo","clear"]) $(action).addEventListener("click", () => {
    if (!canDraw()) return;
    if (activeStroke) flush(true);
    cancelStroke(true); editPending = true; send(action); render();
  });
  $("guess-form").addEventListener("submit", event => {
    event.preventDefault();
    const guess = $("guess-input").value.trim();
    if (!canGuess() || !guess || performance.now() < guessCooldown) return;
    send("guess",{guess}); $("guess-input").value = ""; guessCooldown = performance.now() + 750; renderClock();
  });
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) { if (activeStroke) flush(true); cancelStroke(true); stopSounds(); $("timer").classList.remove("game-countdown-blink"); $("secret").textContent = ""; $("private-card").hidden = true; }
    else { choiceTurn = -1; sync(); }
  });
  window.addEventListener("pagehide", () => { connected = false; cancelStroke(true); stopSounds(); $("secret").textContent = ""; $("private-card").hidden = true; $("timer").classList.remove("game-countdown-blink"); clearInterval(clockTimer); });
  const clockTimer = setInterval(() => { if (performance.now() - lastClock > 6000 && connected && state && !state.paused && state.phase !== "finished") sync(); renderClock(); }, 200);
  controller.connect();
})();
