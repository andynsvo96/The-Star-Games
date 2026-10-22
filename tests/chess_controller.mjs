// Isolated Chess, shared controller layout and Debug phone preview checks. No browser package required.
// Usage: node tests/chess_controller.mjs [path-to-chrome]
import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {resolve, join, extname, sep} from 'node:path';
import {spawn} from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const output = join(root, '.test_data', 'chess-controller');
const chrome = process.argv[2] || process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

async function protocol(url) {
	const socket = new WebSocket(url), requests = new Map();
	let id = 0;
	socket.addEventListener('message', event => {
		const message = JSON.parse(event.data), pending = requests.get(message.id);
		if (pending) { requests.delete(message.id); message.error ? pending.reject(new Error(JSON.stringify(message.error))) : pending.resolve(message.result); }
	});
	await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, {once:true}); socket.addEventListener('error', reject, {once:true}); });
	return {socket, send(method, params = {}) {
		return new Promise((resolve, reject) => { requests.set(++id, {resolve,reject}); socket.send(JSON.stringify({id,method,params})); });
	}};
}
const opening = [-4,-2,-3,-5,-6,-3,-2,-4,...Array(8).fill(-1),...Array(32).fill(0),...Array(8).fill(1),4,2,3,5,6,3,2,4];
const snapshot = {
	board: opening, players: [{id:'phone',display_name:'Royal Player',color:'#cf2337'},{id:'other',display_name:'Opponent',color:'#195fc0'}],
	turn:1, legal_moves:[{from:52,to:44,promotion:0,capture:-1},{from:52,to:36,promotion:0,capture:-1}],
	last_move:{},guidance:true,outcome:0,result_reason:'',paused:false,animating:false,
	revision:0,round_id:'1',session_wins:[0,0],draws:0,clock_seconds:0,remaining:[0,0],clock_running:false,check:false,
	history:'No completed games yet.',moves:[],status:"Game 1: Royal Player's turn (White)."
};
const boot = `
window.qaState = ${JSON.stringify(snapshot)};
window.qaSent = [];
class StarGamesController extends window.StarGamesController {
	constructor(id, handlers) { super(id, handlers); window.qaHandlers = handlers; this.handlers = handlers; }
	connect() { this.handlers.connected({id:'phone',display_name:'Royal Player',color:'#cf2337'}); this.handlers.message(structuredClone(qaState)); }
	send(input) { qaSent.push(input); }
}
window.StarGamesController = StarGamesController;
const scenery = document.createElement('img'); scenery.className = 'game-background'; scenery.src = '/game/chess/art/royal-study.png'; scenery.alt = ''; document.body.prepend(scenery);
`;
const assertions = `
(async () => {
	let checks = 0;
	const check = (ok, message) => { checks++; if (!ok) throw new Error(message); };
	const cells = [...document.querySelectorAll('#board > button')];
	const publish = patch => { qaState = {...qaState, ...patch}; qaHandlers.message(structuredClone(qaState)); };
	try {
		check(cells.length === 64 && document.querySelectorAll('#board button img').length === 32, 'Opening pieces render');
		check(!document.querySelector('#board button .coordinate') && document.querySelectorAll('.board-coordinates span').length === 32, 'Coordinates occupy four frame edges while squares stay clear');
		check(document.querySelector('.board-coordinates.bottom').textContent === 'abcdefgh' && document.querySelector('.board-coordinates.left').textContent === '87654321', 'White coordinates match square indexes');
		cells[52].click(); check(cells[36].classList.contains('destination'), 'Guidance highlights legal destinations');
		cells[36].click(); check(qaSent.at(-1).action === 'move' && qaSent.at(-1).from === 52 && qaSent.at(-1).to === 36 && qaSent.at(-1).revision === 0, 'Tap sends an authoritative move request');
		publish({guidance:false,revision:1}); cells[52].click();
		check(!cells[36].classList.contains('destination'), 'Guidance can be switched off');
		cells[36].click(); check(qaSent.at(-1).action === 'move', 'Guidance off preserves input');
		publish({revision:2,paused:true}); check(cells.every(cell => cell.disabled), 'Disconnect snapshot disables placement');
		qaHandlers.disconnected(); check(document.getElementById('connection').textContent.includes('Reconnecting'), 'Connection loss shows reconnection feedback');
		qaHandlers.connected({id:'phone',display_name:'Royal Player'}); publish({revision:3,paused:false,guidance:true});
		check(document.querySelectorAll('#board button img').length === 32 && !cells[52].disabled, 'Reconnect restores the complete board');
		publish({players:[qaState.players[1],qaState.players[0]],turn:2,round_id:'2',revision:4});
		check(cells[63].style.order === '0' && document.getElementById('black-player').textContent.includes('Black'), 'Black perspective rotates visual order without changing indexes');
		check(document.querySelector('.board-coordinates.bottom').textContent === 'hgfedcba' && document.querySelector('.board-coordinates.left').textContent === '12345678', 'Black coordinates rotate with the board after sync');
		const promoted = Array(64).fill(0); promoted[4] = -6; promoted[60] = 6; promoted[8] = 1;
		publish({players:[qaState.players[1],qaState.players[0]],board:promoted,turn:1,round_id:'3',revision:5,legal_moves:[{from:8,to:0,promotion:5,capture:-1},{from:8,to:0,promotion:2,capture:-1}]});
		cells[8].click(); cells[0].click(); check(document.getElementById('promotion').open, 'Promotion offers an explicit choice');
		document.querySelector('[data-promotion="2"]').click(); check(qaSent.at(-1).promotion === 2, 'Underpromotion request carries the selected piece');
		publish({outcome:1,result_reason:'Checkmate',session_wins:[1,0],revision:6});
		check(!document.getElementById('replay').hidden && cells.every(cell => cell.disabled), 'A completed board shows one replay control and disables moves');
		publish({outcome:0,board:${JSON.stringify(opening)},round_id:'4',revision:7,turn:1,last_move:{},session_wins:[1,0],legal_moves:[{from:52,to:36,promotion:0,capture:-1}]});
		check(document.getElementById('replay').hidden && document.getElementById('white-score').textContent === '1 WIN', 'Replay restores play and session wins');
		publish({clock_seconds:73,remaining:[73,73],clock_running:false,revision:8});
		check(document.getElementById('white-clock').textContent === '1:13', 'Custom clock renders non-preset values');
		publish({animating:true}); check(cells.every(cell => cell.disabled), 'Authoritative movement lock disables input');
		publish({animating:false,clock_seconds:0,session_wins:[0,0],revision:9});
		check(document.getElementById('white-clock').hidden && document.getElementById('black-clock').hidden && document.querySelectorAll('.game-stat-grid .game-stat-item').length === 12, 'Untimed games free clock space while keeping all piece counts');
		check(!document.querySelector('#board [title]'), 'Board has no hover text');
		await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
		check(document.documentElement.scrollWidth <= innerWidth, 'Controller has no horizontal overflow');
		check(document.querySelector('header').getBoundingClientRect().top <= 20, 'Game heading starts near the top in both orientations');
		const board = document.getElementById('board').getBoundingClientRect();
		check(board.left >= 0 && board.right <= innerWidth && board.bottom <= innerHeight, 'Full board fits in the viewport');
		const beforeReplay = board.top;
		publish({outcome:1,result_reason:'Checkmate',revision:10});
		await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
		check(Math.abs(document.getElementById('board').getBoundingClientRect().top - beforeReplay) < 1 && document.getElementById('replay').getBoundingClientRect().bottom <= innerHeight, 'Replay fits without shifting the board: ' + JSON.stringify({before:beforeReplay,after:document.getElementById('board').getBoundingClientRect().top,replayBottom:document.getElementById('replay').getBoundingClientRect().bottom,height:innerHeight}));
		publish({outcome:0,revision:11});
		check(!document.getElementById('moves') && ![...document.querySelectorAll('summary')].some(item => /moves.*help/i.test(item.textContent)), 'Moves and Help is removed');
		check(!document.querySelector('#claim,#offer,#accept,#resign,#resign-confirm') && ![...document.querySelectorAll('button')].some(item => /claim draw|offer draw|accept draw|resign/i.test(item.textContent)), 'Draw and resignation controls are removed');
		check(!document.querySelector('#perspective,#guidance,#clock-setting,#session-scores,#history,.game-details,header .eyebrow'), 'Player screen omits host options, history, perspective note and extra title');
		const contains = (inner, outer) => inner.left >= outer.left-1 && inner.right <= outer.right+1 && inner.top >= outer.top-1 && inner.bottom <= outer.bottom+1;
		const players = qaState.players;
		publish({players:players.map((p,index) => ({...p,display_name:index?'A longer opponent player name':'A longer royal player name'})),session_wins:[1234,5678],clock_seconds:86400,remaining:[86400,86400],revision:12});
		await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
		check(document.body.classList.contains('game-royal') && document.querySelectorAll('.game-ledger').length === 2, 'Chess inherits the shared royal palette and both framed-paper cards');
		check([...document.querySelectorAll('.game-ledger')].every(card => {
			const rect = card.getBoundingClientRect(), style = getComputedStyle(card);
			const inner = {left:rect.left+parseFloat(style.borderLeftWidth)+parseFloat(style.paddingLeft),right:rect.right-parseFloat(style.borderRightWidth)-parseFloat(style.paddingRight),top:rect.top+parseFloat(style.borderTopWidth)+parseFloat(style.paddingTop),bottom:rect.bottom-parseFloat(style.borderBottomWidth)-parseFloat(style.paddingBottom)};
			return [...card.querySelectorAll('p,output,.game-stat-clock,.game-stat-grid img,.game-stat-grid span')].every(item => {
				if (!contains(item.getBoundingClientRect(),inner)) return false;
				if (item.tagName === 'IMG') return true;
				const range = document.createRange(); range.selectNodeContents(item);
				return [...range.getClientRects()].every(rect => contains(rect,inner));
			});
		}), 'Long names, large wins, clocks, icons and count text fit inside the framed-paper margins');
		publish({players,session_wins:[0,0],clock_seconds:0,remaining:[0,0],revision:13});
		await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
		const report = document.createElement('meta'); report.name = 'chess-test-result'; report.content = JSON.stringify({checks,failures:0}); document.head.append(report);
	} catch (error) {
		const report = document.createElement('meta'); report.name = 'chess-test-result'; report.content = JSON.stringify({checks,failures:1,error:String(error)}); document.head.append(report);
	}
})();
`;

