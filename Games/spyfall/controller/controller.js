(() => {
  "use strict";
  const $ = id => document.getElementById(id);
  let state = null, online = false, revealed = false, hideCardTimer = null, receivedAt = 0, targetAction = "accuse", renderedLocations = "";
  const motion = matchMedia("(prefers-reduced-motion: reduce)");
  let countdownRound = -1, countdownTicks = new Set(), audioContext = null, sound = null, soundCursor = 0, soundBaseline = true, renderedTeam = "";
  const buffers = {}, effects = new Set();
  const soundNames = ["countdown", "timer_up", "vote", "spy_win", "non_spies_win"];
  const audioBytes = Object.fromEntries(soundNames.map(name => [name, fetch(`audio/${name}.wav`).then(response => response.ok ? response.arrayBuffer() : null).catch(() => null)]));
  const targetPicker = new StarGamesPlayerPicker($("target"), seat => { $("confirm-target").disabled = seat < 0; });
  function unlockAudio() {
    if (!audioContext) {
      const Context = window.AudioContext || window.webkitAudioContext;
      if (!Context) return;
      audioContext = new Context();
      for (const name of soundNames) audioBytes[name].then(bytes => bytes && audioContext.decodeAudioData(bytes)).then(buffer => { buffers[name] = buffer; }).catch(() => {});
    }
    audioContext.resume().catch(() => {});
  }
  function stopCountdown() {
    sound?.stop(); sound = null;
    for (const id of ["timer", "vote-timer"]) $(id).classList.remove("game-countdown-tick");
  }
  function playSound(kind) {
    if (document.hidden || audioContext?.state !== "running" || !buffers[kind]) return null;
    const source = audioContext.createBufferSource(); source.buffer = buffers[kind];
    source.connect(audioContext.destination); source.start();
    return source;
  }
  function stopEffects() { for (const source of effects) source.stop(); effects.clear(); }
  function presentSounds(payload, baseline) {
    if (baseline || payload.paused || !online || document.hidden) stopEffects();
    else for (const event of payload.sound_events || []) {
      if (event.sequence <= soundCursor || !soundNames.includes(event.kind) || event.kind === "countdown") continue;
      const source = playSound(event.kind);
      if (source) { effects.add(source); source.onended = () => effects.delete(source); }
    }
    soundCursor = payload.sound_sequence || 0;
  }
  document.addEventListener("pointerdown", unlockAudio, {passive: true});
  document.addEventListener("keydown", unlockAudio);
  const controller = new StarGamesController("spyfall", {
    connected: player => { online = true; soundBaseline = true; hideCard(); $("connection").textContent = `Connected as ${player.display_name}`; controller.send({action: "sync"}); if (state) render(); },
    disconnected: () => { online = false; hideCard(); closeDecisions(); stopCountdown(); stopEffects(); $("connection").textContent = "Reconnecting…"; if (state) render(); },
    error: message => { $("connection").textContent = message.message; },
    message: payload => {
      if (payload.viewer < 0 || !payload.secret) return; // Public host updates never replace a private view.
      if (state && payload.revision < state.revision) return;
      const newRound = !state || payload.round !== state.round;
      if (newRound) { hideCard(); closeDecisions(); stopCountdown(); }
      if (payload.phase === "finished" || payload.paused) hideCard();
      if (state && payload.phase !== state.phase || payload.paused) closeDecisions();
      presentSounds(payload, newRound || soundBaseline);
      soundBaseline = false;
      state = payload; receivedAt = performance.now(); render();
    }
  });
  function hideCard() { clearTimeout(hideCardTimer); hideCardTimer = null; revealed = false; }
  function send(action, extra = {}) {
    if (!state || !online || state.paused) return;
    controller.send({action, revision: state.revision, ...extra});
  }
  function closeDecisions() { for (const id of ["target-dialog", "guess-dialog"]) if ($(id).open) $(id).close(); }
  function paintClock() {
    if (!state) return;
    const voting = ["vote", "final_vote"].includes(state.phase);
    const elapsed = online && !state.paused ? (performance.now() - receivedAt) / 1000 : 0;
    const roundRunning = state.phase === "playing" && state.timer_started;
    const voteRunning = voting && state.vote_timer_started;
    const reduced = motion.matches || state.reduced_motion;
    const paint = (id, value, running, enabled, kind) => {
      const seconds = Math.ceil(Math.max(0, value - (running ? elapsed : 0)));
      const urgent = enabled && seconds > 0 && seconds <= 10;
      $(id).textContent = urgent ? String(seconds) : `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
      $(id).setAttribute("aria-label", `${seconds} seconds of ${kind} time remaining`);
      $(id).classList.toggle("game-danger-text", urgent);
      return {seconds, urgent};
    };
    const round = paint("timer", state.remaining, roundRunning, state.phase === "playing", "round");
    const vote = paint("vote-timer", state.vote_remaining, voteRunning, voting && state.vote_timer_started, "voting");
    $("clock-status").textContent = state.phase === "final_vote" ? "ROUND TIMER FINISHED" : !online || state.paused || voting ? "ROUND TIMER PAUSED" : "ROUND TIMER";
    $("vote-clock-status").textContent = !online || state.paused ? "VOTING TIMER PAUSED" : state.vote_timer_started ? "VOTING DEADLINE" : "VOTING · AWAITING FIRST VOTE";
    for (const id of ["clock", "vote-clock"]) $(id).classList.toggle("has-reduced-motion", Boolean(reduced));
    if (countdownRound !== state.round) { countdownRound = state.round; countdownTicks.clear(); }
    const id = voting ? "vote-timer" : "timer", active = voting ? vote : round;
    const running = online && !state.paused && (voting ? voteRunning : roundRunning);
    $(voting ? "timer" : "vote-timer").classList.remove("game-countdown-tick");
    if (!running || document.hidden || !active.urgent) { stopCountdown(); return; }
    if (reduced) $(id).classList.remove("game-countdown-tick");
    const key = `${voting ? `vote:${state.vote_number}:` : "round:"}${active.seconds}`;
    if (countdownTicks.has(key)) return;
    countdownTicks.add(key);
    $(id).classList.remove("game-countdown-tick");
    if (!reduced) { void $(id).offsetWidth; $(id).classList.add("game-countdown-tick"); }
    sound?.stop(); sound = playSound("countdown");
  }
  function render() {
    const locked = !online || state.paused, finished = state.phase === "finished";
    $("private-card").hidden = finished;
    $("status").hidden = !locked;
    $("status").textContent = online ? "Paused: waiting for players to reconnect." : "Paused: reconnecting to the host.";
    $("clock").hidden = finished;
    $("vote-clock").hidden = !["vote", "final_vote"].includes(state.phase);
    $("round").textContent = `ROUND ${state.round}`;
    $("secret-label").textContent = revealed ? (state.secret.spy ? "YOUR ROLE" : "YOUR LOCATION") : "PRIVATE CARD";
    $("secret").textContent = revealed ? (state.secret.spy ? "YOU ARE THE SPY" : state.secret.location) : "Hidden";
    $("secret").classList.toggle("game-danger-text", revealed && state.secret.spy);
    $("peek").textContent = revealed ? "HIDE CARD" : "SHOW CARD";
    $("peek").setAttribute("aria-expanded", String(revealed));
    $("peek").disabled = !online;
    $("accuse").hidden = state.secret.spy || state.phase !== "playing";
    $("accuse").disabled = locked || !state.can_accuse;
    $("guess").hidden = !state.secret.spy || state.phase !== "playing";
    $("guess").disabled = locked || !state.can_guess;
    $("role-actions").hidden = state.phase !== "playing";
    $("vote").hidden = state.phase !== "vote";
    if (state.phase === "vote") {
      $("vote-heading").textContent = `Is ${state.players[state.suspect].display_name} the spy?`;
      $("vote-status").textContent = state.viewer === state.suspect ? "You are the suspect and do not vote." : state.voted ? "Your vote is recorded. Waiting for the others." : "Everyone except the suspect must agree.";
    }
    for (const id of ["agree", "disagree"]) { $(id).hidden = !state.can_vote; $(id).disabled = locked || !state.can_vote; }
    $("final-vote").hidden = state.phase !== "final_vote";
    $("final-status").hidden = !state.voted;
    $("final-status").textContent = "Your vote is recorded. Waiting for the others.";
    $("choose-final").hidden = !state.can_vote;
    $("choose-final").disabled = locked || !state.can_vote;
    $("result").hidden = !finished;
    const spyWins = finished && state.outcome.spy_wins;
    document.body.classList.toggle("game-result-screen", finished);
    document.body.classList.toggle("game-result-danger", Boolean(spyWins));
    $("result").classList.toggle("game-result-danger", Boolean(spyWins));
    if (online) $("connection").replaceChildren("Connected as ", playerName(state.viewer));
    if (finished) {
      const result = state.outcome;
      $("winner").textContent = result.spy_wins ? "THE SPY WINS!" : "CIVILIANS WIN!";
      const team = state.players.filter((player, seat) => (seat === result.spy) === Boolean(result.spy_wins));
      const teamKey = JSON.stringify([state.round, result.spy_wins, team]);
      if (renderedTeam !== teamKey) {
        renderedTeam = teamKey;
        $("result-team").replaceChildren(...team.map(player => {
          const member = document.createElement("figure"); member.className = "game-team-member";
          const avatar = document.createElement("div"); avatar.className = "avatar"; avatar.setAttribute("aria-hidden", "true");
          avatar.style.setProperty("--avatar-color", player.color);
          const pose = Number.isInteger(player.pose) && player.pose >= 0 && player.pose <= 5 ? player.pose : 0;
          avatar.style.setProperty("--avatar-pose", `url('/avatar-${pose}.svg')`);
          const name = document.createElement("figcaption"); name.textContent = player.display_name;
          if (result.spy_wins) name.className = "game-danger-text";
          member.append(avatar, name); return member;
        }));
      }
      const reasons = {caught: "The spy was caught.", innocent: "An innocent player was convicted.", escaped: "The final vote did not reach agreement.", guessed: "The spy guessed correctly.", wrong_guess: "The spy guessed incorrectly."};
      $("reveal").replaceChildren("Spy: ", playerName(result.spy), `\nLocation: ${result.location}\n${reasons[result.reason] || ""}${result.guess ? `\nGuess: ${result.guess}` : ""}`);
      $("earned").textContent = `You earned ${result.points[state.viewer]} points · Session: ${state.session_points[state.viewer]} points`;
    } else { $("reveal").replaceChildren(); $("winner").textContent = ""; $("earned").textContent = ""; $("result-team").replaceChildren(); renderedTeam = ""; }
    const locationsKey = JSON.stringify(state.locations);
    if (renderedLocations !== locationsKey) {
      renderedLocations = locationsKey;
      $("location").replaceChildren(...state.locations.map(name => new Option(name, name)));
    }
    paintClock();
  }
  function playerName(seat) {
    const name = document.createElement("span");
    name.textContent = state.players[seat].display_name;
    if (state.phase === "finished" && seat === state.outcome.spy) name.classList.add("game-danger-text");
    return name;
  }
  function canChoose(action) {
    return state && online && !state.paused && (action === "accuse" ? state.phase === "playing" && !state.secret.spy && state.can_accuse : state.phase === "final_vote" && state.can_vote);
  }
  function chooseTarget(action) {
    if (!canChoose(action)) return;
    targetAction = action;
    targetPicker.setPlayers(state.players, state.viewer);
    $("target-heading").textContent = action === "accuse" ? "Accuse a player" : "Choose a suspect";
    $("target-note").textContent = action === "accuse" ? "This uses your one accusation. A unanimous innocent conviction gives the spy the win." : "Your final vote cannot be changed.";
    $("target-dialog").showModal();
  }
  $("peek").addEventListener("click", () => {
    if (!online || !state) return;
    if (revealed) hideCard();
    else {
      revealed = true;
      hideCardTimer = setTimeout(() => { hideCard(); if (state) render(); }, 3000);
    }
    render();
  });
  $("accuse").addEventListener("click", () => chooseTarget("accuse"));
  $("choose-final").addEventListener("click", () => chooseTarget("final_vote"));
  $("confirm-target").addEventListener("click", () => { if (!$("target-dialog").open || targetPicker.selectedSeat < 0 || !canChoose(targetAction)) return; const target = targetPicker.selectedSeat; $("target-dialog").close(); send(targetAction, {target}); });
  $("guess").addEventListener("click", () => { if (online && !state.paused && state.can_guess) $("guess-dialog").showModal(); });
  $("confirm-guess").addEventListener("click", () => { if (!$("guess-dialog").open || !state.can_guess) return; $("guess-dialog").close(); send("guess", {location: $("location").value}); });
  $("agree").addEventListener("click", () => send("vote", {agree: true}));
  $("disagree").addEventListener("click", () => send("vote", {agree: false}));
  for (const button of document.querySelectorAll("[data-close]")) button.addEventListener("click", () => button.closest("dialog").close());
  document.addEventListener("visibilitychange", () => { if (document.hidden) { hideCard(); closeDecisions(); stopCountdown(); stopEffects(); if (state) render(); } });
  window.addEventListener("pagehide", () => { hideCard(); closeDecisions(); if (state) render(); stopCountdown(); stopEffects(); });
  motion.addEventListener("change", paintClock);
  setInterval(paintClock, 250);
  controller.connect();
})();
