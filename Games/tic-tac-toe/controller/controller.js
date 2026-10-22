(() => {
  "use strict";
  let player = null, state = null, online = false, pending = false;
  let shownState = null;
  const $ = id => document.getElementById(id);
  const buttons = Array.from({length: 9}, (_, cell) => {
    const button = document.createElement("button");
    button.type = "button";
    button.disabled = true;
    button.addEventListener("click", () => send("move", {cell}));
    $("board").append(button);
    return button;
  });
  const celebration = new StarGamesCelebration($("board"));
  const controller = new StarGamesController("tic-tac-toe", {
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
    controller.send({action, revision: state.revision, ...extra});
    pending = true; render();
  }
  function render() {
    const mark = state && player ? state.players.findIndex(p => p.id === player.id) + 1 : 0;
    const winners = state?.winning_cells || [];
    const newRound = state?.round_id !== shownState?.round_id;
    const newWin = winners.length > 0 && (newRound || JSON.stringify(winners) !== JSON.stringify(shownState?.winning_cells || []));
    if (newRound || !winners.length) celebration.clear();
    if (newWin) {
      const segments = (state.winning_lines || []).map(line => [line[0], line[2]].map(cell => [(cell % 3 + .5) / 3, (Math.floor(cell / 3) + .5) / 3]));
      celebration.show(segments, "THREE IN A ROW!", state.outcome === 1 ? "#ff4262" : "#00b9ef", !!shownState && !matchMedia("(prefers-reduced-motion: reduce)").matches);
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
          image.src = `/game/tic-tac-toe/art/${piece === 1 ? "x" : "o"}.svg`;
          image.alt = "";
          if (shownState) image.classList.add("game-piece-pop");
          button.append(image);
        }
      }
      button.classList.toggle("winning-cell", winners.includes(cell));
      if (newWin && shownState && winners.includes(cell)) {
        button.classList.add("game-win-pulse");
        const image = button.querySelector("img");
        image.classList.remove("game-piece-pop");
        image.classList.add(changed ? "game-piece-pop-win" : "game-piece-win");
        image.style.setProperty("--win-delay", `${winners.indexOf(cell) * 80}ms`);
      }
      button.setAttribute("aria-label", `Row ${Math.floor(cell / 3) + 1}, column ${cell % 3 + 1}: ${piece ? ["", "X", "O"][piece] : "empty"}`);
      button.style.setProperty("--piece", ["var(--accent)", "#ff626b", "#609dff"][piece]);
      button.disabled = !online || pending || !mark || !state || state.paused || state.outcome !== 0 || state.turn !== mark || piece !== 0;
    });
    $("replay").hidden = !state?.outcome;
    $("replay").disabled = !online || pending || !!state?.paused;
    ["x", "o"].forEach((key, index) => $(`${key}-player`).classList.toggle("is-active-player", online && !!state && !state.paused && !state.outcome && state.turn === index + 1));
    if (!state) return;
    ["x", "o"].forEach((key, index) => {
      $(`${key}-player`).textContent = state.players[index].display_name;
      const score = $(`${key}-score`);
      score.textContent = state.session_wins[index];
      if (newRound) score.classList.remove("game-piece-win");
      if (newWin && shownState && state.outcome === index + 1) score.classList.add("game-piece-win");
    });
    $("scores").replaceChildren(markLabel(1), ` ${state.players[0].display_name} ${state.session_wins[0]} : ${state.session_wins[1]} ${state.players[1].display_name} `, markLabel(2));
    $("status").textContent = state.status;
    if (!state.outcome && !state.paused) {
      // Only replace the final mark token; names stay plain text.
      const suffix = `(${["", "X", "O"][state.turn]})`;
      if (state.status.endsWith(suffix)) $("status").replaceChildren(state.status.slice(0, -suffix.length), "(", markLabel(state.turn), ")");
    }
    shownState = state;
  }
  function markLabel(mark) {
    const span = document.createElement("span");
    span.textContent = ["", "X", "O"][mark];
    span.style.color = ["", "#ff626b", "#609dff"][mark];
    return span;
  }
  $("replay").addEventListener("click", () => send("play_again"));
  controller.connect();
})();
