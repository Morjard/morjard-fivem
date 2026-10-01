/*
 * morjard-style-bridge.js — additive, see ../morjard-settings and docs/HYBRID_STYLE.md.
 * Applies the server-chosen hybrid style on top of this resource's own palette
 * (style.css --accent/--accent2) without touching that file.
 * client/main.lua sends: SendNUIMessage({ type = 'applyMorjardStyle', style = {...} })
 */
window.addEventListener('message', function (event) {
    var data = event.data || {};
    if (data.type !== 'applyMorjardStyle' || !data.style) return;
    var root = document.documentElement.style;
    if (data.style.accent)    root.setProperty('--accent', data.style.accent);
    if (data.style.accentAlt) root.setProperty('--accent2', data.style.accentAlt);
});
