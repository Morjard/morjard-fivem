# Ember Design System — the ONE house style

The whole suite follows this. Source of truth: `resources/morjard-multicharacter/html/style.css`.
The blue-slate "FLOW tokens" from the earlier Dark Reference wave are REJECTED — never apply them.

## Tier 1 — primitives

```css
--accent:        #F97316;  /* primary orange */
--accent2:       #FBBF24;  /* gold / amber */
--accent-glow:   rgba(249,115,22,0.35);
--accent-dim:    rgba(249,115,22,0.12);
--danger:        #EF4444;
--danger-dim:    rgba(239,68,68,0.12);
--warn:          #FBBF24;
--bg:            #060504;  /* near-black warm */
--bg2:           rgba(15,13,11,0.35);
--bg3:           rgba(26,23,20,0.28);
--border:        rgba(249,115,22,0.18);
--borderB:       rgba(249,115,22,0.45);
--border-light:  rgba(249,115,22,0.08);
--text:          #FAFAF9;   /* warm off-white */
--text-dim:      rgba(168,162,158,0.7);
--text-bright:   #ffffff;
--mono:          'JetBrains Mono', monospace;
--main:          'Inter', sans-serif;
--display:       'Space Grotesk', sans-serif;
--glass:         rgba(15,13,11,0.85);
--glass-border:  rgba(249,115,22,0.22);
--radius:        0px;
--transition:    0.25s ease;
```

## Rules

- Notched corners (NEVER rounded):
  ```css
  clip-path: polygon(4px 0, calc(100% - 4px) 0, 100% 4px, 100% calc(100% - 4px),
                     calc(100% - 4px) 100%, 4px 100%, 0 calc(100% - 4px), 0 4px);
  ```
- Section header pattern: uppercase tracked `--display` or `--mono` 10 px with `--accent`.
- Panel surfaces: linear-gradient from `rgba(15,13,11,0.85)` to `rgba(6,5,4,0.75)` + 1 px `--border` + box-shadow `0 0 60px rgba(0,0,0,0.5), inset 0 8px 24px rgba(249,115,22,0.03)`.
- No `backdrop-filter` over the game world — measured, it composites to black.
- Corner brackets (`.wc.tl/.tr/.bl/.br`): small L-shapes in `--accent` on each notched corner for important panels.
- Scanline overlay: subtle `repeating-linear-gradient` at 2 px with `rgba(0,0,0,0.03)` — only on large panels.
- Dividers: thin lines in `--border` with text center `--accent`.
- Hover: `--borderB` border, `rgba(249,115,22,0.06)` background bump, 0.25 s ease.
- Buttons:
  - primary: `rgba(249,115,22,0.06)` bg, `--borderB` border, `--accent` text, `--display` 14 px uppercase letter-spacing 0.2em; hover `linear-gradient(135deg, rgba(249,115,22,0.14), rgba(251,191,36,0.1))`; notched clip-path like panels.
  - secondary: `rgba(168,162,158,0.05)` bg, `rgba(168,162,158,0.18)` border, `--text-dim`; hover `--text`.
  - destructive: `--danger` border + text, `--danger-dim` hover fill.
- Status accents: `--accent` = active/selected, `--accent2` = highlighted secondary, `--danger` = critical, mono tag in `--text-dim` for neutral.
- Text hierarchy: labels mono uppercase `--text-dim` 10 px, values `--text` or mono.
- `prefers-reduced-motion` safeguard mandatory.

## Exceptions

- **morjard-multicharacter**: already the reference, don't touch again without user ask.
- **morjard-phone**: a device chassis MAY use `border-radius: 20px` for the frame only (physical object exception). Everything inside stays notched/square.
- **morjard-radio**: device chassis MAY use `border-radius: 10-14px` (physical object exception).
- Everything else: notched clip-path corners only.
