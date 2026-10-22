(function (global) {
  "use strict";
  // The launcher supplies local sources; games never hard-code an extension.
  class GameBackground {
    constructor(gameId) {
      this.motion = matchMedia("(prefers-reduced-motion: reduce)");
      this.video = null;
      this.media = null;
      this.variant = "";
      this.currentVariant = null;
      this.hostReduced = false;
      this.generation = 0;
      this.layers = new Set();
      this.motion.addEventListener("change", () => this.updatePlayback());
      document.addEventListener("visibilitychange", () => this.updatePlayback());
      this.load(gameId);
    }

    async load(gameId) {
      try {
        const response = await fetch(`/game/${encodeURIComponent(gameId)}/background.json`);
        if (!response.ok) return;
        this.media = await response.json();
        this.showVariant(this.variant, false);
      } catch (_) {
        // Background preparation must never interfere with joining or play.
      }
    }

    setVariant(name = "", animate = true, reduced = false) {
      this.variant = name;
      this.hostReduced = reduced;
      this.updatePlayback();
      if (this.media && name !== this.currentVariant) this.showVariant(name, animate);
    }

    async showVariant(name, animate) {
      const media = name ? this.media.variants?.[name] : this.media;
      if (!media || (!media.image && !(media.videos || []).length)) return;
      const generation = ++this.generation;
      this.currentVariant = name;
      const layer = document.createElement("div");
      layer.className = "game-background-layer";
      layer.setAttribute("aria-hidden", "true");
      layer.style.opacity = "0";
      if (this.layer) this.layer.after(layer);
      else document.body.prepend(layer);
      this.layers.add(layer);
      let ready = false;
      const reveal = () => {
        if (generation !== this.generation) { layer.remove(); this.layers.delete(layer); return; }
        if (ready) return;
        ready = true;
        layer.dataset.ready = "true";
        const oldLayers = [...this.layers].filter(item => item !== layer);
        this.layer = layer;
        const moving = animate && !this.motion.matches && !this.hostReduced;
        layer.style.transition = moving ? "opacity 900ms ease-in-out" : "none";
        void layer.offsetWidth;
        layer.style.opacity = "1";
        const cleanup = () => oldLayers.forEach(item => {
          item.querySelectorAll("video").forEach(video => video.pause());
          item.remove(); this.layers.delete(item);
        });
        if (moving) setTimeout(cleanup, 950);
        else cleanup();
        this.updatePlayback();
      };
      if (media.image) {
        const image = document.createElement("img");
        image.className = "game-background";
        image.alt = "";
        image.setAttribute("aria-hidden", "true");
        image.src = media.image;
        layer.append(image);
        try { await image.decode(); reveal(); } catch (_) { image.remove(); }
      }
      if (generation !== this.generation) { layer.remove(); this.layers.delete(layer); return; }
      const video = document.createElement("video");
      const sources = (media.videos || []).filter(source => video.canPlayType(source.type));
      // MP4/WebM are the most portable phone formats; Theora is a host option.
      sources.sort((a, b) => (a.type === "video/ogg") - (b.type === "video/ogg"));
      if (!sources.length) { if (!ready) { layer.remove(); this.layers.delete(layer); } return; }
      this.video = video;
      video.className = "game-background";
      video.setAttribute("aria-hidden", "true");
      video.muted = true;
      video.defaultMuted = true;
      video.loop = true;
      video.playsInline = true;
      video.preload = "auto";
      video.hidden = true;
      let index = 0;
      video.addEventListener("error", () => {
        if (++index < sources.length) video.src = sources[index].url;
        else { video.remove(); if (this.video === video) this.video = null; if (!ready) { layer.remove(); this.layers.delete(layer); } }
      });
      video.addEventListener("loadeddata", () => {
        video.hidden = false;
        reveal();
        this.updatePlayback();
      });
      video.src = sources[0].url;
      layer.append(video);
    }

    updatePlayback() {
      const reduced = this.motion.matches || this.hostReduced;
      if (reduced && this.layer) {
        this.layer.style.transition = "none";
        this.layer.style.opacity = "1";
        for (const layer of this.layers) {
          if (layer === this.layer || layer.dataset.ready !== "true") continue;
          layer.querySelectorAll("video").forEach(video => video.pause());
          layer.remove(); this.layers.delete(layer);
        }
      }
      for (const layer of this.layers) for (const video of layer.querySelectorAll("video")) {
        if (reduced || document.hidden) video.pause();
        else video.play().catch(() => {});
      }
    }
  }

  // Shared board sizing respects CSS aspect-ratio and reserves replay space.
  class GameBoardLayout {
    constructor(board, replay) {
      this.board = board;
      this.replay = replay;
      this.controls = board?.closest(".game-playfield")?.querySelector(".game-board-controls");
      this.controlsHome = this.controls?.parentElement;
      this.controlsSide = board?.closest(".game-controller")?.querySelector("[data-game-side-controls]");
      this.frame = 0;
      this.stopped = false;
      const container = board?.closest(".game-controller");
      if (!board || !replay || !container) return;
      this.stats = container.querySelector(".game-board-stats");
      board.dataset.gameBoard = "";
      replay.classList.add("game-board-replay");
      this.refresh = () => {
        if (this.stopped) return;
        cancelAnimationFrame(this.frame);
        this.frame = requestAnimationFrame(() => this.fit());
      };
      this.observer = new ResizeObserver(this.refresh);
      this.observer.observe(container);
      this.observer.observe(board.parentElement);
      const header = container.querySelector("header");
      if (header) this.observer.observe(header);
      if (this.controls) this.observer.observe(this.controls);
      if (this.stats) this.observer.observe(this.stats);
      window.addEventListener("resize", this.refresh);
      document.fonts.ready.then(this.refresh);
      window.addEventListener("pagehide", () => {
        this.stopped = true;
        this.observer.disconnect();
        cancelAnimationFrame(this.frame);
        window.removeEventListener("resize", this.refresh);
      }, {once:true});
      this.refresh();
    }

    fit() {
      const footerReserve = Number.parseFloat(getComputedStyle(this.board.closest(".game-playfield")).getPropertyValue("--game-board-footer-reserve")) || 90;
      const beside = Number.parseFloat(getComputedStyle(this.board.closest(".game-playfield")).getPropertyValue("--game-board-controls-side")) === 1 && this.controlsSide;
      const destination = beside ? this.controlsSide : this.controlsHome;
      if (this.controlsSide && this.controls && destination && this.controls.parentElement !== destination) destination.append(this.controls);
      const room = Math.max(footerReserve, this.controls && !beside ? this.controls.getBoundingClientRect().height + 16 : 0);
      const fullFooter = this.board.closest(".game-controller").classList.contains("game-board-controller");
      this.board.closest(".game-playfield")?.style.setProperty("--game-board-bottom-room", (fullFooter ? room : room - 12) + "px");
      const aspect = getComputedStyle(this.board).aspectRatio.match(/^([\d.]+)(?:\s*\/\s*([\d.]+))?$/);
      const ratio = aspect ? Number(aspect[1]) / Number(aspect[2] || 1) : 1;
      let changed = false;
      // Centered containers move the board's top as its height changes. Settle
      // that feedback in this frame so a later snapshot cannot shift the board.
      for (let pass = 0; pass < 12; pass++) {
        const container = this.board.closest(".game-controller");
        const centered = container.classList.contains("game-centered-controller");
        const style = getComputedStyle(container);
        const boardController = container.classList.contains("game-board-controller");
        const footer = boardController && this.stats && !this.stats.hidden
          ? this.stats.getBoundingClientRect().height + parseFloat(style.rowGap || 0) + 8
          : 0;
        const availableHeight = centered
          ? innerHeight - parseFloat(style.paddingTop) - parseFloat(style.paddingBottom) - room
          : innerHeight - this.board.getBoundingClientRect().top - room - footer - (boardController ? parseFloat(style.paddingBottom) : 0);
        const limit = Math.floor(Math.min(this.board.parentElement.clientWidth, Math.max(boardController ? 44 : 160, availableHeight * ratio)));
        if (this.board.style.maxWidth === limit + "px") break;
        this.board.style.maxWidth = limit + "px";
        this.replay.style.maxWidth = boardController && this.replay.hasAttribute("data-game-inline-action") ? "" : limit + "px";
        changed = true;
      }
      if (changed) window.dispatchEvent(new Event("gameboardresize"));
    }
  }

  class StarGamesController {
    constructor(gameId, handlers = {}) {
      this.gameId = gameId;
      this.handlers = handlers;
      this.socket = null;
      this.identity = JSON.parse(localStorage.getItem(`star-games:${location.host}`) || "null");
      this.retryTimer = null;
      this.background = new GameBackground(gameId);
      this.boardLayout = new GameBoardLayout(document.getElementById("board"), document.getElementById("replay"));
    }

    connect() {
      const wsPort = Number(location.port || 80) + 1;
      this.socket = new WebSocket(`ws://${location.hostname}:${wsPort}/`);
      this.socket.addEventListener("message", event => this.#handle(JSON.parse(event.data)));
      this.socket.addEventListener("close", () => {
        this.handlers.disconnected?.();
        this.retryTimer = setTimeout(() => this.connect(), 1500);
      });
    }

    send(payload) {
      if (this.socket?.readyState === WebSocket.OPEN) {
        this.socket.send(JSON.stringify({ type: "game", game_id: this.gameId, payload }));
      }
    }

    setBackgroundVariant(name = "", animate = true, reduced = false) {
      this.background.setVariant(name, animate, reduced);
    }

    setThemeRevision(revision) {
      if (this.themeRevision === revision) return;
      this.themeRevision = revision;
      this.background.currentVariant = null;
      this.background.load(this.gameId);
    }

    #handle(message) {
      if (message.type === "hello" && this.identity) {
        this.socket.send(JSON.stringify({ type: "join", name: this.identity.name, reconnect_token: this.identity.token }));
      } else if (message.type === "joined") {
        if (message.game_id !== this.gameId) {
          location.href = message.game_id ? `/game/${encodeURIComponent(message.game_id)}/` : "/";
          return;
        }
        this.identity = { name: message.player.display_name, token: message.reconnect_token };
        localStorage.setItem(`star-games:${location.host}`, JSON.stringify(this.identity));
        document.documentElement.style.setProperty("--accent", message.player.color || "#58d6ff");
        document.documentElement.style.setProperty("--player-color", message.player.color || "#58d6ff");
        this.handlers.connected?.(message.player);
      } else if (message.type === "game" && message.game_id === this.gameId) {
        this.handlers.message?.(message.payload);
      } else if (message.type === "screen" && message.game_id !== this.gameId) {
        location.href = message.game_id ? `/game/${encodeURIComponent(message.game_id)}/` : "/";
      } else if (message.type === "error") {
        this.handlers.error?.(message);
      }
    }
  }
  // A reusable, accessible choice of public player icons. Games still validate
  // eligibility and submit only the selected seat through their normal SDK.
  class StarGamesPlayerPicker {
    constructor(element, onSelect = () => {}, presentation = "") {
      this.element = element;
      this.onSelect = onSelect;
      this.selectedSeat = -1;
      this.buttons = [];
      this.presentation = presentation;
      element.classList.add("game-player-picker");
      element.setAttribute("role", "radiogroup");
    }

    setPlayers(players, excludedSeat = -1) {
      this.selectedSeat = -1;
      this.buttons = players.flatMap((player, seat) => {
        if (seat === excludedSeat) return [];
        const button = document.createElement("button");
        button.type = "button";
        button.className = "game-player-choice game-compact-control";
        button.dataset.seat = String(seat);
        button.setAttribute("role", "radio");
        button.setAttribute("aria-checked", "false");
        button.setAttribute("aria-label", player.display_name);
        button.tabIndex = -1;
        const icon = document.createElement("span");
        icon.className = "avatar" + (this.presentation === "assembly" ? " game-avatar-bust" : "");
        icon.setAttribute("aria-hidden", "true");
        icon.style.setProperty("--avatar-color", player.color || "#58d6ff");
        const pose = Math.max(0, Math.min(5, Number(player.pose) || 0));
        icon.style.setProperty("--avatar-pose", `url('/avatar-${Math.floor(pose)}.svg')`);
        const name = document.createElement("span");
        name.className = "game-player-name";
        name.textContent = player.display_name;
        button.append(icon, name);
        button.addEventListener("click", () => this.select(seat));
        button.addEventListener("keydown", event => {
          const index = this.buttons.indexOf(button);
          const offset = ["ArrowRight", "ArrowDown"].includes(event.key) ? 1 : ["ArrowLeft", "ArrowUp"].includes(event.key) ? -1 : 0;
          if (!offset && !["Home", "End"].includes(event.key)) return;
          event.preventDefault();
          const next = event.key === "Home" ? 0 : event.key === "End" ? this.buttons.length - 1 : (index + offset + this.buttons.length) % this.buttons.length;
          const target = this.buttons[next];
          this.select(Number(target.dataset.seat));
          target.focus();
        });
        return [button];
      });
      if (this.buttons[0]) this.buttons[0].tabIndex = 0;
      this.element.replaceChildren(...this.buttons);
      this.onSelect(-1);
    }

    select(seat) {
      if (!this.buttons.some(button => Number(button.dataset.seat) === seat && !button.disabled)) return;
      this.selectedSeat = seat;
      for (const button of this.buttons) {
        const selected = Number(button.dataset.seat) === seat;
        button.setAttribute("aria-checked", String(selected));
        button.tabIndex = selected ? 0 : -1;
      }
      this.onSelect(seat);
    }
  }
  global.StarGamesPlayerPicker = StarGamesPlayerPicker;
  global.StarGamesController = StarGamesController;
  global.StarGamesBoardLayout = GameBoardLayout;
})(window);
