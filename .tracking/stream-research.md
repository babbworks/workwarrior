# Stream Research — 2026-06-04

## WebWarrior PWA (reference implementation at /Users/mp/Documents/WebWarrior/)

The elite-level stream in WebWarrior works as follows:

### Architecture
- `services/stream/` — full service with: index.js, format.js, config.js, intercept.js,
  session.js, render.js, lenses.js, bus.js, log.js, dey.js, cooper.js, export.js, replay.js,
  worker.js, regen.js
- Append-only event log: `$WW_BASE/stream/stream.log`
- **Positional encoding (Hollerith):** `<ts> <op> <action> <object> [<ctx_json>]`
  - OP codes: T(task), F(frick/focus), B(bundy/timew), D(dey/signal), H(header), S(system),
    A(annotation), M(mutation)
- 8 lenses: Burroughs, Bundy, Hollerith, Pacioli, Frick, Felt, Dey, Cooper

### Status model
- `status.enabled` = user has enabled stream feature globally (flag file or config)
- `status.active` = currently recording events
- Topbar visible across ALL sections when `enabled`; toggle btn `.active` when `active`

### Toggle wiring (verbatim from WebWarrior)
```javascript
document.getElementById('btn-stream-toggle-top')?.addEventListener('click', async () => {
  const status = await Stream.getStatus(activeProfile);
  await Stream.toggle(activeProfile, !status.active);
  updateStreamUI();
  showToast(status.active ? 'Stream paused' : 'Stream resumed');
});

async function updateStreamUI() {
  const status = await Stream.getStatus(activeProfile);
  const topbar = document.getElementById('stream-topbar');
  const navStream = document.getElementById('nav-stream');
  const toggleBtn = document.getElementById('btn-stream-toggle-top');
  if (topbar) topbar.classList.toggle('hidden', !status.enabled);
  if (navStream) navStream.classList.toggle('hidden', !status.enabled);
  if (toggleBtn) toggleBtn.classList.toggle('active', status.active);
}
```

### Mini waveform canvas
- 60×16px canvas, subscribes to `{op: 'D'}` bus events
- Draws live Dey intensity signal in real time

### Dey signal (signal processing)
- 11 source signals → weighted sum → EMA smoothing → (ts, i, s, f) samples
- Three dimensions: intensity (i), stability (s), fragmentation (f)
- Session detection: gap > threshold → session boundary

### Intercept layer
- `intercept.js` wraps all service modules to auto-capture events
- In ww backend equivalent: auto-ingest via on-modify hooks

---

## workwarrior repo (/Users/mp/Documents/Vaults/babb/repos/workwarrior)

No dedicated stream service, stream.log, or Hollerith encoding found.
Only "stream" references are stdin/stdout (`input_stream`) in Timewarrior on-modify hooks.
No Dey signal, lenses, or enable/disable mechanism exists in this codebase.
This is the original pre-WebWarrior codebase — stream was not yet built at this stage.

---

## ww-standard repo (/Users/mp/github/ww-standard) — DATED CONTENT NOTES

ww-standard is documentation (255 md files). Key dated/outdated items:

| Item | File | Issue |
|------|------|-------|
| taskwarrior-tui v0.25.4 "last version for TW v2.x" | repos/kdheepak-taskwarrior-tui.md:42 | Current is 0.26.12; TW v2.x no longer baseline |
| taskcheck "no longer actively developed" | taskcheck-integration.md:96 | Upstream dormant; ww still wraps it |
| Taskwiki "deprecating Python 2" | repos/tbabej-taskwiki.md:78 | Python 2 EOL since 2020 |
| setuptools inject for Python 3.12 / distutils removal | dependency-installer.md:53 | May be stale if taskw updated |
| Neovim v0.3.4 minimum | repos/soywod-kronos.vim.md:70 | 2018-era; modern guidance should require v0.5+ |

**NO stream service, Hollerith encoding, Dey signal, or lens content in ww-standard.**
ww-standard predates or does not document the stream subsystem.

---

## Current ww stream implementation gaps (repos/ww vs WebWarrior)

1. **Toggle semantics**: btn-stream-toggle-top calls `showSection('stream')` — wrong.
   Should: fetch status → toggle active → updateStreamUI()
2. **Topbar visibility**: topbar only shows when on stream section. Should show across all
   sections when stream is enabled (log exists).
3. **No /data/stream/status endpoint**: Full event load on every status check is wasteful.
   Need lightweight status endpoint.
4. **No enable/disable mechanism**: ww stream is file-based; need flag file or config entry.
5. **Lens rendering**: Current UI just renders raw event table. WebWarrior has 8 distinct
   lenses with computed views (Bundy=timew, Pacioli=ledger, Dey=signal, etc.)
6. **Mini waveform**: Not implemented. Needs D-op events and canvas renderer.
7. **Session detection**: Not implemented.
8. **Intercept layer**: No auto-capture. Events written manually by hooks.
