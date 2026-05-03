# Figma → Workwarrior Design System Rules

Generated from codebase analysis for MCP Figma integration.

---

## 1. Design Tokens

**Location:** `services/browser/static/style.css` — `:root {}` block

All tokens are CSS custom properties. There is no build-time transformation system (no Sass, no Style Dictionary, no Tailwind config). Tokens live directly in the browser stylesheet.

```css
/* Color tokens (copy these exactly — do not invent new hex values) */
:root {
  --bg: #0d1117;              /* page background */
  --surface: #161b22;         /* sidebar, panels, cards */
  --border: #21262d;          /* all borders */
  --text: #e6edf3;            /* primary text */
  --muted: #7d8590;           /* secondary/inactive text */
  --accent: #58a6ff;          /* primary blue — hover states, active nav, links */
  --success: #3fb950;         /* green */
  --warning: #d29922;         /* amber */
  --error: #f85149;           /* red */
  --term-green: #39d353;      /* terminal activity color */

  /* Function category colors */
  --clr-tasks: #3fb950;
  --clr-time: #79c0ff;
  --clr-journal: #d2883e;
  --clr-ledger: #e6edf3;
  --clr-warrior: #f85149;

  /* Layout tokens */
  --sidebar-w: 240px;
  --sidebar-collapsed-w: 42px;
  --row-gap: 8px;
  --font-size: 13px;
  --term-h: 80px;
}
```

**Token rules when translating from Figma:**
- Always use the token variable name, never the raw hex
- Dark theme only — there is no light theme and no theming system
- Do not add new color variables without a task card authorizing the addition

---

## 2. Component Library

**No framework component library.** The UI is vanilla HTML + vanilla JavaScript.

**Location:** `services/browser/static/`
- `index.html` — all markup (single-page app shell)
- `style.css` — all styles
- `app.js` — all interactivity

**Pattern:** BEM-adjacent flat class names. Components are CSS classes applied to HTML elements, not importable components. No Shadow DOM, no web components, no JSX.

```html
<!-- Example: nav item -->
<button class="nav-item active" data-section="tasks">
  <span class="nav-icon icon-tasks">∼</span>
  <span class="nav-label">Tasks</span>
</button>

<!-- Example: button states -->
<button class="cmd-ctrl-btn">CMD</button>
<button class="cmd-ctrl-btn active">CTRL</button>  <!-- active = accent border + tint -->
```

**No Storybook.** No component documentation system beyond the CSS file itself.

---

## 3. Frameworks & Libraries

| Layer | Technology |
|---|---|
| Markup | Vanilla HTML5 (single `index.html`) |
| Styling | Vanilla CSS (custom properties, no preprocessor) |
| JavaScript | Vanilla ES6+ (no framework, no bundler) |
| Backend | Python (`services/browser/server.py`) |
| AI SDK | `@google/generative-ai` (only dependency in `package.json`) |
| Shell | Bash 5 (`set -euo pipefail` required) |

**No React. No Vue. No Angular. No TypeScript. No build step for the browser UI.**

When translating Figma output: strip all JSX, Tailwind, and React-isms. Convert to plain HTML + CSS custom properties.

---

## 4. Asset Management

**Location:** `services/browser/static/` — flat directory, no subdirectories

- No CDN
- No image optimization pipeline
- No asset hashing or fingerprinting
- Static files served directly by `server.py`

Reference assets with root-relative paths: `/style.css`, `/app.js`

There are no image assets currently. Icons are Unicode characters embedded in HTML.

---

## 5. Icon System

**No icon library.** Icons are Unicode/emoji characters inline in HTML.

```html
<!-- Nav icons — colored badge squares -->
<span class="nav-icon icon-tasks">∼</span>   <!-- tasks -->
<span class="nav-icon icon-time">⭕</span>    <!-- time -->
<span class="nav-icon icon-journal">╱</span>  <!-- journal -->
<span class="nav-icon icon-ledger">═</span>   <!-- ledger -->

<!-- Action icons — bare Unicode -->
<span>⇄</span>   <!-- sync -->
<span>⤓</span>   <!-- export -->
<span>⚔</span>   <!-- sword weapon -->
<span>◎</span>   <!-- community -->
```

**Nav icon badges** use `.nav-icon` base class + a function color modifier:

```css
.nav-icon { width: 18px; height: 18px; border-radius: 3px; font-size: 12px; font-weight: bold; }
.icon-tasks { background: var(--clr-tasks); color: #000; }
.icon-time  { background: var(--clr-time);  color: #000; }
.icon-journal { background: var(--clr-journal); color: #fff; }
.icon-ledger  { background: var(--clr-ledger);  color: #000; }
```

When translating Figma icons: use the closest Unicode character. Do not introduce SVG icon libraries.

---

## 6. Styling Approach

**Methodology:** Flat CSS classes with CSS custom properties. No CSS Modules, no Styled Components, no utility-first framework.

**Global styles:** Yes — reset at top of `style.css`, then layout, then components in order.

**Responsive design:** None currently. The UI is desktop-only, terminal-first. No media queries, no mobile breakpoints. Do not add responsive behavior unless a task card explicitly requires it.

**Hover/active pattern:**
```css
/* Standard interactive element pattern */
.some-btn { background: var(--bg); border: 1px solid var(--border); color: var(--muted); }
.some-btn:hover { border-color: var(--accent); color: var(--accent); }
.some-btn.active { border-color: var(--accent); color: var(--accent); background: rgba(88,166,255,0.1); }
```

**Typography:** Monospace only. No serif or sans-serif.
```css
font-family: ui-monospace, Menlo, Consolas, "Liberation Mono", monospace;
font-size: 13px;
line-height: 1.5;
```

**Layout:** Flexbox for sidebar + main split. No CSS Grid in use currently.

```css
#app { display: flex; height: calc(100vh - var(--term-h)); }
```

---

## 7. Project Structure

```
services/browser/
  browser.sh        — bash entry point (start/stop/status/export)
  server.py         — Python HTTP server
  static/
    index.html      — single-page app shell (all panels rendered here)
    style.css       — all styles (tokens + components)
    app.js          — all frontend logic
  test_heuristic_compound.py

config/             — YAML configs (ai, models, ctrl, groups, shortcuts)
lib/                — bash libraries (24 files)
services/           — 25+ service categories, each a bash script
bin/ww              — main CLI dispatcher
```

**When adding UI panels from Figma:**
1. Add markup to `index.html` inside `<div id="main">`
2. Add styles to `style.css` following the existing flat-class pattern
3. Add JS behavior to `app.js`
4. Never create separate HTML files — everything is in the single SPA shell

---

## 8. Figma Translation Checklist

When receiving Figma design output and adapting it to this codebase:

- [ ] Strip all React/JSX — convert to plain HTML elements
- [ ] Strip all Tailwind classes — convert to CSS custom property references
- [ ] Replace hex color values with the appropriate `--token` variable
- [ ] Replace any sans-serif or variable font references with the monospace stack
- [ ] Use Unicode characters instead of SVG icon libraries
- [ ] Match the dark-only color scheme (no light mode branching)
- [ ] Keep font-size at 13px base unless the design explicitly shows a larger heading
- [ ] Use `var(--border)` for all borders, not hardcoded values
- [ ] Apply the standard hover/active pattern (muted → accent on hover, rgba tint when active)
- [ ] Confirm the new component class names don't collide with existing ones in `style.css`
