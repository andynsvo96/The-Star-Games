(() => {
  "use strict";
  // Sun/moon artwork is separate from the shared image/video background player.
  window.MafiaSkyCycle = class {
    constructor() {
      this.daytime = null; this.cycle = 0; this.cityMix = 0; this.frame = 0;
      this.motion = matchMedia("(prefers-reduced-motion: reduce)");
      this.layer = document.createElement("div");
      this.layer.className = "mafia-sky";
      this.layer.hidden = true;
      this.layer.setAttribute("aria-hidden", "true");
      this.planets = ["sun", "moon"].map(name => {
        const image = document.createElement("img");
        image.src = `/game/mafia/art/${name}.svg`; image.alt = "";
        image.dataset.planet = name; this.layer.append(image); return image;
      });
      this.cities = ["night", "day"].map(name => {
        const image = document.createElement("img");
        image.className = "mafia-city"; image.dataset.city = name;
        image.src = `/game/mafia/art/town-${name}-front.png`; image.alt = "";
        this.layer.append(image); return image;
      });
      document.body.append(this.layer);
      window.addEventListener("resize", () => this.draw());
      this.motion.addEventListener("change", () => {
        if (this.motion.matches && this.daytime !== null) this.setDaytime(this.daytime, false, true);
      });
      window.addEventListener("pagehide", () => { cancelAnimationFrame(this.frame); this.layer.remove(); }, {once: true});
      this.draw();
    }
    setDaytime(value, animate = true, reduced = false) {
      this.layer.hidden = false;
      reduced ||= this.motion.matches;
      if (value === this.daytime && !reduced) return;
      cancelAnimationFrame(this.frame);
      const moving = animate && !reduced && this.daytime !== null;
      this.daytime = value;
      if (!moving) { this.cycle = value ? 0 : 1; this.cityMix = value ? 1 : 0; this.draw(); return; }
      let target = Math.floor(this.cycle) + 1;
      if (target % 2 !== (value ? 0 : 1)) target++;
      const from = this.cycle, fromCity = this.cityMix, start = performance.now();
      const tick = now => {
        const t = Math.min(1, (now - start) / 1800), eased = .5 - .5 * Math.cos(Math.PI * t);
        this.cycle = from + (target - from) * eased;
        this.cityMix = fromCity + ((value ? 1 : 0) - fromCity) * (.5 - .5 * Math.cos(Math.PI * Math.min(1, t * 2)));
        this.draw();
        this.frame = t < 1 ? requestAnimationFrame(tick) : 0;
      };
      this.frame = requestAnimationFrame(tick);
    }
    draw() {
      const w = innerWidth, h = innerHeight, radius = Math.max(26, Math.min(67, Math.min(w, h) * .075));
      const heightRadius = h * 1.1 - Math.min(h * .17, Math.min(w, h) * .13);
      this.planets.forEach((image, index) => {
        const angle = -Math.PI / 2 + (this.cycle + index) * Math.PI;
        image.style.width = image.style.height = `${radius * 2}px`;
        image.style.left = `${w * (.79 + .12 * Math.cos(angle)) - radius}px`;
        image.style.top = `${h * 1.1 + heightRadius * Math.sin(angle) - radius}px`;
      });
      this.layer.dataset.cycle = this.cycle;
      this.cities[1].style.opacity = this.cityMix;
    }
  };
})();
