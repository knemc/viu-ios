(() => {
    const sections = Array.from(document.querySelectorAll('.slider-container')).map(section => {
        const seen = new Set();
        const items = Array.from(section.querySelectorAll('.item:not(.slick-cloned)')).flatMap(card => {
            const link = card.querySelector('a.movie-card-link');
            const title = card.querySelector('.movie-card-title')?.textContent.trim();
            if (!link || !title) return [];
            const url = new URL(link.href, location.href);
            if (url.origin !== location.origin || !/^\/(wm|wtv)\/\d+\//.test(url.pathname) || seen.has(url.href)) return [];
            seen.add(url.href);
            return [{id: url.pathname, title, url: url.href,
                poster: card.querySelector('.movie-card-thumb img')?.src || null,
                year: card.querySelector('.mf-year')?.textContent.trim() || '',
                rating: card.querySelector('.imdb-rating-icon span')?.textContent.trim() || ''}];
        });
        return {id: section.querySelector('.slider-title-container h1')?.textContent.trim() || '', items};
    }).filter(section => section.id && section.items.length);
    return JSON.stringify({sections});
})();
