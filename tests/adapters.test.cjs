const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { JSDOM } = require('jsdom');

function read(name, html, url = 'https://viu.to/') {
  const dom = new JSDOM(html, { url, runScripts: 'outside-only' });
  try {
    return JSON.parse(dom.window.eval(readFileSync(`ios/VIU/${name}.js`, 'utf8')));
  } finally { dom.window.close(); }
}

// Sanitised fixtures preserve the markup observed on VIU, with dummy media.
function card(path, title, classes = '') {
  return `<div class="item ${classes}"><div class="item-flip">
    <div class="movie-card-thumb"><img src="https://images.example/poster.jpg"></div>
    <div class="movie-card-info"><a class="movie-card-link" href="${path}"></a>
    <h2 class="movie-card-title">${title}</h2>
    <span class="imdb-rating-icon"><span>7.2</span></span><div class="mf-year">2024</div>
    </div></div></div>`;
}

test('home reader keeps real cards, removes carousel clones and duplicate links', () => {
  const result = read('Catalogue', `<div class="slider-container">
    <div class="slider-title-container"><h1>Continue Watching</h1><a>View All</a></div>
    ${card('/wm/1/Film', 'Film', 'slick-cloned')}
    ${card('/wm/1/Film', 'Film')}${card('/wm/1/Film', 'Film')}
    ${card('/wtv/2/Series', 'Series')}
    </div>`);
  assert.equal(result.sections.length, 1);
  assert.equal(result.sections[0].id, 'Continue Watching');
  assert.deepEqual(result.sections[0].items.map(i => i.id), ['/wm/1/Film', '/wtv/2/Series']);
  assert.equal(result.sections[0].items[0].rating, '7.2');
});

test('catalogue readers reject offsite and unsupported title links', () => {
  const html = card('https://other.example/wm/1/Film', 'Offsite') + card('/logout', 'Invalid');
  assert.equal(read('Browse', `<section id="content">${html}</section><div id="spinner_load" style="display:none"></div>`).items.length, 0);
  assert.equal(read('Catalogue', `<div class="slider-container"><div class="slider-title-container"><h1>Titles</h1></div>${html}</div>`).sections.length, 0);
});

test('browse reader distinguishes loading, loaded-empty and missing markup', () => {
  assert.equal(read('Browse', '<section id="content"></section><div id="spinner_load"></div>').ready, false);
  const empty = read('Browse', '<section id="content"></section><div id="spinner_load" style="display:none"></div>');
  assert.equal(empty.ready, true);
  assert.deepEqual(empty.items, []);
  assert.equal(read('Browse', '<main>Unexpected page</main>').ready, false);
});

test('details reader preserves episode identity separately from stale player identity', () => {
  const value = read('TitleDetails', `<div class="movie-info"><h1>Series</h1>
    <p class="movie-description">Synopsis</p><span class="movie-date">2024</span>
    <span class="movie-time">43 min</span><span class="imdb-rating">8.2</span>
    <span class="movie-genre"><a>Drama</a></span></div>
    <li class="li-season active" id="season_205">Season 1</li>
    <div class="tv-details-episodes"><ol class="active">
    <li class="li-episode active" data-episode="1723"><span class="item-episode-number">1</span>A Hard Day's Night</li>
    </ol></div><div id="video" aria-label="Video Player - Season 22 Episode 10 - Previous"></div>
    <video src="https://media.example/previous.mp4"></video>`);
  assert.equal(value.activeSeason, 'season_205');
  assert.equal(value.activeEpisode, '1723');
  assert.equal(value.episodes[0].title, "A Hard Day's Night");
  assert.equal(value.episodes[0].number, '1');
  assert.ok(!value.playerLabel.includes("Season 1 Episode 1 - A Hard Day's Night"));
  assert.deepEqual(value.genres, ['Drama']);
});

test('saved-list reader distinguishes selected, unselected and unavailable controls', () => {
  const value = read('TitleDetails', '<div class="favorites-add active">Saved</div><div class="watchlist-add">Watch later</div>');
  assert.equal(value.isFavourite, true);
  assert.equal(value.isWatchLater, false);
  const absent = read('TitleDetails', '<main>Unexpected page</main>');
  assert.equal(absent.isFavourite, null);
  assert.equal(absent.isWatchLater, null);
});

test('details reader excludes browser-local and insecure media URLs', () => {
  assert.equal(read('TitleDetails', '<video src="blob:https://viu.to/local"></video>').media, null);
  assert.equal(read('TitleDetails', '<video src="http://media.example/video.mp4"></video>').media, null);
  assert.equal(read('TitleDetails', '<video src="https://media.example/video.mp4"></video>').media, 'https://media.example/video.mp4');
});

test('live reader extracts labelled channels once and ignores icon and offsite links', () => {
  const result = read('LiveTV', `<a href="/wltv/640">&#xe600;</a><a href="/wltv/640">Channel Four</a>
    <a href="/wltv/640">Channel Four</a><a href="https://other.example/wltv/1">Other</a>`);
  assert.deepEqual(result.channels, [{id:'/wltv/640', title:'Channel Four', url:'https://viu.to/wltv/640'}]);
  assert.equal(result.stream, null);
});

test('live reader resolves HTTPS VLC handoff when video uses a browser blob', () => {
  const value = read('LiveTV', `<video src="blob:https://viu.to/local"></video>
    <a href="vlc-x-callback://x-callback-url/stream?url=https%3A%2F%2Fmedia.example%2Flive.m3u8%3Ftest%3D1">PLAY ON VLCPLAYER</a>`);
  assert.equal(value.stream, 'https://media.example/live.m3u8?test=1');
  const insecure = read('LiveTV', '<a href="vlc-x-callback://x-callback-url/stream?url=http%3A%2F%2Fmedia.example%2Flive.m3u8">VLC</a>');
  assert.equal(insecure.stream, null);
});
