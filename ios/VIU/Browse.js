(() => {
    const content = document.querySelector('#content');
    const spinner = document.querySelector('#spinner_load');
    const seen = new Set();
    const items = Array.from(content?.querySelectorAll('.item') || []).flatMap(card => {
        const link = card.querySelector('.movie-card-link');
        const title = card.querySelector('.movie-card-title')?.textContent.trim();
        if (!link || !title) return [];
        const url = new URL(link.href, location.href);
        if (url.origin !== location.origin || !/^\/(wm|wtv)\/\d+\//.test(url.pathname) || seen.has(url.pathname)) return [];
        seen.add(url.pathname);
        const image = card.querySelector('.movie-card-thumb img');
        return [{id:url.pathname, title, url:url.href,
            poster:image?.src?.startsWith('https:') ? image.src : null,
            year:card.querySelector('.mf-year')?.textContent.trim() || '',
            rating:card.querySelector('.imdb-rating-icon span')?.textContent.trim() || ''}];
    });
    const searchSpinner = document.querySelector('#spinner');
    const hidden = element => !element || getComputedStyle(element).display === 'none';
    return JSON.stringify({items, query:new URL(location.href).searchParams.get('q') || '',
        ready:!!content && !!spinner && hidden(spinner) && hidden(searchSpinner)});
})();
