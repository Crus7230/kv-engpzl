/* Dependency-free preview bridge. Android uses the retained native audio pack. */
(() => {
  let music = null;
  let path = null;
  let requestedActive = false;
  let disposed = false;
  const pools = new Map();
  const soundIds = ['select', 'swap', 'pop', 'special'];
  const assetUrl = p => new URL(`assets/${p}`, document.baseURI).href;
  const pauseAll = () => {
    music?.pause();
    for (const pool of pools.values()) for (const audio of pool) audio.pause();
  };
  const resume = () => {
    if (!disposed && requestedActive && !document.hidden && music) {
      // Autoplay rejection is normal until the first user gesture.
      music.play().catch(() => {});
    }
  };
  const visibility = () => document.hidden ? pauseAll() : resume();
  const pageHide = () => pauseAll();
  window.kvmAudio = {
    async initialize() {
      disposed = false;
      if (pools.size === 0) {
        for (const id of soundIds) {
          pools.set(id, Array.from({length: 3}, () => {
            const audio = new Audio(assetUrl(`assets/audio/${id}.wav`));
            audio.preload = 'auto';
            return audio;
          }));
        }
      }
      document.addEventListener('visibilitychange', visibility);
      window.addEventListener('pagehide', pageHide);
    },
    async music(nextPath, volume, active) {
      if (disposed) return;
      requestedActive = active;
      if (path !== nextPath) {
        music?.pause();
        if (music) { music.removeAttribute('src'); music.load(); }
        path = nextPath;
        music = path ? new Audio(assetUrl(path)) : null;
        if (music) { music.loop = true; music.preload = 'auto'; }
      }
      if (music) music.volume = Math.max(0, Math.min(1, volume));
      if (!active || document.hidden) pauseAll(); else resume();
    },
    effect(id, volume) {
      if (disposed || !requestedActive || document.hidden) return;
      const pool = pools.get(id);
      const audio = pool?.find(a => a.paused || a.ended);
      if (!audio) return;
      audio.currentTime = 0;
      audio.volume = Math.max(0, Math.min(1, volume));
      audio.play().catch(() => {});
    },
    unlock: resume,
    suspend() { requestedActive = false; pauseAll(); },
    dispose() {
      disposed = true;
      requestedActive = false;
      pauseAll();
      if (music) { music.removeAttribute('src'); music.load(); }
      music = null; path = null;
      for (const pool of pools.values()) for (const audio of pool) {
        audio.removeAttribute('src'); audio.load();
      }
      pools.clear();
      document.removeEventListener('visibilitychange', visibility);
      window.removeEventListener('pagehide', pageHide);
    },
  };
})();
