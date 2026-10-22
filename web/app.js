(() => {
  "use strict";
  const status = document.querySelector("#status");
  const form = document.querySelector("#join-form");
  const input = document.querySelector("#player-name");
  const error = document.querySelector("#error");
  const joined = document.querySelector("#joined");
  const joinedName = document.querySelector("#joined-name");
  const roster = document.querySelector("#roster");
  const storageKey = `star-games:${location.host}`;
  const colors = ["#202020", "#ffffff", "#e53935", "#228b22", "#2463eb", "#ffdf00", "#ff8c00", "#8b35c9", "#ff91af", "#8b4513", "#808080", "#00ced1", "#00a080", "#a4de02", "#000080", "#800020"];
  let lobbyOpen = true;
  let players = [];
  function updateAvailability() {
    document.querySelectorAll("#colors button").forEach(button => {
      const taken = players.some(player => player.id !== playerId && player.color === button.dataset.color);
      button.disabled = !lobbyOpen || taken;
    });
  }
  let playerId;
  function setLobby(open) {
    document.querySelector("#party-state").textContent = open ? "Choose your avatar color" : "Party locked. The host is choosing a game.";
    lobbyOpen = open;
    updateAvailability();
    form.querySelector("button").disabled = !open;
    status.textContent = open ? "Lobby open. Gather your crew!" : "Party started. New players can join in the lobby.";
  }
  let avatarState = "";
  let avatarAnimation;
  function setColor(color, pose = 0) {
    const avatar = document.querySelector("#avatar");
    const state = `${color}:${pose}`;
    if (avatarState !== state) {
      avatarAnimation?.cancel();
      avatar.style.setProperty("--avatar-pose", `url('/avatar-${Number.isInteger(pose) && pose >= 0 && pose < 6 ? pose : 0}.svg')`);
      if (!matchMedia("(prefers-reduced-motion: reduce)").matches) {
        avatarAnimation = avatar.animate([
          { transform: "scale(.86) rotate(-5deg)" },
          { transform: "scale(1.08) rotate(3deg)", offset: .55 },
          { transform: "scale(1) rotate(0)" }
        ], { duration: 400, easing: "ease-out" });
      }
      avatarState = state;
    }
    document.documentElement.style.setProperty("--accent", color);
    document.querySelector("#avatar").style.setProperty("--avatar-color", color);
    document.querySelectorAll("#colors button").forEach(button => button.setAttribute("aria-pressed", String(button.dataset.color === color)));
  }
  colors.forEach((color, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.dataset.color = color;
    button.style.background = color;
    button.setAttribute("aria-label", ["Black", "White", "Red", "Green", "Blue", "Yellow", "Orange", "Purple", "Pink", "Brown", "Gray", "Cyan", "Teal", "Lime", "Navy", "Maroon"][index]);
    button.setAttribute("aria-pressed", "false");
    button.addEventListener("click", () => {
      if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify({type: "color", color}));
    });
    document.querySelector("#colors").append(button);
  });
  let socket;
  let retryTimer;
  let identity = JSON.parse(localStorage.getItem(storageKey) || "null");

  function connect() {
    clearTimeout(retryTimer);
    const wsPort = Number(location.port || 80) + 1;
    socket = new WebSocket(`ws://${location.hostname}:${wsPort}/`);
    status.textContent = "Connecting to the host…";
    socket.addEventListener("open", () => { status.textContent = "Connected. Choose your player name."; });
    socket.addEventListener("message", event => handle(JSON.parse(event.data)));
    socket.addEventListener("close", event => {
      if (event.code === 4003) {
        identity = null;
        playerId = null;
        localStorage.removeItem(storageKey);
        form.hidden = false;
        joined.hidden = true;
        error.textContent = "You were removed by the host.";
      }
      status.textContent = "Connection lost. Reconnecting…";
      retryTimer = setTimeout(connect, 1500);
    });
  }

  function handle(message) {
    if (message.type === "hello") {
      status.textContent = `Connected to ${message.host_name}`;
      form.hidden = false;
      setLobby(message.lobby_open);
      if (identity?.name) {
        input.value = identity.name;
        join(identity.name, identity.token || "");
      }
    } else if (message.type === "joined") {
      playerId = message.player.id;
      setColor(message.player.color, message.player.pose);
      setLobby(message.lobby_open);
      identity = { name: message.player.display_name, token: message.reconnect_token };
      localStorage.setItem(storageKey, JSON.stringify(identity));
      form.hidden = true;
      joined.hidden = false;
      joinedName.textContent = message.player.display_name;
      error.textContent = "";
      if (message.game_id) location.href = `/game/${encodeURIComponent(message.game_id)}/`;
    } else if (message.type === "roster") {
      players = message.players;
      updateAvailability();
      const self = message.players.find(player => player.id === playerId);
      if (self) { setColor(self.color, self.pose); error.textContent = ""; }
      roster.replaceChildren(...message.players.map(player => {
        const tag = document.createElement("span");
        tag.textContent = player.display_name;
        tag.style.border = `1px solid ${player.color}`;
        return tag;
      }));
    } else if (message.type === "lobby_state") {
      setLobby(message.lobby_open);
    } else if (message.type === "screen" && message.game_id && playerId) {
      location.href = message.path;
    } else if (message.type === "error") {
      error.textContent = message.message;
      if (message.code === "color_unavailable") return;
      if (message.code === "name_in_use") {
        identity = null;
        localStorage.removeItem(storageKey);
      }
      form.hidden = false;
      joined.hidden = true;
    }
  }

  function join(name, token = "") {
    if (socket?.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({ type: "join", name, reconnect_token: token }));
    }
  }

  form.addEventListener("submit", event => {
    event.preventDefault();
    error.textContent = "";
    join(input.value.trim(), identity?.name?.toLowerCase() === input.value.trim().toLowerCase() ? identity.token : "");
  });

  connect();
})();
