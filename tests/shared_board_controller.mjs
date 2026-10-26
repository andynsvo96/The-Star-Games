// Self-contained shared board/footer layout regression. Node 22+ and Chromium.
// Uses only public shared browser assets; no installed game or rendered fixture.
import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {resolve, join, extname, sep} from 'node:path';
import {spawn} from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const output = join(root, '.test_data', 'shared-board-controller');
const chrome = process.argv[2] || process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

async function protocol(url) {
	const socket = new WebSocket(url), requests = new Map();
	let id = 0;
	socket.addEventListener('message', event => {
		const message = JSON.parse(event.data), pending = requests.get(message.id);
		if (pending) {
			requests.delete(message.id);
			message.error ? pending.reject(new Error(JSON.stringify(message.error))) : pending.resolve(message.result);
		}
	});
	await new Promise((resolve, reject) => {
		socket.addEventListener('open', resolve, {once:true});
		socket.addEventListener('error', reject, {once:true});
	});
	return {socket, send(method, params = {}) {
		return new Promise((resolve, reject) => {
			requests.set(++id, {resolve, reject});
			socket.send(JSON.stringify({id, method, params}));
		});
	}};
}

const assertions = `
(async () => {
	let checks = 0;
	const check = (ok, message) => { checks++; if (!ok) throw new Error(message); };
	const settle = async () => { for (let frame = 0; frame < 10; frame++) await new Promise(requestAnimationFrame); };
	const board = document.querySelector('#board'), replay = document.querySelector('#replay');
	const footer = document.querySelector('.game-board-stats'), status = document.querySelector('#status');
	const count = Number(new URLSearchParams(location.search).get('seats'));
	const presentation = new URLSearchParams(location.search).get('cards');
	const run = Number(new URLSearchParams(location.search).get('run'));
	const measure = () => ({board:board.getBoundingClientRect().toJSON(), footer:footer.getBoundingClientRect().toJSON()});
	const layout = caption => {
		const {board:b, footer:f} = measure();
		check(Math.abs(b.width - b.height) < 1 && b.width >= 44, caption + ': square usable board');
		check(b.left >= -1 && b.right <= innerWidth + 1 && b.top >= 0 && b.bottom <= innerHeight + 1, caption + ': board stays in viewport');
		check(status.getBoundingClientRect().bottom <= b.top + 1, caption + ': status precedes board');
		check(f.top >= b.bottom - 1 && f.bottom <= innerHeight + 1, caption + ': complete stats follow board');
		check(document.documentElement.scrollWidth <= innerWidth && document.documentElement.scrollHeight <= innerHeight + 1, caption + ': no page scrollbars ' + JSON.stringify({width:innerWidth,height:innerHeight,...measure(),scrollWidth:document.documentElement.scrollWidth,scrollHeight:document.documentElement.scrollHeight}));
		check(footer.scrollWidth <= footer.clientWidth + 1 && footer.scrollHeight <= footer.clientHeight + 1, caption + ': footer has no internal overflow');
		check([...footer.children].every(card => [card, ...card.children].every(element => element.scrollWidth <= element.clientWidth + 1)), caption + ': names and counters fit cards');
		return measure();
	};
	const unchanged = (before, after, caption) => check(['x','y','width','height'].every(key => Math.abs(before[key] - after[key]) < 1), caption + ' ' + JSON.stringify({before,after,controls:document.querySelector('.game-board-controls').getBoundingClientRect().toJSON()}));
	try {
		await document.fonts.ready;
		window.qaLayout = new StarGamesBoardLayout(board, replay);
		await settle();
		check(footer.children.length === count, 'Synthetic roster contains requested seat count');
		check(!document.querySelector('[title]'), 'Synthetic controls omit hover tooltips');
        const cameraView=document.createElement('div');cameraView.style.cssText='position:fixed;left:-2000px;top:0;width:240px;height:180px';const surface=document.createElement('div');cameraView.append(surface);document.body.append(cameraView);
        const camera=new StarGamesBoardCamera(cameraView,{surface});let selected=0;cameraView.addEventListener('click',()=>selected++);
        cameraView.dispatchEvent(new WheelEvent('wheel',{deltaY:-300,clientX:-1880,clientY:90,bubbles:true,cancelable:true}));check(camera.zoom>1,'Shared inline wheel magnifies the map');
        const pointer=(type,id,x,y,target=cameraView)=>target.dispatchEvent(new PointerEvent(type,{pointerId:id,clientX:-2000+x,clientY:y,button:0,bubbles:true,cancelable:true,pointerType:'touch'}));
        pointer('pointerdown',1,60,80);pointer('pointermove',1,100,110,window);pointer('pointerup',1,100,110,window);cameraView.click();check(selected===0&&camera.pan.x>0,'Shared map drag suppresses gameplay click');
        camera.reset();pointer('pointerdown',2,60,80);pointer('pointerdown',3,120,80);pointer('pointermove',3,180,80,window);pointer('pointerup',3,180,80,window);pointer('pointerup',2,60,80,window);check(camera.zoom>1,'Shared touch pinch magnifies inline');
        const z=camera.zoom;camera.cancel();pointer('pointermove',3,220,80,window);check(camera.zoom===z,'Canceled gesture cannot move the map later');
        camera.reset();check(camera.zoom===1&&camera.pan.x===0&&camera.pan.y===0,'Shared fit restores the camera');camera.destroy();cameraView.remove();
        const row=new StarGamesPlayerRow(()=>{});row.update({display_name:'Name <tag> [literal]',color:'#000000',pose:0},[{icon:'/ui/playful/table-cards.svg',label:'Public cards',value:7}],true);const original=row.element;
        row.update({display_name:'Updated player',color:'#ffffff',pose:1},[{icon:'/ui/playful/table-cards.svg',label:'Public cards',value:8}],false);check(row.element===original&&row.element.getAttribute('aria-label').includes('Public cards: 8')&&!row.element.querySelector('tag'),'Shared player updates preserve the accessible target and literal names');

		const opening = layout('Initial');
		status.replaceChildren(document.createTextNode('Your turn.'), document.createElement('br'), document.createTextNode('Select a piece.'));
		await settle();
		unchanged(opening.board, layout('Two-line status').board, 'Two-line status retains board placement');
		replay.hidden = false;
		status.replaceChildren(document.createTextNode('Round completed.'), document.createElement('br'), document.createTextNode('Play again when ready.'));
		await settle();
		const result = layout('Result and replay');
		unchanged(opening.board, result.board, 'Result and replay retain board placement');
		const replayBefore = replay.getBoundingClientRect().toJSON();
		check(replayBefore.top >= result.board.bottom && replayBefore.bottom <= result.footer.top + 1 && replayBefore.height >= 44, 'Replay is a reachable 44px action between board and stats');
		status.textContent = 'Your turn.';
		await settle();
		unchanged(result.board, layout('Short status restored').board, 'Restoring a short status retains board placement');
		unchanged(replayBefore, replay.getBoundingClientRect().toJSON(), 'Status changes retain replay placement');
		const names = [...footer.querySelectorAll('[data-player-name]')];
		for (const [index, name] of names.entries()) name.textContent = index % 2 ? 'A Very Long Player Name 12345678' : '<Star & Player> 1234567890123456';
		await settle();
		const longNames = layout('Long names');
		check(!footer.querySelector('star'), 'Player names remain literal text');
		check(longNames.footer.height >= opening.footer.height - 1, 'Wrapping names retain sufficient footer height');
		if (longNames.footer.height > opening.footer.height + 1) {
			check(longNames.board.width <= opening.board.width + 1, 'Observed footer growth updates board fitting');
		}
		if (presentation === 'ledger') {
			const card = footer.firstElementChild;
			check(parseFloat(getComputedStyle(card).borderTopWidth) <= 10 && parseFloat(getComputedStyle(card.querySelector('p')).fontSize) <= 13, 'Template ledger cards inherit compact shared footer styling');
		} else {
			check(parseFloat(getComputedStyle(footer.firstElementChild).fontSize) <= 13 && parseFloat(getComputedStyle(footer.querySelector('output')).fontSize) <= 13, 'Session scores inherit compact shared footer styling');
		}
		replay.hidden = true;
		await settle();
		unchanged(longNames.board, layout('Replay hidden').board, 'Hiding replay preserves reserved board geometry');
		// Feedback geometry must not depend on a party-table ancestor. Use a
		// deliberately large intrinsic portrait to reproduce overflow on phones.
		const feedback = document.createElement('div'), picture = document.createElement('img'), words = document.createElement('span');
		feedback.className = 'game-table-feedback'; feedback.hidden = true;
		picture.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="1024" height="1536"%3E%3Crect width="1024" height="1536" fill="gold"/%3E%3C/svg%3E';
		picture.alt = ''; words.textContent = 'Public card proof with a long literal player name <Player & Friends>.';
		feedback.append(picture, words); document.querySelector('main').append(feedback);
		check(getComputedStyle(feedback).display === 'none', 'Hidden shared feedback stays hidden in every palette');
		feedback.hidden = false;
		await picture.decode();
		const thumbnail = picture.getBoundingClientRect(), feedbackBounds = feedback.getBoundingClientRect();
		check(thumbnail.width === 42 && thumbnail.height === 63 && thumbnail.right <= feedbackBounds.right, 'Large public artwork stays a bounded thumbnail without party-table styling');
		check(feedback.scrollWidth <= feedback.clientWidth + 1 && !feedback.querySelector('player'), 'Feedback text wraps literally within the surface');
		feedback.remove();
		const cash = new StarGamesMoneyEffect(() => null);
		check(cash.amountText(3) === '+$3' && cash.amountText(-7) === '−$7', 'Money feedback retains default dollar formatting');
		cash.clear(); cash.layer.remove();
		const money = new StarGamesMoneyEffect(seat => ({x:20 + seat * 120,y:120,width:60,height:24}), {amountPrefix:'',icon:'/ui/playful/table-dice.svg'});
		money.update({revision:0,money:[],active:false});
		const payment = {revision:1,elapsed:.3,duration:1,active:true,money:[{start:0,duration:1,seat:0,target:1,changes:[{seat:0,amount:-2},{seat:1,amount:2}]}]};
		money.update(payment, {paused:true,reduced:true});
		check(money.layer.querySelector('.is-gain').textContent === '+2' && money.layer.querySelector('.is-loss').textContent === '−2', 'Coin/token formatting retains exact signed amounts');
		const staticLeft = money.staticLeft;
		money.update({...payment,elapsed:0}, {paused:true,reduced:true});
		check(money.event.elapsed >= .3 && money.staticLeft === staticLeft, 'Duplicate paused snapshots preserve motion progress and static lifetime');
		check(!money.layer.querySelector('img') && money.layer.getAttribute('aria-hidden') === 'true' && getComputedStyle(money.layer).pointerEvents === 'none', 'Reduced money feedback has no flights and never captures input');
		money.update({...payment,revision:2}, {paused:true});
		if (!matchMedia('(prefers-reduced-motion: reduce)').matches) {
			const flight = money.layer.querySelector('img');
			check(flight?.src.endsWith('/ui/playful/table-dice.svg') && getComputedStyle(flight).objectFit === 'contain', 'Custom offline transfer artwork preserves its proportions');
		}
		money.clear(); check(!money.layer.childElementCount, 'Clearing money feedback removes every amount and flight'); money.layer.remove();
		const numbers = new StarGamesMoneyEffect(seat => ({x:20 + seat * 120,y:120,width:60,height:24}), {amountPrefix:'',amountBadge:false,showTransfers:false});
		numbers.update({revision:0,money:[],active:false});
		numbers.update({...payment,revision:3}, {paused:true});
		const gain = numbers.layer.querySelector('.is-gain'), loss = numbers.layer.querySelector('.is-loss');
		check(gain.getBoundingClientRect().bottom < 120 && loss.getBoundingClientRect().top > 144, 'Gains float above the balance and losses below it');
		check(getComputedStyle(gain).backgroundColor === 'rgba(0, 0, 0, 0)' && getComputedStyle(gain).borderTopWidth === '0px' && !numbers.layer.querySelector('img'), 'Plain signed amounts omit badges and transfer artwork');
		numbers.clear(); numbers.layer.remove();
		const order = StarGamesTurnStrip([{display_name:'Literal <player>',color:'#2463eb'},{display_name:'Out player',color:'#e53935',alive:false}],1,{tracked:true});
		document.body.append(order);
		check(order.children.length === 2 && order.lastElementChild.classList.contains('game-seat-eliminated') && order.lastElementChild.getAttribute('aria-label').endsWith(', eliminated') && !order.querySelector('.is-active'), 'Turn order preserves eliminated seats, mutes them, and rejects an eliminated current turn');
		check(getComputedStyle(order.lastElementChild).filter.includes('0.55') && !order.querySelector('player'), 'Eliminated turn names stay literal and inherit shared dimming'); order.remove();
		window.qaResult = {run, checks, failures:0, seats:count, cards:presentation, boardWidth:opening.board.width, footerHeight:opening.footer.height, longFooterHeight:longNames.footer.height};
	} catch (error) {
		window.qaResult = {run, checks, failures:1, error:String(error)};
	}
})();`;

