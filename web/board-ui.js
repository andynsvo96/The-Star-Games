/* Shared illustrated references and public round summaries. No game authority. */
(() => {
	"use strict";
	const node = (tag, className, text) => {
		const element = document.createElement(tag);
		if (className) element.className = className;
		if (text !== undefined) element.textContent = String(text);
		return element;
	};
	function sheet(parent, heading, className) {
		const dialog = node("dialog", `game-dialog game-scroll-dialog ${className}`);
		const title = node("h2", "dialog-heading", heading);
		const body = node("div", "dialog-body"), actions = node("div", "dialog-actions game-action-row");
		dialog.append(title, body, actions); parent.append(dialog);
		dialog.setAttribute("aria-label", heading);
		return {dialog, title, body, actions};
	}
	class GuideDemonstration {
		constructor(record) {
			this.record=record; this.active=false; this.playing=true; this.frame=0;
			this.element=node("div","game-guide-demonstration"); this.stage=node("div","game-guide-demo-stage");
			this.stage.style.aspectRatio=String(record.aspect||1); this.stage.setAttribute("role","img"); this.stage.setAttribute("aria-label",record.description||"Illustrated move demonstration");
			const background=node("img"); background.src=record.background; background.alt=""; background.setAttribute("aria-hidden","true"); this.stage.append(background);
			background.addEventListener("load",()=>{if(!record.aspect&&background.naturalHeight)this.stage.style.aspectRatio=String(background.naturalWidth/background.naturalHeight);});
			this.actors=(record.sprites||[]).map(sprite=>{const image=node("img","game-guide-demo-piece");image.src=sprite.image;image.alt="";image.setAttribute("aria-hidden","true");this.stage.append(image);return image;});
			this.caption=node("p","game-guide-demo-caption"); const controls=node("div","game-action-row game-action-compact");
			this.pause=node("button","game-secondary","PAUSE"); this.replay=node("button","game-secondary","REPLAY");
			for(const button of [this.pause,this.replay])button.type="button";
			this.pause.addEventListener("click",()=>{this.playing=!this.playing;this.pause.textContent=this.playing?"PAUSE":"PLAY";this.schedule();});
			this.replay.addEventListener("click",()=>this.restart()); controls.append(this.pause,this.replay); this.element.append(this.stage,this.caption,controls);
			this.visibility=()=>this.schedule(); document.addEventListener("visibilitychange",this.visibility); this.restart();
		}
		restart(){this.playing=true;this.pause.textContent="PAUSE";this.beginStep(0);this.schedule();}
		beginStep(index){
			const steps=this.record.steps||[];if(!steps.length)return;
			this.step=index%steps.length;const instruction=steps[this.step];
			if(!this.step||instruction.reset)this.sprites=(this.record.sprites||[]).map(sprite=>({...sprite,rect:[...sprite.rect],opacity:sprite.opacity??1}));
			this.starts=structuredClone(this.sprites);this.targets=structuredClone(this.sprites);this.paths=new Map();this.fades=new Set();
			for(const move of instruction.moves||[]){const actor=move.sprite;if(!this.targets[actor])continue;
				if(move.rect){this.targets[actor].rect=move.rect;this.paths.set(actor,[this.starts[actor].rect,...(move.via||[]),move.rect]);}
				if(move.opacity!==undefined)this.targets[actor].opacity=move.opacity;if(move.image)this.targets[actor].image=move.image;
				if(move.fade)this.fades.add(actor);
			}
			this.elapsed=0;this.caption.textContent=instruction.caption||"";this.advance(0);
		}
		advance(delta){
			const instruction=this.record.steps?.[this.step];if(!instruction||!this.starts)return;
			this.elapsed+=delta;const duration=Math.max(.3,instruction.duration||1.2),progress=Math.max(0,Math.min(1,(this.elapsed-.55)/duration)),eased=progress*progress*(3-2*progress);
			this.actors.forEach((image,index)=>{const start=this.starts[index],target=this.targets[index],route=this.paths.get(index);let rect=start.rect;
				if(route){const part=Math.min(eased*(route.length-1),route.length-1.00001),segment=Math.floor(part);rect=route[segment].map((a,i)=>a+(route[segment+1][i]-a)*(part-segment));}
				const opacity=this.fades.has(index)?start.opacity+(target.opacity-start.opacity)*eased:progress>=1?target.opacity:start.opacity;
				const src=progress>=1?target.image:start.image;this.sprites[index]={...this.sprites[index],rect:[...rect],opacity,image:src};
				Object.assign(image.style,{left:rect[0]*100+"%",top:rect[1]*100+"%",width:rect[2]*100+"%",height:rect[3]*100+"%",opacity});
				if(image.getAttribute("src")!==src)image.src=src;
			});
			if(this.elapsed>=duration+1.55)this.beginStep(this.step+1);
		}
		setActive(value){this.active=value;this.schedule();}
		schedule(){cancelAnimationFrame(this.frame);this.last=performance.now();if(this.active&&this.playing&&!document.hidden)this.frame=requestAnimationFrame(now=>{this.advance(Math.min(.1,(now-this.last)/1000));this.schedule();});}
		destroy(){cancelAnimationFrame(this.frame);document.removeEventListener("visibilitychange",this.visibility);this.element.remove();}
	}
	class PieceTray {
		constructor(parent,onSelect) {
			this.element=node("section","game-piece-tray");this.element.setAttribute("aria-label","Reserve");
			this.caption=node("p","game-piece-tray-caption");this.row=node("div","game-piece-tray-slots");this.element.append(this.caption,this.row);parent.append(this.element);
			this.buttons=Array.from({length:5},(_,index)=>{const button=node("button","game-compact-control"),image=node("img"),count=node("span");button.type="button";image.alt="";button.append(image,count);button.addEventListener("click",()=>{if(!button.disabled)onSelect(this.items[index].key);});this.row.append(button);return button;});
		}
		update(items,selected=-1,title="Your reserve") {
			this.items=items;let total=0,choice="";
			this.buttons.forEach((button,index)=>{const item=items[index];button.hidden=!item;if(!item)return;total+=item.count;
				const image=button.querySelector("img");if(image.getAttribute("src")!==item.image)image.src=item.image;button.querySelector("span").textContent="×"+item.count;
				button.disabled=!item.enabled||!item.count;const active=item.key===selected;button.setAttribute("aria-pressed",String(active));button.setAttribute("aria-label",`${item.label}, ${item.count} in reserve${active?", selected":""}`);if(active)choice=item.label;
			});
			this.caption.textContent=title+(choice?" · "+choice+" selected":!total?" · Empty":"");
		}
	}
	class IllustratedGuide {
		constructor(parent, {heading = "How to Play", onChange = () => {}, paged = false, assetUrl = path => path} = {}) {
			Object.assign(this, sheet(parent, heading, "game-illustrated-guide"));
			this.onChange = onChange; this.paged = paged; this.page = 0; this.groupPages = new Map();this.assetUrl=assetUrl;
			this.motionPreference=matchMedia("(prefers-reduced-motion: reduce)");this.hostReduced=false;
			this.motionPreference.addEventListener("change",()=>this.updateMotion());
			const close = node("button", "game-secondary", "CLOSE"); close.type = "button";
			close.dataset.guideClose = "";
			close.addEventListener("click", () => this.dialog.close()); this.actions.append(close);
			if (paged) {
				this.dialog.classList.add("game-guide-paged");
				this.header = node("header", "dialog-heading game-guide-banner");
				this.title.className = ""; this.title.replaceWith(this.header); this.header.append(this.title);
				this.headerActions = node("div", "game-guide-header-actions"); this.header.append(this.headerActions);
				close.textContent = "×"; close.classList.add("game-guide-close"); close.setAttribute("aria-label", "Close tutorial"); this.header.append(close);
				this.tabs = node("nav", "game-guide-tabs"); this.tabs.setAttribute("aria-label", "Guide sections");
				this.topics = node("select", "game-choice game-guide-topics"); this.topics.setAttribute("aria-label", "Lesson topic");
				this.topics.addEventListener("change", () => this.selectPage(Number(this.topics.value)));
				this.lesson = node("section", "game-guide-section game-guide-page");
				this.lesson.setAttribute("aria-live", "polite");
				this.body.append(this.tabs, this.topics, this.lesson);
				this.previous = node("button", "game-secondary", "PREV"); this.previous.type = "button"; this.previous.setAttribute("aria-label", "Previous lesson");
				this.next = node("button", "game-secondary", "NEXT"); this.next.type = "button"; this.next.setAttribute("aria-label", "Next lesson");
				this.counter = node("output", "game-guide-counter"); this.counter.setAttribute("aria-label", "Lesson page");
				this.previous.addEventListener("click", () => this.selectPage(this.page - 1));
				this.next.addEventListener("click", () => this.selectPage(this.page + 1));
				this.actions.prepend(this.previous, this.counter, this.next);
			}
			this.dialog.addEventListener("close", () => { this.demonstration?.setActive(false); this.trigger?.focus({preventScroll:true}); this.onChange(false); });
			this.key = "";
		}
		setItems(items) {
			items=this.resolveAssets(items);
			const key = JSON.stringify(items); if (key === this.key) return;
			this.key = key; this.items = items;
			if (this.paged) {
				this.groups = [...new Set(items.map(item => item.section || "Guide"))];
				this.tabs.replaceChildren(...this.groups.map(group => {
					const button = node("button", "game-secondary", group); button.type = "button";
					button.addEventListener("click", () => this.selectPage(this.groupPages.get(group) ?? items.findIndex(item => (item.section || "Guide") === group)));
					return button;
				}));
				this.selectPage(Math.min(this.page, items.length - 1)); return;
			}
			this.body.replaceChildren();
			for (const item of items) {
				const section = node("section", "game-guide-section");
				const image = node("img"); image.src = item.image; image.alt = item.description || "";
				section.append(node("h3", "", item.heading), image, node("p", "", item.detail)); this.body.append(section);
			}
		}
		resolveAssets(value){if(Array.isArray(value))return value.map(entry=>this.resolveAssets(entry));if(value&&typeof value==="object")return Object.fromEntries(Object.entries(value).map(([key,entry])=>[key,["image","background"].includes(key)&&typeof entry==="string"?this.assetUrl(entry):this.resolveAssets(entry)]));return value;}
		selectPage(index) {
			if (!this.items?.length) { this.previous.disabled = this.next.disabled = true; this.lesson.replaceChildren(); return; }
			this.page = Math.max(0, Math.min(index, this.items.length - 1));
			const item = this.items[this.page], group = item.section || "Guide";
			this.groupPages.set(group, this.page);
			[...this.tabs.children].forEach(button => button.setAttribute("aria-pressed", String(button.textContent === group)));
			this.topics.replaceChildren(...this.items.flatMap((entry, index) => {
				if ((entry.section || "Guide") !== group) return [];
				const option = node("option", "", entry.heading); option.value = index; return [option];
			})); this.topics.value = this.page;
			const image = node("img"); image.src = item.image; image.alt = item.description || "";
			this.demonstration?.destroy();this.demonstration=null;this.staticImage=image;
			const visual=node("div","game-guide-visual");visual.append(image);
			if(item.demonstration?.steps?.length){this.demonstration=new GuideDemonstration(item.demonstration);visual.append(this.demonstration.element);}
			const copy = node("div", "game-guide-copy"); copy.append(node("h3", "", item.heading), node("p", "", item.detail));
			if (item.tip) copy.append(node("p", "game-guide-tip", item.tip));
			this.lesson.replaceChildren(visual, copy);this.updateMotion();
			this.counter.textContent = `${this.page + 1} / ${this.items.length}`;
			this.previous.disabled = this.page === 0; this.next.disabled = this.page === this.items.length - 1;
			this.body.scrollTop = 0;
		}
		setReducedMotion(value){this.hostReduced=!!value;this.updateMotion();}
		updateMotion(){if(!this.demonstration)return;const reduced=this.hostReduced||this.motionPreference.matches;this.staticImage.hidden=!reduced;this.demonstration.element.hidden=reduced;this.demonstration.setActive(this.dialog.open&&!reduced);}
		open(trigger) { this.trigger = trigger; if (!this.dialog.open) { this.dialog.showModal(); this.dialog.querySelector("[data-guide-close]").focus({preventScroll:true}); this.demonstration?.setActive(true); this.onChange(true); } }
		close() { if (this.dialog.open) this.dialog.close(); }
	}
	class RoundResults {
		constructor(parent, replay, {onChange = () => {}} = {}) {
			Object.assign(this, sheet(parent, "Game results", "game-round-dialog"));
			this.onChange = onChange; this.key = "";
			this.summary = node("p", "game-round-summary"); this.grid = node("div", "game-round-results");
			this.body.append(this.summary, this.grid);
			this.review = node("button", "game-secondary", "VIEW BOARD"); this.review.type = "button";
			this.review.addEventListener("click", () => this.dialog.close());
			this.actions.append(this.review, replay); replay.style.maxWidth = "";
			this.dialog.addEventListener("close", () => this.onChange(false));
		}
		update({key, heading, summary, players}, ready) {
			if (!ready) return;
			if (key === this.key) return;
			this.key = key; this.title.textContent = heading; this.summary.textContent = summary; this.grid.replaceChildren();
			for (const player of players) {
				const card = node("article", "game-round-player"), header = node("header");
				const name = node("strong", "", player.display_name);
				name.style.borderLeft = `3px solid ${player.color}`;
				const crown = node("img"); crown.alt = player.winner ? "Winner" : "";
				if (player.winner) crown.src = "/ui/playful/table-crown.svg"; else crown.style.visibility = "hidden";
				header.append(name, crown); card.append(header);
				const list = node("dl");
				for (const metric of player.metrics) list.append(node("dt", "", metric.label), node("dd", "", metric.value));
				card.append(list); this.grid.append(card);
			}
			this.open();
		}
		open() { if (this.key && !this.dialog.open) { this.dialog.showModal(); queueMicrotask(() => this.onChange(true)); } }
		reset() { this.key = ""; if (this.dialog.open) this.dialog.close(); }
	}
	window.StarGamesIllustratedGuide = IllustratedGuide;
	window.StarGamesPieceTray = PieceTray;
	window.StarGamesRoundResults = RoundResults;
	class MovePreview {
		constructor(parent,{rectFor,createVisual}) { Object.assign(this,{parent,rectFor,createVisual,key:"",visual:null,frame:0,elapsed:0,paused:false}); }
		update(record,{paused=false,reduced=false,restore=false}={}) {
			this.paused=paused;
			if(!record || !Number.isInteger(record.to) || record.to<0) {this.clear();return;}
			const key=record.key??JSON.stringify([record.from,record.to,record.path]);
			if(key!==this.key) {
				this.clear();this.key=key;this.route=record.path?.length>1?record.path:[record.from,record.to];
				this.duration=Math.min(1500,Math.max(350,(this.route.length-1)*320));this.elapsed=reduced||restore?this.duration:0;
				this.visual=this.createVisual(record);this.visual.classList.add('game-guide-ghost');this.visual.setAttribute('aria-hidden','true');this.parent.append(this.visual);
			}
			if(reduced||restore)this.elapsed=this.duration;
			this.last=performance.now();this.refresh();this.schedule();
		}
		schedule(){cancelAnimationFrame(this.frame);if(this.visual&&!this.paused&&this.elapsed<this.duration)this.frame=requestAnimationFrame(now=>{this.elapsed=Math.min(this.duration,this.elapsed+now-this.last);this.last=now;this.refresh();this.schedule();});}
		refresh(){
			if(!this.visual)return;
			const p=Math.min(1,this.elapsed/this.duration)*(this.route.length-1),index=Math.min(Math.floor(p),this.route.length-2),t=p-index,ease=t*t*(3-2*t);
			const a=this.rectFor(this.route[index]),b=this.rectFor(this.route[index+1]),parent=this.parent.getBoundingClientRect();
			const width=a.width+(b.width-a.width)*t,height=a.height+(b.height-a.height)*t;
			Object.assign(this.visual.style,{left:(a.x+a.width/2+(b.x+b.width/2-a.x-a.width/2)*ease-parent.left-this.parent.clientLeft-width/2)+'px',top:(a.y+a.height/2+(b.y+b.height/2-a.y-a.height/2)*ease-parent.top-this.parent.clientTop-height/2-Math.sin(t*Math.PI)*height*.15)+'px',width:width+'px',height:height+'px'});
		}
		clear(){cancelAnimationFrame(this.frame);this.visual?.remove();this.visual=null;this.key="";}
	}
	window.StarGamesMovePreview=MovePreview;
	// Taps and keyboard clicks keep their normal handlers. Only a deliberate drag
	// suppresses its follow-up click; authority always stays with onDrop's caller.
	class PieceDrag {
		constructor(surface, options) {
			this.surface = surface; this.options = options; this.gesture = null; this.suppressUntil = 0;
			surface.addEventListener("dragstart", event => event.preventDefault());
			surface.addEventListener("pointerdown", event => {
				if (this.gesture && this.gesture.id !== event.pointerId) this.cancel();
				if (!event.isPrimary || event.button !== 0 || this.gesture) return;
				const from = options.hitTest(event.clientX, event.clientY);
				if (from < 0 || !options.canStart(from)) return;
				this.gesture = {id:event.pointerId, from, x:event.clientX, y:event.clientY, revision:options.revision(), dragging:false};
			});
			window.addEventListener("pointermove", event => {
				const g = this.gesture; if (!g || g.id !== event.pointerId) return;
				if (!this.valid()) { this.cancel(); return; }
				if (!g.dragging && Math.hypot(event.clientX-g.x, event.clientY-g.y) >= 8) {
					g.dragging = true; this.suppressUntil = performance.now()+400;
					g.preview = options.createPreview(g.from); g.preview.classList.add("game-piece-drag-preview");
					surface.append(g.preview); options.onStart?.(g.from);
					try { surface.setPointerCapture(g.id); } catch {}
				}
				if (g.dragging) {
					g.preview.style.left = event.clientX+"px"; g.preview.style.top = event.clientY+"px";
					event.preventDefault();
				}
			}, {passive:false});
			window.addEventListener("pointerup", event => {
				const g = this.gesture; if (!g || g.id !== event.pointerId) return;
				const to = options.hitTest(event.clientX, event.clientY);
				const commit = g.dragging && this.valid() && to >= 0 && to !== g.from;
				this.clear(); if (commit) options.onDrop(g.from, to);
			});
			window.addEventListener("pointercancel", event => { if (this.gesture?.id === event.pointerId) this.cancel(); });
			surface.addEventListener("lostpointercapture", event => { if (event.target === surface && event.pointerId === this.gesture?.id) this.cancel(); });
			surface.addEventListener("click", event => {
				if (event.detail && performance.now() < this.suppressUntil) { event.preventDefault(); event.stopImmediatePropagation(); }
			}, true);
			for (const name of ["blur", "resize", "pagehide"]) window.addEventListener(name, () => this.cancel());
			new ResizeObserver(() => this.cancel()).observe(surface);
		}
		valid() { const g=this.gesture; return !!g && g.revision===this.options.revision() && this.options.canStart(g.from); }
		blocksTap() { return !!this.gesture?.dragging || performance.now()<this.suppressUntil; }
		validate() { if (this.gesture && !this.valid()) this.cancel(); }
		cancel() { if (this.gesture) this.clear(); }
		clear() {
			const g=this.gesture; this.gesture=null; if(!g) return;
			if(g.dragging) { this.suppressUntil=performance.now()+400; g.preview.remove(); this.options.onEnd?.(g.from); }
			try { if(this.surface.hasPointerCapture(g.id)) this.surface.releasePointerCapture(g.id); } catch {}
		}
	}
	window.StarGamesPieceDrag = PieceDrag;
})();
