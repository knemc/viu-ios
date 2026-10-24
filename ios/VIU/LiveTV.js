(() => {
    const channels = new Map();
    for (const link of document.querySelectorAll('a')) {
        const url = new URL(link.href, location.href);
        const title = link.textContent.trim();
        if (url.origin === location.origin && /^\/wltv\/\d+$/.test(url.pathname) && /[\p{L}\p{N}]/u.test(title)) {
            channels.set(url.pathname, {id:url.pathname, title, url:url.href});
        }
    }
    const video = document.querySelector('video');
    let stream = video?.currentSrc || video?.src || video?.querySelector('source')?.src;
    if (!stream?.startsWith('https:')) {
        const vlc = Array.from(document.querySelectorAll('a')).find(a => a.protocol === 'vlc-x-callback:');
        stream = vlc ? new URL(vlc.href).searchParams.get('url') : null;
    }
    return JSON.stringify({channels:Array.from(channels.values()), stream:stream?.startsWith('https:') ? stream : null});
})();