function fixture(url) {
	const seats = url.searchParams.get('seats') === '6' ? 6 : 2;
	const ledger = url.searchParams.get('cards') === 'ledger';
	const prominent = seats === 6;
	const cards = Array.from({length:seats}, (_, index) => ledger
		? `<aside class="game-score-card game-ledger game-text-score"><p data-player-name class="${index === 0 ? 'is-active-player' : ''}">Player ${index + 1}</p><output>0 WINS</output></aside>`
		: `<aside class="game-session-score"><p data-player-name class="${index === 0 ? 'is-active-player' : ''}">Player ${index + 1}</p><output>0 WINS</output><p>0 / 10 HOME</p></aside>`).join('');
	return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>Shared board fixture</title><link rel="stylesheet" href="/styles.css"><style>
	#board { aspect-ratio:1; width:100%; margin:auto; background:repeating-conic-gradient(#f0d9a0 0% 25%, #6c452e 0% 50%) 0 0 / 25% 25%; }
	</style></head><body class="playful-game game-royal"><main class="game-controller game-board-controller"><header><img class="game-title-art${prominent ? ' game-title-prominent' : ''}" alt="Shared board example" src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='480' height='${prominent ? 160 : 52}'%3E%3Crect width='480' height='${prominent ? 160 : 52}' rx='12' fill='%23efca6f'/%3E%3Ctext x='240' y='35' text-anchor='middle' font-size='28' fill='%2356351f'%3ESHARED BOARD%3C/text%3E%3C/svg%3E"><p id="connection" role="status">Connected as Player 1</p><p id="status" class="game-status game-status-reserved" role="status">Your turn.</p></header><section class="game-playfield"><div id="board" role="group" aria-label="Example square board"></div><div class="game-board-controls game-action-row game-action-compact"><button type="button">MOVE</button><button id="replay" class="game-primary" data-game-inline-action hidden>PLAY AGAIN</button></div></section><div class="game-board-stats ${ledger ? '' : 'game-paper game-paper-compact'}" data-game-stats-columns="${seats === 6 ? '3' : '2'}" role="group" aria-label="Players and session scores">${cards}</div></main><script src="/controller-sdk.js"></script><script src="/card-ui.js"></script><script>${assertions}</script></body></html>`;
}

