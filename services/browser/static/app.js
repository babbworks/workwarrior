// app.js — Workwarrior Browser UI
// Vanilla JS, no frameworks. Serves as the SPA shell for Wave 2.

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

  function switchSection(name) {
    activeSection = name;
    document.querySelectorAll('.section').forEach(s => s.classList.add('hidden'));
    const el = document.getElementById('section-' + name);
    if (el) el.classList.remove('hidden');
    document.querySelectorAll('.nav-item').forEach(b => {
      b.classList.toggle('active', b.dataset.section === name);
    });
    sectionTitle.textContent = name.charAt(0).toUpperCase() + name.slice(1);
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
      if (data.ok) setProfile(data.profile);
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
          // Filter mode: dispatch event for sections to handle (Wave 3)
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

  // ── Init ───────────────────────────────────────────────────────────────────
  async function init() {
    initSidebar();
    initNav();
    initProfilePill();
    initTerminal();
    connectSSE();

    // Fetch initial profile from /health
    try {
      const res = await fetch('/health');
      const data = await res.json();
      if (data.profile) setProfile(data.profile);
    } catch (_) { }

    termInput.focus();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
