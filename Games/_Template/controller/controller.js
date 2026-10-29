(() => {
  // Optional personal turn glow: toggle the shared .game-turn-glow class only
  // on this controller's own identity when the authoritative turn matches it.
  "use strict";
  const gameId = "replace-with-game-id";
	const exampleCard = StarGamesCard({ name: "EXAMPLE", value: 1 });
	exampleCard.hidden = true;
	document.querySelector(".game-controller").append(exampleCard);
	const exampleCharacter = StarGamesCard({layout:'character',caption_style:'paper',name:'Envoy',detail:'Character ability',foot:'Public counteraction'}, {color:'#278eac'});
	exampleCharacter.hidden = true;
	document.querySelector(".game-controller").append(exampleCharacter);
  // Optional composed cards: StarGamesCard(card,{art,color,onSelect}).
  // layout:'deal' opts into a 2:3 complete face with a live semantic name.
  // Optional shared card-table surfaces: game-table on body, game-paper-card
  // on a game-paper section, game-hand-dock-felt on its existing hand dock,
  // and game-player-chip with --player-color for compact public navigation.
  // StarGamesCardReader shows full-screen cards with validated action callbacks,
  // and showReference([{src,alt},{src,alt}]) adds Back and a front/back flip.
  // StarGamesCard({layout:'character',name:'Envoy',detail:'Ability',foot:'Counteraction'},
  //   {art:'/game/my-game/art/envoy.png',color:'#278eac'}) keeps names/rules live
  // over full portrait artwork. Native GameCard uses the same semantic fields.
  const exampleReader = new StarGamesCardReader();
  // After showCard, setSubtitle("Owned by …") supplies public ownership.
  // Public cash changes use host timing and live name rectangles. Return null
  // for players absent from this view; never derive money from local input.
  // Optional coin/token formatting; omit the options for default dollar cash.
  const exampleMoney = new StarGamesMoneyEffect(() => null, {amountPrefix:'', amountBadge:false, showTransfers:false, resolveFontSize:()=>parseFloat(getComputedStyle(exampleCard).fontSize), resolveFont:()=>getComputedStyle(exampleCard).font});
  exampleMoney.update({revision: 0, money: [], active: false});
  new StarGamesDragScroll(exampleCard);
  // For a virtual card fan, optional getOffset/setOffset callbacks use pixels;
  // isEnabled, onStart and onEnd retain the module's movement/input locks.
  // setRotation({side,label,onRotate,reduced,animate}) adds an icon to the reader.
  // StarGamesCardMotion(resolveRect, renderFace).update(snapshot.motion, {paused,
  // reduced}) draws finite flights above the table. Only the host owns the clock,
  // cards and legal inputs; redact all other players' hidden pickup faces.
  // Optional flight hold seconds stay at the source within duration;
  // easing:'smooth' gives a gradual departure/arrival instead of cubic ease-out.
  // Card tables can opt into .game-card-controller on main, shared compact
  // controls, and .game-hand-dock on the private-hand section. Dock geometry
  // can use --game-hand-dock-width and --game-hand-dock-left in landscape.
  // StarGamesHandDock(hand, toolbar) keeps the same action buttons above the
  // hand in portrait, restoring their original placement in landscape.
  // The SDK applies payload.theme.revision automatically before message().
  // Keep canonical local asset URLs so host and phone resolve the same skin.
  const connection = document.querySelector("#connection");
  const action = document.querySelector("#action");
  // Reuse lobby colors/poses for a public player choice. Exclude the owner with
  // setPlayers(players, viewer); validate and confirm its selectedSeat on the host.
  // An optional third constructor argument, "assembly", selects outlined busts.
  const examplePlayers = [{display_name: "PLAYER ONE", color: "#2463eb", pose: 0}, {display_name: "PLAYER TWO", color: "#e53935", pose: 1}];
  // alive:false mutes that seat in the shared turn strip. Apply
  // game-seat-eliminated to public artwork while keeping OUT help readable.
  const eliminatedExample = StarGamesTurnStrip([{...examplePlayers[0],alive:false},examplePlayers[1]],1,{tracked:true});
  eliminatedExample.hidden = true; document.querySelector('main').append(eliminatedExample);
  const partySeat = document.querySelector("#example-party-seat");
  StarGamesTableUI.partySeat(partySeat,examplePlayers[0].color);
  partySeat.append(StarGamesTableUI.avatar(examplePlayers[0]), document.createTextNode("PLAYER ONE"), StarGamesTableUI.stat("cards", 7, "Seven cards"));
  StarGamesTableUI.handBrowse(document.querySelector('#example-party-browse'),1,3);
  // Optional context-only actions use the same floating helper without dimming.
  const contextExample=new StarGamesPlayerFocus({onAction:id=>{ void id; }});
  contextExample.update({context:true,prompt:'Special actions',actions:[{id:'example',label:'EXAMPLE'}]});contextExample.update();
  // A replay inside an existing action slot opts out of separate footer placement.
  const inlineReplayExample=document.createElement('button');inlineReplayExample.className='game-board-replay';inlineReplayExample.dataset.gameInlineAction='';inlineReplayExample.hidden=true;partySeat.append(inlineReplayExample);
  // Seat geometry can set --game-seat-columns, --game-seat-avatar-row,
  // --game-seat-avatar-size, --game-seat-padding and --game-seat-justify.
  // Keep .is-current authoritative and preserve the existing button on sync.
  // Set .is-winner only for a confirmed winner; current turns have no crown.
  const playerPicker = new StarGamesPlayerPicker(document.querySelector("#example-player-picker"), seat => {
    document.querySelector("#example-player-selection").textContent = seat < 0 ? "Choose a player icon" : examplePlayers[seat].display_name;
  });
  playerPicker.setPlayers(examplePlayers);
  const controller = new StarGamesController(gameId, {
    connected: player => { connection.textContent = `Connected as ${player.display_name}`; controller.send({ action: "sync" }); },
    disconnected: () => { connection.textContent = "Reconnecting…"; },
    message: payload => { document.querySelector("#status").textContent = payload.status || "Message received"; },
    error: message => { connection.textContent = message.message; }
  });
  action.addEventListener("click", () => controller.send({ action: "pressed" }));
  document.querySelector("#show-options").addEventListener("click", () => document.querySelector("#options").showModal());
  document.querySelector("#close-options").addEventListener("click", () => document.querySelector("#options").close());
  // Optional compact art-panel controls restore normal touch sizing when wrapped.
  const fitChoice = () => document.querySelector("#example-choice").classList.toggle("game-compact-control", innerWidth >= 1100);
  window.addEventListener("resize", fitChoice);
  fitChoice();
  // A single dot button cycles sizes without replacing a held input target.
  for (const tool of ["Brush", "Eraser"]) {
    let exampleSize = 1;
    document.querySelector("#example-" + tool.toLowerCase() + "-cycle").addEventListener("click", event => {
      exampleSize = (exampleSize + 1) % 3;
      const names = ["Small", "Medium", "Large"], sizes = [4, 9, 18];
      event.currentTarget.setAttribute("aria-label", tool + " size: " + names[exampleSize] + ". Tap for " + names[(exampleSize + 1) % 3] + ".");
      event.currentTarget.querySelector(".game-brush-dot").style.setProperty("--brush-dot-size", sizes[exampleSize] + "px");
    });
  }
  // Optional shared modern-table components use caller-supplied public values.
  const modernExample = document.querySelector('#example-modern-table');
  document.getElementById('example-table-decision-close')?.addEventListener('click',()=>document.getElementById('example-table-decision').close());
  if (modernExample && window.StarGamesTableUI) {
    modernExample.append(StarGamesTurnStrip(examplePlayers,0,{tracked:true}));
    // One shared surface may combine public assets, identity and a private hand.
    // Put .own-zone, .hand-topline, .private-hand and .action-bar inside the dock.
    const combinedExample=document.createElement('section');combinedExample.className='hand-dock';
    for(const className of ['player-zone own-zone','hand-topline','private-hand','action-bar']){const part=document.createElement('div');part.className=className;combinedExample.append(part);}
    modernExample.append(combinedExample);const releaseExampleDock=StarGamesHandDock.combine(modernExample,combinedExample);addEventListener('pagehide',releaseExampleDock,{once:true});
    modernExample.append(StarGamesCard({layout:'deal',kind:'property',name:'EXAMPLE',mortgaged:true,deed_state:{area:[25,122,190,147],accent:'#2463eb',badge:'1 HOUSE',icon:'house',rows:[{label:'RENT',value:'$2',active:false},{label:'With 1 House',value:'$10',active:true}]}}));
    modernExample.append(StarGamesTableUI.avatar(examplePlayers[0],true));
    modernExample.append(StarGamesTableUI.winner());
    modernExample.append(StarGamesTableUI.setBars([{id:1,color:'blue',cards:[],complete:false}],{blue:{name:'Blue',color:'#2463eb',size:2}}));
    // data-table-layout="roster" on a modern-table game-controller opts into
    // the all-player grid without piles. sortGroups orders complete sets first.
    // Reader setPreview can accept onSelect for a host-validated card chooser;
    // setRotation animates only when animate:true follows an explicit press.
    modernExample.append(StarGamesTableUI.stat('bank','$5','Bank: $5'),StarGamesTableUI.stat('cards',7,'7 cards in hand'),StarGamesTableUI.stat('house','1/3','1 of 3 complete sets'));
    modernExample.append(StarGamesTableUI.group({label:'Example',color:'#2463eb',count:0,size:3,rent:0,complete:false},[],()=>{}));
    modernExample.append(StarGamesCardGrid([StarGamesCardTile(StarGamesCard({id:1,name:'EXAMPLE',value:1}),{label:'Example payment card',caption:'$1',selected:true,onSelect:()=>{}}),StarGamesCardPlaceholder(),StarGamesCardPlaceholder()],{cardWidth:144}));
    // is-dark keeps navy slots in other palettes, including disabled empty slots.
    // Counts are supplied by the module from the viewer's authorized inventory.
    const countedTile=StarGamesCardTile(StarGamesCard({id:'example-counted',name:'Example card',value:1}),{label:'Example card, 2 owned',onSelect:()=>{}}),emptyTile=StarGamesCardTile(StarGamesCardPlaceholder(),{label:'Example card, not owned',onSelect:()=>{}});
    emptyTile.disabled=true;StarGamesButtonBadge(countedTile,2);StarGamesButtonBadge(emptyTile,0);
    const darkGrid=StarGamesCardGrid([countedTile,emptyTile]);darkGrid.classList.add('is-dark');modernExample.append(darkGrid);
    modernExample.append(StarGamesCard({id:'symbol',layout:'symbol',name:'Choose',detail:'Pick any two tokens.',foot:'Public reference',accent:'#397c91'},{art:'/ui/playful/stat-resources.svg'}));
    // Read-only public collections can instead use a single-row strip. It fits
    // three cards on phones, at most four at full width, and supports mouse/touch
    // dragging, keyboard scrolling, and tap-to-read without submitting commands.
    modernExample.append(StarGamesCardStrip([StarGamesCard({id:1,name:'EXAMPLE',value:1}),StarGamesCardPlaceholder(),StarGamesCardPlaceholder(),StarGamesCardPlaceholder()],{label:'Example public cards'}));
    // reader.setPreview keeps a card on the left and host-supplied consequences
    // on the right on wide screens; portrait phones stack a large card above
    // its preview. Omit setPreview when no legal choices exist so read-only
    // action cards use the normal full-size reader. Selection never sends a
    // command; Play still validates.
    exampleReader.setPreview([{label:'Example action',summary:'Public consequences',players:[{...examplePlayers[1],amount:2}],cards:[]}]);
    // The optional players presentation shows all targets with public bank fans.
    exampleReader.setPreview([{label:'Example player',players:[{...examplePlayers[1],bank_total:1}],cards:[StarGamesCard({id:1,name:'EXAMPLE',value:1})]}],{presentation:'players'});
    // Card choices group all candidates by owner and role without a dropdown.
    exampleReader.setPreview([{label:'Take card',summary:'Take a public card',players:[],groups:[{key:'take',value:1,owner:1,label:'Take',player:examplePlayers[1],cards:[StarGamesCard({id:1,name:'EXAMPLE',value:1})]}]}],{presentation:'cards'});
    // Reference readers include an accessible corner flip icon and dismiss on
    // outside clicks. Other sheets can opt into the same pointer-aware helper.
    StarGamesDismissOnOutside(document.getElementById('example-table-decision'));
    const exampleEffect=new StarGamesCardEffect(card=>StarGamesCard(card));
    exampleEffect.update({revision:0,effects:[]});
  }
  const standardExample=document.getElementById('example-standard-cards');
  if(standardExample&&typeof StarGamesCard==='function')standardExample.append(StarGamesCard({layout:'standard',rank:'A',suit:'spades',name:'Ace of spades'}),StarGamesCard({layout:'standard',back:true}));
  controller.connect();
  // Hidden opt-in examples: public rows inspect without issuing game commands;
  // the map camera keeps targets at 44px by projecting their normalized points.
  // Add data-game-board-trailing to a utility row after a playfield to reserve
  // its observed height alongside the private-hand/action footer.
  const cameraWrapper=document.createElement('div');cameraWrapper.hidden=true;document.querySelector('main').append(cameraWrapper);
  // An active full-screen example adds data-game-board-fit to its normal anchor.
  // The SDK fits that anchor while the camera surface can paint beyond it.
  const cameraFit=document.createElement('div');cameraFit.className='game-map-fit';cameraFit.style.cssText='width:180px;height:180px';cameraWrapper.append(cameraFit);
  const cameraExample=document.createElement('div');cameraExample.className='game-board-canvas';cameraWrapper.append(cameraExample);
  const cameraSurface=document.createElementNS('http://www.w3.org/2000/svg','svg');cameraExample.append(cameraSurface);
  const hitExample=document.createElement('button');hitExample.className='game-board-hit-target';hitExample.setAttribute('aria-label','Inspect an example map site');cameraExample.append(hitExample);
  const controlsExample=document.createElement('div');controlsExample.className='game-board-controls is-dark';cameraWrapper.append(controlsExample);
  const exampleCamera=new StarGamesBoardCamera(cameraExample,{fitElement:cameraFit});
  const rowExample=new StarGamesPlayerRow(()=>exampleCamera.reset());
  rowExample.leader='silver'; // Explicit tied-lead indicator, independent of turn.
  const inventorySection=document.createElement('section');inventorySection.className='game-table-section';cameraWrapper.append(inventorySection);
  // is-compact fits short sections/hands; has-inline-header places header beside content.
  const inventoryExample=new StarGamesResourceHand(()=>exampleCamera.reset());inventorySection.append(inventoryExample.element);
  inventoryExample.update([{icon:'/ui/playful/table-cards.svg',label:'Example resource',amount:3,color:'#27ad68'}]);
  inventorySection.append(StarGamesCostRow([{icon:'/ui/playful/stat-resources.svg',label:'Example material',owned:1,required:1,available:true}],{iconOnly:true,compact:true}));
  const exchangeExample=new StarGamesExchangeButton(()=>{}, {label:'Example exchange',confirmationLabel:'CONFIRM'});inventorySection.append(exchangeExample.element);exchangeExample.update([{giveIcon:'/ui/playful/table-cards.svg',takeIcon:'/ui/playful/stat-resources.svg',owned:3,rate:3,label:'Have 3 cards. Exchange 3 for 1 resource.'}]);
  rowExample.element.classList.add('is-detailed','has-headline','has-identity-turn-outline','is-dark');
  rowExample.update({display_name:'Example player',color:'#2463eb',pose:0},[{icon:'/ui/playful/table-cards.svg',value:7,label:'Public card count'}],true,{icon:'/ui/playful/stat-victory.svg',value:2,label:'Public points'});cameraWrapper.append(rowExample.element);
  cameraWrapper.append(StarGamesTurnStrip([{display_name:'Example player',color:'#2463eb'}],0,{tracked:true,actions:['Played a public card']}));
  const statGridExample=new StarGamesStatGrid();statGridExample.element.classList.add('is-dark');statGridExample.update([{icon:'/ui/playful/stat-victory.svg',value:2,label:'Public points',highlighted:true}]);cameraWrapper.append(statGridExample.element);
  cameraWrapper.append(StarGamesCostRow([{icon:'/ui/playful/table-cards.svg',label:'One required card',available:false}]));
  const countedCost=StarGamesCostRow([{icon:'/ui/playful/table-cards.svg',label:'Example material',owned:2,required:3,available:false}],{highlightCounts:true,iconOnly:true,compact:true});countedCost.classList.add('is-dark');cameraWrapper.append(countedCost);
  // game-dialog-soft supplies a lighter backdrop for board phase prompts.
  const softPrompt=document.createElement('dialog');softPrompt.className='game-dialog game-dialog-soft';cameraWrapper.append(softPrompt);
  StarGamesButtonBadge(rowExample.element,2);
  // showReference(pages,{fit:true}) fits both faces without a reader scrollbar.
  // Paragraph feeds opt into game-activity-separated/game-activity-bold-latest.
  addEventListener('pagehide',()=>exampleCamera.destroy(),{once:true});
  const rulesExample=document.getElementById('example-rules-dialog');
  // Feed eligible badge elements and public obstacles only; clear on exit/pause.
  const playerFocusExample=new StarGamesPlayerFocus();
  playerFocusExample.update({targets:[],prompt:'Choose a player.'});
  if(rulesExample){document.getElementById('example-rules-close').addEventListener('click',()=>rulesExample.close());StarGamesDismissOnOutside(rulesExample);}
  const rankedExample=document.getElementById('example-ranked-results');
  const casinoRange=document.getElementById('example-casino-range');
  if(casinoRange&&window.StarGamesTableUI){const badge=document.createElement('div');badge.className='game-casino-player';badge.append(StarGamesTableUI.avatar(examplePlayers[0]),document.createTextNode('Example player'));casinoRange.parentElement.append(badge);}
  if(casinoRange&&window.StarGamesTableUI){StarGamesTableUI.range(casinoRange);casinoRange.addEventListener('input',()=>StarGamesTableUI.range(casinoRange));}
  if(rankedExample&&window.StarGamesRankedResults){
    const ranked=new StarGamesRankedResults(rankedExample,{amountIcon:'/ui/playful/table-cash.svg'});
    ranked.setEntries([{rank:1,seat:0,name:'Example winner',category:'Royal Flush',amount:100,marked_cards:[0],card_mark:'HOLE',cards:[{layout:'standard',rank:'A',suit:'spades',name:'Ace of spades'}]},{rank:2,seat:1,name:'Example loss',category:'One Pair',amount:-100,cards:[]}]);
    ranked.fit(160);
  }
})();
