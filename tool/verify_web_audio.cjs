const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const sounds = [];
class Audio {
  constructor(src) { this.src = src; this.paused = true; sounds.push(this); }
  play() { this.paused = false; this.plays = (this.plays || 0) + 1; return Promise.resolve(); }
  pause() { this.paused = true; }
  load() {}
  removeAttribute() { this.src = ''; }
}
const events = new Map();
const document = {
  baseURI: 'http://localhost:8769/', hidden: false,
  addEventListener: (id, action) => events.set(id, action),
  removeEventListener: id => events.delete(id),
};
const window = {
  addEventListener: (id, action) => events.set(id, action),
  removeEventListener: id => events.delete(id),
};
vm.runInNewContext(fs.readFileSync('web/audio.js', 'utf8'), {Audio, URL, document, window});

(async () => {
  const bridge = window.kvmAudio;
  await bridge.initialize();
  await bridge.music('assets/audio/intro.mp3', .4, true);
  const intro = sounds.at(-1);
  assert.equal(intro.loop, true);
  assert.equal(intro.src, 'http://localhost:8769/assets/assets/audio/intro.mp3');
  assert.equal(intro.paused, false);
  const count = sounds.length;
  await bridge.music('assets/audio/intro.mp3', .2, true);
  assert.equal(sounds.length, count); // Same music element and position.
  bridge.effect('select', .6);
  assert(sounds.some(audio => audio.src.endsWith('/select.wav') && !audio.paused));
  document.hidden = true; events.get('visibilitychange')();
  assert(sounds.every(audio => audio.paused));
  bridge.unlock(); bridge.effect('pop', .6);
  assert(sounds.every(audio => audio.paused));
  document.hidden = false; events.get('visibilitychange')();
  assert.equal(intro.paused, false);
  await bridge.music('assets/audio/bgm02.mp3', .4, true);
  assert.equal(intro.src, '');
  assert.equal(sounds.at(-1).loop, true);
  bridge.suspend(); bridge.unlock();
  assert(sounds.every(audio => audio.paused));
  await bridge.music(null, 0, true); // Music off, independent effects on.
  bridge.effect('special', .4);
  assert(sounds.some(audio => audio.src.endsWith('/special.wav') && !audio.paused));
  bridge.dispose(); bridge.unlock();
  assert(sounds.every(audio => audio.paused));
  assert.equal(events.size, 0);
  console.log('PASS: web loop/reuse/visibility/suspend/independent effects/disposal contracts (mocked Audio, not audible playback).');
})().catch(error => { console.error(error); process.exitCode = 1; });
