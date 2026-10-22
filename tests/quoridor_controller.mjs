// Offline controller behavior and layout fixtures. Node 22+ and Chromium.
import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {resolve, join, extname, sep} from 'node:path';
import {spawn} from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const output = join(root, '.test_data', 'quoridor-controller');
const chrome = process.argv[2] || process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function protocol(url) {
	const socket = new WebSocket(url), requests = new Map(); let id = 0;
	socket.addEventListener('message', event => {
		const message = JSON.parse(event.data), pending = requests.get(message.id);
		if (pending) { requests.delete(message.id); message.error ? pending.reject(new Error(JSON.stringify(message.error))) : pending.resolve(message.result); }
	});
	await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, {once:true}); socket.addEventListener('error', reject, {once:true}); });
	return {socket, send(method, params = {}) { return new Promise((resolve, reject) => { requests.set(++id,{resolve,reject}); socket.send(JSON.stringify({id,method,params})); }); }};
}
const initial = {
	pawns:[76,4],walls:[],remaining:[10,10],players:[{id:'phone',display_name:'Garden [Player]',color:'#25b3ab'},{id:'other',display_name:'Opponent',color:'#e8794b'}],
	turn:1,outcome:0,revision:0,round_id:'1',legal_moves:[67,75,77],legal_walls:[{row:3,col:3,orientation:'h'},{row:3,col:3,orientation:'v'},{row:4,col:4,orientation:'h'}],
	paused:false,animating:false,reduced_motion:false,last_action:{},session_wins:[0,0],status:"Game 1: Garden [Player]'s turn",history:'No completed games yet.'
};
const boot = `
window.qaState = ${JSON.stringify(initial)}; window.qaSent = [];
class FixtureController extends window.StarGamesController {
	constructor(id, handlers) { super(id,handlers); window.qaHandlers = handlers; this.handlers = handlers; }
	connect() { this.handlers.connected({id:'phone',display_name:'Garden [Player]',color:'#25b3ab'}); this.handlers.message(structuredClone(qaState)); }
	send(input) { qaSent.push(input); }
}
window.StarGamesController = FixtureController;
`;
const assertions = `
(async () => {
	let checks = 0;
	const check = (ok, message) => { checks++; if (!ok) throw new Error(message); };
	const publish = patch => { qaState = {...qaState,...patch}; qaHandlers.message(structuredClone(qaState)); };
	const settle = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
	const cell = index => document.querySelector('[data-cell="'+index+'"]');
	const anchor = (row,col) => document.querySelector('[data-row="'+row+'"][data-col="'+col+'"]');
	const board = document.querySelector('#board');
	try {
		check(document.querySelectorAll('.quoridor-cell').length === 81 && document.querySelectorAll('.quoridor-pawn').length === 2, 'Exact 9x9 board and two pawns');
		check(document.getElementById('one-player').textContent === 'Garden [Player]' && document.getElementById('one-walls').textContent === '10 WALLS', 'Literal identity and wall stock restore');
		check(document.querySelectorAll('.destination').length === 3, 'Only three legal opening squares highlight');
		check(document.querySelector('#wall > img').getAttribute('src') === '/ui/playful/control-wall.svg' && document.querySelectorAll('aside:not([hidden]) .game-illustrated-stat').length === 4, 'Buttons and stat counters use shared illustrated assets');
		publish({remaining:[0,10]});
		check(document.getElementById('wall').disabled && getComputedStyle(document.getElementById('wall')).backgroundColor === 'rgb(191, 195, 202)' && getComputedStyle(document.querySelector('#wall > img')).filter.includes('grayscale'), 'Empty wall stock greys out both control and icon');
		document.getElementById('wall').click(); check(anchor(3,3).hidden, 'Grey Wall control cannot enter placement mode');
		publish({remaining:[10,10],legal_walls:[]}); check(document.getElementById('wall').disabled, 'No legal wall placements disables the Wall control');
		publish({legal_walls:${JSON.stringify(initial.legal_walls)}});
		cell(67).click(); check(qaSent.at(-1).action === 'move' && qaSent.at(-1).to === 67 && qaSent.at(-1).revision === 0, 'Pawn tap submits a revision-bound input');
		const count = qaSent.length; cell(67).click(); check(qaSent.length === count, 'Pending input cannot be submitted twice');
		publish({revision:1}); await settle(); const beforeWall = board.getBoundingClientRect(); document.getElementById('wall').click(); await settle();
		check(Math.abs(board.getBoundingClientRect().width-beforeWall.width) < 1 && Math.abs(board.getBoundingClientRect().top-beforeWall.top) < 1, 'Wall confirmation does not shrink or shift the board: '+JSON.stringify({before:{top:beforeWall.top,width:beforeWall.width},after:{top:board.getBoundingClientRect().top,width:board.getBoundingClientRect().width},controls:document.getElementById('controls').offsetHeight,reserve:getComputedStyle(board.parentElement).getPropertyValue('--game-board-bottom-room')}));
		check(!anchor(3,3).hidden && !anchor(3,3).disabled && anchor(0,0).disabled, 'Wall mode only enables authoritative legal anchors');
		check(getComputedStyle(anchor(0,0),'::after').backgroundColor === 'rgb(154, 157, 161)', 'Blocked wall junctions have visible grey markers');
		anchor(3,3).click(); check(document.querySelectorAll('.preview').length === 1 && qaSent.length === count, 'Preview does not mutate authoritative state');
		document.getElementById('rotate').click(); check(document.getElementById('status').textContent.includes('Vertical'), 'Rotate updates the wall preview');
		document.getElementById('confirm').click(); check(qaSent.at(-1).action === 'wall' && qaSent.at(-1).orientation === 'v' && qaSent.at(-1).row === 3 && qaSent.at(-1).col === 3, 'Confirmation submits one complete wall');
		publish({revision:2}); document.getElementById('wall').click(); anchor(3,3).click(); document.getElementById('move').click();
		check(!document.querySelector('.preview') && anchor(3,3).hidden, 'Move cancels a wall preview');
		publish({revision:3,paused:true}); check([...document.querySelectorAll('#board button')].every(button=>button.disabled), 'Paused state disables every input');
		qaHandlers.disconnected(); check(document.getElementById('connection').textContent.includes('Reconnecting'), 'Connection loss shows reconnection status');
		qaHandlers.connected({id:'phone',display_name:'Garden [Player]'}); publish({revision:4,paused:false});
		check(!cell(67).disabled && document.querySelectorAll('.quoridor-pawn').length === 2, 'Reconnect restores original pawn input');
		publish({revision:5,players:[qaState.players[1],qaState.players[0]],turn:2,legal_moves:[13,3,5],round_id:'2'});
		check(Number.parseFloat(cell(4).style.top) > 80 && Number.parseFloat(cell(76).style.top) < 10, 'Second phone sees its pawn at the bottom without changing indexes');
		document.getElementById('wall').click(); anchor(3,3).click(); document.getElementById('confirm').click();
		check(qaSent.at(-1).row === 3 && qaSent.at(-1).col === 3, 'Rotated perspective preserves authoritative wall anchors');
		publish({revision:6,players:[qaState.players[1],qaState.players[0]],turn:1,legal_moves:[67,75,77],round_id:'3',pawns:[76,4],walls:[{row:4,col:4,orientation:'h',side:2}],remaining:[10,9]});
		check(document.querySelectorAll('.quoridor-wall:not(.preview)').length === 1 && document.getElementById('two-walls').textContent === '9 WALLS', 'Walls and counters restore from sync');
		check(document.querySelector('.quoridor-wall').getBoundingClientRect().height >= Math.max(6,board.clientWidth*89/9*.0029)-.2, 'Placed walls remain thicker than the grooves on every viewport');
		publish({revision:7,pawns:[67,4],turn:2,legal_moves:[13,3,5],animating:true,last_action:{action:'move',side:1,from:76,to:67}});
		const movingCount = qaSent.length; cell(13).click(); check(qaSent.length === movingCount, 'Movement taps are discarded');
		publish({revision:7,animating:false}); await new Promise(resolve=>setTimeout(resolve,300));
		publish({revision:8,turn:1,legal_moves:[58,66,68,76],animating:true});
		check(cell(58).disabled, 'Authoritative lock survives local settling');
		publish({revision:8,animating:false}); check(!cell(58).disabled, 'Input resumes only when host and local movement settle');
		publish({revision:9,reduced_motion:true,pawns:[58,4],last_action:{action:'move',side:1,from:67,to:58},turn:2});
		check(document.body.classList.contains('has-reduced-motion') && document.querySelector('.quoridor-pawn').getAnimations().length === 0, 'Host reduced motion places pawns immediately');
		publish({revision:10,turn:1,legal_moves:[49],animating:false});
		await settle(); const before = board.getBoundingClientRect();
		publish({revision:11,outcome:1,pawns:[0,4],legal_moves:[],legal_walls:[],session_wins:[1,0],status:'Garden [Player] wins!'});
		await settle();
		check(!document.getElementById('replay').hidden && [...document.querySelectorAll('#board button')].every(button=>button.disabled), 'Single replay control after a decisive board');
		check(Math.abs(board.getBoundingClientRect().top-before.top) < 1, 'Winning does not shift the board');
		document.getElementById('replay').click(); check(qaSent.at(-1).action === 'play_again' && qaSent.at(-1).revision === 11, 'Replay carries the current revision');
		publish({revision:12,outcome:0,round_id:'4',pawns:[76,4],turn:1,legal_moves:[67,75,77],legal_walls:${JSON.stringify(initial.legal_walls)},remaining:[10,10],walls:[],last_action:{}});
		check(document.getElementById('replay').hidden && document.getElementById('one-score').textContent === '1 WIN', 'Replay preserves session wins');
		check(!document.querySelector('#board [title]') && !document.querySelector('.game-sidebar'), 'No hover popups or phone settings/history');
		await settle();
		check(document.documentElement.scrollWidth <= innerWidth, 'No horizontal overflow');
		const bounds = board.getBoundingClientRect();
		check(bounds.left >= -1 && bounds.right <= innerWidth+1 && bounds.bottom <= innerHeight, 'Entire board fits');
		check(Math.abs(bounds.width-bounds.height) < 1, 'Board remains square');
		check(document.querySelector('header').getBoundingClientRect().top < 25, 'Shared heading starts near top');
		const controlBounds = document.getElementById('controls').getBoundingClientRect();
		check(controlBounds.bottom <= innerHeight && controlBounds.left >= -1 && controlBounds.right <= innerWidth+1, 'Move/wall controls remain reachable');
		publish({revision:13,outcome:1,pawns:[0,4],session_wins:[1,0],legal_moves:[],legal_walls:[]}); await settle();
		check(document.getElementById('replay').getBoundingClientRect().bottom <= innerHeight, 'Play Again fits without scrolling');
		publish({revision:14,outcome:0,round_id:'5',pawns:[76,4],turn:1,legal_moves:[67,75,77],legal_walls:${JSON.stringify(initial.legal_walls)},walls:[{row:3,col:3,orientation:'h',side:2}],remaining:[10,9],last_action:{},status:'Game 5: Garden [Player]\\'s turn'});
		const starts = [76,36,4,44];
		for (let side = 1; side <= 4; side++) {
			const players = ['South','West','North','East'].map((name,index) => ({id:index===side-1?'phone':'seat-'+index,display_name:name,color:['#25b3ab','#e8794b','#2463eb','#8f62cc'][index]}));
			publish({revision:15+side,outcome:0,round_id:'four-'+side,pawns:starts,remaining:[5,5,5,5],players,turn:side,session_wins:[0,0,0,0],legal_moves:[[67,75,77],[27,37,45],[3,5,13],[35,43,53]][side-1],legal_walls:[{row:1,col:5,orientation:'h'}],walls:[{row:2,col:4,orientation:'h',side:1}],last_action:{},status:players[side-1].display_name+"'s turn"});
			await settle();
			check(document.querySelectorAll('.quoridor-pawn').length === 4 && document.querySelectorAll('aside:not([hidden])').length === 4 && document.querySelector('#four-walls').textContent === '5 WALLS', 'Four pawns and counters restore for seat '+side);
			check(Number.parseFloat(cell(starts[side-1]).style.top)>80 && Math.abs(Number.parseFloat(cell(starts[side-1]).style.left)-45.352)<.1, 'Seat '+side+' sees its own starting edge at the bottom');
			const placed = document.querySelector('.quoridor-wall');
			check(side%2 ? placed.clientWidth>placed.clientHeight : placed.clientHeight>placed.clientWidth, 'Quarter-turn views swap wall geometry for seat '+side);
			document.getElementById('wall').click(); anchor(1,5).click();
			check(!document.getElementById('confirm').disabled && document.querySelector('.preview'), 'Seat '+side+' previews authoritative walls');
			document.getElementById('confirm').click();
			check(qaSent.at(-1).action==='wall' && qaSent.at(-1).row===1 && qaSent.at(-1).col===5 && qaSent.at(-1).orientation==='h', 'Seat '+side+' sends unrotated wall indexes and orientation');
		}
		publish({revision:20,reduced_motion:false,pawns:[76,36,4,43],turn:4,animating:true,last_action:{action:'move',side:4,from:44,to:43},legal_moves:[42]});
		check(cell(42).disabled && (matchMedia('(prefers-reduced-motion: reduce)').matches || document.querySelectorAll('.quoridor-pawn')[3].getAnimations().length===1), 'Fourth pawn movement locks input and uses its own visual');
		publish({revision:20,animating:false});
		if (!matchMedia('(prefers-reduced-motion: reduce)').matches) check(cell(42).disabled, 'Fourth pawn waits for local motion after the host unlocks');
		await new Promise(resolve=>setTimeout(resolve,280));
		check(!cell(42).disabled, 'Fourth pawn unlocks only after movement settles');
		publish({revision:21,outcome:4,pawns:[76,36,4,36],session_wins:[0,0,0,1],legal_moves:[],legal_walls:[],status:'East wins!',last_action:{}}); await settle();
		check(document.querySelector('#four-score').textContent==='1 WIN' && !replay.hidden && cell(36).classList.contains('winner'), 'Fourth-seat victory has correct highlight, score and replay');
		const fourBounds = board.getBoundingClientRect();
		check(document.documentElement.scrollWidth<=innerWidth && fourBounds.left>=-1 && fourBounds.right<=innerWidth+1 && fourBounds.bottom<=innerHeight && replay.getBoundingClientRect().bottom<=innerHeight, 'Four-player board and replay fit without scrolling');
		publish({revision:21,outcome:0,round_id:'four-replay',pawns:starts,turn:2,remaining:[5,5,5,5],legal_moves:[27,37,45],legal_walls:[{row:1,col:5,orientation:'h'}],last_action:{}});
		check(document.querySelector('#four-score').textContent==='1 WIN' && replay.hidden, 'Four-player replay preserves wins');
		publish({revision:22,players:qaState.players.map((player,index)=>({...player,id:'spectator-seat-'+index}))});
		check(document.querySelector('#controls').hidden && replay.hidden && document.querySelector('#status').textContent.startsWith('Watching:') && [...document.querySelectorAll('#board button')].every(button=>button.disabled), 'Unseated phones watch with no gameplay or replay controls');
		qaHandlers.disconnected(); qaHandlers.connected({id:'phone',display_name:'Garden [Player]'});
		publish({revision:23,round_id:'four-final',players:[{id:'phone',display_name:'Garden [Player]',color:'#25b3ab'},{id:'other',display_name:'Opponent',color:'#e8794b'},{id:'computer',display_name:'Computer 1',color:'#2463eb'},{id:'computer-2',display_name:'Computer 2',color:'#8f62cc'}],pawns:starts,turn:1,outcome:0,remaining:[5,5,5,5],legal_moves:[67,75,77],legal_walls:${JSON.stringify(initial.legal_walls)},session_wins:[1,0,0,0],walls:[{row:3,col:3,orientation:'h',side:2}],status:'Garden [Player]\\'s turn'}); await settle();
		check(!cell(67).disabled && document.querySelectorAll('.quoridor-pawn').length===4, 'Four-player reconnect restores input and every pawn');
		const report = document.createElement('meta'); report.name = 'quoridor-test-result'; report.content = JSON.stringify({checks,failures:0}); document.head.append(report);
	} catch(error) { const report = document.createElement('meta'); report.name = 'quoridor-test-result'; report.content = JSON.stringify({checks,failures:1,error:String(error)}); document.head.append(report); }
})();`;
const originalHtml = await readFile(join(root,'Games/quoridor/controller/index.html'),'utf8');
const fixture = originalHtml.replace('href="style.css"','href="/game/quoridor/controller/style.css"').replace('<script src="controller.js"></script>',`<script>${boot}</script><script src="/game/quoridor/controller/controller.js"></script><script>${assertions}</script>`);
const types = {'.html':'text/html','.js':'text/javascript','.css':'text/css','.svg':'image/svg+xml','.png':'image/png','.json':'application/json','.wav':'audio/wav'};
const server = createServer(async (request,response) => {
	try {
		const url = new URL(request.url,'http://127.0.0.1');
		if (url.pathname === '/') { response.writeHead(200,{'Content-Type':'text/html'}); response.end(fixture); return; }
		if (url.pathname === '/game/quoridor/background.json') { response.writeHead(200,{'Content-Type':'application/json'}); response.end(JSON.stringify({image:'/game/quoridor/art/courtyard.png',videos:[]})); return; }
		const file = resolve(root, url.pathname.startsWith('/game/') ? 'Games/'+url.pathname.slice(6) : url.pathname.startsWith('/ui/') ? url.pathname.slice(1) : 'web/'+url.pathname.slice(1));
		if (!file.startsWith(root+sep)) throw new Error('Unsafe asset path');
		const body = await readFile(file);
		response.writeHead(200,{'Content-Type':types[extname(file)]||'application/octet-stream'}); response.end(body);
	} catch { response.writeHead(404); response.end(); }
});
await mkdir(output,{recursive:true}); await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const child = spawn(chrome,['--headless','--no-sandbox','--disable-gpu','--no-first-run','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${join(output,'profile-'+process.pid)}`],{windowsHide:true,stdio:['ignore','ignore','pipe']});
const ready = new Promise((resolve,reject)=>{ child.on('error',reject); child.stderr.on('data',chunk=>{ const match = String(chunk).match(/DevTools listening on (ws:\/\/[^\s]+)/); if (match) resolve(match[1]); }); });
let browser, timer, failed = false;
try {
	const endpoint = await Promise.race([ready,new Promise((_,reject)=>{ timer = setTimeout(()=>reject(new Error('Chromium did not start')),15000); })]); clearTimeout(timer);
	browser = await protocol(endpoint);
	const target = await browser.send('Target.createTarget',{url:'about:blank'});
	const tabs = await (await fetch(`http://127.0.0.1:${new URL(endpoint).port}/json/list`)).json();
	const page = await protocol(tabs.find(tab=>tab.id===target.targetId).webSocketDebuggerUrl); await page.send('Page.enable');
	for (const [name,width,height,reduced] of [['portrait',390,844,false],['landscape',844,390,false],['small',320,568,false],['tablet',768,1024,false],['desktop',1280,720,false],['reduced',390,844,true]]) {
		await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
		await page.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
		await page.send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/?view=${name}`});
		let value;
		for (let attempt=0; attempt<100; attempt++) { await delay(50); const reply = await page.send('Runtime.evaluate',{expression:'document.querySelector(\'meta[name="quoridor-test-result"]\')?.content',returnByValue:true}); value = reply.result.value; if (value) break; }
		if (!value) throw new Error(name+': assertions did not finish');
		const result = JSON.parse(value); console.log(name+': '+JSON.stringify(result)); failed ||= result.failures > 0;
		await delay(180); const screenshot = await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false}); await writeFile(join(output,name+'.png'),Buffer.from(screenshot.data,'base64'));
		if (!result.failures) {
			await page.send('Runtime.evaluate',{expression:"qaHandlers.message({...structuredClone(qaState),remaining:[0,9]});"});
			await delay(100); const disabled = await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false}); await writeFile(join(output,name+'-disabled.png'),Buffer.from(disabled.data,'base64'));
			await page.send('Runtime.evaluate',{expression:"qaHandlers.message(structuredClone(qaState));"});
			await page.send('Runtime.evaluate',{expression:"document.getElementById('wall').click(); if (document.getElementById('rotate').getAttribute('aria-label').endsWith('horizontal')) document.getElementById('rotate').click(); document.querySelector('[data-row=\"4\"][data-col=\"4\"]').click();"});
			await delay(100); const preview = await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false}); await writeFile(join(output,name+'-wall.png'),Buffer.from(preview.data,'base64'));
		}
	}
	page.socket.close();
} finally {
	clearTimeout(timer); if (browser) { await browser.send('Browser.close').catch(()=>{}); browser.socket.close(); } else child.kill();
	await new Promise(resolve=>server.close(resolve));
}
if (failed) process.exitCode = 1;
