(() => {
  'use strict';
  const lengths = [5, 4, 3, 3, 2], names = ['Carrier', 'Battleship', 'Cruiser', 'Submarine', 'Destroyer'];
  const $ = selector => document.querySelector(selector);
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  const singleFleet = matchMedia('(max-width: 680px), (max-height: 560px)');
  const bridgeSize = [1672, 941], consoleAreas = [[.02,.30,.20,.45],[.78,.30,.20,.45]], consoleAngles = [0,0];
  let state = null, player = null, online = false, fresh = true, previous = null;
  let selected = 0, vertical = false, ownView = false, awaiting = false, pendingPlace = null, celebrated = '';
  let followShot = false;
  const reduced = () => motion.matches || !!state?.reduced_motion;
  const shipCells = (cell, length, upright) => {
    if (cell < 0 || cell >= 100 || (upright ? Math.floor(cell / 10) + length > 10 : cell % 10 + length > 10)) return [];
    return Array.from({length}, (_, i) => cell + i * (upright ? 10 : 1));
  };

  class FleetView {
    constructor(element) {
      this.root = element; this.busy = false; this.frame = 0; this.shipNodes = new Map(); this.event = null;
      element.innerHTML = '<h2 class="fleet-caption"></h2><div class="fleet-water" aria-hidden="true"></div><div class="fleet-coordinates columns" aria-hidden="true"></div><div class="fleet-coordinates rows" aria-hidden="true"></div><div class="fleet-ships" aria-hidden="true"></div><div class="fleet-cells"></div><img class="fleet-cannon" src="/game/battleship/art/cannon.svg" alt="" aria-hidden="true"><canvas class="fleet-effects" aria-hidden="true"></canvas>';
      this.layer = element.querySelector('.fleet-ships'); this.canvas = element.querySelector('canvas'); this.cannon = element.querySelector('.fleet-cannon');
      element.querySelector('.columns').innerHTML = Array.from({length:10}, (_, i) => `<span>${String.fromCharCode(65+i)}</span>`).join('');
      element.querySelector('.rows').innerHTML = Array.from({length:10}, (_, i) => `<span>${i+1}</span>`).join('');
      this.cells = Array.from({length:100}, (_, cell) => {
        const button = document.createElement('button'); button.type = 'button'; button.className = 'fleet-cell'; button.dataset.cell = cell;
        button.disabled = true; button.setAttribute('aria-label', `${String.fromCharCode(65+cell%10)}${Math.floor(cell/10)+1}`);
        element.querySelector('.fleet-cells').append(button);
        button.addEventListener('click', () => {
          if (this.suppressClick===cell) { this.suppressClick=-1; return; }
          this.tap(cell);
        });
        button.addEventListener('pointerdown', event => this.beginHold(cell,event));
        button.addEventListener('keydown', event => { if (event.key.toLowerCase()==='r' && this.setup) { event.preventDefault(); this.rotate(cell); } });
        button.setAttribute('aria-keyshortcuts','R');
        button.addEventListener('pointerenter', () => this.preview(cell));
        button.addEventListener('focus', () => this.preview(cell));
        button.addEventListener('blur', () => this.clearPreview());
        return button;
      });
      element.addEventListener('pointerleave', () => this.clearPreview());
      element.addEventListener('contextmenu', event => { if (this.setup) event.preventDefault(); });
      window.addEventListener('pointerup', event => { if (this.press?.pointer===event.pointerId) this.cancelHold(); });
      window.addEventListener('pointercancel', event => { if (this.press?.pointer===event.pointerId) { this.suppressClick=this.press.cell; this.cancelHold(); } });
      window.addEventListener('pointermove', event => {
        if (this.press?.pointer===event.pointerId && Math.hypot(event.clientX-this.press.x,event.clientY-this.press.y)>12) { this.suppressClick=this.press.cell; this.cancelHold(); }
      });
    }

    draw(index, interactive, setup, animatePlacement) {
      this.index = index; this.setup = setup; this.interactive = interactive;
      if (!setup || !interactive) this.cancelHold();
      const own = index === state.viewer - 1, marks = state.incoming[index], ships = state.fleets[index];
      this.root.classList.toggle('enemy-fleet', !own);
      this.root.querySelector('h2').textContent = own ? 'PLAYER FLEET' : 'ENEMY FLEET';
      this.root.setAttribute('aria-label', own ? 'Your fleet grid' : 'Enemy fleet targeting grid');
      for (const [id, node] of this.shipNodes) if (!ships.some(ship => ship.ship === id)) { node.remove(); this.shipNodes.delete(id); }
      for (const ship of ships) {
        let node = this.shipNodes.get(ship.ship), added = !node;
        if (!node) { node = document.createElement('div'); node.className = 'ship-placement'; node.innerHTML = '<img class="ship-art" src="/game/battleship/art/ship.png" alt="">'; this.layer.append(node); this.shipNodes.set(ship.ship, node); }
        const key = `${ship.cell}:${ship.vertical}`, changed = node.dataset.placement !== key;
        node.dataset.placement = key; node.classList.toggle('vertical', ship.vertical);
        node.style.left = (ship.cell % 10 + (ship.vertical ? .5 : ship.length / 2)) * 10 + '%';
        node.style.top = (Math.floor(ship.cell / 10) + (ship.vertical ? ship.length / 2 : .5)) * 10 + '%';
        node.style.width = ship.length * 10 + '%';
        const wreck = ship.cells.every(cell => marks[cell] === 3); node.classList.toggle('wreck', wreck);
        if (added && wreck && this.busy && this.event?.result === 3 && ship.cells.includes(this.event.cell) && this.age < .48) node.classList.add('pending-wreck');
        if (changed && animatePlacement && setup && !reduced()) {
          node.classList.remove('placing'); void node.offsetWidth; node.classList.add('placing');
          const art = node.firstElementChild; art.classList.remove('game-piece-pop'); void art.offsetWidth; art.classList.add('game-piece-pop');
        }
      }
      this.cells.forEach((button, cell) => {
        const mark = marks[cell], label = `${String.fromCharCode(65+cell%10)}${Math.floor(cell/10)+1}`;
        button.disabled = !interactive || (!setup && mark !== 0);
        const waiting = this.busy && !this.source && this.event?.result===3 && this.age<.48 && ships.find(ship=>ship.ship===this.event.ship)?.cells.includes(cell);
        button.classList.toggle('is-sunk', mark === 3 && !waiting);
        const image = mark ? `<img src="/game/battleship/art/${mark===1?'miss':'hit'}.svg" alt="">` : '';
        if (button.dataset.mark !== String(mark)) { button.innerHTML = image; button.dataset.mark = mark; }
        button.setAttribute('aria-label', `${label}${mark===1?', miss':mark===2?', hit':mark===3?', sunk ship':''}`);
      });
      this.clearPreview();
    }

    validPlacement(cell, selection=selected, upright=vertical) {
      const cells = shipCells(cell, lengths[selection], upright);
      return cells.length && state.fleets[this.index].every(ship => ship.ship === selection || ship.cells.every(index => !cells.includes(index)));
    }

    beginHold(cell, event) {
      if (!this.setup || !this.interactive || this.busy || awaiting || !online || event.button!==0 || !event.isPrimary) return;
      this.cancelHold(); this.suppressClick=-1;
      this.press={cell,pointer:event.pointerId,x:event.clientX,y:event.clientY};
      this.cells[cell].classList.add('holding');
      this.holdTimer=setTimeout(()=>{ this.suppressClick=cell; this.rotate(cell); this.cancelHold(); },450);
    }

    cancelHold() {
      clearTimeout(this.holdTimer);
      if (this.press) this.cells[this.press.cell].classList.remove('holding');
      this.press=null;
    }

    rotate(cell) {
      if (!this.setup || !this.interactive || this.busy || awaiting || !online) return;
      const ship=state.fleets[this.index].find(ship=>ship.cells.includes(cell));
      if (!ship) { vertical=!vertical; this.preview(cell); return; }
      if (!this.validPlacement(ship.cell,ship.ship,!ship.vertical)) { $('#status').textContent='Not enough clear space to rotate this ship.'; return; }
      selected=ship.ship; vertical=!ship.vertical;
      send({action:'rotate',cell});
    }

    tap(cell) {
      if (!this.interactive || this.busy || awaiting || !online) return;
      if (this.setup) {
        if (!this.validPlacement(cell)) { $('#status').textContent = 'Choose a clear position inside the grid.'; return; }
        pendingPlace = {ship:selected, cell, vertical}; send({action:'place', ...pendingPlace});
      } else send({action:'fire', cell});
    }

    preview(cell) {
      this.clearPreview();
      if (!this.setup || !this.interactive) return;
      const valid = this.validPlacement(cell);
      shipCells(cell, lengths[selected], vertical).forEach(index => this.cells[index].classList.add(valid?'placement-ghost':'placement-invalid'));
    }

    clearPreview() { this.cells.forEach(cell => cell.classList.remove('placement-ghost','placement-invalid')); }

    animateShot(event, source) {
      this.cancel(); if (reduced()) return;
      this.busy = true; this.event = event; this.source = source; this.age = 0;
      this.root.setAttribute('aria-busy', 'true');
      this.start = performance.now();
      if (source) { this.cannon.classList.remove('cannon-fire'); void this.cannon.offsetWidth; this.cannon.classList.add('cannon-fire'); }
      else {
        this.cells[event.cell].classList.add('pending-impact');
        if (event.result===3 && this.index!==state.viewer-1) this.shipNodes.get(event.ship)?.classList.add('pending-wreck');
      }
      let landed=false;
      const tick = now => {
        this.age = (now - this.start) / 1000;
        if (this.age >= .48 && !landed) {
          landed=true; this.cells[event.cell].classList.remove('pending-impact'); this.layer.querySelectorAll('.pending-wreck').forEach(node => node.classList.remove('pending-wreck')); render();
          if (!source && event.result===3) this.shipNodes.get(event.ship)?.classList.add('sinking');
        }
        this.paint();
        if (this.age < 1.25 && !reduced()) this.frame = requestAnimationFrame(tick);
        else { this.cancel(); finishFollowing(); render(); }
      };
      this.frame = requestAnimationFrame(tick);
    }

    paint() {
      const size = this.root.clientWidth, ctx = this.canvas.getContext('2d'), ratio = Math.min(devicePixelRatio, 2);
      const height=this.root.clientHeight;
      if (this.canvas.width !== Math.round(size*ratio) || this.canvas.height !== Math.round(height*ratio)) { this.canvas.width = Math.round(size*ratio); this.canvas.height = Math.round(height*ratio); }
      ctx.setTransform(ratio,0,0,ratio,0,0); ctx.clearRect(0,0,size,height); if (!size) return;
      const edge = size*32/424, t = this.age, event = this.event;
      const burst = (x,y,r,color,alpha) => {
        ctx.fillStyle = color; ctx.globalAlpha = Math.max(0,alpha); ctx.beginPath();
        for (let i=0;i<20;i++) { const radius = r*(i%2?.42:1), angle=i*Math.PI/10; const px=x+Math.cos(angle)*radius,py=y+Math.sin(angle)*radius; i?ctx.lineTo(px,py):ctx.moveTo(px,py); }
        ctx.closePath(); ctx.fill(); ctx.globalAlpha=1;
      };
      if (this.source) { if (t<.24) burst(size*65/424,size*17/424,edge*(.25+t*4),'#ffdc4f',1-t/.24); return; }
      const x=size*56/424+(event.cell%10+.5)*edge, y=size*94/424+(Math.floor(event.cell/10)+.5)*edge;
      if (t<.48) {
        const p=t/.48, px=size*.07+(x-size*.07)*p, py=size*.12+(y-size*.12)*p-Math.sin(p*Math.PI)*size*.22;
        ctx.strokeStyle='#fff5ac'; ctx.lineWidth=Math.max(2,edge*.1); ctx.beginPath(); ctx.moveTo(px-edge*.55,py+edge*.5); ctx.lineTo(px,py); ctx.stroke();
        ctx.fillStyle='#262c3f'; ctx.beginPath(); ctx.arc(px,py,Math.max(3,edge*.12),0,Math.PI*2); ctx.fill(); return;
      }
      const elapsed=t-.48, fade=1-elapsed/.77;
      if (event.result===1) {
        ctx.globalAlpha=Math.max(0,fade); ctx.strokeStyle='#d0ffff'; ctx.lineWidth=Math.max(2,edge*.06); ctx.beginPath(); ctx.arc(x,y,edge*(.22+elapsed*2.2),0,Math.PI*2); ctx.stroke();
        for (let i=0;i<8;i++) { const angle=i*Math.PI/4; ctx.fillStyle='#d0ffff'; ctx.beginPath(); ctx.arc(x+Math.cos(angle)*edge*elapsed*2,y+Math.sin(angle)*edge*elapsed*2-edge*Math.sin(elapsed*Math.PI/.77)*.65,Math.max(2,edge*.065),0,Math.PI*2); ctx.fill(); }
        ctx.globalAlpha=1;
      } else {
        burst(x,y,edge*(.45+elapsed*1.4)*(event.result===3?1.3:1),'#ffad18',fade); burst(x,y,edge*(.22+elapsed*.75),'#fff2a3',fade);
        ctx.fillStyle='#263347'; ctx.globalAlpha=Math.max(0,fade*.5);
        for (let i=0;i<5;i++) { ctx.beginPath(); ctx.arc(x+(i-2)*edge*.19,y-elapsed*edge*(.7+i*.22),edge*(.09+elapsed*.15),0,Math.PI*2); ctx.fill(); }
        ctx.globalAlpha=1;
      }
    }

    cancel() {
      this.cancelHold();
      this.suppressClick=-1;
      cancelAnimationFrame(this.frame); this.busy=false; this.event=null;
      this.root.setAttribute('aria-busy', 'false');
      this.canvas.getContext('2d').clearRect(0,0,this.canvas.width,this.canvas.height);
      this.cannon.classList.remove('cannon-fire'); this.cells.forEach(cell => cell.classList.remove('pending-impact'));
      this.layer.querySelectorAll('.pending-wreck').forEach(node => node.classList.remove('pending-wreck'));
      this.layer.querySelectorAll('.sinking').forEach(node => node.classList.remove('sinking'));
    }
  }

  const primary = new FleetView($('#board')), secondary = new FleetView($('#home-board')), views = [primary, secondary];
  const celebration = new StarGamesCelebration($('#board'));
  const busy = () => views.some(view => view.busy);
  function finishFollowing() {
    if (followShot && state?.turn===state.viewer && !state.animating && !busy()) { ownView=false; followShot=false; }
  }
  const send = input => { if (!state || !online || awaiting || busy() || state.animating || state.paused) return; awaiting=true; controller.send({...input, revision:state.revision}); render(); };

  function layoutConsoles() {
    // Fixed background media covers the viewport inside the browser's scrollbar gutter.
    const viewportWidth=document.documentElement.clientWidth;
    const scale=Math.max(viewportWidth/bridgeSize[0],innerHeight/bridgeSize[1]), width=bridgeSize[0]*scale, height=bridgeSize[1]*scale;
    const rects=consoleAreas.map(([x,y,w,h])=>({x:(viewportWidth-width)/2+x*width,y:(innerHeight-height)/2+y*height,width:w*width,height:h*height}));
    const docked=innerWidth>=1100 && rects.every(rect=>rect.x>=0 && rect.y>=0 && rect.x+rect.width<=innerWidth && rect.y+rect.height<=innerHeight) && rects[0].width>=148 && rects[0].height>=96;
    $('#fleet-consoles').classList.toggle('is-docked',docked);
    $('#deployment').hidden=state?.phase!=='setup';
    const parent=docked?$('#own-console'):$('#ready-slot');
    if ($('#deployment').parentElement!==parent) parent.prepend($('#deployment'));
    ['ship-type','auto','clear','ready'].forEach(id=>$(`#${id}`).classList.toggle('game-compact-control',docked));
    ['own','enemy'].forEach((prefix,index)=>{
      const pane=$(`#${prefix}-console`), rect=rects[index];
      pane.hidden=state?.phase==='setup' && (!docked || index===1);
      for (const [property,value] of Object.entries({left:rect.x,top:rect.y,width:rect.width,height:rect.height})) pane.style[property]=docked?value+'px':'';
      pane.style.setProperty('--fleet-angle',docked?consoleAngles[index]+'deg':'0deg');
      if (docked) pane.style.setProperty('--fleet-heading-size',Math.max(10,rect.width*.07)+'px');
      else pane.style.removeProperty('--fleet-heading-size');
      pane.style.setProperty('--fleet-row-height',((rect.height-Math.max(10,rect.width*.07)-9)/5)+'px');
    });
    const center=docked?2*Math.min(viewportWidth/2-rects[0].x-rects[0].width,rects[1].x-viewportWidth/2)-32:viewportWidth;
    document.documentElement.style.setProperty('--fleet-center-width',center+'px');
    $('#own-fleet-status').hidden=state?.phase==='setup';
    $('#enemy-fleet-status').hidden=state?.phase==='setup';
  }

  function fleetStatus(prefix, seat) {
    const list=$(`#${prefix}-ships`);
    if (!list.children.length) names.forEach((name,index)=>{
      const row=document.createElement('li'); row.style.setProperty('--ship-length',(lengths[index]/5*100)+'%');
      row.innerHTML=`<img src="/game/battleship/art/fleet-${name.toLowerCase()}.svg" alt=""><span class="fleet-name">${name.toUpperCase()}</span><span class="fleet-lamp" aria-hidden="true"></span>`; list.append(row);
    });
    [...list.children].forEach((row,index)=>{
      const ship=state.fleets[seat].find(ship=>ship.ship===index), marks=state.incoming[seat];
      const sunk=!!ship && ship.cells.every(cell=>marks[cell]===3), damaged=!!ship && !sunk && ship.cells.some(cell=>marks[cell]===2);
      row.classList.toggle('sunk',sunk); row.classList.toggle('damaged',damaged);
      row.setAttribute('aria-label',`${names[index]}: ${sunk?'sunk':damaged?'damaged':'afloat'}`);
    });
  }

  function render() {
    if (!state || !player) return;
    const own = state.viewer-1, enemy=1-own, setup=state.phase==='setup', locked=!online || state.paused || state.animating || busy() || awaiting;
    layoutConsoles();
    const showOwn=setup || ownView;
    primary.draw(showOwn?own:enemy, !locked && (setup?!state.ready[own]:!showOwn && state.phase==='battle' && state.turn===state.viewer), setup && !state.ready[own], !fresh);
    secondary.draw(own, false, false, false);
    $('.battle-boards').classList.toggle('deploying', setup);
    $('#show-own').setAttribute('aria-pressed',String(showOwn)); $('#show-enemy').setAttribute('aria-pressed',String(!showOwn));
    $('#show-own').disabled=setup || busy() || state.animating; $('#show-enemy').disabled=setup || busy() || state.animating;
    $('#ship-type').value=selected; $('#ship-type').disabled=locked || state.ready[own];
    $('#auto').disabled=locked || state.ready[own]; $('#clear').disabled=locked || state.ready[own] || !state.fleets[own].length;
    $('#ready').disabled=locked || state.ready[own] || state.fleets[own].length!==5;
    $('#ready').hidden=!setup;
    $('#ready').textContent=state.ready[own]?'LOCKED':'READY';
    names.forEach((name,index) => $('#ship-type').options[index].textContent=`${name} · ${lengths[index]}${state.fleets[own].some(ship=>ship.ship===index)?' ✓':''}`);
    $('#status').textContent=state.status;
    fleetStatus('own',own);
    fleetStatus('enemy',enemy);
    $('#replay').hidden=state.phase!=='finished'; $('#replay').disabled=locked;
    if (state.outcome && !state.animating && !busy() && celebrated!==state.round_id) {
      celebrated=state.round_id; celebration.show([], 'FLEET SUNK!', '#ffce4c', !fresh && !reduced());
    }
  }

  const controller = new StarGamesController('battleship', {
    connected: identity => { player=identity; online=true; fresh=true; previous=null; awaiting=false; views.forEach(view=>view.cancel()); $('#connection').textContent=`Connected as ${identity.display_name}`; controller.send({action:'sync'}); },
    disconnected: () => { online=false; fresh=true; previous=null; awaiting=false; views.forEach(view=>view.cancel()); $('#connection').textContent='Reconnecting…'; render(); },
    error: error => { awaiting=false; $('#connection').textContent=error.message; render(); },
    message: payload => {
      if (!player || ![1,2].includes(payload.viewer) || payload.players?.[payload.viewer-1]?.id!==player.id) return;
      const newRound=!state || state.round_id!==payload.round_id || state.viewer!==payload.viewer;
      if (newRound || fresh) { views.forEach(view=>view.cancel()); celebration.clear(); celebrated=''; ownView=false; followShot=false; selected=0; vertical=false; }
      const old=previous; state=payload; awaiting=false;
      if (pendingPlace && state.fleets[state.viewer-1].some(ship=>ship.ship===pendingPlace.ship && ship.cell===pendingPlace.cell && ship.vertical===pendingPlace.vertical)) {
        const next=lengths.findIndex((_,index)=>!state.fleets[state.viewer-1].some(ship=>ship.ship===index)); if (next>=0) selected=next;
      }
      pendingPlace=null;
      const shot=state.last_shot, key=shot?.id?`${state.round_id}:${shot.id}`:'';
      const newShot=!fresh && !newRound && old && key && old!==key;
      if (newShot && singleFleet.matches) { ownView=shot.seat!==state.viewer; followShot=ownView; }
      if (!newShot) finishFollowing();
      render();
      if (newShot) {
        views.forEach(view=>view.animateShot(shot,view.index===shot.seat-1)); render();
        if (reduced()) { finishFollowing(); render(); }
      }
      previous=key || 'setup'; fresh=false;
    }
  });
  $('#ship-type').addEventListener('change',event=>{ selected=Number(event.target.value); views.forEach(view=>view.clearPreview()); });
  $('#auto').addEventListener('click',()=>send({action:'auto'})); $('#clear').addEventListener('click',()=>send({action:'clear'})); $('#ready').addEventListener('click',()=>send({action:'ready'}));
  $('#replay').addEventListener('click',()=>send({action:'play_again'}));
  $('#show-own').addEventListener('click',()=>{ ownView=true; render(); }); $('#show-enemy').addEventListener('click',()=>{ ownView=false; render(); });
  window.addEventListener('gameboardresize',()=>{ $('#home-board').style.width=$('#board').getBoundingClientRect().width+'px'; });
  window.addEventListener('resize',()=>{ layoutConsoles(); });
  motion.addEventListener('change',()=>{ views.forEach(view=>view.cancel()); finishFollowing(); render(); });
  window.addEventListener('pagehide',()=>{ views.forEach(view=>view.cancel()); celebration.clear(); },{once:true});
  controller.connect();
})();
