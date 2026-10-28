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
      this.canvas = board;
      board = board?.closest('.game-controller')?.querySelector('[data-game-board-fit]') || board;
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
      this.trailing = container.querySelector("[data-game-board-trailing]");
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
      if (this.trailing) this.observer.observe(this.trailing);
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
        const trailingStyle = this.trailing ? getComputedStyle(this.trailing) : null;
        const trailingHeight = this.trailing && !this.trailing.hidden ? this.trailing.getBoundingClientRect().height + parseFloat(trailingStyle.marginTop || 0) + parseFloat(trailingStyle.marginBottom || 0) + parseFloat(style.rowGap || 0) : 0;
        const footer = trailingHeight + (boardController && this.stats && !this.stats.hidden
          ? this.stats.getBoundingClientRect().height + parseFloat(style.rowGap || 0) + 8
          : 0);
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
        if (typeof message.payload?.theme?.revision === "string") this.setThemeRevision(message.payload.theme.revision);
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
  // View-only map camera. Keeps gameplay taps separate from drag/pinch gestures.
  class StarGamesBoardCamera {
    constructor(element, {surface = element.querySelector('svg'), fitElement = null, onChange = () => {}} = {}) {
      this.element = element; this.surface = surface; this.onChange = onChange;
      this.fitElement = fitElement;
      this.zoom = 1; this.pan = {x:0,y:0}; this.points = new Map(); this.gesture = false; this.suppressUntil = 0;
      element.classList.add('game-board-camera'); element.tabIndex = 0;
      const listen = (target, event, handler, options) => { target.addEventListener(event,handler,options); this.cleanup.push(() => target.removeEventListener(event,handler,options)); };
      this.cleanup = [];
      listen(element,'pointerdown',e => {
        if (e.button !== 0) return;
        this.points.set(e.pointerId,{x:e.clientX,y:e.clientY,startX:e.clientX,startY:e.clientY});
        if (this.points.size > 1) this.gesture = true;
      });
      listen(window,'pointermove',e => {
        const p = this.points.get(e.pointerId); if (!p) return;
        const before = this.measure(); p.x = e.clientX; p.y = e.clientY; const after = this.measure();
        if (Math.hypot(p.x-p.startX,p.y-p.startY) >= 8) this.gesture = true;
        if (!this.gesture) return;
        e.preventDefault(); this.suppressUntil = performance.now()+400;
        if (before.distance > 1 && after.distance > 1) this.zoomAt(after.distance/before.distance,this.local(before));
        this.pan.x += after.x-before.x; this.pan.y += after.y-before.y; this.apply();
      },{passive:false});
      const end = e => {
        if (!this.points.has(e.pointerId)) return;
        if (this.gesture || e.type === 'pointercancel') this.suppressUntil = performance.now()+400;
        this.points.delete(e.pointerId); if (!this.points.size) this.gesture = false;
      };
      listen(window,'pointerup',end); listen(window,'pointercancel',end);
      listen(element,'click',e => { if (performance.now()<this.suppressUntil) { e.preventDefault(); e.stopImmediatePropagation(); } },true);
      listen(element,'wheel',e => { e.preventDefault(); this.zoomAt(Math.exp(-e.deltaY*.002),this.local({x:e.clientX,y:e.clientY})); },{passive:false});
      listen(element,'keydown',e => {
        if (e.target !== element) return;
        const center = {x:element.clientWidth/2,y:element.clientHeight/2};
        if (['+','=','-','Home','ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key)) e.preventDefault(); else return;
        if (e.key==='Home') this.reset();
        else if (['+','=','-'].includes(e.key)) this.zoomAt(e.key==='-'?1/1.2:1.2,center);
        else { this.pan.x += e.key==='ArrowLeft'?32:e.key==='ArrowRight'?-32:0; this.pan.y += e.key==='ArrowUp'?32:e.key==='ArrowDown'?-32:0; this.apply(); }
      });
      listen(window,'blur',() => this.cancel());
      listen(window,'gameboardresize',() => this.apply());
      listen(document,'visibilitychange',() => { if (document.hidden) this.cancel(); });
      this.observer = new ResizeObserver(() => this.apply()); this.observer.observe(element);
      if (fitElement) this.observer.observe(fitElement);
    }
    local(p) { const r=this.element.getBoundingClientRect(); return {x:p.x-r.left,y:p.y-r.top}; }
    measure() { const p=[...this.points.values()]; return {x:p.reduce((n,p)=>n+p.x,0)/p.length,y:p.reduce((n,p)=>n+p.y,0)/p.length,distance:p.length>1?Math.hypot(p[0].x-p[1].x,p[0].y-p[1].y):0}; }
    frame() { const r=this.element.getBoundingClientRect(),f=this.fitElement?.getBoundingClientRect();return f?{x:f.left-r.left,y:f.top-r.top,width:f.width,height:f.height}:{x:0,y:0,width:r.width,height:r.height}; }
    project(x,y) { const f=this.frame(); return {x:(x-.5)*f.width*this.zoom+f.x+f.width/2+this.pan.x,y:(y-.5)*f.height*this.zoom+f.y+f.height/2+this.pan.y}; }
    zoomAt(factor,anchor) {
      const f=this.frame(),next=Math.max(1,Math.min(4,this.zoom*factor)),cx=f.x+f.width/2,cy=f.y+f.height/2;
      this.pan.x=anchor.x-cx-(anchor.x-cx-this.pan.x)*next/this.zoom; this.pan.y=anchor.y-cy-(anchor.y-cy-this.pan.y)*next/this.zoom;
      this.zoom=next; this.apply();
    }
    apply() {
      const frame=this.frame(),edge=Math.min(48,this.element.clientWidth*.12,this.element.clientHeight*.12);
      for (const [axis,size,length] of [['x',this.element.clientWidth,frame.width],['y',this.element.clientHeight,frame.height]]) {
        const limit=size*(.35+(this.zoom-1)*.5),center=frame[axis]+length/2;
        this.pan[axis]=this.fitElement?Math.max(edge-center-length*this.zoom/2,Math.min(size-edge-center+length*this.zoom/2,this.pan[axis])):Math.max(-limit,Math.min(limit,this.pan[axis]));
      }
      if (this.surface) this.surface.style.transform=`translate(${this.pan.x}px,${this.pan.y}px) scale(${this.zoom})`;
      if (this.surface && this.fitElement) { const f=this.frame();Object.assign(this.surface.style,{left:f.x+'px',top:f.y+'px',width:f.width+'px',height:f.height+'px'}); }
      this.element.dataset.cameraZoom=String(this.zoom); this.onChange(this);
    }
    cancel() { if(this.points.size)this.suppressUntil=performance.now()+400; this.points.clear(); this.gesture=false; }
    reset() { this.zoom=1; this.pan={x:0,y:0}; this.apply(); }
    destroy() { this.cancel(); this.observer.disconnect(); for (const release of this.cleanup) release(); }
  }
  class StarGamesPlayerRow {
    constructor(onSelect) {
      this.element=document.createElement('button'); this.element.type='button'; this.element.className='game-player-row';
      this.avatar=document.createElement('span'); this.avatar.className='game-player-row-avatar'; this.avatar.setAttribute('aria-hidden','true');
      this.name=document.createElement('span'); this.name.className='game-player-row-name';
      this.stats=document.createElement('span'); this.stats.className='game-player-row-stats';
      this.headline=document.createElement('span');this.headline.className='game-player-row-headline';this.headline.append(document.createElement('img'),document.createElement('output'));this.headline.firstChild.alt='';this.headline.hidden=true;
      this.element.append(this.avatar,this.name,this.headline,this.stats); this.element.addEventListener('click',onSelect);
    }
    update(player,metrics,active=false,headline={}) {
      this.element.dataset.leader=this.leader||'';
      this.name.textContent=player.display_name; this.element.style.setProperty('--score-color',player.color);
      if(this.element.classList.contains('is-dark')&&global.StarGamesTableUI){const ink=StarGamesTableUI.partyAccent(player.color);this.name.style.color=ink;this.element.style.setProperty('--turn-color',ink);}
      this.element.classList.toggle('is-current',active); this.element.setAttribute('aria-label',[player.display_name,active?'Current turn':'Player details',...(this.leader?[this.leader==='silver'?'Joint leader':'Leader']:[]),...metrics.map(s=>s.label+': '+s.value)].join(', '));
      this.headline.hidden=headline.value===undefined;if(!this.headline.hidden){this.headline.firstChild.src=headline.icon;this.headline.lastChild.textContent=headline.value;this.headline.setAttribute('aria-label',headline.label+': '+headline.value);this.element.setAttribute('aria-label',this.element.getAttribute('aria-label')+', '+headline.label+': '+headline.value);}
      if (global.StarGamesTableUI) { if (!this.avatar.firstChild) this.avatar.append(StarGamesTableUI.avatar(player)); else StarGamesTableUI.updateAvatar(this.avatar.firstChild,player); }
      while(this.stats.children.length>metrics.length)this.stats.lastChild.remove();
      metrics.forEach((metric,index) => {
        let item=this.stats.children[index];
        if(!item) { item=document.createElement('span');const value=document.createElement('span'),caption=document.createElement('small');value.className='game-player-row-value';caption.className='game-player-row-caption';item.append(document.createElement('img'),value,caption);this.stats.append(item); }
        item.firstChild.src=metric.icon;item.firstChild.alt='';item.children[1].textContent=metric.value;item.lastChild.textContent=metric.caption||metric.label;item.setAttribute('aria-label',metric.label+': '+metric.value);
        item.firstChild.classList.toggle('game-stat-highlight',!!metric.highlighted);
        item.children[1].classList.toggle('is-long-count',String(metric.value).length>2);
      });
    }
  }
  class StarGamesStatGrid {
    constructor() { this.element=document.createElement('div');this.element.className='game-stat-cards'; }
    update(metrics) {
      while(this.element.children.length>metrics.length)this.element.lastChild.remove();
      metrics.forEach((metric,index)=>{
        let tile=this.element.children[index];
        if(!tile){tile=document.createElement('div');tile.className='game-stat-card';const image=document.createElement('img'),copy=document.createElement('div');image.alt='';copy.append(document.createElement('output'),document.createElement('span'));tile.append(image,copy);this.element.append(tile);}
        tile.firstChild.src=metric.icon;tile.lastChild.firstChild.textContent=metric.value;tile.lastChild.lastChild.textContent=metric.label;tile.setAttribute('aria-label',metric.label+': '+metric.value);
        tile.firstChild.classList.toggle('game-stat-highlight',!!metric.highlighted);
      });
    }
  }
  global.StarGamesResourceCard = item => {
    const card=document.createElement('span'),icon=document.createElement('img');card.className='game-resource-hand-card game-resource-card';icon.alt='';icon.src=item.icon;card.style.setProperty('--resource-color',item.color);card.setAttribute('aria-label',item.label||'Resource');card.append(icon);return card;
  };
  class StarGamesResourceHand {
    constructor(onSelect) {
      this.element=document.createElement('button');this.element.type='button';this.element.className='game-resource-hand';this.amounts=[];
      this.element.addEventListener('click',onSelect);
    }
    update(items) {
      while(this.element.children.length>items.length){this.element.lastChild.remove();this.amounts.pop();}
      items.forEach((item,index)=>{
        let card=this.element.children[index];
        if(!card){card=global.StarGamesResourceCard(item);const count=document.createElement('output');card.append(count);this.element.append(card);this.amounts.push(count);}
        card.style.setProperty('--resource-color',item.color);card.firstChild.src=item.icon;card.lastChild.textContent=item.amount;card.setAttribute('aria-label',item.label+': '+item.amount);
        card.classList.toggle('is-empty',Number(item.amount)===0);
      });
      this.element.setAttribute('aria-label',items.map(item=>item.label+': '+item.amount).join(', ')+'. Inspect resources and production');
    }
  }
  global.StarGamesResourceHand=StarGamesResourceHand;
  global.StarGamesExchangeButton=class {
    constructor(onSelect,{label='Exchange resources'}={}) {
      this.element=document.createElement('button');this.element.type='button';this.element.className='game-primary game-compact-control game-exchange-button';this.label=label;this.key='';this.element.addEventListener('click',onSelect);
    }
    update(items) {
      const key=JSON.stringify(items);if(key===this.key)return;this.key=key;this.element.replaceChildren();
      const descriptions=[this.label];
      for(const item of items){
        const row=document.createElement('span');row.className='game-exchange-row';const count=document.createElement('span');count.className='game-exchange-count';count.append(document.createTextNode(item.owned+' / '));
        if(item.rate<(item.defaultRate||4)){const old=document.createElement('s');old.textContent=item.defaultRate||4;old.className='game-exchange-old-rate';count.append(old,document.createTextNode(' '+item.rate));}else count.append(document.createTextNode(item.rate));
        row.append(count);const give=document.createElement('img');give.src=item.giveIcon;give.alt='';row.append(give);
        if(item.port){const port=document.createElement('span');port.className='game-exchange-port';port.textContent='⚓';port.setAttribute('aria-hidden','true');row.append(port);}
        const equal=document.createElement('span');equal.textContent='= 1';const take=document.createElement('img');take.src=item.takeIcon;take.alt='';const check=document.createElement('span');check.textContent='✓';check.className='game-exchange-check';row.append(equal,take,check);this.element.append(row);descriptions.push(item.label);
      }
      this.element.setAttribute('aria-label',descriptions.join('. '));
    }
  };
  global.StarGamesBoardCamera = StarGamesBoardCamera;
  global.StarGamesPlayerRow = StarGamesPlayerRow;
  global.StarGamesStatGrid = StarGamesStatGrid;
  global.StarGamesCostRow = (items,{highlightCounts=false,iconOnly=false}={}) => {
    const row=document.createElement('div');row.className='game-cost-row';row.classList.toggle('has-status-counts',highlightCounts);
    for(const item of items){const image=document.createElement('img');image.src=item.icon;image.alt=item.label+(item.available?' available':' missing');image.classList.toggle('is-unavailable',!item.available);if(item.owned!==undefined&&item.required!==undefined){const material=document.createElement('div');material.className='game-cost-material';material.classList.toggle('is-covered',item.owned>=item.required);material.setAttribute('aria-label',`${item.label}: have ${item.owned}, need ${item.required}`);material.append(image);for(const [tag,text] of [['span',item.label],['strong',`${item.owned} / ${item.required}`],['small',item.owned>=item.required?'Ready':`Need ${item.required-item.owned} more`]]){if(iconOnly&&tag!=='strong')continue;const label=document.createElement(tag);label.textContent=text;material.append(label);}row.append(material);}else row.append(image);}
    return row;
  };
  global.StarGamesButtonBadge = (button,count) => {
    let badge=button.querySelector('.game-notification-badge');
    if(!badge){badge=document.createElement('span');badge.className='game-notification-badge';badge.setAttribute('aria-hidden','true');button.append(badge);}
    badge.hidden=count<1;badge.textContent=count>99?'99+':String(count);button.classList.add('has-notification-badge');
  };
  global.StarGamesPlayerPicker = StarGamesPlayerPicker;
  global.StarGamesController = StarGamesController;
  global.StarGamesBoardLayout = GameBoardLayout;
})(window);
