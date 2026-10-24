(() => {
    const text = selector => document.querySelector(selector)?.textContent.trim() || '';
    const secureURL = value => {
        if (!value) return null;
        try {
            const url = new URL(value, location.href);
            return url.protocol === 'https:' ? url.href : null;
        } catch { return null; }
    };
    const video = document.querySelector('video');
    return JSON.stringify({
        title: text('.movie-info h1'),
        synopsis: text('.movie-description'),
        year: text('.movie-date'),
        runtime: text('.movie-time'),
        rating: text('.movie-info .imdb-rating'),
        isFavourite: document.querySelector('.favorites-add')?.classList.contains('active') ?? null,
        isWatchLater: document.querySelector('.watchlist-add')?.classList.contains('active') ?? null,
        genres: Array.from(document.querySelectorAll('.movie-info .movie-genre a')).map(e => e.textContent.trim()),
        media: secureURL(video?.currentSrc || video?.src || video?.querySelector('source')?.src),
        seasons: Array.from(document.querySelectorAll('.li-season')).map(e => ({id: e.id, title: e.textContent.trim()})),
        activeSeason: document.querySelector('.li-season.active')?.id || '',
        activeEpisode: document.querySelector('.tv-details-episodes ol.active .li-episode.active')?.getAttribute('data-episode') || '',
        playerLabel: document.querySelector('#video')?.getAttribute('aria-label') || '',
        episodes: Array.from(document.querySelectorAll('.tv-details-episodes ol.active .li-episode')).map(e => ({
            id:e.getAttribute('data-episode') || '',
            number:e.querySelector('.item-episode-number')?.textContent.trim() || '',
            title:Array.from(e.childNodes).filter(n => n.nodeType === Node.TEXT_NODE).map(n => n.textContent).join('').trim()
        })).filter(e => /^\d+$/.test(e.id))
    });
})();
