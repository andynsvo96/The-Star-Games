(() => {
  "use strict";
  let player = null, state = null, online = false, pending = false;
  let shownState = null;
  const motion = matchMedia("(prefers-reduced-motion: reduce)");
  const drops = new Map();
  let dropUntil = 0, victoryTimer = 0;
  let previewColumn = 3, previewRevision = -1;
  const $ = id => document.getElementById(id);
  const buttons = Array.from({length: 42}, (_, cell) => {
    const button = document.createElement("button");
    button.type = "button";
    button.disabled = true;
    button.addEventListener("click", () => send("move", {column: cell % 7}));
    button.addEventListener("pointerenter", () => preview(cell % 7));
    button.addEventListener("focus", () => preview(cell % 7));
    $("board").append(button);
    return button;
  });
  const columnPreview = document.createElement("div");
  columnPreview.className = "column-preview"; columnPreview.hidden = true;
  columnPreview.setAttribute("aria-hidden", "true");
  const ghost = document.createElement("img"); ghost.alt = "";
  columnPreview.append(ghost); $("board").append(columnPreview);
  const celebration = new StarGamesCelebration($("board"));
  const controller = new StarGamesController("four-in-a-row", {
    connected: identity => {
      player = identity; online = true; state = null; pending = false; shownState = null;
      $("connection").textContent = `Connected as ${player.display_name}`;
      render(); controller.send({action: "sync"});
    },
    disconnected: () => { online = false; $("connection").textContent = "Reconnecting... Play is paused."; render(); },
    error: error => { online = false; $("connection").textContent = error.message; render(); },
    message: payload => { state = payload; pending = false; render(); }
  });
  function send(action, extra = {}) {
    if (!online || !state || pending) return;
    if (state.animating || drops.size) return;
    controller.send({action, revision: state.revision, ...extra});
    pending = true; render();
  }
  function render() {
    const mark = state && player ? state.players.findIndex(p => p.id === player.id) + 1 : 0;
    const winners = state?.winning_cells || [];
    const newRound = state?.round_id !== shownState?.round_id;
    const newWin = winners.length > 0 && (newRound || JSON.stringify(winners) !== JSON.stringify(shownState?.winning_cells || []));
    if (newRound) clearDrops();
    const falling = buttons.map((button, cell) => cell).filter(cell => shownState && !motion.matches && state?.board[cell] && (newRound || !shownState.board[cell]));
    const landingDelay = Math.max(0, dropUntil - performance.now()) + falling.reduce((sum, cell) => sum + dropDuration(cell), 0);
    if (newRound || !winners.length) celebration.clear();
    if (newWin) {
      const segments = (state.winning_lines || []).map(line => [line[0], line[3]].map(cell => [(cell % 7 + .5) / 7, (Math.floor(cell / 7) + .5) / 6]));
      const color = state.outcome === 1 ? "#ff4262" : "#ffcf32";
      const animate = !!shownState && !motion.matches;
      if (landingDelay && animate) victoryTimer = setTimeout(() => celebration.show(segments, "FOUR IN A ROW!", color, true), landingDelay);
      else celebration.show(segments, "FOUR IN A ROW!", color, animate);
    }
    buttons.forEach((button, cell) => {
      const piece = state?.board[cell] || 0;
      const changed = newRound || Number(button.dataset.piece || 0) !== piece;
      if (changed || !state) {
        button.replaceChildren();
        button.dataset.piece = String(piece);
        button.classList.remove("game-win-pulse");
        if (piece) {
          const image = document.createElement("img");
          image.src = `/game/four-in-a-row/art/${piece === 1 ? "red" : "yellow"}.svg`;
          image.alt = "";
          button.append(image);
          if (falling.includes(cell)) dropPiece(image, cell);
        }
      }
      button.classList.toggle("winning-cell", winners.includes(cell));
      if (newWin && shownState && winners.includes(cell)) {
        button.classList.add("game-win-pulse");
        const image = button.querySelector("img");
        image.classList.add("game-piece-win");
        image.style.setProperty("--win-delay", `${landingDelay + winners.indexOf(cell) * 80}ms`);
        button.style.setProperty("--win-delay", `${landingDelay}ms`);
      }
      button.setAttribute("aria-label", `Row ${Math.floor(cell / 7) + 1}, column ${cell % 7 + 1}: ${piece ? ["", "Red", "Yellow"][piece] : "empty"}`);
      button.style.setProperty("--piece", ["var(--accent)", "#ff626b", "#ffcf32"][piece]);
    });
    // Check after queuing all drops, including a computer reply from a snapshot.
    buttons.forEach((button, cell) => {
      button.disabled = !online || pending || !mark || !state || state.animating || drops.size > 0 || state.paused || state.outcome !== 0 || state.turn !== mark || state.board[cell % 7] !== 0;
    });
    renderPreview();
    $("replay").hidden = !state?.outcome;
    $("replay").disabled = !online || pending || !!state?.paused || !!state?.animating || drops.size > 0;
    ["x", "o"].forEach((key, index) => $(`${key}-player`).classList.toggle("is-active-player", online && !!state && !state.paused && !state.outcome && state.turn === index + 1));
    if (!state) return;
    ["x", "o"].forEach((key, index) => {
      $(`${key}-player`).textContent = state.players[index].display_name;
      const score = $(`${key}-score`);
      score.textContent = state.session_wins[index];
      score.style.color = index === 0 ? "#ff6280" : "#ffcf32";
      if (newRound) score.classList.remove("game-piece-win");
      if (newWin && shownState && state.outcome === index + 1) {
        score.style.setProperty("--win-delay", `${landingDelay}ms`);
        score.classList.add("game-piece-win");
      }
    });
    $("scores").replaceChildren(markLabel(1), ` ${state.players[0].display_name} ${state.session_wins[0]} : ${state.session_wins[1]} ${state.players[1].display_name} `, markLabel(2));
    $("status").textContent = state.status;
    if (!state.outcome && !state.paused) {
      // Only replace the final mark token; names stay plain text.
      const suffix = `(${["", "Red", "Yellow"][state.turn]})`;
      if (state.status.endsWith(suffix)) $("status").replaceChildren(state.status.slice(0, -suffix.length), "(", markLabel(state.turn), ")");
    }
    shownState = state;
  }
  function preview(column) {
    if (buttons[column].disabled) return;
    previewColumn = column; renderPreview();
  }
  function renderPreview() {
    if (state?.revision !== previewRevision) {
      previewRevision = state?.revision; previewColumn = 3;
    }
    if (buttons[previewColumn].disabled) {
      previewColumn = [3,2,4,1,5,0,6].find(column => !buttons[column].disabled) ?? 3;
    }
    columnPreview.hidden = buttons[previewColumn].disabled;
    if (columnPreview.hidden) return;
    let target = previewColumn;
    for (let row = 5; row >= 0; row--) {
      if (!state.board[row * 7 + previewColumn]) { target = row * 7 + previewColumn; break; }
    }
    columnPreview.dataset.target = String(target);
    const board = $("board"), origin = board.getBoundingClientRect();
    const top = buttons[previewColumn].getBoundingClientRect(), landing = buttons[target].getBoundingClientRect();
    columnPreview.style.left = `${top.left - origin.left - board.clientLeft}px`;
    columnPreview.style.top = `${top.top - origin.top - board.clientTop}px`;
    columnPreview.style.width = `${top.width}px`;
    columnPreview.style.height = `${buttons[35 + previewColumn].getBoundingClientRect().bottom - top.top}px`;
    ghost.src = `/game/four-in-a-row/art/${state.turn === 1 ? "red" : "yellow"}.svg`;
    ghost.style.top = `${landing.top - top.top}px`;
    ghost.style.height = `${landing.height}px`;
  }
  function markLabel(mark) {
    const span = document.createElement("span");
    span.textContent = ["", "Red", "Yellow"][mark];
    span.style.color = ["", "#c82746", "#a66300"][mark];
    return span;
  }
  function dropDuration(cell) { return 200 * Math.sqrt(Math.floor(cell / 7) + 1) + 140; }
  function dropPiece(image, cell) {
    const now = performance.now(), delay = Math.max(0, dropUntil - now), duration = dropDuration(cell);
    dropUntil = now + delay + duration;
    const top = buttons[cell % 7].getBoundingClientRect();
    const target = buttons[cell].getBoundingClientRect();
    const gap = parseFloat(getComputedStyle($("board")).rowGap) || 0;
    const distance = target.top - top.top + target.height + gap;
    const fallEnd = (duration - 140) / duration;
    // Separate translation from the shared victory scale animation.
    const animation = image.animate([
      {translate: `0 -${distance}px`, opacity: 0, offset: 0},
      {translate: `0 -${distance}px`, opacity: 1, offset: .001, easing: "cubic-bezier(.55,0,1,.45)"},
      {translate: "0 0", opacity: 1, offset: fallEnd, easing: "ease-out"},
      {translate: `0 -${distance * .03}px`, opacity: 1, offset: (duration - 70) / duration, easing: "ease-in"},
      {translate: "0 0", opacity: 1, offset: 1}
    ], {duration, delay, fill: "both"});
    drops.set(image, animation);
    animation.onfinish = () => {
      animation.cancel(); drops.delete(image);
      if (!drops.size) { dropUntil = 0; render(); }
    };
  }
  function clearDrops() {
    drops.forEach(animation => animation.cancel());
    drops.clear(); dropUntil = 0;
    clearTimeout(victoryTimer); victoryTimer = 0;
  }
  motion.addEventListener("change", () => {
    if (!motion.matches) return;
    clearDrops();
    render();
    if (state?.winning_lines?.length) {
      const segments = state.winning_lines.map(line => [line[0], line[3]].map(cell => [(cell % 7 + .5) / 7, (Math.floor(cell / 7) + .5) / 6]));
      celebration.show(segments, "FOUR IN A ROW!", state.outcome === 1 ? "#ff4262" : "#ffcf32", false);
    }
  });
  window.addEventListener("pagehide", clearDrops);
  // Orientation changes settle current discs into the newly laid-out board.
  window.addEventListener("resize", () => {
    drops.forEach(animation => animation.finish());
    dropUntil = 0;
  });
  window.addEventListener("gameboardresize", () => {
    drops.forEach(animation => animation.finish());
    dropUntil = 0;
    renderPreview();
  });
  $("replay").addEventListener("click", () => send("play_again"));
  controller.connect();
})();
