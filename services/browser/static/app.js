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

  // ── Sidebar ────────────────────────────────────────────────────────────────
  function initSidebar() {
    const collapsed = localStorage.getItem('ww-sidebar-collapsed') === 'true';
    if (collapsed) collapseSidebar(false); // no transition on init

    sidebarToggle.addEventListener('click', () => {
      const isCollapsed = sidebar.classList.contains('collapsed');
      if (isCollapsed) expandSidebar(true);
      else collapseSidebar(true);
    });
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
    sectionTitle.textContent = name.charAt(0).toUpperCase() + name.slice(1);
    await loadSection(name);
  }

  // ── Profile ────────────────────────────────────────────────────────────────
  function setProfile(name) {
    const display = name || '—';
    profilePill.textContent = display;
    headerProfile.textContent = display;
    document.querySelectorAll('#profile-switcher li').forEach(li => {
      li.classList.toggle('active-profile', li.dataset.profile === name);
    });
  }

  async function loadProfiles() {
    try {
      const res = await fetch('/cmd', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ cmd: 'profile list' }),
      });
      const data = await res.json();
      if (!data.ok) return;
      const lines = data.output.trim().split('\n').filter(Boolean);
      profileList.innerHTML = '';
      lines.forEach(line => {
        // profile list output: one profile name per line (may have extra info)
        const name = line.trim().split(/\s+/)[0];
        if (!name) return;
        const li = document.createElement('li');
        li.textContent = name;
        li.dataset.profile = name;
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
        await loadSection(activeSection);
      }
    } catch (_) { }
  }

  function initProfilePill() {
    profilePill.addEventListener('click', async (e) => {
      e.stopPropagation();
      if (profileList.classList.contains('hidden')) {
        await loadProfiles();
        profileList.classList.remove('hidden');
      } else {
        profileList.classList.add('hidden');
      }
    });
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
      hintsBar.textContent = 'type a ww command — tab to filter mode';
    } else {
      termPrompt.textContent = '/ ';
      termPrompt.className = 'prompt-filter';
      hintsBar.textContent = 'filtering ' + activeSection + ' — tab to execute mode';
    }
    termInput.value = '';
  }

  function showOutput(text, isError) {
    cmdOutput.textContent = text;
    cmdOutput.className = isError ? 'error' : '';
    cmdOutput.classList.remove('hidden');
  }

  function hideOutput() {
    cmdOutput.classList.add('hidden');
    cmdOutput.textContent = '';
  }

  function pushHistory(cmd) {
    cmdHistory = [cmd, ...cmdHistory.filter(c => c !== cmd)].slice(0, 100);
    localStorage.setItem('ww-cmd-history', JSON.stringify(cmdHistory));
    historyIdx = -1;
  }

  async function execCmd(cmd) {
    pushHistory(cmd);
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
          historyIdx = -1;
        }
        return;
      }

      if (e.key === 'ArrowUp') {
        e.preventDefault();
        if (historyIdx < cmdHistory.length - 1) {
          historyIdx++;
          termInput.value = cmdHistory[historyIdx];
        }
        return;
      }

      if (e.key === 'ArrowDown') {
        e.preventDefault();
        if (historyIdx > 0) {
          historyIdx--;
          termInput.value = cmdHistory[historyIdx];
        } else {
          historyIdx = -1;
          termInput.value = '';
        }
        return;
      }

      if (e.key === 'Enter') {
        const val = termInput.value.trim();
        if (!val) return;
        termInput.value = '';
        if (termMode === 'execute') {
          await execCmd(val);
        } else {
          // Filter mode: dispatch event for sections to handle
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
  }

  // ── Data fetching ──────────────────────────────────────────────────────────

  async function loadSection(name) {
    if (name === 'tasks') await loadTasks();
    else if (name === 'time') await loadTime();
    else if (name === 'journal') await loadJournal();
    else if (name === 'ledger') await loadLedger();
  }

  async function loadTasks() {
    const list = document.getElementById('task-list');
    try {
      const res = await fetch('/data/tasks');
      const data = await res.json();
      renderTasks(data.tasks || []);
    } catch (e) {
      list.innerHTML = `<div class="empty-state">Could not load tasks: ${e.message}</div>`;
    }
  }

  function renderTasks(tasks) {
    const list = document.getElementById('task-list');
    if (!tasks.length) {
      list.innerHTML = '<div class="empty-state">No pending tasks</div>';
      return;
    }
    // Sort by urgency descending
    tasks.sort((a, b) => (b.urgency || 0) - (a.urgency || 0));
    list.innerHTML = tasks.map(t => {
      const urg = (t.urgency || 0).toFixed(1);
      const urgClass = t.urgency > 15 ? 'urg-high'
                     : t.urgency > 10 ? 'urg-med'
                     : t.urgency > 5  ? 'urg-low'
                     : 'urg-none';
      const project = t.project ? `<span class="badge-project">${t.project}</span>` : '';
      const tags = (t.tags || []).map(g => `<span class="tag">${g}</span>`).join('');
      const pri = t.priority ? `<span class="pri-dot pri-${t.priority.toLowerCase()}">${t.priority}</span>` : '';
      const due = t.due ? renderDue(t.due) : '';
      const isActive = t.status === 'active';
      const activeClass = isActive ? ' task-active' : '';
      const annotations = (t.annotations || []).map(a =>
        `<div class="annotation">↳ ${a.description}</div>`).join('');
      const startStop = isActive
        ? `<button class="act-btn act-stop" data-id="${t.id}">■</button>`
        : `<button class="act-btn act-start" data-id="${t.id}">▶</button>`;
      return `<div class="task-row${activeClass}" data-id="${t.id}" data-desc="${t.description}" data-project="${t.project || ''}" data-tags="${(t.tags || []).join(',')}">
        <span class="urg ${urgClass}">${urg}</span>
        ${project}
        <span class="task-desc">${t.description}</span>
        ${tags}${due}${pri}
        <span class="task-actions">
          ${startStop}
          <button class="act-btn act-done" data-id="${t.id}">✓</button>
        </span>
        ${annotations ? `<div class="task-annotations">${annotations}</div>` : ''}
      </div>`;
    }).join('');

    // Wire action buttons
    list.querySelectorAll('.act-done').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const id = btn.dataset.id;
        const res = await fetch('/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'done', id: parseInt(id) }),
        });
        const data = await res.json();
        if (data.ok) renderTasks(data.tasks || []);
      });
    });
    list.querySelectorAll('.act-start').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const res = await fetch('/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'start', id: parseInt(btn.dataset.id) }),
        });
        const data = await res.json();
        if (data.ok) renderTasks(data.tasks || []);
      });
    });
    list.querySelectorAll('.act-stop').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const res = await fetch('/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'stop', id: parseInt(btn.dataset.id) }),
        });
        const data = await res.json();
        if (data.ok) renderTasks(data.tasks || []);
      });
    });

    // Re-wire inline filter
    document.getElementById('task-filter').addEventListener('input', filterTasks);
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
      if (!data.ok) { today.textContent = data.error || 'Time data unavailable'; return; }

      const fmt = s => `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;
      let todayHtml = `<div class="time-card"><span class="time-total">${fmt(data.today_total_seconds)}</span> today`;
      if (data.active) {
        todayHtml += ` <span class="tracking-badge">● tracking: ${data.active_tags}</span>`;
      }
      todayHtml += '</div>';
      today.innerHTML = todayHtml;

      // Per-day bars for the current week
      const dayMap = {};
      const maxSec = 8 * 3600; // 8 h = full bar
      (data.intervals || []).forEach(iv => {
        const d = iv.start.slice(0, 8);
        dayMap[d] = (dayMap[d] || 0) + iv.duration;
      });
      const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const now = new Date();
      let weekHtml = '<div class="week-bars">';
      for (let i = 0; i < 7; i++) {
        const d = new Date(now);
        d.setDate(now.getDate() - now.getDay() + 1 + i);
        const key = d.toISOString().slice(0, 10).replace(/-/g, '');
        const secs = dayMap[key] || 0;
        const pct = Math.min(100, Math.round(secs / maxSec * 100));
        weekHtml += `<div class="week-day">
          <span class="day-name">${dayNames[i]}</span>
          <div class="day-bar"><div class="day-fill" style="width:${pct}%"></div></div>
          <span class="day-total">${secs ? fmt(secs) : '—'}</span>
        </div>`;
      }
      weekHtml += `<div class="week-total">Week total: ${fmt(data.week_total_seconds)}</div></div>`;
      week.innerHTML = weekHtml;

      // Recent intervals (most recent first, capped at 10)
      const recent = [...(data.intervals || [])].reverse().slice(0, 10);
      ints.innerHTML = '<div class="intervals-header">Recent</div>' + recent.map(iv => {
        return `<div class="interval-row"><span class="int-tags">${iv.tags}</span><span class="int-dur">${fmt(iv.duration)}</span></div>`;
      }).join('');
    } catch (e) {
      today.textContent = `Error: ${e.message}`;
    }
  }

  async function loadJournal() {
    const list = document.getElementById('journal-list');
    try {
      const res = await fetch('/data/journal');
      const data = await res.json();
      if (!data.ok || !data.entries.length) {
        list.innerHTML = '<div class="empty-state">No journal entries</div>';
        return;
      }
      list.innerHTML = data.entries.map((e, i) => {
        const lines = e.body.split('\n').filter(Boolean);
        const preview = lines.slice(0, 3).join('\n');
        const hasMore = lines.length > 3;
        return `<div class="journal-entry">
          <div class="entry-date">${e.date}</div>
          <div class="entry-body" id="jentry-${i}">${preview}</div>
          ${hasMore ? `<button class="entry-more" data-idx="${i}" data-full="${encodeURIComponent(e.body)}">show more</button>` : ''}
        </div>`;
      }).join('');
      list.querySelectorAll('.entry-more').forEach(btn => {
        btn.addEventListener('click', () => {
          const idx = btn.dataset.idx;
          document.getElementById(`jentry-${idx}`).textContent = decodeURIComponent(btn.dataset.full);
          btn.remove();
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
      // hledger JSON balance output is an array of account rows.
      // Each item has acctname and amounts.
      const balances = data.balances;
      if (Array.isArray(balances) && balances.length) {
        balDiv.innerHTML = '<div class="ledger-header">Balances</div>' + balances.map(row => {
          const name = row.acctname || row[0] || '';
          const amt = row.amounts?.[0]?.quantity ?? row[1] ?? '';
          const cls = name.startsWith('assets')   ? 'bal-asset'
                    : name.startsWith('income')   ? 'bal-income'
                    : name.startsWith('expenses') ? 'bal-expense'
                    : '';
          return `<div class="balance-row ${cls}">
            <span class="acct-name">${name}</span>
            <span class="acct-amt">${amt}</span>
          </div>`;
        }).join('');
      } else {
        balDiv.innerHTML = '<div class="empty-state">No balance data</div>';
      }

      const recent = data.recent;
      if (Array.isArray(recent) && recent.length) {
        recDiv.innerHTML = '<div class="ledger-header">Recent</div>' + recent.map(row => {
          // hledger register JSON: each row has date, description, account, amount, balance
          const d    = row.date        || row[0] || '';
          const desc = row.description || row[1] || '';
          const acct = row.account     || row[2] || '';
          const amt  = row.amount      || row[3] || '';
          return `<div class="ledger-row">
            <span class="tx-date">${d}</span>
            <span class="tx-desc">${desc}</span>
            <span class="tx-acct">${acct}</span>
            <span class="tx-amt">${amt}</span>
          </div>`;
        }).join('');
      }
    } catch (e) {
      balDiv.innerHTML = `<div class="empty-state">Error: ${e.message}</div>`;
    }
  }

  // ── Add forms ──────────────────────────────────────────────────────────────

  function initAddForms() {
    // Tasks
    document.getElementById('btn-add-task')?.addEventListener('click', () => {
      document.getElementById('add-task-form').classList.toggle('hidden');
    });
    document.getElementById('add-task-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const tags = fd.get('tags') ? fd.get('tags').split(',').map(t => t.trim()).filter(Boolean) : [];
      const res = await fetch('/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'add', args: {
          description: fd.get('description'),
          project:  fd.get('project')  || undefined,
          priority: fd.get('priority') || undefined,
          due:      fd.get('due')      || undefined,
          tags,
        }}),
      });
      const data = await res.json();
      if (data.ok) {
        renderTasks(data.tasks || []);
        e.target.reset();
        e.target.classList.add('hidden');
      }
    });
    document.querySelector('#add-task-form .btn-cancel')?.addEventListener('click', () => {
      document.getElementById('add-task-form').classList.add('hidden');
    });

    // Journal
    document.getElementById('btn-add-journal')?.addEventListener('click', () => {
      document.getElementById('add-journal-form').classList.toggle('hidden');
    });
    document.getElementById('add-journal-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const res = await fetch('/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'journal_add', args: { entry: fd.get('entry') } }),
      });
      const data = await res.json();
      if (data.ok) {
        await loadJournal();
        e.target.reset();
        e.target.classList.add('hidden');
      }
    });
    document.querySelector('#add-journal-form .btn-cancel')?.addEventListener('click', () => {
      document.getElementById('add-journal-form').classList.add('hidden');
    });

    // Ledger
    document.getElementById('btn-add-ledger')?.addEventListener('click', () => {
      document.getElementById('add-ledger-form').classList.toggle('hidden');
    });
    document.getElementById('add-ledger-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const res = await fetch('/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'ledger_add', args: {
          date:        fd.get('date')        || undefined,
          description: fd.get('description'),
          account:     fd.get('account')     || 'expenses:misc',
          amount:      fd.get('amount')      || '0',
        }}),
      });
      const data = await res.json();
      if (data.ok) {
        await loadLedger();
        e.target.reset();
        e.target.classList.add('hidden');
      }
    });
    document.querySelector('#add-ledger-form .btn-cancel')?.addEventListener('click', () => {
      document.getElementById('add-ledger-form').classList.add('hidden');
    });
  }

  // ── Init ───────────────────────────────────────────────────────────────────
  async function init() {
    initSidebar();
    initNav();
    initProfilePill();
    initTerminal();
    initAddForms();
    connectSSE();

    // Fetch initial profile from /health
    try {
      const res = await fetch('/health');
      const data = await res.json();
      if (data.profile) setProfile(data.profile);
    } catch (_) { }

    await loadSection(activeSection);

    termInput.focus();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
