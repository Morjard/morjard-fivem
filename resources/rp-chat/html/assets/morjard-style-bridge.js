/*
 * morjard-style-bridge.js
 *
 * Additive, unminified bridge: applies the server-chosen hybrid style
 * (Morjard / DDCZ, see ../../morjard-settings/shared/settings.lua) on top
 * of the built chat bundle's own theming system.
 *
 * Does NOT touch index.js/index.css (built output) -- it only calls the CSS
 * custom properties that bundle already reads (confirmed present in the
 * built bundle: --accent, --accent-rgb, --color-primary, --color-primary-rgb,
 * --secondary, --font-family-override).
 *
 * client.lua sends: SendNUIMessage({ action = 'applyMorjardStyle', style = {...} })
 * right after the resource starts, using the palette from morjard-settings.
 */
(function () {
  function applyStyle(style) {
    if (!style) return;
    var root = document.documentElement.style;
    if (style.accent) {
      root.setProperty('--accent', style.accent);
      root.setProperty('--color-primary', style.accent);
    }
    if (style.accentRgb) {
      root.setProperty('--accent-rgb', style.accentRgb);
      root.setProperty('--color-primary-rgb', style.accentRgb);
    }
    if (style.secondary) {
      root.setProperty('--secondary', style.secondary);
      root.setProperty('--color-secondary', style.secondary);
    }
    if (style.font) {
      root.setProperty('--font-family-override', style.font);
    }
  }

  window.addEventListener('message', function (event) {
    var data = event.data || {};
    if (data.action === 'applyMorjardStyle') {
      applyStyle(data.style);
    }
  });
})();
