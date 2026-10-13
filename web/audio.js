/* Dependency-free preview bridge. Android uses the retained native audio pack. */
(() => {
  let music = null;
  let path = null;
  let requestedActive = false;
  let disposed = false;
  const pools = new Map();
  const soundIds = ['select', 'swap', 'pop', 'special'];
  // Opt-in localhost diagnostics for actual decoded media playback. Normal
  // app sessions remain silent; this does not expose saves or user data.
  const diagnostics = window.location &&
    ['localhost', '127.0.0.1'].includes(window.location.hostname) &&
    new URLSearchParams(window.location.search).get('audioDebug') === '1';
  const report = (event, value) => {
    if (diagnostics) console.debug(`[kvm-audio] ${event} ${JSON.stringify(value)}`);
  };
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
        if (music) {
          music.loop = true; music.preload = 'auto';
          if (diagnostics) {
            const player = music, selectedPath = path;
            let advanced = false;
            const state = () => ({path: selectedPath, position: player.currentTime,
              duration: player.duration, loop: player.loop, paused: player.paused});
            player.addEventListener('playing', () => report('playing', state()));
            player.addEventListener('pause', () => report('paused', state()));
            player.addEventListener('error', () => report('error', {
              path: selectedPath, code: player.error?.code,
            }));
            player.addEventListener('timeupdate', () => {
              if (!advanced && player.currentTime >= 1 && !player.paused) {
                advanced = true;
                report('advancing', state());
              }
            });
          }
        }
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
