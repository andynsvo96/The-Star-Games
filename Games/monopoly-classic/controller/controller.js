(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  let state = null, connected = false, identity = null, shown = null;
  let cardsSignature = '', actionsSignature = '', localMoving = false, localTimer = null, clockAt = 0, priorRects=new Map();
  const give = new Set(), take = new Set();
  const reader = new StarGamesCardReader();
  const moneyEffect = new StarGamesMoneyEffect(seat => seat === state?.viewer ? $('stats').querySelector('[data-money-amount]')?.getBoundingClientRect() : null);
  const cardEffect = new StarGamesCardEffect(face);
  const cardMotion = new StarGamesCardMotion((zone,card,source) => {
    if (zone.zone === 'reveal') { const height = Math.min(230, innerHeight * .42); return {x: innerWidth / 2 - height / 3, y: innerHeight / 2 - height / 2, width: height * 2 / 3, height}; }
    if(zone.zone==='player'){
      if(zone.seat===state?.viewer){if(source&&priorRects.has(card?.id))return priorRects.get(card.id);const tile=$('properties').querySelector('[data-card="'+card?.id+'"]');return (tile||$('identity')).getBoundingClientRect();}
      return $('turn-order').querySelector('[data-seat="'+zone.seat+'"]')?.getBoundingClientRect()||null;
    }
    return document.querySelector('.classic-heading .game-title-art').getBoundingClientRect();
  }, face);
  reader.dialog.id = 'card-reader';
  const controller = new StarGamesController('monopoly-classic', {
    connected(player) { identity = player; connected = true; controller.send({action: 'sync'}); },
    disconnected() {
      connected = false; clearTimeout(localTimer); localMoving = false;
      clearEffects();
      $('status').textContent = 'Reconnecting…'; updateLocks();
    },
    message(packet) {
      if (packet.type === 'clock') {
        if (state && packet.revision === state.revision) { state.clocks = packet.clocks; clockAt = performance.now(); renderClocks(); }
        return;
      }
      if (packet.type !== 'state' || packet.viewer < 0) return;
      render(packet);
    },
    error(error) { $('status').textContent = error.message; }
  });
  const reduced = () => !!state?.reduced_motion || matchMedia('(prefers-reduced-motion: reduce)').matches;
  const locked = () => !connected || !state || state.paused || state.animating || state.autoplay || localMoving;
  const choices = action => (state?.actions || []).filter(choice => choice.payload.action === action);
  const name = card => state?.theme?.labels?.[card.key] || card.name;
  const art = key => `/game/monopoly-classic/art/${key}.svg?v=${encodeURIComponent(state?.theme?.revision || '')}`;
  const person = seat => state?.players?.[seat]?.display_name || 'Bank';
  const property = id => state.properties.find(item => item.id === id);
  const text = (tag, value, className = '') => { const node = document.createElement(tag); node.textContent = value; if (className) node.className = className; return node; };
  function send(payload) {
    if (locked()) return false;
    controller.send({...payload, revision: state.revision});
    return true;
  }
  function button(label, payload, primary = false) {
    const node = text('button', label, primary ? 'game-primary' : 'game-secondary');
    node.type = 'button'; node.dataset.command = payload.action;
    node.addEventListener('click', () => { if (send(payload)) reader.close(); });
    node.disabled = locked(); return node;
  }
  function face(card) {
    const node=StarGamesCard({...card, display_name: name(card)}, {art: art(card.key), color: card.color || '#9aafa1'});if(card.id!==undefined)node.dataset.card=card.id;return node;
  }
  function openCard(card) {
    shown = card.id ?? card.key;
    const available = card.kind === 'property' ? (state.actions || []).filter(choice => choice.payload.property === card.id) : [];
    reader.showCard(face(card), {heading: name(card), actions: available.map(choice => ({label: choice.label, action: choice.payload.action, disabled: locked(), onSelect() { if (send(choice.payload)) reader.close(); }}))});
    if(card.kind==='property')reader.setSubtitle(card.owner>=0?'Owned by '+card.owner_name:'Available from the Bank');
  }
  function render(next) {
    const previous = state;
    if(previous&&previous.revision!==next.revision)priorRects=new Map([...$('properties').querySelectorAll('[data-card]')].map(node=>[Number(node.dataset.card),node.getBoundingClientRect()]));
    state = next; clockAt = performance.now();
    controller.setThemeRevision(state.theme.revision);
    document.body.classList.toggle('has-reduced-motion', !!state.reduced_motion);
    if (reduced()) { clearTimeout(localTimer); localMoving = false; $('properties').classList.remove('game-piece-pop'); }
    $('status').textContent = state.status;
    $('turn-order').replaceChildren(StarGamesTurnStrip(state.players,state.phase==='finished'?-1:state.turn));
    const me = state.players[state.viewer];
    $('identity').replaceChildren();
    if (me) $('identity').append(StarGamesTableUI.avatar(me), text('strong', me.display_name));
    else $('identity').append(text('strong', identity?.display_name || 'Player'));
    $('stats').replaceChildren();
    if (me) {
      const cash=StarGamesTableUI.stat('bank', '$' + me.cash, 'Cash: $' + me.cash);
      const amount=text('span', '$' + me.cash); amount.dataset.moneyAmount=''; cash.lastChild.replaceWith(amount);
      $('stats').append(cash, text('strong', '$' + me.wealth + ' total wealth'), text('span', me.wins + ' session wins'));
      $('jail').hidden = me.jailed < 0 && !me.jail_cards;
      $('jail').textContent = me.jailed >= 0 ? 'In Jail · ' + me.jailed + ' attempts used' : me.jail_cards + ' Jail Free card' + (me.jail_cards === 1 ? '' : 's');
    }
    const mine = (state.properties || []).filter(item => item.owner === state.viewer);
    const signature = JSON.stringify([mine, state.theme]);
    if (signature !== cardsSignature) {
      const changed = previous && mine.some(card => !previous.properties?.some(old => old.id === card.id && old.owner === card.owner && old.buildings === card.buildings && old.mortgaged === card.mortgaged));
      cardsSignature = signature;
      const tiles = mine.map(card => {
        const caption = card.mortgaged ? 'MORTGAGED' : card.buildings === 5 ? 'HOTEL' : card.buildings ? card.buildings + ' houses' : 'Rent $' + card.rent;
        return StarGamesCardTile(face(card), {label: name(card) + ', ' + caption, caption, onSelect: () => openCard(property(card.id))});
      });
      $('properties').replaceChildren(tiles.length ? StarGamesCardGrid(tiles, {cardWidth: 128}) : text('p', 'No properties yet.'));
      if (changed && !reduced()) {
        clearTimeout(localTimer); localMoving = true;
        $('properties').classList.remove('game-piece-pop'); void $('properties').offsetWidth; $('properties').classList.add('game-piece-pop');
        localTimer = setTimeout(() => { localMoving = false; $('properties').classList.remove('game-piece-pop'); updateLocks(); }, 260);
      }
    }
    const fingerprint = JSON.stringify([state.phase, state.actor, state.actions, state.auction, state.trade, state.debt, state.transfer, state.buy_id]);
    if (fingerprint !== actionsSignature) { actionsSignature = fingerprint; renderDecision(); }
    $('trade').hidden = !choices('offer_trade').length;
    renderResults(); renderClocks(); updateLocks();
    moneyEffect.update(state.motion, {paused: state.paused, reduced: reduced()});
    cardEffect.update(state.motion, {paused: state.paused, reduced: reduced()});
    cardMotion.update(state.motion, {paused: state.paused, reduced: reduced()});
    if (reader.open && shown !== null) {
      const card = state.properties.find(item => item.id === shown) || (state.last_card?.key === shown ? state.last_card : null);
      if (card) openCard(card); else reader.close();
    }
    if (state.phase === 'finished' && $('trade-dialog').open) $('trade-dialog').close();
  }
  function clearEffects() {
    moneyEffect.clear(); cardEffect.update(null); cardMotion.update(null);
  }
  window.addEventListener('pagehide', clearEffects);
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) clearEffects(); else if (connected) controller.send({action: 'sync'});
  });
  function renderDecision() {
    $('context').replaceChildren(); $('actions').replaceChildren();
    $('decision-heading').textContent = state.phase === 'setup' ? 'Waiting for the host' : state.actor === state.viewer ? 'Your decision' : 'Your actions';
    if (state.phase === 'auction') {
      const auction = state.auction, deed = property(auction.property);
      const building = auction.kind === 'building';
      $('context').append(text('p', building ? 'Last ' + auction.building + ' auction' : name(deed)), text('p', auction.leader >= 0 ? person(auction.leader) + ' leads at $' + auction.amount : 'Bidding starts at $10.'));
      const bid = choices('bid')[0];
      if (bid) {
        const group = document.createElement('label'); group.className = 'classic-bid'; group.append(text('span', 'Your bid $'));
        const amount = document.createElement('input'); amount.type = 'number'; amount.id = 'bid-amount'; amount.className = 'game-choice'; amount.min = String(bid.payload.amount); amount.max = String(state.players[state.viewer].cash); amount.step = '1'; amount.value = String(bid.payload.amount); amount.setAttribute('aria-label', 'Your auction bid');
        const submit = text('button', 'BID', 'game-primary'); submit.type = 'button'; submit.dataset.command = 'bid';
        let placement;
        if (building) {
          placement = document.createElement('select'); placement.id = 'bid-property'; placement.className = 'game-choice'; placement.setAttribute('aria-label', 'Place the building on');
          for (const id of auction.eligible[String(state.viewer)]) { const option = text('option', name(property(id))); option.value = String(id); placement.append(option); }
          $('context').append(placement);
        }
        submit.addEventListener('click', () => { const value = Number(amount.value); if (Number.isSafeInteger(value) && value >= Number(amount.min) && value <= Number(amount.max)) send({action: 'bid', amount: value, ...(placement ? {property: Number(placement.value)} : {})}); });
        group.append(amount, submit); $('context').append(group);
      }
    } else if (state.phase === 'building_interest') {
      $('context').append(text('p', 'The bank has one ' + state.building_sale.kind + ' left. Request it for one of your eligible streets, or pass. Competing requests go to auction.'));
    } else if (state.phase === 'debt') {
      $('context').append(text('p', person(state.debt.seat) + ' owes $' + state.debt.amount + ' to ' + person(state.debt.target) + '.', 'game-owed'));
      if (state.debt.seat === state.viewer) $('context').append(text('p', 'Open your deeds below to mortgage property or sell buildings. You can also offer a trade.'));
    } else if (state.phase === 'transfer') {
      const deed = property(state.transfer.property);
      $('context').append(text('p', name(deed) + ' is mortgaged. Keep it for $' + Math.ceil(deed.mortgage / 10) + ' interest, or repay $' + Math.ceil(deed.mortgage * 11 / 10) + '.'));
    } else if (state.phase === 'buy') {
      const deed = property(state.buy_id);
      if (deed) $('context').append(text('p', name(deed) + ' · $' + deed.price));
    } else if (state.phase === 'trade' && state.trade.give_properties) {
      const sender = state.trade.from === state.viewer;
      for (const [prefix, label] of [['give', sender ? 'You give' : 'You receive'], ['take', sender ? 'You receive' : 'You give']]) {
        const section=document.createElement('section');section.append(text('h3',label),text('strong','$'+state.trade[prefix+'_cash'],'game-success-text'));
        const cards=state.trade[prefix+'_properties'].map(id=>face(property(id)));
        for(const deck of state.trade[prefix+'_jail'])cards.push(face({key:deck+'-jail-free',name:'Get Out of Jail Free',kind:deck,layout:'deal',value:0}));
        if(cards.length)section.append(StarGamesCardGrid(cards,{cardWidth:116}));$('context').append(section);
      }
    }
    for (const choice of state.actions || []) {
      if (('property' in choice.payload && choice.payload.action !== 'claim_building') || ['offer_trade', 'bid'].includes(choice.payload.action)) continue;
      const label = choice.payload.action === 'claim_building' ? 'Request for ' + name(property(choice.payload.property)) : choice.label;
      $('actions').append(button(label, choice.payload, ['roll', 'buy', 'end', 'pay_debt', 'accept_trade', 'claim_building'].includes(choice.payload.action)));
    }
  }
  function renderResults() {
    $('results').hidden = state.phase !== 'finished';
    if (state.phase !== 'finished') return;
    $('winner').textContent = person(state.winner) + ' wins!';
    const ranked = [...state.players].sort((a, b) => Number(b.seat === state.winner) - Number(a.seat === state.winner) || b.wealth - a.wealth);
    $('standings').replaceChildren(...ranked.map(player => text('p', player.display_name + ' · $' + player.wealth + ' · ' + (player.seat === state.winner ? 'WINNER' : 'LOSS'))));
    $('tie-break').hidden = !state.tie_rolls?.length;
  }
  function updateLocks() {
    for (const node of document.querySelectorAll('[data-command], #trade, #send-trade, #bid-amount, #replay')) node.disabled = locked();
    if (reader.open && state) for (const node of reader.dialog.querySelectorAll('[data-reader-action]')) node.disabled = locked();
  }
  function format(seconds) { const whole = Math.max(0, Math.ceil(seconds)); return Math.floor(whole / 60) + ':' + String(whole % 60).padStart(2, '0'); }
  function renderClocks() {
    if (!state) return;
    const elapsed = state.clocks.running && connected ? Math.min(1, (performance.now() - clockAt) / 1000) : 0;
    const parts = [];
    if (state.clocks.game_enabled) parts.push(text('span', 'GAME ' + format(state.clocks.game - elapsed)));
    if (state.clocks.turn_enabled) parts.push(text('span', (state.clocks.owner === state.viewer ? 'YOUR TIME ' : 'TURN ') + format(state.clocks.turn - elapsed)));
    $('clocks').replaceChildren(...parts);
  }
  function openTrade() {
    if (locked() || !choices('offer_trade').length) return;
    const others = state.players.filter(player => player.seat !== state.viewer && !player.bankrupt);
    $('trade-target').replaceChildren(...others.map(player => { const option = text('option', player.display_name); option.value = String(player.seat); return option; }));
    populateTrade(); $('trade-dialog').showModal();
  }
  function populateTrade() {
    give.clear(); take.clear();
    const other = Number($('trade-target').value);
    $('give-cash').max = String(state.players[state.viewer].cash); $('take-cash').max = String(state.players[other].cash);
    $('give-cash').value = '0'; $('take-cash').value = '0';
    for (const [owner, set, prefix] of [[state.viewer, give, 'give'], [other, take, 'take']]) {
      const nodes = state.properties.filter(item => item.owner === owner).map(card => {
        const developed = state.properties.some(item => item.group === card.group && item.buildings > 0);
        let tile;
        tile = StarGamesCardTile(face(card), {label: name(card), caption: developed ? 'Sell buildings first' : card.mortgaged ? 'Mortgaged' : '$' + card.price, onSelect() { if (developed) return; if (set.has(card.id)) set.delete(card.id); else set.add(card.id); tile.classList.toggle('is-selected', set.has(card.id)); tile.setAttribute('aria-pressed', String(set.has(card.id))); }});
        tile.disabled = developed; tile.dataset.property = String(card.id); tile.setAttribute('aria-pressed', 'false'); return tile;
      });
      $(prefix + '-properties').replaceChildren(nodes.length ? StarGamesCardGrid(nodes, {cardWidth: 108}) : text('p', 'No properties.'));
      $(prefix + '-jail').replaceChildren(...(state.players[owner].jail_decks || []).map(deck => { const label = document.createElement('label'), input = document.createElement('input'); input.type = 'checkbox'; input.value = deck; label.append(input, text('span', deck + ' Jail Free card')); return label; }));
    }
  }
  $('trade-form').addEventListener('submit', event => {
    event.preventDefault(); if (locked()) return;
    const giveCash = Number($('give-cash').value), takeCash = Number($('take-cash').value);
    if (!Number.isSafeInteger(giveCash) || !Number.isSafeInteger(takeCash) || giveCash < 0 || takeCash < 0) return;
    const selected = prefix => [...$(prefix + '-jail').querySelectorAll('input:checked')].map(input => input.value);
    if (send({action: 'offer_trade', to: Number($('trade-target').value), give_cash: giveCash, take_cash: takeCash, give_properties: [...give], take_properties: [...take], give_jail: selected('give'), take_jail: selected('take')})) $('trade-dialog').close();
  });
  $('trade-target').addEventListener('change', populateTrade);
  $('trade').addEventListener('click', openTrade);
  $('cancel-trade').addEventListener('click', () => $('trade-dialog').close());
  $('replay').addEventListener('click', () => send({action: 'replay'}));
  $('help').addEventListener('click', () => $('help-dialog').showModal());
  $('close-help').addEventListener('click', () => $('help-dialog').close());
  StarGamesDismissOnOutside($('trade-dialog')); StarGamesDismissOnOutside($('help-dialog'));
  matchMedia('(prefers-reduced-motion: reduce)').addEventListener('change', () => { if (reduced()) { clearTimeout(localTimer); localMoving = false; updateLocks(); } });
  setInterval(renderClocks, 250);
  controller.connect();
})();