let html = await readFile(join(root, 'Games/chess/controller/index.html'), 'utf8');
html = html.replace('href="style.css"', 'href="/game/chess/controller/style.css"')
	.replace('<script src="/controller-sdk.js"></script>', `<script src="/controller-sdk.js"></script><script>${boot}</script>`)
	.replace('src="board-motion.js"', 'src="/game/chess/controller/board-motion.js"')
	.replace('src="controller.js"', 'src="/game/chess/controller/controller.js"')
	.replace('</body>', `<script>${assertions}</script></body>`);
const types = {'.html':'text/html','.css':'text/css','.js':'application/javascript','.svg':'image/svg+xml','.png':'image/png'};
const fixtures = new Map([['chess', html]]);
for (const id of ['tic-tac-toe','four-in-a-row','checkers','_Template']) {
	const count = {'tic-tac-toe':9,'four-in-a-row':42,checkers:64,_Template:0}[id];
	const board = Array(count).fill(0);
	if (id === 'checkers') for (let cell=0; cell<64; cell++) {
		if ((Math.floor(cell/8)+cell%8)%2) board[cell] = cell<24?2:cell>=40?1:0;
	}
	const state = {...snapshot,board,winning_cells:[],winning_lines:[],legal_moves:id === 'checkers' ? [{from:40,to:33,capture:-1}] : [],forced_from:-1,force_jump:true,counts:[{men:12,kings:0},{men:12,kings:0}],status:'Game 1: Royal Player’s turn.'};
	const stem = {'tic-tac-toe':'garden','four-in-a-row':'vintage-arcade',checkers:'tournament-hall'}[id];
	const setup = `
	window.qaState = ${JSON.stringify(state)};
	window.qaSent = [];
	class TestController extends window.StarGamesController {
		constructor(id, handlers) { super(id, handlers); this.handlers = handlers; window.qaHandlers = handlers; }
		connect() { this.handlers.connected({id:'phone',display_name:'Royal Player',color:'#cf2337'}); this.handlers.message(structuredClone(qaState)); }
		send(input) { qaSent.push(input); }
	}
	window.StarGamesController = TestController;
	${stem ? `const scenery = document.createElement('img'); scenery.className = 'game-background'; scenery.src = '/game/${id}/art/${stem}.png'; scenery.alt = ''; document.body.prepend(scenery);` : ''}
	`;
	const checks = `
	(async () => {
		let checks = 0;
		const check = (ok, message) => { checks++; if (!ok) throw new Error(message); };
		const settle = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
		try {
			await settle();
			const board = document.getElementById('board'), replay = document.getElementById('replay');
			check(board.hasAttribute('data-game-board') && replay.classList.contains('game-board-replay'), 'Module inherits the shared layout');
			check(document.documentElement.scrollWidth <= innerWidth, 'No horizontal overflow');
			check(document.querySelector('header').getBoundingClientRect().top <= 20, 'Game heading starts near the top in both orientations');
			check(!document.querySelector('#help,#perspective,.game-note'), 'Below-board instruction notes are absent');
			const before = board.getBoundingClientRect();
			check(before.left >= 0 && before.right <= innerWidth && before.bottom <= innerHeight, 'Board fits the viewport');
			qaHandlers.disconnected();
			check(document.getElementById('connection').textContent.includes('Reconnecting'), 'Connection feedback');
			qaHandlers.connected({id:'phone',display_name:'Royal Player',color:'#cf2337'}); qaHandlers.message(structuredClone(qaState));
			check(document.getElementById('status').textContent === qaState.status, 'Reconnect restores host status');
			qaState.outcome = 1; qaState.revision++; qaHandlers.message(structuredClone(qaState)); replay.hidden = false;
			await settle();
			check(Math.abs(board.getBoundingClientRect().top-before.top)<1 && replay.getBoundingClientRect().bottom<=innerHeight, 'Replay fits without moving the board');
			qaState.outcome = 0; qaState.revision++; qaHandlers.message(structuredClone(qaState)); replay.hidden = true;
			check(!document.querySelector('button[title],#board [title]'), 'No hover text');
			${id === 'four-in-a-row' ? `
			const cells = [...board.querySelectorAll(':scope > button')], preview = board.querySelector('.column-preview');
			const publish = patch => { qaState = {...qaState,...patch}; qaHandlers.message(structuredClone(qaState)); };
			cells[2].dispatchEvent(new PointerEvent('pointerenter'));
			check(!preview.hidden && preview.dataset.target === '37' && getComputedStyle(preview).pointerEvents === 'none', 'Column guide shows the empty landing slot without intercepting input');
			publish({animating:true}); const sent = qaSent.length;
			cells[3].click(); cells[2].dispatchEvent(new PointerEvent('pointerenter'));
			check(preview.hidden && qaSent.length === sent, 'Host movement hides preview and discards taps');
			publish({animating:false,paused:true}); check(preview.hidden, 'Disconnect pause hides preview');
			publish({paused:false}); check(!preview.hidden && qaSent.length === sent, 'Unlock restores preview without replaying taps');
			const next = [...qaState.board]; next[38] = 1;
			publish({board:next,revision:++qaState.revision});
			check(matchMedia('(prefers-reduced-motion: reduce)').matches || preview.hidden, 'Local falling disc also hides preview');
			if (!matchMedia('(prefers-reduced-motion: reduce)').matches) {
				publish({animating:false}); cells[3].click();
				check(preview.hidden && qaSent.length === sent, 'Early host unlock still discards taps until local bounce settles');
				await new Promise(resolve => setTimeout(resolve,800));
			}
			cells[3].dispatchEvent(new PointerEvent('pointerenter'));
			check(!preview.hidden && preview.dataset.target === '31' && qaSent.length === sent, 'After landing the guide advances to the next empty row without queued input');
			publish({board:Array(42).fill(0),round_id:'preview-reset',revision:++qaState.revision});
			` : ''}
			${id === 'checkers' ? `
			const cells = [...board.querySelectorAll(':scope > button')];
			cells[40].click();
			check(cells[40].classList.contains('game-selection-ring') && getComputedStyle(cells[40],'::before').borderRadius === '50%' && getComputedStyle(cells[40],'::before').pointerEvents === 'none', 'Selected piece has a circular input-transparent ring');
			qaState.paused = true; qaHandlers.message(structuredClone(qaState));
			check(!board.querySelector('.game-selection-ring'), 'Pause clears the piece ring');
			qaState.paused = false; qaHandlers.message(structuredClone(qaState));
			` : ''}
			${id !== '_Template' ? `check(!document.querySelector('#session-scores,#history,.game-details,header .eyebrow'), 'Host session panels and extra title are absent from players');` : ''}
			${id === 'checkers' ? `qaState.clock_seconds = 93; qaState.remaining = [93,60]; qaState.clock_running = false; qaHandlers.message(structuredClone(qaState)); check(!document.getElementById('red-clock').hidden && document.getElementById('red-clock').textContent === '1:33' && document.getElementById('black-clock').textContent === '1:00', 'Read-only custom timer restores on sync'); qaState.clock_seconds = 0; qaHandlers.message(structuredClone(qaState)); check(document.getElementById('red-clock').hidden, 'Optional timer stays hidden when disabled');` : ''}
			${id === '_Template' ? `
              document.getElementById('show-options').click(); check(document.getElementById('options').open, 'Shared options dialog'); document.getElementById('close-options').click();
              const rulesExample=document.getElementById('example-rules-dialog'),rulesList=rulesExample.querySelector('.game-rules-list'),rule=rulesList.querySelector('.game-rule-item');
              for(let row=0;row<12;row++)rulesList.append(rule.cloneNode(true));
              rulesExample.showModal();const rulesBounds=rulesExample.getBoundingClientRect(),closeRules=document.getElementById('example-rules-close').getBoundingClientRect();
              check(rulesBounds.top>=0&&rulesBounds.bottom<=innerHeight&&closeRules.bottom<=innerHeight,'Shared rules dialog scrolls long lists while Close stays reachable');
              document.getElementById('example-rules-close').click();check(!rulesExample.open,'Template rules dialog closes through its visible action');
            ` : ''}
			const report = document.createElement('meta'); report.name = 'chess-test-result'; report.content = JSON.stringify({checks,failures:0}); document.head.append(report);
		} catch (error) {
			const report = document.createElement('meta'); report.name = 'chess-test-result'; report.content = JSON.stringify({checks,failures:1,error:String(error)}); document.head.append(report);
		}
	})();`;
	let source = await readFile(join(root, 'Games', id, 'controller/index.html'), 'utf8');
	source = source.replace('href="style.css"', `href="/game/${id}/controller/style.css"`)
		.replace('<script src="/controller-sdk.js"></script>', `<script src="/controller-sdk.js"></script><script>${setup}</script>`)
		.replace('src="board-motion.js"', `src="/game/${id}/controller/board-motion.js"`)
		.replace('src="controller.js"', `src="/game/${id}/controller/controller.js"`)
		.replace('</body>', `<script>${checks}</script></body>`);
	fixtures.set(id, source);
}
// Exercise the actual lobby page with a local, offline host-message fixture.
const lobbySetup = `
window.qaSent = [];
class TestSocket extends EventTarget {
    static OPEN = 1;
    constructor() { super(); this.readyState = 1; window.qaSocket = this; queueMicrotask(() => this.deliver({type:'hello',host_name:'The Star Games',lobby_open:true})); }
    send(input) { qaSent.push(JSON.parse(input)); }
    deliver(data) { this.dispatchEvent(new MessageEvent('message', {data:JSON.stringify(data)})); }
}
window.WebSocket = TestSocket;
`;
const lobbyAssertions = `
(async () => {
    let checks = 0;
    const check = (ok, message) => { checks++; if (!ok) throw new Error(message); };
    const settle = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    try {
        await settle();
        check(!document.querySelector('.brand .star,.brand .eyebrow'), 'Lobby omits the animated star and Welcome to');
        check(document.getElementById('title').getBoundingClientRect().top < 60, 'Remaining lobby UI starts near the top');
        const form = document.getElementById('join-form');
        check(!form.hidden && !form.querySelector('button').disabled, 'Join controls remain available');
        document.getElementById('player-name').value = 'Royal Player'; form.dispatchEvent(new Event('submit', {cancelable:true}));
        check(qaSent.at(-1).type === 'join' && qaSent.at(-1).name === 'Royal Player', 'Join uses the existing host connection');
        const player = {id:'phone',display_name:'Royal Player',color:'#ffdf00',pose:0};
        qaSocket.deliver({type:'joined',player,reconnect_token:'fixture',lobby_open:true});
        qaSocket.deliver({type:'roster',players:[player]});
        await settle();
        check(!document.getElementById('joined').hidden && form.hidden && document.querySelectorAll('#colors button').length === 16, 'Identity and all color choices remain available after joining');
        check(document.getElementById('title').getBoundingClientRect().top < 60 && document.getElementById('joined').getBoundingClientRect().top < innerHeight && document.documentElement.scrollWidth <= innerWidth, 'Joined controls and heading stay near the top without horizontal overflow');
        qaSocket.deliver({type:'lobby_state',lobby_open:false});
        check([...document.querySelectorAll('#colors button')].every(button => button.disabled), 'Host lobby lock still disables color changes');
        qaSocket.deliver({type:'lobby_state',lobby_open:true});
        const report = document.createElement('meta'); report.name = 'chess-test-result'; report.content = JSON.stringify({checks,failures:0}); document.head.append(report);
    } catch(error) {
        const report = document.createElement('meta'); report.name = 'chess-test-result'; report.content = JSON.stringify({checks,failures:1,error:String(error)}); document.head.append(report);
    }
})();`;
const lobbyHtml = (await readFile(join(root,'web/index.html'), 'utf8')).replace('<script src="/app.js" defer></script>', `<script>${lobbySetup}</script><script src="/app.js"></script><script>${lobbyAssertions}</script>`);
fixtures.set('lobby', lobbyHtml);
let debugFixture = 'chess';
const server = createServer(async (request, response) => {
	try {
		const url = new URL(request.url, 'http://127.0.0.1'), path = url.pathname;
		if (path === '/') { response.writeHead(200, {'Content-Type':'text/html'}); response.end(fixtures.get(url.searchParams.get('game') || debugFixture)); return; }
		const file = resolve(root, path.startsWith('/game/') ? 'Games/' + path.slice(6) : (path.startsWith('/ui/') ? path.slice(1) : 'web/' + path.slice(1)));
		if (!file.startsWith(root + sep)) throw new Error('Unsafe test asset path');
		const body = await readFile(file);
		response.writeHead(200, {'Content-Type':types[extname(file)] || 'application/octet-stream'}); response.end(body);
	} catch { response.writeHead(404); response.end(); }
});
await mkdir(output, {recursive:true});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const port = server.address().port;
let failed = false;
const profile = join(output,'render-profile-'+process.pid);
const child = spawn(chrome, ['--headless','--no-sandbox','--disable-gpu','--no-first-run','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${profile}`], {windowsHide:true,stdio:['ignore','ignore','pipe']});
let endpoint;
const endpointReady = new Promise((resolve, reject) => {
	child.on('error', reject);
	child.stderr.on('data', chunk => { const match = String(chunk).match(/DevTools listening on (ws:\/\/[^\s]+)/); if (match) resolve(match[1]); });
});
let browser;
let startupTimer;
try {
	endpoint = await Promise.race([endpointReady, new Promise((_, reject) => { startupTimer = setTimeout(() => reject(new Error('Chromium renderer did not start')), 15000); })]);
	clearTimeout(startupTimer);
	browser = await protocol(endpoint);
	const target = await browser.send('Target.createTarget', {url:'about:blank'});
	const port = new URL(endpoint).port;
	const tabs = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
	const page = await protocol(tabs.find(tab => tab.id === target.targetId).webSocketDebuggerUrl);
	await page.send('Page.enable');
	for (const id of fixtures.keys()) for (const [name,width,height,reduced] of [['portrait',390,844,false],['landscape',844,390,false],['tablet',768,1024,false],['reduced',390,844,true]]) {
		await page.send('Emulation.setDeviceMetricsOverride', {width,height,deviceScaleFactor:1,mobile:false});
		await page.send('Emulation.setEmulatedMedia', {features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
		await page.send('Page.navigate', {url:`http://127.0.0.1:${server.address().port}/?game=${id}&view=${name}`});
		let value;
		for (let attempt=0; attempt<100; attempt++) {
			await delay(50);
			const reply = await page.send('Runtime.evaluate', {expression:'document.querySelector(\'meta[name="chess-test-result"]\')?.content',returnByValue:true});
			value = reply.result.value;
			if (value) break;
		}
		if (!value) throw new Error(id + '/' + name + ': browser did not finish assertions');
		const result = JSON.parse(value);
		await delay(250);
		const screenshot = await page.send('Page.captureScreenshot', {format:'png',captureBeyondViewport:false});
		await writeFile(join(output,id+'-'+name+'.png'), Buffer.from(screenshot.data,'base64'));
		if (id === '_Template') {
			await page.send('Runtime.evaluate', {expression:"document.querySelectorAll('details.game-scroll-details').forEach(sheet => sheet.open = true); document.querySelector('details.game-scroll-details').scrollIntoView({block:'start'});"});
			await delay(100);
			const papers = await page.send('Page.captureScreenshot', {format:'png',captureBeyondViewport:false});
			await writeFile(join(output,id+'-'+name+'-scrolls.png'), Buffer.from(papers.data,'base64'));
		}
		console.log(id + '/' + name + ': ' + JSON.stringify(result));
		failed ||= result.failures > 0;
	}
	// A real iframe must keep phone media queries/viewport units even when browser
	// chrome clamps the outer window or the desktop is too small to show it at 1:1.
	for (const id of fixtures.keys()) for (const [name,width,height] of [['window',500,900],['small-window',320,600]]) {
		debugFixture = id;
		await page.send('Emulation.setDeviceMetricsOverride', {width,height,deviceScaleFactor:1,mobile:false});
		await page.send('Page.navigate', {url:`http://127.0.0.1:${server.address().port}/debug.html?width=390&height=844`});
		let value;
		for (let attempt=0; attempt<100; attempt++) {
			await delay(50);
			const reply = await page.send('Runtime.evaluate', {expression:`(() => {
				const frame = document.querySelector('iframe');
				const result = frame?.contentDocument.querySelector('meta[name="chess-test-result"]')?.content;
				if (!result) return null;
				const bounds = frame.getBoundingClientRect();
				return {report:JSON.parse(result),width:frame.contentWindow.innerWidth,height:frame.contentWindow.innerHeight,
					portrait:frame.contentWindow.matchMedia('(orientation: portrait)').matches,
					fits:bounds.left >= -1 && bounds.top >= -1 && bounds.right <= innerWidth + 1 && bounds.bottom <= innerHeight + 1};
			})()`,returnByValue:true});
			value = reply.result.value;
			if (value) break;
		}
		if (!value || value.width !== 390 || value.height !== 844 || !value.portrait || !value.fits || value.report.failures) throw new Error(`Debug ${id}/${name}: ${JSON.stringify(value)}`);
		if (name === 'window') {
			const screenshot = await page.send('Page.captureScreenshot', {format:'png',captureBeyondViewport:false});
			await writeFile(join(output,id+'-debug.png'), Buffer.from(screenshot.data,'base64'));
		}
		console.log(`Debug ${id}/${name}: 390 x 844 viewport, preview fits; ${value.report.checks} controller checks passed`);
	}
	// Navigate and refresh the controller without replacing the outer preview.
	await page.send('Runtime.evaluate', {expression:"document.querySelector('iframe').src = '/?game=lobby'"});
	await delay(250);
	await page.send('Runtime.evaluate', {expression:"document.querySelector('iframe').contentWindow.location.reload()"});
	await delay(250);
	const navigation = await page.send('Runtime.evaluate', {expression:"(() => { const frame = document.querySelector('iframe'); return location.pathname === '/debug.html' && frame.contentWindow.location.search === '?game=lobby' && frame.contentWindow.innerWidth === 390 && frame.contentWindow.innerHeight === 844; })()",returnByValue:true});
	if (!navigation.result.value) throw new Error('Debug navigation/refresh did not preserve the phone viewport');
	console.log('Debug navigation and refresh preserve the phone viewport');
	page.socket.close();
} finally {
	clearTimeout(startupTimer);
	if (browser) { await browser.send('Browser.close').catch(() => {}); browser.socket.close(); }
	else child.kill();
	await new Promise(resolve => server.close(resolve));
}
if (failed) process.exitCode = 1;
