(() => {
  "use strict";
  const $ = id => document.getElementById(id);
  const roleNames = {mafia: "Mafia", godfather: "Godfather", detective: "Detective", doctor: "Doctor", boxer: "Boxer", civilian: "Civilian"};
  const actionNames = {mafia: "Mafia kill vote", godfather: "Mafia kill vote", detective: "Investigate", doctor: "Protect", boxer: "Block a night action"};
  const roleInstructions = {
    mafia: "You are Mafia. At night, choose a living town player and Confirm your kill vote, or Pass. Show Role reveals your teammates and their confirmed votes. The leading target is attacked; tied leaders are chosen randomly. Win when living Mafia reach parity with the town.",
    godfather: "You are the Godfather, on the Mafia team. At night, Confirm a kill vote against a living town player, or Pass. Show Role reveals teammates and their votes. You appear civilian to Detective. Win when living Mafia reach parity with the town.",
    detective: "You are the Detective. At night, investigate one other living player and Confirm. Show Role/View Results contains your private reports after investigation. Ordinary Mafia appear mafia; the Godfather and every other role appear civilian. A Boxer can block your investigation. Win by eliminating all Mafia.",
    doctor: "You are the Doctor. At night, protect any living player, including yourself, and Confirm. You may protect the same player on consecutive nights. Protection prevents the night's attack unless Boxer blocks you. Win by eliminating all Mafia.",
    boxer: "You are the Boxer. At night, block one other living player's action, or Pass. Blocking a mafioso removes only their kill vote; another mafioso can still attack. You can also block protection or investigation. Win by eliminating all Mafia.",
    civilian: "You are a Civilian. Each night, use Suspect Players to choose who you think is Mafia, or No One. Your suspicion is shown to everyone the next day and does not eliminate anyone. Win by eliminating all Mafia."
  };
  let state = null, online = false, synced = false, revealed = false, hideTimer = null, pending = false, pickerKey = "", pickerAction = "", ejectionKey = "", livingKey = "", backgroundVariant = null;
  const sky = new MafiaSkyCycle();
  const picker = new StarGamesPlayerPicker($("target"), seat => {
    $("confirm").disabled = seat < 0 || !eligible(pickerAction);
    $("selection").textContent = seat < 0 ? "Choose a player icon" : state.players[seat].display_name;
  }, "assembly");
  const controller = new StarGamesController("mafia", {
    connected: player => {
      online = true; synced = false; pending = false; ejectionKey = ""; backgroundVariant = null; hideRole();
      $("connection").textContent = `Connected as ${player.display_name}`;
      controller.send({action: "sync"});
      if (state) render();
    },
    disconnected: () => {
      online = false; synced = false; pending = false; hideRole(); closePicker();
      $("connection").textContent = "Reconnecting…";
      if (state) render();
    },
    error: error => { $("connection").textContent = error.message; },
    message: payload => {
      if (payload.viewer < 0 || !payload.secret || !Array.isArray(payload.players)) return;
      if (state && payload.revision < state.revision) return;
      if (!state || payload.round !== state.round || payload.phase !== state.phase || payload.paused) {
        hideRole(); closePicker(); pickerKey = "";
      }
      if (!state || payload.round !== state.round) $("instructions").open = false;
      state = payload; synced = true; pending = false;
      if ((pickerAction === "suspect" ? state.suspect_submitted : state.submitted) || state.phase === "finished") closePicker();
      render();
    }
  });
  function eligible(action = "") { return state && online && synced && !state.paused && !pending && (action === "suspect" ? state.can_suspect : (state.can_act || state.can_vote)); }
  function closePicker() { if ($("target-dialog").open) $("target-dialog").close(); }
  function hideRole() { clearTimeout(hideTimer); hideTimer = null; revealed = false; }
  function name(seat) { return seat < 0 ? "Pass" : state.players[seat]?.display_name || "Player"; }
  function paragraph(text) { const p = document.createElement("p"); p.textContent = text; return p; }
  function playerName(player, role = "") {
    const span = document.createElement("span");
    span.textContent = player.display_name;
    span.classList.toggle("game-player-eliminated", !player.alive);
    span.classList.toggle("game-danger-text", ["mafia", "godfather"].includes(role));
    return span;
  }
  function submit(target, action = state?.phase === "night" ? "night_action" : "vote") {
    const targets = action === "suspect" ? state?.suspect_targets : state?.targets;
    if (!eligible(action) || (target >= 0 && !targets.includes(target))) return;
    if (target < 0 && action === "night_action" && ["detective", "doctor"].includes(state.secret.role)) return;
    controller.send({action, revision: state.revision, target});
    pending = true; closePicker(); render();
  }
  function avatarStyle(avatar, player) {
    avatar.style.setProperty("--avatar-color", player.color);
    avatar.style.setProperty("--avatar-pose", `url('/avatar-${Math.max(0, Math.min(5, Math.floor(Number(player.pose) || 0)))}.svg')`);
  }
  function teamMember(player, iconsOnly = false, assembly = false) {
    const figure = document.createElement("figure"), avatar = document.createElement("span"), caption = document.createElement("figcaption");
    figure.className = "game-team-member"; avatar.className = "avatar"; avatar.setAttribute("aria-hidden", "true");
    const eliminated = !player.alive;
    if (assembly && !eliminated) avatar.classList.add("game-avatar-bust");
    figure.classList.toggle("game-team-eliminated", eliminated);
    avatarStyle(avatar, player); caption.textContent = player.display_name + (eliminated ? " · OUT" : "");
    caption.classList.toggle("game-player-eliminated", eliminated);
    const seat = state.players.findIndex(p => p.id === player.id);
    caption.classList.toggle("game-danger-text", state.phase === "finished" && ["mafia", "godfather"].includes(state.outcome.roles[seat]));
    if (iconsOnly) caption.classList.add("sr-only");
    figure.append(avatar, caption); return figure;
  }
  function render() {
    const finished = state.phase === "finished", role = state.secret.role;
    const locked = !online || !synced || state.paused || pending;
    const main = $("private-card").parentElement;
    // Keep day voting within reach; private results remain directly beneath it.
    if (state.phase === "vote") {
      if ($("decisions").nextElementSibling !== $("private-card")) main.insertBefore($("decisions"), $("private-card"));
    } else {
      if ($("private-card").nextElementSibling !== $("suspect-decisions")) main.insertBefore($("private-card"), $("suspect-decisions"));
      if ($("decisions").nextElementSibling !== $("vote-summary")) main.insertBefore($("decisions"), $("vote-summary"));
    }
    document.body.classList.toggle("has-reduced-motion", Boolean(state.reduced_motion));
    const daytime = state.daytime ?? ["discussion", "vote", "ejection"].includes(state.phase);
    if (synced) {
      sky.setDaytime(daytime, backgroundVariant !== null, Boolean(state.reduced_motion));
      controller.setBackgroundVariant(daytime ? "day" : "", backgroundVariant !== null, Boolean(state.reduced_motion));
      backgroundVariant = daytime;
    }
    document.body.classList.toggle("game-result-screen", finished);
    document.body.classList.toggle("game-result-danger", finished && state.outcome.mafia_wins);
    $("status").textContent = !online ? "Reconnecting to the host." : state.paused ? "Paused: waiting for players to reconnect." : state.status;
    $("phase").textContent = state.phase === "setup" ? "GET READY" : `${state.phase === "night" ? "NIGHT" : "DAY"} ${state.day}`;
    $("life").textContent = state.phase === "setup" ? "Waiting for the host to start." : !state.players[state.viewer].alive ? "You are out. Watch the remaining players." : state.phase === "vote" ? "Discuss the suspects and cast your vote." : state.phase === "night" && role === "civilian" ? "The town is asleep." : "You are still in the game.";
    const nextLivingKey = JSON.stringify(state.players);
    if (livingKey !== nextLivingKey) {
      livingKey = nextLivingKey;
      $("living-team").classList.toggle("game-assembly-dense", state.players.length > 8);
      $("living-team").replaceChildren(...state.players.map(player => teamMember(player, false, true)));
    }
    $("private-card").hidden = finished;
    $("peek").disabled = !online || !synced || state.paused || !role;
    $("peek").textContent = revealed ? "HIDE ROLE" : role === "detective" && state.secret.reports.length ? "SHOW ROLE/VIEW RESULTS" : "SHOW ROLE";
    $("peek").setAttribute("aria-expanded", String(revealed));
    $("secrets").hidden = !revealed;
    $("role").textContent = revealed ? roleNames[role] || "" : "";
    $("role").classList.toggle("game-danger-text", revealed && ["mafia", "godfather"].includes(role));
    $("allies").replaceChildren();
    if (revealed && state.secret.allies.length) {
      $("allies").append("Mafia team: ");
      state.secret.allies.forEach((seat, index) => {
        if (index) $("allies").append(", ");
        $("allies").append(playerName(state.players[seat]));
      });
    }
    $("mafia-votes").replaceChildren(...(revealed ? state.secret.mafia_votes.map(ballot => paragraph(`${name(ballot.voter)} confirmed: ${name(ballot.target)}`)) : []));
    $("reports").replaceChildren(...(revealed ? state.secret.reports.map(report => {
      const p = paragraph(`Night ${report.night}: `);
      if (report.result === "blocked") p.append("Your investigation was blocked.");
      else p.append(playerName(state.players[report.target]), ` appears ${report.result}.`);
      return p;
    }) : []));
    const decidingPhase = ["night", "vote"].includes(state.phase);
    const hasDecision = state.players[state.viewer].alive && (state.phase === "vote" || (state.phase === "night" && role && role !== "civilian"));
    $("decisions").hidden = finished || !decidingPhase || !hasDecision;
    $("decision-heading").textContent = state.phase === "vote" ? "Town vote" : actionNames[role] || "";
    $("decision-status").textContent = pending ? "Waiting for the host…" : state.submitted ? `Confirmed: ${state.choice < 0 ? (state.phase === "vote" ? "Skip" : "Pass") : name(state.choice)}. Waiting for the others.` : state.phase === "vote" ? `${state.vote_count} / ${state.alive_count} voted` : "Choose a player, then Confirm.";
    $("choose").disabled = locked || !eligible();
    $("pass").disabled = locked || !eligible();
    $("pass").hidden = state.phase === "night" && ["detective", "doctor"].includes(role);
    $("pass").textContent = state.phase === "vote" ? "SKIP" : "PASS";
    $("choose").textContent = state.phase === "vote" ? "VOTE" : "CHOOSE PLAYER";
    const dangerChoice = state.phase === "vote" || (["mafia", "godfather"].includes(role) && state.phase === "night");
    $("choose").classList.toggle("game-danger", dangerChoice);
    $("choose").classList.toggle("game-primary", !dangerChoice);
    $("pass").classList.toggle("game-success", state.phase === "vote");
    $("confirm").classList.toggle("game-danger", state.phase === "vote" && pickerAction !== "suspect");
    $("confirm").classList.toggle("game-primary", !(state.phase === "vote" && pickerAction !== "suspect"));
    const suspecting = state.phase === "night" && role === "civilian" && state.players[state.viewer].alive;
    const will = !state.players[state.viewer].alive && ["night", "vote"].includes(state.phase);
    $("suspect-decisions").hidden = !suspecting && !will;
    $("suspect-heading").textContent = will ? "Last will" : "Suspect players";
    $("suspect-status").textContent = pending ? "Waiting for the host…" : state.suspect_submitted ? `${state.suspect_choice < 0 ? "No one suspected" : `Suspects ${name(state.suspect_choice)}`}. Revealed next day.` : will && state.last_will_used ? "Your one last will has been submitted." : will ? "Leave one final suspicion. It will be shown the next day." : "Choose who you think is Mafia. Revealed next day.";
    for (const id of ["suspect", "suspect-none"]) $(id).disabled = !eligible("suspect");
    $("vote-summary").hidden = state.phase !== "vote";
    $("ballots").replaceChildren(paragraph(`${state.vote_count} / ${state.alive_count} voted`), ...(state.ballots || []).map(b => paragraph(`${name(b.voter)} → ${b.target < 0 ? "Skip" : name(b.target)}`)));
    $("confirm").disabled = !eligible(pickerAction) || picker.selectedSeat < 0;
    const pickerTargets = pickerAction === "suspect" ? state.suspect_targets || [] : state.targets;
    for (const button of picker.buttons) button.disabled = !eligible(pickerAction) || !pickerTargets.includes(Number(button.dataset.seat));
    $("role-instructions").replaceChildren(paragraph(roleInstructions[role] || "Your role will be assigned when the host starts."));
    if (role) $("role-instructions").append(paragraph(!state.players[state.viewer].alive ? "You are eliminated. You cannot vote or use your night action. You may leave one last will through Suspect Players, shown the next day." : "Town voting opens automatically at dawn. Discuss the suspects, then Confirm one living suspect or Skip. A tie or a leading Skip eliminates nobody. Everyone on the winning team earns one point, including eliminated teammates."));
    renderEjection();
    $("result").hidden = !finished;
    if (finished) {
      $("result").classList.toggle("game-result-danger", state.outcome.mafia_wins);
      $("result-heading").textContent = state.outcome.mafia_wins ? "MAFIA WINS!" : "TOWN WINS!";
      $("result-points").textContent = state.outcome.winners.includes(state.viewer) ? "Your team won. +1 point." : "Your team lost this game.";
      $("role-reveal").replaceChildren(...state.players.map((player, seat) => {
        const p = document.createElement("p");
        p.append(playerName(player, state.outcome.roles[seat]), ` · ${roleNames[state.outcome.roles[seat]]}${state.outcome.winners.includes(seat) ? " +1 point" : ""}`);
        return p;
      }));
      $("team").replaceChildren(...state.outcome.winners.map(seat => teamMember(state.players[seat])));
    } else { $("team").replaceChildren(); $("role-reveal").replaceChildren(); }
  }
  function renderEjection() {
    const ejecting = state.phase === "ejection" && state.ejection?.seat >= 0;
    $("ejection").hidden = !ejecting;
    const avatar = $("ejected-avatar");
    const stage = $("ejection-stage");
    if (!ejecting) { ejectionKey = ""; stage.classList.remove("is-ejecting"); if ($("ejection-dialog").open) $("ejection-dialog").close(); return; }
    if (!$("ejection-dialog").open) $("ejection-dialog").showModal();
    const event = state.ejection, key = `${state.round}:${event.day}:${event.seat}`, player = state.players[event.seat];
    $("ejection-message").textContent = `${player.display_name} ${event.reveal === false ? "was voted out" : event.mafia ? "is Mafia" : "is innocent"}.`;
    avatarStyle(avatar, player);
    stage.style.setProperty("--ejection-play-state", state.paused || !online || !synced ? "paused" : "running");
    if (!synced) return;
    if (ejectionKey !== key) {
      ejectionKey = key; stage.classList.remove("is-ejecting");
      stage.style.setProperty("--ejection-offset", `-${Number(event.elapsed) || 0}s`);
      stage.style.setProperty("--ejection-duration", `${Number(event.duration) || 6.5}s`);
      void stage.offsetWidth; stage.classList.add("is-ejecting");
    }
  }
  $("peek").addEventListener("click", () => {
    if (!state || !online || !synced || state.paused || !state.secret.role) return;
    if (revealed) hideRole();
    else { revealed = true; hideTimer = setTimeout(() => { hideRole(); render(); }, 3000); }
    render();
  });
  function openPicker(action) {
    if (!eligible(action)) return;
    pickerAction = action;
    const targets = action === "suspect" ? state.suspect_targets : state.targets;
    const key = `${state.round}:${state.day}:${state.phase}:${action}:${targets.join(",")}`;
    if (pickerKey !== key) {
      picker.setPlayers(state.players);
      picker.buttons = picker.buttons.filter(button => targets.includes(Number(button.dataset.seat)));
      $("target").replaceChildren(...picker.buttons);
      if (picker.buttons[0]) picker.buttons[0].tabIndex = 0;
      pickerKey = key;
    }
    $("target-heading").textContent = action === "suspect" ? "Suspect players" : state.phase === "vote" ? "Vote out a suspect" : actionNames[state.secret.role];
    $("confirm").disabled = picker.selectedSeat < 0;
    $("target-dialog").showModal();
  }
  $("choose").addEventListener("click", () => openPicker(state?.phase === "night" ? "night_action" : "vote"));
  $("suspect").addEventListener("click", () => openPicker("suspect"));
  $("suspect-none").addEventListener("click", () => submit(-1, "suspect"));
  $("confirm").addEventListener("click", () => { if ($("target-dialog").open) submit(picker.selectedSeat, pickerAction); });
  $("cancel").addEventListener("click", closePicker);
  $("pass").addEventListener("click", () => submit(-1));
  $("ejection-dialog").addEventListener("cancel", event => event.preventDefault());
  document.addEventListener("visibilitychange", () => { if (document.hidden) { hideRole(); closePicker(); if (state) render(); } });
  window.addEventListener("pagehide", () => { hideRole(); closePicker(); if (state) render(); });
  controller.connect();
})();
