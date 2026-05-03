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
  let termContextCmd = null; // non-null = context mode: next Enter prepends this cmd
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
  let taskShowDone = false;
  let taskAnnVisible = localStorage.getItem('ww-task-ann-visible') !== 'false';
  let udaSchema = new Map(); // name → {type, label}
  let bulkSelected = new Set(); // selected task IDs for bulk ops
  let communityState = { names: [], selected: '', entries: [], view: 'unified' };

  function esc(s) {
    if (s == null || s === undefined) return '';
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

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

  // ── Confirm modal ─────────────────────────────────────────────────────────
  function confirmAction(title, description, onConfirm) {
    document.getElementById('ww-confirm-modal')?.remove();
    const overlay = document.createElement('div');
    overlay.id = 'ww-confirm-modal';
    overlay.className = 'confirm-overlay';
    overlay.innerHTML = `<div class="confirm-dialog">
      <div class="confirm-title">${esc(title)}</div>
      <div class="confirm-body">${description}</div>
      <div class="confirm-actions">
        <button class="act-btn confirm-ok-btn">${esc(title)}</button>
        <button class="btn-inline-alt confirm-cancel-btn">cancel</button>
      </div>
    </div>`;
    document.body.appendChild(overlay);
    const close = () => overlay.remove();
    overlay.querySelector('.confirm-ok-btn').addEventListener('click', () => { close(); onConfirm(); });
    overlay.querySelector('.confirm-cancel-btn').addEventListener('click', close);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });
    overlay.querySelector('.confirm-ok-btn').focus();
  }

  // ── ww Help Panel ─────────────────────────────────────────────────────────
  const WW_HELP_TOPICS = [
    { id: 'overview', group: 'intro', label: '✱ Overview', content: `
<h2>ww · workwarrior</h2>
<p>Terminal-first, profile-based productivity system. Unifies TaskWarrior, TimeWarrior, JRNL, and Hledger under a single <code>ww</code> CLI. Each profile is a fully isolated workspace — its own tasks, time tracking, journals, and ledgers.</p>
<h3>Core Tools</h3>
<table><tr><th>Tool</th><th>What it does</th></tr>
<tr><td>task</td><td>TaskWarrior — tasks with UDAs, urgency scoring, dependencies, projects</td></tr>
<tr><td>timew</td><td>TimeWarrior — interval time tracking with tags, summaries, and reports</td></tr>
<tr><td>j</td><td>JRNL — dated journal entries with tags, projects, and priorities</td></tr>
<tr><td>l</td><td>Hledger — double-entry accounting with reports, accounts, and balances</td></tr>
</table>
<h3>Key Concepts</h3>
<table>
<tr><td>Profile</td><td>Isolated workspace — activate with <code>p-&lt;name&gt;</code>, all tools redirect automatically</td></tr>
<tr><td>ww</td><td>CLI dispatcher — routes all commands to 25+ service scripts</td></tr>
<tr><td>Shell functions</td><td>Injected on profile activation: <code>task</code>, <code>timew</code>, <code>j</code>, <code>l</code>, <code>q</code>, <code>list</code></td></tr>
<tr><td>Browser UI</td><td>Locally-served SPA on port 7777 — this interface</td></tr>
<tr><td>CMD</td><td>Unified command input with heuristic engine (627 rules) + AI fallback</td></tr>
<tr><td>Weapons</td><td>Task manipulation tools: gun (bulk series), sword (splitting), next, schedule</td></tr>
</table>
<h3>Quick Start</h3>
<pre><code>./install.sh
ww profile create work
p-work
ww browser</code></pre>` },

    { id: 'start', group: 'intro', label: '→ Getting Started', content: `
<h2>Getting Started</h2>
<h3>Install</h3>
<pre><code>git clone &lt;repo-url&gt; ~/ww
cd ~/ww && ./install.sh
source ~/.zshrc        # or ~/.bashrc</code></pre>
<p>The installer detects your platform, checks for dependencies (TaskWarrior, TimeWarrior, JRNL, Hledger, Python 3), and offers to install missing tools via brew/apt/dnf/pacman.</p>
<h3>Create and Activate a Profile</h3>
<pre><code>ww profile create work
p-work                # activates — env vars set, all tools redirect</code></pre>
<h3>Tasks</h3>
<pre><code>task add "Review PR" project:api priority:H due:tomorrow +review
task list
task 1 start          # also starts time tracking via hook
task 1 done</code></pre>
<h3>Time</h3>
<pre><code>timew day             # today's breakdown
timew summary         # this week
timew start dev       # start tracking with tag 'dev'
timew stop</code></pre>
<h3>Journal</h3>
<pre><code>j "Sprint planning complete — 8 stories committed"
j standup "Daily standup notes"
j --profile work "cross-profile entry"</code></pre>
<h3>Ledger</h3>
<pre><code>l balance
l register expenses
l add</code></pre>
<h3>Browser UI</h3>
<pre><code>ww browser            # opens http://localhost:7777
ww browser --port 8888
ww browser stop</code></pre>
<h3>Multiple Profiles</h3>
<pre><code>ww profile create personal
ww profile create freelance
p-personal            # switch
p-work                # back</code></pre>` },

    { id: 'profiles', group: 'intro', label: '◈ Profiles', content: `
<h2>Profiles</h2>
<p>Each profile is a self-contained directory. Switching is instant — just environment variable changes. No tool knows Workwarrior exists.</p>
<h3>Lifecycle</h3>
<pre><code>ww profile create &lt;name&gt;
ww profile list
ww profile info &lt;name&gt;
ww profile delete &lt;name&gt;    # prompts for confirmation</code></pre>
<h3>Activate</h3>
<pre><code>p-&lt;name&gt;                    # e.g. p-work, p-personal</code></pre>
<h3>Backup and Restore</h3>
<pre><code>ww profile backup work                      # creates tar.gz in home dir
ww profile backup work ~/backups            # custom location
ww profile import ~/work-backup-*.tar.gz   # as new profile
ww profile import ~/backup.tar.gz work-copy # under different name
ww profile restore work ~/backup.tar.gz    # overwrites (safety backup auto-created)</code></pre>
<h3>UDA Management</h3>
<pre><code>ww profile uda list
ww profile uda add &lt;name&gt; &lt;type&gt; &lt;label&gt;
ww profile uda remove &lt;name&gt;
ww profile uda group &lt;name&gt; &lt;group&gt;</code></pre>
<h3>Scope Flags</h3>
<pre><code>j --profile work "entry"      # write to another profile's journal
task --profile work list      # list another profile's tasks
l --global balance            # use global ledger
list --global                 # global list workspace</code></pre>
<h3>Environment Variables (set on activation)</h3>
<table>
<tr><td>WARRIOR_PROFILE</td><td>Active profile name</td></tr>
<tr><td>WORKWARRIOR_BASE</td><td>Profile base directory</td></tr>
<tr><td>TASKRC</td><td>Profile .taskrc path</td></tr>
<tr><td>TASKDATA</td><td>Profile .task directory</td></tr>
<tr><td>TIMEWARRIORDB</td><td>Profile .timewarrior directory</td></tr>
</table>` },

    { id: 'tasks', group: 'functions', label: '∼ Tasks', content: `
<h2>Tasks</h2>
<p>TaskWarrior with profile isolation. All standard task commands work. Hooks auto-start TimeWarrior on task start.</p>
<h3>Common Commands</h3>
<pre><code>task add "description" project:api priority:H due:tomorrow +tag
task list
task 1 start          # starts task + time tracking
task 1 stop
task 1 done
task 1 delete
task 1 modify priority:M
task 1 annotate "note text"</code></pre>
<h3>Filtering</h3>
<pre><code>task project:api
task +review +backend
task priority:H
task due:today
task status:pending</code></pre>
<h3>Dependencies</h3>
<pre><code>task 3 modify depends:1,2     # task 3 blocked by 1 and 2
task 3 modify depends+:4      # add dep
task 3 modify depends-:1      # remove dep</code></pre>
<h3>UDAs (User Defined Attributes)</h3>
<pre><code>ww profile uda list            # show configured UDAs
task add "thing" uda_field:value
ww profile urgency             # view urgency config</code></pre>
<h3>Bulk Operations (Browser UI)</h3>
<p>Select tasks with checkboxes → bulk toolbar: done, delete, set project, add/remove tags, set priority.</p>
<h3>Urgency</h3>
<pre><code>ww profile urgency             # show urgency coefficients
task 1 info                    # show urgency score for a task</code></pre>` },

    { id: 'time', group: 'functions', label: '⭕ Time', content: `
<h2>Time Tracking</h2>
<p>TimeWarrior with profile isolation. Interval-based tracking with tags. Hooks auto-start/stop on task start/done.</p>
<h3>Track Time</h3>
<pre><code>timew start dev api           # start with tags
timew stop
timew track 9am to 10am dev   # log past interval
timew continue                # resume last interval</code></pre>
<h3>Reports</h3>
<pre><code>timew day                     # today
timew week                    # this week
timew summary                 # default summary
timew summary :week           # explicit week filter
timew summary :month dev      # filter by tag</code></pre>
<h3>Modify Intervals</h3>
<pre><code>timew @1 modify :adjust       # edit most recent
timew @2 untag dev            # remove tag from interval
timew delete @1               # delete most recent</code></pre>
<h3>Browser UI — Times Section</h3>
<p>Start tracking with optional tags + description + linked task. View today total, week breakdown by tag, recent intervals. Click interval to expand; ⊗ to archive (delete).</p>
<h3>Extensions</h3>
<pre><code>ww timew extensions list      # per-profile extensions
ww extensions taskwarrior list</code></pre>` },

    { id: 'journal', group: 'functions', label: '╱ Journal', content: `
<h2>Journal</h2>
<p>JRNL with profile isolation. Timestamped entries with tags, projects, and priorities. Supports multiple named journals per profile.</p>
<h3>Write Entries</h3>
<pre><code>j "Sprint planning complete — 8 stories"
j standup "Daily notes"          # named journal
j --profile work "entry"         # target profile directly</code></pre>
<h3>Manage Journals</h3>
<pre><code>ww journal list
ww journal add &lt;name&gt;
ww journal rename &lt;old&gt; &lt;new&gt;
ww journal remove &lt;name&gt;
journals                          # list all (standalone)</code></pre>
<h3>Browse and Filter</h3>
<pre><code>j list                           # recent entries
j @tag                           # filter by tag
j "search term"                  # search entries
j --format pretty                # pretty-print</code></pre>
<h3>Entry Format</h3>
<p>Entries start with a date/time header. Use <code>@tag</code> for tags and <code>@project:name</code> for projects in the entry body. Priority metadata via <code>@priority:H</code>.</p>
<h3>Browser UI — Journals Section</h3>
<p>Add entries with project, tags, priority. Search and paginate. Filter by Annotated / Rejournaled / All Comments. Click entry to expand inline; ⊗ to archive.</p>` },

    { id: 'ledger', group: 'functions', label: '═ Ledger', content: `
<h2>Ledger</h2>
<p>Hledger with profile isolation. Double-entry accounting. Supports multiple named ledgers per profile.</p>
<h3>Basic Operations</h3>
<pre><code>l balance                        # all account balances
l register expenses              # transaction register
l register expenses:food 2024   # filter by account + year
l add                            # interactive transaction entry
l check                          # check journal for errors</code></pre>
<h3>Reports</h3>
<pre><code>l balancesheet
l incomestatement
l cashflow
l activity
l roi
l stats</code></pre>
<h3>Manage Ledger Files</h3>
<pre><code>ww ledger list
ww ledger add &lt;name&gt;
ww ledger rename &lt;old&gt; &lt;new&gt;
ww ledger remove &lt;name&gt;
ledgers                          # list all (standalone)</code></pre>
<h3>Accounts</h3>
<pre><code>l accounts                       # list all accounts
# Add accounts via Browser UI "add account" input</code></pre>
<h3>Browser UI — Ledgers Section</h3>
<p>Add transactions with date, description, account, amount, comment. Unit filter pills (auto-detect custom units from your data). Run balance sheet, income statement, cashflow, register, and more. Search transactions. ⊗ to archive (comment-out) entries.</p>` },

    { id: 'lists', group: 'functions', label: '• Lists', content: `
<h2>Lists</h2>
<p>Simple list management (sjl/t). Each profile can have multiple named lists.</p>
<h3>Commands</h3>
<pre><code>list                             # show items in active list
list add "item text"
list done &lt;prefix&gt;              # mark item done
list remove &lt;prefix&gt;            # remove item
list edit &lt;prefix&gt; "new text"   # edit item</code></pre>
<h3>Multiple Lists</h3>
<pre><code>list --list shopping "Milk"      # add to named list
list --list work                 # switch active list
list new shopping                # create list</code></pre>
<h3>Profile Scoping</h3>
<pre><code>list --profile work              # view another profile's list
list --global                    # global list workspace</code></pre>
<h3>Browser UI — Lists Section</h3>
<p>Add items, mark done, edit, add notes (stored as <code> // note text</code> suffix). Notes display below item. Buttons: ✓ done, ✎ edit, + note, → journal (log to journal), @comm (add to community collection), − remove. Filter items with search bar.</p>` },

    { id: 'search', group: 'functions', label: '⌕ Search', content: `
<h2>Search</h2>
<p>Cross-profile, cross-type search via <code>ww find</code>. Also per-section search in the browser UI.</p>
<h3>Basic Find</h3>
<pre><code>ww find invoice                  # search all profiles, all types
ww find --profile work meeting   # search one profile
ww find --type journal standup   # search only journals
ww find --global invoice         # include global workspace</code></pre>
<h3>Advanced Queries</h3>
<pre><code>ww find --query '(invoice OR receipt) AND NOT draft'
ww find --query 'type:journal profile:work "weekly review" | group type'
ww find --case-sensitive Invoice
ww find --regex 'inv(oi)?ce'
ww find --exclude '*/archive/*' invoice</code></pre>
<h3>Native Tool Search</h3>
<pre><code>ww find --type task --native invoice
ww find --type time --native @client-x :week
ww find --type ledger --native 'desc:invoice'</code></pre>
<h3>Browser UI Search</h3>
<p>Press <code>/</code> or <code>g s</code> to open the global search overlay. Searches tasks and journal entries. Results navigate to the relevant section.</p>
<h3>Per-section Search</h3>
<p>Filter inputs in Tasks, Journal, Ledger, Lists, Tags, and Projects sections filter their visible content live.</p>` },

    { id: 'weapons', group: 'services', label: '⚔ Weapons', content: `
<h2>Weapons</h2>
<p>Task manipulation tools for power users.</p>
<h3>Gun — Bulk Task Series</h3>
<p>Generates deadline-spaced sequences of tasks (e.g. course lectures, book chapters).</p>
<pre><code>ww gun ML_Course 20 Lecture 2d 7d         # 20 lectures, 2d offset, 7d interval
ww gun ML_Course 20 Lecture 2d 7d weekend # skip weekends</code></pre>
<p>Browser UI: Gun section — fill project, parts, unit name, offset, interval, skip pattern.</p>
<h3>Sword — Task Splitting</h3>
<p>Splits a single task into N sequential subtasks with dependency chains and due date offsets.</p>
<pre><code>ww sword &lt;task-id&gt; -p 3 -i 1d -prefix "Part"
# creates Part 1, Part 2, Part 3 with deps and due dates</code></pre>
<p>Browser UI: Sword section — search task, set parts, interval, prefix.</p>
<h3>Next — Task Recommendation</h3>
<p>CFS-inspired selector: scores pending tasks by urgency, recency, and fatigue. Recommends what to work on now.</p>
<pre><code>ww next</code></pre>
<h3>Schedule — Auto-Scheduler</h3>
<p>Assigns due dates to unscheduled tasks based on available capacity.</p>
<pre><code>ww schedule status
ww schedule enable
ww schedule disable
ww schedule run
ww schedule dryrun</code></pre>` },

    { id: 'sync', group: 'services', label: '⇄ Sync', content: `
<h2>GitHub Sync</h2>
<p>Two-way sync between TaskWarrior tasks and GitHub issues. Classified as high-fragility — requires GitHub CLI auth.</p>
<h3>Setup</h3>
<pre><code>ww issues install             # configure sync for current profile
gh auth login                 # ensure GitHub CLI is authenticated</code></pre>
<h3>Sync Operations</h3>
<pre><code>ww issues sync                # bidirectional sync
ww issues push                # push local → GitHub
ww issues pull                # pull GitHub → local
ww issues status              # show sync state</code></pre>
<h3>Enable / Disable</h3>
<pre><code>ww issues enable
ww issues disable</code></pre>
<h3>Field Mapping</h3>
<table>
<tr><th>TaskWarrior</th><th>GitHub</th></tr>
<tr><td>description</td><td>issue title</td></tr>
<tr><td>annotations</td><td>comments</td></tr>
<tr><td>tags</td><td>labels (ww: prefix)</td></tr>
<tr><td>priority</td><td>label (priority:H/M/L)</td></tr>
<tr><td>project</td><td>label (project:name)</td></tr>
<tr><td>status:done</td><td>issue closed</td></tr>
</table>
<h3>Browser UI — Sync Section</h3>
<p>Status dashboard showing last sync, pending changes. Buttons: status, pull, push, install.</p>` },

    { id: 'browser', group: 'services', label: '◆ Browser UI', content: `
<h2>Browser UI</h2>
<p>Locally-served SPA at <code>http://localhost:7777</code>. Python 3 stdlib only — no external dependencies.</p>
<h3>Launch</h3>
<pre><code>ww browser                    # opens browser automatically
ww browser --port 8888
ww browser --no-open          # start server without opening browser
ww browser stop
ww browser status</code></pre>
<h3>Sections</h3>
<table>
<tr><td>Tasks</td><td>Task list with add form, filter, group by project, bulk ops, inline detail, dep display</td></tr>
<tr><td>Times</td><td>Start/stop/track time, today total, week breakdown, recent intervals</td></tr>
<tr><td>Journals</td><td>Add entries, search, paginate, filter, inline expand, archive</td></tr>
<tr><td>Ledgers</td><td>Add transactions, reports, account management, unit filters</td></tr>
<tr><td>Lists</td><td>Multi-list management with notes, journal export, community push</td></tr>
<tr><td>Tags</td><td>Tag browser with chip filters, sort modes, task counts</td></tr>
<tr><td>Projects</td><td>Project cards with stats, task summary, inline detail, filter</td></tr>
<tr><td>Communities</td><td>Named collections — add tasks, journal entries, list items</td></tr>
</table>
<h3>Keyboard Shortcuts</h3>
<pre><code>?           keyboard shortcut overlay
g t         go to Tasks
g j         go to Journal
g l         go to Ledger
g m         go to Times
g p         go to Projects
/           global search
Escape      close overlays</code></pre>
<h3>CMD — Unified Command Input</h3>
<p>Terminal bar at the bottom. Accepts <code>ww</code> commands directly. Heuristic engine matches 627 rules; falls through to AI if configured. CMD section has full input with history.</p>
<h3>Architecture</h3>
<p>ThreadingHTTPServer handles SSE (live reload) without blocking POST requests. Static files served from disk — changes visible on browser refresh. All task/time mutations broadcast via SSE to connected clients.</p>` },

    { id: 'groups', group: 'services', label: '⊞ Groups & Models', content: `
<h2>Groups &amp; Models</h2>
<h3>Profile Groups</h3>
<p>Named sets of profiles for batch operations.</p>
<pre><code>ww group create focus work personal
ww group add focus client-x
ww group show focus
ww group list
ww group remove focus client-x
ww group delete focus
groups                           # list all (standalone)</code></pre>
<h3>AI Models</h3>
<p>Registry of LLM providers and models used by the CMD heuristic + AI fallback.</p>
<pre><code>ww model list
ww model providers
ww model show &lt;name&gt;
ww model add-provider openai openai https://api.openai.com/v1 OPENAI_API_KEY
ww model add-model gpt-4o-mini openai gpt-4o-mini "fast"
ww model set-default gpt-4o-mini
ww model env                     # show required env vars
ww model check                   # verify env vars set
models                           # standalone</code></pre>
<h3>CTRL — Settings</h3>
<pre><code>ww ctrl status
ww ctrl ai-on
ww ctrl ai-off
ww ctrl ai-status
ww ctrl shortcuts                # list shortcut bindings
ww ctrl version</code></pre>` },

    { id: 'commands', group: 'reference', label: '❯ Commands', content: `
<h2>Command Reference</h2>
<h3>Profile</h3>
<pre><code>ww profile create/list/info/delete/backup/import/restore
ww profile uda list/add/remove/group/perm
ww profile urgency
ww profile density</code></pre>
<h3>Data Services</h3>
<pre><code>ww journal add/list/remove/rename
ww ledger add/list/remove/rename
ww find &lt;term&gt; [--profile X] [--type T] [--global]
ww export</code></pre>
<h3>System Services</h3>
<pre><code>ww service list/info/help
ww group list/create/show/add/remove/delete
ww model list/providers/show/add-provider/set-default/env/check
ww ctrl status/ai-on/ai-off/ai-status
ww shortcut list/info/add/remove
ww extensions taskwarrior list/search/info/cards/refresh
ww deps install/check</code></pre>
<h3>Weapons</h3>
<pre><code>ww gun &lt;project&gt; &lt;parts&gt; &lt;unit&gt; &lt;offset&gt; &lt;interval&gt; [skip]
ww sword &lt;id&gt; -p &lt;parts&gt; [-i interval] [-prefix text]
ww next
ww schedule status/enable/disable/run/dryrun/install</code></pre>
<h3>Issues / Sync</h3>
<pre><code>ww issues sync/push/pull/status/enable/disable/install/custom</code></pre>
<h3>Browser and Build</h3>
<pre><code>ww browser [--port N] [--no-open] [stop|status]
ww compile-heuristics [--verbose] [--digest]
ww remove &lt;profile&gt; [--keep|--all|--archive-all|--delete-all|--dry-run]</code></pre>
<h3>Shell Functions (after profile activation)</h3>
<table>
<tr><td>p-&lt;name&gt;</td><td>Activate a profile</td></tr>
<tr><td>task [args]</td><td>TaskWarrior (profile-isolated)</td></tr>
<tr><td>timew [args]</td><td>TimeWarrior (profile-isolated)</td></tr>
<tr><td>j [journal] "entry"</td><td>Write to journal</td></tr>
<tr><td>l [args]</td><td>Hledger (profile-isolated)</td></tr>
<tr><td>i [args]</td><td>Issue sync</td></tr>
<tr><td>q [args]</td><td>Questions service</td></tr>
<tr><td>list [args]</td><td>List management</td></tr>
<tr><td>search [args]</td><td>Cross-profile search</td></tr>
</table>
<h3>Standalone (no ww prefix)</h3>
<pre><code>extensions taskwarrior list
models / groups / journals / ledgers
find / services / tasks / times</code></pre>` },

    { id: 'arch', group: 'reference', label: '⊕ Architecture', content: `
<h2>Architecture</h2>
<h3>How It Fits Together</h3>
<pre><code>p-work
  → shell-integration.sh sets TASKRC, TASKDATA, TIMEWARRIORDB
  → all tools redirect to profiles/work/ data

task add "Ship API" due:friday
  → TaskWarrior writes to profiles/work/.task/
  → on-modify hook starts TimeWarrior tracking

ww browser
  → Python3 HTTP server on localhost:7777
  → reads profile data via same env vars
  → SSE broadcasts mutations to all clients

CMD: "add task review and start tracking"
  → HeuristicEngine matches 627 rules
  → splits on "and"
  → executes: task add review + timew start review</code></pre>
<h3>Directory Structure</h3>
<table>
<tr><td>bin/ww</td><td>CLI dispatcher — all commands route here (700+ lines)</td></tr>
<tr><td>lib/</td><td>24 core bash libraries (sourced, not executed)</td></tr>
<tr><td>services/</td><td>25+ service categories (executables discovered by ww)</td></tr>
<tr><td>weapons/</td><td>gun/, sword/ — task manipulation tools</td></tr>
<tr><td>config/</td><td>ai.yaml, models.yaml, ctrl.yaml, groups.yaml, shortcuts.yaml</td></tr>
<tr><td>profiles/</td><td>User workspaces (created at runtime, gitignored)</td></tr>
<tr><td>docs/</td><td>User-facing documentation (guides/, search-guides/)</td></tr>
<tr><td>tests/</td><td>BATS test suites</td></tr>
</table>
<h3>Profile Isolation</h3>
<p>Each profile is a self-contained directory. Tools redirect via env vars, not symlinks. Switching is instant. Backup = <code>tar</code> the directory. Restore = <code>untar</code> and activate.</p>
<h3>Security Model</h3>
<p>Browser server: <code>ALLOWED_SUBCOMMANDS</code> frozenset validates every POST /cmd. No <code>sh -c</code>, no eval. First token must be a known ww subcommand.</p>
<h3>Heuristic Engine</h3>
<p>627 compiled regex rules with action templates and confidence scores. Compound commands split on conjunctions. Falls through to AI (if configured) when no match above 0.8.</p>
<h3>Sync Engine</h3>
<p>10 files in <code>lib/</code> implement two-way GitHub sync: change detection, field mapping, conflict resolution (last-write-wins), annotation↔comment sync, label encoding.</p>` },
  ];

  let _helpKeyHandler = null;

  function openHelpPanel(topicId) {
    const overlay = document.getElementById('ww-help-overlay');
    if (!overlay) return;
    overlay.classList.remove('hidden');
    _renderHelpNav(topicId || 'overview');
    if (_helpKeyHandler) document.removeEventListener('keydown', _helpKeyHandler);
    _helpKeyHandler = (e) => { if (e.key === 'Escape') closeHelpPanel(); };
    document.addEventListener('keydown', _helpKeyHandler);
  }

  function closeHelpPanel() {
    const overlay = document.getElementById('ww-help-overlay');
    if (!overlay) return;
    overlay.classList.add('hidden');
    if (_helpKeyHandler) { document.removeEventListener('keydown', _helpKeyHandler); _helpKeyHandler = null; }
  }

  function _renderHelpNav(activeId) {
    const nav = document.getElementById('ww-help-nav');
    const content = document.getElementById('ww-help-content');
    if (!nav || !content) return;
    const groups = [
      { key: 'intro', label: 'intro' },
      { key: 'functions', label: 'functions' },
      { key: 'services', label: 'services' },
      { key: 'reference', label: 'reference' },
    ];
    let html = '';
    groups.forEach(g => {
      const topics = WW_HELP_TOPICS.filter(t => t.group === g.key);
      if (!topics.length) return;
      html += `<div class="ww-help-nav-sep">${g.label}</div>`;
      topics.forEach(t => {
        html += `<button class="ww-help-nav-item${t.id === activeId ? ' wh-active' : ''}" data-topic="${t.id}">${t.label}</button>`;
      });
    });
    nav.innerHTML = html;
    nav.querySelectorAll('.ww-help-nav-item').forEach(btn => {
      btn.addEventListener('click', () => {
        nav.querySelectorAll('.ww-help-nav-item').forEach(b => b.classList.remove('wh-active'));
        btn.classList.add('wh-active');
        const topic = WW_HELP_TOPICS.find(t => t.id === btn.dataset.topic);
        if (topic) { content.innerHTML = topic.content; content.scrollTop = 0; }
      });
    });
    const activeTopic = WW_HELP_TOPICS.find(t => t.id === activeId);
    if (activeTopic) content.innerHTML = activeTopic.content;
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

    document.querySelector('.wordmark-ww')?.addEventListener('click', () => openHelpPanel('overview'));
    document.getElementById('btn-ww-help-close')?.addEventListener('click', closeHelpPanel);
    document.getElementById('ww-help-overlay')?.addEventListener('click', (e) => {
      if (e.target === document.getElementById('ww-help-overlay')) closeHelpPanel();
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
    document.querySelector('.community-footer-btn')?.addEventListener('click', (e) => {
      switchSection(e.currentTarget.dataset.section);
    });
    document.getElementById('btn-group-toggle')?.addEventListener('click', () => {
      taskGroupMode = !taskGroupMode;
      localStorage.setItem('ww-task-group-mode', taskGroupMode ? 'grouped' : 'flat');
      renderTasks(cachedTasks);
    });
    document.getElementById('btn-ann-toggle')?.addEventListener('click', () => {
      taskAnnVisible = !taskAnnVisible;
      localStorage.setItem('ww-task-ann-visible', taskAnnVisible ? 'true' : 'false');
      document.getElementById('task-list')?.classList.toggle('task-anns-hidden', !taskAnnVisible);
      document.getElementById('btn-ann-toggle')?.classList.toggle('active', taskAnnVisible);
    });
    document.getElementById('task-list')?.classList.toggle('task-anns-hidden', !taskAnnVisible);
    document.getElementById('btn-ann-toggle')?.classList.toggle('active', taskAnnVisible);

    document.getElementById('btn-show-done-tasks')?.addEventListener('click', async () => {
      taskShowDone = !taskShowDone;
      const btn = document.getElementById('btn-show-done-tasks');
      btn?.classList.toggle('active', taskShowDone);
      const liveList = document.getElementById('task-list');
      const doneList = document.getElementById('task-done-list');
      if (taskShowDone) {
        liveList?.classList.add('hidden');
        doneList?.classList.remove('hidden');
        await loadDoneTasks();
      } else {
        liveList?.classList.remove('hidden');
        if (doneList) { doneList.classList.add('hidden'); doneList.innerHTML = ''; }
      }
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
    const cfBtn = document.querySelector('.community-footer-btn');
    if (cfBtn) cfBtn.classList.toggle('active', name === 'community');
    // CMD/CTRL/weapon button active states
    document.querySelectorAll('.cmd-ctrl-btn').forEach(b => b.classList.toggle('active', b.dataset.section === name));
    document.getElementById('btn-weapon-gun')?.classList.toggle('active', name === 'gun');
    document.getElementById('btn-weapon-sword')?.classList.toggle('active', name === 'sword');
    const titleMap = {
      tasks:'Tasks', time:'Times', journal:'Journals', ledger:'Ledgers', lists:'Lists',
      next:'Next', schedule:'Schedule', gun:'Gun', cmd:'CMD', ctrl:'CTRL',
      sync:'Sync', groups:'Groups', models:'Models', network:'Network',
      export:'Export', questions:'Questions', saves:'Saves',
      profile:'Profile', warrior:'Warrior', projects:'Projects', sword:'Sword',
      community:'Communities', warlock:'Warlock', tags:'Tags'
    };
    sectionTitle.textContent = titleMap[name] || name;
    // header-resource-slot visibility is handled by refreshResourceSelectors
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
    t: 'tasks',   T: 'time',    j: 'journal', l: 'ledger', L: 'lists',
    n: 'next',    s: 'schedule',c: 'cmd',     C: 'ctrl',
    S: 'sync',    G: 'groups',  m: 'models',  N: 'network',
    e: 'export',  q: 'questions',p: 'profile',w: 'warrior',
    u: 'gun',     x: 'sword',   o: 'community', W: 'warlock',
  };

  // Compound commands that enter context mode (next Enter appends free-form args)
  const TERM_CONTEXT_CMDS = {
    'task add': 'task add',    't add': 'task add',
    'journal add': 'journal add', 'j add': 'journal add',
    'journal entry': 'journal add', 'j entry': 'journal add',
    'ledger add': 'ledger add', 'l add': 'ledger add',
    'time track': 'time track', 'timew track': 'time track',
  };

  // Single-token commands that navigate to a section (no execution)
  const TERM_SECTION_NAV = {
    'tasks': 'tasks', 'task': 'tasks',
    'time': 'time',   'timew': 'time',
    'journal': 'journal', 'j': 'journal',
    'ledger': 'ledger',   'l': 'ledger',
    'lists': 'lists',
    'next': 'next',        'schedule': 'schedule', 'sync': 'sync',
    'groups': 'groups',    'models': 'models',     'network': 'network',
    'export': 'export',    'questions': 'questions', 'saves': 'saves',
    'projects': 'projects','cmd': 'cmd',            'ctrl': 'ctrl',
    'warrior': 'warrior',  'community': 'community', 'warlock': 'warlock',
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
          <span class="shortcut-key">g L</span><span>Lists</span>
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
          <span class="shortcut-key">g o</span><span>Community</span>
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
        await loadTaskMeta();
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
        else if (type === 'lists' && activeSection === 'lists') loadLists();
        else if (type === 'community' && activeSection === 'community') loadCommunity();
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
  let journalActiveFilter = null; // null | 'annotated' | 'rejournaled' | 'all-comments'
  let journalShowArchived = false; // defaults off — don't persist across sessions
  let journalMdRender = localStorage.getItem('journal_md_render') === '1';
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

  function setTermContext(cmd) {
    termContextCmd = cmd;
    const ctxEl = document.getElementById('term-context');
    if (cmd) {
      if (ctxEl) { ctxEl.textContent = cmd; ctxEl.classList.remove('hidden'); }
      termPrompt.textContent = '  ›  ';
      termPrompt.className = 'prompt-context';
      hintsBar.textContent = `${cmd} › type args — Escape to cancel`;
    } else {
      if (ctxEl) { ctxEl.textContent = ''; ctxEl.classList.add('hidden'); }
      termPrompt.textContent = '❯ ';
      termPrompt.className = 'prompt-exec';
      termInput.dispatchEvent(new Event('input')); // restore hints
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
        if (termContextCmd) { setTermContext(null); termInput.value = ''; return; }
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
        if (!val && !termContextCmd) return;
        if (termMode === 'execute') {
          // Context mode: prepend primed command to args
          if (termContextCmd) {
            const fullCmd = val ? `${termContextCmd} ${val}` : termContextCmd;
            termInput.value = '';
            setTermContext(null);
            await execCmd(fullCmd);
            return;
          }
          // Single-token section nav
          const navTarget = TERM_SECTION_NAV[val.toLowerCase()];
          if (navTarget) {
            termInput.value = '';
            await switchSection(navTarget);
            termInput.dispatchEvent(new Event('input'));
            return;
          }
          // Compound context command → enter context mode
          const ctxCmd = TERM_CONTEXT_CMDS[val.toLowerCase()];
          if (ctxCmd) {
            termInput.value = '';
            setTermContext(ctxCmd);
            return;
          }
          termInput.value = '';
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
      if (termContextCmd) {
        hintsBar.textContent = `${termContextCmd} › type args — Escape to cancel`;
        return;
      }
      if (termMode === 'search') {
        runGlobalSearch(val);
        return;
      }
      if (termMode === 'filter') {
        const rows = document.querySelectorAll(
          `#section-${activeSection} .task-row, #section-${activeSection} .journal-entry, #section-${activeSection} .ledger-row, #section-${activeSection} .list-row`
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
  let taskMetaCache = { projects: [], tags: [] };

  async function loadProfileResources() {
    try {
      const res = await fetch('/data/profile-resources', { cache: 'no-store' });
      const data = await res.json();
      if (data.ok) profileResources = data;
    } catch (_) {}
  }

  async function loadTaskMeta() {
    try {
      const res = await fetch('/data/task-meta');
      const data = await res.json();
      if (data.ok) {
        taskMetaCache = { projects: data.projects || [], tags: data.tags || [] };
        populateTaskMetaDropdowns();
      }
    } catch (_) {}
  }

  function populateTaskMetaDropdowns() {
    const { projects, tags } = taskMetaCache;
    const projOptions = projects.map(p => `<option value="${esc(p)}">`).join('');
    const tagOptions  = tags.map(t => `<option value="${esc(t)}">`).join('');
    // Journal project datalist
    const jProjDl = document.getElementById('journal-projects-dl');
    if (jProjDl) jProjDl.innerHTML = projOptions;
    // Journal tags datalist
    const jTagsDl = document.getElementById('journal-tags-list');
    if (jTagsDl) jTagsDl.innerHTML = tagOptions;
    // Community project/tag datalists
    const cProjDl = document.getElementById('comm-projects-dl');
    if (cProjDl) cProjDl.innerHTML = projOptions;
    const cTagsDl = document.getElementById('comm-tags-dl');
    if (cTagsDl) cTagsDl.innerHTML = tagOptions;
  }

  function renderResourceSelector(containerId, kind, activeKey, onSelect) {
    const container = document.getElementById(containerId);
    if (!container) return;
    container.innerHTML = '';
    const wrap = document.createElement('span');
    wrap.className = 'resource-bar-inner';

    let sel = null;
    if (profileResources) {
      const options = profileResources.resources[kind] || {};
      const names = Object.keys(options);
      if (names.length > 0) {
        sel = document.createElement('select');
        sel.className = 'resource-select';
        names.forEach(n => {
          const opt = document.createElement('option');
          opt.value = n;
          opt.textContent = n;
          if (n === activeKey) opt.selected = true;
          sel.appendChild(opt);
        });
        if (names.length === 1) sel.disabled = true;
        sel.addEventListener('change', async () => {
          const chosen = sel.value;
          const r = await fetch('/resource', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ kind, name: chosen }),
          });
          const d = await r.json().catch(() => ({}));
          if (d.ok && profileResources?.active) {
            const keyMap = { journals: 'journal', ledgers: 'ledger', tasklists: 'tasklist', timew: 'timew', lists: 'list' };
            const ak = keyMap[kind];
            if (ak) profileResources.active[ak] = chosen;
          }
          await onSelect(chosen);
        });
        wrap.appendChild(sel);
      }
    }

    // "+" button always shown
    const addBtn = document.createElement('button');
    addBtn.className = 'resource-add-btn';
    addBtn.textContent = '+';
    addBtn.title = 'Create new ' + kind.replace(/s$/, '');
    addBtn.addEventListener('click', () => showResourceCreateForm(container, kind, sel, onSelect));
    wrap.appendChild(addBtn);

    container.appendChild(wrap);
    container.classList.remove('hidden');
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
    const slot = document.getElementById('header-resource-slot');
    const RESOURCE_SECTIONS = new Set(['tasks','time','journal','ledger','lists']);
    if (slot) slot.classList.toggle('hidden', !RESOURCE_SECTIONS.has(section));
    if (!profileResources) return;
    const active = profileResources.active;
    if (section === 'tasks') {
      renderResourceSelector('header-resource-slot', 'tasklists', active.tasklist, () => loadTasks());
    } else if (section === 'time') {
      renderResourceSelector('header-resource-slot', 'timew', active.timew, () => loadTime());
    } else if (section === 'journal') {
      renderResourceSelector('header-resource-slot', 'journals', active.journal, () => loadJournal());
    } else if (section === 'ledger') {
      renderResourceSelector('header-resource-slot', 'ledgers', active.ledger, () => loadLedger());
    } else if (section === 'lists') {
      renderResourceSelector('header-resource-slot', 'lists', active.list || 'default', () => loadLists());
    }
  }

  // ── Data fetching ──────────────────────────────────────────────────────────

  async function loadSection(name) {
    if (name === 'tasks') await loadTasks();
    else if (name === 'time') await loadTime();
    else if (name === 'journal') await loadJournal();
    else if (name === 'ledger') await loadLedger();
    else if (name === 'lists') await loadLists();
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
    else if (name === 'community') { updateContextBar('community', null); populateTaskMetaDropdowns(); populateCommJournalMiniSel(); await loadCommunity(); }
    else if (name === 'saves') updateContextBar('saves', null);
    else if (name === 'projects') { updateContextBar('projects', null); await loadProjects(); }
    else if (name === 'ctrl') { await refreshCtrlState(); updateContextBar('ctrl', null); }
    else if (name === 'profile') { updateContextBar('profile', null); await loadProfileScreen(); }
    else if (name === 'warrior') { updateContextBar('warrior', null); await loadWarrior(); }
    else if (name === 'warlock') { updateContextBar('warlock', null); await loadWarlock(); }
    else if (name === 'tags') { updateContextBar('tags', null); await loadTags(); }
    else updateContextBar(name, null);
    await refreshResourceSelectors(name);
  }

  const nextSkipped = new Set(); // session-scoped skip list, cleared on section switch

  async function loadNext() {
    const card = document.getElementById('next-card');
    try {
      const skipParam = nextSkipped.size ? `?skip=${[...nextSkipped].join(',')}` : '';
      const res = await fetch(`/data/next${skipParam}`);
      const data = await res.json();
      if (!data.ok || !data.task) {
        card.innerHTML = `<div class="empty-state">No next task${nextSkipped.size ? ` — ${nextSkipped.size} skipped` : ''}</div>`;
        if (nextSkipped.size) {
          const resetBtn = document.createElement('button');
          resetBtn.className = 'btn-inline-alt';
          resetBtn.style.cssText = 'margin-top:8px;display:block';
          resetBtn.textContent = 'reset skips';
          resetBtn.addEventListener('click', () => { nextSkipped.clear(); loadNext(); });
          card.querySelector('.empty-state')?.after(resetBtn);
        }
        updateContextBar('next', null);
        return;
      }
      const t = data.task;
      updateContextBar('next', t);
      const urg = (t.urgency || 0).toFixed(1);
      const project = t.project ? `<span class="badge-project" onclick="event.stopPropagation();window.__navigateProject('${t.project}')" style="cursor:pointer">${t.project}</span>` : '';
      const tags = (t.tags || []).map(g => `<span class="tag">${g}</span>`).join('');
      const due = t.due ? renderDue(t.due) : '';
      const skipNote = nextSkipped.size ? `<span class="next-skip-note">${nextSkipped.size} skipped</span>` : '';
      card.innerHTML = `<div class="next-task-card">
        <div class="next-label">next task · urgency ${urg}${skipNote ? ' · ' + skipNote : ''}</div>
        <div class="next-desc">${t.description}</div>
        <div class="next-meta">${project}${tags}${due}</div>
        <div class="next-actions">
          <button class="act-btn act-start" data-id="${t.id}">▶ start</button>
          <button class="act-btn act-done" data-id="${t.id}">✓ done</button>
          <button class="act-btn" id="btn-next-skip" data-id="${t.id}">skip</button>
          ${nextSkipped.size ? `<button class="act-btn" id="btn-next-reset">reset skips</button>` : ''}
        </div>
      </div>`;
      card.querySelector('.act-start')?.addEventListener('click', async () => {
        nextSkipped.clear();
        await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
          body: JSON.stringify({ action: 'start', id: t.id }) });
        await loadNext();
      });
      card.querySelector('.act-done')?.addEventListener('click', async () => {
        nextSkipped.clear();
        await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
          body: JSON.stringify({ action: 'done', id: t.id }) });
        await loadNext();
      });
      card.querySelector('#btn-next-skip')?.addEventListener('click', () => {
        nextSkipped.add(t.id);
        loadNext();
      });
      card.querySelector('#btn-next-reset')?.addEventListener('click', () => {
        nextSkipped.clear();
        loadNext();
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

  async function loadDoneTasks() {
    const list = document.getElementById('task-done-list');
    if (!list) return;
    list.innerHTML = '<div class="skeleton-msg">Loading completed tasks…</div>';
    try {
      const res = await fetch('/data/tasks?done=1');
      const data = await res.json();
      if (!data.ok) {
        list.innerHTML = `<div class="empty-state">${data.error || 'failed'}</div>`;
        return;
      }
      const tasks = data.tasks || [];
      if (!tasks.length) {
        list.innerHTML = '<div class="empty-state">No completed tasks</div>';
        return;
      }
      list.innerHTML = `<div class="done-tasks-header">Completed — ${tasks.length} task${tasks.length !== 1 ? 's' : ''}</div>` +
        tasks.map(t => {
          const endRaw = t.end ? t.end.replace(/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2}).*/, '$1-$2-$3 $4:$5') : '';
          const proj = t.project ? `<span class="badge-project" onclick="event.stopPropagation();window.__navigateProject('${esc(t.project)}')" style="cursor:pointer">${esc(t.project)}</span>` : '';
          const tags = (t.tags || []).map(g => `<span class="tag">${esc(g)}</span>`).join('');
          const pri = t.priority ? `<span class="pri-dot pri-${t.priority.toLowerCase()}">${t.priority}</span>` : '';
          const uuid = t.uuid || '';
          return `<div class="done-task-row" data-uuid="${esc(uuid)}">
            <div class="done-task-main">
              <span class="done-task-check">✓</span>
              <span class="done-task-desc">${esc(t.description || '')}</span>
            </div>
            <div class="done-task-meta">
              ${proj}${tags}${pri}
              ${endRaw ? `<span class="done-task-date">completed ${esc(endRaw)}</span>` : ''}
              <button class="done-task-revive" data-uuid="${esc(uuid)}" title="Revive this task">↩ revive</button>
            </div>
          </div>`;
        }).join('');

      list.querySelectorAll('.done-task-revive').forEach(btn => {
        btn.addEventListener('click', async () => {
          const uuid = btn.dataset.uuid;
          if (!uuid) return;
          btn.disabled = true;
          btn.textContent = '…';
          try {
            const r = await fetch('/action', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ action: 'task_modify', id: uuid, args: { status: 'pending' } }),
            });
            const d = await r.json();
            if (d.ok) {
              toast('Task revived');
              btn.closest('.done-task-row')?.remove();
              const header = list.querySelector('.done-tasks-header');
              const remaining = list.querySelectorAll('.done-task-row').length;
              if (header) header.textContent = `Completed — ${remaining} task${remaining !== 1 ? 's' : ''}`;
              if (!remaining) list.innerHTML = '<div class="empty-state">No completed tasks</div>';
              if (cachedTasks !== undefined) await loadTasks();
            } else {
              toast(d.output || d.error || 'revive failed', 'error');
              btn.disabled = false;
              btn.textContent = '↩ revive';
            }
          } catch (e) {
            toast(e.message, 'error');
            btn.disabled = false;
            btn.textContent = '↩ revive';
          }
        });
      });
    } catch (e) {
      list.innerHTML = `<div class="empty-state">Error: ${esc(e.message)}</div>`;
    }
  }

  // Returns HTML string for a single task row (used in both flat + grouped modes).
  // hideProject=true omits the project badge (grouped mode shows it in the header).
  function taskRowHTML(t, hideProject = false) {
    const urg = (t.urgency || 0).toFixed(1);
    const urgClass = t.urgency > 15 ? 'urg-high' : t.urgency > 10 ? 'urg-med' : t.urgency > 5 ? 'urg-low' : 'urg-none';
    const project = (!hideProject && t.project) ? `<span class="badge-project" onclick="event.stopPropagation();window.__navigateProject('${t.project}')" style="cursor:pointer">${t.project}</span>` : '';
    const tags = (t.tags || []).map(g => `<span class="tag">${g}</span>`).join('');
    const pri = t.priority ? `<span class="pri-dot pri-${t.priority.toLowerCase()}">${t.priority}</span>` : '';
    const due = t.due ? renderDue(t.due) : '';
    const sched = (!t.due && t.scheduled) ? renderScheduled(t.scheduled) : '';
    const depCount = (t.depends || []).length;
    const blocksCount = cachedTasks.filter(x => (x.depends || []).includes(t.uuid)).length;
    const depBadge = depCount ? `<span class="dep-badge dep-blocked" title="Blocked by ${depCount} task${depCount>1?'s':''}">⊸${depCount}</span>` : '';
    const blocksBadge = blocksCount ? `<span class="dep-badge dep-blocking" title="Blocking ${blocksCount} task${blocksCount>1?'s':''}">→${blocksCount}</span>` : '';
    const isActive = t.status === 'active';
    const activeClass = isActive ? ' task-active' : '';
    const startStop = isActive
      ? `<button class="act-btn act-stop" data-id="${t.id}"><span class="btn-icon">■</span><span class="btn-word">stop</span></button>`
      : `<button class="act-btn act-start" data-id="${t.id}"><span class="btn-icon">▶</span><span class="btn-word">start</span></button>`;
    const checked = bulkSelected.has(t.id) ? ' checked' : '';
    const anns = (t.annotations || []);
    const annHTML = anns.length
      ? anns.map(a => {
          const dateStr = (a.entry || '').replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3');
          return `<div class="task-row-ann">↳ <span class="task-row-ann-date">${dateStr}</span> ${esc(a.description)}</div>`;
        }).join('')
      : '';
    return `<div class="task-row${activeClass}" data-id="${t.id}" data-uuid="${esc(t.uuid||'')}" data-desc="${(t.description||'').replace(/"/g,'&quot;')}" data-project="${t.project || ''}" data-tags="${(t.tags || []).join(',')}" data-priority="${t.priority || ''}">
      <input type="checkbox" class="task-cb" data-id="${t.id}"${checked} />
      <span class="urg ${urgClass}">${urg}</span>
      ${project}
      <span class="task-desc">${t.description}</span>
      ${tags}${due}${sched}${pri}${depBadge}${blocksBadge}
      <span class="task-row-quick">
        <button class="task-quick-btn task-quick-annotate" data-id="${t.id}" title="Add annotation">+ annotate</button>
        <button class="task-quick-btn task-quick-journal" data-id="${t.id}" title="New journal entry">→ journal</button>
        <button class="task-quick-btn task-quick-dep" data-id="${t.id}" data-uuid="${esc(t.uuid||'')}" title="Add dependency">+ dep</button>
      </span>
      <span class="task-actions">
        ${startStop}
        <button class="act-btn act-done" data-id="${t.id}"><span class="btn-icon">✓</span><span class="btn-word">done</span></button>
        <button class="act-btn act-to-community" data-id="${t.id}"><span class="btn-icon">◎</span><span class="btn-word">comm</span></button>
        <button class="act-btn act-archive" data-id="${t.id}" data-desc="${esc(t.description||'')}" title="Archive (delete) this task">⊗</button>
      </span>
    </div>
    ${annHTML}
    <div class="task-inline-detail hidden" id="tid-${t.id}"></div>`;
  }

  function renderTasks(tasks) {
    const list = document.getElementById('task-list');
    // Preserve open inline detail across re-renders (SSE updates, action results)
    const openDetail = list.querySelector('.task-inline-detail:not(.hidden)');
    const openDetailId = openDetail ? parseInt(openDetail.id.replace('tid-', '')) : null;
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

    list.querySelectorAll('.act-to-community').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const tid = btn.dataset.id;
        const detailDiv = document.getElementById('tid-' + tid);
        if (!detailDiv) return;
        // Toggle
        if (!detailDiv.classList.contains('hidden') && detailDiv.dataset.mode === 'community') {
          detailDiv.classList.add('hidden'); detailDiv.innerHTML = ''; return;
        }
        list.querySelectorAll('.task-inline-detail').forEach(d => { d.classList.add('hidden'); d.innerHTML = ''; });
        detailDiv.dataset.mode = 'community';
        detailDiv.classList.remove('hidden');
        detailDiv.innerHTML = '<div class="skeleton-msg" style="font-size:12px">Loading collections…</div>';
        let names = [];
        try {
          const lr = await fetch('/data/community/list');
          const ld = await lr.json();
          if (ld.ok) names = (ld.communities || []).map(c => c.name);
        } catch (_) {}
        if (!names.length) {
          detailDiv.innerHTML = '<div class="empty-state" style="font-size:12px">No collections yet. Open <strong>Community</strong> to create one.</div>';
          return;
        }
        const projOpts = taskMetaCache.projects.map(p => `<option value="${esc(p)}">`).join('');
        const tagOpts  = taskMetaCache.tags.map(t => `<option value="${esc(t)}">`).join('');
        detailDiv.innerHTML = `
          <div class="task-comm-panel">
            <label class="task-comm-label">collection</label>
            <select class="resource-select task-comm-sel">${names.map(n=>`<option value="${esc(n)}">${esc(n)}</option>`).join('')}</select>
            <label class="task-comm-label">project</label>
            <input type="text" class="task-comm-input task-comm-proj" placeholder="project" autocomplete="off" list="task-comm-proj-dl" />
            <datalist id="task-comm-proj-dl">${projOpts}</datalist>
            <label class="task-comm-label">tags</label>
            <input type="text" class="task-comm-input task-comm-tags" placeholder="tags" autocomplete="off" list="task-comm-tags-dl" />
            <datalist id="task-comm-tags-dl">${tagOpts}</datalist>
            <label class="task-comm-label">priority</label>
            <select class="resource-select task-comm-pri"><option value="">—</option><option>H</option><option>M</option><option>L</option></select>
            <button type="button" class="btn-inline-submit task-comm-send">→ community</button>
          </div>`;
        detailDiv.querySelector('.task-comm-send').addEventListener('click', async () => {
          const comm = detailDiv.querySelector('.task-comm-sel').value;
          if (!comm) { toast('pick a collection', 'error'); return; }
          const args = {
            community: comm, kind: 'task', task_id: tid,
            community_project: detailDiv.querySelector('.task-comm-proj').value.trim() || undefined,
            community_tags:    detailDiv.querySelector('.task-comm-tags').value.trim() || undefined,
            community_priority: detailDiv.querySelector('.task-comm-pri').value.trim() || undefined,
          };
          const r = await fetch('/action', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'community_add', args }),
          });
          const d = await r.json();
          if (d.ok) { toast('task added to community'); detailDiv.classList.add('hidden'); detailDiv.innerHTML = ''; }
          else toast(d.error || 'add failed', 'error');
        });
      });
    });

    // Archive (delete) task
    list.querySelectorAll('.act-archive').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const id = parseInt(btn.dataset.id);
        const desc = btn.dataset.desc || `#${id}`;
        confirmAction('archive task', `Delete task <strong>#${id}</strong>: "${esc(desc)}"? This cannot be undone.`, async () => {
          try {
            const r = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
              body: JSON.stringify({ action: 'task_delete', id }) });
            const d = await r.json();
            if (d.ok) { toast('task archived'); renderTasks(d.tasks || cachedTasks); }
            else toast(d.error || 'archive failed', 'error');
          } catch (err) { toast('archive failed', 'error'); }
        });
      });
    });

    // Quick hover actions: annotate and → journal
    list.querySelectorAll('.task-quick-annotate').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const tid = btn.dataset.id;
        const row = btn.closest('.task-row');
        // Remove any existing quick input
        const existing = row.parentNode.querySelector(`.task-quick-input[data-id="${tid}"]`);
        if (existing) { existing.remove(); return; }
        const wrap = document.createElement('div');
        wrap.className = 'task-quick-input';
        wrap.dataset.id = tid;
        wrap.innerHTML = `<input class="task-quick-input-field" placeholder="annotation…" /><button class="btn-inline-submit task-quick-input-save">add</button><button class="btn-inline-alt task-quick-input-cancel">✕</button>`;
        row.after(wrap);
        const inp = wrap.querySelector('.task-quick-input-field');
        inp.focus();
        const submit = async () => {
          const note = inp.value.trim();
          if (!note) { wrap.remove(); return; }
          const r = await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'annotate', id: parseInt(tid), args: { note } }) });
          const d = await r.json();
          if (d.ok) { toast('✓ annotation added'); renderTasks(d.tasks || cachedTasks); }
          else { toast(d.error || 'failed', 'error'); wrap.remove(); }
        };
        inp.addEventListener('keydown', (e2) => { if (e2.key === 'Enter') submit(); if (e2.key === 'Escape') wrap.remove(); });
        wrap.querySelector('.task-quick-input-save').addEventListener('click', submit);
        wrap.querySelector('.task-quick-input-cancel').addEventListener('click', () => wrap.remove());
      });
    });

    list.querySelectorAll('.task-quick-journal').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const row = btn.closest('.task-row');
        const uuid = row?.dataset.uuid || '';
        const desc = row?.dataset.desc || btn.dataset.desc || '';
        const proj = row?.dataset.project || '';
        const tags = (row?.dataset.tags || '').split(',').filter(Boolean);
        const pri  = row?.dataset.priority || '';
        const meta = [
          proj ? `project:${proj}` : '',
          pri  ? `priority:${pri}` : '',
          ...tags.map(tg => `tag:${tg}`),
        ].filter(Boolean).join(' ');
        const entry = `[task-entry:${uuid}|${desc}|${meta}|]`;
        btn.disabled = true; btn.textContent = '…';
        const r = await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'journal_add', args: { entry } }) });
        const d = await r.json();
        if (d.ok) { toast('✓ journal entry created'); btn.disabled = false; btn.textContent = '→ journal'; }
        else { toast(d.error || 'failed', 'error'); btn.disabled = false; btn.textContent = '→ journal'; }
      });
    });

    // Quick dep pop-down
    list.querySelectorAll('.task-quick-dep').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const tid = parseInt(btn.dataset.id);
        const tuuid = btn.dataset.uuid;
        const row = btn.closest('.task-row');
        const existing = row.parentNode.querySelector(`.task-quick-dep-row[data-id="${tid}"]`);
        if (existing) { existing.remove(); return; }
        const wrap = document.createElement('div');
        wrap.className = 'task-quick-dep-row task-quick-input';
        wrap.dataset.id = tid;
        const opts = cachedTasks.filter(x => x.id !== tid)
          .map(x => `<option value="${x.id}">${esc(x.description.slice(0,50))}${x.project ? ' ['+x.project+']' : ''}</option>`).join('');
        wrap.innerHTML = `
          <input class="task-quick-dep-input" placeholder="task ID or description…" list="dep-qlist-${tid}" autocomplete="off" />
          <select class="task-quick-dep-select">${opts}</select>
          <div class="task-quick-dep-preview"></div>
          <button class="btn-inline-submit dep-q-blocked-by" title="This task is blocked by selected — selected must finish first">⊸ blocked by</button>
          <button class="btn-inline-alt dep-q-blocks" title="This task blocks selected — this must finish first">→ blocks</button>
          <button class="btn-inline-alt task-quick-input-cancel">✕</button>
          <datalist id="dep-qlist-${tid}">${cachedTasks.filter(x => x.id !== tid).map(x => `<option value="${x.id}" label="#${x.id} ${x.description.slice(0,40)}">`).join('')}</datalist>`;
        row.after(wrap);

        const inp = wrap.querySelector('.task-quick-dep-input');
        const sel = wrap.querySelector('.task-quick-dep-select');
        const preview = wrap.querySelector('.task-quick-dep-preview');

        const resolveDepQ = () => {
          const typed = inp.value.trim();
          // If user typed something, resolve by text/ID; otherwise use the select value
          if (typed) {
            const numId = /^\d+$/.test(typed) ? parseInt(typed, 10) : null;
            return numId
              ? (cachedTasks.find(x => x.id === numId) || null)
              : (cachedTasks.find(x => x.uuid === typed || x.description.toLowerCase().includes(typed.toLowerCase())) || null);
          }
          // Fallback: use select
          const selId = parseInt(sel.value, 10);
          return isNaN(selId) ? null : (cachedTasks.find(x => x.id === selId) || null);
        };

        const updatePreview = () => {
          const match = resolveDepQ();
          if (match) {
            preview.innerHTML = `<span class="dep-preview-id">#${match.id}</span> <span class="dep-preview-desc">${esc(match.description)}</span>${match.project ? ` <span class="badge-project" style="font-size:10px">${esc(match.project)}</span>` : ''}`;
            preview.style.display = 'flex';
          } else {
            preview.style.display = 'none';
          }
        };

        inp.addEventListener('input', updatePreview);
        sel.addEventListener('change', () => { inp.value = ''; updatePreview(); });
        // Show initial preview from first select option
        updatePreview();
        inp.focus();

        wrap.querySelector('.dep-q-blocked-by').addEventListener('click', async (ev) => {
          ev.stopPropagation(); ev.preventDefault();
          const depTask = resolveDepQ();
          if (!depTask) { toast('select a task first', 'error'); return; }
          try {
            const r = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
              body: JSON.stringify({ action: 'dep_add', id: String(tid), dep_uuid: depTask.uuid }) });
            const d = await r.json();
            if (d.ok) { toast(`#${tid} blocked by #${depTask.id}`); wrap.remove(); await loadTasks(); }
            else toast(`failed: ${d.error || 'unknown error'}`, 'error');
          } catch (e) { toast(`network error: ${e.message}`, 'error'); }
        });

        wrap.querySelector('.dep-q-blocks').addEventListener('click', async (ev) => {
          ev.stopPropagation(); ev.preventDefault();
          const depTask = resolveDepQ();
          if (!depTask) { toast('select a task first', 'error'); return; }
          try {
            const r = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
              body: JSON.stringify({ action: 'dep_add', id: String(depTask.id), dep_uuid: tuuid }) });
            const d = await r.json();
            if (d.ok) { toast(`#${tid} blocks #${depTask.id}`); wrap.remove(); await loadTasks(); }
            else toast(`failed: ${d.error || 'unknown error'}`, 'error');
          } catch (e) { toast(`network error: ${e.message}`, 'error'); }
        });

        wrap.querySelector('.task-quick-input-cancel').addEventListener('click', () => wrap.remove());
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

    // Re-open inline detail that was open before the re-render
    if (openDetailId) {
      const task = cachedTasks.find(t => t.id === openDetailId);
      const detail = document.getElementById('tid-' + openDetailId);
      if (task && detail) expandTaskInline(detail, task);
    }
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
          const proj = t.project ? `<span class="badge-project" onclick="event.stopPropagation();window.__navigateProject('${t.project}')" style="cursor:pointer">${t.project}</span> ` : '';
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

  function renderDepSection(sec, t) {
    if (!sec) return;
    const blockedByUuids = t.depends || [];
    const blockingTasks = cachedTasks.filter(x => (x.depends || []).includes(t.uuid));
    const blockedByTasks = blockedByUuids.map(u => cachedTasks.find(x => x.uuid === u)).filter(Boolean);

    // removerId / removeUuid: the task whose depends list gets modified on remove
    const depRow = (task, removerId, removeUuid) => {
      const rmBtn = removerId
        ? `<button class="dep-rm-btn" data-id="${removerId}" data-uuid="${removeUuid}" title="Remove">×</button>`
        : '';
      return `<div class="dep-task-row">
        <span class="dep-task-id">#${task.id}</span>
        <span class="dep-task-desc" onclick="window.__navigateTask('${task.uuid}')" style="cursor:pointer">${esc(task.description)}</span>
        ${task.project ? `<span class="badge-project" style="font-size:10px;cursor:pointer" onclick="window.__navigateProject('${task.project}')">${task.project}</span>` : ''}
        ${rmBtn}
      </div>`;
    };

    sec.innerHTML = `
      <div class="dep-section-head">dependencies</div>
      ${blockedByTasks.length
        ? `<div class="dep-group-label">⊸ blocked by (must finish first)</div>`
          + blockedByTasks.map(tx => depRow(tx, t.id, tx.uuid)).join('')
        : ''}
      ${blockingTasks.length
        ? `<div class="dep-group-label">→ blocking (waiting on this)</div>`
          + blockingTasks.map(tx => depRow(tx, tx.id, t.uuid)).join('')
        : ''}
      ${!blockedByTasks.length && !blockingTasks.length ? '<div class="dep-empty">no dependencies</div>' : ''}
      <div class="dep-add-row">
        <input type="text" class="dep-add-input" placeholder="task ID or description…" list="dep-task-list-${t.id}" autocomplete="off" />
        <datalist id="dep-task-list-${t.id}">${cachedTasks.filter(x => x.id !== t.id).map(x => `<option value="${x.id}" label="#${x.id} ${x.description.slice(0,40)}">`).join('')}</datalist>
        <div class="dep-input-preview" style="display:none"></div>
        <button class="btn-inline-alt dep-add-blocked-by" title="This task is blocked by the selected task — selected must finish first">⊸ blocked by</button>
        <button class="btn-inline-alt dep-add-blocks" title="This task blocks the selected task — this must finish first">→ blocks</button>
      </div>`;

    // Remove dependency (works for both directions — id owns the depends list)
    sec.querySelectorAll('.dep-rm-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const r = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
          body: JSON.stringify({ action: 'dep_remove', id: btn.dataset.id, dep_uuid: btn.dataset.uuid }) });
        const d = await r.json();
        if (d.ok) { toast('dependency removed'); await loadTasks(); }
        else toast(`failed: ${d.error}`, 'error');
      });
    });

    const addInput = sec.querySelector('.dep-add-input');
    const inputPreview = sec.querySelector('.dep-input-preview');
    const resolveTask = () => {
      const raw = (addInput?.value || '').trim();
      if (!raw) return null;
      const numId = /^\d+$/.test(raw) ? parseInt(raw) : null;
      return numId
        ? cachedTasks.find(x => x.id === numId)
        : cachedTasks.find(x => x.uuid === raw || x.description.toLowerCase().includes(raw.toLowerCase()));
    };

    addInput?.addEventListener('input', () => {
      const match = resolveTask();
      if (match && inputPreview) {
        inputPreview.innerHTML = `<span class="dep-preview-id">#${match.id}</span> <span class="dep-preview-desc">${esc(match.description)}</span>${match.project ? ` <span class="badge-project" style="font-size:10px">${esc(match.project)}</span>` : ''}`;
        inputPreview.style.display = 'flex';
      } else if (inputPreview) {
        inputPreview.style.display = 'none';
      }
    });

    // "blocked by": current task depends on selected (selected must finish first)
    sec.querySelector('.dep-add-blocked-by')?.addEventListener('click', async () => {
      const depTask = resolveTask();
      if (!depTask) { toast('task not found', 'error'); return; }
      const r = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
        body: JSON.stringify({ action: 'dep_add', id: String(t.id), dep_uuid: depTask.uuid }) });
      const d = await r.json();
      if (d.ok) { toast(`#${t.id} now blocked by #${depTask.id}`); addInput.value = ''; await loadTasks(); }
      else toast(`failed: ${d.error}`, 'error');
    });

    // "blocks": selected task depends on current (this must finish first)
    sec.querySelector('.dep-add-blocks')?.addEventListener('click', async () => {
      const depTask = resolveTask();
      if (!depTask) { toast('task not found', 'error'); return; }
      const r = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
        body: JSON.stringify({ action: 'dep_add', id: String(depTask.id), dep_uuid: t.uuid }) });
      const d = await r.json();
      if (d.ok) { toast(`#${t.id} now blocks #${depTask.id}`); addInput.value = ''; await loadTasks(); }
      else toast(`failed: ${d.error}`, 'error');
    });
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
      `<div class="annotation">↳ <span style="color:var(--muted);font-size:11px">${a.entry ? a.entry.replace(/(\d{4})(\d{2})(\d{2})T.*/, '$1-$2-$3') : ''}</span> ${esc(a.description)}<span class="ann-act-row"><button class="btn-ann-act btn-tann-journal" data-body="${esc(a.description)}" data-uuid="${esc(t.uuid||'')}" data-desc="${esc(t.description||'')}" data-project="${esc(t.project||'')}" data-tags="${esc((t.tags||[]).join(','))}" data-priority="${esc(t.priority||'')}" title="Create journal entry">→ journal</button><span class="tann-jsel-slot"></span><button class="btn-ann-act btn-tann-comm" data-body="${esc(a.description)}" data-uuid="${esc(t.uuid||'')}" data-desc="${esc(t.description||'')}" title="Send to community">+ community</button></span></div>`
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
      <div class="task-dep-section" id="dep-section-${t.id}"></div>
    `;
    el.classList.remove('hidden');

    // Render dependencies section
    renderDepSection(el.querySelector(`#dep-section-${t.id}`), t);

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

    // Journal note — writes a structured [task-entry:...] card
    const noteBtn = el.querySelector('.te-note-btn');
    const noteInp = el.querySelector('.te-note-input');
    const doNote = async () => {
      const note = noteInp.value.trim();
      if (!note) return;
      const meta = [
        t.status   ? `status:${t.status}`     : '',
        t.project  ? `project:${t.project}`   : '',
        t.priority ? `priority:${t.priority}` : '',
        ...(t.tags || []).map(tag => `tag:${tag}`),
      ].filter(Boolean).join(' ');
      const entry = `[task-entry:${t.uuid || ''}|${t.description}|${meta}|${note}]`;
      const jSel = el.querySelector('.journal-target-select');
      await sendJournalNote(entry, jSel);
      noteInp.value = '';
      noteInp.placeholder = '✓ added to journal';
      setTimeout(() => { if (noteInp) noteInp.placeholder = 'note to journal…'; }, 2000);
    };
    noteBtn.addEventListener('click', doNote);
    noteInp.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); doNote(); } });

    // Per-annotation: → journal
    el.querySelectorAll('.btn-tann-journal').forEach(btn => {
      btn.addEventListener('click', async () => {
        const note = btn.dataset.body || '';
        const uuid = btn.dataset.uuid || '';
        const desc = btn.dataset.desc || '';
        const proj = btn.dataset.project || '';
        const tags = (btn.dataset.tags || '').split(',').filter(Boolean);
        const pri  = btn.dataset.priority || '';
        const meta = [
          proj ? `project:${proj}` : '',
          pri  ? `priority:${pri}` : '',
          ...tags.map(tg => `tag:${tg}`),
        ].filter(Boolean).join(' ');
        const entry = `[task-entry:${uuid}|${desc}|${meta}|${note}]`;
        btn.disabled = true; btn.textContent = '…';
        const r = await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'journal_add', args: { entry } }) });
        const d = await r.json();
        if (d.ok) { toast('✓ entry created'); btn.textContent = '✓'; }
        else { btn.disabled = false; btn.textContent = '→ journal'; toast(d.error || 'failed', 'error'); }
      });
    });

    // Per-annotation: + community — write annotation to journal then add that entry to a community
    el.querySelectorAll('.btn-tann-comm').forEach(btn => {
      btn.addEventListener('click', async () => {
        const body = btn.dataset.body;
        if (!body) return;
        btn.disabled = true; btn.textContent = '…';
        let names = [];
        try {
          const lr = await fetch('/data/community/list');
          const list = await lr.json();
          if (list.ok && Array.isArray(list.communities)) names = list.communities.map(c => c.name);
        } catch (_) {}
        if (!names.length) { btn.disabled = false; btn.textContent = '+ community'; toast('no collections', 'info'); return; }
        const wrap = document.createElement('span');
        wrap.className = 'ann-comm-pick';
        wrap.innerHTML = `<select class="resource-select" style="font-size:10px;height:20px">${names.map(n => `<option>${esc(n)}</option>`).join('')}</select> <button class="btn-ann-act" style="background:rgba(88,166,255,0.12);border-color:rgba(88,166,255,0.3)">add</button>`;
        btn.replaceWith(wrap);
        wrap.querySelector('button').addEventListener('click', async () => {
          const comm = wrap.querySelector('select').value;
          // Write annotation body to journal first, then add that entry to the community
          const jr = await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'journal_add', args: { entry: body } }) });
          const jd = await jr.json();
          if (!jd.ok) { toast(jd.error || 'journal write failed', 'error'); return; }
          const jnDate = jd.date || new Date().toISOString().slice(0, 16).replace('T', ' ');
          const cr = await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'community_add', args: { community: comm, kind: 'journal', journal_date: jnDate } }) });
          const cd = await cr.json();
          if (cd.ok) { toast('✓ added to community'); wrap.remove(); }
          else { toast(cd.error || 'add failed', 'error'); }
        });
        btn.disabled = false;
      });
    });
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
      // Hide/show sibling annotation rows to match their parent task visibility
      let sib = row.nextElementSibling;
      while (sib && sib.classList.contains('task-row-ann')) {
        sib.style.display = match ? '' : 'none';
        sib = sib.nextElementSibling;
      }
    });
  }

  // Terminal filter mode pushes into the inline filter box for tasks / lists
  document.addEventListener('filter', (e) => {
    if (e.detail.section === 'tasks') {
      const fi = document.getElementById('task-filter');
      if (fi) { fi.value = e.detail.query; filterTasks(); }
      return;
    }
    if (e.detail.section === 'lists') {
      const lf = document.getElementById('list-filter');
      if (!lf) return;
      lf.value = e.detail.query;
      const q = lf.value.toLowerCase();
      document.querySelectorAll('#list-items .list-row').forEach(el => {
        el.style.display = (!q || el.textContent.toLowerCase().includes(q)) ? '' : 'none';
      });
    }
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
          intHtml += `<div class="interval-row" data-tags="${escapedTags}" data-timew-id="${iv.timew_id || ''}">
            ${dot}<span class="int-tags" style="cursor:pointer" title="Click to start tracking">${iv.tags}</span><span class="int-dur">${fmt(iv.duration)}</span>
            <span class="int-actions">
              <button class="act-btn int-journal-btn" data-tags="${escapedTags}" data-dur="${fmt(iv.duration)}">→ journal</button>
              ${!iv.active ? `<button class="act-btn int-archive-btn" data-timew-id="${iv.timew_id || ''}" data-tags="${escapedTags}" data-dur="${fmt(iv.duration)}" title="Delete this interval">⊗</button>` : ''}
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

      // Journal note about time interval — writes [time-entry:TAGS|DUR|NOTE] card
      ints.querySelectorAll('.int-journal-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const row = btn.closest('.interval-row');
          const actionRow = row?.nextElementSibling;
          if (!actionRow) return;
          if (!actionRow.classList.contains('hidden')) { actionRow.classList.add('hidden'); actionRow.innerHTML = ''; return; }
          const wrapper = document.createElement('div');
          wrapper.className = 'task-detail-input';
          wrapper.innerHTML = `<input type="text" placeholder="note about ${btn.dataset.tags}…" class="tjnl-input" style="flex:1"/><span class="tjnl-jsel-slot"></span><button class="btn-inline-alt tjnl-btn">→ journal</button>`;
          wrapper.querySelector('.tjnl-jsel-slot').replaceWith(makeJournalSelect());
          actionRow.appendChild(wrapper);
          actionRow.classList.remove('hidden');
          actionRow.querySelector('.tjnl-input').focus();
          const submit = async () => {
            const note = actionRow.querySelector('.tjnl-input').value.trim();
            if (!note) return;
            const entry = `[time-entry:${btn.dataset.tags}|${btn.dataset.dur}|${note}]`;
            const jSel = actionRow.querySelector('.journal-target-select');
            await sendJournalNote(entry, jSel);
            actionRow.querySelector('.tjnl-input').value = '';
            actionRow.querySelector('.tjnl-input').placeholder = '✓ recorded in journal';
            setTimeout(() => { actionRow.classList.add('hidden'); actionRow.innerHTML = ''; }, 1500);
          };
          actionRow.querySelector('.tjnl-btn').addEventListener('click', submit);
          actionRow.querySelector('.tjnl-input').addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
        });
      });

      // ⊗ archive time interval
      ints.querySelectorAll('.int-archive-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const timewId = btn.dataset.timewId;
          const tags = btn.dataset.tags || '';
          const dur = btn.dataset.dur || '';
          confirmAction('delete interval', `Delete time interval <strong>${esc(tags)}</strong> (${esc(dur)})? This cannot be undone.`, async () => {
            try {
              const r = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
                body: JSON.stringify({ action: 'timew_delete', args: { timew_id: timewId } }) });
              const d = await r.json();
              if (d.ok) { toast('interval deleted'); await loadTime(); }
              else toast(d.error || 'delete failed', 'error');
            } catch (err) { toast('delete failed', 'error'); }
          });
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
    const e2 = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    // Stash structured card HTML as null-byte placeholders BEFORE the general
    // HTML-escape pass — otherwise the generated <div>/<strong> etc. get escaped.
    const taskCards = [];
    const _ph = () => { const n = taskCards.length - 1; return `\x00CTK${n}\x00`; };

    // Parse meta string into typed inline pills (project=blue, tag=green, priority=muted)
    const buildTaskMetaPills = (meta) => meta.trim().split(/\s+/).filter(Boolean).flatMap(p => {
      const [key, ...rest] = p.split(':'); const val = rest.join(':');
      if (key === 'project') return [`<span class="ctn-pill-project" style="cursor:pointer" onclick="window.__navigateProject('${e2(val)}')">${e2(val)}</span>`];
      if (key === 'tag')     return [`<span class="ctn-pill-tag">${e2(val)}</span>`];
      if (key === 'tags')    return val.split(',').map(t => t.trim()).filter(Boolean).map(t => `<span class="ctn-pill-tag">${e2(t)}</span>`);
      if (key === 'priority') return [`<span class="ctn-pill-pri">${e2(val)}</span>`];
      return [];
    }).join('');

    // [community-task:COMMID|UUID|DESC|META|NOTE] — task from community panel
    text = text.replace(/\[community-task:(\d+)\|([^|\]]+)\|([^|\]]+)\|([^|\]]*)\|([^\]]*)\]/g,
      (_, commId, taskUuid, desc, meta, note) => {
        const pills = buildTaskMetaPills(meta);
        const noteHtml = note.trim() ? `<div class="ctn-note">${e2(note.trim())}</div>` : '';
        const html = `<div class="ctn-card"><div class="ctn-head"><strong class="ctn-title">${e2(desc)}</strong><button class="ctn-ref-btn" onclick="window.__navigateTask('${e2(taskUuid)}')">task</button><button class="ctn-comm-btn" onclick="window.__navigateCommunityEntry(${parseInt(commId)})">comm #${parseInt(commId)}</button></div>${pills ? `<div class="ctn-meta">${pills}</div>` : ''}${noteHtml}</div>`;
        taskCards.push(html);
        return _ph();
      });

    // [task-entry:UUID|DESC|META|NOTE] — task journaled from task view
    text = text.replace(/\[task-entry:([^|\]]*)\|([^|\]]+)\|([^|\]]*)\|([^\]]*)\]/g,
      (_, taskUuid, desc, meta, note) => {
        const shortUuid = taskUuid ? taskUuid.slice(0, 8) : '';
        const pills = buildTaskMetaPills(meta);
        const noteHtml = note.trim() ? `<div class="ctn-note">${e2(note.trim())}</div>` : '';
        const taskBtn = taskUuid
          ? `<button class="ctn-ref-btn" onclick="window.__navigateTask('${e2(taskUuid)}')">task</button>`
          : '';
        const uuidBadge = shortUuid ? `<span class="ctn-uuid-badge" title="${e2(taskUuid)}">${e2(shortUuid)}…</span>` : '';
        const html = `<div class="ctn-card"><div class="ctn-head"><strong class="ctn-title">${e2(desc)}</strong>${taskBtn}${uuidBadge}</div>${pills ? `<div class="ctn-meta">${pills}</div>` : ''}${noteHtml}</div>`;
        taskCards.push(html);
        return _ph();
      });

    // [time-entry:TAGS|DUR|NOTE] — time interval journaled from times view
    text = text.replace(/\[time-entry:([^|\]]+)\|([^|\]]+)\|([^\]]*)\]/g,
      (_, tags, dur, note) => {
        const noteHtml = note.trim() ? `<div class="ctn-note">${e2(note.trim())}</div>` : '';
        const html = `<div class="ctn-card ctn-time"><div class="ctn-head"><strong class="ctn-title">⏱ ${e2(tags)}</strong><span class="ctn-meta-pill">${e2(dur)}</span></div>${noteHtml}</div>`;
        taskCards.push(html);
        return _ph();
      });

    // [list-entry:PREFIX|TEXT|NOTE] — list item journaled from lists view
    text = text.replace(/\[list-entry:([^|\]]+)\|([^|\]]+)\|([^\]]*)\]/g,
      (_, prefix, itemText, note) => {
        const noteHtml = note.trim() ? `<div class="ctn-note">${e2(note.trim())}</div>` : '';
        const html = `<div class="ctn-card ctn-list"><div class="ctn-head"><strong class="ctn-title">${e2(itemText)}</strong><span class="ctn-uuid-badge">${e2(prefix)}</span></div>${noteHtml}</div>`;
        taskCards.push(html);
        return _ph();
      });

    // [ledger-entry:DATE|DESC|AMT|PROJECT|TAGS|NOTE] — transaction journaled from ledger view
    // Also handles old 4-field format [ledger-entry:DATE|DESC|AMT|NOTE] via rest-split
    text = text.replace(/\[ledger-entry:([^|\]]+)\|([^|\]]+)\|([^|\]]+)\|([^\]]*)\]/g,
      (_, date, desc, amt, rest) => {
        const parts = rest.split('|');
        let project = '', tags = '', note = '';
        if (parts.length >= 3) { [project, tags, note] = parts; }
        else { note = parts[0] || ''; }
        const safeDate = e2(date);
        const safeDesc = e2(desc).replace(/'/g, '&#39;');
        const noteHtml = note.trim() ? `<div class="ctn-note">${e2(note.trim())}</div>` : '';
        const projHtml = project.trim() ? `<span class="ctn-pill-project" style="cursor:pointer" onclick="window.__navigateProject('${e2(project.trim())}')">${e2(project.trim())}</span>` : '';
        const tagsHtml = tags.trim() ? tags.trim().split(',').map(t => `<span class="ctn-pill-tag">${e2(t.trim())}</span>`).join('') : '';
        const ledgerMeta = (projHtml || tagsHtml) ? `<div class="ctn-meta">${projHtml}${tagsHtml}</div>` : '';
        const html = `<div class="ctn-card ctn-ledger"><div class="ctn-head"><strong class="ctn-title">${e2(desc)}</strong><button class="ctn-ref-btn" onclick="window.__navigateLedger('${safeDate}','${safeDesc}')">ledger ═</button><span class="ctn-uuid-badge">${safeDate}</span><span class="ctn-meta-pill">${e2(amt)}</span></div>${ledgerMeta}${noteHtml}</div>`;
        taskCards.push(html);
        return _ph();
      });
    // Strip jrnl metadata tokens — already shown as chips, don't duplicate in body
    text = text.replace(/@project:\S+/g, '').replace(/@tags:\S+/g, '').replace(/\s{2,}/g, ' ').trim();
    // General escaping + inline marker rendering (placeholders survive unharmed)
    let out = text
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/\[community-ref:(\d+)\|([^|\]]+)(?:\|([^\]]*))?\]/g, (_, entryId, sourceRef, descSnip) => {
        const label = (descSnip || '').trim() || sourceRef.trim() || `entry #${entryId}`;
        return `<span class="journal-backlink" data-entry-id="${entryId}" title="Communities entry: ${esc(sourceRef)}" onclick="window.__navigateCommunityEntry(${entryId})">⟵ ${esc(label.slice(0, 60))}${label.length > 60 ? '…' : ''}</span>`;
      })
      .replace(/rejournal-of:(\S+)/g, (_, slug) => {
        const label = slug.replace('_', ' ').replace(/-(\d{2})-(\d{2})$/, ' $1:$2');
        return `<span class="journal-rejournal-link" title="Go to source entry" onclick="window.__navigateJournalEntry('${slug}')">⟵ ${esc(label)}</span>`;
      })
      .replace(/rejournaled → (\S+)/g, (_, slug) => {
        const label = slug.replace('_', ' ').replace(/-(\d{2})-(\d{2})$/, ' $1:$2');
        return `<span class="journal-rejournal-link" title="Go to rejournal entry" onclick="window.__navigateJournalEntry('${slug}')">⟶ ${esc(label)}</span>`;
      })
      .replace(/@(\w[\w:.-]*)/g, '<span class="journal-tag">@$1</span>');
    // Restore community-task card HTML from placeholders
    taskCards.forEach((html, i) => { out = out.replace(`\x00CTK${i}\x00`, html); });
    return out;
  }

  // ── Journal markdown rendering ────────────────────────────────────────────
  function _mdEsc(s) {
    return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function _mdInline(s) {
    // s is already HTML-escaped; apply inline markdown on safe text
    return s
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/\*(.+?)\*/g, '<em>$1</em>')
      .replace(/`([^`]+)`/g, '<code class="jmd-code">$1</code>')
      .replace(/\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
  }

  function renderMdBody(rawText) {
    const stash = [];
    const ph = n => `\x00MD${n}\x00`;

    // 1. Stash all special bracket tokens so markdown doesn't mangle them
    let t = rawText
      .replace(/\[(?:community-task|task-entry|time-entry|list-entry|ledger-entry|community-ref):[^\]]*\]/g, m => {
        stash.push(m); return ph(stash.length - 1);
      })
      .replace(/rejournal-of:\S+/g, m => { stash.push(m); return ph(stash.length - 1); })
      .replace(/rejournaled → \S+/g, m => { stash.push(m); return ph(stash.length - 1); });

    // 2. Strip jrnl metadata tokens (shown as chips)
    t = t.replace(/@project:\S+/g, '').replace(/@tags:\S+/g, '').replace(/\s{2,}/g, ' ').trim();

    // 3. Block-level markdown, line by line with paragraph accumulation
    const lines = t.split('\n');
    let html = '';
    let inUl = false;
    let inOl = false;
    let paraLines = [];   // accumulated prose lines for current paragraph

    const flushPara = () => {
      if (!paraLines.length) return;
      // Trim trailing space added between consecutive lines
      html += `<p class="jmd-p">${paraLines.join('').replace(/ $/, '')}</p>`;
      paraLines = [];
    };
    const closeLists = () => {
      if (inUl) { html += '</ul>'; inUl = false; }
      if (inOl) { html += '</ol>'; inOl = false; }
    };

    for (const line of lines) {
      const hm  = line.match(/^(#{1,4})\s+(.*)/);
      const bq  = line.match(/^>\s?(.*)/);
      const uli = line.match(/^[-*]\s+(.*)/);
      const oli = line.match(/^(\d+)\.\s+(.*)/);
      const trimmed = line.trim();
      const isCard = trimmed !== '' && trimmed.replace(/\x00MD\d+\x00/g, '').trim() === '';

      if (hm) {
        flushPara(); closeLists();
        const lv = hm[1].length;
        html += `<h${lv} class="jmd-h">${_mdInline(_mdEsc(hm[2]))}</h${lv}>`;
      } else if (bq) {
        flushPara(); closeLists();
        html += `<blockquote class="jmd-bq">${_mdInline(_mdEsc(bq[1]))}</blockquote>`;
      } else if (uli) {
        flushPara();
        if (inOl) { html += '</ol>'; inOl = false; }
        if (!inUl) { html += '<ul class="jmd-ul">'; inUl = true; }
        html += `<li>${_mdInline(_mdEsc(uli[1]))}</li>`;
      } else if (oli) {
        flushPara();
        if (inUl) { html += '</ul>'; inUl = false; }
        if (!inOl) { html += '<ol class="jmd-ol">'; inOl = true; }
        html += `<li>${_mdInline(_mdEsc(oli[2]))}</li>`;
      } else if (isCard) {
        // Structured card placeholder — output bare, no block wrapper
        flushPara(); closeLists();
        html += trimmed;
      } else if (trimmed === '') {
        // Blank line = paragraph boundary
        flushPara(); closeLists();
      } else {
        // Regular prose — accumulate into paragraph
        closeLists();
        const hardBreak = line.endsWith('  ');
        const content = _mdInline(_mdEsc(hardBreak ? line.slice(0, -2) : line));
        paraLines.push(hardBreak ? content + '<br>' : content + ' ');
      }
    }
    flushPara(); closeLists();

    // 4. @tag highlight
    html = html.replace(/@(\w[\w:.-]*)/g, '<span class="journal-tag">@$1</span>');

    // 5. Restore stashed tokens via the normal highlightTags pipeline
    stash.forEach((original, i) => {
      html = html.replace(ph(i), highlightTags(original));
    });

    return html;
  }

  function renderEntryBody(rawText) {
    return journalMdRender ? renderMdBody(rawText) : highlightTags(rawText);
  }

  // Inline-only markdown (bold, italic, code, links) — for short note fields
  // that live inside flex/baseline containers where block elements would break layout.
  function renderMdInline(rawText) {
    if (!journalMdRender) return esc(rawText);
    return _mdInline(_mdEsc(rawText));
  }

  function syncMdToggleBtn() {
    const btn = document.getElementById('journal-md-toggle');
    if (!btn) return;
    btn.classList.toggle('active', journalMdRender);
    btn.title = journalMdRender ? 'Markdown rendering ON — click to show raw' : 'Click to render markdown';
  }

  function wireJournalMdToggle() {
    const btn = document.getElementById('journal-md-toggle');
    if (!btn || btn.dataset.wired) { syncMdToggleBtn(); return; }
    btn.dataset.wired = '1';
    btn.addEventListener('click', () => {
      journalMdRender = !journalMdRender;
      localStorage.setItem('journal_md_render', journalMdRender ? '1' : '0');
      syncMdToggleBtn();
      const list = document.getElementById('journal-list');
      renderJournalPage(list);
      wireJournalEntryEvents(list);
    });
    syncMdToggleBtn();
  }

  function wireJournalArchiveToggle() {
    const btn = document.getElementById('journal-archive-toggle');
    if (!btn || btn.dataset.wired) {
      if (btn) btn.classList.toggle('active', journalShowArchived);
      return;
    }
    btn.dataset.wired = '1';
    btn.classList.toggle('active', journalShowArchived);
    btn.addEventListener('click', () => {
      journalShowArchived = !journalShowArchived;
      btn.classList.toggle('active', journalShowArchived);
      journalPage = 1;
      const list = document.getElementById('journal-list');
      renderJournalPage(list);
      wireJournalEntryEvents(list);
    });
  }

  // Global helper called by inline onclick in journal backlinks
  window.__navigateCommunityEntry = async function(entryId) {
    communityState.pendingHighlight = parseInt(entryId);
    await switchSection('community');
    // After entries load, scroll to and flash the entry
    const poll = setInterval(() => {
      const card = document.querySelector(`.community-entry-card[data-id="${entryId}"]`);
      if (card) {
        clearInterval(poll);
        card.scrollIntoView({ behavior: 'smooth', block: 'center' });
        card.classList.add('community-entry-highlight');
        setTimeout(() => card.classList.remove('community-entry-highlight'), 2000);
        communityState.pendingHighlight = null;
      }
    }, 80);
    setTimeout(() => clearInterval(poll), 3000); // give up after 3s
  };

  // Global helper: navigate to ledger section and highlight a transaction by date+description
  window.__navigateLedger = async function(date, desc) {
    await switchSection('ledger');
    const tryHighlight = () => {
      const items = document.querySelectorAll('.ledger-item');
      for (const item of items) {
        const d = item.querySelector('.tx-date')?.textContent?.trim();
        const t = item.querySelector('.tx-desc')?.textContent?.trim();
        if (d === date && t === desc) {
          item.scrollIntoView({ behavior: 'smooth', block: 'center' });
          item.classList.add('ledger-item-highlight');
          setTimeout(() => item.classList.remove('ledger-item-highlight'), 2200);
          return true;
        }
      }
      return false;
    };
    if (!tryHighlight()) {
      const poll = setInterval(() => { if (tryHighlight()) clearInterval(poll); }, 80);
      setTimeout(() => clearInterval(poll), 3000);
    }
  };

  // Global helper: navigate to a project by name in the Projects screen
  window.__navigateProject = async function(name) {
    if (!name) return;
    await switchSection('projects');
    const tryFind = () => {
      const card = document.querySelector(`.proj-card[data-project="${CSS.escape(name)}"]`);
      if (card) {
        card.scrollIntoView({ behavior: 'smooth', block: 'center' });
        card.classList.add('proj-card-highlight');
        setTimeout(() => card.classList.remove('proj-card-highlight'), 2000);
        return true;
      }
      return false;
    };
    if (!tryFind()) {
      const poll = setInterval(() => { if (tryFind()) clearInterval(poll); }, 80);
      setTimeout(() => clearInterval(poll), 3000);
    }
  };

  // Global helper: navigate to a task by UUID, switch to tasks view and expand its detail.
  // If the task isn't in the current list, searches all tasklists and switches automatically.
  window.__navigateTask = async function(uuid) {
    if (!uuid) return;
    let task = cachedTasks.find(t => t.uuid === uuid);
    if (!task) {
      try {
        const r = await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'task_find_by_uuid', args: { uuid } }) });
        const d = await r.json();
        if (d.ok && d.list_name) {
          // Switch active tasklist to the one containing this task
          await fetch('/resource', { method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ kind: 'tasklists', name: d.list_name }) });
          await loadProfileResources();
        } else {
          toast('task not found (may be completed or in another profile)', 'info');
          return;
        }
      } catch (_) {}
    }
    await switchSection('tasks');
    task = cachedTasks.find(t => t.uuid === uuid);
    if (!task) { toast('task not found', 'info'); return; }
    const detail = document.getElementById('tid-' + task.id);
    if (!detail) return;
    document.querySelectorAll('.task-inline-detail').forEach(d => {
      if (d !== detail) { d.classList.add('hidden'); d.innerHTML = ''; }
    });
    expandTaskInline(detail, task);
    setTimeout(() => {
      const row = document.querySelector(`.task-row[data-id="${task.id}"]`);
      if (row) {
        row.scrollIntoView({ behavior: 'smooth', block: 'center' });
        row.classList.add('task-row-highlight');
        setTimeout(() => row.classList.remove('task-row-highlight'), 2200);
      }
    }, 100);
  };

  // Global helper: navigate to a journal entry by slug, clearing any active filter if needed
  window.__navigateJournalEntry = async function(slug) {
    if (activeSection !== 'journal') await switchSection('journal');
    // Clear filter so the target entry is visible
    journalActiveFilter = null;
    syncJournalFilterButtons();
    journalPage = Math.ceil(cachedJournalEntries.length / PAGE_SIZE); // load all pages
    const list = document.getElementById('journal-list');
    renderJournalPage(list);
    wireJournalEntryEvents(list);
    const poll = setInterval(() => {
      const el = list.querySelector(`[data-slug="${slug}"]`);
      if (el) {
        clearInterval(poll);
        // Un-collapse the parent date group if it is currently hidden
        const dateBody = el.closest('.journal-date-body');
        if (dateBody && dateBody.classList.contains('hidden')) {
          dateBody.classList.remove('hidden');
          const hdr = dateBody.previousElementSibling;
          if (hdr) {
            hdr.classList.remove('jgrp-collapsed');
            const label = decodeURIComponent(hdr.dataset.label || '');
            if (label) localStorage.removeItem(`ww-jgrp-${label}`);
          }
        }
        setTimeout(() => {
          el.scrollIntoView({ behavior: 'smooth', block: 'center' });
          el.classList.add('journal-entry-highlight');
          setTimeout(() => el.classList.remove('journal-entry-highlight'), 2500);
        }, 50);
      }
    }, 80);
    setTimeout(() => clearInterval(poll), 3000);
  };

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
    const annotations = e.annotations || [];
    const annHTML = annotations.length
      ? `<div class="entry-annotations">${annotations.map((a, ai) => {
          const annId = `jann-${i}-${ai}`;
          return `<div class="entry-ann-block">
            <span class="entry-ann-ts">${esc(a.date)}</span>
            <span class="entry-ann-text">${highlightTags(a.text)}</span>
            <span class="ann-act-row">
              <button class="btn-ann-act btn-ann-task" data-body="${esc(a.text)}" title="Create task from this annotation">+ task</button>
              <button class="btn-ann-act btn-ann-journal" data-body="${esc(a.text)}" title="Create journal entry from this annotation">+ entry</button>
            </span>
          </div>`;
        }).join('')}</div>`
      : '';
    const slug = e.date_slug || e.date.replace(' ', '_').replace(/:/g, '-');
    // Metadata chips from scanner
    const metaChips = [
      e.project ? `<span class="ledger-project-chip jmeta-chip" style="cursor:pointer" onclick="window.__navigateProject('${esc(e.project)}')">${esc(e.project)}</span>` : '',
      ...(e.tags || []).map(t => `<span class="ledger-tag-chip jmeta-chip">${esc(t)}</span>`),
      e.priority ? `<span class="ledger-pri-chip ledger-pri-${(e.priority||'').toLowerCase()} jmeta-chip">${esc(e.priority)}</span>` : '',
      e.status   ? `<span class="jmeta-status-chip">${esc(e.status)}</span>` : '',
    ].filter(Boolean).join('');
    const metaBar = metaChips ? `<div class="entry-meta-chips">${metaChips}</div>` : '';
    // Source navigation: detect [task-entry:] or [ledger-entry:] in body
    const body = e.body || '';
    const taskMatch = body.match(/\[task-entry:([^\]|]+)/);
    const ledgerMatch = body.match(/\[ledger-entry:([^|]+)\|([^|]*)/);
    const srcBtns = [
      taskMatch ? `<button class="act-btn entry-src-task-btn" data-idx="${i}" data-uuid="${esc(taskMatch[1].trim())}">→ task</button>` : '',
      ledgerMatch ? `<button class="act-btn entry-src-ledger-btn" data-idx="${i}" data-date="${esc(ledgerMatch[1].trim())}" data-desc="${esc(ledgerMatch[2].trim())}">→ ledger</button>` : '',
    ].filter(Boolean).join('');
    const isArchived = body.includes('@status:archived');
    return `<div class="journal-entry${isArchived ? ' entry-archived' : ''}" data-idx="${i}" data-slug="${esc(slug)}">
      <div class="entry-date">${fmtJournalDate(e.date)}</div>
      <div class="entry-body${journalMdRender ? ' md-on' : ''}" id="jentry-${i}">${renderEntryBody(preview)}</div>
      ${hasMore ? `<button class="entry-more" data-idx="${i}" data-full="${encodeURIComponent(e.body)}">show more</button>` : ''}
      ${annHTML}${metaBar}
      <div class="entry-actions">
        <button class="act-btn entry-annotate-btn" data-idx="${i}" data-date="${e.date}" data-slug="${esc(slug)}" data-body="${encodeURIComponent(e.body)}">+ annotate</button>
        <button class="act-btn entry-journal-btn" data-idx="${i}" data-date="${e.date}" data-slug="${esc(slug)}" data-body="${encodeURIComponent(e.body)}">+ new entry</button>
        <button class="act-btn entry-community-btn" data-idx="${i}" data-date="${e.date}">→ community</button>
        <button class="act-btn entry-meta-btn" data-idx="${i}" data-slug="${esc(slug)}" data-project="${esc(e.project||'')}" data-tags="${esc((e.tags||[]).join(','))}" data-priority="${esc(e.priority||'')}" data-status="${esc(e.status||'')}">metadata</button>
        ${srcBtns}
        ${isArchived
          ? `<button class="act-btn entry-restore-btn" data-idx="${i}" data-slug="${esc(slug)}" data-date="${esc(e.date)}" title="Restore this archived entry">↩ restore</button>`
          : `<button class="act-btn entry-archive-btn" data-idx="${i}" data-slug="${esc(slug)}" data-date="${esc(e.date)}" title="Archive entry (adds @status:archived, reversible)">⊗ archive</button>`}
        <button class="act-btn entry-delete-btn" data-idx="${i}" data-slug="${esc(slug)}" data-date="${esc(e.date)}" title="Permanently delete this entry">⊗ delete</button>
      </div>
      <div class="entry-action-row hidden" id="jaction-${i}"></div>
    </div>`;
  }

  function wireJournalEntryEvents(list) {
    list.querySelectorAll('.entry-more').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = btn.dataset.idx;
        document.getElementById(`jentry-${idx}`).innerHTML = renderEntryBody(decodeURIComponent(btn.dataset.full));
        btn.remove();
      });
    });
    list.querySelectorAll('.entry-annotate-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = btn.dataset.idx;
        const row = document.getElementById(`jaction-${idx}`);
        if (!row.classList.contains('hidden')) { row.classList.add('hidden'); row.innerHTML = ''; return; }
        row.innerHTML = `<div class="task-detail-input"><input type="text" placeholder="annotation text…" id="jann-input-${idx}" /><button class="btn-inline-submit" id="jann-btn-${idx}">add</button></div>`;
        row.classList.remove('hidden');
        document.getElementById(`jann-input-${idx}`).focus();
        const submit = async () => {
          const note = document.getElementById(`jann-input-${idx}`).value.trim();
          if (!note) return;
          const slug = btn.dataset.slug;
          try {
            const r = await fetch('/action', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ action: 'journal_annotate', args: { date_slug: slug, text: note } }),
            });
            const d = await r.json();
            if (d.ok) {
              toast('✓ annotation added');
              row.classList.add('hidden');
              row.innerHTML = '';
              await loadJournal();
            } else {
              toast(d.error || 'annotate failed', 'error');
            }
          } catch (e) { toast(e.message, 'error'); }
        };
        document.getElementById(`jann-btn-${idx}`).addEventListener('click', submit);
        document.getElementById(`jann-input-${idx}`).addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
      });
    });
    list.querySelectorAll('.entry-journal-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = btn.dataset.idx;
        const slug = btn.dataset.slug;
        const row = document.getElementById(`jaction-${idx}`);
        if (!row.classList.contains('hidden')) { row.classList.add('hidden'); row.innerHTML = ''; return; }
        // Build form: input + optional journal selector + submit
        const jSelEl = makeJournalSelect('resource-select jnew-jsel');
        const wrapper = document.createElement('div');
        wrapper.className = 'task-detail-input';
        wrapper.innerHTML = `<input type="text" placeholder="note for new entry…" id="jnew-input-${idx}" style="flex:1"/><span class="jnew-jsel-slot"></span><button class="btn-inline-alt" id="jnew-btn-${idx}">+ new entry</button>`;
        wrapper.querySelector('.jnew-jsel-slot').replaceWith(jSelEl);
        row.appendChild(wrapper);
        row.classList.remove('hidden');
        document.getElementById(`jnew-input-${idx}`).focus();
        const submit = async () => {
          const note = document.getElementById(`jnew-input-${idx}`)?.value.trim();
          if (!note || !slug) return;
          const journal = jSelEl.value || '';
          // Carry any community-task marker from the source body into the new entry
          const srcBody = decodeURIComponent(btn.dataset.body);
          const taskMatch = srcBody.match(/\[community-task:[^\]]+\]/);
          const carry = taskMatch ? taskMatch[0] : '';
          try {
            const r = await fetch('/action', {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ action: 'journal_rejournal',
                args: { source_slug: slug, text: note, journal, carry_marker: carry } }),
            });
            const d = await r.json();
            if (d.ok) {
              toast('✓ new entry created');
              row.classList.add('hidden'); row.innerHTML = '';
              await loadJournal();
            } else {
              toast(d.error || 'failed', 'error');
            }
          } catch (e) { toast(e.message, 'error'); }
        };
        document.getElementById(`jnew-btn-${idx}`).addEventListener('click', submit);
        document.getElementById(`jnew-input-${idx}`).addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
      });
    });
    list.querySelectorAll('.entry-community-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const idx = btn.dataset.idx;
        const dateHdr = btn.dataset.date;
        const row = document.getElementById(`jaction-${idx}`);
        if (!row.classList.contains('hidden')) { row.classList.add('hidden'); row.innerHTML = ''; return; }
        row.innerHTML = '<div class="skeleton-msg">Loading collections…</div>';
        row.classList.remove('hidden');
        let names = [];
        try {
          const lr = await fetch('/data/community/list');
          const list = await lr.json();
          if (list.ok && Array.isArray(list.communities)) names = list.communities.map(c => c.name);
        } catch (_) {}
        if (!names.length) {
          row.innerHTML = '<div class="empty-state" style="font-size:12px">No collections yet. Open the <strong>Communities</strong> tab and create one, or run <code>ww community create …</code> in the terminal.</div>';
          return;
        }
        row.innerHTML = `<div class="task-detail-input jcomm-row"><label class="community-select-wrap" style="flex:1;min-width:0;margin:0"><span class="community-toolbar-label">collection</span><select class="resource-select jcomm-sel" style="width:100%"></select></label><button type="button" class="btn-inline-submit jcomm-btn">add</button></div>`;
        const sel = row.querySelector('.jcomm-sel');
        names.forEach(n => {
          const o = document.createElement('option');
          o.value = n;
          o.textContent = n;
          sel.appendChild(o);
        });
        const submit = async () => {
          const comm = sel.value;
          if (!comm) return;
          const d = await postAddJournalToCommunity(comm, dateHdr);
          if (d.ok) {
            toast('journal entry added to collection');
            row.classList.add('hidden');
            row.innerHTML = '';
          } else {
            toast(d.error || 'add failed', 'error');
          }
        };
        row.querySelector('.jcomm-btn').addEventListener('click', submit);
      });
    });

    // metadata: set project/tags/priority/status via inline jrnl annotation
    list.querySelectorAll('.entry-meta-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = btn.dataset.idx;
        const row = document.getElementById(`jaction-${idx}`);
        if (!row.classList.contains('hidden')) { row.classList.add('hidden'); row.innerHTML = ''; return; }
        row.innerHTML = `<div class="task-detail-input jmeta-form">
          <input type="text" id="jmeta-proj-${idx}" placeholder="project" value="${btn.dataset.project || ''}" style="width:90px" />
          <input type="text" id="jmeta-tags-${idx}" placeholder="tags (comma sep)" value="${btn.dataset.tags || ''}" style="width:130px" />
          <select id="jmeta-pri-${idx}" class="resource-select" style="width:60px">
            <option value="">pri</option>
            ${['H','M','L'].map(p => `<option value="${p}"${btn.dataset.priority===p?' selected':''}>${p}</option>`).join('')}
          </select>
          <select id="jmeta-status-${idx}" class="resource-select" style="width:80px">
            <option value="">status</option>
            ${['active','pending','done','hold'].map(s => `<option value="${s}"${btn.dataset.status===s?' selected':''}>${s}</option>`).join('')}
          </select>
          <button class="btn-inline-submit" id="jmeta-btn-${idx}">save</button>
        </div>`;
        row.classList.remove('hidden');
        document.getElementById(`jmeta-proj-${idx}`).focus();
        const submit = async () => {
          const proj    = document.getElementById(`jmeta-proj-${idx}`).value.trim();
          const tagsRaw = document.getElementById(`jmeta-tags-${idx}`).value.trim();
          const pri     = document.getElementById(`jmeta-pri-${idx}`).value;
          const status  = document.getElementById(`jmeta-status-${idx}`).value;
          const parts = [];
          if (proj)    parts.push(`@project:${proj}`);
          if (tagsRaw) parts.push(`@tags:${tagsRaw.replace(/\s*,\s*/g, ',')}`);
          if (pri)     parts.push(`@priority:${pri}`);
          if (status)  parts.push(`@status:${status}`);
          if (!parts.length) return;
          const text = parts.join(' ');
          try {
            const r = await fetch('/action', {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ action: 'journal_annotate', args: { date_slug: btn.dataset.slug, text } }),
            });
            const d = await r.json();
            if (d.ok) { toast('✓ metadata saved'); row.classList.add('hidden'); row.innerHTML = ''; await loadJournal(); }
            else { toast(d.error || 'failed', 'error'); }
          } catch (e) { toast(e.message, 'error'); }
        };
        document.getElementById(`jmeta-btn-${idx}`).addEventListener('click', submit);
      });
    });

    // → task: navigate to the source task referenced in this entry
    list.querySelectorAll('.entry-src-task-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const uuid = btn.dataset.uuid;
        if (uuid) window.__navigateTask(uuid);
      });
    });

    // → ledger: navigate to the source ledger entry referenced in this entry
    list.querySelectorAll('.entry-src-ledger-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        if (btn.dataset.date && btn.dataset.desc) window.__navigateLedger(btn.dataset.date, btn.dataset.desc);
      });
    });

    // Per-annotation: + task (create task from annotation text)
    list.querySelectorAll('.btn-ann-task').forEach(btn => {
      btn.addEventListener('click', async () => {
        const body = btn.dataset.body;
        if (!body) return;
        btn.disabled = true; btn.textContent = '…';
        const r = await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'add', args: { description: body } }) });
        const d = await r.json();
        if (d.ok) {
          btn.textContent = '✓ task';
          if (d.new_uuid) { btn.onclick = () => window.__navigateTask(d.new_uuid); btn.disabled = false; btn.title = d.new_uuid; }
          else toast('task created');
        } else { btn.disabled = false; btn.textContent = '+ task'; toast(d.error || 'failed', 'error'); }
      });
    });

    // Per-annotation: + entry (create new journal entry from annotation text)
    list.querySelectorAll('.btn-ann-journal').forEach(btn => {
      btn.addEventListener('click', async () => {
        const body = btn.dataset.body;
        if (!body) return;
        btn.disabled = true; btn.textContent = '…';
        const r = await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'journal_add', args: { entry: body } }) });
        const d = await r.json();
        if (d.ok) { toast('✓ entry created'); btn.textContent = '✓ entry'; }
        else { btn.disabled = false; btn.textContent = '+ entry'; toast(d.error || 'failed', 'error'); }
      });
    });

    // Archive journal entry
    list.querySelectorAll('.entry-archive-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const date = btn.dataset.date;
        const slug = btn.dataset.slug;
        confirmAction('archive entry', `Mark journal entry from <strong>${esc(date)}</strong> as archived? It will remain in the file with <code>@status:archived</code> and can be found by searching.`, async () => {
          try {
            const r = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
              body: JSON.stringify({ action: 'journal_archive', args: { date_slug: slug } }) });
            const d = await r.json();
            if (d.ok) { toast('entry archived'); await loadJournal(); }
            else toast(d.error || 'archive failed', 'error');
          } catch (err) { toast('archive failed', 'error'); }
        });
      });
    });
    // Restore archived journal entry
    list.querySelectorAll('.entry-restore-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const slug = btn.dataset.slug;
        const date = btn.dataset.date;
        try {
          const r = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
            body: JSON.stringify({ action: 'journal_restore', args: { date_slug: slug } }) });
          const d = await r.json();
          if (d.ok) { toast('entry restored'); await loadJournal(); }
          else toast(d.error || 'restore failed', 'error');
        } catch (err) { toast('restore failed', 'error'); }
      });
    });

    list.querySelectorAll('.entry-delete-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const date = btn.dataset.date;
        const slug = btn.dataset.slug;
        confirmAction('delete entry', `Permanently delete journal entry from <strong>${esc(date)}</strong>? This <strong>cannot be undone</strong>.`, async () => {
          try {
            const r = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
              body: JSON.stringify({ action: 'journal_delete', args: { date_slug: slug } }) });
            const d = await r.json();
            if (d.ok) { toast('entry deleted'); await loadJournal(); }
            else toast(d.error || 'delete failed', 'error');
          } catch (err) { toast('delete failed', 'error'); }
        });
      });
    });
  }

  function getJournalFilteredEntries() {
    if (!journalActiveFilter) return cachedJournalEntries;
    // Build set of slugs that are referenced by rejournal-of: markers in any entry body
    const rejournaled = new Set();
    if (journalActiveFilter === 'rejournaled' || journalActiveFilter === 'all-comments') {
      const rjRe = /rejournal-of:(\S+)/g;
      for (const e of cachedJournalEntries) {
        for (const m of (e.body || '').matchAll(rjRe)) rejournaled.add(m[1]);
        for (const a of (e.annotations || [])) {
          for (const m of (a.text || '').matchAll(rjRe)) rejournaled.add(m[1]);
        }
      }
    }
    return cachedJournalEntries.filter(e => {
      const isArchived = (e.body || '').includes('@status:archived');
      if (isArchived && !journalShowArchived) return false;
      const hasAnn = (e.annotations || []).length > 0;
      const isRejournaled = rejournaled.has(e.date_slug || '');
      if (journalActiveFilter === 'annotated')    return hasAnn;
      if (journalActiveFilter === 'rejournaled')  return isRejournaled;
      if (journalActiveFilter === 'all-comments') return hasAnn || isRejournaled;
      return true;
    });
  }

  function renderJournalPage(list) {
    const filtered = getJournalFilteredEntries();
    const total = filtered.length;
    if (total === 0 && journalActiveFilter) {
      const hints = {
        annotated: 'No annotated entries. Use <strong>+ annotate</strong> on any entry.',
        rejournaled: 'No rejournaled entries. Use <strong>→ journal</strong> on an entry to create a follow-up.',
        'all-comments': 'No annotated or rejournaled entries yet.',
      };
      list.innerHTML = `<div class="empty-state">${hints[journalActiveFilter] || 'No matching entries.'}</div>`;
      return;
    }
    const visible = filtered.slice(0, journalPage * PAGE_SIZE);
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

  function syncJournalFilterButtons() {
    document.querySelectorAll('.journal-filter-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.filter === journalActiveFilter);
    });
  }

  function wireJournalFilterButtons() {
    const bar = document.querySelector('.journal-filter-bar');
    if (!bar || bar.dataset.wired) { syncJournalFilterButtons(); return; }
    bar.dataset.wired = '1';
    bar.querySelectorAll('.journal-filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const f = btn.dataset.filter;
        const isActive = btn.classList.contains('active');
        journalActiveFilter = isActive ? null : f;
        syncJournalFilterButtons();
        journalPage = 1;
        const list = document.getElementById('journal-list');
        renderJournalPage(list);
        wireJournalEntryEvents(list);
      });
    });
    syncJournalFilterButtons();
    wireJournalMdToggle();
    wireJournalArchiveToggle();
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
      wireJournalFilterButtons();
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

  let cachedListItems = [];
  let listShowDone = false;

  function _listEscAttr(s) {
    return String(s ?? '').replace(/&/g, '&amp;').replace(/"/g, '&quot;');
  }

  function _listEscText(s) {
    return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function wireListRowEvents(box) {
    box.querySelectorAll('.list-done-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const prefix = btn.getAttribute('data-prefix');
        const res = await fetch('/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'list_finish', args: { prefix } }),
        });
        const d = await res.json();
        if (d.ok) { toast('✓ done'); await loadLists(); }
        else toast(d.error || d.output || 'failed', 'error');
      });
    });
    box.querySelectorAll('.list-edit-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const row = btn.closest('.list-row');
        if (!row) return;
        const prefix = btn.getAttribute('data-prefix');
        const textSpan = row.querySelector('.list-text');
        const cur = textSpan ? textSpan.textContent : '';
        const act = row.querySelector('.list-row-actions');
        if (!act) return;
        act.innerHTML = `<input type="text" class="inline-filter list-edit-input" style="flex:1;min-width:140px" value="${_listEscAttr(cur)}" />
          <button type="button" class="act-btn list-edit-save">save</button>
          <button type="button" class="act-btn list-edit-cancel">×</button>`;
        const inp = act.querySelector('.list-edit-input');
        const runSave = async () => {
          const nv = inp.value.trim();
          if (!nv) return;
          try {
            const res = await fetch('/action', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ action: 'list_edit', args: { prefix, text: nv } }),
            });
            const d = await res.json();
            if (d.ok) { toast('✓ updated'); await loadLists(); }
            else toast(d.error || d.output || 'failed', 'error');
          } catch (err) {
            toast(`list edit failed: ${err.message}`, 'error');
          }
        };
        act.querySelector('.list-edit-save')?.addEventListener('click', runSave);
        inp?.addEventListener('keydown', (ev) => {
          if (ev.key === 'Enter') {
            ev.preventDefault();
            runSave();
          }
        });
        act.querySelector('.list-edit-cancel')?.addEventListener('click', () => loadLists());
        inp?.focus();
      });
    });
    box.querySelectorAll('.list-remove-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const prefix = btn.getAttribute('data-prefix');
        if (!prefix) return;
        try {
          const res = await fetch('/action', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'list_remove', args: { prefix } }),
          });
          const d = await res.json();
          if (d.ok) { toast('✓ removed'); await loadLists(); }
          else toast(d.error || d.output || 'remove failed', 'error');
        } catch (err) {
          toast(`list remove failed: ${err.message}`, 'error');
        }
      });
    });

    // + note: append inline note to item text via list_edit
    box.querySelectorAll('.list-note-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const row = btn.closest('.list-row');
        const idx = row?.dataset.idx;
        const actionRow = document.getElementById(`lrow-action-${idx}`);
        if (!actionRow) return;
        if (!actionRow.classList.contains('hidden')) { actionRow.classList.add('hidden'); actionRow.innerHTML = ''; return; }
        actionRow.innerHTML = `<div class="task-detail-input"><input type="text" placeholder="inline note…" class="lnote-inp" style="flex:1"/><button class="btn-inline-submit lnote-btn">+ note</button></div>`;
        actionRow.classList.remove('hidden');
        actionRow.querySelector('.lnote-inp').focus();
        const submit = async () => {
          const note = actionRow.querySelector('.lnote-inp').value.trim();
          if (!note) return;
          const prefix = btn.getAttribute('data-prefix');
          const text = btn.getAttribute('data-text');
          const newText = `${text} // ${note}`;
          const res = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
            body: JSON.stringify({ action: 'list_edit', args: { prefix, text: newText } }) });
          const d = await res.json();
          if (d.ok) { toast('✓ note added'); actionRow.classList.add('hidden'); actionRow.innerHTML = ''; await loadLists(); }
          else toast(d.error || 'failed', 'error');
        };
        actionRow.querySelector('.lnote-btn').addEventListener('click', submit);
        actionRow.querySelector('.lnote-inp').addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
      });
    });

    // → journal: write a [list-entry:PREFIX|TEXT|NOTE] card to journal
    box.querySelectorAll('.list-journal-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const row = btn.closest('.list-row');
        const idx = row?.dataset.idx;
        const actionRow = document.getElementById(`lrow-action-${idx}`);
        if (!actionRow) return;
        if (!actionRow.classList.contains('hidden')) { actionRow.classList.add('hidden'); actionRow.innerHTML = ''; return; }
        const wrapper = document.createElement('div');
        wrapper.className = 'task-detail-input';
        wrapper.innerHTML = `<input type="text" placeholder="journal note…" class="ljlist-inp" style="flex:1"/><span class="ljlist-jsel-slot"></span><button class="btn-inline-alt ljlist-btn">→ journal</button>`;
        wrapper.querySelector('.ljlist-jsel-slot').replaceWith(makeJournalSelect());
        actionRow.appendChild(wrapper);
        actionRow.classList.remove('hidden');
        actionRow.querySelector('.ljlist-inp').focus();
        const submit = async () => {
          const note = actionRow.querySelector('.ljlist-inp').value.trim();
          if (!note) return;
          const prefix = btn.getAttribute('data-prefix');
          const text = btn.getAttribute('data-text');
          const entry = `[list-entry:${prefix}|${text}|${note}]`;
          const jSel = actionRow.querySelector('.journal-target-select');
          await sendJournalNote(entry, jSel);
          actionRow.querySelector('.ljlist-inp').value = '';
          actionRow.querySelector('.ljlist-inp').placeholder = '✓ added to journal';
          setTimeout(() => { actionRow.classList.add('hidden'); actionRow.innerHTML = ''; }, 1500);
        };
        actionRow.querySelector('.ljlist-btn').addEventListener('click', submit);
        actionRow.querySelector('.ljlist-inp').addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
      });
    });

    // @comm: send list item to a community
    box.querySelectorAll('.list-comm-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const row = btn.closest('.list-row');
        const idx = row?.dataset.idx;
        const actionRow = document.getElementById(`lrow-action-${idx}`);
        if (!actionRow) return;
        if (!actionRow.classList.contains('hidden')) { actionRow.classList.add('hidden'); actionRow.innerHTML = ''; return; }
        actionRow.innerHTML = '<div class="skeleton-msg">Loading collections…</div>';
        actionRow.classList.remove('hidden');
        let names = communityState.names.length ? communityState.names : [];
        if (!names.length) {
          try {
            const lr = await fetch('/data/community/list');
            const list = await lr.json();
            if (list.ok && Array.isArray(list.communities)) names = list.communities.map(c => c.name);
          } catch (_) {}
        }
        if (!names.length) {
          actionRow.innerHTML = '<div class="empty-state" style="font-size:12px">No collections yet.</div>';
          return;
        }
        const selOpts = names.map(n => `<option value="${_listEscAttr(n)}">${_listEscText(n)}</option>`).join('');
        const existingNote = btn.dataset.note || '';
        actionRow.innerHTML = `<div class="lcomm-full-row"><input class="task-input lcomm-note-inp" type="text" placeholder="note (optional)" value="${_listEscAttr(existingNote)}" /><select class="resource-select lcomm-sel">${selOpts}</select><button class="btn-inline-submit lcomm-list-btn">→ collection</button></div>`;
        actionRow.querySelector('.lcomm-list-btn').addEventListener('click', async () => {
          const comm = actionRow.querySelector('.lcomm-sel').value;
          if (!comm) return;
          const note = actionRow.querySelector('.lcomm-note-inp').value;
          const res = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
            body: JSON.stringify({ action: 'community_add', args: {
              community: comm, kind: 'list',
              list_prefix: btn.dataset.prefix,
              list_text: btn.dataset.text,
              list_note: note,
            } }) });
          const d = await res.json();
          if (d.ok) { toast('list item added to collection'); actionRow.classList.add('hidden'); actionRow.innerHTML = ''; }
          else toast(d.error || 'add failed', 'error');
        });
      });
    });
  }

  function renderListRows() {
    const box = document.getElementById('list-items');
    if (!box) return;
    if (!cachedListItems.length) {
      box.innerHTML = '<div class="empty-state">No items — add one above</div>';
      return;
    }
    box.innerHTML = cachedListItems.map((it, i) => {
      const sepIdx = it.text.indexOf(' // ');
      const mainText = sepIdx >= 0 ? it.text.slice(0, sepIdx) : it.text;
      const noteText = sepIdx >= 0 ? it.text.slice(sepIdx + 4) : '';
      const noteHTML = noteText
        ? `<div class="list-row-note">↳ ${_listEscText(noteText)}</div>`
        : '';
      return `
      <div class="list-row" data-idx="${i}">
        <span class="list-prefix">${_listEscText(it.prefix)}</span>
        <span class="list-text">${_listEscText(mainText)}</span>
        <span class="list-row-actions">
          <button type="button" class="act-btn list-done-btn" data-prefix="${_listEscAttr(it.prefix)}"><span class="btn-icon">✓</span><span class="btn-word">done</span></button>
          <button type="button" class="act-btn list-edit-btn" data-prefix="${_listEscAttr(it.prefix)}"><span class="btn-icon">✎</span><span class="btn-word">edit</span></button>
          <button type="button" class="act-btn list-note-btn" data-prefix="${_listEscAttr(it.prefix)}" data-text="${_listEscAttr(it.text)}">+ note</button>
          <button type="button" class="act-btn list-journal-btn" data-prefix="${_listEscAttr(it.prefix)}" data-text="${_listEscAttr(it.text)}">→ journal</button>
          <button type="button" class="act-btn list-comm-btn" data-prefix="${_listEscAttr(it.prefix)}" data-text="${_listEscAttr(mainText)}" data-note="${_listEscAttr(noteText)}">@comm</button>
          <button type="button" class="act-btn list-remove-btn" data-prefix="${_listEscAttr(it.prefix)}"><span class="btn-icon">−</span><span class="btn-word">remove</span></button>
        </span>
        <div class="list-action-row hidden" id="lrow-action-${i}"></div>
        ${noteHTML}
      </div>`;
    }).join('');
    wireListRowEvents(box);
  }

  async function loadLists() {
    const box = document.getElementById('list-items');
    if (!box) return;
    try {
      const res = await fetch('/data/lists');
      const data = await res.json();
      if (!data.ok) {
        box.innerHTML = `<div class="empty-state">${_listEscText(data.error || 'Could not load lists')}</div>`;
        cachedListItems = [];
        updateContextBar('lists', { items: [] });
        return;
      }
      cachedListItems = data.items || [];
      renderListRows();
      const lf = document.getElementById('list-filter');
      if (lf && lf.value) {
        const q = lf.value.toLowerCase();
        document.querySelectorAll('#list-items .list-row').forEach(el => {
          el.style.display = (!q || el.textContent.toLowerCase().includes(q)) ? '' : 'none';
        });
      }
      updateContextBar('lists', { items: cachedListItems, basename: data.list_basename });
      if (lf && !lf.dataset.wired) {
        lf.dataset.wired = '1';
        lf.addEventListener('input', () => {
          const q = lf.value.toLowerCase();
          document.querySelectorAll('#list-items .list-row').forEach(el => {
            el.style.display = (!q || el.textContent.toLowerCase().includes(q)) ? '' : 'none';
          });
        });
      }
    } catch (e) {
      box.innerHTML = `<div class="empty-state">${_listEscText(e.message)}</div>`;
      cachedListItems = [];
    }
  }

  async function loadListDone() {
    const box = document.getElementById('list-done-items');
    if (!box) return;
    try {
      const res = await fetch('/data/lists?done=1');
      const data = await res.json();
      if (!data.ok || !data.items?.length) {
        box.innerHTML = '<div class="empty-state">No completed items.</div>';
        return;
      }
      box.innerHTML = data.items.map(it => `
        <div class="list-row list-row-done">
          <span class="list-prefix">${_listEscText(it.prefix)}</span>
          <span class="list-text" style="text-decoration:line-through;opacity:.5">${_listEscText(it.text)}</span>
        </div>`).join('');
    } catch (e) {
      box.innerHTML = `<div class="empty-state">${_listEscText(e.message)}</div>`;
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
        const TYPE_ORDER = ['assets', 'liabilities', 'equity', 'income', 'expenses'];
        const TYPE_LABEL = { assets: 'Assets', liabilities: 'Liabilities', equity: 'Equity', income: 'Income', expenses: 'Expenses' };
        const TYPE_CLS   = { assets: 'bal-asset', liabilities: 'bal-liability', equity: 'bal-equity', income: 'bal-income', expenses: 'bal-expense' };
        const groups = {};
        data.balances.forEach(row => {
          const type = row.account.split(':')[0];
          (groups[type] = groups[type] || []).push(row);
        });
        const orderedTypes = [...TYPE_ORDER, ...Object.keys(groups).filter(t => !TYPE_ORDER.includes(t))];
        let html = '<div class="ledger-header">Balances</div>';
        orderedTypes.forEach(type => {
          if (!groups[type]) return;
          html += `<div class="bal-type-label">${TYPE_LABEL[type] || type}</div>`;
          groups[type].forEach(row => {
            const depth = (row.account.match(/:/g) || []).length;
            const indent = depth * 14;
            const cls = TYPE_CLS[type] || '';
            html += `<div class="balance-row ${cls}" style="padding-left:${indent}px">
              <span class="acct-name">${row.account}</span>
              <span class="acct-amt">${row.amount}</span>
            </div>`;
          });
        });
        balDiv.innerHTML = html;
      } else {
        balDiv.innerHTML = '<div class="empty-state">No balance data</div>';
      }

      if (data.recent && data.recent.length) {
        // Build annotation lookup: "date|description" → [note, ...]
        const annMap = {};
        (data.annotations || []).forEach(a => {
          const key = `${a.date}|${a.description}`;
          (annMap[key] = annMap[key] || []).push(a.note);
        });

        recDiv.innerHTML = '<div class="ledger-header">Recent</div>' +
          data.recent.map((row, i) => {
            const notes = annMap[`${row.date}|${row.description}`] || [];
            const noteHtml = notes.map(n =>
              `<div class="ledger-note-line"><span class="ledger-note-marker">;</span> ${renderMdInline(n)}</div>`
            ).join('');
            const projChip = row.project
              ? `<span class="ledger-project-chip" data-project="${esc(row.project)}" style="cursor:pointer" onclick="window.__navigateProject('${esc(row.project)}')">${esc(row.project)}<button class="chip-remove" data-date="${esc(row.date)}" data-desc="${esc(row.description)}" data-remove-project="1" title="remove">×</button></span>` : '';
            const tagChips = (row.tags || []).map(t =>
              `<span class="ledger-tag-chip" data-tag="${esc(t)}">${esc(t)}<button class="chip-remove" data-date="${esc(row.date)}" data-desc="${esc(row.description)}" data-remove-tag="${esc(t)}" title="remove">×</button></span>`
            ).join('');
            const priChip = row.priority
              ? `<span class="ledger-pri-chip ledger-pri-${row.priority.toLowerCase()}">${esc(row.priority)}<button class="chip-remove" data-date="${esc(row.date)}" data-desc="${esc(row.description)}" data-remove-priority="1" title="remove">×</button></span>` : '';
            const taskChip = row.task_uuid
              ? `<span class="ledger-task-chip" onclick="window.__navigateTask('${esc(row.task_uuid)}')" title="go to task">→ task</span>` : '';
            const chipsHtml = (projChip || tagChips || priChip || taskChip)
              ? `<div class="ledger-chips">${projChip}${tagChips}${priChip}${taskChip}</div>` : '';
            const escDesc = esc(row.description);
            const escDate = esc(row.date);
            const escAmt  = esc(row.amount);
            const escProj = esc(row.project || '');
            const escTags = esc((row.tags || []).join(','));
            const escPri  = esc(row.priority || '');
            return `<div class="ledger-item" data-idx="${i}" data-project="${escProj}" data-tags="${escTags}" data-priority="${escPri}">
            <div class="ledger-row" tabindex="0" role="button" aria-expanded="false">
              <span class="tx-date">${escDate}</span>
              <span class="tx-desc">${escDesc}</span>
              <span class="tx-amt">${escAmt}</span>
              <button class="act-btn ledger-annotate-btn ledger-note-icon" data-idx="${i}" data-desc="${escDesc}" data-date="${escDate}" data-amt="${escAmt}" title="Add note">⊕</button>
            </div>
            <div class="ledger-detail hidden">
              <div class="ledger-detail-meta">
                <span class="ledger-detail-acct">${esc(row.account)}</span>
                ${chipsHtml}${noteHtml}
              </div>
              <div class="ledger-item-actions">
                <button class="act-btn ledger-journal-btn" data-idx="${i}" data-desc="${escDesc}" data-date="${escDate}" data-amt="${escAmt}" data-project="${escProj}" data-tags="${escTags}">→ journal</button>
                <button class="act-btn ledger-project-btn" data-idx="${i}" data-desc="${escDesc}" data-date="${escDate}">project</button>
                <button class="act-btn ledger-tags-btn" data-idx="${i}" data-desc="${escDesc}" data-date="${escDate}">tags</button>
                <button class="act-btn ledger-priority-btn" data-idx="${i}" data-desc="${escDesc}" data-date="${escDate}" data-priority="${escPri}">priority</button>
                <button class="act-btn ledger-task-btn" data-idx="${i}" data-desc="${escDesc}" data-date="${escDate}" data-amt="${escAmt}" data-project="${escProj}" data-tags="${escTags}">+ task</button>
                <button class="act-btn ledger-comm-btn" data-idx="${i}" data-desc="${escDesc}" data-date="${escDate}" data-amt="${escAmt}" data-project="${escProj}" data-tags="${escTags}" data-priority="${escPri}">+ community</button>
                <button class="act-btn ledger-archive-btn" data-idx="${i}" data-desc="${escDesc}" data-date="${escDate}">⊗ archive</button>
              </div>
            </div>
            <div class="ledger-action-row hidden" id="laction-${i}"></div>
          </div>`;
          }).join('');

        // Close all open action panels except the given idx
        const closeOtherPanels = (keepIdx) => {
          recDiv.querySelectorAll('.ledger-action-row').forEach(el => {
            if (el.id !== `laction-${keepIdx}`) { el.classList.add('hidden'); el.innerHTML = ''; }
          });
        };

        // Click primary row → expand/collapse detail
        recDiv.querySelectorAll('.ledger-row').forEach(row => {
          const toggleDetail = (e) => {
            if (e.target.closest('.ledger-annotate-btn')) return; // note icon handles its own click
            const item = row.closest('.ledger-item');
            const detail = item?.querySelector('.ledger-detail');
            if (!detail) return;
            const open = detail.classList.toggle('hidden');
            row.setAttribute('aria-expanded', String(!open));
          };
          row.addEventListener('click', toggleDetail);
          row.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') { e.preventDefault(); toggleDetail(e); }
            if (e.key === 'Escape') {
              const detail = row.closest('.ledger-item')?.querySelector('.ledger-detail');
              detail?.classList.add('hidden');
              row.setAttribute('aria-expanded', 'false');
            }
          });
        });

        // chip-remove: remove project/tag/priority from transaction
        recDiv.querySelectorAll('.chip-remove').forEach(btn => {
          btn.addEventListener('click', async (e) => {
            e.stopPropagation();
            const args = { date: btn.dataset.date, description: btn.dataset.desc };
            if (btn.dataset.removeProject) args.remove_project = true;
            if (btn.dataset.removePriority) args.remove_priority = true;
            if (btn.dataset.removeTag) args.remove_tags = [btn.dataset.removeTag];
            const res = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
              body: JSON.stringify({ action: 'ledger_untag', args }) });
            const d = await res.json();
            if (d.ok) { await loadLedger(); } else { toast(d.error || 'failed', 'error'); }
          });
        });

        // + note: append a ledger comment annotation
        recDiv.querySelectorAll('.ledger-annotate-btn').forEach(btn => {
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const idx = btn.dataset.idx;
            const panel = document.getElementById(`laction-${idx}`);
            if (!panel.classList.contains('hidden')) { panel.classList.add('hidden'); panel.innerHTML = ''; return; }
            closeOtherPanels(idx);
            panel.innerHTML = `<div class="task-detail-input"><input type="text" placeholder="note on: ${btn.dataset.desc}…" id="lann-input-${idx}" /><button class="btn-inline-submit" id="lann-btn-${idx}">add note</button></div>`;
            panel.classList.remove('hidden');
            document.getElementById(`lann-input-${idx}`).focus();
            const submit = async () => {
              const note = document.getElementById(`lann-input-${idx}`).value.trim();
              if (!note) return;
              await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
                body: JSON.stringify({ action: 'ledger_annotate', args: { date: btn.dataset.date, description: btn.dataset.desc, note } }) });
              await loadLedger();
            };
            document.getElementById(`lann-btn-${idx}`).addEventListener('click', submit);
            document.getElementById(`lann-input-${idx}`).addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
          });
        });

        // → journal: write a journal note about this transaction (carries project/tags)
        recDiv.querySelectorAll('.ledger-journal-btn').forEach(btn => {
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const idx = btn.dataset.idx;
            const panel = document.getElementById(`laction-${idx}`);
            if (!panel.classList.contains('hidden')) { panel.classList.add('hidden'); panel.innerHTML = ''; return; }
            closeOtherPanels(idx);
            panel.innerHTML = `<div class="task-detail-input"><input type="text" placeholder="journal note: ${btn.dataset.desc}…" id="ljnl-input-${idx}" /><span class="ljnl-jsel-slot"></span><button class="btn-inline-alt" id="ljnl-btn-${idx}">→ journal</button></div>`;
            panel.classList.remove('hidden');
            panel.querySelector('.ljnl-jsel-slot')?.appendChild(makeJournalSelect());
            document.getElementById(`ljnl-input-${idx}`).focus();
            const submit = async () => {
              const note = document.getElementById(`ljnl-input-${idx}`).value.trim();
              if (!note) return;
              const entry = `[ledger-entry:${btn.dataset.date}|${btn.dataset.desc}|${btn.dataset.amt}|${btn.dataset.project || ''}|${btn.dataset.tags || ''}|${note}]`;
              const jSel = panel.querySelector('.journal-target-select');
              await sendJournalNote(entry, jSel);
              document.getElementById(`ljnl-input-${idx}`).value = '';
              document.getElementById(`ljnl-input-${idx}`).placeholder = '✓ added to journal';
              setTimeout(() => { panel.classList.add('hidden'); panel.innerHTML = ''; }, 1500);
            };
            document.getElementById(`ljnl-btn-${idx}`).addEventListener('click', submit);
            document.getElementById(`ljnl-input-${idx}`).addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
          });
        });

        // project: set project tag on transaction
        recDiv.querySelectorAll('.ledger-project-btn').forEach(btn => {
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const idx = btn.dataset.idx;
            const panel = document.getElementById(`laction-${idx}`);
            if (!panel.classList.contains('hidden')) { panel.classList.add('hidden'); panel.innerHTML = ''; return; }
            closeOtherPanels(idx);
            panel.innerHTML = `<div class="task-detail-input"><input type="text" placeholder="project name…" id="lproj-input-${idx}" class="ledger-project-input" /><button class="btn-inline-submit" id="lproj-btn-${idx}">set project</button></div>`;
            panel.classList.remove('hidden');
            const inp = document.getElementById(`lproj-input-${idx}`);
            inp.focus();
            const submit = async () => {
              const project = inp.value.trim();
              if (!project) return;
              const res = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
                body: JSON.stringify({ action: 'ledger_tag', args: { date: btn.dataset.date, description: btn.dataset.desc, project, tags: [] } }) });
              const d = await res.json();
              if (d.ok) { await loadLedger(); }
              else { inp.placeholder = `error: ${d.error || 'failed'}`; inp.value = ''; }
            };
            document.getElementById(`lproj-btn-${idx}`).addEventListener('click', submit);
            inp.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
          });
        });

        // tags: add tag(s) to transaction
        recDiv.querySelectorAll('.ledger-tags-btn').forEach(btn => {
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const idx = btn.dataset.idx;
            const panel = document.getElementById(`laction-${idx}`);
            if (!panel.classList.contains('hidden')) { panel.classList.add('hidden'); panel.innerHTML = ''; return; }
            closeOtherPanels(idx);
            panel.innerHTML = `<div class="task-detail-input"><input type="text" placeholder="tag1, tag2…" id="ltag-input-${idx}" /><button class="btn-inline-submit" id="ltag-btn-${idx}">add tags</button></div>`;
            panel.classList.remove('hidden');
            const inp = document.getElementById(`ltag-input-${idx}`);
            inp.focus();
            const submit = async () => {
              const raw = inp.value.trim();
              if (!raw) return;
              const tags = raw.split(/[,\s]+/).filter(Boolean);
              const res = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
                body: JSON.stringify({ action: 'ledger_tag', args: { date: btn.dataset.date, description: btn.dataset.desc, project: '', tags } }) });
              const d = await res.json();
              if (d.ok) { await loadLedger(); }
              else { inp.placeholder = `error: ${d.error || 'failed'}`; inp.value = ''; }
            };
            document.getElementById(`ltag-btn-${idx}`).addEventListener('click', submit);
            inp.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
          });
        });

        // priority: set H/M/L priority on transaction
        recDiv.querySelectorAll('.ledger-priority-btn').forEach(btn => {
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const idx = btn.dataset.idx;
            const panel = document.getElementById(`laction-${idx}`);
            if (!panel.classList.contains('hidden')) { panel.classList.add('hidden'); panel.innerHTML = ''; return; }
            closeOtherPanels(idx);
            panel.innerHTML = `<div class="task-detail-input"><span class="lpri-label">Priority:</span>${['H','M','L'].map(p =>
              `<button class="act-btn lpri-pick${btn.dataset.priority === p ? ' lpri-active' : ''}" data-pri="${p}" data-idx="${idx}" data-date="${btn.dataset.date}" data-desc="${btn.dataset.desc}">${p}</button>`
            ).join('')}</div>`;
            panel.classList.remove('hidden');
            panel.querySelectorAll('.lpri-pick').forEach(pb => {
              pb.addEventListener('click', async (ev) => {
                ev.stopPropagation();
                const res = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
                  body: JSON.stringify({ action: 'ledger_tag', args: { date: pb.dataset.date, description: pb.dataset.desc, priority: pb.dataset.pri, tags: [] } }) });
                const d = await res.json();
                if (d.ok) { await loadLedger(); } else { toast(d.error || 'failed', 'error'); }
              });
            });
          });
        });

        // + task: create a task from this ledger item
        recDiv.querySelectorAll('.ledger-task-btn').forEach(btn => {
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const idx = btn.dataset.idx;
            const panel = document.getElementById(`laction-${idx}`);
            if (!panel.classList.contains('hidden')) { panel.classList.add('hidden'); panel.innerHTML = ''; return; }
            closeOtherPanels(idx);
            panel.innerHTML = `<div class="task-detail-input">
              <input type="text" id="ltask-input-${idx}" value="${btn.dataset.desc}" style="flex:1" />
              <input type="text" id="ltask-proj-${idx}" placeholder="project…" value="${btn.dataset.project || ''}" style="width:100px" />
              <input type="text" id="ltask-tags-${idx}" placeholder="tags…" value="${btn.dataset.tags || ''}" style="width:100px" />
              <button class="btn-inline-submit" id="ltask-btn-${idx}">create task</button>
            </div>`;
            panel.classList.remove('hidden');
            document.getElementById(`ltask-input-${idx}`).focus();
            const submit = async () => {
              const desc = document.getElementById(`ltask-input-${idx}`).value.trim();
              if (!desc) return;
              const proj = document.getElementById(`ltask-proj-${idx}`).value.trim();
              const tagsRaw = document.getElementById(`ltask-tags-${idx}`).value.trim();
              const tags = tagsRaw ? tagsRaw.split(/[,\s]+/).filter(Boolean) : [];
              const res = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
                body: JSON.stringify({ action: 'add', args: { description: desc, project: proj, tags } }) });
              const d = await res.json();
              if (d.ok && d.new_uuid) {
                // Tag the ledger transaction with the task UUID so the chip shows
                await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
                  body: JSON.stringify({ action: 'ledger_tag', args: { date: btn.dataset.date, description: btn.dataset.desc, task_uuid: d.new_uuid, tags: [] } }) });
                await loadLedger();
              } else {
                toast(d.error || (d.output || '').slice(0, 80) || 'task creation failed', 'error');
              }
            };
            document.getElementById(`ltask-btn-${idx}`).addEventListener('click', submit);
            document.getElementById(`ltask-input-${idx}`).addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); submit(); } });
          });
        });

        // + community: send ledger item to a community
        recDiv.querySelectorAll('.ledger-comm-btn').forEach(btn => {
          btn.addEventListener('click', async (e) => {
            e.stopPropagation();
            const idx = btn.dataset.idx;
            const panel = document.getElementById(`laction-${idx}`);
            if (!panel.classList.contains('hidden')) { panel.classList.add('hidden'); panel.innerHTML = ''; return; }
            panel.innerHTML = '<div class="skeleton-msg">Loading collections…</div>';
            panel.classList.remove('hidden');
            let names = [];
            try {
              const lr = await fetch('/data/community/list');
              const list = await lr.json();
              if (list.ok && Array.isArray(list.communities)) names = list.communities.map(c => c.name);
            } catch (_) {}
            if (!names.length) {
              panel.innerHTML = '<div class="empty-state" style="font-size:12px">No collections yet.</div>';
              return;
            }
            panel.innerHTML = `<div class="task-detail-input jcomm-row"><label class="community-select-wrap" style="flex:1;min-width:0;margin:0"><span class="community-toolbar-label">collection</span><select class="resource-select lcomm-sel" style="width:100%"></select></label><button type="button" class="btn-inline-submit lcomm-btn">add</button></div>`;
            const sel = panel.querySelector('.lcomm-sel');
            names.forEach(n => { const o = document.createElement('option'); o.value = n; o.textContent = n; sel.appendChild(o); });
            const submit = async () => {
              const comm = sel.value;
              if (!comm) return;
              const tagArr = (btn.dataset.tags || '').split(',').filter(Boolean);
              const res = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
                body: JSON.stringify({ action: 'community_add', args: {
                  community: comm, kind: 'ledger',
                  tx_date: btn.dataset.date, tx_desc: btn.dataset.desc,
                  tx_amt: btn.dataset.amt, tx_project: btn.dataset.project || '',
                  tx_tags: tagArr, tx_priority: btn.dataset.priority || '',
                } }) });
              const d = await res.json();
              if (d.ok) { toast('ledger item added to collection'); panel.classList.add('hidden'); panel.innerHTML = ''; }
              else { toast(d.error || 'add failed', 'error'); }
            };
            panel.querySelector('.lcomm-btn').addEventListener('click', submit);
          });
        });

        // ⊗ archive: comment out the ledger transaction
        recDiv.querySelectorAll('.ledger-archive-btn').forEach(btn => {
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const date = btn.dataset.date;
            const desc = btn.dataset.desc;
            confirmAction('archive transaction', `Comment out transaction <strong>${esc(date)} ${esc(desc)}</strong>? The lines will be preserved but prefixed with <code>;</code>.`, async () => {
              try {
                const r = await fetch('/action', { method: 'POST', headers: {'Content-Type':'application/json'},
                  body: JSON.stringify({ action: 'ledger_delete', args: { date, description: desc } }) });
                const d = await r.json();
                if (d.ok) { toast('transaction archived'); await loadLedger(); }
                else toast(d.error || 'archive failed', 'error');
              } catch (err) { toast('archive failed', 'error'); }
            });
          });
        });
      }

      // Re-render unit pills with auto-detected units from this load, then re-apply filter
      _lastDetectedUnits = _detectUnits(data.recent || []);
      _renderUnitPills(_lastDetectedUnits);
      _applyUnitFilter();

      // Ledger search
      document.getElementById('ledger-search')?.addEventListener('input', (e) => {
        const q = e.target.value.toLowerCase();
        document.querySelectorAll('.ledger-item').forEach(el => {
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
    } else if (section === 'lists') {
      const n = (data.items || []).length;
      const bn = data.basename || '—';
      statContextBar.textContent = `open: ${n}  ·  file: ${bn}`;
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
      statContextBar.textContent = `unified command interface · tasks · times · journals · ledgers · lists${aiPart}`;
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
    } else if (section === 'warlock') {
      statContextBar.textContent = 'task-warlock · graphical TaskWarrior UI · port 5001';
    } else if (section === 'questions') {
      statContextBar.textContent = 'templated question workflows';
    } else if (section === 'saves') {
      statContextBar.textContent = 'saves · knowledge base builder · peers8862';
    } else if (section === 'projects') {
      statContextBar.textContent = 'projects · tasks · journals · ledgers · times';
    } else if (section === 'ctrl') {
      statContextBar.textContent = 'global and profile settings';
    } else if (section === 'profile') {
      statContextBar.textContent = 'profile details and statistics';
    } else if (section === 'warrior') {
      statContextBar.textContent = 'global overview · all profiles';
    } else if (section === 'community') {
      statContextBar.textContent = 'shared collections · global .community db';
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

  async function loadWarlock() {
    const body = document.getElementById('warlock-body');
    body.innerHTML = '<div class="skeleton-msg">Loading warlock status…</div>';
    try {
      const res = await fetch('/data/warlock/status');
      const d = await res.json();
      const installBtn = document.getElementById('btn-warlock-install');
      const startBtn   = document.getElementById('btn-warlock-start');
      const stopBtn    = document.getElementById('btn-warlock-stop');
      if (!d.installed) {
        installBtn?.removeAttribute('disabled');
        startBtn?.setAttribute('disabled', '');
        stopBtn?.setAttribute('disabled', '');
        body.innerHTML = `<div class="warlock-status-row">
          <span class="warlock-badge not-installed">Not installed</span>
          <span class="warlock-hint">Run <code>ww browser warlock install</code> or click install below.</span>
        </div>`;
      } else {
        installBtn?.setAttribute('disabled', '');
        if (d.running) {
          startBtn?.setAttribute('disabled', '');
          stopBtn?.removeAttribute('disabled');
          body.innerHTML = `<div class="warlock-status-row">
            <span class="warlock-badge running">Running</span>
            <span class="warlock-profile">profile: ${esc(d.profile)}</span>
            <a class="warlock-open-link" href="http://localhost:${d.port}" target="_blank" rel="noopener">Open Warlock →</a>
          </div>
          <div class="warlock-meta">${esc(d.method)} · ${esc(d.tag)} · port ${d.port} · pid ${esc(d.pid)}</div>`;
        } else {
          startBtn?.removeAttribute('disabled');
          stopBtn?.setAttribute('disabled', '');
          body.innerHTML = `<div class="warlock-status-row">
            <span class="warlock-badge stopped">Stopped</span>
            <span class="warlock-hint">profile: (none active)</span>
          </div>
          <div class="warlock-meta">${esc(d.method)} · ${esc(d.tag)} · port ${d.port} · installed ${esc(d.installed_date)}</div>`;
        }
      }
    } catch (e) { renderError(body, `Warlock: ${e.message}`, loadWarlock); }
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

  function communityEntryKind(ref) {
    if (!ref) return 'other';
    if (ref.includes('.journal.')) return 'journal';
    if (ref.includes('.task.')) return 'task';
    if (ref.includes('.ledger.')) return 'ledger';
    return 'other';
  }

  function communityCitationLine(entry) {
    const cap = entry.captured_state || {};
    const k = communityEntryKind(entry.source_ref);
    if (k === 'task') return cap.description || entry.source_ref;
    if (k === 'journal') {
      const b = cap.body || cap.text || '';
      return b ? String(b).split('\n')[0].slice(0, 120) : entry.source_ref;
    }
    if (k === 'ledger') return `${cap.date || ''} ${cap.description || entry.source_ref}`.trim();
    return entry.source_ref;
  }

  function wireCommunityJournalForms(container) {
    container.querySelectorAll('.community-journal-form').forEach(form => {
      const entryId = parseInt(form.dataset.entryId);
      const kind = form.dataset.kind || '';
      const sourceSlug = form.dataset.sourceSlug || '';
      const input = form.querySelector('.community-jrnl-input');

      async function doComment() {
        const text = (input?.value || '').trim();
        if (!text) return;
        try {
          const r = await fetch('/action', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'community_comment_save', args: { entry_id: entryId, entry: text } }),
          });
          const d = await r.json();
          if (d.ok) { toast('✓ comment saved'); if (input) input.value = ''; await loadCommunityEntries(); }
          else toast(d.error || 'failed', 'error');
        } catch (err) { toast(err.message, 'error'); }
      }

      async function doJournalAction() {
        const text = (input?.value || '').trim();
        if (!text) return;
        if (kind === 'journal' && sourceSlug) {
          try {
            const r = await fetch('/action', {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ action: 'journal_annotate', args: { date_slug: sourceSlug, text } }),
            });
            const d = await r.json();
            if (d.ok) { toast('✓ source annotated'); if (input) input.value = ''; await loadCommunityEntries(); }
            else toast(d.error || 'annotate failed', 'error');
          } catch (err) { toast(err.message, 'error'); }
        } else if (kind === 'ledger') {
          // Add a note annotation to the source ledger entry
          const ledgerParts = (form.closest('.community-entry-card')?.querySelector('code')?.textContent || '').split('.ledger.')[1] || '';
          const txDate = ledgerParts.split('|')[0] || '';
          const txDesc = ledgerParts.split('|').slice(1).join('|') || '';
          try {
            const r = await fetch('/action', {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ action: 'ledger_annotate', args: { date: txDate, description: txDesc, note: text } }),
            });
            const d = await r.json();
            if (d.ok) { toast('✓ ledger noted'); if (input) input.value = ''; await loadCommunityEntries(); }
            else toast(d.error || 'failed', 'error');
          } catch (err) { toast(err.message, 'error'); }
        } else {
          // Task (or unknown): structured journal entry via community_journal_entry
          try {
            const r = await fetch('/action', {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ action: 'community_journal_entry', args: { entry_id: entryId, entry: text } }),
            });
            const d = await r.json();
            if (d.ok) { toast('✓ journal entry written'); if (input) input.value = ''; await loadCommunityEntries(); }
            else toast(d.error || 'failed', 'error');
          } catch (err) { toast(err.message, 'error'); }
        }
      }

      form.querySelector('.community-jrnl-save')?.addEventListener('click', doComment);
      form.addEventListener('submit', (e) => { e.preventDefault(); doJournalAction(); });
    });

    // Remove entry buttons
    container.querySelectorAll('.btn-entry-remove').forEach(btn => {
      btn.addEventListener('click', async () => {
        const eid = btn.dataset.entryId;
        const comm = btn.dataset.community;
        if (!confirm('Remove this entry from the collection?')) return;
        const r = await fetch('/action', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'community_remove_entry', args: { community: comm, entry_id: parseInt(eid) } }),
        });
        const d = await r.json();
        if (d.ok) { toast('entry removed'); await loadCommunityEntries(); }
        else toast(d.error || 'remove failed', 'error');
      });
    });

    // Refresh entry buttons (task entries only)
    container.querySelectorAll('.btn-entry-refresh').forEach(btn => {
      btn.addEventListener('click', async () => {
        const eid = btn.dataset.entryId;
        const comm = btn.dataset.community;
        btn.disabled = true; btn.textContent = '↻…';
        const r = await fetch('/action', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'community_refresh_entry', args: { community: comm, entry_id: parseInt(eid) } }),
        });
        const d = await r.json();
        btn.disabled = false; btn.textContent = '↻ refresh';
        if (d.ok) { toast('snapshot refreshed'); await loadCommunityEntries(); }
        else toast(d.error || 'refresh failed', 'error');
      });
    });

    // Copy-back buttons on comments (all source kinds: task, journal, ledger)
    container.querySelectorAll('.btn-cmt-copyback').forEach(btn => {
      btn.addEventListener('click', () => {
        const cid = parseInt(btn.dataset.commentId);
        const eid = parseInt(btn.dataset.entryId);
        const rawBody = btn.dataset.body;
        const kind = btn.dataset.kind || 'task';
        const commName = communityState.selected || '';

        // Show approve/deny modal with community prefix toggle
        document.getElementById('ww-comm-copyback-modal')?.remove();
        const overlay = document.createElement('div');
        overlay.id = 'ww-comm-copyback-modal';
        overlay.className = 'confirm-overlay';
        const kindLabel = kind === 'task' ? 'source task' : kind === 'journal' ? 'source journal entry' : 'source ledger entry';
        overlay.innerHTML = `<div class="confirm-dialog">
          <div class="confirm-title">Copy annotation to ${kindLabel}?</div>
          <div class="confirm-body" style="margin-bottom:8px;font-size:12px;color:var(--muted)">${esc(rawBody)}</div>
          <label class="comm-prefix-toggle-row" style="display:flex;align-items:center;gap:8px;font-size:11px;margin-bottom:12px;cursor:pointer">
            <input type="checkbox" id="comm-prefix-chk" checked />
            <span>Include community prefix <code>[community:${esc(commName)}]</code></span>
          </label>
          <div class="confirm-actions">
            <button class="act-btn confirm-ok-btn">copy to ${kindLabel}</button>
            <button class="btn-inline-alt confirm-cancel-btn">deny</button>
          </div>
        </div>`;
        document.body.appendChild(overlay);
        const close = () => overlay.remove();
        overlay.querySelector('.confirm-cancel-btn').addEventListener('click', close);
        overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });
        overlay.querySelector('.confirm-ok-btn').addEventListener('click', async () => {
          close();
          const usePrefix = overlay.querySelector('#comm-prefix-chk')?.checked ?? true;
          const annotationBody = usePrefix ? `[community:${commName}] ${rawBody}` : rawBody;
          btn.disabled = true; btn.textContent = '…';
          if (kind === 'task') {
            const r = await fetch('/action', {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ action: 'community_comment_copy_back', args: { comment_id: cid, entry_id: eid, body: annotationBody } }),
            });
            const d = await r.json();
            if (d.ok) { toast('copied to task'); await loadCommunityEntries(); }
            else { btn.disabled = false; btn.textContent = '→ task'; toast(d.error || 'copy-back failed', 'error'); }
          } else if (kind === 'journal') {
            const slug = btn.dataset.sourceSlug;
            const r = await fetch('/action', {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ action: 'journal_annotate', args: { date_slug: slug, text: annotationBody } }),
            });
            const d = await r.json();
            if (d.ok) { toast('annotated source journal entry'); await loadCommunityEntries(); }
            else { btn.disabled = false; btn.textContent = '→ journal'; toast(d.error || 'failed', 'error'); }
          } else if (kind === 'ledger') {
            const txDate = btn.dataset.ledgerDate;
            const txDesc = btn.dataset.ledgerDesc;
            const r = await fetch('/action', {
              method: 'POST', headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ action: 'ledger_annotate', args: { date: txDate, description: txDesc, note: annotationBody } }),
            });
            const d = await r.json();
            if (d.ok) { toast('annotated source ledger entry'); await loadCommunityEntries(); }
            else { btn.disabled = false; btn.textContent = '→ ledger'; toast(d.error || 'failed', 'error'); }
          }
        });
        overlay.querySelector('.confirm-ok-btn').focus();
      });
    });

    // + task from comment: create task with comment body as description
    container.querySelectorAll('.btn-cmt-newtask').forEach(btn => {
      btn.addEventListener('click', async () => {
        const body = btn.dataset.body;
        if (!body) return;
        btn.disabled = true; btn.textContent = '…';
        const r = await fetch('/action', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'add', args: { description: body } }),
        });
        const d = await r.json();
        if (d.ok) {
          toast('task created');
          btn.textContent = '✓ task';
          if (d.new_uuid) { btn.onclick = () => window.__navigateTask(d.new_uuid); btn.disabled = false; btn.title = d.new_uuid; }
        } else {
          btn.disabled = false; btn.textContent = '+ task'; toast(d.error || 'failed', 'error');
        }
      });
    });

    // + journal from comment: create new journal entry from comment body
    container.querySelectorAll('.btn-cmt-newjournal').forEach(btn => {
      btn.addEventListener('click', async () => {
        const body = btn.dataset.body;
        if (!body) return;
        btn.disabled = true; btn.textContent = '…';
        const r = await fetch('/action', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'journal_add', args: { entry: body } }),
        });
        const d = await r.json();
        if (d.ok) { toast('journal entry created'); btn.textContent = '✓ journal'; }
        else { btn.disabled = false; btn.textContent = '+ journal'; toast(d.error || 'failed', 'error'); }
      });
    });
  }

  function renderCommunityBody() {
    const body = document.getElementById('community-body');
    if (!body) return;
    const view = communityState.view;
    const all = (communityState.entries || []).slice();

    if (view === 'comments') {
      const rows = [];
      all.forEach(en => {
        (en.comments || []).forEach(c => {
          rows.push({ comment: c, entry: en });
        });
      });
      rows.sort((a, b) => String(b.comment.created_at).localeCompare(String(a.comment.created_at)));
      body.innerHTML = rows.length
        ? rows.map(r => `<div class="community-comment-row">
            <div class="community-comment-meta">${esc(r.comment.created_at)} · ${esc(communityCitationLine(r.entry))}</div>
            <div class="community-comment-body${journalMdRender ? ' md-on' : ''}">${renderEntryBody(r.comment.body)}</div>
          </div>`).join('')
        : '<div class="empty-state">No comments yet</div>';
      wireCommunityJournalForms(body);
      return;
    }

    let entries = all;
    if (view === 'journal') entries = all.filter(e => communityEntryKind(e.source_ref) === 'journal');
    else if (view === 'tasks') entries = all.filter(e => communityEntryKind(e.source_ref) === 'task');
    entries.sort((a, b) => String(b.added_at).localeCompare(String(a.added_at)));

    body.innerHTML = entries.length
      ? entries.map(en => renderCommunityEntryCard(en, view)).join('')
      : '<div class="empty-state">No entries in this view</div>';
    wireCommunityJournalForms(body);
  }

  function renderCommunityEntryCard(en, view) {
    const kind = communityEntryKind(en.source_ref);
    const cap = en.captured_state || {};
    let main = '';
    if (kind === 'task') {
      const taskUuidRaw = en.source_ref.includes('.task.') ? en.source_ref.split('.task.')[1] : '';
      const taskNavBtn = taskUuidRaw
        ? `<button class="ctn-ref-btn" onclick="window.__navigateTask('${esc(taskUuidRaw)}')">task</button>`
        : '';
      const capTagsArr = Array.isArray(cap.tags) ? cap.tags : (cap.tags ? String(cap.tags).split(',').map(t => t.trim()).filter(Boolean) : []);
      const capMetaLine = (cap.project || capTagsArr.length)
        ? `<div class="comm-entry-meta-row">${cap.project ? `<span class="badge-project" style="cursor:pointer" onclick="window.__navigateProject('${esc(cap.project)}')">${esc(cap.project)}</span>` : ''}${capTagsArr.map(t => `<span class="comm-tag-pill">${esc(t)}</span>`).join('')}</div>`
        : '';
      const metaParts = [cap.status, cap.priority ? `pri:${cap.priority}` : '', cap.due ? `due:${cap.due.slice(0,10)}` : ''].filter(Boolean);
      main = `<div class="community-task-slim">
        <div class="comm-entry-titlerow"><span class="community-task-desc">${esc(cap.description || '—')}</span>${taskNavBtn}</div>
        ${capMetaLine}
        ${metaParts.length ? `<div class="community-task-meta">${esc(metaParts.join(' · '))}</div>` : ''}
      </div>`;
      const live = en.live_state;
      if (live) {
        const DIFF_KEYS = ['status', 'priority', 'due', 'scheduled', 'wait', 'project', 'tags', 'description'];
        const diffs = DIFF_KEYS.filter(k => JSON.stringify(cap[k]) !== JSON.stringify(live[k]));
        if (diffs.length) {
          const rows = diffs.map(k => {
            const was = cap[k] != null ? String(Array.isArray(cap[k]) ? cap[k].join(', ') : cap[k]) : '—';
            const now = live[k] != null ? String(Array.isArray(live[k]) ? live[k].join(', ') : live[k]) : '—';
            return `<tr><td class="diff-key">${esc(k)}</td><td class="diff-was">${esc(was)}</td><td class="diff-arrow">→</td><td class="diff-now">${esc(now)}</td></tr>`;
          }).join('');
          main += `<div class="community-task-diff"><span class="diff-label">changed since captured</span><table class="diff-table">${rows}</table></div>`;
        }
      }
    } else if (kind === 'journal') {
      const bodyTxt = cap.body || cap.text || '—';
      main = `<div class="community-journal-body${journalMdRender ? ' md-on' : ''}">${renderEntryBody(bodyTxt)}</div>`;
    } else if (kind === 'ledger') {
      const txTagsArr = Array.isArray(cap.tags) ? cap.tags : (cap.tags ? String(cap.tags).split(',').map(t => t.trim()).filter(Boolean) : []);
      const txTagsHtml = txTagsArr.length ? txTagsArr.map(t => `<span class="comm-tag-pill">${esc(t)}</span>`).join('') : '';
      const txProjHtml = cap.project ? `<span class="badge-project">${esc(cap.project)}</span>` : '';
      const txPriHtml  = cap.priority ? `<span class="ledger-pri-chip ledger-pri-${cap.priority.toLowerCase()}">${esc(cap.priority)}</span>` : '';
      main = `<div class="community-task-slim">
        <div class="comm-entry-titlerow"><span class="community-task-desc">${esc(cap.description || '—')}</span><span class="ctn-meta-pill">${esc(cap.amount || '')}</span><span class="muted" style="font-size:11px">${esc(cap.date || '')}</span></div>
        ${txProjHtml || txTagsHtml || txPriHtml ? `<div class="ledger-chips" style="padding:2px 0">${txProjHtml}${txTagsHtml}${txPriHtml}</div>` : ''}
      </div>`;
    } else {
      main = `<pre class="community-raw">${esc(JSON.stringify(cap, null, 2))}</pre>`;
    }
    const isTask = kind === 'task';

    // Community-level project + tags (separate from the captured state)
    const commTagsArr = en.community_tags
      ? en.community_tags.split(',').map(t => t.trim()).filter(Boolean)
      : [];
    const commProjBadge = (en.community_project || commTagsArr.length)
      ? `<div class="comm-entry-meta-row">${en.community_project ? `<span class="badge-project" style="cursor:pointer" onclick="window.__navigateProject('${esc(en.community_project)}')">${esc(en.community_project)}</span>` : ''}${commTagsArr.map(t => `<span class="comm-tag-pill">${esc(t)}</span>`).join('')}</div>`
      : '';
    const commTagsLine = '';
    const commPriority = en.community_priority
      ? `<span class="pri-dot pri-${(en.community_priority||'').toLowerCase()}">${esc(en.community_priority)}</span> `
      : '';

    const sourceSlugForCmt = kind === 'journal' ? (en.source_ref.split('.journal.')[1] || '') : '';
    const ledgerDateForCmt = kind === 'ledger' ? ((en.source_ref.split('.ledger.')[1] || '').split('|')[0] || '') : '';
    const ledgerDescForCmt = kind === 'ledger' ? ((en.source_ref.split('.ledger.')[1] || '').split('|').slice(1).join('|') || '') : '';
    const ann = (en.comments || []).length
      ? `<div class="community-annotations"><div class="ann-h">${view === 'journal' ? 'annotations' : 'comments'}</div>${en.comments.map(c => {
          let copyBtn = '';
          if (!c.copied_to_source) {
            if (isTask) {
              copyBtn = `<button class="btn-cmt-copyback" data-comment-id="${c.id}" data-entry-id="${en.id}" data-body="${esc(c.body)}" data-kind="task" title="Copy to source task">→ task</button>`;
            } else if (kind === 'journal' && sourceSlugForCmt) {
              copyBtn = `<button class="btn-cmt-copyback" data-comment-id="${c.id}" data-entry-id="${en.id}" data-body="${esc(c.body)}" data-kind="journal" data-source-slug="${esc(sourceSlugForCmt)}" title="Annotate source journal entry">→ journal</button>`;
            } else if (kind === 'ledger' && ledgerDateForCmt) {
              copyBtn = `<button class="btn-cmt-copyback" data-comment-id="${c.id}" data-entry-id="${en.id}" data-body="${esc(c.body)}" data-kind="ledger" data-ledger-date="${esc(ledgerDateForCmt)}" data-ledger-desc="${esc(ledgerDescForCmt)}" title="Annotate source ledger entry">→ ledger</button>`;
            }
            copyBtn += ` <button class="btn-cmt-newtask" data-body="${esc(c.body)}" title="Create new task from this comment">+ task</button>`;
            copyBtn += ` <button class="btn-cmt-newjournal" data-body="${esc(c.body)}" data-entry-id="${en.id}" title="Create new journal entry from this comment">+ journal</button>`;
          } else {
            copyBtn = `<span class="cmt-copied-badge">↩ copied</span>`;
          }
          return `<div class="community-cmt"><span class="community-cmt-t">${esc(c.created_at)}</span> <span class="${journalMdRender ? 'md-on' : ''}">${renderMdInline(c.body)}</span> <span class="cmt-actions">${copyBtn}</span></div>`;
        }).join('')}</div>`
      : '';
    const actionLabel = kind === 'journal' ? '-> annotate' : (kind === 'ledger' ? '-> note' : '-> journal');
    const actionPlaceholder = kind === 'journal' ? 'annotate this journal entry...' : (kind === 'ledger' ? 'note about this ledger item...' : 'note about this task..');
    const journalForm = `<div class="community-entry-journal">
      <form class="community-journal-form" data-entry-id="${en.id}" data-kind="${kind}" data-source-slug="${esc(sourceSlugForCmt)}" onsubmit="return false;">
        <input type="text" class="community-jrnl-input" placeholder="${esc(actionPlaceholder)}" autocomplete="off" />
        <button type="button" class="btn-inline-alt community-jrnl-save">+ comment</button>
        <button type="submit" class="btn-inline-submit community-jrnl-journal">${esc(actionLabel)}</button>
      </form>
    </div>`;
    const refreshBtn = isTask
      ? `<button class="btn-entry-action btn-entry-refresh" data-entry-id="${en.id}" data-community="${esc(communityState.selected)}" title="Re-snapshot current task state">↻ refresh</button>`
      : '';
    const entryActions = `<div class="community-entry-actions">
      ${refreshBtn}
      <button class="btn-entry-action btn-entry-remove" data-entry-id="${en.id}" data-community="${esc(communityState.selected)}" title="Remove from this collection">× remove</button>
    </div>`;
    return `<div class="community-entry-card" data-id="${en.id}">
      <div class="community-entry-head"><code>${esc(en.source_ref)}</code> · <span class="muted">${esc(en.added_at)}</span>${commPriority}${entryActions}</div>
      ${commProjBadge}${commTagsLine}
      ${main}
      ${ann}
      ${journalForm}
    </div>`;
  }

  async function loadCommunityEntries() {
    const body = document.getElementById('community-body');
    const name = communityState.selected;
    if (!name) return;
    body.innerHTML = '<div class="skeleton-msg">Loading…</div>';
    try {
      const res = await fetch(`/data/community/${encodeURIComponent(name)}?view=${encodeURIComponent(communityState.view)}`);
      const d = await res.json();
      if (!d.ok) {
        body.innerHTML = `<div class="empty-state">${esc(d.error || 'failed to load')}</div>`;
        communityState.entries = [];
        return;
      }
      communityState.entries = d.entries || [];
      renderCommunityBody();
    } catch (e) {
      renderError(body, e.message, loadCommunityEntries);
    }
  }

  async function postAddJournalToCommunity(comm, journalDate) {
    const jn = (profileResources && profileResources.active && profileResources.active.journal) || 'default';
    const r = await fetch('/action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        action: 'community_add',
        args: { community: comm, kind: 'journal', journal_date: journalDate, journal: jn },
      }),
    });
    return r.json();
  }

  async function refreshCommunityPickers() {
    const taskSel = document.getElementById('community-task-pick');
    const jSel = document.getElementById('community-journal-pick');
    if (!taskSel || !jSel) return;
    taskSel.innerHTML = '<option value="">— pick task —</option>';
    jSel.innerHTML = '<option value="">— pick journal entry —</option>';
    try {
      const tr = await fetch('/data/tasks');
      const td = await tr.json();
      if (td.ok && Array.isArray(td.tasks)) {
        td.tasks.forEach(t => {
          const o = document.createElement('option');
          o.value = String(t.id);
          const d = (t.description || '').slice(0, 200);
          o.textContent = `${t.id} · ${d.slice(0, 72)}${d.length > 72 ? '…' : ''}`;
          taskSel.appendChild(o);
        });
      }
    } catch (_) {}
    try {
      const jr = await fetch('/data/journal');
      const jd = await jr.json();
      if (jd.ok && Array.isArray(jd.entries)) {
        jd.entries.forEach(en => {
          const o = document.createElement('option');
          o.value = en.date;
          const preview = (en.body || '').split('\n')[0].slice(0, 52);
          o.textContent = `${en.date} · ${preview}${(en.body || '').split('\n')[0].length > 52 ? '…' : ''}`;
          jSel.appendChild(o);
        });
        if (jSel.options.length > 1) jSel.selectedIndex = 1; // auto-select most recent entry
      }
    } catch (_) {}
  }

  async function loadCommunity() {
    const body = document.getElementById('community-body');
    const sel = document.getElementById('community-select');
    try {
      const lr = await fetch('/data/community/list');
      const list = await lr.json();
      if (!list.ok) {
        renderError(body, list.error || 'list failed', loadCommunity);
        return;
      }
      const comms = list.communities || [];
      communityState.names = comms.map(c => c.name);
      communityState.meta = Object.fromEntries(comms.map(c => [c.name, c]));
      const prev = communityState.selected;
      sel.innerHTML = comms.length
        ? comms.map(c => `<option value="${c.name}">${esc(c.name)} (${c.entry_count})</option>`).join('')
        : '<option value="">— no communities —</option>';
      await refreshCommunityPickers();
      if (!communityState.names.length) {
        communityState.selected = '';
        communityState.entries = [];
        body.innerHTML = '<div class="empty-state">No communities yet. Create one above or run <code>ww community create &lt;name&gt;</code> in the terminal.</div>';
        return;
      }
      if (!prev || !communityState.names.includes(prev)) communityState.selected = communityState.names[0];
      else communityState.selected = prev;
      sel.value = communityState.selected;
      _updateMgmtBar(communityState.selected);
      await loadCommunityEntries();
    } catch (e) {
      renderError(body, `Community: ${e.message}`, loadCommunity);
    }
  }

  function _updateMgmtBar(name) {
    const meta = (communityState.meta || {})[name] || {};
    const descEl = document.getElementById('community-mgmt-desc-text');
    if (descEl) descEl.textContent = meta.description || '';
    const archBtn = document.getElementById('btn-comm-archive');
    if (archBtn) archBtn.textContent = meta.archived ? 'unarchive' : 'archive';
  }

  function initCommunityPanel() {
    const tabs = document.getElementById('community-view-tabs');
    const sel = document.getElementById('community-select');
    const form = document.getElementById('community-create-form');
    tabs?.addEventListener('click', (e) => {
      const t = e.target.closest('.community-tab');
      if (!t) return;
      tabs.querySelectorAll('.community-tab').forEach(x => x.classList.remove('active'));
      t.classList.add('active');
      communityState.view = t.dataset.view || 'unified';
      renderCommunityBody();
    });
    sel?.addEventListener('change', async () => {
      communityState.selected = sel.value;
      _updateMgmtBar(sel.value);
      await loadCommunityEntries();
    });
    form?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(form);
      const raw = (fd.get('name') || '').toString().trim();
      const desc = (fd.get('description') || '').toString().trim();
      if (!raw) return;
      const r = await fetch('/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'community_create', args: { name: raw } }),
      });
      const rd = await r.json();
      if (!rd.ok) { toast(rd.error || 'create failed', 'error'); return; }
      if (desc) {
        await fetch('/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'community_describe', args: { name: raw, description: desc } }),
        });
      }
      toast(`collection '${raw}' created`);
      form.reset();
      communityState.selected = raw;
      await loadCommunity();
    });

    // Management bar — describe / rename / archive
    let _mgmtMode = null;
    const mgmtInline = document.getElementById('community-mgmt-inline');
    const mgmtInput = document.getElementById('community-mgmt-input');

    const _showMgmtInline = (mode, placeholder, currentVal) => {
      _mgmtMode = mode;
      if (mgmtInline) mgmtInline.classList.remove('hidden');
      if (mgmtInput) { mgmtInput.placeholder = placeholder; mgmtInput.value = currentVal || ''; mgmtInput.focus(); }
    };
    const _hideMgmtInline = () => {
      _mgmtMode = null;
      if (mgmtInline) mgmtInline.classList.add('hidden');
      if (mgmtInput) mgmtInput.value = '';
    };

    document.getElementById('btn-comm-describe')?.addEventListener('click', () => {
      const desc = document.getElementById('community-mgmt-desc-text')?.textContent || '';
      _showMgmtInline('describe', 'community description…', desc);
    });
    document.getElementById('btn-comm-rename')?.addEventListener('click', () => {
      _showMgmtInline('rename', 'new collection name…', communityState.selected);
    });
    document.getElementById('btn-comm-archive')?.addEventListener('click', async () => {
      const name = communityState.selected;
      if (!name) return;
      const meta = (communityState.meta || {})[name] || {};
      const isArchived = meta.archived;
      const action = isArchived ? 'community_unarchive' : 'community_archive';
      const msg = isArchived
        ? `Restore collection '${name}'?`
        : `Archive collection '${name}'? It will be hidden from the list but data is preserved.`;
      if (!confirm(msg)) return;
      const r = await fetch('/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action, args: { name } }),
      });
      const d = await r.json();
      if (d.ok) { toast(isArchived ? `'${name}' restored` : `'${name}' archived`); await loadCommunity(); }
      else toast(d.error || 'failed', 'error');
    });
    document.getElementById('btn-comm-mgmt-cancel')?.addEventListener('click', _hideMgmtInline);
    document.getElementById('btn-comm-mgmt-ok')?.addEventListener('click', async () => {
      const val = mgmtInput?.value.trim();
      const name = communityState.selected;
      if (!name || !_mgmtMode) return;
      if (_mgmtMode === 'describe') {
        const r = await fetch('/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'community_describe', args: { name, description: val } }),
        });
        const d = await r.json();
        if (d.ok) { toast('description saved'); _hideMgmtInline(); await loadCommunity(); }
        else toast(d.error || 'failed', 'error');
      } else if (_mgmtMode === 'rename') {
        if (!val) { toast('name required', 'error'); return; }
        const r = await fetch('/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'community_rename', args: { old_name: name, new_name: val } }),
        });
        const d = await r.json();
        if (d.ok) { toast(`renamed to '${val}'`); _hideMgmtInline(); communityState.selected = val; await loadCommunity(); }
        else toast(d.error || 'rename failed', 'error');
      }
    });
    mgmtInput?.addEventListener('keydown', e => {
      if (e.key === 'Enter') document.getElementById('btn-comm-mgmt-ok')?.click();
      if (e.key === 'Escape') _hideMgmtInline();
    });

    document.getElementById('btn-community-add-task')?.addEventListener('click', async () => {
      const comm = document.getElementById('community-select')?.value;
      const tid = document.getElementById('community-task-pick')?.value;
      if (!comm) { toast('pick a collection first', 'error'); return; }
      if (!tid) { toast('pick a task', 'error'); return; }
      const args = {
        community: comm, kind: 'task', task_id: tid,
        community_project: (document.getElementById('comm-t-project')?.value || '').trim() || undefined,
        community_tags: (document.getElementById('comm-t-tags')?.value || '').trim() || undefined,
        community_priority: (document.getElementById('comm-t-priority')?.value || '').trim() || undefined,
      };
      const r = await fetch('/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'community_add', args }),
      });
      const d = await r.json();
      if (d.ok) {
        toast('task added to collection');
        await loadCommunityEntries();
        await refreshCommunityPickers();
      } else {
        toast(d.error || 'add failed', 'error');
      }
    });

    document.getElementById('btn-community-add-journal')?.addEventListener('click', async () => {
      const comm = document.getElementById('community-select')?.value;
      const dateHdr = document.getElementById('community-journal-pick')?.value;
      if (!comm) { toast('pick a collection first', 'error'); return; }
      if (!dateHdr) { toast('pick a journal entry', 'error'); return; }
      const jn = (profileResources && profileResources.active && profileResources.active.journal) || 'default';
      const r = await fetch('/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'community_add',
          args: {
            community: comm, kind: 'journal', journal_date: dateHdr, journal: jn,
            community_project: (document.getElementById('comm-j-project')?.value || '').trim() || undefined,
            community_tags: (document.getElementById('comm-j-tags')?.value || '').trim() || undefined,
            community_priority: (document.getElementById('comm-j-priority')?.value || '').trim() || undefined,
          },
        }),
      });
      const d = await r.json();
      if (d.ok) {
        toast('journal entry added to collection');
        await loadCommunityEntries();
      } else {
        toast(d.error || 'add failed', 'error');
      }
    });
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

  async function applyNavOrder() {
    // Reorder sidebar service buttons according to /data/nav-config (nav.yaml).
    try {
      const r = await fetch('/data/nav-config');
      const cfg = await r.json();
      if (!cfg.ok || !Array.isArray(cfg.services)) return;
      const navEl = document.getElementById('sidebar-nav');
      if (!navEl) return;
      // Find the services group label
      const labels = Array.from(navEl.querySelectorAll('.nav-group-label'));
      const servicesLabel = labels.find(l => l.textContent.trim() === 'services');
      if (!servicesLabel) return;
      // Collect all nav-item buttons in the services section
      // (everything after the services label until end or a non-nav-item sibling)
      const allServiceBtns = {};
      let node = servicesLabel.nextElementSibling;
      while (node) {
        if (node.classList.contains('nav-item') && node.dataset.section) {
          allServiceBtns[node.dataset.section] = node;
        }
        node = node.nextElementSibling;
      }
      // Reorder: apply config order first, then any unlisted items after
      const orderedSections = cfg.services;
      const listed = new Set(orderedSections);
      const extra = Object.keys(allServiceBtns).filter(k => !listed.has(k));
      const finalOrder = [...orderedSections, ...extra];
      let insertAfter = servicesLabel;
      finalOrder.forEach(section => {
        const btn = allServiceBtns[section];
        if (!btn) return;
        insertAfter.after(btn);
        insertAfter = btn;
      });
    } catch (_) {}
  }

  async function loadProjects() {
    const body = document.getElementById('projects-body');
    try {
      const res = await fetch('/data/projects');
      const data = await res.json();
      const projects = data.projects || {};
      const names = Object.keys(projects);
      if (!names.length) {
        body.innerHTML = '<div class="empty-state">No projects yet. Tasks with a project: field will appear here automatically, or define one above.</div>';
        return;
      }
      body.innerHTML = names.map(name => {
        const p = projects[name];
        const t = p.tasks || {};
        const j = p.journal || {};
        const l = p.ledger || {};
        const master = t.master;
        const nxt = t.next;
        const total = (t.pending || 0) + (t.done || 0);
        const pct = total ? Math.round((t.done / total) * 100) : 0;

        const masterBadge = master
          ? `<span class="proj-master-badge" title="master task: ${esc(master.description)}">⬡ master</span>`
          : `<button class="proj-create-master-btn btn-inline-alt" data-project="${esc(name)}">+ master task</button>`;

        const taskBar = total
          ? `<div class="proj-progress-wrap" title="${t.done}/${total} done">
               <div class="proj-progress-bar" style="width:${pct}%"></div>
             </div>`
          : '';

        const activeIndicator = t.active
          ? `<span class="proj-active-dot" title="${t.active} active"></span>`
          : '';

        const nextRow = nxt
          ? `<div class="proj-next-row">
               <span class="proj-next-label">next</span>
               <span class="proj-next-desc">${esc(nxt.description)}</span>
               <span class="proj-next-urg">${nxt.urgency}</span>
             </div>`
          : '';

        const journalRow = j.count
          ? `<div class="proj-stat-row">
               <span class="proj-stat-icon">╱</span>
               <span class="proj-stat-val">${j.count} journal entr${j.count === 1 ? 'y' : 'ies'}</span>
               ${j.last_date ? `<span class="proj-stat-muted">· last ${j.last_date.split(' ')[0]}</span>` : ''}
             </div>`
          : '';

        const ledgerAmts = (l.amounts || []).join('  ');
        const ledgerRow = l.count
          ? `<div class="proj-stat-row">
               <span class="proj-stat-icon">═</span>
               <span class="proj-stat-val">${l.count} ledger tx</span>
               ${ledgerAmts ? `<span class="proj-stat-muted">· ${esc(ledgerAmts)}</span>` : ''}
             </div>`
          : '';

        const timewRow = `<div class="proj-stat-row proj-item-filter-row">
          <input type="text" class="proj-item-filter" data-project="${esc(name)}" placeholder="filter items…" autocomplete="off" />
        </div>`;

        return `<div class="proj-card" data-project="${esc(name)}" data-expanded="false">
          <div class="proj-card-header">
            <span class="proj-name">${esc(name)}</span>
            ${activeIndicator}
            ${masterBadge}
            <span class="proj-expand-chevron">›</span>
          </div>
          ${p.description ? `<div class="proj-desc">${esc(p.description)}</div>` : ''}
          <div class="proj-task-summary">
            <span class="proj-task-counts">
              ${t.pending || 0} pending · ${t.done || 0} done
              ${t.active ? ` · <span class="proj-active-text">${t.active} active</span>` : ''}
            </span>
            ${taskBar}
          </div>
          ${nextRow}
          <div class="proj-stats">
            ${journalRow}
            ${ledgerRow}
            ${timewRow}
          </div>
          <div class="proj-usage-hint">
            tasks: <code>project:${name}</code> · journal: <code>@project:${name}</code> · ledger: tag via row button
          </div>
          <div class="proj-detail" style="display:none"></div>
        </div>`;
      }).join('');

      // Filter input
      const filterEl = document.getElementById('project-filter');
      const applyFilter = () => {
        const q = (filterEl?.value || '').toLowerCase();
        document.querySelectorAll('.proj-card').forEach(card => {
          card.style.display = !q || card.dataset.project.toLowerCase().includes(q) ? '' : 'none';
        });
      };
      filterEl?.removeEventListener('input', applyFilter);
      filterEl?.addEventListener('input', applyFilter);

      // Stop filter inputs from triggering card expand
      body.querySelectorAll('.proj-item-filter').forEach(inp => {
        inp.addEventListener('click', e => e.stopPropagation());
        inp.addEventListener('input', e => {
          e.stopPropagation();
          const q = inp.value.toLowerCase();
          const card = inp.closest('.proj-card');
          if (!card) return;
          const detail = card.querySelector('.proj-detail');
          if (!detail) return;
          detail.querySelectorAll('.proj-detail-row').forEach(row => {
            row.style.display = !q || row.textContent.toLowerCase().includes(q) ? '' : 'none';
          });
        });
      });

      // Master task creation buttons
      body.querySelectorAll('.proj-create-master-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
          const pname = btn.dataset.project;
          btn.disabled = true;
          btn.textContent = '…';
          const r = await fetch('/action', {
            method: 'POST', headers: {'Content-Type':'application/json'},
            body: JSON.stringify({ action: 'project_create_master', args: { name: pname } }),
          });
          const d = await r.json();
          if (d.ok) { toast(`master task created for ${pname}`); await loadProjects(); }
          else { toast(d.error || 'failed', 'error'); btn.disabled = false; btn.textContent = '+ master task'; }
        });
      });

      // Navigate to master task on badge click
      body.querySelectorAll('.proj-master-badge').forEach(badge => {
        badge.style.cursor = 'pointer';
        badge.addEventListener('click', () => {
          const project = badge.closest('.proj-card')?.dataset.project;
          if (project) switchSection('tasks');
        });
      });

      // Expand/collapse project detail on header click
      body.querySelectorAll('.proj-card-header').forEach(hdr => {
        hdr.addEventListener('click', async (e) => {
          if (e.target.closest('button') || e.target.closest('.proj-master-badge')) return;
          const card = hdr.closest('.proj-card');
          const name = card.dataset.project;
          const detail = card.querySelector('.proj-detail');
          const chevron = hdr.querySelector('.proj-expand-chevron');
          const expanded = card.dataset.expanded === 'true';
          if (expanded) {
            card.dataset.expanded = 'false';
            detail.style.display = 'none';
            return;
          }
          card.dataset.expanded = 'true';
          detail.style.display = '';
          if (!card.dataset.detailLoaded) {
            detail.innerHTML = '<div class="proj-detail-loading">loading…</div>';
            try {
              const r = await fetch(`/data/project/${encodeURIComponent(name)}`);
              const d = await r.json();
              if (!d.ok) { detail.innerHTML = `<div class="proj-detail-err">${esc(d.error || 'failed')}</div>`; return; }
              detail.innerHTML = renderProjectDetail(d);
              // Wire navigate-on-click for detail rows
              detail.querySelectorAll('[data-navigate]').forEach(row => {
                row.style.cursor = 'pointer';
                row.addEventListener('click', (e) => {
                  e.stopPropagation();
                  const section = row.dataset.navigate;
                  if (section === 'tasks') {
                    const uuid = row.dataset.uuid;
                    if (uuid) { window.__navigateTask(uuid); return; }
                  }
                  if (section === 'journal') {
                    const slug = row.dataset.slug;
                    if (slug) { window.__navigateJournalEntry(slug); return; }
                  }
                  if (section === 'ledger') {
                    const date = row.dataset.date, desc = row.dataset.desc;
                    if (date && desc && window.__navigateLedger) { window.__navigateLedger(date, desc); return; }
                  }
                  switchSection(section);
                });
              });
              // Wire subsection collapse toggles
              detail.querySelectorAll('.proj-subsection-toggle').forEach(tog => {
                tog.addEventListener('click', (e) => {
                  e.stopPropagation();
                  const key = tog.dataset.subsection;
                  const body = document.getElementById(`proj-${key}`);
                  if (!body) return;
                  const collapsed = body.classList.toggle('hidden');
                  const chevron = tog.querySelector('.proj-subsec-chevron');
                  if (chevron) chevron.style.transform = collapsed ? '' : 'rotate(90deg)';
                });
              });
              card.dataset.detailLoaded = 'true';
            } catch (e2) {
              detail.innerHTML = `<div class="proj-detail-err">load failed: ${esc(e2.message)}</div>`;
            }
          }
        });
      });

    } catch (e) { renderError(body, `Projects: ${e.message}`, loadProjects); }
  }

  async function loadTags() {
    const body = document.getElementById('tags-body');
    const chipsPanel = document.getElementById('tags-chips');
    const filterEl = document.getElementById('tags-filter');
    const excludeBtn = document.getElementById('tags-exclude');
    const sortEl = document.getElementById('tags-sort');
    const minCountEl = document.getElementById('tags-min-count');
    if (!body) return;
    const e2 = s => String(s ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');

    const STATUS_KEYWORDS = new Set(['next','waiting','someday','hold','blocked','review','active',
      'paused','wip','backlog','inbox','maybe','today','urgent','pending','focus','later','followup']);

    let excludeMode = false;
    let activePriFilter = null; // 'H'|'M'|'L'|'none'|null
    let activeUdaFilter = null; // uda name | null

    body.innerHTML = '<div class="skeleton-msg">Loading…</div>';
    if (chipsPanel) chipsPanel.innerHTML = '';
    try {
      const res = await fetch('/data/tags');
      const data = await res.json();
      if (!data.ok) { body.innerHTML = `<div class="empty-state">${data.error || 'Failed to load tags'}</div>`; return; }
      const allTags = data.tags || [];
      const udaNames = data.uda_names || [];
      if (!allTags.length) { body.innerHTML = '<div class="empty-state">No tags found. Add tags: to tasks to see them here.</div>'; return; }

      // Build chip rows
      if (chipsPanel) {
        const statusTags = allTags.filter(t => STATUS_KEYWORDS.has(t.tag.toLowerCase()));
        const priPresent = [...new Set(allTags.flatMap(t => t.priorities || []))].sort();
        const udaPresent = [...new Set(allTags.flatMap(t => t.udas || []))];

        let html = '';
        if (statusTags.length) {
          html += `<div class="tags-chip-row"><span class="tags-chip-label">status</span>`
            + statusTags.map(t => `<button class="tags-chip" data-type="text" data-val="${e2(t.tag)}">${e2(t.tag)} <span class="tags-chip-count">${t.count}</span></button>`).join('')
            + `</div>`;
        }
        if (priPresent.length) {
          const priLabels = {H:'High',M:'Medium',L:'Low'};
          html += `<div class="tags-chip-row"><span class="tags-chip-label">priority</span>`
            + priPresent.map(p => `<button class="tags-chip tags-chip-pri" data-type="pri" data-val="${e2(p)}">${priLabels[p]||p}</button>`).join('')
            + `<button class="tags-chip tags-chip-pri" data-type="pri" data-val="none">none</button>`
            + `</div>`;
        }
        if (udaPresent.length) {
          html += `<div class="tags-chip-row"><span class="tags-chip-label">uda</span>`
            + udaPresent.map(u => `<button class="tags-chip tags-chip-uda" data-type="uda" data-val="${e2(u)}">${e2(u)}</button>`).join('')
            + `</div>`;
        }
        chipsPanel.innerHTML = html;

        chipsPanel.addEventListener('click', e => {
          const chip = e.target.closest('.tags-chip');
          if (!chip) return;
          const type = chip.dataset.type, val = chip.dataset.val;
          if (type === 'text') {
            filterEl.value = chip.classList.contains('tags-chip-active') ? '' : val;
            chipsPanel.querySelectorAll('[data-type="text"]').forEach(c => c.classList.toggle('tags-chip-active', c === chip && filterEl.value));
          } else if (type === 'pri') {
            const wasActive = chip.classList.contains('tags-chip-active');
            chipsPanel.querySelectorAll('[data-type="pri"]').forEach(c => c.classList.remove('tags-chip-active'));
            activePriFilter = wasActive ? null : val;
            if (!wasActive) chip.classList.add('tags-chip-active');
          } else if (type === 'uda') {
            const wasActive = chip.classList.contains('tags-chip-active');
            chipsPanel.querySelectorAll('[data-type="uda"]').forEach(c => c.classList.remove('tags-chip-active'));
            activeUdaFilter = wasActive ? null : val;
            if (!wasActive) chip.classList.add('tags-chip-active');
          }
          renderCards();
        });
      }

      if (excludeBtn) {
        excludeBtn.addEventListener('click', () => {
          excludeMode = !excludeMode;
          excludeBtn.classList.toggle('tags-chip-active', excludeMode);
          renderCards();
        });
      }

      const renderCards = () => {
        const q = (filterEl?.value || '').toLowerCase();
        const minC = parseInt(minCountEl?.value || '0') || 0;
        const sortMode = sortEl?.value || 'name';

        let visible = allTags.filter(t => {
          // text filter (with exclude mode)
          if (q) {
            const matches = t.tag.toLowerCase().includes(q);
            if (excludeMode ? matches : !matches) return false;
          }
          if (t.count < minC) return false;
          // priority chip filter
          if (activePriFilter) {
            if (activePriFilter === 'none') { if ((t.priorities||[]).length > 0) return false; }
            else { if (!(t.priorities||[]).includes(activePriFilter)) return false; }
          }
          // uda chip filter
          if (activeUdaFilter && !(t.udas||[]).includes(activeUdaFilter)) return false;
          return true;
        });

        if (sortMode === 'count-desc') visible.sort((a,b) => b.count - a.count);
        else if (sortMode === 'count-asc') visible.sort((a,b) => a.count - b.count);
        else if (sortMode === 'modified') visible.sort((a,b) => (b.latest_modified||'').localeCompare(a.latest_modified||''));
        else visible.sort((a,b) => a.tag.localeCompare(b.tag));

        if (!visible.length) { body.innerHTML = '<div class="empty-state">No tags match that filter.</div>'; return; }
        body.innerHTML = visible.map(t => {
          const taskRows = (t.tasks || []).map(task => {
            const pri = task.priority ? `<span class="badge-priority pri-${task.priority.toLowerCase()}">${task.priority}</span>` : '';
            const proj = task.project ? `<span class="badge-project" style="cursor:pointer" onclick="event.stopPropagation();window.__navigateProject('${e2(task.project)}')">${e2(task.project)}</span>` : '';
            const raw = task.modified || task.entry || '';
            const dateChip = raw.length >= 8 ? `<span class="tag-task-date">${raw.slice(0,4)}-${raw.slice(4,6)}-${raw.slice(6,8)}</span>` : '';
            const udaChips = task.udas ? Object.entries(task.udas).map(([k,v]) =>
              `<span class="tags-chip-uda-mini">${e2(k)}: ${e2(String(v))}</span>`).join('') : '';
            return `<div class="tag-task-row" data-uuid="${e2(task.uuid)}" onclick="window.__navigateTask('${e2(task.uuid)}')" style="cursor:pointer">
              <span class="tag-task-desc">${e2(task.description)}</span>
              <span class="tag-task-meta">${pri}${proj}${dateChip}${udaChips}</span>
            </div>`;
          }).join('');
          const more = t.count > (t.tasks||[]).length ? `<div class="tag-more-note">+${t.count - t.tasks.length} more tasks not shown</div>` : '';
          const lm = t.latest_modified||'';
          const latestDisplay = lm.length >= 8 ? `${lm.slice(0,4)}-${lm.slice(4,6)}-${lm.slice(6,8)}` : '';
          return `<div class="tag-card">
            <div class="tag-card-head" onclick="this.parentElement.classList.toggle('tag-card-open')">
              <span class="tag-card-name ctn-pill-tag">${e2(t.tag)}</span>
              <span class="tag-card-count">${t.count} task${t.count !== 1 ? 's' : ''}</span>
              ${latestDisplay ? `<span class="tag-card-date">${latestDisplay}</span>` : ''}
              <span class="tag-card-chevron">▸</span>
            </div>
            <div class="tag-card-body">${taskRows}${more}</div>
          </div>`;
        }).join('');
      };

      renderCards();
      filterEl?.addEventListener('input', renderCards);
      sortEl?.addEventListener('change', renderCards);
      minCountEl?.addEventListener('input', renderCards);
    } catch (e) { renderError(body, `Tags: ${e.message}`, loadTags); }
  }

  function renderProjectDetail(d) {
    const tasks = d.tasks || {};
    const journal = d.journal || {};
    const ledger = d.ledger || {};
    const timew = d.timew || {};
    let html = '<div class="proj-detail-inner">';

    // Tasks section
    const allTasks = [...(tasks.active || []), ...(tasks.pending || [])];
    const pendingMore = (tasks.pending_total || 0) - (tasks.pending || []).length;
    html += `<div class="proj-detail-section">
      <div class="proj-detail-label">Tasks <span class="proj-detail-count">${(tasks.pending_total || 0) + (tasks.active || []).length} pending · ${tasks.done || 0} done</span></div>`;
    if (tasks.master) {
      html += `<div class="proj-detail-row proj-detail-master" data-navigate="tasks" data-uuid="${esc(tasks.master.uuid||'')}">
        <span class="proj-di-role">⬡</span>
        <span class="proj-di-desc">${esc(tasks.master.description)}</span>
        <span class="proj-di-meta">master task</span>
      </div>`;
    }
    allTasks.forEach(t => {
      const icon = t.status === 'active' ? '●' : '·';
      html += `<div class="proj-detail-row" data-navigate="tasks" data-task-id="${t.id||''}" data-uuid="${esc(t.uuid||'')}">
        <span class="proj-di-status">${icon}</span>
        <span class="proj-di-desc">${esc(t.description)}</span>
        <span class="proj-di-meta">${t.urgency > 0 ? t.urgency : ''}</span>
      </div>`;
    });
    if (pendingMore > 0) html += `<div class="proj-detail-more">+ ${pendingMore} more pending tasks</div>`;
    if (!allTasks.length && !tasks.master) html += `<div class="proj-detail-empty">no pending tasks</div>`;

    // Done tasks — collapsed
    const doneList = tasks.done_list || [];
    if (doneList.length || tasks.done > 0) {
      html += `<div class="proj-subsection">
        <div class="proj-subsection-toggle" data-subsection="done-${esc(d.name)}">
          <span class="proj-subsec-chevron">›</span> Done (${tasks.done})
        </div>
        <div class="proj-subsection-body hidden" id="proj-done-${esc(d.name)}">`;
      doneList.forEach(t => {
        html += `<div class="proj-detail-row proj-detail-done" data-navigate="tasks" data-uuid="${esc(t.uuid||'')}">
          <span class="proj-di-status">✓</span>
          <span class="proj-di-desc">${esc(t.description)}</span>
          <span class="proj-di-meta proj-di-dim">${(t.end||'').slice(0,10)}</span>
        </div>`;
      });
      if (tasks.done > doneList.length) {
        html += `<div class="proj-detail-more">+ ${tasks.done - doneList.length} more completed</div>`;
      }
      html += '</div></div>';
    }
    html += '</div>';

    // Journal section
    html += `<div class="proj-detail-section">
      <div class="proj-detail-label">Journal <span class="proj-detail-count">${journal.total || 0} entries</span></div>`;
    (journal.entries || []).forEach(e => {
      const tags = e.tags?.length ? `<span class="proj-di-tags">@${e.tags.join(' @')}</span>` : '';
      const pri  = e.priority ? `<span class="proj-di-pri">${e.priority}</span>` : '';
      html += `<div class="proj-detail-row" data-navigate="journal" data-slug="${esc(e.date_slug||'')}">
        <span class="proj-di-date">${e.date.split(' ')[0]}</span>
        <span class="proj-di-desc">${esc(e.preview)}</span>
        ${tags}${pri}
      </div>`;
    });
    const jMore = (journal.total || 0) - (journal.entries || []).length;
    if (jMore > 0) html += `<div class="proj-detail-more">+ ${jMore} more entries</div>`;
    if (!journal.total) html += `<div class="proj-detail-empty">no journal entries with @project:${esc(d.name)}</div>`;
    html += '</div>';

    // Ledger section
    html += `<div class="proj-detail-section">
      <div class="proj-detail-label">Ledger <span class="proj-detail-count">${ledger.total || 0} transactions</span></div>`;
    (ledger.transactions || []).forEach(tx => {
      const postings = (tx.postings || []).map(p => `${esc(p.account)}  ${esc(p.amount)}`).join('  ·  ');
      html += `<div class="proj-detail-row" data-navigate="ledger">
        <span class="proj-di-date">${tx.date}</span>
        <span class="proj-di-desc">${esc(tx.description)}</span>
        <span class="proj-di-meta proj-di-dim">${postings}</span>
      </div>`;
    });
    const lMore = (ledger.total || 0) - (ledger.transactions || []).length;
    if (lMore > 0) html += `<div class="proj-detail-more">+ ${lMore} more transactions</div>`;
    if (!ledger.total) html += `<div class="proj-detail-empty">no ledger entries with ; project:${esc(d.name)}</div>`;
    html += '</div>';

    // TimeWarrior + task time — collapsed
    const fmtH = s => s >= 3600 ? `${(s/3600).toFixed(1)}h` : s >= 60 ? `${Math.floor(s/60)}m` : `${s}s`;
    const timewSec = timew.total_seconds || 0;
    const runningSec = timew.running_seconds || 0;
    const pendingTaskSec = (d.tasks && d.tasks.pending_time_sec) || 0;
    const doneTaskSec = (d.tasks && d.tasks.done_time_sec) || 0;
    const totalAllSec = timewSec + pendingTaskSec + doneTaskSec;
    const runningMin = Math.floor(runningSec / 60);
    const timewLabel = totalAllSec > 0
      ? ` (${fmtH(totalAllSec)} total${runningSec > 0 ? ` · <span class="proj-timew-running">${runningMin}m running</span>` : ''})`
      : '';
    html += `<div class="proj-detail-section proj-subsection">
      <div class="proj-subsection-toggle" data-subsection="timew-${esc(d.name)}">
        <span class="proj-subsec-chevron">›</span> Time tracked${timewLabel}
      </div>
      <div class="proj-subsection-body hidden" id="proj-timew-${esc(d.name)}">`;
    // Summary rows
    if (pendingTaskSec > 0 || doneTaskSec > 0 || timewSec > 0) {
      html += `<div class="proj-detail-row proj-time-summary">
        <span class="proj-di-desc">pending tasks</span><span class="proj-di-meta">${fmtH(pendingTaskSec)}</span>
      </div>
      <div class="proj-detail-row proj-time-summary">
        <span class="proj-di-desc">done tasks</span><span class="proj-di-meta">${fmtH(doneTaskSec)}</span>
      </div>`;
      if (timewSec > 0) {
        html += `<div class="proj-detail-row proj-time-summary">
          <span class="proj-di-desc">timew sessions</span><span class="proj-di-meta">${fmtH(timewSec)}</span>
        </div>`;
      }
      html += `<div class="proj-detail-row proj-time-summary proj-time-total">
        <span class="proj-di-desc">total</span><span class="proj-di-meta">${fmtH(totalAllSec)}</span>
      </div>`;
    }
    // Timew interval detail
    const ivs = timew.intervals || [];
    if (ivs.length) {
      html += `<div class="proj-detail-empty" style="padding-top:6px;padding-bottom:2px">timew intervals</div>`;
      ivs.forEach(iv => {
        const durH = (iv.duration_sec / 3600).toFixed(2);
        const dateStr = iv.date ? `${iv.date.slice(0,4)}-${iv.date.slice(4,6)}-${iv.date.slice(6,8)}` : '';
        const runningBadge = iv.running ? ` <span class="proj-timew-running">● live</span>` : '';
        html += `<div class="proj-detail-row">
          <span class="proj-di-date">${dateStr}</span>
          <span class="proj-di-desc">${(iv.tags||[]).filter(t=>t!==d.name).join(', ')||'(untagged)'}${runningBadge}</span>
          <span class="proj-di-meta">${durH}h</span>
        </div>`;
      });
    } else if (pendingTaskSec === 0 && doneTaskSec === 0) {
      html += `<div class="proj-detail-empty">no time tracked for ${esc(d.name)}</div>`;
    }
    html += '</div></div>';

    html += '</div>';
    return html;
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
    // Wire tabs on first load
    document.querySelectorAll('.warrior-tab').forEach(tab => {
      if (tab.dataset.wired) return;
      tab.dataset.wired = '1';
      tab.addEventListener('click', () => {
        document.querySelectorAll('.warrior-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.warrior-tab-panel').forEach(p => p.classList.add('hidden'));
        tab.classList.add('active');
        const panel = document.getElementById(`warrior-tab-${tab.dataset.tab}`);
        panel?.classList.remove('hidden');
        if (tab.dataset.tab === 'profiles') _loadWarriorProfiles();
        if (tab.dataset.tab === 'community') _loadWarriorCommunity();
      });
    });
    await _loadWarriorSummary();
  }

  async function _loadWarriorSummary() {
    const panel = document.getElementById('warrior-tab-summary');
    if (!panel) return;
    try {
      const res = await fetch('/data/warrior');
      const d = await res.json();
      if (!d.ok) { panel.innerHTML = '<div class="empty-state">Warrior data unavailable</div>'; return; }
      const profiles = d.profiles || [];

      let html = `<div class="warrior-agg-row">
        <div class="warrior-agg-stat"><span class="stat-val">${profiles.length}</span><span class="stat-lbl">profiles</span></div>
        <div class="warrior-agg-stat"><span class="stat-val">${d.total_tasks}</span><span class="stat-lbl">total tasks</span></div>
        <div class="warrior-agg-stat"><span class="stat-val" style="color:var(--success)">${d.total_active}</span><span class="stat-lbl">active</span></div>
      </div><div class="warrior-profile-list">`;
      for (const p of profiles) {
        const urgHigh = Math.min(p.task_count, Math.ceil(p.task_count * 0.3));
        const urgMed  = Math.min(p.task_count - urgHigh, Math.ceil(p.task_count * 0.4));
        const urgLow  = p.task_count - urgHigh - urgMed;
        const barTotal = p.task_count || 1;
        const activeDot = p.active_count > 0 ? '<span class="warrior-active-dot"></span>' : '';
        html += `<div class="warrior-profile-card ${p.is_active ? 'warrior-card-active' : ''}">
          <div class="warrior-card-header">
            <span class="warrior-prof-name">${esc(p.name)}</span>${activeDot}
            ${p.is_active ? '<span class="warrior-current-badge">active</span>' : ''}
            <span class="warrior-task-count">${p.task_count} tasks</span>
          </div>
          ${p.top_task ? `<div class="warrior-top-task">${esc(p.top_task)}</div>` : ''}
          ${p.task_count > 0 ? `<div class="warrior-urg-bar">
            <div class="urg-seg urg-high" style="width:${(urgHigh/barTotal*100).toFixed(1)}%"></div>
            <div class="urg-seg urg-med"  style="width:${(urgMed/barTotal*100).toFixed(1)}%"></div>
            <div class="urg-seg urg-low"  style="width:${(urgLow/barTotal*100).toFixed(1)}%"></div>
          </div>` : ''}
        </div>`;
      }
      html += `</div><div style="margin-top:12px;padding-top:8px;border-top:1px solid var(--border)">
        <div style="display:flex;gap:6px;flex-wrap:wrap">
          <button class="btn-inline-alt" id="btn-w-version">version</button>
          <button class="btn-inline-alt" id="btn-w-deps">deps</button>
          <button class="btn-inline-alt" id="btn-w-shortcuts">shortcuts</button>
        </div>
        <div class="cmd-unified-output hidden" id="warrior-output"></div>
      </div>`;
      panel.innerHTML = html;

      const wOut = document.getElementById('warrior-output');
      const wCmd = async (cmd) => {
        wOut.className = 'cmd-unified-output'; wOut.textContent = 'loading…';
        const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ cmd }) });
        const rd = await r.json(); wOut.textContent = rd.output || 'done';
      };
      document.getElementById('btn-w-version')?.addEventListener('click', () => wCmd('version'));
      document.getElementById('btn-w-deps')?.addEventListener('click', () => wCmd('deps check'));
      document.getElementById('btn-w-shortcuts')?.addEventListener('click', () => wCmd('shortcut list'));
    } catch (e) { if (panel) panel.innerHTML = `<div class="empty-state">Warrior: ${esc(e.message)}</div>`; }
  }

  async function _loadWarriorProfiles() {
    const panel = document.getElementById('warrior-tab-profiles');
    if (!panel || panel.dataset.loaded) return;
    panel.innerHTML = '<div class="skeleton-msg">loading profiles…</div>';
    try {
      const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ cmd: 'warrior profiles' }) });
      const d = await r.json();
      panel.dataset.loaded = '1';
      panel.innerHTML = d.output
        ? `<pre class="warrior-pre">${esc(d.output)}</pre>`
        : '<div class="empty-state">No profiles found</div>';
    } catch (e) { panel.innerHTML = `<div class="empty-state">error: ${esc(e.message)}</div>`; }
  }

  async function _loadWarriorCommunity() {
    const panel = document.getElementById('warrior-community-list');
    if (!panel || panel.dataset.loaded) return;
    panel.innerHTML = '<div class="skeleton-msg">loading communities…</div>';
    try {
      const r = await fetch('/cmd', { method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ cmd: 'warrior community list' }) });
      const d = await r.json();
      panel.dataset.loaded = '1';
      if (d.output) {
        panel.innerHTML = `<pre class="warrior-pre">${esc(d.output)}</pre>
          <button class="btn-inline-alt" id="warrior-comm-refresh" style="margin-top:6px">↻ refresh</button>`;
        document.getElementById('warrior-comm-refresh')?.addEventListener('click', () => {
          delete panel.dataset.loaded; _loadWarriorCommunity();
        });
      } else {
        panel.innerHTML = '<div class="empty-state">No communities yet</div>';
      }
    } catch (e) { panel.innerHTML = `<div class="empty-state">error: ${esc(e.message)}</div>`; }
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

  // Ledger unit filter state — persists across loadLedger calls
  let _activeUnit = '';
  let _lastDetectedUnits = [];

  function _detectUnits(recent) {
    const BUILTIN_SYMS = new Set(['', '$', 'h']);
    const seen = new Set(BUILTIN_SYMS);
    const units = [];
    (recent || []).forEach(row => {
      const amt = (row.amount || '').trim();
      // Trailing word token: "10.5 BTC" → "BTC", "10h" → "h"
      const trail = amt.match(/[\d.,]+\s*([A-Za-z]+)$/);
      if (trail) {
        const sym = trail[1];
        if (!seen.has(sym)) { seen.add(sym); units.push({ sym, label: sym }); }
      }
    });
    return units;
  }

  function _renderUnitPills(detectedUnits) {
    const filter = document.getElementById('ledger-unit-filter');
    if (!filter) return;
    let custom = [];
    try { custom = JSON.parse(localStorage.getItem('ww-ledger-units') || '[]'); } catch (_) {}
    const BUILTIN = [
      { sym: '', label: 'all' },
      { sym: '$', label: '$ currency' },
      { sym: 'h', label: 'h hours' },
    ];
    const seen = new Set(BUILTIN.map(u => u.sym));
    const allUnits = [...BUILTIN];
    [...custom, ...detectedUnits].forEach(u => {
      if (!seen.has(u.sym)) { seen.add(u.sym); allUnits.push({ sym: u.sym, label: u.label || u.sym }); }
    });
    const builtinSyms = new Set(BUILTIN.map(u => u.sym));
    filter.innerHTML = `
      <span class="unit-filter-label">unit:</span>
      ${allUnits.map(u => {
        const isCustom = !builtinSyms.has(u.sym);
        const pill = `<button class="unit-btn${u.sym === _activeUnit ? ' active' : ''}" data-unit="${esc(u.sym)}">${esc(u.label)}</button>`;
        if (!isCustom) return pill;
        return `<span class="unit-pill-wrap">${pill}<button class="unit-edit-btn" data-sym="${esc(u.sym)}" data-label="${esc(u.label)}" title="Edit unit">✎</button><button class="unit-del-btn" data-sym="${esc(u.sym)}" title="Delete unit">✕</button></span>`;
      }).join('')}
      <button class="unit-add-btn" id="unit-add-btn" title="Register unit type">+</button>`;
    filter.querySelectorAll('.unit-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        _activeUnit = btn.dataset.unit;
        filter.querySelectorAll('.unit-btn').forEach(b => b.classList.toggle('active', b.dataset.unit === _activeUnit));
        _applyUnitFilter();
      });
    });
    filter.querySelectorAll('.unit-del-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const sym = btn.dataset.sym;
        let stored = [];
        try { stored = JSON.parse(localStorage.getItem('ww-ledger-units') || '[]'); } catch (_) {}
        stored = stored.filter(u => u.sym !== sym);
        localStorage.setItem('ww-ledger-units', JSON.stringify(stored));
        if (_activeUnit === sym) _activeUnit = '';
        _renderUnitPills(_lastDetectedUnits);
        _applyUnitFilter();
      });
    });
    filter.querySelectorAll('.unit-edit-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const existing = filter.querySelector('.unit-add-form');
        if (existing) existing.remove();
        const sym = btn.dataset.sym;
        const currentLabel = btn.dataset.label;
        const form = document.createElement('div');
        form.className = 'unit-add-form';
        form.innerHTML = `<input class="unit-add-sym" placeholder="symbol" maxlength="10" value="${esc(sym)}" /><input class="unit-add-label" placeholder="label" value="${esc(currentLabel)}" /><button class="btn-inline-submit unit-add-save">save</button><button class="btn-inline-alt unit-add-cancel">✕</button>`;
        filter.insertBefore(form, document.getElementById('unit-add-btn'));
        form.querySelector('.unit-add-sym').focus();
        const doSave = () => {
          const newSym = form.querySelector('.unit-add-sym').value.trim();
          const newLbl = form.querySelector('.unit-add-label').value.trim() || newSym;
          if (!newSym) return;
          let stored = [];
          try { stored = JSON.parse(localStorage.getItem('ww-ledger-units') || '[]'); } catch (_) {}
          stored = stored.filter(u => u.sym !== sym);
          if (!stored.find(u => u.sym === newSym)) stored.push({ sym: newSym, label: `${newSym} ${newLbl}` });
          localStorage.setItem('ww-ledger-units', JSON.stringify(stored));
          if (_activeUnit === sym) _activeUnit = newSym;
          form.remove();
          _renderUnitPills(_lastDetectedUnits);
          _applyUnitFilter();
        };
        form.querySelector('.unit-add-save').addEventListener('click', doSave);
        form.querySelector('.unit-add-cancel').addEventListener('click', () => form.remove());
        form.querySelector('.unit-add-sym').addEventListener('keydown', ev => { if (ev.key === 'Enter') doSave(); if (ev.key === 'Escape') form.remove(); });
      });
    });
    document.getElementById('unit-add-btn')?.addEventListener('click', () => {
      const existing = filter.querySelector('.unit-add-form');
      if (existing) { existing.remove(); return; }
      const form = document.createElement('div');
      form.className = 'unit-add-form';
      form.innerHTML = `<input class="unit-add-sym" placeholder="symbol (e.g. BTC)" maxlength="10" /><input class="unit-add-label" placeholder="label (e.g. Bitcoin)" /><button class="btn-inline-submit unit-add-save">add</button><button class="btn-inline-alt unit-add-cancel">✕</button>`;
      filter.appendChild(form);
      form.querySelector('.unit-add-sym').focus();
      const doAdd = () => {
        const sym = form.querySelector('.unit-add-sym').value.trim();
        const lbl = form.querySelector('.unit-add-label').value.trim() || sym;
        if (!sym) return;
        let stored = [];
        try { stored = JSON.parse(localStorage.getItem('ww-ledger-units') || '[]'); } catch (_) {}
        if (!stored.find(u => u.sym === sym)) {
          stored.push({ sym, label: `${sym} ${lbl}` });
          localStorage.setItem('ww-ledger-units', JSON.stringify(stored));
          toast(`unit "${sym}" registered`);
        }
        form.remove();
        _renderUnitPills(_lastDetectedUnits);
      };
      form.querySelector('.unit-add-save').addEventListener('click', doAdd);
      form.querySelector('.unit-add-cancel').addEventListener('click', () => form.remove());
      form.querySelector('.unit-add-sym').addEventListener('keydown', (ev) => { if (ev.key === 'Enter') doAdd(); if (ev.key === 'Escape') form.remove(); });
    });
  }

  function _applyUnitFilter() {
    document.querySelectorAll('.ledger-item').forEach(item => {
      if (!_activeUnit) { item.style.display = ''; return; }
      const amt = item.querySelector('.tx-amt')?.textContent?.trim() || '';
      const match = _activeUnit === '$'
        ? /[$£€]/.test(amt)
        : amt.trim().endsWith(_activeUnit) || new RegExp('\\s' + _activeUnit + '$').test(amt);
      item.style.display = match ? '' : 'none';
    });
    document.querySelectorAll('.balance-row').forEach(row => {
      if (!_activeUnit) { row.style.display = ''; return; }
      const amt = row.querySelector('.acct-amt')?.textContent?.trim() || '';
      const match = _activeUnit === '$'
        ? /[$£€]/.test(amt)
        : amt.trim().endsWith(_activeUnit) || new RegExp('\\s' + _activeUnit + '$').test(amt);
      row.style.display = match ? '' : 'none';
    });
  }

  // Tab-completion for hierarchical account paths (Assets:Checking, Expenses:Food:Out, …)
  // Completes the current colon-delimited segment from knownAccounts, then appends ":"
  // if any known account has children below the completed path.
  function wireAccountTabComplete(input) {
    input.addEventListener('keydown', e => {
      if (e.key !== 'Tab') return;
      const val = input.value;
      if (!val) return;

      const colonIdx = val.lastIndexOf(':');
      const prefix   = colonIdx >= 0 ? val.slice(0, colonIdx + 1) : ''; // e.g. "Assets:" or ""
      const lowerVal = val.toLowerCase();

      // All known accounts whose full path starts with what's typed
      const matches = knownAccounts.filter(a => a.toLowerCase().startsWith(lowerVal));
      if (!matches.length) return;

      // Extract the next segment (after prefix) from each match — deduplicated
      const segs = [...new Set(matches.map(a => {
        const rest = a.slice(prefix.length);
        const c = rest.indexOf(':');
        return c >= 0 ? rest.slice(0, c) : rest;
      }))];

      // Longest common prefix of all candidate segments
      const commonLen = segs.slice(1).reduce((len, seg) => {
        const ref = segs[0];
        let i = 0;
        while (i < len && i < seg.length && ref[i].toLowerCase() === seg[i].toLowerCase()) i++;
        return i;
      }, segs[0].length);

      if (!commonLen) return; // nothing in common — need more input
      e.preventDefault();

      // Use casing from the first match
      const completed = prefix + segs[0].slice(0, commonLen);
      // Append ":" only if a known account has children below this path
      const hasChildren = knownAccounts.some(a => a.toLowerCase().startsWith(completed.toLowerCase() + ':'));
      input.value = completed + (hasChildren ? ':' : '');
    });
  }

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
        const toggle = document.getElementById('jrnl-enter-toggle');
        const enterSubmits = !toggle || toggle.checked;
        if (e.key === 'Enter' && !e.shiftKey && enterSubmits) {
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
      const args = { entry };
      const activeJournal = profileResources?.active?.journal;
      if (activeJournal) args.journal = activeJournal;
      const project = (document.getElementById('journal-project-input')?.value || fd.get('project') || '').trim();
      const tags = (fd.get('tags') || '').trim();
      const priority = (fd.get('priority') || '').trim();
      if (project) args.project = project;
      if (tags) args.tags = tags;
      if (priority) args.priority = priority;
      const res = await fetch('/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'journal_add', args }),
      });
      const data = await res.json();
      if (data.ok) {
        toast('✓ journal entry added');
        await loadJournal();
        e.target.reset();
      } else { toast('journal failed', 'error'); }
    });

    // ── Lists (list.py) ─────────────────────────────────────────────────────
    const addListForm = document.getElementById('add-list-form');
    async function submitListItem(formEl) {
      const fd = new FormData(formEl);
      const text = (fd.get('text') || '').toString().trim();
      if (!text) return;
      try {
        const res = await fetch('/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'list_add', args: { text } }),
        });
        const data = await res.json();
        if (data.ok) {
          toast('✓ item added');
          await loadLists();
          formEl.reset();
        } else {
          toast(data.error || data.output || 'list add failed', 'error');
        }
      } catch (err) {
        toast(`list add failed: ${err.message}`, 'error');
      }
    }
    addListForm?.addEventListener('submit', async (e) => {
      e.preventDefault();
      await submitListItem(e.target);
    });
    addListForm?.querySelector('input[name="text"]')?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        addListForm.requestSubmit();
      }
    });
    document.getElementById('list-refresh-btn')?.addEventListener('click', async () => {
      await loadProfileResources();
      await refreshResourceSelectors('lists');
      await loadLists();
      toast('↻ lists refreshed', 'info');
    });
    document.getElementById('list-create-btn')?.addEventListener('click', () => {
      const container = document.getElementById('header-resource-slot');
      if (!container || !profileResources) return;
      const sel = container.querySelector('select.resource-select');
      if (!sel) return;
      showResourceCreateForm(container, 'lists', sel, () => loadLists());
    });
    document.getElementById('list-show-done-btn')?.addEventListener('click', async () => {
      listShowDone = !listShowDone;
      const btn = document.getElementById('list-show-done-btn');
      const doneBox = document.getElementById('list-done-items');
      if (listShowDone) {
        btn.textContent = 'hide done';
        btn.classList.add('active');
        doneBox?.classList.remove('hidden');
        await loadListDone();
      } else {
        btn.textContent = 'show done';
        btn.classList.remove('active');
        doneBox?.classList.add('hidden');
      }
    });

    // ── Ledger ─────────────────────────────────────────────────────────────
    const ledgerDateInput = document.querySelector('#add-ledger-form input[name="date"]');
    if (ledgerDateInput && !ledgerDateInput.value) ledgerDateInput.value = todayStr();
    const ledgerAcctInput = document.querySelector('#add-ledger-form input[name="account"]');
    if (ledgerAcctInput) wireAccountTabComplete(ledgerAcctInput);

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
          comment:     fd.get('comment')     || '',
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
    let _activeHlCmd = null;
    async function runHledger(cmd, extraArgs) {
      const out = document.getElementById('hledger-output');
      // Toggle: clicking the active command again collapses the output
      if (_activeHlCmd === cmd && !out.classList.contains('hidden')) {
        out.classList.add('hidden');
        _activeHlCmd = null;
        document.querySelectorAll('.hl-btn').forEach(b => b.classList.remove('active'));
        return;
      }
      _activeHlCmd = cmd;
      document.querySelectorAll('.hl-btn').forEach(b => b.classList.toggle('active', b.dataset.cmd === cmd));
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

    // Auto-rerun active hledger command when filter controls change
    ['hl-period', 'hl-depth'].forEach(id => {
      document.getElementById(id)?.addEventListener('change', () => {
        if (_activeHlCmd) runHledger(_activeHlCmd);
      });
    });
    let _hlFilterTimer = null;
    document.getElementById('hl-filter')?.addEventListener('input', () => {
      clearTimeout(_hlFilterTimer);
      _hlFilterTimer = setTimeout(() => { if (_activeHlCmd) runHledger(_activeHlCmd); }, 350);
    });

    // Unit type filter buttons — rendered dynamically; wire initial static pills if present
    _renderUnitPills([]);

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
    document.getElementById('btn-export-snapshot')?.addEventListener('click', async () => {
      const out = document.getElementById('export-output');
      out.className = 'cmd-unified-output'; out.textContent = 'generating snapshot…';
      try {
        const res = await fetch('/export/snapshot');
        if (!res.ok) { out.textContent = 'error: ' + res.status; return; }
        const blob = await res.blob();
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        const profile = document.getElementById('header-profile')?.textContent?.trim() || 'profile';
        a.href = url;
        a.download = `ww-snapshot-${profile}-${new Date().toISOString().slice(0,10)}.html`;
        document.body.appendChild(a); a.click(); document.body.removeChild(a);
        URL.revokeObjectURL(url);
        out.textContent = 'snapshot downloaded';
      } catch (err) { out.textContent = 'error: ' + err.message; }
    });
    // Warlock buttons
    async function warlockCmd(cmd) {
      const out = document.getElementById('warlock-output');
      out.className = 'cmd-unified-output'; out.textContent = `running: ww browser warlock ${cmd}…`;
      try {
        const res = await fetch('/cmd', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ cmd: `browser warlock ${cmd}` }) });
        const d = await res.json();
        out.textContent = d.output || d.error || 'done';
      } catch (e) { out.textContent = 'error: ' + e.message; }
      await loadWarlock();
    }
    document.getElementById('btn-warlock-install')?.addEventListener('click', () => warlockCmd('install'));
    document.getElementById('btn-warlock-start')?.addEventListener('click', () => warlockCmd('start'));
    document.getElementById('btn-warlock-stop')?.addEventListener('click', () => warlockCmd('stop'));
    document.getElementById('btn-warlock-status')?.addEventListener('click', async () => {
      const out = document.getElementById('warlock-output');
      out.className = 'cmd-unified-output';
      await loadWarlock();
      out.textContent = '';
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
      const body = document.getElementById('saves-body');
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
      if (data.ok) { e.target.reset(); toast(`project '${name}' defined`); await loadProjects(); }
      else { toast(data.error || 'failed', 'error'); }
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
    const addAcctInput = document.getElementById('add-account-input');
    addAcctInput?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') { e.preventDefault(); document.getElementById('btn-add-account')?.click(); }
    });
    if (addAcctInput) wireAccountTabComplete(addAcctInput);

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

  const _dismissedCmdLog = new Set(); // session-only dismissed entry keys

  function _cmdLogKey(e) { return `${e.ts || ''}:${e.command || ''}`; }

  function _renderCmdLog(entries) {
    const logEl = document.getElementById('cmd-log');
    if (!logEl) return;
    const visible = entries.filter(e => !_dismissedCmdLog.has(_cmdLogKey(e)));
    if (!visible.length) {
      logEl.innerHTML = '<div class="empty-state">No commands yet this session</div>';
      return;
    }
    logEl.innerHTML = visible.map((e, idx) => {
      const t = e.ts ? new Date(e.ts).toLocaleString([], {month:'short',day:'numeric',hour:'2-digit',minute:'2-digit'}) : '';
      const ok = e.ok ? '✓' : '✗';
      const key = _cmdLogKey(e);
      const collapsed = idx > 0; // most-recent expanded, rest collapsed
      return `<div class="cmd-log-entry${collapsed ? ' collapsed' : ''}" data-key="${esc(key)}">
        <div class="cmd-log-header-row">
          <span class="cmd-log-toggle">${collapsed ? '▶' : '▼'}</span>
          <span class="cmd-log-cmd">${ok} ${esc(e.command || '')}</span>
          <span class="cmd-log-time">${t}${e.profile ? ' · ' + esc(e.profile) : ''}</span>
          <button class="cmd-log-dismiss" title="Dismiss">×</button>
        </div>
        <div class="cmd-log-result">${esc(e.output || '').replace(/\n/g, '<br>')}</div>
      </div>`;
    }).join('');
    logEl.querySelectorAll('.cmd-log-entry').forEach(entry => {
      entry.querySelector('.cmd-log-header-row')?.addEventListener('click', ev => {
        if (ev.target.classList.contains('cmd-log-dismiss')) return;
        const collapsed = entry.classList.toggle('collapsed');
        const tog = entry.querySelector('.cmd-log-toggle');
        if (tog) tog.textContent = collapsed ? '▶' : '▼';
      });
      entry.querySelector('.cmd-log-dismiss')?.addEventListener('click', ev => {
        ev.stopPropagation();
        _dismissedCmdLog.add(entry.dataset.key);
        entry.remove();
        if (!logEl.querySelector('.cmd-log-entry'))
          logEl.innerHTML = '<div class="empty-state">No commands yet this session</div>';
      });
    });
    // Auto-scroll most-recent into view
    logEl.querySelector('.cmd-log-entry')?.scrollIntoView({ block: 'nearest' });
  }

  async function loadCmdLog() {
    const logEl = document.getElementById('cmd-log');
    if (!logEl) return;
    // Wire clear button once
    const clearBtn = document.getElementById('cmd-log-clear');
    if (clearBtn && !clearBtn.dataset.wired) {
      clearBtn.dataset.wired = '1';
      clearBtn.addEventListener('click', () => {
        logEl.querySelectorAll('.cmd-log-entry').forEach(el => _dismissedCmdLog.add(el.dataset.key));
        logEl.innerHTML = '<div class="empty-state">No commands yet this session</div>';
      });
    }
    try {
      const res = await fetch('/data/cmd-log');
      const data = await res.json();
      if (!data.ok || !data.entries.length) {
        logEl.innerHTML = '<div class="empty-state">No commands yet this session</div>';
        return;
      }
      _renderCmdLog(data.entries);
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

  // ── Community mini journal panel ────────────────────────────────────────────
  function populateCommJournalMiniSel() {
    const sel = document.getElementById('comm-jmini-sel');
    if (!sel || !profileResources) return;
    const journals = profileResources.resources?.journals || {};
    const active = profileResources.active?.journal || '';
    sel.innerHTML = Object.keys(journals).map(j =>
      `<option value="${esc(j)}"${j === active ? ' selected' : ''}>${esc(j)}</option>`
    ).join('') || '<option value="">— no journals —</option>';
  }

  function initCommJournalMini() {
    const sel = document.getElementById('comm-jmini-sel');
    const form = document.getElementById('comm-jmini-form');
    if (!form) return;

    document.getElementById('btn-comm-jmini-new')?.addEventListener('click', async () => {
      const name = window.prompt('New journal name (letters, numbers, hyphens):');
      if (!name || !/^[a-zA-Z0-9_-]+$/.test(name)) return;
      const r = await fetch('/resource/create', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ kind: 'journal', name }),
      });
      const d = await r.json();
      if (d.ok) { toast(`journal '${name}' created`); await loadProfileResources(); }
      else toast(d.error || 'create failed', 'error');
    });

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const text = (document.getElementById('comm-jmini-entry')?.value || '').trim();
      if (!text) return;
      const project = (document.getElementById('comm-jmini-project')?.value || '').trim();
      const tags = (document.getElementById('comm-jmini-tags')?.value || '').trim();
      const priority = (document.getElementById('comm-jmini-priority')?.value || '').trim();
      const journal = sel?.value || '';
      const r = await fetch('/action', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'journal_add', args: { entry: text, project, tags, priority, journal } }),
      });
      const d = await r.json();
      if (d.ok) {
        toast('journal entry added');
        const ta = document.getElementById('comm-jmini-entry');
        if (ta) ta.value = '';
      } else {
        toast(d.error || 'journal add failed', 'error');
      }
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
    initCommunityPanel();
    initCommJournalMini();
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
    applyNavOrder();
    await loadSection(activeSection);

    // 30s polling fallback for active section (paused when tab hidden)
    setInterval(() => {
      if (document.visibilityState === 'hidden') return;
      if (activeSection === 'tasks') loadTasks();
      else if (activeSection === 'time') loadTime();
      else if (activeSection === 'journal') { journalPage = 1; loadJournal(); }
      else if (activeSection === 'lists') loadLists();
    }, 30000);

    termInput.focus();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
