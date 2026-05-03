## TASK-SITE-039: Journal markdown rendering with toggle

Goal:                 Render journal entry bodies as formatted markdown in the browser UI,
                      with a per-session toggle to switch between rendered and raw text view.

Acceptance criteria:  1. Journal entry bodies render markdown (bold, italic, headers, lists,
                         inline code, blockquotes, links) instead of plain text
                      2. A toggle button in the Journal section header switches between
                         "Rendered" and "Raw" view modes; state persists across page/section
                         navigation within the session (localStorage key: journal_md_render)
                      3. The "show more" expansion respects the current toggle state
                      4. highlightTags() (tag/project chip colorization) still applies in
                         rendered mode — markdown is rendered first, then tags highlighted
                      5. Raw mode is identical to current behavior (no regression)
                      6. No external CDN dependencies — use a minimal bundled markdown
                         renderer (marked.js vendored into static/vendor/marked.min.js, or
                         a ~2KB hand-rolled subset covering the 6 constructs above)
                      7. bats tests/test-service-browser.bats passes (if it exists); manual
                         smoke: open browser, toggle on, verify a multi-line entry renders

Write scope:          services/browser/static/app.js
                      services/browser/static/style.css
                      services/browser/static/index.html
                      services/browser/static/vendor/marked.min.js  (new — vendored lib)

Tests required:       bats tests/test-service-browser.bats (if exists)
                      bats tests/
                      Manual: ww browser → Journal section → toggle render on/off, verify
                        bold/italic/headers/lists render correctly; verify raw mode unchanged;
                        verify toggle state survives switching away and back to Journal section

Rollback:             git checkout services/browser/static/app.js
                      git checkout services/browser/static/style.css
                      git checkout services/browser/static/index.html
                      git rm --cached services/browser/static/vendor/marked.min.js
                      rm -f services/browser/static/vendor/marked.min.js

Fragility:            None — browser static files only; no lib/ or sync involvement
                      SERIALIZED: none (app.js is not serialized; no parallel active Builder
                        task confirmed before dispatch)

Risk notes:           (Orchestrator) highlightTags() injects raw HTML spans; markdown renderer
                      must run before highlightTags, and the rendered HTML must be safe
                      (no user-supplied script injection). Use marked with sanitize option or
                      DOMPurify if renderer does not escape by default. Journal bodies come
                      from jrnl (user's own data), but XSS hygiene is still required.
                      The "show more" path at line ~3290 reconstructs innerHTML directly from
                      e.body — Builder must apply markdown + highlightTags there too.
                      (Builder pre-flight) [fill in before touching any file]

Status:               complete — 2026-04-27 (implementation confirmed in app.js renderMdBody/renderEntryBody/wireJournalMdToggle + index.html #journal-md-toggle button; localStorage key journal_md_render)
Taskwarrior:          wwdev task 13 (fded3e63-5361-4b88-8a13-da74380efdb6) status:completed
