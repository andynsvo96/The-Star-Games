/* Offline, snapshot-driven image/video surface. Clip sound belongs to the host. */
class StarGamesMediaView {
  constructor(container) {
    this.container = container;
    this.key = '';
    this.video = null;
    this.playbackKey = '';
  }
  render(data, playback = {}, suspended = false) {
    const key = JSON.stringify(data || null);
    if (key !== this.key) {
      this.clear(); this.key = key;
      if (!data) return;
      this.container.hidden = false;
      const image = data.sources?.find(source => source.type?.startsWith('image/'));
      const videos = data.sources?.filter(source => source.type?.startsWith('video/')) || [];
      if (image) {
        const element = document.createElement('img');
        element.src = image.url; element.alt = data.alt || '';
        this.container.append(element);
      } else if (videos.length) {
        this.video = document.createElement('video');
        this.video.muted = true; this.video.playsInline = true;
        this.video.preload = 'metadata';
        this.video.setAttribute('aria-label', data.alt || 'Video clue');
        if (data.poster) this.video.poster = data.poster;
        for (const source of videos) {
          const element = document.createElement('source');
          element.src = source.url; element.type = source.type;
          this.video.append(element);
        }
        this.container.append(this.video);
      }
      const caption = document.createElement('p'); caption.textContent = data.alt || '';
      this.container.append(caption);
    }
    if (!this.video) return;
    const nextPlayback = JSON.stringify([playback.sequence, Boolean(playback.playing), Boolean(suspended)]);
    if (nextPlayback === this.playbackKey) return;
    this.playbackKey = nextPlayback;
    const video = this.video;
    const apply = () => {
      if (this.video !== video || this.playbackKey !== nextPlayback) return;
      const position = Math.max(0, Number(playback.position) || 0);
      if (Number.isFinite(this.video.duration)) this.video.currentTime = Math.min(position, this.video.duration);
      if (playback.playing && !suspended) this.video.play().catch(() => {});
      else this.video.pause();
    };
    if (this.video.readyState) apply();
    else this.video.addEventListener('loadedmetadata', apply, {once:true});
  }
  clear() {
    if (this.video) { this.video.pause(); this.video.removeAttribute('src'); this.video.replaceChildren(); this.video.load(); }
    this.video = null; this.key = ''; this.playbackKey = '';
    this.container.replaceChildren(); this.container.hidden = true;
  }
}
