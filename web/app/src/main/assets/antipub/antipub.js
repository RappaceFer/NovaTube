/* NovaTube anti-pub : retire les pubs des reponses de YouTube avant que le lecteur ne les lise
   (meme principe que NovaTube / SmartTube). Tourne dans la page, avant les scripts de YouTube. */
(() => {
  'use strict';
  if (window.__novatubeAntiPub) return;
  window.__novatubeAntiPub = true;
  const DROP = new Set(['adPlacements', 'playerAds', 'adSlots', 'adBreakHeartbeatParams',
    'adBreakParams', 'adParams', 'adBreakServiceRenderer', 'promotedSparklesWebRenderer']);
  const AD_ITEM = /^(adSlotRenderer|promotedVideoRenderer|displayAdRenderer|compactPromotedVideoRenderer|statementBannerRenderer|adSlotAndLayoutRenderer|tvMastheadRenderer|bannerPromoRenderer)$/;
  const prune = (o, d) => {
    if (!o || typeof o !== 'object' || d > 40) return;
    if (Array.isArray(o)) {
      for (let i = o.length - 1; i >= 0; i--) {
        const it = o[i];
        if (it && typeof it === 'object' && !Array.isArray(it)) {
          const k = Object.keys(it);
          if (k.length && k.every(x => AD_ITEM.test(x))) { o.splice(i, 1); continue; }
        }
        prune(it, d + 1);
      }
      return;
    }
    for (const k of Object.keys(o)) {
      if (DROP.has(k)) { delete o[k]; continue; }
      const v = o[k];
      if (v && typeof v === 'object') prune(v, d + 1);
    }
  };
  /* on ne fouille que les reponses de l'API YouTube, pour rester rapide */
  const isYt = r => r && typeof r === 'object' && ('responseContext' in r || 'playabilityStatus' in r
    || 'playerResponse' in r || 'adPlacements' in r || 'playerAds' in r || 'contents' in r);
  const clean = r => { try { if (isYt(r)) prune(r, 0); } catch (e) {} return r; };

  const parse = JSON.parse;
  JSON.parse = function () { return clean(parse.apply(this, arguments)); };

  const rjson = Response.prototype.json;
  Response.prototype.json = function () { return rjson.apply(this, arguments).then(clean); };

  const desc = Object.getOwnPropertyDescriptor(XMLHttpRequest.prototype, 'response');
  if (desc && desc.get) {
    Object.defineProperty(XMLHttpRequest.prototype, 'response', {
      configurable: true,
      get() { const r = desc.get.call(this); return (this.responseType === 'json') ? clean(r) : r; }
    });
  }
  for (const name of ['ytInitialPlayerResponse', 'ytInitialData']) {
    let val;
    try {
      Object.defineProperty(window, name, { configurable: true, get() { return val; }, set(v) { val = clean(v); } });
    } catch (e) {}
  }
})();