const types = {'.js':'text/javascript', '.css':'text/css', '.svg':'image/svg+xml', '.png':'image/png'};
const missing = new Set();
const server = createServer(async (request, response) => {
	const url = new URL(request.url, 'http://127.0.0.1');
	try {
		if (url.pathname === '/') {
			response.writeHead(200, {'Content-Type':'text/html'});
			response.end(fixture(url));
			return;
		}
		const directory = url.pathname.startsWith('/ui/') ? join(root, 'ui') : join(root, 'web');
		const relative = url.pathname.startsWith('/ui/') ? url.pathname.slice(4) : url.pathname.slice(1);
		const file = resolve(directory, relative);
		if (!file.startsWith(directory + sep)) throw new Error('Unsafe asset path');
		const body = await readFile(file);
		response.writeHead(200, {'Content-Type':types[extname(file)] || 'application/octet-stream'});
		response.end(body);
	} catch {
		if (url.pathname !== '/favicon.ico') missing.add(url.pathname);
		response.writeHead(404);
		response.end();
	}
});

await mkdir(output, {recursive:true});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const child = spawn(chrome, ['--headless', '--no-sandbox', '--disable-gpu', '--no-first-run', '--disable-background-networking', '--remote-debugging-port=0', `--user-data-dir=${join(output, 'profile-' + process.pid)}`], {windowsHide:true, stdio:['ignore', 'ignore', 'pipe']});
const ready = new Promise((resolve, reject) => {
	child.on('error', reject);
	child.stderr.on('data', chunk => {
		const match = String(chunk).match(/DevTools listening on (ws:\/\/[^\s]+)/);
		if (match) resolve(match[1]);
	});
});
let browser, page, timer, failures = 0, checks = 0, run = 0, observedGrowth = false;
try {
	const endpoint = await Promise.race([ready, new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Chromium did not start')), 15000); })]);
	clearTimeout(timer);
	browser = await protocol(endpoint);
	const target = await browser.send('Target.createTarget', {url:'about:blank'});
	const tabs = await (await fetch(`http://127.0.0.1:${new URL(endpoint).port}/json/list`)).json();
	page = await protocol(tabs.find(tab => tab.id === target.targetId).webSocketDebuggerUrl);
	await page.send('Page.enable');
	for (const [name, width, height, reduced] of [['small',320,568,false], ['portrait',390,844,false], ['landscape',844,390,false], ['tablet',768,1024,false], ['desktop',1280,720,false], ['reduced',390,844,true]]) {
		await page.send('Emulation.setDeviceMetricsOverride', {width, height, deviceScaleFactor:1, mobile:false});
		await page.send('Emulation.setEmulatedMedia', {features:[{name:'prefers-reduced-motion', value:reduced ? 'reduce' : 'no-preference'}]});
		for (const [cards, seats] of [['ledger',2], ['session',2], ['session',6]]) {
			run++;
			await page.send('Page.navigate', {url:`http://127.0.0.1:${server.address().port}/?cards=${cards}&seats=${seats}&run=${run}`});
			let result;
			for (let attempt = 0; attempt < 120; attempt++) {
				await delay(50);
				const reply = await page.send('Runtime.evaluate', {expression:'window.qaResult', returnByValue:true});
				result = reply.result.value;
				if (result?.run === run) break;
			}
			if (result?.run !== run) throw new Error(name + ': assertions did not finish');
			checks += result.checks;
			failures += result.failures;
			observedGrowth ||= result.longFooterHeight > result.footerHeight + 1;
			console.log(`${name}/${cards}-${seats}: ${JSON.stringify(result)}`);
			const screenshot = await page.send('Page.captureScreenshot', {format:'png', captureBeyondViewport:false});
			await writeFile(join(output, `${name}-${cards}-${seats}.png`), Buffer.from(screenshot.data, 'base64'));
		}
	}
	checks += 2;
	if (!observedGrowth) { failures++; console.error('FAIL: no viewport exercised observed long-name footer growth'); }
	if (missing.size) { failures++; console.error('FAIL: missing shared offline assets: ' + [...missing].join(', ')); }
} finally {
	clearTimeout(timer);
	page?.socket.close();
	if (browser) { await browser.send('Browser.close').catch(() => {}); browser.socket.close(); }
	else child.kill();
	await new Promise(resolve => server.close(resolve));
}
console.log(`Shared board controllers: ${checks} checks, ${failures} failures`);
if (failures) process.exitCode = 1;
