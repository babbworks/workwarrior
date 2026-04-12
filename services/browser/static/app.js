// app.js — Workwarrior Browser UI
// Vanilla JS, no frameworks. Serves as the SPA shell.

(function () {
  'use strict';

  // ── State ─────────────────────────────────────────────────────────────────
  let activeSection = 'tasks';
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
  }

  async function switchSection(name) {
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

    sseSource.onerror = () => {
      setConnected(false);
      sseSource.close();
      sseSource = null;
      setTimeout(connectSSE, sseRetryDelay);
      sseRetryDelay = Math.min(sseRetryDelay * 2, 30000);
    };
  }

  // ── Terminal line ──────────────────────────────────────────────────────────
  function setTermMode(mode) {
    termMode = mode;
    if (mode === 'execute') {
      termPrompt.textContent = '❯ ';
      termPrompt.className = 'prompt-exec';
      termInput.value = '';
      termInput.dispatchEvent(new Event('input'));
    } else {
      termPrompt.textContent = '/ ';
      termPrompt.className = 'prompt-filter';
      hintsBar.textContent = 'filtering ' + activeSection + ' — tab to execute mode';
      termInput.value = '';
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
        setTermMode(termMode === 'execute' ? 'filter' : 'execute');
        return;
      }

      if (e.key === 'Escape') {
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

    // Typeahead hints
    termInput.addEventListener('input', () => {
      const val = termInput.value.trim();
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
      card.innerHTML = `<div class="empty-state">Error loading next task: ${e.message}</div>`;
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
      card.innerHTML = `<div class="empty-state">Error: ${e.message}</div>`;
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
      list.innerHTML = `<div class="empty-state">Tasks error: ${e.message}</div>`;
    }
  }

  function renderTasks(tasks) {
    const list = document.getElementById('task-list');
    cachedTasks = tasks;

    if (!tasks.length) {
      list.innerHTML = '<div class="empty-state">No pending tasks</div>';
      return;
    }
    tasks.sort((a, b) => (b.urgency || 0) - (a.urgency || 0));
    try { list.innerHTML = tasks.map(t => {
      const urg = (t.urgency || 0).toFixed(1);
      const urgClass = t.urgency > 15 ? 'urg-high' : t.urgency > 10 ? 'urg-med' : t.urgency > 5 ? 'urg-low' : 'urg-none';
      const project = t.project ? `<span class="badge-project">${t.project}</span>` : '';
      const tags = (t.tags || []).map(g => `<span class="tag">${g}</span>`).join('');
      const pri = t.priority ? `<span class="pri-dot pri-${t.priority.toLowerCase()}">${t.priority}</span>` : '';
      const due = t.due ? renderDue(t.due) : '';
      const isActive = t.status === 'active';
      const activeClass = isActive ? ' task-active' : '';
      const startStop = isActive
        ? `<button class="act-btn act-stop" data-id="${t.id}"><span class="btn-icon">■</span><span class="btn-word">stop</span></button>`
        : `<button class="act-btn act-start" data-id="${t.id}"><span class="btn-icon">▶</span><span class="btn-word">start</span></button>`;
      return `<div class="task-row${activeClass}" data-id="${t.id}" data-desc="${(t.description||'').replace(/"/g,'&quot;')}" data-project="${t.project || ''}" data-tags="${(t.tags || []).join(',')}">
        <span class="urg ${urgClass}">${urg}</span>
        ${project}
        <span class="task-desc">${t.description}</span>
        ${tags}${due}${pri}
        <span class="task-actions">
          ${startStop}
          <button class="act-btn act-done" data-id="${t.id}"><span class="btn-icon">✓</span><span class="btn-word">done</span></button>
        </span>
      </div>
      <div class="task-inline-detail hidden" id="tid-${t.id}"></div>`;
    }).join('');
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
        } catch (err) { console.error('done failed:', err); }
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
        } catch (err) { console.error('start failed:', err); }
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
        } catch (err) { console.error('stop failed:', err); }
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

    document.getElementById('task-filter').addEventListener('input', filterTasks);
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
    const entryFmt = t.entry ? t.entry.replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3') : '';
    const urg = (t.urgency || 0).toFixed(1);
    const annotations = (t.annotations || []).map(a =>
      `<div class="annotation">↳ <span style="color:var(--muted);font-size:11px">${a.entry ? a.entry.replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3') : ''}</span> ${a.description}</div>`
    ).join('');

    // Editable user UDAs
    let userUdaHtml = '';
    if (userUdas.length) {
      userUdaHtml = userUdas.map(([k, v]) =>
        `<div class="task-detail-uda-row"><label class="task-detail-uda-label">${k}</label><input type="text" class="task-detail-uda-input" data-uda="${k}" value="${String(v ?? '').replace(/"/g, '&quot;')}" /></div>`
      ).join('');
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

    // Populate UDA autocomplete
    (async () => {
      try {
        const res = await fetch('/data/udas');
        const data = await res.json();
        const dl = el.querySelector('#uda-autocomplete-list');
        if (dl && data.udas) {
          data.udas.forEach(u => {
            const opt = document.createElement('option');
            opt.value = u.name;
            opt.label = `${u.name} (${u.type}) — ${u.label}`;
            dl.appendChild(opt);
          });
        }
      } catch (_) {}
    })();

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
      const oldTags = new Set(t.tags || []);
      const newTags = new Set(gf('te-tags').value.split(',').map(s => s.trim()).filter(Boolean));
      const tagsAdd = [...newTags].filter(x => !oldTags.has(x));
      const tagsRm = [...oldTags].filter(x => !newTags.has(x));
      if (tagsAdd.length) mods.tags_add = tagsAdd;
      if (tagsRm.length) mods.tags_remove = tagsRm;
      el.querySelectorAll('.task-detail-uda-input').forEach(inp => {
        const k = inp.dataset.uda;
        const v = inp.value.trim();
        if (v !== String(t[k] ?? '')) mods[k] = v;
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

  async function loadTime() {
    const today = document.getElementById('time-today');
    const week  = document.getElementById('time-week');
    const ints  = document.getElementById('time-intervals');
    try {
      const res = await fetch('/data/time');
      const data = await res.json();
      if (!data.ok) { today.innerHTML = `<div class="empty-state">${data.error || 'No active profile'}</div>`; return; }

      const fmt = s => `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;

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
            '$1-$2-$3T$4:$5:$6Z')).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'}) : '';
        todayHtml += `<span class="tracking-badge"><span class="pulse-dot"></span> tracking ${data.active_tags || ''}${sinceLocal ? ' since ' + sinceLocal : ''}</span>`;
      } else {
        todayHtml += `<span class="idle-badge">idle</span>`;
      }
      todayHtml += `</div>`;
      today.innerHTML = todayHtml;

      // Update today's time stat in top bar
      if (statTimeToday) {
        statTimeToday.textContent = `${fmt(data.today_total_seconds)} today`;
        statTimeToday.classList.remove('hidden');
      }
      updateContextBar('time', data);

      // Per-day bars for the current week — label current day with accent color
      const dayMap = {};
      const maxSec = 8 * 3600; // 8 h = full bar
      (data.intervals || []).forEach(iv => {
        const d = iv.start.slice(0, 8);
        dayMap[d] = (dayMap[d] || 0) + iv.duration;
      });
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const now = new Date();
      const todayIdx = (now.getDay() + 6) % 7; // Mon=0
      let weekHtml = '<div class="week-bars">';
      for (let i = 0; i < 7; i++) {
        const d = new Date(now);
        d.setDate(now.getDate() - todayIdx + i);
        const key = d.toISOString().slice(0, 10).replace(/-/g, '');
        const secs = dayMap[key] || 0;
        const pct = Math.min(100, Math.round(secs / maxSec * 100));
        const isCurrent = i === todayIdx;
        weekHtml += `<div class="week-day">
          <span class="day-name${isCurrent ? ' day-current' : ''}">${days[i]} ${d.getDate()}</span>
          <div class="day-bar"><div class="day-fill${isCurrent ? ' day-fill-current' : ''}" style="width:${pct}%"></div></div>
          <span class="day-total">${secs ? fmt(secs) : '—'}</span>
        </div>`;
      }
      weekHtml += `<div class="week-total">Week total: ${fmt(data.week_total_seconds)}</div></div>`;
      week.innerHTML = weekHtml;

      // Recent intervals grouped by local date
      const byDay = {};
      [...(data.intervals || [])].reverse().slice(0, 20).forEach(iv => {
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
      today.textContent = `Error: ${e.message}`;
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

  async function loadJournal() {
    const list = document.getElementById('journal-list');
    try {
      const res = await fetch('/data/journal');
      const data = await res.json();
      if (!data.ok || !data.entries.length) {
        list.innerHTML = '<div class="empty-state">No journal entries</div>';
        updateContextBar('journal', { entries: [] });
        return;
      }
      updateContextBar('journal', data);
      list.innerHTML = data.entries.map((e, i) => {
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
      }).join('');
      list.querySelectorAll('.entry-more').forEach(btn => {
        btn.addEventListener('click', () => {
          const idx = btn.dataset.idx;
          document.getElementById(`jentry-${idx}`).innerHTML = highlightTags(decodeURIComponent(btn.dataset.full));
          btn.remove();
        });
      });
      // Annotate: add a follow-up entry referencing this one
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
          document.getElementById(`jann-input-${idx}`).addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); submit(); } });
        });
      });
      // Journal note: add a new entry referencing this one
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
          document.getElementById(`jnote-input-${idx}`).addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); submit(); } });
        });
      });
      // Client-side search
      document.getElementById('journal-search')?.addEventListener('input', (e) => {
        const q = e.target.value.toLowerCase();
        document.querySelectorAll('.journal-entry').forEach(el => {
          el.style.display = (!q || el.textContent.toLowerCase().includes(q)) ? '' : 'none';
        });
      });
    } catch (e) {
      list.innerHTML = `<div class="empty-state">Error: ${e.message}</div>`;
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
      balDiv.innerHTML = `<div class="empty-state">Error: ${e.message}</div>`;
    }
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
      statContextBar.textContent = `entries: ${count}  ·  last: ${last}`;
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

  async function loadSync() {
    const body = document.getElementById('sync-body');
    try {
      const res = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ cmd: 'issues help' }) });
      const data = await res.json();
      body.innerHTML = `<pre class="service-output">${data.output || 'Sync service available. Use buttons below.'}</pre>`;
    } catch (_) { body.innerHTML = '<div class="empty-state">Sync service unavailable</div>'; }
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
      body.innerHTML = Object.entries(data.groups).map(([name, profiles]) =>
        `<div class="group-card">
          <div class="group-name">${name}</div>
          <div class="group-profiles">${profiles.join(', ') || 'empty'}</div>
          <div style="margin-top:6px;display:flex;gap:4px">
            <button class="act-btn group-show-btn" data-name="${name}">show</button>
            <button class="act-btn group-delete-btn" data-name="${name}">delete</button>
          </div>
        </div>`
      ).join('');
      body.querySelectorAll('.group-show-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
          const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ cmd: `group show ${btn.dataset.name}` }) });
          const d = await r.json();
          alert(d.output || 'no data');
        });
      });
      body.querySelectorAll('.group-delete-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
          if (!confirm(`Delete group "${btn.dataset.name}"?`)) return;
          await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ cmd: `group delete ${btn.dataset.name}` }) });
          await loadGroups();
        });
      });
    } catch (_) { body.innerHTML = '<div class="empty-state">Error loading groups</div>'; }
  }

  async function loadModels() {
    const body = document.getElementById('models-body');
    try {
      const res = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ cmd: 'model list' }) });
      const data = await res.json();
      body.innerHTML = `<pre class="service-output">${data.output || 'No models configured'}</pre>`;
    } catch (_) { body.innerHTML = '<div class="empty-state">Error loading models</div>'; }
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
    } catch (_) { body.innerHTML = '<div class="empty-state">Network check failed</div>'; }
  }

  async function loadQuestions() {
    const body = document.getElementById('questions-body');
    try {
      const res = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ cmd: 'q list' }) });
      const data = await res.json();
      body.innerHTML = `<pre class="service-output">${data.output || 'No templates. Create one below.'}</pre>`;
    } catch (_) { body.innerHTML = '<div class="empty-state">Questions service unavailable</div>'; }
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
    } catch (_) { body.innerHTML = '<div class="empty-state">Error loading projects</div>'; }
  }

  async function loadProfileScreen() {
    const body = document.getElementById('profile-body');
    try {
      const profRes = await fetch('/data/profiles');
      const profData = await profRes.json();
      const profiles = profData.profiles || [];
      const active = profData.active || '';
      let html = `<select id="profile-detail-select" class="resource-select" style="font-size:12px;padding:4px 8px;margin-bottom:8px">`;
      profiles.forEach(p => { html += `<option value="${p}"${p === active ? ' selected' : ''}>${p}</option>`; });
      html += `</select><div id="profile-detail-content"><div class="skeleton-msg">Loading…</div></div>`;
      body.innerHTML = html;
      const loadDetail = async (name) => {
        const content = document.getElementById('profile-detail-content');
        try {
          const res = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ cmd: 'profile info ' + name }) });
          const data = await res.json();
          content.innerHTML = `<pre class="service-output">${data.output || 'No info'}</pre>`;
        } catch (_) { content.innerHTML = '<div class="empty-state">Error</div>'; }
      };
      document.getElementById('profile-detail-select')?.addEventListener('change', (e) => loadDetail(e.target.value));
      await loadDetail(active || profiles[0] || '');
    } catch (_) { body.innerHTML = '<div class="empty-state">Error</div>'; }
  }

  async function loadWarrior() {
    const body = document.getElementById('warrior-body');
    try {
      const profRes = await fetch('/data/profiles');
      const profData = await profRes.json();
      const profiles = profData.profiles || [];
      const active = profData.active || '';

      let html = `<div style="margin-bottom:12px;font-size:12px;color:var(--muted)">
        <span style="color:var(--text)">${profiles.length}</span> profiles ·
        active: <span style="color:var(--accent)">${active || 'none'}</span>
      </div>`;

      // Global stats summary
      html += '<div class="warrior-global-stats">';
      for (const p of profiles.slice(0, 10)) {
        html += `<div class="group-card"><div class="group-name">${p}${p === active ? ' ✱' : ''}</div>`;
        html += `<div class="group-profiles" id="warrior-stat-${p}">loading…</div></div>`;
      }
      html += '</div>';

      // Global settings access
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

      // Load per-profile task counts
      for (const p of profiles.slice(0, 10)) {
        try {
          const res = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ cmd: `profile stats ${p}` }) });
          const data = await res.json();
          const el = document.getElementById(`warrior-stat-${p}`);
          if (el) {
            const lines = (data.output || '').split('\n').filter(l => l.trim()).slice(0, 4);
            el.textContent = lines.join(' · ') || 'no stats';
          }
        } catch (_) {}
      }

      // Wire global settings buttons
      const wOut = document.getElementById('warrior-output');
      const wCmd = async (cmd) => {
        wOut.className = 'cmd-unified-output'; wOut.textContent = 'loading…';
        const res = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ cmd }) });
        const data = await res.json(); wOut.textContent = data.output || 'done';
      };
      document.getElementById('btn-w-version')?.addEventListener('click', () => wCmd('version'));
      document.getElementById('btn-w-deps')?.addEventListener('click', () => wCmd('deps check'));
      document.getElementById('btn-w-shortcuts')?.addEventListener('click', () => wCmd('shortcut list'));
    } catch (_) { body.innerHTML = '<div class="empty-state">Error loading warrior</div>'; }
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
          project:  fd.get('project')  || undefined,
          priority: fd.get('priority') || undefined,
          due:      fd.get('due')      || undefined,
          tags,
        }}),
      });
      const data = await res.json();
      if (data.ok) {
        renderTasks(data.tasks || []);
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
      }
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
      const tags = form?.querySelector('input[name="tags"]')?.value?.trim() || '';
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
      await timeFormAction('timew_start');
      await loadTime();
    });

    document.getElementById('btn-timew-stop')?.addEventListener('click', async () => {
      await fetch('/action', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ action: 'timew_stop' }) });
      await loadTime();
    });

    document.getElementById('add-time-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const form = e.target;
      const duration = form.querySelector('input[name="duration"]')?.value || '';
      if (!duration) return;
      await timeFormAction('timew_track', { duration });
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
        await loadJournal();
        e.target.reset();
      }
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
    document.getElementById('btn-bb-status')?.addEventListener('click', () => bbCmd('find bookbuilder'));
    document.getElementById('btn-bb-search')?.addEventListener('click', () => {
      const term = prompt('Search knowledge base:');
      if (term) bbCmd(`find --type journal ${term}`);
    });
    document.getElementById('btn-bb-inbox')?.addEventListener('click', () => {
      const out = bbOut();
      out.className = 'cmd-unified-output';
      out.textContent = 'BookBuilder inbox:\n  bookbuilder inbox\n  bookbuilder inbox --status want_to_read\n\nRun from terminal: bookbuilder inbox';
    });
    document.getElementById('btn-bb-run')?.addEventListener('click', () => {
      const out = bbOut();
      out.className = 'cmd-unified-output';
      out.textContent = 'Run the full pipeline from terminal:\n  bookbuilder run\n\nOr individual stages:\n  bookbuilder ingest\n  bookbuilder fetch\n  bookbuilder analyze\n  bookbuilder cluster\n  bookbuilder build\n  bookbuilder agents';
    });
    document.getElementById('bb-add-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const url = e.target.querySelector('input[name="url"]')?.value?.trim();
      if (!url) return;
      const out = bbOut();
      out.className = 'cmd-unified-output'; out.textContent = `saving: ${url}…`;
      // Log to journal as a saved item
      await sendJournalNote(`[saved] ${url}`, null);
      out.textContent = `✓ saved to journal: ${url}\n\nTo add to bookbuilder knowledge base:\n  bookbuilder add ${url}`;
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

  // ── Init ───────────────────────────────────────────────────────────────────
  async function init() {
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

    loadCommands();
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

    termInput.focus();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
