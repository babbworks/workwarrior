// app.js — Workwarrior Browser UI
// Vanilla JS, no frameworks. Serves as the SPA shell.

(function () {
  'use strict';

  // ── State ─────────────────────────────────────────────────────────────────
  let activeSection = 'tasks';
  const scrollPositions = new Map(); // section → scrollTop
  let termMode = 'execute'; // 'execute' | 'filter'
  let cmdHistory = JSON.parse(localStorage.getItem('ww-cmd-history') || '[]');
  let historyIdx = -1;
  let sseRetryDelay = 1000;
  let connTimeout = null;
  let sseSource = null;
  let ctrlState = {
    ai: { mode: 'local-only', cmd_ai: true, provider: '', model: '', available: false },
    command_line: { show_ww: true, show_ai: true },
    ui: { show_active_model: true },
  };

  // ── DOM refs ───────────────────────────────────────────────────────────────
  const sidebar       = document.getElementById('sidebar');
  const sidebarToggle = document.getElementById('sidebar-toggle');
  const profilePill   = document.getElementById('profile-pill');
  const profileList   = document.getElementById('profile-switcher');
  const connDot       = document.getElementById('conn-dot');
  const headerProfile = document.getElementById('header-profile');
  const sectionTitle  = document.getElementById('section-title');
  const termInput     = document.getElementById('term-input');
  const termPrompt    = document.getElementById('term-prompt');
  const cmdOutput     = document.getElementById('cmd-output');
  const hintsBar      = document.getElementById('hints-bar');
  const statTasksCount = document.getElementById('stat-tasks-count');
  const statTimeToday  = document.getElementById('stat-time-today');
  const statDate       = document.getElementById('stat-date');
  const statContextBar = document.getElementById('stat-context-bar');

  // ── Terminal position state ────────────────────────────────────────────────
  let termPosition = localStorage.getItem('ww-term-position') || 'bottom';
  const termPosToggle = document.getElementById('term-pos-toggle');

  // ── Typeahead command cache ────────────────────────────────────────────────
  let wwCommands = []; // [{name, desc}] loaded from /data/commands
  let cachedTasks = []; // full task objects for detail panel lookup
  let taskGroupMode = localStorage.getItem('ww-task-group-mode') === 'grouped';
  let udaSchema = new Map(); // name → {type, label}
  let bulkSelected = new Set(); // selected task IDs for bulk ops

  async function loadUdaSchema() {
    try {
      const res = await fetch('/data/udas');
      const data = await res.json();
      udaSchema = new Map((data.udas || []).map(u => [u.name, u]));
    } catch (_) {}
  }

  // ── Toast notifications ────────────────────────────────────────────────────
  // Non-blocking feedback for mutations. Auto-dismisses after 2s with fade.
  let toastContainer = null;

  function initToasts() {
    toastContainer = document.createElement('div');
    toastContainer.id = 'toast-container';
    document.body.appendChild(toastContainer);
  }

  function toast(msg, type = 'success', duration = 2000) {
    if (!toastContainer) return;
    const el = document.createElement('div');
    el.className = `toast toast-${type}`;
    el.textContent = msg;
    toastContainer.appendChild(el);
    // Trigger enter animation
    requestAnimationFrame(() => el.classList.add('toast-visible'));
    setTimeout(() => {
      el.classList.remove('toast-visible');
      el.addEventListener('transitionend', () => el.remove(), { once: true });
    }, duration);
  }

  // ── Sidebar ────────────────────────────────────────────────────────────────
  function initSidebar() {
    const collapsed = localStorage.getItem('ww-sidebar-collapsed') === 'true';
    if (collapsed) collapseSidebar(false); // no transition on init

    sidebarToggle.addEventListener('click', () => {
      const isCollapsed = sidebar.classList.contains('collapsed');
      if (isCollapsed) expandSidebar(true);
      else collapseSidebar(true);
    });
    document.getElementById('sidebar-peek')?.addEventListener('click', () => expandSidebar(true));
  }

  function collapseSidebar(animate) {
    if (!animate) sidebar.style.transition = 'none';
    sidebar.classList.add('collapsed');
    sidebarToggle.textContent = '›';
    localStorage.setItem('ww-sidebar-collapsed', 'true');
    if (!animate) requestAnimationFrame(() => { sidebar.style.transition = ''; });
  }

  function expandSidebar(animate) {
    if (!animate) sidebar.style.transition = 'none';
    sidebar.classList.remove('collapsed');
    sidebarToggle.textContent = '‹';
    localStorage.setItem('ww-sidebar-collapsed', 'false');
    if (!animate) requestAnimationFrame(() => { sidebar.style.transition = ''; });
  }

  // ── Nav ────────────────────────────────────────────────────────────────────
  function initNav() {
    document.querySelectorAll('.nav-item').forEach(btn => {
      btn.addEventListener('click', () => switchSection(btn.dataset.section));
    });
    document.getElementById('btn-group-toggle')?.addEventListener('click', () => {
      taskGroupMode = !taskGroupMode;
      localStorage.setItem('ww-task-group-mode', taskGroupMode ? 'grouped' : 'flat');
      renderTasks(cachedTasks);
    });
  }

  async function switchSection(name) {
    // Save current section scroll before hiding
    const contentArea = document.getElementById('content-area');
    if (contentArea && activeSection) scrollPositions.set(activeSection, contentArea.scrollTop);
    activeSection = name;
    document.querySelectorAll('.section').forEach(s => s.classList.add('hidden'));
    const el = document.getElementById('section-' + name);
    if (el) el.classList.remove('hidden');
    document.querySelectorAll('.nav-item').forEach(b => {
      b.classList.toggle('active', b.dataset.section === name);
    });
    // CMD/CTRL/weapon button active states
    document.querySelectorAll('.cmd-ctrl-btn').forEach(b => b.classList.toggle('active', b.dataset.section === name));
    document.getElementById('btn-weapon-gun')?.classList.toggle('active', name === 'gun');
    document.getElementById('btn-weapon-sword')?.classList.toggle('active', name === 'sword');
    const titleMap = {
      tasks:'Tasks', time:'Times', journal:'Journals', ledger:'Ledgers',
      next:'Next', schedule:'Schedule', gun:'Gun', cmd:'CMD', ctrl:'CTRL',
      sync:'Sync', groups:'Groups', models:'Models', network:'Network',
      export:'Export', questions:'Questions', bookbuilder:'BookBuilder',
      profile:'Profile', warrior:'Warrior', projects:'Projects', sword:'Sword'
    };
    sectionTitle.textContent = titleMap[name] || name;
    await loadSection(name);
    // Restore scroll position after content loads
    if (contentArea && scrollPositions.has(name)) {
      contentArea.scrollTop = scrollPositions.get(name);
    }
  }

  // ── Keyboard shortcuts ─────────────────────────────────────────────────────
  // g+key: section navigation. ?: show overlay. Escape: focus terminal input.
  // Skips when an input/textarea/select is focused.
  const KB_SECTIONS = {
    t: 'tasks',   T: 'time',    j: 'journal', l: 'ledger',
    n: 'next',    s: 'schedule',c: 'cmd',     C: 'ctrl',
    S: 'sync',    G: 'groups',  m: 'models',  N: 'network',
    e: 'export',  q: 'questions',p: 'profile',w: 'warrior',
    u: 'gun',     x: 'sword',
  };

  let gPrefixPending = false;
  let gPrefixTimer = null;

  function isInputFocused() {
    const el = document.activeElement;
    return el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT' || el.isContentEditable);
  }

  function initKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      if (isInputFocused()) { gPrefixPending = false; return; }

      // Escape → focus terminal input
      if (e.key === 'Escape') {
        const ti = document.querySelector('.terminal-input');
        if (ti) { ti.focus(); }
        gPrefixPending = false;
        closeShortcutOverlay();
        return;
      }

      // ? → toggle shortcut overlay
      if (e.key === '?') {
        e.preventDefault();
        toggleShortcutOverlay();
        gPrefixPending = false;
        return;
      }

      // g prefix handling
      if (e.key === 'g' && !gPrefixPending) {
        e.preventDefault();
        gPrefixPending = true;
        clearTimeout(gPrefixTimer);
        gPrefixTimer = setTimeout(() => { gPrefixPending = false; }, 1500);
        return;
      }

      if (gPrefixPending) {
        gPrefixPending = false;
        clearTimeout(gPrefixTimer);
        const section = KB_SECTIONS[e.key];
        if (section) {
          e.preventDefault();
          switchSection(section);
          closeShortcutOverlay();
        }
      }
    });
  }

  function toggleShortcutOverlay() {
    let overlay = document.getElementById('shortcut-overlay');
    if (overlay) { overlay.remove(); return; }
    overlay = document.createElement('div');
    overlay.id = 'shortcut-overlay';
    overlay.innerHTML = `
      <div class="shortcut-panel">
        <div class="shortcut-title">Keyboard Shortcuts <span class="shortcut-close">×</span></div>
        <div class="shortcut-grid">
          <span class="shortcut-key">g t</span><span>Tasks</span>
          <span class="shortcut-key">g T</span><span>Times</span>
          <span class="shortcut-key">g j</span><span>Journal</span>
          <span class="shortcut-key">g l</span><span>Ledger</span>
          <span class="shortcut-key">g n</span><span>Next</span>
          <span class="shortcut-key">g s</span><span>Schedule</span>
          <span class="shortcut-key">g c</span><span>CMD</span>
          <span class="shortcut-key">g C</span><span>CTRL</span>
          <span class="shortcut-key">g S</span><span>Sync</span>
          <span class="shortcut-key">g G</span><span>Groups</span>
          <span class="shortcut-key">g m</span><span>Models</span>
          <span class="shortcut-key">g N</span><span>Network</span>
          <span class="shortcut-key">g e</span><span>Export</span>
          <span class="shortcut-key">g q</span><span>Questions</span>
          <span class="shortcut-key">g p</span><span>Profile</span>
          <span class="shortcut-key">g w</span><span>Warrior</span>
          <span class="shortcut-key">g u</span><span>Gun</span>
          <span class="shortcut-key">g x</span><span>Sword</span>
          <span class="shortcut-key">?</span><span>This overlay</span>
          <span class="shortcut-key">Esc</span><span>Focus terminal</span>
        </div>
      </div>`;
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay || e.target.classList.contains('shortcut-close')) overlay.remove();
    });
    document.body.appendChild(overlay);
  }

  function closeShortcutOverlay() {
    document.getElementById('shortcut-overlay')?.remove();
  }

  // ── Profile ────────────────────────────────────────────────────────────────
  function setProfile(name) {
    const display = name || '—';
    profilePill.textContent = display;
    headerProfile.textContent = display;
    const badge = document.getElementById('term-profile-badge');
    if (badge) badge.textContent = display;
    document.querySelectorAll('#profile-switcher li').forEach(li => {
      li.classList.toggle('active-profile', li.dataset.profile === name);
    });
    applyTerminalIndicators();
  }

  function applyTerminalIndicators() {
    const badge = document.getElementById('term-profile-badge');
    const wwHint = document.getElementById('hints-bar');
    const aiActive = ctrlState.ai && ctrlState.ai.mode !== 'off' && ctrlState.ai.cmd_ai;
    if (badge) {
      const bits = [];
      if (ctrlState.command_line?.show_ww) bits.push('ww');
      if (ctrlState.command_line?.show_ai && aiActive) bits.push('(AI)');
      badge.textContent = bits.join(' ') || (profilePill.textContent || '');
    }
    if (wwHint) {
      const modelBits = [];
      if (ctrlState.ui?.show_active_model && ctrlState.ai?.provider) {
        const m = ctrlState.ai.model ? `/${ctrlState.ai.model}` : '';
        modelBits.push(`ai:${ctrlState.ai.provider}${m}`);
      }
      wwHint.textContent = `type a ww command — tab to filter mode${modelBits.length ? ' · ' + modelBits.join(' ') : ''}`;
    }
  }

  function applyAiMeta() {
    const meta = document.getElementById('cmd-ai-meta');
    if (!meta) return;
    const ai = ctrlState.ai || {};
    if (ai.mode === 'off' || !ai.cmd_ai) {
      meta.textContent = 'AI: off';
      return;
    }
    if (ai.provider) {
      meta.textContent = `AI: ${ai.provider}${ai.model ? '/' + ai.model : ''} · ${ai.mode}`;
      return;
    }
    meta.textContent = `AI: unavailable${ai.reason ? ' · ' + ai.reason : ''}`;
  }

  async function refreshCtrlState() {
    try {
      const r = await fetch('/data/ctrl');
      const data = await r.json();
      if (!data.ok) return;
      ctrlState = data;
      applyTerminalIndicators();
      applyAiMeta();
      const aiModeSelect = document.getElementById('ctrl-ai-mode');
      const aiStatus = document.getElementById('ctrl-ai-status');
      if (aiModeSelect) aiModeSelect.value = data.ai?.mode || 'local-only';
      if (aiStatus) {
        if (data.ai?.mode === 'off' || !data.ai?.cmd_ai) {
          aiStatus.textContent = 'AI disabled';
        } else if (data.ai?.provider) {
          aiStatus.textContent = `${data.ai.provider}${data.ai.model ? '/' + data.ai.model : ''}`;
        } else {
          aiStatus.textContent = data.ai?.reason || 'unavailable';
        }
      }
      const clWw = document.getElementById('ctrl-cl-ww');
      const clAi = document.getElementById('ctrl-cl-ai');
      const uiModel = document.getElementById('ctrl-ui-model');
      if (clWw) clWw.checked = !!data.command_line?.show_ww;
      if (clAi) clAi.checked = !!data.command_line?.show_ai;
      if (uiModel) uiModel.checked = !!data.ui?.show_active_model;
    } catch (_) {}
  }

  async function loadProfiles() {
    try {
      const res = await fetch('/data/profiles');
      const data = await res.json();
      if (!data.ok) return;
      profileList.innerHTML = '';
      (data.profiles || []).forEach(name => {
        const li = document.createElement('li');
        li.textContent = name;
        li.dataset.profile = name;
        if (name === data.active) li.classList.add('active-profile');
        li.addEventListener('click', () => switchProfile(name));
        profileList.appendChild(li);
      });
    } catch (_) { /* server not ready yet */ }
  }

  async function switchProfile(name) {
    profileList.classList.add('hidden');
    try {
      const res = await fetch('/profile', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ profile: name }),
      });
      const data = await res.json();
      if (data.ok) {
        setProfile(data.profile);
        profileResources = null;
        await loadProfileResources();
        await loadAccounts();
        await loadTimewTags();
        await loadSection(activeSection);
      }
    } catch (_) { }
  }

  function initProfilePill() {
    const _toggleProfileSwitcher = async (e) => {
      e.stopPropagation();
      if (profileList.classList.contains('hidden')) {
        await loadProfiles();
        profileList.classList.remove('hidden');
      } else {
        profileList.classList.add('hidden');
      }
    };
    profilePill.addEventListener('click', _toggleProfileSwitcher);
    // Header profile name also opens the profile switcher
    headerProfile?.addEventListener('click', _toggleProfileSwitcher);
    document.addEventListener('click', () => profileList.classList.add('hidden'));
  }

  // ── SSE ────────────────────────────────────────────────────────────────────
  function setConnected(yes) {
    connDot.classList.toggle('connected', yes);
    connDot.title = yes ? 'connected' : 'disconnected';
  }

  function resetConnTimeout() {
    clearTimeout(connTimeout);
    connTimeout = setTimeout(() => setConnected(false), 30000);
  }

  function connectSSE() {
    if (sseSource) { sseSource.close(); sseSource = null; }
    sseSource = new EventSource('/events');

    sseSource.addEventListener('connected', (e) => {
      const d = JSON.parse(e.data);
      setProfile(d.profile || '');
      setConnected(true);
      sseRetryDelay = 1000;
      resetConnTimeout();
    });

    sseSource.addEventListener('profile', (e) => {
      const d = JSON.parse(e.data);
      setProfile(d.profile || '');
    });

    sseSource.addEventListener('ping', () => {
      resetConnTimeout();
    });

    // Live data refresh: server broadcasts after mutations
    sseSource.addEventListener('data', (e) => {
      if (document.visibilityState === 'hidden') return;
      try {
        const d = JSON.parse(e.data);
        const type = d.type;
        if (type === 'tasks' && activeSection === 'tasks') loadTasks();
        else if (type === 'time' && activeSection === 'time') loadTime();
        else if (type === 'journal' && activeSection === 'journal') loadJournal();
      } catch (_) {}
    });

    sseSource.onerror = () => {
      setConnected(false);
      sseSource.close();
      sseSource = null;
      setTimeout(connectSSE, sseRetryDelay);
      sseRetryDelay = Math.min(sseRetryDelay * 2, 30000);
    };
  }

  // ── Terminal line ──────────────────────────────────────────────────────────
  let cachedJournalEntries = []; // populated by loadJournal for search use
  let journalPage = 1;          // current page (20 entries per page)
  let timeWeekOffset = 0;       // 0 = current week, -1 = last week, etc.
  let cachedTimeIntervals = []; // all intervals from server for week navigation

  function setTermMode(mode) {
    termMode = mode;
    const overlay = document.getElementById('search-overlay');
    if (mode === 'execute') {
      termPrompt.textContent = '❯ ';
      termPrompt.className = 'prompt-exec';
      termInput.value = '';
      termInput.dispatchEvent(new Event('input'));
      if (overlay) overlay.classList.add('hidden');
    } else if (mode === 'filter') {
      termPrompt.textContent = '/ ';
      termPrompt.className = 'prompt-filter';
      hintsBar.textContent = 'filtering ' + activeSection + ' — tab to execute mode';
      termInput.value = '';
      if (overlay) overlay.classList.add('hidden');
    } else if (mode === 'search') {
      termPrompt.textContent = '🔍 ';
      termPrompt.className = 'prompt-search';
      hintsBar.textContent = 'global search — Escape to cancel';
      termInput.value = '';
      if (overlay) { overlay.classList.remove('hidden'); overlay.querySelector('#search-results').innerHTML = '<div class="search-hint">Start typing to search tasks and journals…</div>'; }
    }
  }

  function showOutput(text, isError) {
    cmdOutput.textContent = text;
    cmdOutput.className = isError ? 'error' : '';
    cmdOutput.classList.remove('hidden');
    applyTermPosition(termPosition, false);
  }

  function hideOutput() {
    cmdOutput.classList.add('hidden');
    cmdOutput.textContent = '';
    applyTermPosition(termPosition, false);
  }

  // Pinned command: shows the last submitted command above the input so the
  // user can continue typing arguments (e.g. submit "j" then type "babb note").
  function setPinnedCmd(cmd) {
    let el = document.getElementById('term-pinned');
    if (!el) {
      el = document.createElement('span');
      el.id = 'term-pinned';
      el.className = 'term-pinned';
      const row = document.getElementById('terminal-input-row');
      row.insertBefore(el, termPrompt);
    }
    // Update pinned icon based on command type
    const iconEl = document.getElementById('term-pinned-icon');
    if (cmd) {
      el.textContent = cmd;
      el.classList.remove('hidden');
      if (iconEl) {
        const first = cmd.split(/\s/)[0];
        const iconMap = { task: 'icon-tasks', timew: 'icon-time', journal: 'icon-journal', j: 'icon-journal', ledger: 'icon-ledger', l: 'icon-ledger' };
        iconEl.className = 'term-pinned-icon ' + (iconMap[first] || '');
        iconEl.textContent = first === 'task' ? '∼' : first === 'timew' ? '⭕' : first === 'journal' || first === 'j' ? '╱' : first === 'ledger' || first === 'l' ? '═' : '';
        iconEl.classList.toggle('hidden', !iconEl.textContent);
      }
    } else {
      el.classList.add('hidden');
      if (iconEl) iconEl.classList.add('hidden');
    }
  }

  function pushHistory(cmd) {
    cmdHistory = [cmd, ...cmdHistory.filter(c => c !== cmd)].slice(0, 100);
    localStorage.setItem('ww-cmd-history', JSON.stringify(cmdHistory));
    historyIdx = -1;
  }

  async function execCmd(cmd) {
    pushHistory(cmd);
    setPinnedCmd(cmd);
    try {
      const res = await fetch('/cmd', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ cmd }),
      });
      const data = await res.json();
      showOutput(data.output || (data.error || 'no output'), !data.ok);
    } catch (err) {
      showOutput('error: ' + err.message, true);
    }
  }

  function initTerminal() {
    termInput.addEventListener('keydown', async (e) => {
      if (e.key === 'Tab') {
        e.preventDefault();
        if (termMode === 'search') { setTermMode('execute'); return; }
        setTermMode(termMode === 'execute' ? 'filter' : 'execute');
        return;
      }

      // / in execute mode → global search
      if (e.key === '/' && termMode === 'execute' && !termInput.value) {
        e.preventDefault();
        setTermMode('search');
        return;
      }

      if (e.key === 'Escape') {
        if (termMode === 'search') { setTermMode('execute'); return; }
        if (!cmdOutput.classList.contains('hidden')) {
          hideOutput();
        } else {
          termInput.value = '';
          setPinnedCmd(null);
          historyIdx = -1;
          termInput.dispatchEvent(new Event('input'));
        }
        return;
      }

      // ArrowUp/Down for command history
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        if (termMode === 'execute' && cmdHistory.length) {
          historyIdx = Math.min(historyIdx + 1, cmdHistory.length - 1);
          termInput.value = cmdHistory[historyIdx] || '';
        }
        return;
      }
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        if (termMode === 'execute') {
          historyIdx = Math.max(historyIdx - 1, -1);
          termInput.value = historyIdx >= 0 ? cmdHistory[historyIdx] : '';
        }
        return;
      }

      if (e.key === 'Enter') {
        const val = termInput.value.trim();
        if (!val) return;
        termInput.value = '';
        if (termMode === 'execute') {
          await execCmd(val);
          termInput.dispatchEvent(new Event('input'));
        } else {
          document.dispatchEvent(new CustomEvent('filter', { detail: { query: val, section: activeSection } }));
        }
        return;
      }

      // Live filter dispatch as user types (filter mode)
      if (termMode === 'filter') {
        requestAnimationFrame(() => {
          document.dispatchEvent(new CustomEvent('filter', {
            detail: { query: termInput.value, section: activeSection }
          }));
        });
      }
    });

    // Typeahead hints + live global search
    termInput.addEventListener('input', () => {
      const val = termInput.value.trim();
      if (termMode === 'search') {
        runGlobalSearch(val);
        return;
      }
      if (termMode === 'filter') {
        const rows = document.querySelectorAll(
          `#section-${activeSection} .task-row, #section-${activeSection} .journal-entry, #section-${activeSection} .ledger-row`
        );
        const visible = [...rows].filter(r => r.style.display !== 'none').length;
        hintsBar.textContent = `filtering ${visible} item${visible !== 1 ? 's' : ''} in ${activeSection} — tab to execute mode`;
        return;
      }
      if (!val) {
        const last = cmdHistory[0];
        hintsBar.textContent = last ? `last: ${last}` : 'type a ww command — tab to filter mode';
        return;
      }
      const matches = wwCommands.filter(c => c.name.startsWith(val) || c.name.includes(val));
      if (matches.length) {
        hintsBar.textContent = matches.slice(0, 3).map(c => `${c.name} — ${c.desc}`).join('  ·  ');
      } else {
        hintsBar.textContent = 'no matching command — tab to filter mode';
      }
    });
  }

  // ── Resource selectors (journals / ledgers / tasklists / timew) ─────────────

  let profileResources = null;

  async function loadProfileResources() {
    try {
      const res = await fetch('/data/profile-resources');
      const data = await res.json();
      if (data.ok) profileResources = data;
    } catch (_) {}
  }

  function renderResourceSelector(containerId, kind, activeKey, onSelect) {
    const container = document.getElementById(containerId);
    if (!container) return;
    if (!profileResources) { container.innerHTML = ''; return; }
    const options = profileResources.resources[kind] || {};
    const names = Object.keys(options);
    if (names.length === 0) { container.innerHTML = ''; return; }

    container.innerHTML = '';
    const wrap = document.createElement('span');
    wrap.className = 'resource-bar-inner';

    // Dropdown (always shown so user sees which resource is active)
    const sel = document.createElement('select');
    sel.className = 'resource-select';
    names.forEach(n => {
      const opt = document.createElement('option');
      opt.value = n;
      opt.textContent = n;
      if (n === activeKey) opt.selected = true;
      sel.appendChild(opt);
    });
    sel.addEventListener('change', async () => {
      await fetch('/resource', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ kind, name: sel.value }),
      });
      await loadProfileResources();
      await onSelect(sel.value);
    });
    wrap.appendChild(sel);

    // "+ new" button — available for all resource kinds
    const addBtn = document.createElement('button');
    addBtn.className = 'resource-add-btn';
    addBtn.textContent = '+';
    addBtn.title = 'Create new ' + kind.replace(/s$/, '');
    addBtn.addEventListener('click', () => {
      showResourceCreateForm(container, kind, sel, onSelect);
    });
    wrap.appendChild(addBtn);

    container.appendChild(wrap);
  }

  function showResourceCreateForm(container, kind, sel, onSelect) {
    // Don't add a second form
    if (container.querySelector('.resource-create-form')) return;
    const form = document.createElement('form');
    form.className = 'resource-create-form';
    const input = document.createElement('input');
    input.type = 'text';
    input.placeholder = 'name';
    input.className = 'resource-create-input';
    input.pattern = '[a-zA-Z0-9_-]+';
    const ok = document.createElement('button');
    ok.type = 'submit';
    ok.textContent = 'create';
    ok.className = 'resource-create-ok';
    const cancel = document.createElement('button');
    cancel.type = 'button';
    cancel.textContent = '×';
    cancel.className = 'resource-create-cancel';
    cancel.addEventListener('click', () => form.remove());
    form.appendChild(input);
    form.appendChild(ok);
    form.appendChild(cancel);
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const name = input.value.trim();
      if (!name) return;
      ok.disabled = true;
      try {
        const res = await fetch('/resource/create', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ kind, name }),
        });
        const data = await res.json();
        if (data.ok) {
          profileResources = { ok: true, resources: data.resources, active: profileResources.active };
          // Add new option to dropdown and select it
          const opt = document.createElement('option');
          opt.value = name;
          opt.textContent = name;
          sel.appendChild(opt);
          sel.value = name;
          // Switch active resource to the new one
          await fetch('/resource', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ kind, name }),
          });
          await loadProfileResources();
          toast(`✓ ${kind} '${name}' created`);
          form.remove();
          await onSelect(name);
        } else {
          input.setCustomValidity(data.error || 'failed');
          input.reportValidity();
          ok.disabled = false;
        }
      } catch (_) {
        ok.disabled = false;
      }
    });
    container.appendChild(form);
    input.focus();
  }

  async function refreshResourceSelectors(section) {
    if (!profileResources) return;
    const active = profileResources.active;
    if (section === 'tasks') {
      renderResourceSelector('tasklist-selector', 'tasklists', active.tasklist, () => loadTasks());
    } else if (section === 'time') {
      renderResourceSelector('timew-selector', 'timew', active.timew, () => loadTime());
    } else if (section === 'journal') {
      renderResourceSelector('journal-selector', 'journals', active.journal, () => loadJournal());
    } else if (section === 'ledger') {
      renderResourceSelector('ledger-selector', 'ledgers', active.ledger, () => loadLedger());
    }
  }

  // ── Data fetching ──────────────────────────────────────────────────────────

  async function loadSection(name) {
    if (name === 'tasks') await loadTasks();
    else if (name === 'time') await loadTime();
    else if (name === 'journal') await loadJournal();
    else if (name === 'ledger') await loadLedger();
    else if (name === 'next') await loadNext();
    else if (name === 'schedule') await loadSchedule();
    else if (name === 'gun') updateContextBar('gun', null);
    else if (name === 'cmd') { await refreshCtrlState(); updateContextBar('cmd', null); await loadCmdLog(); }
    else if (name === 'sync') { updateContextBar('sync', null); await loadSync(); }
    else if (name === 'groups') { updateContextBar('groups', null); await loadGroups(); }
    else if (name === 'models') { updateContextBar('models', null); await loadModels(); }
    else if (name === 'network') { updateContextBar('network', null); await loadNetwork(); }
    else if (name === 'export') updateContextBar('export', null);
    else if (name === 'questions') { updateContextBar('questions', null); await loadQuestions(); }
    else if (name === 'bookbuilder') updateContextBar('bookbuilder', null);
    else if (name === 'projects') { updateContextBar('projects', null); await loadProjects(); }
    else if (name === 'ctrl') { await refreshCtrlState(); updateContextBar('ctrl', null); }
    else if (name === 'profile') { updateContextBar('profile', null); await loadProfileScreen(); }
    else if (name === 'warrior') { updateContextBar('warrior', null); await loadWarrior(); }
    else updateContextBar(name, null);
    await refreshResourceSelectors(name);
  }

  async function loadNext() {
    const card = document.getElementById('next-card');
    try {
      const res = await fetch('/data/next');
      const data = await res.json();
      if (!data.ok || !data.task) {
        card.innerHTML = '<div class="empty-state">No next task — add some tasks to get started</div>';
        updateContextBar('next', null);
        return;
      }
      const t = data.task;
      updateContextBar('next', t);
      const urg = (t.urgency || 0).toFixed(1);
      const project = t.project ? `<span class="badge-project">${t.project}</span>` : '';
      const tags = (t.tags || []).map(g => `<span class="tag">${g}</span>`).join('');
      const due = t.due ? renderDue(t.due) : '';
      card.innerHTML = `<div class="next-task-card">
        <div class="next-label">next task · urgency ${urg}</div>
        <div class="next-desc">${t.description}</div>
        <div class="next-meta">${project}${tags}${due}</div>
        <div class="next-actions">
          <button class="act-btn act-start" data-id="${t.id}">▶ start</button>
          <button class="act-btn act-done" data-id="${t.id}">✓ done</button>
          <button class="act-btn" id="btn-next-skip" data-id="${t.id}">skip</button>
        </div>
      </div>`;
      card.querySelector('.act-start')?.addEventListener('click', async () => {
        await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
          body: JSON.stringify({ action: 'start', id: t.id }) });
        await loadNext();
      });
      card.querySelector('.act-done')?.addEventListener('click', async () => {
        await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
          body: JSON.stringify({ action: 'done', id: t.id }) });
        await loadNext();
      });
      // Skip just reloads — the task stays pending but user sees the next one
      card.querySelector('#btn-next-skip')?.addEventListener('click', async () => {
        await loadNext();
      });
    } catch (e) {
      renderError(card, `Next: ${e.message}`, loadNext);
      updateContextBar('next', null);
    }
  }

  async function loadSchedule() {
    const card = document.getElementById('schedule-card');
    try {
      const res = await fetch('/data/schedule');
      const data = await res.json();
      const badge = data.enabled
        ? '<span class="service-badge enabled">enabled</span>'
        : '<span class="service-badge disabled">disabled</span>';
      card.innerHTML = `<div class="service-card">
        <h3>Schedule service ${badge}</h3>
        <pre class="service-output">${data.output || '—'}</pre>
      </div>`;
      updateContextBar('schedule', data);
    } catch (e) {
      renderError(card, `Schedule: ${e.message}`, loadSchedule);
    }
  }

  async function loadTasks() {
    const list = document.getElementById('task-list');
    try {
      const res = await fetch('/data/tasks');
      const data = await res.json();
      if (!data.ok) {
        list.innerHTML = `<div class="empty-state">${data.error || 'No active profile'}</div>`;
        return;
      }
      renderTasks(data.tasks || []);
      // Update top bar task count stat
      const count = (data.tasks || []).length;
      if (statTasksCount) {
        statTasksCount.textContent = `${count} task${count !== 1 ? 's' : ''}`;
        statTasksCount.classList.remove('hidden');
      }
      updateContextBar('tasks', data.tasks || []);
    } catch (e) {
      renderError(list, `Tasks: ${e.message}`, loadTasks);
    }
  }

  // Returns HTML string for a single task row (used in both flat + grouped modes).
  // hideProject=true omits the project badge (grouped mode shows it in the header).
  function taskRowHTML(t, hideProject = false) {
    const urg = (t.urgency || 0).toFixed(1);
    const urgClass = t.urgency > 15 ? 'urg-high' : t.urgency > 10 ? 'urg-med' : t.urgency > 5 ? 'urg-low' : 'urg-none';
    const project = (!hideProject && t.project) ? `<span class="badge-project">${t.project}</span>` : '';
    const tags = (t.tags || []).map(g => `<span class="tag">${g}</span>`).join('');
    const pri = t.priority ? `<span class="pri-dot pri-${t.priority.toLowerCase()}">${t.priority}</span>` : '';
    const due = t.due ? renderDue(t.due) : '';
    const sched = (!t.due && t.scheduled) ? renderScheduled(t.scheduled) : '';
    const isActive = t.status === 'active';
    const activeClass = isActive ? ' task-active' : '';
    const startStop = isActive
      ? `<button class="act-btn act-stop" data-id="${t.id}"><span class="btn-icon">■</span><span class="btn-word">stop</span></button>`
      : `<button class="act-btn act-start" data-id="${t.id}"><span class="btn-icon">▶</span><span class="btn-word">start</span></button>`;
    const checked = bulkSelected.has(t.id) ? ' checked' : '';
    return `<div class="task-row${activeClass}" data-id="${t.id}" data-desc="${(t.description||'').replace(/"/g,'&quot;')}" data-project="${t.project || ''}" data-tags="${(t.tags || []).join(',')}">
      <input type="checkbox" class="task-cb" data-id="${t.id}"${checked} />
      <span class="urg ${urgClass}">${urg}</span>
      ${project}
      <span class="task-desc">${t.description}</span>
      ${tags}${due}${sched}${pri}
      <span class="task-actions">
        ${startStop}
        <button class="act-btn act-done" data-id="${t.id}"><span class="btn-icon">✓</span><span class="btn-word">done</span></button>
      </span>
    </div>
    <div class="task-inline-detail hidden" id="tid-${t.id}"></div>`;
  }

  function renderTasks(tasks) {
    const list = document.getElementById('task-list');
    cachedTasks = tasks;
    startActiveTaskRefresh();

    if (!tasks.length) {
      list.innerHTML = '<div class="empty-state">No pending tasks</div>';
      return;
    }

    // Update toggle button appearance
    const toggleBtn = document.getElementById('btn-group-toggle');
    if (toggleBtn) toggleBtn.classList.toggle('active', taskGroupMode);

    tasks.sort((a, b) => (b.urgency || 0) - (a.urgency || 0));
    try {
      if (taskGroupMode) {
        list.innerHTML = buildGroupedHTML(tasks);
      } else {
        list.innerHTML = tasks.map(t => taskRowHTML(t)).join('');
      }
    } catch(renderErr) {
      list.innerHTML = `<div class="empty-state">Render error: ${renderErr.message}</div>`;
      return;
    }

    // Wire action buttons (stopPropagation so they don't toggle the detail)
    list.querySelectorAll('.act-done').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        try {
          const res = await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ action:'done', id:parseInt(btn.dataset.id) }) });
          const data = await res.json();
          renderTasks(data.tasks || cachedTasks);
          toast('✓ task done');
        } catch (err) { toast('done failed', 'error'); }
      });
    });
    list.querySelectorAll('.act-start').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        try {
          const res = await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ action:'start', id:parseInt(btn.dataset.id) }) });
          const data = await res.json();
          renderTasks(data.tasks || cachedTasks);
          toast('▶ task started');
        } catch (err) { toast('start failed', 'error'); }
      });
    });
    list.querySelectorAll('.act-stop').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        try {
          const res = await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ action:'stop', id:parseInt(btn.dataset.id) }) });
          const data = await res.json();
          renderTasks(data.tasks || cachedTasks);
          toast('■ task stopped', 'info');
        } catch (err) { toast('stop failed', 'error'); }
      });
    });

    // Click row to toggle inline detail
    list.querySelectorAll('.task-row').forEach(row => {
      row.addEventListener('click', () => {
        const id = parseInt(row.dataset.id);
        const detailDiv = document.getElementById('tid-' + id);
        if (!detailDiv) return;
        // Close any other open detail
        list.querySelectorAll('.task-inline-detail').forEach(d => {
          if (d !== detailDiv) { d.classList.add('hidden'); d.innerHTML = ''; }
        });
        if (!detailDiv.classList.contains('hidden')) {
          detailDiv.classList.add('hidden'); detailDiv.innerHTML = '';
          return;
        }
        const task = cachedTasks.find(t => t.id === id);
        if (task) expandTaskInline(detailDiv, task);
      });
    });

    // Group headers: toggle collapse
    list.querySelectorAll('.task-group-header').forEach(hdr => {
      hdr.addEventListener('click', () => {
        const key = hdr.dataset.group;
        const body = hdr.nextElementSibling;
        if (!body) return;
        const collapsed = body.classList.toggle('hidden');
        const stored = JSON.parse(localStorage.getItem('ww-group-collapsed') || '{}');
        if (collapsed) stored[key] = true; else delete stored[key];
        localStorage.setItem('ww-group-collapsed', JSON.stringify(stored));
        hdr.classList.toggle('group-collapsed', collapsed);
      });
    });

    // Bulk checkboxes
    const bulkBar = document.getElementById('bulk-toolbar');
    const bulkCount = document.getElementById('bulk-count');
    const updateBulkBar = () => {
      const n = bulkSelected.size;
      if (bulkBar) bulkBar.classList.toggle('hidden', n === 0);
      if (bulkCount) bulkCount.textContent = `${n} selected`;
      const selAll = document.getElementById('bulk-select-all');
      if (selAll) selAll.checked = n > 0 && n === cachedTasks.length;
    };
    list.querySelectorAll('.task-cb').forEach(cb => {
      cb.addEventListener('change', (e) => {
        e.stopPropagation();
        const id = parseInt(cb.dataset.id);
        if (cb.checked) bulkSelected.add(id); else bulkSelected.delete(id);
        updateBulkBar();
      });
      cb.addEventListener('click', (e) => e.stopPropagation());
    });
    // Space on focused task row toggles checkbox
    list.querySelectorAll('.task-row').forEach(row => {
      row.setAttribute('tabindex', '0');
      row.addEventListener('keydown', (e) => {
        if (e.key === ' ') {
          e.preventDefault();
          const cb = row.querySelector('.task-cb');
          if (cb) { cb.checked = !cb.checked; cb.dispatchEvent(new Event('change')); }
        }
      });
    });
    updateBulkBar();

    document.getElementById('task-filter').addEventListener('input', filterTasks);
  }

  async function doBulkAction(op, args) {
    const ids = [...bulkSelected];
    if (!ids.length) return;
    const res = await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({ action:'bulk', ids, op, args: args || {} }) });
    const data = await res.json();
    if (data.ok) {
      bulkSelected.clear();
      renderTasks(data.tasks || cachedTasks);
      toast(`✓ ${op} applied to ${ids.length} task${ids.length !== 1 ? 's' : ''}`);
    } else { toast('bulk action failed', 'error'); }
  }

  function initBulkToolbar() {
    document.getElementById('bulk-select-all')?.addEventListener('change', (e) => {
      const checked = e.target.checked;
      if (checked) cachedTasks.forEach(t => bulkSelected.add(t.id));
      else bulkSelected.clear();
      renderTasks(cachedTasks);
    });
    document.getElementById('bulk-toolbar')?.querySelectorAll('.btn-bulk').forEach(btn => {
      btn.addEventListener('click', async () => {
        const op = btn.dataset.op;
        if (op === 'done') await doBulkAction('done');
        else if (op === 'delete') await doBulkAction('delete');
        else if (op === 'set-project') {
          const v = document.getElementById('bulk-project-input')?.value.trim();
          if (v !== undefined) await doBulkAction('modify', { project: v });
        } else if (op === 'add-tag') {
          const t = document.getElementById('bulk-tag-input')?.value.trim();
          if (t) await doBulkAction('modify', { tags_add: [t] });
        } else if (op === 'remove-tag') {
          const t = document.getElementById('bulk-tag-input')?.value.trim();
          if (t) await doBulkAction('modify', { tags_remove: [t] });
        } else if (op === 'set-priority') {
          const p = document.getElementById('bulk-priority-select')?.value;
          if (p !== undefined) await doBulkAction('modify', { priority: p });
        }
      });
    });
  }

  function buildGroupedHTML(tasks) {
    const today = new Date(); today.setHours(0,0,0,0);
    const collapsed = JSON.parse(localStorage.getItem('ww-group-collapsed') || '{}');
    const overdue = tasks.filter(t => t.due && new Date(t.due.replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3')) < today);
    const overdueIds = new Set(overdue.map(t => t.id));
    const rest = tasks.filter(t => !overdueIds.has(t.id));

    // Group by project
    const groups = new Map();
    rest.forEach(t => {
      const key = t.project || '__inbox__';
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(t);
    });

    let html = '';

    // Overdue pinned group
    if (overdue.length) {
      const isCollapsed = collapsed['__overdue__'];
      html += `<div class="task-group-header task-group-overdue${isCollapsed ? ' group-collapsed' : ''}" data-group="__overdue__">
        <span class="group-name">Overdue</span>
        <span class="group-meta">${overdue.length} task${overdue.length !== 1 ? 's' : ''}</span>
      </div>
      <div class="task-group-body${isCollapsed ? ' hidden' : ''}">
        ${overdue.map(t => taskRowHTML(t)).join('')}
      </div>`;
    }

    // Project groups (sorted by name, inbox last)
    const sortedKeys = [...groups.keys()].sort((a, b) => {
      if (a === '__inbox__') return 1;
      if (b === '__inbox__') return -1;
      return a.localeCompare(b);
    });
    sortedKeys.forEach(key => {
      const group = groups.get(key);
      const label = key === '__inbox__' ? 'inbox' : key;
      const isCollapsed = collapsed[key];
      const totalUrg = group.reduce((s, t) => s + (t.urgency || 0), 0);
      html += `<div class="task-group-header${isCollapsed ? ' group-collapsed' : ''}" data-group="${key}">
        <span class="group-name">${label}</span>
        <span class="group-meta">${group.length} · ${totalUrg.toFixed(0)}u</span>
      </div>
      <div class="task-group-body${isCollapsed ? ' hidden' : ''}">
        ${group.map(t => taskRowHTML(t, true)).join('')}
      </div>`;
    });
    return html;
  }

  // ── Global search ──────────────────────────────────────────────────────────
  function highlight(text, q) {
    if (!q) return text;
    const idx = text.toLowerCase().indexOf(q.toLowerCase());
    if (idx < 0) return text;
    return text.slice(0, idx) + `<mark>${text.slice(idx, idx + q.length)}</mark>` + text.slice(idx + q.length);
  }

  function runGlobalSearch(q) {
    const resultsEl = document.getElementById('search-results');
    if (!resultsEl) return;
    if (!q) {
      resultsEl.innerHTML = '<div class="search-hint">Start typing to search tasks and journals…</div>';
      hintsBar.textContent = 'global search — Escape to cancel';
      return;
    }
    const ql = q.toLowerCase();

    // Tasks
    const taskHits = cachedTasks.filter(t =>
      (t.description || '').toLowerCase().includes(ql) ||
      (t.project || '').toLowerCase().includes(ql) ||
      (t.tags || []).some(tag => tag.toLowerCase().includes(ql))
    );

    // Journal
    const journalHits = cachedJournalEntries.filter(e =>
      (e.body || e.title || '').toLowerCase().includes(ql)
    );

    const taskHTML = taskHits.length
      ? taskHits.slice(0, 15).map(t => {
          const proj = t.project ? `<span class="badge-project">${t.project}</span> ` : '';
          return `<div class="search-result search-result-task" data-id="${t.id}">
            <span class="sr-icon">✦</span>
            ${proj}<span class="sr-text">${highlight(t.description || '', q)}</span>
          </div>`;
        }).join('')
      : '<div class="search-none">no matching tasks</div>';

    const journalHTML = journalHits.length
      ? journalHits.slice(0, 10).map((e, i) => {
          const body = e.body || e.title || '';
          const snippet = body.length > 80 ? body.slice(0, 78) + '…' : body;
          return `<div class="search-result search-result-journal" data-idx="${e._idx ?? i}">
            <span class="sr-icon">◈</span>
            <span class="sr-date">${e.date || ''}</span>
            <span class="sr-text">${highlight(snippet, q)}</span>
          </div>`;
        }).join('')
      : '<div class="search-none">no matching journal entries</div>';

    resultsEl.innerHTML = `
      <div class="search-group-header">Tasks (${taskHits.length})</div>${taskHTML}
      <div class="search-group-header">Journal (${journalHits.length})</div>${journalHTML}`;

    hintsBar.textContent = `${taskHits.length + journalHits.length} results — Enter to navigate, Escape to cancel`;

    // Click task result → switch to tasks, open inline detail
    resultsEl.querySelectorAll('.search-result-task').forEach(el => {
      el.addEventListener('click', async () => {
        const id = parseInt(el.dataset.id);
        setTermMode('execute');
        await switchSection('tasks');
        setTimeout(() => {
          const row = document.querySelector(`.task-row[data-id="${id}"]`);
          if (row) { row.scrollIntoView({ block: 'center' }); row.click(); }
        }, 200);
      });
    });

    // Click journal result → switch to journal section
    resultsEl.querySelectorAll('.search-result-journal').forEach(el => {
      el.addEventListener('click', async () => {
        setTermMode('execute');
        await switchSection('journal');
        const idx = parseInt(el.dataset.idx);
        setTimeout(() => {
          const entries = document.querySelectorAll('.journal-entry');
          if (entries[idx]) entries[idx].scrollIntoView({ block: 'center' });
        }, 300);
      });
    });
  }

  // Service-managed UDA prefixes — these are read-only in the UI
  const svcUdaPrefixes = ['github','gitlab','jira','trello','bw_','sync_'];
  function isSvcUda(name) { return svcUdaPrefixes.some(p => name.startsWith(p)); }

  function expandTaskInline(el, t) {
    // Fetch full task to get all UDAs
    (async () => {
      try {
        const res = await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
          body: JSON.stringify({ action:'task_get', id:t.id }) });
        const data = await res.json();
        renderInlineEditor(el, data.ok && data.task ? data.task : t);
      } catch (_) { renderInlineEditor(el, t); }
    })();
  }

  function renderInlineEditor(el, t) {
    const stdFields = new Set(['id','uuid','description','status','entry','start','end','due',
      'until','wait','modified','scheduled','recur','mask','imask','parent','project',
      'priority','depends','tags','annotations','urgency']);
    const allUdas = Object.entries(t).filter(([k]) => !stdFields.has(k) && !k.startsWith('_'));
    const svcUdas = allUdas.filter(([k]) => isSvcUda(k));
    const userUdas = allUdas.filter(([k]) => !isSvcUda(k));

    const dueFmt = t.due ? t.due.replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3') : '';
    const scheduledFmt = t.scheduled ? t.scheduled.replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3') : '';
    const waitFmt = t.wait ? t.wait.replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3') : '';
    const entryFmt = t.entry ? t.entry.replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3') : '';
    const urg = (t.urgency || 0).toFixed(1);
    const annotations = (t.annotations || []).map(a =>
      `<div class="annotation">↳ <span style="color:var(--muted);font-size:11px">${a.entry ? a.entry.replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3') : ''}</span> ${a.description}</div>`
    ).join('');

    // Editable user UDAs — type-aware inputs
    let userUdaHtml = '';
    if (userUdas.length) {
      userUdaHtml = userUdas.map(([k, v]) => {
        const def = udaSchema.get(k);
        const utype = def?.type || 'string';
        const label = def?.label || k;
        const val = String(v ?? '').replace(/"/g, '&quot;');
        let input;
        if (utype === 'date') {
          // TW date format 20250101T000000Z → YYYY-MM-DD
          const dateFmt = val.replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3');
          input = `<input type="date" class="task-detail-uda-input" data-uda="${k}" data-type="date" value="${dateFmt}" />`;
        } else if (utype === 'numeric') {
          input = `<input type="number" class="task-detail-uda-input" data-uda="${k}" data-type="numeric" value="${val}" step="any" />`;
        } else if (utype === 'duration') {
          input = `<input type="text" class="task-detail-uda-input" data-uda="${k}" data-type="duration" value="${val}" placeholder="e.g. 2h 30m" pattern="[0-9a-zA-Z ]+" title="e.g. 2h, 30m, 1d" />`;
        } else {
          input = `<input type="text" class="task-detail-uda-input" data-uda="${k}" data-type="string" value="${val}" />`;
        }
        return `<div class="task-detail-uda-row"><label class="task-detail-uda-label" title="${utype}">${label}</label>${input}</div>`;
      }).join('');
    }

    // Read-only service UDAs (collapsed)
    let svcUdaHtml = '';
    if (svcUdas.length) {
      svcUdaHtml = `<details class="task-detail-svc-udas"><summary class="task-detail-uda-header">service UDAs (${svcUdas.length})</summary>`;
      svcUdas.forEach(([k, v]) => {
        svcUdaHtml += `<div class="task-detail-uda-row"><label class="task-detail-uda-label">${k}</label><span class="task-detail-ro" style="font-size:11px">${String(v ?? '')}</span></div>`;
      });
      svcUdaHtml += '</details>';
    }

    el.innerHTML = `
      <div class="task-detail-edit-grid">
        <label>description</label><input type="text" data-field="te-desc" value="${(t.description || '').replace(/"/g, '&quot;')}" />
        <label>project</label><input type="text" data-field="te-project" value="${t.project || ''}" />
        <label>priority</label><select data-field="te-priority"><option value="">—</option><option${t.priority==='H'?' selected':''}>H</option><option${t.priority==='M'?' selected':''}>M</option><option${t.priority==='L'?' selected':''}>L</option></select>
        <label>due</label><input type="date" data-field="te-due" value="${dueFmt}" />
        <label>sched</label><input type="date" data-field="te-scheduled" value="${scheduledFmt}" />
        <label>wait</label><input type="date" data-field="te-wait" value="${waitFmt}" />
        <label>tags</label><input type="text" data-field="te-tags" value="${(t.tags || []).join(', ')}" />
        <label>status</label><span class="task-detail-ro">${t.status || 'pending'}</span>
        <label>urgency</label><span class="task-detail-ro">${urg}</span>
        <label>created</label><span class="task-detail-ro">${entryFmt}</span>
      </div>
      ${userUdaHtml ? '<div class="task-detail-uda-section"><div class="task-detail-uda-header">UDAs</div>' + userUdaHtml + '</div>' : ''}
      ${svcUdaHtml}
      <div class="task-detail-uda-section">
        <div class="task-detail-input" style="margin-top:4px">
          <input type="text" class="te-add-uda-name" placeholder="add UDA (type to search)…" list="uda-autocomplete-list" style="width:140px" />
          <datalist id="uda-autocomplete-list"></datalist>
          <input type="text" class="te-add-uda-value" placeholder="value" style="flex:1" />
          <button class="btn-inline-alt te-add-uda-btn">+ UDA</button>
        </div>
      </div>
      <div class="task-detail-actions">
        <button class="btn-inline-submit te-save">save</button>
      </div>
      ${annotations ? '<div class="task-detail-annotations">' + annotations + '</div>' : ''}
      <div class="task-detail-input"><input type="text" class="te-annotate-input" placeholder="add annotation…" /><button class="btn-inline-submit te-annotate-btn">annotate</button></div>
      <div class="task-detail-input"><input type="text" class="te-note-input" placeholder="note to journal…" /><span class="te-journal-sel-slot"></span><button class="btn-inline-alt te-note-btn">→ journal</button></div>
    `;
    el.classList.remove('hidden');

    // Insert journal selector
    const jSelSlot = el.querySelector('.te-journal-sel-slot');
    if (jSelSlot) jSelSlot.appendChild(makeJournalSelect());

    // Populate UDA autocomplete from cached schema
    const dl = el.querySelector('#uda-autocomplete-list');
    if (dl && udaSchema.size) {
      udaSchema.forEach(u => {
        const opt = document.createElement('option');
        opt.value = u.name;
        opt.label = `${u.name} (${u.type}) — ${u.label}`;
        dl.appendChild(opt);
      });
    }
    // Auto-switch value input type when a known UDA name is chosen
    const nameInpAuto = el.querySelector('.te-add-uda-name');
    const valInpAuto = el.querySelector('.te-add-uda-value');
    nameInpAuto?.addEventListener('input', () => {
      const def = udaSchema.get(nameInpAuto.value.trim());
      if (!def || !valInpAuto) return;
      const utype = def.type;
      valInpAuto.type = utype === 'numeric' ? 'number' : utype === 'date' ? 'date' : 'text';
      valInpAuto.placeholder = utype === 'duration' ? 'e.g. 2h 30m' : utype === 'date' ? 'YYYY-MM-DD' : 'value';
    });

    // Add UDA button
    const addUdaBtn = el.querySelector('.te-add-uda-btn');
    if (addUdaBtn) {
      addUdaBtn.addEventListener('click', async () => {
        const nameInp = el.querySelector('.te-add-uda-name');
        const valInp = el.querySelector('.te-add-uda-value');
        const udaName = nameInp?.value?.trim();
        const udaVal = valInp?.value?.trim();
        if (!udaName || !udaVal) return;
        const res = await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
          body: JSON.stringify({ action:'task_modify', id:t.id, args:{ [udaName]: udaVal } }) });
        const data = await res.json();
        if (data.ok || data.tasks) {
          cachedTasks = data.tasks || cachedTasks;
          const updated = cachedTasks.find(x => x.id === t.id);
          if (updated) renderInlineEditor(el, updated);
          else { nameInp.value = ''; valInp.value = ''; }
        }
      });
      el.querySelector('.te-add-uda-value')?.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') { e.preventDefault(); addUdaBtn.click(); }
      });
    }

    // Save
    el.querySelector('.te-save').addEventListener('click', async () => {
      const mods = {};
      const gf = (sel) => el.querySelector(`[data-field="${sel}"]`);
      const newDesc = gf('te-desc').value.trim();
      if (newDesc && newDesc !== t.description) mods.description = newDesc;
      const newProj = gf('te-project').value.trim();
      if (newProj !== (t.project || '')) mods.project = newProj || '';
      const newPri = gf('te-priority').value;
      if (newPri !== (t.priority || '')) mods.priority = newPri || '';
      const newDue = gf('te-due').value;
      if (newDue !== dueFmt) mods.due = newDue || '';
      const newSched = gf('te-scheduled').value;
      if (newSched !== scheduledFmt) mods.scheduled = newSched || '';
      const newWait = gf('te-wait').value;
      if (newWait !== waitFmt) mods.wait = newWait || '';
      const oldTags = new Set(t.tags || []);
      const newTags = new Set(gf('te-tags').value.split(',').map(s => s.trim()).filter(Boolean));
      const tagsAdd = [...newTags].filter(x => !oldTags.has(x));
      const tagsRm = [...oldTags].filter(x => !newTags.has(x));
      if (tagsAdd.length) mods.tags_add = tagsAdd;
      if (tagsRm.length) mods.tags_remove = tagsRm;
      el.querySelectorAll('.task-detail-uda-input').forEach(inp => {
        const k = inp.dataset.uda;
        let v = inp.value.trim();
        // Normalize date UDAs: YYYY-MM-DD → YYYYMMDDTHHMMSSZ for TW
        if (inp.dataset.type === 'date' && v && /^\d{4}-\d{2}-\d{2}$/.test(v)) {
          v = v.replace(/-/g, '') + 'T000000Z';
        }
        const orig = String(t[k] ?? '');
        if (v !== orig) mods[k] = v;
      });
      if (!Object.keys(mods).length) return;
      const res = await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ action:'task_modify', id:t.id, args:mods }) });
      const data = await res.json();
      if (data.ok) {
        cachedTasks = data.tasks || [];
        const updated = cachedTasks.find(x => x.id === t.id);
        if (updated) renderInlineEditor(el, updated);
      }
    });

    // Annotate
    const annBtn = el.querySelector('.te-annotate-btn');
    const annInp = el.querySelector('.te-annotate-input');
    const doAnnotate = async () => {
      const note = annInp.value.trim();
      if (!note) return;
      const res = await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ action:'annotate', id:t.id, args:{ note } }) });
      const data = await res.json();
      if (data.ok) {
        cachedTasks = data.tasks || [];
        const updated = cachedTasks.find(x => x.id === t.id);
        if (updated) renderInlineEditor(el, updated);
      }
    };
    annBtn.addEventListener('click', doAnnotate);
    annInp.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); doAnnotate(); } });

    // Journal note
    const noteBtn = el.querySelector('.te-note-btn');
    const noteInp = el.querySelector('.te-note-input');
    const doNote = async () => {
      const note = noteInp.value.trim();
      if (!note) return;
      const entry = `[task:${t.id}] ${t.description} — ${note}`;
      const jSel = el.querySelector('.journal-target-select');
      await sendJournalNote(entry, jSel);
      noteInp.value = '';
      noteInp.placeholder = '✓ added to journal';
      setTimeout(() => { if (noteInp) noteInp.placeholder = 'note to journal…'; }, 2000);
    };
    noteBtn.addEventListener('click', doNote);
    noteInp.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); doNote(); } });
  }

  function showTaskDetail(t) {
    // Legacy entry point — redirect to inline
    const el = document.getElementById('tid-' + t.id);
    if (el) expandTaskInline(el, t);
  }

  function filterTasks() {
    const q = (document.getElementById('task-filter')?.value || '').toLowerCase();
    document.querySelectorAll('.task-row').forEach(row => {
      const match = !q
        || row.dataset.desc.toLowerCase().includes(q)
        || (row.dataset.project || '').toLowerCase().includes(q)
        || (row.dataset.tags || '').toLowerCase().includes(q);
      row.style.display = match ? '' : 'none';
    });
  }

  // Terminal filter mode pushes into the inline filter box for the tasks section
  document.addEventListener('filter', (e) => {
    if (e.detail.section !== 'tasks') return;
    const fi = document.getElementById('task-filter');
    if (fi) { fi.value = e.detail.query; filterTasks(); }
  });

  function renderDue(due) {
    // due is "20260415T000000Z" format from task export
    const ts = Date.parse(due.replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3'));
    if (isNaN(ts)) return '';
    const days = Math.round((ts - Date.now()) / 86400000);
    const cls = days < 0 ? 'due-overdue' : days <= 2 ? 'due-soon' : 'due-ok';
    const label = days < 0 ? `${Math.abs(days)}d overdue` : days === 0 ? 'today' : `in ${days}d`;
    return `<span class="due ${cls}">${label}</span>`;
  }

  function renderScheduled(scheduled) {
    const ts = Date.parse(scheduled.replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3'));
    if (isNaN(ts)) return '';
    const days = Math.round((ts - Date.now()) / 86400000);
    if (days < 0) return ''; // past scheduled — don't show badge
    const label = days === 0 ? 'sched: today' : `sched: in ${days}d`;
    return `<span class="sched-badge">${label}</span>`;
  }

  // ── Time formatting — second and millisecond granularity ──────────────────
  // s = seconds (float ok for sub-second). Used throughout time section.
  function fmtDuration(s) {
    if (s < 0) s = 0;
    if (s < 1)    return `${Math.round(s * 1000)}ms`;
    if (s < 60)   return `${s.toFixed(1)}s`;
    if (s < 3600) return `${Math.floor(s / 60)}m ${Math.floor(s % 60)}s`;
    return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m ${Math.floor(s % 60)}s`;
  }

  // Live elapsed timer for active tracking — updates every second
  let activeTrackingInterval = null;
  function startLiveElapsed(activeSinceISO) {
    stopLiveElapsed();
    const startMs = activeSinceISO
      ? Date.parse(activeSinceISO.replace(/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z/, '$1-$2-$3T$4:$5:$6Z'))
      : null;
    if (!startMs) return;
    const badge = document.getElementById('term-profile-badge');
    const updateElapsed = () => {
      const elapsed = (Date.now() - startMs) / 1000;
      const el = document.getElementById('timew-live-elapsed');
      if (el) el.textContent = fmtDuration(elapsed);
      // Also update terminal badge with elapsed if in time section
      if (activeSection === 'time' && badge) {
        const base = badge.dataset.base || badge.textContent;
        badge.dataset.base = base;
      }
    };
    updateElapsed();
    activeTrackingInterval = setInterval(updateElapsed, 1000);
  }
  function stopLiveElapsed() {
    if (activeTrackingInterval) { clearInterval(activeTrackingInterval); activeTrackingInterval = null; }
  }

  // Parse TW timestamp "20260413T104500Z" → milliseconds
  function parseTwTs(ts) {
    if (!ts) return 0;
    return Date.parse(ts.replace(/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z/, '$1-$2-$3T$4:$5:$6Z'));
  }

  // Get Monday 00:00 for the week at `offset` weeks from now
  function weekStartFor(offset) {
    const now = new Date();
    const todayIdx = (now.getDay() + 6) % 7; // Mon=0
    const mon = new Date(now);
    mon.setHours(0,0,0,0);
    mon.setDate(now.getDate() - todayIdx + offset * 7);
    return mon;
  }

  function renderWeekBars(container, fmt) {
    const dayMap = {};
    const wkStart = weekStartFor(timeWeekOffset);
    const wkEnd = new Date(wkStart); wkEnd.setDate(wkEnd.getDate() + 7);
    cachedTimeIntervals.forEach(iv => {
      const ts = parseTwTs(iv.start);
      if (ts >= wkStart.getTime() && ts < wkEnd.getTime()) {
        const d = iv.start.slice(0, 8);
        dayMap[d] = (dayMap[d] || 0) + iv.duration;
      }
    });
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const now = new Date();
    const todayKey = now.toISOString().slice(0, 10).replace(/-/g, '');
    const weekTotal = Object.values(dayMap).reduce((s, v) => s + v, 0);
    const maxSec = 8 * 3600;

    // Date range label
    const wkEndDisp = new Date(wkEnd); wkEndDisp.setDate(wkEnd.getDate() - 1);
    const rangeLabel = `${wkStart.toLocaleDateString([],{month:'short',day:'numeric'})} – ${wkEndDisp.toLocaleDateString([],{month:'short',day:'numeric'})}`;
    const isCurrentWeek = timeWeekOffset === 0;

    let html = `<div class="week-nav">
      <button class="btn-week-nav" id="btn-week-prev">‹ prev</button>
      <span class="week-range-label">${rangeLabel}</span>
      <button class="btn-week-nav" id="btn-week-next"${isCurrentWeek ? ' disabled' : ''}>next ›</button>
    </div>
    <div class="week-bars">`;
    for (let i = 0; i < 7; i++) {
      const d = new Date(wkStart);
      d.setDate(wkStart.getDate() + i);
      const key = d.toISOString().slice(0, 10).replace(/-/g, '');
      const secs = dayMap[key] || 0;
      const pct = Math.min(100, Math.round(secs / maxSec * 100));
      const isToday = key === todayKey;
      html += `<div class="week-day">
        <span class="day-name${isToday ? ' day-current' : ''}">${dayNames[i]} ${d.getDate()}</span>
        <div class="day-bar"><div class="day-fill${isToday ? ' day-fill-current' : ''}" style="width:${pct}%"></div></div>
        <span class="day-total">${secs ? fmt(secs) : '—'}</span>
      </div>`;
    }
    html += `<div class="week-total">Week total: ${fmt(weekTotal)}</div></div>`;
    container.innerHTML = html;

    container.querySelector('#btn-week-prev')?.addEventListener('click', () => {
      timeWeekOffset--;
      renderWeekBars(container, fmt);
      // Re-render intervals for the new week
      const section = document.getElementById('section-time');
      if (section) { loadTime(); } // re-fetch so intervals update
    });
    container.querySelector('#btn-week-next')?.addEventListener('click', () => {
      if (timeWeekOffset >= 0) return;
      timeWeekOffset++;
      renderWeekBars(container, fmt);
      loadTime();
    });
  }

  async function loadTime() {
    const today = document.getElementById('time-today');
    const week  = document.getElementById('time-week');
    const ints  = document.getElementById('time-intervals');
    try {
      const res = await fetch('/data/time');
      const data = await res.json();
      if (!data.ok) { today.innerHTML = `<div class="empty-state">${data.error || 'No active profile'}</div>`; return; }

      const fmt = fmtDuration;

      // Populate task selector for time entry association
      try {
        const taskRes = await fetch('/data/tasks');
        const taskData = await taskRes.json();
        const sel = document.getElementById('time-task-select');
        if (sel && taskData.ok) {
          const current = sel.value;
          sel.innerHTML = '<option value="">no task</option>';
          (taskData.tasks || []).forEach(t => {
            const opt = document.createElement('option');
            opt.value = t.id;
            opt.textContent = t.description;
            if (String(t.id) === current) opt.selected = true;
            sel.appendChild(opt);
          });
        }
      } catch (_) {}

      // Today card with active tracking indicator
      let todayHtml = `<div class="time-card">`;
      todayHtml += `<span class="time-total">${fmt(data.today_total_seconds)}</span><span class="time-label"> today</span>`;
      if (data.active) {
        const sinceLocal = data.active_since ? new Date(
          data.active_since.replace(/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z/,
            '$1-$2-$3T$4:$5:$6Z')).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit',second:'2-digit'}) : '';
        const elapsedSec = data.active_since
          ? (Date.now() - Date.parse(data.active_since.replace(/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z/, '$1-$2-$3T$4:$5:$6Z'))) / 1000
          : 0;
        todayHtml += `<span class="tracking-badge"><span class="pulse-dot"></span> tracking ${data.active_tags || ''}</span>`;
        todayHtml += `<span class="tracking-elapsed" id="timew-live-elapsed">${fmt(elapsedSec)}</span>`;
        todayHtml += sinceLocal ? `<span class="idle-badge"> since ${sinceLocal}</span>` : '';
        startLiveElapsed(data.active_since);
      } else {
        stopLiveElapsed();
        todayHtml += `<span class="idle-badge">idle</span>`;
      }
      todayHtml += `</div>`;
      today.innerHTML = todayHtml;

      // Update today's time stat in top bar (second granularity)
      if (statTimeToday) {
        statTimeToday.textContent = `${fmtDuration(data.today_total_seconds)} today`;
        statTimeToday.classList.remove('hidden');
      }
      updateContextBar('time', data);

      // Cache all intervals for week navigation
      cachedTimeIntervals = data.intervals || [];
      renderWeekBars(week, fmt);

      // Recent intervals for selected week, grouped by local date
      const byDay = {};
      const wkStart = weekStartFor(timeWeekOffset);
      const wkEnd = new Date(wkStart); wkEnd.setDate(wkEnd.getDate() + 7);
      const weekIvs = cachedTimeIntervals.filter(iv => {
        const ts = parseTwTs(iv.start);
        return ts >= wkStart.getTime() && ts < wkEnd.getTime();
      });
      [...weekIvs].reverse().slice(0, 30).forEach(iv => {
        const d = new Date(iv.start.replace(/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z/, '$1-$2-$3T$4:$5:$6Z'));
        const key = d.toLocaleDateString([], {weekday:'short', month:'short', day:'numeric'});
        if (!byDay[key]) byDay[key] = [];
        byDay[key].push(iv);
      });
      let intHtml = '<div class="intervals-header">Recent</div>';
      Object.entries(byDay).forEach(([day, ivs]) => {
        intHtml += `<div class="day-group-header">${day}</div>`;
        ivs.forEach(iv => {
          const dot = iv.active ? '<span class="pulse-dot"></span> ' : '';
          const escapedTags = (iv.tags || '').replace(/"/g, '&quot;');
          intHtml += `<div class="interval-row" data-tags="${escapedTags}">
            ${dot}<span class="int-tags" style="cursor:pointer" title="Click to start tracking">${iv.tags}</span><span class="int-dur">${fmt(iv.duration)}</span>
            <span class="int-actions">
              <button class="act-btn int-annotate-btn" data-tags="${escapedTags}" data-dur="${fmt(iv.duration)}">※</button>
              <button class="act-btn int-journal-btn" data-tags="${escapedTags}" data-dur="${fmt(iv.duration)}">╱</button>
            </span>
          </div>
          <div class="entry-action-row hidden" id="taction-${day.replace(/[^a-zA-Z0-9]/g,'')}-${ivs.indexOf(iv)}"></div>`;
        });
      });
      ints.innerHTML = intHtml;

      // Click interval row to start tracking those tags
      ints.querySelectorAll('.interval-row').forEach(row => {
        row.addEventListener('click', async (e) => {
          // Don't trigger if clicking action buttons
          if (e.target.closest('.int-actions')) return;
          const tags = row.dataset.tags || '';
          if (!tags) return;
          await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ action: 'timew_start', args: { tags } }) });
          await loadTime();
        });
      });

      // Annotate time interval → journal entry
      ints.querySelectorAll('.int-annotate-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const row = btn.closest('.interval-row');
          const actionRow = row?.nextElementSibling;
          if (!actionRow) return;
          if (!actionRow.classList.contains('hidden')) { actionRow.classList.add('hidden'); actionRow.innerHTML = ''; return; }
          actionRow.innerHTML = `<div class="task-detail-input"><input type="text" placeholder="annotate: ${btn.dataset.tags} (${btn.dataset.dur})…" class="tann-input" /><span class="tann-jsel-slot"></span><button class="btn-inline-submit tann-btn">add</button></div>`;
          actionRow.classList.remove('hidden');
          actionRow.querySelector('.tann-jsel-slot')?.appendChild(makeJournalSelect());
          const inp = actionRow.querySelector('.tann-input');
          inp.focus();
          const submit = async () => {
            const note = inp.value.trim();
            if (!note) return;
            const entry = `[time:${btn.dataset.tags}] ${btn.dataset.dur} — ${note}`;
            const jSel = actionRow.querySelector('.journal-target-select');
            await sendJournalNote(entry, jSel);
            inp.value = ''; inp.placeholder = '✓ time annotation recorded';
            setTimeout(() => { actionRow.classList.add('hidden'); actionRow.innerHTML = ''; }, 1500);
          };
          actionRow.querySelector('.tann-btn').addEventListener('click', submit);
          inp.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
        });
      });

      // Journal note about time interval
      ints.querySelectorAll('.int-journal-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const row = btn.closest('.interval-row');
          const actionRow = row?.nextElementSibling;
          if (!actionRow) return;
          if (!actionRow.classList.contains('hidden')) { actionRow.classList.add('hidden'); actionRow.innerHTML = ''; return; }
          actionRow.innerHTML = `<div class="task-detail-input"><input type="text" placeholder="journal note: ${btn.dataset.tags}…" class="tjnl-input" /><span class="tjnl-jsel-slot"></span><button class="btn-inline-alt tjnl-btn">→ journal</button></div>`;
          actionRow.classList.remove('hidden');
          actionRow.querySelector('.tjnl-jsel-slot')?.appendChild(makeJournalSelect());
          const inp = actionRow.querySelector('.tjnl-input');
          inp.focus();
          const submit = async () => {
            const note = inp.value.trim();
            if (!note) return;
            const jSel = actionRow.querySelector('.journal-target-select');
            await sendJournalNote(note, jSel);
            inp.value = ''; inp.placeholder = '✓ note recorded in journal';
            setTimeout(() => { actionRow.classList.add('hidden'); actionRow.innerHTML = ''; }, 1500);
          };
          actionRow.querySelector('.tjnl-btn').addEventListener('click', submit);
          inp.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
        });
      });
    } catch (e) {
      renderError(today, `Time: ${e.message}`, loadTime);
    }
  }

  // Format a raw journal timestamp ("YYYY-MM-DD HH:MM") as human-readable
  function fmtJournalDate(raw) {
    try {
      const d = new Date(raw.replace(' ', 'T') + ':00');
      return d.toLocaleDateString([], {weekday:'short',month:'short',day:'numeric'}) +
             ' ' + d.toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'});
    } catch (_) { return raw; }
  }

  // Wrap @tags in body text with accent-colored span
  function highlightTags(text) {
    return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
               .replace(/@(\w+)/g, '<span class="journal-tag">@$1</span>');
  }

  // ── Journal helpers ──────────────────────────────────────────────────────

  const PAGE_SIZE = 20;

  function journalDateLabel(dateStr) {
    // dateStr: "YYYY-MM-DD HH:MM"
    const entryDate = dateStr.slice(0, 10); // "YYYY-MM-DD"
    const now = new Date();
    const todayStr = now.toISOString().slice(0, 10);
    const yestD = new Date(now); yestD.setDate(yestD.getDate() - 1);
    const yesterdayStr = yestD.toISOString().slice(0, 10);
    if (entryDate === todayStr) return 'Today';
    if (entryDate === yesterdayStr) return 'Yesterday';
    const [y, m, d] = entryDate.split('-');
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return `${months[parseInt(m,10)-1]} ${parseInt(d,10)}, ${y}`;
  }

  function journalEntryHTML(e, i) {
    const lines = e.body.split('\n').filter(Boolean);
    const preview = lines.slice(0, 3).join('\n');
    const hasMore = lines.length > 3;
    return `<div class="journal-entry" data-idx="${i}">
      <div class="entry-date">${fmtJournalDate(e.date)}</div>
      <div class="entry-body" id="jentry-${i}">${highlightTags(preview)}</div>
      ${hasMore ? `<button class="entry-more" data-idx="${i}" data-full="${encodeURIComponent(e.body)}">show more</button>` : ''}
      <div class="entry-actions">
        <button class="act-btn entry-annotate-btn" data-idx="${i}" data-date="${e.date}" data-body="${encodeURIComponent(e.body)}">+ annotate</button>
        <button class="act-btn entry-journal-btn" data-idx="${i}" data-date="${e.date}" data-body="${encodeURIComponent(e.body)}">→ journal</button>
      </div>
      <div class="entry-action-row hidden" id="jaction-${i}"></div>
    </div>`;
  }

  function wireJournalEntryEvents(list) {
    list.querySelectorAll('.entry-more').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = btn.dataset.idx;
        document.getElementById(`jentry-${idx}`).innerHTML = highlightTags(decodeURIComponent(btn.dataset.full));
        btn.remove();
      });
    });
    list.querySelectorAll('.entry-annotate-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = btn.dataset.idx;
        const row = document.getElementById(`jaction-${idx}`);
        if (!row.classList.contains('hidden')) { row.classList.add('hidden'); row.innerHTML = ''; return; }
        row.innerHTML = `<div class="task-detail-input"><input type="text" placeholder="annotate this entry…" id="jann-input-${idx}" /><span class="jann-jsel-slot"></span><button class="btn-inline-submit" id="jann-btn-${idx}">add</button></div>`;
        row.classList.remove('hidden');
        row.querySelector('.jann-jsel-slot')?.appendChild(makeJournalSelect());
        document.getElementById(`jann-input-${idx}`).focus();
        const submit = async () => {
          const note = document.getElementById(`jann-input-${idx}`).value.trim();
          if (!note) return;
          const ref = `[re: ${btn.dataset.date}] ${note}`;
          const jSel = row.querySelector('.journal-target-select');
          await sendJournalNote(ref, jSel);
          await loadJournal();
        };
        document.getElementById(`jann-btn-${idx}`).addEventListener('click', submit);
        document.getElementById(`jann-input-${idx}`).addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
      });
    });
    list.querySelectorAll('.entry-journal-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = btn.dataset.idx;
        const row = document.getElementById(`jaction-${idx}`);
        if (!row.classList.contains('hidden')) { row.classList.add('hidden'); row.innerHTML = ''; return; }
        const bodyPreview = decodeURIComponent(btn.dataset.body).split('\n')[0].slice(0, 60);
        row.innerHTML = `<div class="task-detail-input"><input type="text" placeholder="new journal note about: ${bodyPreview}…" id="jnote-input-${idx}" /><span class="jnote-jsel-slot"></span><button class="btn-inline-alt" id="jnote-btn-${idx}">→ journal</button></div>`;
        row.classList.remove('hidden');
        row.querySelector('.jnote-jsel-slot')?.appendChild(makeJournalSelect());
        document.getElementById(`jnote-input-${idx}`).focus();
        const submit = async () => {
          const note = document.getElementById(`jnote-input-${idx}`).value.trim();
          if (!note) return;
          const jSel = row.querySelector('.journal-target-select');
          await sendJournalNote(note, jSel);
          await loadJournal();
        };
        document.getElementById(`jnote-btn-${idx}`).addEventListener('click', submit);
        document.getElementById(`jnote-input-${idx}`).addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
      });
    });
  }

  function renderJournalPage(list) {
    const total = cachedJournalEntries.length;
    const visible = cachedJournalEntries.slice(0, journalPage * PAGE_SIZE);
    const totalPages = Math.ceil(total / PAGE_SIZE);

    // Group by date label
    const groups = new Map(); // label → [{entry, idx}, ...]
    visible.forEach((e, idx) => {
      const label = journalDateLabel(e.date);
      if (!groups.has(label)) groups.set(label, []);
      groups.get(label).push({ e, idx });
    });

    let html = '';
    for (const [label, items] of groups) {
      const storageKey = `ww-jgrp-${label}`;
      const collapsed = localStorage.getItem(storageKey) === '1';
      const colClass = collapsed ? ' jgrp-collapsed' : '';
      html += `<div class="journal-date-group">
        <div class="journal-date-header${colClass}" data-label="${encodeURIComponent(label)}">
          <span class="jgrp-label">${label}</span>
          <span class="jgrp-count">${items.length}</span>
        </div>
        <div class="journal-date-body${collapsed ? ' hidden' : ''}">
          ${items.map(({ e, idx }) => journalEntryHTML(e, idx)).join('')}
        </div>
      </div>`;
    }

    if (visible.length < total) {
      const remaining = total - visible.length;
      html += `<div class="journal-load-more"><button class="btn-load-more" id="btn-journal-more">load ${Math.min(PAGE_SIZE, remaining)} more <span class="load-more-count">(${remaining} remaining)</span></button></div>`;
    }

    list.innerHTML = html;

    // Wire group collapse toggles
    list.querySelectorAll('.journal-date-header').forEach(hdr => {
      hdr.addEventListener('click', () => {
        const label = decodeURIComponent(hdr.dataset.label);
        const body = hdr.nextElementSibling;
        const collapsed = hdr.classList.toggle('jgrp-collapsed');
        body.classList.toggle('hidden', collapsed);
        localStorage.setItem(`ww-jgrp-${label}`, collapsed ? '1' : '0');
      });
    });

    // Wire load-more
    document.getElementById('btn-journal-more')?.addEventListener('click', () => {
      journalPage++;
      renderJournalPage(list);
      wireJournalEntryEvents(list);
    });

    wireJournalEntryEvents(list);

    // Update context bar with page info
    const pagesLoaded = Math.min(journalPage, totalPages);
    updateContextBar('journal', { entries: cachedJournalEntries, _pages: `${pagesLoaded}/${totalPages}` });
  }

  async function loadJournal() {
    journalPage = 1;
    const list = document.getElementById('journal-list');
    try {
      const res = await fetch('/data/journal');
      const data = await res.json();
      if (!data.ok || !data.entries.length) {
        list.innerHTML = '<div class="empty-state">No journal entries</div>';
        updateContextBar('journal', { entries: [] });
        return;
      }
      cachedJournalEntries = data.entries.map((e, i) => ({ ...e, _idx: i }));
      renderJournalPage(list);
      // Client-side search
      document.getElementById('journal-search')?.addEventListener('input', (e) => {
        const q = e.target.value.toLowerCase();
        document.querySelectorAll('.journal-entry').forEach(el => {
          el.style.display = (!q || el.textContent.toLowerCase().includes(q)) ? '' : 'none';
        });
      });
    } catch (e) {
      renderError(list, `Journal: ${e.message}`, loadJournal);
    }
  }

  async function loadLedger() {
    const balDiv = document.getElementById('ledger-balances');
    const recDiv = document.getElementById('ledger-recent');
    try {
      const res = await fetch('/data/ledger');
      const data = await res.json();
      if (!data.ok) {
        balDiv.innerHTML = `<div class="empty-state">${data.error || 'Ledger unavailable'}</div>`;
        return;
      }
      updateContextBar('ledger', data);

      if (data.balances && data.balances.length) {
        balDiv.innerHTML = '<div class="ledger-header">Balances</div>' +
          data.balances.map(row => {
            const depth = (row.account.match(/:/g) || []).length;
            const indent = depth * 14;
            const cls = row.account.startsWith('assets')      ? 'bal-asset'
                      : row.account.startsWith('income')      ? 'bal-income'
                      : row.account.startsWith('expenses')    ? 'bal-expense'
                      : row.account.startsWith('liabilities') ? 'bal-liability' : '';
            return `<div class="balance-row ${cls}" style="padding-left:${indent}px">
              <span class="acct-name">${row.account}</span>
              <span class="acct-amt">${row.amount}</span>
            </div>`;
          }).join('');
      } else {
        balDiv.innerHTML = '<div class="empty-state">No balance data</div>';
      }

      if (data.recent && data.recent.length) {
        recDiv.innerHTML = '<div class="ledger-header">Recent</div>' +
          data.recent.map((row, i) => `<div class="ledger-row" data-idx="${i}">
            <span class="tx-date">${row.date}</span>
            <span class="tx-desc">${row.description}</span>
            <span class="tx-acct">${row.account}</span>
            <span class="tx-amt">${row.amount}</span>
            <span class="ledger-row-actions">
              <button class="act-btn ledger-annotate-btn" data-idx="${i}" data-desc="${(row.description || '').replace(/"/g, '&quot;')}" data-date="${row.date}" data-amt="${row.amount}">+ annotate</button>
              <button class="act-btn ledger-journal-btn" data-idx="${i}" data-desc="${(row.description || '').replace(/"/g, '&quot;')}" data-date="${row.date}" data-amt="${row.amount}">→ journal</button>
            </span>
            <div class="ledger-action-row hidden" id="laction-${i}"></div>
          </div>`).join('');

        // Annotate: add a ledger comment entry
        recDiv.querySelectorAll('.ledger-annotate-btn').forEach(btn => {
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const idx = btn.dataset.idx;
            const row = document.getElementById(`laction-${idx}`);
            if (!row.classList.contains('hidden')) { row.classList.add('hidden'); row.innerHTML = ''; return; }
            row.innerHTML = `<div class="task-detail-input"><input type="text" placeholder="annotate: ${btn.dataset.desc}…" id="lann-input-${idx}" /><button class="btn-inline-submit" id="lann-btn-${idx}">add to ledger</button></div>`;
            row.classList.remove('hidden');
            document.getElementById(`lann-input-${idx}`).focus();
            const submit = async () => {
              const note = document.getElementById(`lann-input-${idx}`).value.trim();
              if (!note) return;
              const comment = `\n; [${btn.dataset.date}] ${btn.dataset.desc}: ${note}\n`;
              await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
                body: JSON.stringify({ action: 'ledger_add', args: { date: btn.dataset.date, description: `; ${note}`, account: btn.dataset.desc, amount: '0' } }) });
              await loadLedger();
            };
            document.getElementById(`lann-btn-${idx}`).addEventListener('click', submit);
            document.getElementById(`lann-input-${idx}`).addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
          });
        });

        // Journal note about a transaction
        recDiv.querySelectorAll('.ledger-journal-btn').forEach(btn => {
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const idx = btn.dataset.idx;
            const row = document.getElementById(`laction-${idx}`);
            if (!row.classList.contains('hidden')) { row.classList.add('hidden'); row.innerHTML = ''; return; }
            row.innerHTML = `<div class="task-detail-input"><input type="text" placeholder="journal note about: ${btn.dataset.desc}…" id="ljnl-input-${idx}" /><span class="ljnl-jsel-slot"></span><button class="btn-inline-alt" id="ljnl-btn-${idx}">→ journal</button></div>`;
            row.classList.remove('hidden');
            row.querySelector('.ljnl-jsel-slot')?.appendChild(makeJournalSelect());
            document.getElementById(`ljnl-input-${idx}`).focus();
            const submit = async () => {
              const note = document.getElementById(`ljnl-input-${idx}`).value.trim();
              if (!note) return;
              const entry = `[ledger:${btn.dataset.date}] ${btn.dataset.desc} ${btn.dataset.amt} — ${note}`;
              const jSel = row.querySelector('.journal-target-select');
              await sendJournalNote(entry, jSel);
              document.getElementById(`ljnl-input-${idx}`).value = '';
              document.getElementById(`ljnl-input-${idx}`).placeholder = '✓ added to journal';
              setTimeout(() => { row.classList.add('hidden'); row.innerHTML = ''; }, 1500);
            };
            document.getElementById(`ljnl-btn-${idx}`).addEventListener('click', submit);
            document.getElementById(`ljnl-input-${idx}`).addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
          });
        });
      }

      // Ledger search
      document.getElementById('ledger-search')?.addEventListener('input', (e) => {
        const q = e.target.value.toLowerCase();
        document.querySelectorAll('.ledger-row').forEach(el => {
          el.style.display = (!q || el.textContent.toLowerCase().includes(q)) ? '' : 'none';
        });
      });
    } catch(e) {
      renderError(balDiv, `Ledger: ${e.message}`, loadLedger);
    }
  }

  // ── Error state helper ────────────────────────────────────────────────────
  // Renders an error message + retry button inside container.
  // retryFn is called on retry click (shows skeleton briefly first).
  function renderError(container, msg, retryFn) {
    if (!container) return;
    container.innerHTML = `<div class="error-state"><span class="error-msg">⚠ ${msg}</span><button class="btn-retry">retry</button></div>`;
    container.querySelector('.btn-retry')?.addEventListener('click', () => {
      container.innerHTML = '<div class="skeleton-msg">Retrying…</div>';
      setTimeout(retryFn, 300);
    });
  }

  // ── Active task header indicator ──────────────────────────────────────────
  let activeTaskIndicatorInterval = null;

  function updateActiveTaskIndicator() {
    const pill = document.getElementById('active-task-pill');
    if (!pill) return;
    const activeTask = cachedTasks.find(t => t.status === 'active');
    if (!activeTask) {
      pill.classList.add('hidden');
      pill.innerHTML = '';
      // Also un-highlight stat-tasks-count
      if (statTasksCount) statTasksCount.classList.remove('stat-active');
      return;
    }
    // Compute elapsed since task.start
    const startMs = activeTask.start
      ? Date.parse(activeTask.start.replace(/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z/, '$1-$2-$3T$4:$5:$6Z'))
      : null;
    const elapsed = startMs ? fmtDuration((Date.now() - startMs) / 1000) : '';
    const desc = activeTask.description.length > 40
      ? activeTask.description.slice(0, 38) + '…'
      : activeTask.description;
    pill.innerHTML = `<span class="atask-dot">●</span><span class="atask-desc">${desc}</span>${elapsed ? `<span class="atask-elapsed">${elapsed}</span>` : ''}`;
    pill.classList.remove('hidden');
    pill.dataset.taskId = activeTask.id;
    // Highlight count
    if (statTasksCount) statTasksCount.classList.add('stat-active');
  }

  function startActiveTaskRefresh() {
    stopActiveTaskRefresh();
    updateActiveTaskIndicator();
    activeTaskIndicatorInterval = setInterval(updateActiveTaskIndicator, 30000);
  }

  function stopActiveTaskRefresh() {
    if (activeTaskIndicatorInterval) { clearInterval(activeTaskIndicatorInterval); activeTaskIndicatorInterval = null; }
  }

  // ── Context bar + date stat ────────────────────────────────────────────────

  function updateStatDate() {
    const d = new Date();
    const days   = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    if (statDate) statDate.textContent = `${days[d.getDay()]} ${months[d.getMonth()]} ${d.getDate()}`;
  }

  function updateContextBar(section, data) {
    if (!statContextBar) return;
    const fmt = s => `${Math.floor(s/3600)}h ${Math.floor((s%3600)/60)}m`;
    if (section === 'tasks') {
      const pending = data.filter(t => t.status === 'pending').length;
      const active  = data.filter(t => t.status === 'active').length;
      statContextBar.textContent = `pending: ${pending}  ·  active: ${active}`;
    } else if (section === 'time') {
      const tracking = data.active ? `tracking: ${data.active_tags || ''}` : 'idle';
      statContextBar.textContent = `week: ${fmt(data.week_total_seconds || 0)}  ·  ${tracking}`;
    } else if (section === 'journal') {
      const count = (data.entries || []).length;
      const last  = count ? data.entries[0].date : '—';
      const pageInfo = data._pages ? `  ·  page ${data._pages}` : '';
      statContextBar.textContent = `entries: ${count}${pageInfo}  ·  last: ${last}`;
    } else if (section === 'ledger') {
      const assets = (data.balances || []).find(b => b.account.startsWith('assets'));
      statContextBar.textContent = assets ? `assets: ${assets.amount}` : 'no balance data';
    } else if (section === 'next') {
      if (data && data.description) {
        statContextBar.textContent = `recommended: ${data.description}  ·  urgency: ${(data.urgency || 0).toFixed(1)}`;
      } else {
        statContextBar.textContent = 'highest urgency pending task';
      }
    } else if (section === 'schedule') {
      statContextBar.textContent = 'auto-scheduler status';
    } else if (section === 'gun') {
      statContextBar.textContent = 'bulk task series generator · taskgun';
    } else if (section === 'cmd') {
      const ai = ctrlState.ai || {};
      const aiPart = (ai.mode !== 'off' && ai.cmd_ai && ai.provider)
        ? ` · ai: ${ai.provider}${ai.model ? '/' + ai.model : ''}`
        : (ai.mode === 'off' || !ai.cmd_ai ? ' · ai: off' : '');
      statContextBar.textContent = `unified command interface · tasks · times · journals · ledgers${aiPart}`;
    } else if (section === 'sync') {
      statContextBar.textContent = 'github sync · push · pull · status';
    } else if (section === 'groups') {
      statContextBar.textContent = 'profile groups';
    } else if (section === 'models') {
      statContextBar.textContent = 'LLM provider and model registry';
    } else if (section === 'network') {
      statContextBar.textContent = 'connectivity checks';
    } else if (section === 'export') {
      statContextBar.textContent = 'export profile data';
    } else if (section === 'questions') {
      statContextBar.textContent = 'templated question workflows';
    } else if (section === 'bookbuilder') {
      statContextBar.textContent = 'saves · knowledge base builder · peers8862';
    } else if (section === 'projects') {
      statContextBar.textContent = 'projects · tasks · journals · ledgers · times';
    } else if (section === 'ctrl') {
      statContextBar.textContent = 'global and profile settings';
    } else if (section === 'profile') {
      statContextBar.textContent = 'profile details and statistics';
    } else if (section === 'warrior') {
      statContextBar.textContent = 'global overview · all profiles';
    } else {
      statContextBar.textContent = '—';
    }
  }

  // ── Command loading for typeahead ──────────────────────────────────────────

  async function loadCommands() {
    try {
      const res = await fetch('/data/commands');
      const data = await res.json();
      wwCommands = data.commands || [];
    } catch (_) {}
  }

  // ── Terminal position toggle ───────────────────────────────────────────────

  function applyTermPosition(pos, animate) {
    const bar = document.getElementById('terminal-bar');
    if (!animate) bar.style.transition = 'none';
    if (pos === 'top') {
      bar.style.bottom = '';
      bar.style.top = '0';
      bar.style.borderTop = 'none';
      bar.style.borderBottom = '1px solid var(--border)';
      requestAnimationFrame(() => {
        const h = bar.getBoundingClientRect().height;
        document.documentElement.style.setProperty('--term-h', h + 'px');
        document.body.style.paddingTop = h + 'px';
        document.body.style.paddingBottom = '';
        if (!animate) bar.style.transition = '';
      });
      if (termPosToggle) termPosToggle.textContent = '\u2193';
    } else {
      bar.style.top = '';
      bar.style.bottom = '0';
      bar.style.borderTop = '1px solid var(--border)';
      bar.style.borderBottom = 'none';
      requestAnimationFrame(() => {
        const h = bar.getBoundingClientRect().height;
        document.documentElement.style.setProperty('--term-h', h + 'px');
        document.body.style.paddingBottom = '';
        document.body.style.paddingTop = '';
        if (!animate) bar.style.transition = '';
      });
      if (termPosToggle) termPosToggle.textContent = '\u2191';
    }
    termPosition = pos;
    localStorage.setItem('ww-term-position', pos);
  }

  function toggleTermPosition() {
    applyTermPosition(termPosition === 'bottom' ? 'top' : 'bottom', true);
  }

  // ── Density control ──────────────────────────────────────────────────────

  function initDensity() {
    const saved = localStorage.getItem('ww-density') || 'normal';
    applyDensity(saved);
    document.querySelectorAll('.density-btn').forEach(btn => {
      btn.addEventListener('click', () => applyDensity(btn.dataset.density));
    });
  }

  function applyDensity(d) {
    const gaps  = { compact: '4px',  normal: '8px',  relaxed: '14px' };
    const fonts = { compact: '12px', normal: '13px', relaxed: '14px' };
    document.documentElement.style.setProperty('--row-gap',   gaps[d]  || gaps.normal);
    document.documentElement.style.setProperty('--font-size', fonts[d] || fonts.normal);
    document.querySelectorAll('.density-btn').forEach(b =>
      b.classList.toggle('active', b.dataset.density === d));
    localStorage.setItem('ww-density', d);
  }

  // ── Service panel loaders ────────────────────────────────────────────────

  function relTime(ts) {
    if (!ts) return '—';
    const diff = Date.now() - new Date(ts).getTime();
    if (isNaN(diff) || diff < 0) return ts;
    const s = Math.floor(diff / 1000);
    if (s < 60) return `${s}s ago`;
    const m = Math.floor(s / 60);
    if (m < 60) return `${m}m ago`;
    const h = Math.floor(m / 60);
    if (h < 24) return `${h}h ago`;
    return `${Math.floor(h / 24)}d ago`;
  }

  async function loadSync() {
    const body = document.getElementById('sync-body');
    try {
      const res = await fetch('/data/sync');
      const d = await res.json();
      if (!d.ok) {
        body.innerHTML = `<div class="error-state"><span class="error-msg">⚠ ${d.error || 'Sync error'}</span></div>`;
        return;
      }
      const statusBadge = d.configured
        ? `<span class="sync-badge sync-badge-enabled">enabled</span>`
        : `<span class="sync-badge sync-badge-disabled">not configured</span>`;
      body.innerHTML = `
        <div class="sync-dashboard">
          <div class="sync-row"><span class="sync-label">status</span>${statusBadge}</div>
          <div class="sync-row"><span class="sync-label">profile</span><span class="sync-val">${d.profile}</span></div>
          ${d.repo ? `<div class="sync-row"><span class="sync-label">repo</span><span class="sync-val">${d.repo}</span></div>` : ''}
          <div class="sync-row"><span class="sync-label">last pull</span><span class="sync-val">${relTime(d.last_pull)}</span></div>
          <div class="sync-row"><span class="sync-label">last push</span><span class="sync-val">${relTime(d.last_push)}</span></div>
          <div class="sync-row"><span class="sync-label">pending push</span><span class="sync-val ${d.pending_push > 0 ? 'sync-pending' : ''}">${d.pending_push} task${d.pending_push === 1 ? '' : 's'}</span></div>
        </div>`;
    } catch (e) { renderError(body, `Sync: ${e.message}`, loadSync); }
  }

  async function loadGroups() {
    const body = document.getElementById('groups-body');
    try {
      const res = await fetch('/data/groups');
      const data = await res.json();
      if (!data.ok || !Object.keys(data.groups).length) {
        body.innerHTML = '<div class="empty-state">No groups defined. Create one above or use: ww group create &lt;name&gt; [profiles...]</div>';
        return;
      }

      body.innerHTML = Object.entries(data.groups).map(([name, profiles]) => {
        const chips = profiles.map(p =>
          `<span class="group-profile-chip">${p}<button class="group-chip-remove" data-group="${name}" data-profile="${p}" title="remove">×</button></span>`
        ).join('');
        return `<div class="group-card" data-group="${name}">
          <div class="group-card-header">
            <span class="group-name group-name-editable" data-group="${name}" title="click to rename">${name}</span>
            <div class="group-card-actions">
              <button class="act-btn group-expand-btn" data-group="${name}">▼</button>
              <button class="act-btn group-delete-btn" data-group="${name}">delete</button>
            </div>
          </div>
          <div class="group-expand-body hidden" data-for="${name}">
            <div class="group-chips-row">${chips || '<span class="muted-label">no members</span>'}</div>
            <div class="group-add-member-row">
              <input type="text" class="group-add-input" placeholder="add profile…" autocomplete="off" />
              <button class="btn-inline-submit group-add-btn" data-group="${name}">add</button>
            </div>
            <div class="group-cmd-row">
              <input type="text" class="group-cmd-input" placeholder="run ww command on group…" autocomplete="off" />
              <button class="btn-inline-submit group-run-btn" data-group="${name}">run</button>
            </div>
            <pre class="group-cmd-out hidden"></pre>
            <div class="group-members-switch">
              ${profiles.map(p => `<button class="act-btn group-switch-btn" data-profile="${p}">switch → ${p}</button>`).join('')}
            </div>
          </div>
        </div>`;
      }).join('');

      // Expand toggle
      body.querySelectorAll('.group-expand-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          const expandBody = body.querySelector(`.group-expand-body[data-for="${btn.dataset.group}"]`);
          if (!expandBody) return;
          const open = expandBody.classList.toggle('hidden');
          btn.textContent = open ? '▼' : '▲';
        });
      });

      // Delete with toast confirm
      body.querySelectorAll('.group-delete-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
          const name = btn.dataset.group;
          // Inline confirm: second click confirms
          if (btn.dataset.confirm !== '1') {
            btn.textContent = 'confirm?'; btn.dataset.confirm = '1';
            setTimeout(() => { btn.textContent = 'delete'; delete btn.dataset.confirm; }, 3000);
            return;
          }
          await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ cmd: `group delete ${name}` }) });
          toast(`group '${name}' deleted`, 'info');
          await loadGroups();
        });
      });

      // Remove profile chip
      body.querySelectorAll('.group-chip-remove').forEach(btn => {
        btn.addEventListener('click', async () => {
          const { group, profile } = btn.dataset;
          await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ cmd: `group remove ${group} ${profile}` }) });
          toast(`removed ${profile} from ${group}`, 'info');
          await loadGroups();
        });
      });

      // Add member
      body.querySelectorAll('.group-add-btn').forEach(btn => {
        const card = btn.closest('.group-card');
        btn.addEventListener('click', async () => {
          const input = card?.querySelector('.group-add-input');
          const profile = input?.value.trim();
          if (!profile) return;
          await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ cmd: `group add ${btn.dataset.group} ${profile}` }) });
          toast(`added ${profile} to ${btn.dataset.group}`);
          await loadGroups();
        });
      });

      // Run command on group
      body.querySelectorAll('.group-run-btn').forEach(btn => {
        const card = btn.closest('.group-card');
        btn.addEventListener('click', async () => {
          const input = card?.querySelector('.group-cmd-input');
          const cmd = input?.value.trim();
          if (!cmd) return;
          const out = card?.querySelector('.group-cmd-out');
          out.textContent = 'running…'; out.classList.remove('hidden');
          const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ cmd: `group run ${btn.dataset.group} ${cmd}` }) });
          const d = await r.json();
          out.textContent = d.output || d.error || 'done';
        });
      });

      // Switch to profile
      body.querySelectorAll('.group-switch-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
          await fetch('/profile', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ profile: btn.dataset.profile }) });
          toast(`switched to ${btn.dataset.profile}`);
          location.reload();
        });
      });

      // Inline rename (click on group name)
      body.querySelectorAll('.group-name-editable').forEach(nameEl => {
        nameEl.addEventListener('click', () => {
          if (nameEl.querySelector('input')) return;
          const oldName = nameEl.dataset.group;
          const inp = document.createElement('input');
          inp.type = 'text'; inp.value = oldName;
          inp.className = 'group-rename-input';
          nameEl.innerHTML = ''; nameEl.appendChild(inp); inp.focus(); inp.select();
          const commit = async () => {
            const newName = inp.value.trim();
            if (newName && newName !== oldName) {
              await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
                body: JSON.stringify({ cmd: `group rename ${oldName} ${newName}` }) });
              toast(`renamed to ${newName}`);
              await loadGroups();
            } else { nameEl.textContent = oldName; }
          };
          inp.addEventListener('blur', commit);
          inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') inp.blur(); if (e.key === 'Escape') { nameEl.textContent = oldName; } });
        });
      });

    } catch (e) { renderError(body, `Groups: ${e.message}`, loadGroups); }
  }

  async function loadModels() {
    const body = document.getElementById('models-body');
    try {
      const res = await fetch('/data/models');
      const d = await res.json();
      if (!d.ok || !d.models.length) {
        body.innerHTML = `<div class="empty-state">No models configured. Use 'ww model add' or detect ollama below.</div>`;
        return;
      }
      // Collect unique providers for filter tabs
      const providers = [...new Set(d.models.map(m => m.provider))];
      const filterTabs = providers.length > 2
        ? `<div class="model-filter-tabs">
            <button class="model-tab active" data-prov="">all</button>
            ${providers.map(p => `<button class="model-tab" data-prov="${p}">${p}</button>`).join('')}
           </div>`
        : '';
      const cards = d.models.map(m => `
        <div class="model-card ${m.active ? 'model-card-active' : ''}" data-prov="${m.provider}">
          <div class="model-card-header">
            <span class="model-prov-badge">${m.provider}</span>
            <span class="model-name">${m.name}</span>
            ${m.active ? '<span class="model-default-badge">default</span>' : ''}
          </div>
          <div class="model-card-body">
            <span class="model-id">${m.id}</span>
            ${m.notes ? `<span class="model-notes">${m.notes}</span>` : ''}
          </div>
          ${!m.active ? `<button class="btn-inline-alt model-set-default" data-name="${m.name}">set default</button>` : ''}
        </div>`).join('');
      body.innerHTML = filterTabs + `<div class="model-card-list">${cards}</div>`;
      // Provider filter
      body.querySelectorAll('.model-tab').forEach(tab => {
        tab.addEventListener('click', () => {
          body.querySelectorAll('.model-tab').forEach(t => t.classList.remove('active'));
          tab.classList.add('active');
          const prov = tab.dataset.prov;
          body.querySelectorAll('.model-card').forEach(card => {
            card.style.display = (!prov || card.dataset.prov === prov) ? '' : 'none';
          });
        });
      });
      // Set default
      body.querySelectorAll('.model-set-default').forEach(btn => {
        btn.addEventListener('click', async () => {
          btn.textContent = '…';
          btn.disabled = true;
          const r = await fetch('/cmd', { method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ cmd: `model set ${btn.dataset.name}` }) });
          const rd = await r.json();
          if (rd.ok) { toast(`default → ${btn.dataset.name}`); await loadModels(); }
          else { toast(rd.output || 'set failed', 'error'); btn.textContent = 'set default'; btn.disabled = false; }
        });
      });
    } catch (e) { renderError(body, `Models: ${e.message}`, loadModels); }
  }

  async function loadNetwork() {
    const body = document.getElementById('network-body');
    body.innerHTML = '<div class="skeleton-msg">Checking connectivity…</div>';
    try {
      const res = await fetch('/data/network');
      const data = await res.json();
      let html = '';
      (data.checks || []).forEach(c => {
        let extra = '';
        if (c.ip) extra += ` · IP: ${c.ip}`;
        if (c.models) extra += ` · ${c.models.join(', ')}`;
        html += `<div class="net-check">
          <span class="net-dot ${c.ok ? 'ok' : 'fail'}"></span>
          <span class="net-name">${c.name}</span>
          <span class="net-status">${c.ok ? '✓' : '✗'} ${c.status}${extra}</span>
        </div>`;
      });
      body.innerHTML = html || '<div class="empty-state">No checks completed</div>';
    } catch (e) { renderError(body, `Network: ${e.message}`, loadNetwork); }
  }

  async function loadQuestions() {
    const body = document.getElementById('questions-body');
    try {
      const res = await fetch('/data/questions');
      const d = await res.json();
      if (!d.ok || !d.templates.length) {
        body.innerHTML = `<div class="empty-state">No templates. Use 'ww q new' in the terminal to create one.</div>`;
        return;
      }
      body.innerHTML = d.templates.map((t, ti) => `
        <div class="q-card" id="qcard-${ti}">
          <div class="q-card-header">
            <div class="q-card-title">
              <span class="q-svc-badge">${t.service}</span>
              <span class="q-name">${t.name}</span>
            </div>
            ${t.description ? `<div class="q-desc">${t.description}</div>` : ''}
          </div>
          <button class="btn-inline-alt q-run-btn" data-ti="${ti}">run</button>
          <div class="q-form hidden" id="qform-${ti}">
            <div class="q-inputs" id="qinputs-${ti}">
              ${t.questions.map((q, qi) => `
                <div class="q-input-row">
                  <label class="q-label">${q.text}${q.required ? ' *' : ''}</label>
                  <input type="text" class="q-answer" data-qi="${qi}" placeholder="answer…" />
                </div>`).join('')}
            </div>
            <div class="q-form-actions">
              <button class="btn-inline-submit q-submit-btn" data-ti="${ti}">submit</button>
              <button class="btn-inline-alt q-cancel-btn" data-ti="${ti}">cancel</button>
            </div>
          </div>
        </div>`).join('');

      body.querySelectorAll('.q-run-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          const ti = btn.dataset.ti;
          document.getElementById(`qform-${ti}`).classList.toggle('hidden');
          const firstInput = document.querySelector(`#qinputs-${ti} .q-answer`);
          firstInput?.focus();
        });
      });
      body.querySelectorAll('.q-cancel-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          const ti = btn.dataset.ti;
          document.getElementById(`qform-${ti}`).classList.add('hidden');
          document.querySelectorAll(`#qinputs-${ti} .q-answer`).forEach(inp => { inp.value = ''; });
        });
      });
      body.querySelectorAll('.q-submit-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
          const ti = parseInt(btn.dataset.ti, 10);
          const tmpl = d.templates[ti];
          const answers = [...document.querySelectorAll(`#qinputs-${ti} .q-answer`)].map(inp => inp.value.trim());
          const date = new Date().toISOString().slice(0, 10);
          const lines = [`[q:${tmpl.file}] ${date}`];
          tmpl.questions.forEach((q, qi) => {
            lines.push(`Q: ${q.text}`);
            lines.push(`A: ${answers[qi] || '—'}`);
          });
          const entry = lines.join('\n');
          btn.textContent = '…'; btn.disabled = true;
          const r = await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'journal_add', body: entry }) });
          const rd = await r.json();
          if (rd.ok) {
            toast(`✓ ${tmpl.name} recorded`);
            document.getElementById(`qform-${ti}`).classList.add('hidden');
            document.querySelectorAll(`#qinputs-${ti} .q-answer`).forEach(inp => { inp.value = ''; });
          } else {
            toast('submit failed', 'error');
          }
          btn.textContent = 'submit'; btn.disabled = false;
        });
      });
    } catch (e) { renderError(body, `Questions: ${e.message}`, loadQuestions); }
  }

  async function loadProjects() {
    const body = document.getElementById('projects-body');
    try {
      const res = await fetch('/data/projects');
      const data = await res.json();
      const projects = data.projects || {};
      const names = Object.keys(projects);
      if (!names.length) {
        body.innerHTML = '<div class="empty-state">No projects. Create one above.</div>';
        return;
      }
      body.innerHTML = names.map(name => {
        const p = projects[name];
        return `<div class="group-card">
          <div class="group-name">${name}</div>
          <div class="group-profiles">${p.description || ''}</div>
          <div style="margin-top:4px;font-size:11px;color:var(--muted)">
            Use project:${name} in tasks · [project:${name}] in journals
          </div>
        </div>`;
      }).join('');
    } catch (e) { renderError(body, `Projects: ${e.message}`, loadProjects); }
  }

  async function loadProfileScreen() {
    const body = document.getElementById('profile-body');
    try {
      const profRes = await fetch('/data/profiles');
      const profData = await profRes.json();
      const profiles = profData.profiles || [];
      const active = profData.active || '';
      let html = `<select id="profile-detail-select" class="resource-select" style="font-size:12px;padding:4px 8px;margin-bottom:10px">`;
      profiles.forEach(p => { html += `<option value="${p}"${p === active ? ' selected' : ''}>${p}</option>`; });
      html += `</select>
        <div id="profile-detail-content"><div class="skeleton-msg">Loading…</div></div>
        <div class="profile-create-section">
          <div style="font-size:11px;color:var(--muted);margin-bottom:6px;padding-top:12px;border-top:1px solid var(--border)">create profile</div>
          <div style="display:flex;gap:6px;align-items:center">
            <input type="text" id="new-profile-name" placeholder="profile name…" class="task-input" style="max-width:160px" />
            <button class="btn-inline-submit" id="btn-create-profile">create</button>
          </div>
          <div id="create-profile-out" style="font-size:11px;margin-top:4px;color:var(--muted)"></div>
        </div>`;
      body.innerHTML = html;

      const loadDetail = async (name) => {
        const content = document.getElementById('profile-detail-content');
        try {
          const res = await fetch(`/data/profile-detail?profile=${encodeURIComponent(name)}`);
          const d = await res.json();
          if (!d.ok) { content.innerHTML = `<div class="error-state"><span class="error-msg">⚠ ${d.error}</span></div>`; return; }
          const isActive = name === active;
          const f = d.files || {};
          const shorten = p => p ? p.replace(/^\/Users\/[^/]+\//, '~/') : '—';
          const fileRow = (label, val) => `<div class="profile-file-row"><span class="profile-file-lbl">${label}</span><span class="profile-file-val">${val}</span></div>`;
          // journal rows
          let journalRows = '';
          const journals = f.journals || {};
          const jKeys = Object.keys(journals);
          if (jKeys.length === 0) {
            journalRows = fileRow('journal', '—');
          } else if (jKeys.length === 1) {
            journalRows = fileRow('journal', shorten(journals[jKeys[0]]));
          } else {
            journalRows = jKeys.map(k => fileRow(`journal · ${k}`, shorten(journals[k]))).join('');
          }
          // ledger rows
          let ledgerRows = '';
          const ledgers = f.ledgers || {};
          const lKeys = Object.keys(ledgers);
          if (lKeys.length === 0) {
            ledgerRows = fileRow('ledger', '—');
          } else if (lKeys.length === 1) {
            ledgerRows = fileRow('ledger', shorten(ledgers[lKeys[0]]));
          } else {
            ledgerRows = lKeys.map(k => fileRow(`ledger · ${k}`, shorten(ledgers[k]))).join('');
          }
          content.innerHTML = `
            <div class="profile-stat-header">
              <span class="profile-name-label">${d.name}</span>
              ${isActive ? '<span class="profile-active-badge">active</span>' : `<button class="btn-inline-alt profile-switch-btn" data-name="${d.name}">switch to</button>`}
            </div>
            <div class="profile-stat-grid">
              <div class="profile-stat"><span class="stat-val">${d.task_count}</span><span class="stat-lbl">tasks</span></div>
              <div class="profile-stat"><span class="stat-val">${d.journal_count}</span><span class="stat-lbl">journal entries</span></div>
              <div class="profile-stat"><span class="stat-val">${d.uda_count}</span><span class="stat-lbl">UDAs</span></div>
              <div class="profile-stat"><span class="stat-val">${d.created}</span><span class="stat-lbl">created</span></div>
            </div>
            <div class="profile-files-section">
              ${fileRow('taskrc', shorten(f.taskrc))}
              ${fileRow('task data', shorten(f.task_data))}
              ${fileRow('timewarrior', shorten(f.timew_db))}
              ${journalRows}
              ${ledgerRows}
            </div>
            <div class="profile-delete-row">
              ${!isActive ? `<button class="btn-inline-danger profile-delete-btn" data-name="${d.name}">delete profile</button>` : ''}
            </div>`;
          // Switch profile
          content.querySelector('.profile-switch-btn')?.addEventListener('click', async (ev) => {
            const pName = ev.target.dataset.name;
            const r = await fetch('/profile', { method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ profile: pName }) });
            const rd = await r.json();
            if (rd.ok) { toast(`switched to ${pName}`); location.reload(); }
            else { toast(rd.error || 'switch failed', 'error'); }
          });
          // Delete with inline confirmation
          content.querySelector('.profile-delete-btn')?.addEventListener('click', (ev) => {
            const pName = ev.target.dataset.name;
            ev.target.outerHTML = `<span style="font-size:12px;color:var(--error)">delete ${pName}? </span><button class="btn-inline-danger profile-delete-confirm" data-name="${pName}">yes, delete</button><button class="btn-inline-alt profile-delete-cancel">cancel</button>`;
            content.querySelector('.profile-delete-cancel')?.addEventListener('click', () => loadDetail(name));
            content.querySelector('.profile-delete-confirm')?.addEventListener('click', async (ev2) => {
              const r = await fetch('/cmd', { method: 'POST', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ cmd: `profile remove ${pName} --yes` }) });
              const rd = await r.json();
              if (rd.ok) { toast(`deleted ${pName}`); await loadProfileScreen(); }
              else { toast(rd.output || 'delete failed', 'error'); }
            });
          });
        } catch (e) { renderError(content, `Profile: ${e.message}`, () => loadDetail(name)); }
      };

      document.getElementById('profile-detail-select')?.addEventListener('change', (e) => loadDetail(e.target.value));
      // Create profile
      document.getElementById('btn-create-profile')?.addEventListener('click', async () => {
        const nameInput = document.getElementById('new-profile-name');
        const pName = nameInput.value.trim();
        const out = document.getElementById('create-profile-out');
        if (!pName) { out.textContent = 'name required'; return; }
        out.textContent = 'creating…';
        const r = await fetch('/cmd', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ cmd: `profile create ${pName}` }) });
        const rd = await r.json();
        if (rd.ok) { toast(`created ${pName}`); nameInput.value = ''; out.textContent = ''; await loadProfileScreen(); }
        else { out.textContent = rd.output || 'create failed'; }
      });
      document.getElementById('new-profile-name')?.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); document.getElementById('btn-create-profile')?.click(); } });

      await loadDetail(active || profiles[0] || '');
    } catch (e) { renderError(body, `Profile screen: ${e.message}`, loadProfileScreen); }
  }

  async function loadWarrior() {
    const body = document.getElementById('warrior-body');
    try {
      const res = await fetch('/data/warrior');
      const d = await res.json();
      if (!d.ok) { renderError(body, 'Warrior data failed', loadWarrior); return; }
      const profiles = d.profiles || [];
      const active = d.active_profile || '';

      // Aggregate header
      let html = `<div class="warrior-agg-row">
        <div class="warrior-agg-stat"><span class="stat-val">${profiles.length}</span><span class="stat-lbl">profiles</span></div>
        <div class="warrior-agg-stat"><span class="stat-val">${d.total_tasks}</span><span class="stat-lbl">total tasks</span></div>
        <div class="warrior-agg-stat"><span class="stat-val" style="color:var(--success)">${d.total_active}</span><span class="stat-lbl">active</span></div>
      </div>`;

      // Per-profile cards
      html += '<div class="warrior-profile-list">';
      for (const p of profiles) {
        const urgHigh = Math.min(p.task_count, Math.ceil(p.task_count * 0.3));
        const urgMed  = Math.min(p.task_count - urgHigh, Math.ceil(p.task_count * 0.4));
        const urgLow  = p.task_count - urgHigh - urgMed;
        const barTotal = p.task_count || 1;
        const activeDot = p.active_count > 0 ? '<span class="warrior-active-dot"></span>' : '';
        html += `<div class="warrior-profile-card ${p.is_active ? 'warrior-card-active' : ''}">
          <div class="warrior-card-header">
            <span class="warrior-prof-name">${p.name}</span>
            ${activeDot}
            ${p.is_active ? '<span class="warrior-current-badge">active</span>' : ''}
            <span class="warrior-task-count">${p.task_count} tasks</span>
          </div>
          ${p.top_task ? `<div class="warrior-top-task">${p.top_task}</div>` : ''}
          ${p.task_count > 0 ? `<div class="warrior-urg-bar" title="${p.task_count} tasks">
            <div class="urg-seg urg-high" style="width:${(urgHigh/barTotal*100).toFixed(1)}%"></div>
            <div class="urg-seg urg-med"  style="width:${(urgMed/barTotal*100).toFixed(1)}%"></div>
            <div class="urg-seg urg-low"  style="width:${(urgLow/barTotal*100).toFixed(1)}%"></div>
          </div>` : ''}
        </div>`;
      }
      html += '</div>';

      // Global settings
      html += `<div style="margin-top:12px;padding-top:8px;border-top:1px solid var(--border)">
        <div style="font-size:11px;color:var(--muted);margin-bottom:6px">global settings</div>
        <div style="display:flex;gap:6px;flex-wrap:wrap">
          <button class="btn-inline-alt" id="btn-w-version">version</button>
          <button class="btn-inline-alt" id="btn-w-deps">deps</button>
          <button class="btn-inline-alt" id="btn-w-shortcuts">shortcuts</button>
        </div>
        <div class="cmd-unified-output hidden" id="warrior-output"></div>
      </div>`;

      body.innerHTML = html;

      const wOut = document.getElementById('warrior-output');
      const wCmd = async (cmd) => {
        wOut.className = 'cmd-unified-output'; wOut.textContent = 'loading…';
        const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ cmd }) });
        const rd = await r.json(); wOut.textContent = rd.output || 'done';
      };
      document.getElementById('btn-w-version')?.addEventListener('click', () => wCmd('version'));
      document.getElementById('btn-w-deps')?.addEventListener('click', () => wCmd('deps check'));
      document.getElementById('btn-w-shortcuts')?.addEventListener('click', () => wCmd('shortcut list'));
    } catch (e) { renderError(body, `Warrior: ${e.message}`, loadWarrior); }
  }

  // ── Add forms ──────────────────────────────────────────────────────────────

  // Helper: date string N days from now (YYYY-MM-DD)
  function futureDateStr(days) {
    const d = new Date();
    d.setDate(d.getDate() + days);
    return d.toISOString().slice(0, 10);
  }
  function todayStr() { return new Date().toISOString().slice(0, 10); }

  // Ledger account autocomplete cache
  let knownAccounts = [];
  async function loadAccounts() {
    try {
      const res = await fetch('/data/accounts');
      const data = await res.json();
      knownAccounts = data.accounts || [];
      const dl = document.getElementById('account-list');
      if (dl) {
        dl.innerHTML = '';
        knownAccounts.forEach(a => {
          const opt = document.createElement('option');
          opt.value = a;
          dl.appendChild(opt);
        });
      }
    } catch (_) {}
  }

  async function loadTimewTags() {
    try {
      const res = await fetch('/data/timew-tags');
      const data = await res.json();
      const dl = document.getElementById('timew-tags-list');
      if (dl) {
        dl.innerHTML = '';
        (data.tags || []).forEach(t => {
          const opt = document.createElement('option');
          opt.value = t;
          dl.appendChild(opt);
        });
      }
    } catch (_) {}
  }

  // Build a <select> for choosing which journal to write to
  function makeJournalSelect(className) {
    const sel = document.createElement('select');
    sel.className = className || 'journal-target-select';
    sel.innerHTML = '<option value="">active</option>';
    if (profileResources && profileResources.resources && profileResources.resources.journals) {
      Object.keys(profileResources.resources.journals).forEach(name => {
        const opt = document.createElement('option');
        opt.value = name;
        opt.textContent = name;
        sel.appendChild(opt);
      });
    }
    return sel;
  }

  // Send a journal_add with optional journal target
  async function sendJournalNote(entry, journalSelect) {
    const journal = journalSelect ? journalSelect.value : '';
    const args = { entry };
    if (journal) args.journal = journal;
    return fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ action: 'journal_add', args }) });
  }

  function initAddForms() {
    // ── Tasks ──────────────────────────────────────────────────────────────
    const taskForm = document.getElementById('add-task-form');
    const taskDueInput = taskForm?.querySelector('input[name="due"]');
    // Default due = 2 days from now
    if (taskDueInput && !taskDueInput.value) taskDueInput.value = futureDateStr(2);

    async function submitTask(andStart) {
      const fd = new FormData(taskForm);
      const desc = fd.get('description')?.trim();
      if (!desc) return;
      const tags = fd.get('tags') ? fd.get('tags').split(',').map(t => t.trim()).filter(Boolean) : [];
      const res = await fetch('/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'add', args: {
          description: desc,
          project:   fd.get('project')   || undefined,
          priority:  fd.get('priority')  || undefined,
          due:       fd.get('due')       || undefined,
          scheduled: fd.get('scheduled') || undefined,
          wait:      fd.get('wait')      || undefined,
          tags,
        }}),
      });
      const data = await res.json();
      if (data.ok) {
        renderTasks(data.tasks || []);
        toast(andStart ? '▶ task added + started' : '✓ task added');
        // If "start", start the newly created task (last in list by ID)
        if (andStart && data.tasks?.length) {
          const newest = data.tasks.reduce((a, b) => (b.id > a.id ? b : a), data.tasks[0]);
          const r2 = await fetch('/action', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'start', id: newest.id }),
          });
          const d2 = await r2.json();
          if (d2.ok) renderTasks(d2.tasks || []);
        }
        taskForm.reset();
        if (taskDueInput) taskDueInput.value = futureDateStr(2);
      } else { toast('add failed', 'error'); }
    }

    taskForm?.addEventListener('submit', async (e) => {
      e.preventDefault();
      await submitTask(false);
    });
    document.getElementById('btn-task-start')?.addEventListener('click', () => submitTask(true));

    // ── Time ───────────────────────────────────────────────────────────────
    // Helper: get tags and log description to journal if provided
    async function timeFormAction(actionName, extraArgs) {
      const form = document.getElementById('add-time-form');
      const rawTags = form?.querySelector('input[name="tags"]')?.value?.trim() || '';
      const tags = rawTags.toLowerCase().replace(/\s+/g, ' ');
      const desc = form?.querySelector('input[name="description"]')?.value?.trim() || '';
      const taskSel = document.getElementById('time-task-select');
      const taskDesc = taskSel?.selectedOptions[0]?.textContent;
      const fullTags = (taskDesc && taskSel.value) ? (tags + ' ' + taskDesc).trim() : tags;
      const args = { tags: fullTags, ...(extraArgs || {}) };
      await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ action: actionName, args }) });
      // Log description to journal if provided
      if (desc && fullTags) {
        const entry = `[time:${fullTags}] ${desc}`;
        await sendJournalNote(entry, null);
      }
      return { tags: fullTags, desc };
    }

    document.getElementById('btn-timew-start')?.addEventListener('click', async () => {
      const { tags } = await timeFormAction('timew_start');
      toast(`▶ tracking${tags ? ': ' + tags : ''}`);
      await loadTime();
    });

    document.getElementById('btn-timew-stop')?.addEventListener('click', async () => {
      await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ action: 'timew_stop' }) });
      toast('■ tracking stopped', 'info');
      await loadTime();
    });

    document.getElementById('add-time-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const form = e.target;
      const duration = form.querySelector('input[name="duration"]')?.value || '';
      if (!duration) return;
      await timeFormAction('timew_track', { duration });
      toast('✓ time logged');
      await loadTime();
      form.querySelector('input[name="tags"]').value = '';
      form.querySelector('input[name="description"]').value = '';
      form.querySelector('input[name="duration"]').value = '';
    });

    // ── Journal ────────────────────────────────────────────────────────────
    const journalTextarea = document.querySelector('#add-journal-form textarea');
    if (journalTextarea) {
      journalTextarea.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          document.getElementById('add-journal-form')?.requestSubmit();
        }
      });
    }
    document.getElementById('add-journal-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const entry = fd.get('entry')?.trim();
      if (!entry) return;
      const res = await fetch('/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'journal_add', args: { entry } }),
      });
      const data = await res.json();
      if (data.ok) {
        toast('✓ journal entry added');
        await loadJournal();
        e.target.reset();
      } else { toast('journal failed', 'error'); }
    });

    // ── Ledger ─────────────────────────────────────────────────────────────
    const ledgerDateInput = document.querySelector('#add-ledger-form input[name="date"]');
    if (ledgerDateInput && !ledgerDateInput.value) ledgerDateInput.value = todayStr();

    document.getElementById('add-ledger-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const res = await fetch('/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'ledger_add', args: {
          date:        fd.get('date')        || todayStr(),
          description: fd.get('description'),
          account:     fd.get('account')     || 'expenses:misc',
          amount:      fd.get('amount')      || '0',
        }}),
      });
      const data = await res.json();
      if (data.ok) {
        await loadLedger();
        e.target.reset();
        if (ledgerDateInput) ledgerDateInput.value = todayStr();
        await loadAccounts(); // refresh autocomplete after new transaction
      }
    });

    // ── Hledger reports ────────────────────────────────────────────────────
    async function runHledger(cmd, extraArgs) {
      const out = document.getElementById('hledger-output');
      out.className = 'hledger-output';
      out.innerHTML = '<span class="hl-cmd">running…</span>';
      const period = document.getElementById('hl-period')?.value || '';
      const filter = document.getElementById('hl-filter')?.value?.trim() || '';
      const depth = document.getElementById('hl-depth')?.value || '';
      const args = [...(extraArgs || [])];
      if (period) args.push(period);
      if (depth) args.push(depth);
      if (filter) args.push(filter);
      try {
        const res = await fetch('/hledger', { method:'POST', headers:{'Content-Type':'application/json'},
          body: JSON.stringify({ cmd, args }) });
        const data = await res.json();
        out.innerHTML = `<span class="hl-cmd">${data.cmd || cmd}</span>\n${data.output || data.error || 'no output'}`;
      } catch (e) {
        out.innerHTML = `<span class="hl-cmd">${cmd}</span>\nerror: ${e.message}`;
      }
    }
    document.querySelectorAll('.hl-btn').forEach(btn => {
      btn.addEventListener('click', () => runHledger(btn.dataset.cmd));
    });

    // ── Gun ────────────────────────────────────────────────────────────────
    document.getElementById('gun-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const project = fd.get('project')?.trim();
      const parts = fd.get('parts')?.trim();
      const unit = fd.get('unit')?.trim();
      const offset = fd.get('offset')?.trim();
      const interval = fd.get('interval')?.trim();
      const skip = fd.get('skip')?.trim();
      if (!project || !parts || !unit) {
        showGunOutput('project, parts, and unit are required', true);
        return;
      }
      let cmd = `gun create ${project} -p ${parts} -u ${unit}`;
      if (offset) cmd += ` --offset ${offset}`;
      if (interval) cmd += ` --interval ${interval}`;
      if (skip) cmd += ` --skip ${skip}`;
      showGunOutput('creating series…', false);
      try {
        const res = await fetch('/cmd', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ cmd }),
        });
        const data = await res.json();
        showGunOutput(data.output || data.error || 'done', !data.ok);
        if (data.ok) {
          e.target.reset();
          // Refresh tasks if we're on that tab
          if (activeSection === 'tasks') await loadTasks();
        }
      } catch (err) {
        showGunOutput('error: ' + err.message, true);
      }
    });

    // ── Sword task search ──────────────────────────────────────────────────
    const swordSearchInput = document.getElementById('sword-task-search');
    const swordSearchResults = document.getElementById('sword-search-results');
    if (swordSearchInput && swordSearchResults) {
      swordSearchInput.addEventListener('input', async () => {
        const q = swordSearchInput.value.trim().toLowerCase();
        if (!q) { swordSearchResults.innerHTML = ''; return; }
        // Ensure we have tasks cached
        let tasks = cachedTasks;
        if (!tasks.length) {
          const res = await fetch('/data/tasks');
          const d = await res.json();
          cachedTasks = d.tasks || [];
          tasks = cachedTasks;
        }
        const hits = tasks.filter(t =>
          (t.description || '').toLowerCase().includes(q) ||
          (t.project || '').toLowerCase().includes(q) ||
          String(t.id).startsWith(q)
        ).slice(0, 8);
        if (!hits.length) { swordSearchResults.innerHTML = '<div class="sword-no-results">no tasks found</div>'; return; }
        swordSearchResults.innerHTML = hits.map(t =>
          `<div class="sword-result-row" data-id="${t.id}">
            <span class="sword-res-id">${t.id}</span>
            <span class="sword-res-desc">${t.description}</span>
            ${t.project ? `<span class="sword-res-proj">${t.project}</span>` : ''}
            <span class="sword-res-urg">${(t.urgency || 0).toFixed(1)}</span>
          </div>`
        ).join('');
        swordSearchResults.querySelectorAll('.sword-result-row').forEach(row => {
          row.addEventListener('click', () => {
            document.getElementById('sword-task-id').value = row.dataset.id;
            swordSearchResults.innerHTML = '';
            swordSearchInput.value = '';
          });
        });
      });
    }

    // ── Sword ──────────────────────────────────────────────────────────────
    document.getElementById('sword-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const taskId = fd.get('task_id')?.trim();
      const parts = fd.get('parts')?.trim();
      const interval = fd.get('interval')?.trim() || '1d';
      const prefix = fd.get('prefix')?.trim() || 'Part';
      if (!taskId || !parts) {
        const out = document.getElementById('sword-output');
        out.className = 'gun-output error'; out.textContent = 'task ID and parts required';
        return;
      }
      const out = document.getElementById('sword-output');
      out.className = 'gun-output'; out.textContent = 'splitting…';
      try {
        const cmd = `sword ${taskId} -p ${parts} --interval ${interval} --prefix ${prefix}`;
        const res = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
          body: JSON.stringify({ cmd }) });
        const data = await res.json();
        out.textContent = data.output || data.error || 'done';
        if (!data.ok) out.className = 'gun-output error';
        if (data.ok) { e.target.reset(); if (activeSection === 'tasks') await loadTasks(); }
      } catch (err) { out.textContent = 'error: ' + err.message; out.className = 'gun-output error'; }
    });

    // ── Sync buttons ───────────────────────────────────────────────────────
    const syncOut = () => document.getElementById('sync-output');
    const syncCmd = async (cmd) => {
      const out = syncOut();
      out.className = 'cmd-unified-output'; out.textContent = 'running…';
      try {
        const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ cmd }) });
        const d = await r.json(); out.textContent = d.output || d.error || 'done';
        if (!d.ok) out.className = 'cmd-unified-output error';
      } catch (e) { out.textContent = 'error: ' + e.message; out.className = 'cmd-unified-output error'; }
    };
    document.getElementById('btn-sync-status')?.addEventListener('click', () => syncCmd('issues status'));
    document.getElementById('btn-sync-pull')?.addEventListener('click', () => syncCmd('issues pull'));
    document.getElementById('btn-sync-push')?.addEventListener('click', () => syncCmd('issues push'));
    document.getElementById('btn-sync-install')?.addEventListener('click', () => syncCmd('issues install'));

    // ── Schedule buttons ───────────────────────────────────────────────────
    const schedOut = () => document.getElementById('schedule-output');
    const schedCmd = async (cmd) => {
      const out = schedOut();
      out.className = 'cmd-unified-output'; out.textContent = 'running…';
      try {
        const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ cmd }) });
        const d = await r.json(); out.textContent = d.output || d.error || 'done';
        if (!d.ok) out.className = 'cmd-unified-output error';
      } catch (e) { out.textContent = 'error: ' + e.message; out.className = 'cmd-unified-output error'; }
    };
    document.getElementById('btn-sched-status')?.addEventListener('click', () => schedCmd('schedule status'));
    document.getElementById('btn-sched-enable')?.addEventListener('click', () => schedCmd('schedule enable'));
    document.getElementById('btn-sched-disable')?.addEventListener('click', () => schedCmd('schedule disable'));
    document.getElementById('btn-sched-run')?.addEventListener('click', () => schedCmd('schedule run'));
    document.getElementById('btn-sched-dryrun')?.addEventListener('click', () => schedCmd('schedule run --dry-run'));
    document.getElementById('btn-sched-install')?.addEventListener('click', () => schedCmd('schedule install'));

    // Weapon buttons
    document.getElementById('btn-weapon-gun')?.addEventListener('click', () => switchSection('gun'));
    document.getElementById('btn-weapon-sword')?.addEventListener('click', () => switchSection('sword'));
    // CMD/CTRL buttons
    document.getElementById('btn-nav-cmd')?.addEventListener('click', () => switchSection('cmd'));
    document.getElementById('btn-nav-ctrl')?.addEventListener('click', () => switchSection('ctrl'));
    // Profile screen
    document.getElementById('btn-profile-screen')?.addEventListener('click', () => switchSection('profile'));
    document.getElementById('warrior-stats')?.addEventListener('click', () => switchSection('warrior'));
    // CTRL panel buttons
    document.getElementById('btn-ctrl-deps')?.addEventListener('click', async () => {
      const out = document.getElementById('ctrl-output');
      out.className = 'cmd-unified-output'; out.textContent = 'checking…';
      const res = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ cmd: 'deps check' }) });
      const data = await res.json(); out.textContent = data.output || 'done';
    });
    document.getElementById('btn-ctrl-shortcuts')?.addEventListener('click', async () => {
      const out = document.getElementById('ctrl-output');
      out.className = 'cmd-unified-output'; out.textContent = 'loading…';
      const res = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ cmd: 'shortcut list' }) });
      const data = await res.json(); out.textContent = data.output || 'done';
    });
    document.getElementById('btn-ctrl-version')?.addEventListener('click', async () => {
      const out = document.getElementById('ctrl-output');
      out.className = 'cmd-unified-output'; out.textContent = 'loading…';
      const res = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ cmd: 'version' }) });
      const data = await res.json(); out.textContent = data.output || 'done';
    });
    // AI / command-line toggles (persisted via ww ctrl)
    const aiModeSelect = document.getElementById('ctrl-ai-mode');
    const aiStatus = document.getElementById('ctrl-ai-status');
    if (aiModeSelect) {
      aiModeSelect.addEventListener('change', async () => {
        try {
          await fetch('/cmd', {
            method: 'POST',
            headers: {'Content-Type':'application/json'},
            body: JSON.stringify({ cmd: `ctrl ai-mode ${aiModeSelect.value}` }),
          });
          await refreshCtrlState();
        } catch (_) {
          if (aiStatus) aiStatus.textContent = 'failed to update mode';
        }
      });
    }
    const clWw = document.getElementById('ctrl-cl-ww');
    clWw?.addEventListener('change', async () => {
      await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ cmd: `ctrl prompt-ww ${clWw.checked ? 'on' : 'off'}` }) });
      await refreshCtrlState();
    });
    const clAi = document.getElementById('ctrl-cl-ai');
    clAi?.addEventListener('change', async () => {
      await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ cmd: `ctrl prompt-ai ${clAi.checked ? 'on' : 'off'}` }) });
      await refreshCtrlState();
    });
    const uiModel = document.getElementById('ctrl-ui-model');
    uiModel?.addEventListener('change', async () => {
      await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ cmd: `ctrl ui-model-indicator ${uiModel.checked ? 'on' : 'off'}` }) });
      await refreshCtrlState();
    });
    // Export buttons
    document.getElementById('btn-export-json')?.addEventListener('click', async () => {
      const out = document.getElementById('export-output');
      out.className = 'cmd-unified-output'; out.textContent = 'exporting…';
      const res = await fetch('/data/all'); const data = await res.json();
      out.textContent = JSON.stringify(data, null, 2);
    });
    document.getElementById('btn-export-run')?.addEventListener('click', async () => {
      const out = document.getElementById('export-output');
      out.className = 'cmd-unified-output'; out.textContent = 'running…';
      const res = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ cmd: 'export json' }) });
      const data = await res.json(); out.textContent = data.output || 'done';
    });
    // BookBuilder / Saves buttons
    const bbOut = () => document.getElementById('bb-output');
    const bbCmd = async (cmd) => {
      const out = bbOut();
      out.className = 'cmd-unified-output'; out.textContent = 'running…';
      try {
        const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
          body: JSON.stringify({ cmd }) });
        const d = await r.json();
        out.textContent = d.output || d.error || 'done';
        if (!d.ok) out.className = 'cmd-unified-output error';
      } catch (e) { out.textContent = 'error: ' + e.message; out.className = 'cmd-unified-output error'; }
    };
    document.getElementById('btn-bb-status')?.addEventListener('click', async () => {
      const out = bbOut(); out.className = 'cmd-unified-output'; out.textContent = 'checking…';
      try {
        const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
          body: JSON.stringify({ cmd: 'find bookbuilder' }) });
        const d = await r.json();
        const installed = d.ok && d.output && !d.output.includes('not found') && !d.output.includes('No such');
        if (installed) {
          const r2 = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ cmd: 'bookbuilder status' }) });
          const d2 = await r2.json();
          out.textContent = d2.output || 'bookbuilder status returned empty';
        } else {
          out.textContent = 'bookbuilder not installed — running in journal mode\n\nInstall: pip install peers8862-bookbuilder\n        or: pipx install peers8862-bookbuilder';
        }
      } catch (e) { out.textContent = 'error: ' + e.message; }
    });
    document.getElementById('btn-bb-search')?.addEventListener('click', () => {
      const body = document.getElementById('bookbuilder-body');
      const existing = body?.querySelector('.bb-search-row');
      if (existing) { existing.remove(); return; }
      const row = document.createElement('div');
      row.className = 'bb-search-row task-detail-input';
      row.style.cssText = 'margin-top:8px';
      const inp = document.createElement('input');
      inp.type = 'text'; inp.placeholder = 'search knowledge base…';
      inp.className = 'inline-filter'; inp.style.flex = '1';
      const btn2 = document.createElement('button');
      btn2.textContent = 'go'; btn2.className = 'btn-inline-submit';
      const doSearch = async () => {
        const t = inp.value.trim();
        if (!t) return;
        const out = bbOut(); out.className = 'cmd-unified-output'; out.textContent = 'searching…';
        const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
          body: JSON.stringify({ cmd: `bookbuilder search ${t}` }) });
        const d = await r.json();
        if (d.ok && d.output && !d.output.includes('not found')) {
          out.textContent = d.output;
        } else {
          // Fallback: search journal for [saved] entries matching term
          const ql = t.toLowerCase();
          const hits = cachedJournalEntries.filter(e => (e.body || '').toLowerCase().includes(ql) && (e.body || '').includes('[saved]'));
          out.textContent = hits.length
            ? 'journal saves matching "' + t + '":\n' + hits.map(e => '  ' + e.body.split('\n')[0]).join('\n')
            : 'no results (bookbuilder not installed; searched journal saves)';
        }
        row.remove();
      };
      btn2.addEventListener('click', doSearch);
      inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); doSearch(); } if (e.key === 'Escape') row.remove(); });
      row.appendChild(inp); row.appendChild(btn2);
      body?.insertBefore(row, body.querySelector('div[style]') || body.firstChild);
      inp.focus();
    });
    document.getElementById('btn-bb-inbox')?.addEventListener('click', () => bbCmd('bookbuilder inbox'));
    document.getElementById('btn-bb-run')?.addEventListener('click', () => bbCmd('bookbuilder run'));
    document.getElementById('bb-add-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const url = e.target.querySelector('input[name="url"]')?.value?.trim();
      if (!url) return;
      const out = bbOut();
      out.className = 'cmd-unified-output'; out.textContent = `saving: ${url}…`;
      // Try bookbuilder add first
      const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ cmd: `bookbuilder add ${url}` }) });
      const d = await r.json();
      if (d.ok && d.output && !d.output.includes('not found')) {
        out.textContent = `✓ added to bookbuilder: ${url}\n${d.output}`;
        toast('✓ saved to bookbuilder');
      } else {
        // Fallback: journal
        await sendJournalNote(`[saved] ${url}`, null);
        out.textContent = `✓ saved to journal (bookbuilder not installed): ${url}\n\nInstall: pipx install peers8862-bookbuilder`;
        toast('✓ saved to journal');
      }
      e.target.reset();
    });

    // Groups management
    document.getElementById('group-create-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const name = fd.get('name')?.trim();
      const profiles = fd.get('profiles')?.trim();
      if (!name) return;
      const cmd = profiles ? `group create ${name} ${profiles.split(',').map(s => s.trim()).join(' ')}` : `group create ${name}`;
      await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ cmd }) });
      e.target.reset();
      await loadGroups();
    });

    // Projects management
    document.getElementById('project-create-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const name = fd.get('name')?.trim();
      const description = fd.get('description')?.trim();
      if (!name) return;
      const res = await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ action: 'project_create', args: { name, description: description || '' } }) });
      const data = await res.json();
      if (data.ok) {
        e.target.reset();
        await loadProjects();
      }
    });

    // Models buttons
    const modelsOut = () => document.getElementById('models-body');
    const modelsCmd = async (cmd) => {
      const out = modelsOut();
      out.innerHTML = '<div class="skeleton-msg">Loading…</div>';
      const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ cmd }) });
      const d = await r.json();
      out.innerHTML = `<pre class="service-output">${d.output || d.error || 'done'}</pre>`;
    };
    document.getElementById('btn-model-list')?.addEventListener('click', () => modelsCmd('model list'));
    document.getElementById('btn-model-providers')?.addEventListener('click', () => modelsCmd('model providers'));
    document.getElementById('btn-model-env')?.addEventListener('click', () => modelsCmd('model env'));
    document.getElementById('btn-model-check')?.addEventListener('click', () => modelsCmd('model check'));
    document.getElementById('btn-model-detect')?.addEventListener('click', async () => {
      const out = modelsOut();
      out.innerHTML = '<div class="skeleton-msg">Detecting ollama models…</div>';
      try {
        const res = await fetch('/data/network');
        const data = await res.json();
        const ollama = (data.checks || []).find(c => c.name === 'ollama');
        if (!ollama?.ok) {
          out.innerHTML = '<pre class="service-output">ollama not running.\n\nStart with: ollama serve\nInstall: brew install ollama</pre>';
          return;
        }
        // Register each detected model
        let html = '<pre class="service-output">Detected ollama models:\n';
        for (const model of (ollama.models || [])) {
          const name = model.replace(/[:.]/g, '-').replace(/-+/g, '-');
          await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ cmd: `model add-model ${name} ollama ${model} "auto-detected"` }) });
          html += `  ✓ ${model} → registered as ${name}\n`;
        }
        // Set first as default if none set
        const listRes = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
          body: JSON.stringify({ cmd: 'model list' }) });
        const listData = await listRes.json();
        html += '\n' + (listData.output || '') + '</pre>';
        out.innerHTML = html;
      } catch (e) {
        out.innerHTML = `<pre class="service-output">Error: ${e.message}</pre>`;
      }
    });

    // Questions buttons
    const qOut = () => document.getElementById('questions-output');
    const qCmd = async (cmd) => {
      const out = qOut();
      out.className = 'cmd-unified-output'; out.textContent = 'running…';
      const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ cmd }) });
      const d = await r.json();
      out.textContent = d.output || d.error || 'done';
    };
    document.getElementById('btn-q-list')?.addEventListener('click', () => qCmd('q list'));

    // Questions template creator (form-based, not interactive CLI)
    document.getElementById('q-create-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const service = fd.get('service');
      const name = fd.get('name')?.trim();
      const desc = fd.get('description')?.trim();
      if (!name) return;
      const out = qOut();

      // Collect questions from the builder
      const qInputs = document.querySelectorAll('#q-questions-builder input');
      const questions = [...qInputs].map(i => i.value.trim()).filter(Boolean);

      if (questions.length === 0) {
        // Show question builder
        const builder = document.getElementById('q-questions-builder');
        builder.innerHTML = `
          <div style="font-size:11px;color:var(--muted);margin-bottom:4px">add questions (one per field, leave empty to finish):</div>
          <div id="q-fields">
            <input type="text" class="inline-filter q-field" placeholder="Question 1" style="width:100%;margin-bottom:4px" />
            <input type="text" class="inline-filter q-field" placeholder="Question 2" style="width:100%;margin-bottom:4px" />
            <input type="text" class="inline-filter q-field" placeholder="Question 3" style="width:100%;margin-bottom:4px" />
          </div>
          <button type="button" class="btn-inline-alt" id="btn-q-add-field" style="margin-top:4px">+ question</button>
          <button type="button" class="btn-inline-submit" id="btn-q-save" style="margin-top:4px;margin-left:4px">save template</button>
        `;
        document.getElementById('btn-q-add-field')?.addEventListener('click', () => {
          const fields = document.getElementById('q-fields');
          const n = fields.querySelectorAll('input').length + 1;
          const inp = document.createElement('input');
          inp.type = 'text'; inp.className = 'inline-filter q-field';
          inp.placeholder = `Question ${n}`; inp.style.cssText = 'width:100%;margin-bottom:4px';
          fields.appendChild(inp);
        });
        document.getElementById('btn-q-save')?.addEventListener('click', async () => {
          const qs = [...document.querySelectorAll('#q-questions-builder .q-field')].map(i => i.value.trim()).filter(Boolean);
          if (qs.length === 0) { out.className = 'cmd-unified-output'; out.textContent = 'at least one question required'; return; }
          // Create template via action
          const res = await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ action: 'q_create_template', args: { service, name, description: desc || '', questions: qs } }) });
          const data = await res.json();
          out.className = 'cmd-unified-output';
          out.textContent = data.ok ? `✓ template '${name}' created for ${service}` : (data.error || 'failed');
          if (data.ok) {
            e.target.reset();
            document.getElementById('q-questions-builder').innerHTML = '';
            await loadQuestions();
          }
        });
        return;
      }
    });
    // Add account for ledgers
    document.getElementById('btn-add-account')?.addEventListener('click', async () => {
      const inp = document.getElementById('add-account-input');
      const account = inp?.value.trim();
      if (!account) return;
      const res = await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ action:'ledger_add_account', args:{ account } }) });
      const data = await res.json();
      if (data.ok) {
        inp.value = '';
        inp.placeholder = '✓ ' + account + ' declared';
        await loadAccounts();
        await loadLedger();
        setTimeout(() => { if (inp) inp.placeholder = 'add account (e.g. expenses:travel:flights)'; }, 2000);
      }
    });
    document.getElementById('add-account-input')?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') { e.preventDefault(); document.getElementById('btn-add-account')?.click(); }
    });

    // ── CMD ────────────────────────────────────────────────────────────────
    document.getElementById('cmd-unified-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const command = fd.get('command')?.trim();
      if (!command) return;
      const outEl = document.getElementById('cmd-unified-output');
      outEl.textContent = 'thinking…';
      outEl.className = 'cmd-unified-output';
      const ts = new Date().toISOString();

      // Try AI first when enabled in persisted CTRL settings
      const aiOn = !ctrlState.ai || (ctrlState.ai.mode !== 'off' && ctrlState.ai.cmd_ai !== false);
      if (aiOn) {
        try {
        const aiRes = await fetch('/cmd/ai', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ prompt: command }),
        });
        const aiData = await aiRes.json();

        if (aiData.ok && aiData.results) {
          // AI succeeded — show results
          const route = aiData.route || 'ai';
          const routeLabel = route === 'heuristic' ? '⚙ heuristic' : `⚡ ${aiData.provider || 'ai'}${aiData.model ? '/' + aiData.model : ''}`;
          let output = `${routeLabel} → ${aiData.commands.length} command(s)\n\n`;
          aiData.results.forEach(r => {
            output += `❯ ${r.cmd}\n${r.ok ? '✓' : '✗'} ${r.output}\n\n`;
          });
          outEl.textContent = output;
          outEl.className = 'cmd-unified-output';
          // Log
          await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
            body: JSON.stringify({ action: 'cmd_log', args: { entry: {
              command, mode: route, provider: aiData.provider, model: aiData.model || '',
              route: route,
              commands: aiData.commands, output: output.slice(0, 500),
              ok: true, ts, profile: profilePill.textContent
            }}}) });
          e.target.reset();
          await loadCmdLog();
          return;
        }

        // AI not available — fall back to direct CLI
        if (aiData.fallback || !aiData.ok) {
          outEl.textContent = (aiData.error ? aiData.error + '\n\n' : '') + 'running as CLI…';
        }
      } catch (_) {
        // AI endpoint failed — fall through to direct CLI
      }
      } // end if AI enabled

      // Direct CLI fallback — try AI endpoint even without AI mode
      // (the server will use heuristic parsing for natural language)
      try {
        const res = await fetch('/cmd/ai', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ prompt: command }),
        });
        const data = await res.json();
        if (data.ok && data.results) {
          const route = data.route || 'heuristic';
          const routeLabel = route === 'heuristic' ? '⚙ heuristic' : route === 'ai' ? `⚡ ${data.provider}/${data.model}` : `⚙ ${route}`;
          let output = `${routeLabel} → ${data.results.length} command(s)\n\n`;
          data.results.forEach(r => {
            output += `❯ ${r.cmd}\n${r.ok ? '✓' : '✗'} ${r.output}\n\n`;
          });
          outEl.textContent = output;
          outEl.className = 'cmd-unified-output';
          await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
            body: JSON.stringify({ action: 'cmd_log', args: { entry: {
              command, mode: 'ai-fallback', output: output.slice(0, 500),
              ok: true, ts, profile: profilePill.textContent
            }}}) });
          e.target.reset();
          await loadCmdLog();
          return;
        }
        // If AI also failed, try as direct ww CLI
        const cliRes = await fetch('/cmd', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ cmd: command }),
        });
        const cliData = await cliRes.json();
        outEl.textContent = cliData.output || cliData.error || 'done';
        outEl.className = 'cmd-unified-output' + (cliData.ok ? '' : ' error');
        await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
          body: JSON.stringify({ action: 'cmd_log', args: { entry: {
            command, mode: 'cli', output: (cliData.output || '').slice(0, 500),
            ok: cliData.ok, ts, profile: profilePill.textContent
          }}}) });
        e.target.reset();
        await loadCmdLog();
      } catch (err) {
        outEl.textContent = 'error: ' + err.message;
        outEl.className = 'cmd-unified-output error';
      }
    });
  }

  async function loadCmdLog() {
    const logEl = document.getElementById('cmd-log');
    if (!logEl) return;
    try {
      const res = await fetch('/data/cmd-log');
      const data = await res.json();
      if (!data.ok || !data.entries.length) {
        logEl.innerHTML = '<div class="empty-state">no commands yet</div>';
        return;
      }
      logEl.innerHTML = data.entries.map(e => {
        const t = e.ts ? new Date(e.ts).toLocaleString([], {month:'short',day:'numeric',hour:'2-digit',minute:'2-digit'}) : '';
        const ok = e.ok ? '✓' : '✗';
        const preview = (e.output || '').split('\n')[0].slice(0, 80);
        return `<div class="cmd-log-entry">
          <span class="cmd-log-cmd">${ok} ${e.command || ''}</span><span class="cmd-log-time">${t}${e.profile ? ' · ' + e.profile : ''}</span>
          <div class="cmd-log-result">${(e.output || '').replace(/</g, '&lt;')}</div>
        </div>`;
      }).join('');
      logEl.querySelectorAll('.cmd-log-entry').forEach(entry => {
        entry.addEventListener('click', () => entry.classList.toggle('expanded'));
      });
    } catch (_) {
      logEl.innerHTML = '<div class="empty-state">error loading log</div>';
    }
  }

  function showGunOutput(text, isError) {
    const el = document.getElementById('gun-output');
    if (!el) return;
    el.textContent = text;
    el.className = 'gun-output' + (isError ? ' error' : '');
  }

  // ── Time tag preview ────────────────────────────────────────────────────────
  function initTimewTagPreview() {
    const input = document.getElementById('timew-tag-input');
    const preview = document.getElementById('timew-tag-preview');
    if (!input || !preview) return;
    input.addEventListener('input', () => {
      const raw = input.value;
      const tags = raw.trim().toLowerCase().replace(/\s+/g, ' ').split(' ').filter(Boolean);
      if (!tags.length) { preview.innerHTML = ''; return; }
      preview.innerHTML = tags.map(t => `<span class="tag-preview-chip">${t}</span>`).join('');
    });
  }

  // ── Init ───────────────────────────────────────────────────────────────────
  async function init() {
    initToasts();
    initKeyboardShortcuts();
    initBulkToolbar();
    initTimewTagPreview();
    initSidebar();
    initNav();
    initProfilePill();
    initTerminal();
    initDensity();
    initAddForms();
    connectSSE();

    updateStatDate();
    applyTermPosition(termPosition, false);

    termPosToggle?.addEventListener('click', toggleTermPosition);
    document.addEventListener('keydown', (e) => {
      if (e.ctrlKey && e.shiftKey && e.key === 'T') {
        e.preventDefault();
        toggleTermPosition();
      }
    });

    // Active task pill click → switch to tasks + open detail
    document.getElementById('active-task-pill')?.addEventListener('click', async () => {
      const pill = document.getElementById('active-task-pill');
      const id = parseInt(pill?.dataset.taskId);
      await switchSection('tasks');
      if (id) {
        setTimeout(() => {
          const row = document.querySelector(`.task-row[data-id="${id}"]`);
          if (row) row.click();
        }, 200);
      }
    });

    loadCommands();
    loadUdaSchema();
    await refreshCtrlState();

    // Update warrior stats
    try {
      const profRes = await fetch('/data/profiles');
      const profData = await profRes.json();
      const wCount = document.getElementById('warrior-count');
      if (wCount && profData.ok) {
        wCount.textContent = profData.profiles.length + ' profiles';
      }
    } catch (_) {}

    // Fetch initial profile from /health, then load resources
    try {
      const res = await fetch('/health');
      const data = await res.json();
      if (data.profile) setProfile(data.profile);
    } catch (_) { }

    await loadProfileResources();
    await loadAccounts();
    await loadTimewTags();
    applyAiMeta();
    await loadSection(activeSection);

    // 30s polling fallback for active section (paused when tab hidden)
    setInterval(() => {
      if (document.visibilityState === 'hidden') return;
      if (activeSection === 'tasks') loadTasks();
      else if (activeSection === 'time') loadTime();
      else if (activeSection === 'journal') { journalPage = 1; loadJournal(); }
    }, 30000);

    termInput.focus();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
