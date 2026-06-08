// themes/feynman.js — Feynman theme (self-registering)
(function() {
  'use strict';

  // ── Label transformation system ────────────────────────────────────────────

  const FEYNMAN_LABELS = {
    'Add Task': 'Design Experiment',
    'Start Timer': 'Begin Measurement',
    'New Entry': 'Record Observation',
    'Done': 'Conclude',
    'Delete': 'Discard',
    'pending': 'Designing',
    'active': 'Running',
    'Add': 'Record',
    'Tasks': 'Experiments',
    'Times': 'Measurements',
    'Journals': 'Notebook',
    'Ledgers': 'Conservation',
    'Lists': 'Fact Sets',
    'Communities': 'Research Collective',
    'Start': 'Begin Measurement',
    'Stop': 'End Measurement',
    '+ task': 'Design Experiment',
    'New journal entry': 'Record Observation',
    'task…': 'hypothesis…',
    'New list item': 'Record Fact'
  };

  function applyFeynmanLabels(root) {
    var elements = root.querySelectorAll('button, label, span, h3, .nav-label, .section-title, [placeholder]');
    elements.forEach(function(el) {
      // Handle placeholder attributes
      if (el.hasAttribute('placeholder')) {
        var ph = el.getAttribute('placeholder');
        var mappedPh = FEYNMAN_LABELS[ph];
        if (mappedPh && !el.dataset.feynmanOriginalPh) {
          el.dataset.feynmanOriginalPh = ph;
          el.setAttribute('placeholder', mappedPh);
        }
      }
      // Handle textContent
      var text = el.textContent.trim();
      var mapped = FEYNMAN_LABELS[text];
      if (mapped && !el.dataset.feynmanOriginal) {
        el.dataset.feynmanOriginal = el.textContent;
        el.textContent = mapped;
      }
    });
  }

  function restoreDefaultLabels(root) {
    root.querySelectorAll('[data-feynman-original]').forEach(function(el) {
      el.textContent = el.dataset.feynmanOriginal;
      delete el.dataset.feynmanOriginal;
    });
    root.querySelectorAll('[data-feynman-original-ph]').forEach(function(el) {
      el.setAttribute('placeholder', el.dataset.feynmanOriginalPh);
      delete el.dataset.feynmanOriginalPh;
    });
  }

  // ── Observations Hierarchy Ordering ──────────────────────────────────────────
  // Weight mapping for observation types — higher weight renders first.
  // Used wherever mixed observation types appear together (Notebook, Questions Bank,
  // Investigation summary).

  const FEYNMAN_TYPE_WEIGHT = {
    observation: 4,
    measurement: 3,
    discovery: 3,   // same weight as measurement
    question: 2.5,  // between measurement and theory
    theory: 2,
    opinion: 1
  };

  /**
   * Sort child elements within a container by observation-type weight.
   * Only reorders when multiple types exist in the same container.
   * @param {Element} container - Parent element containing items to sort
   * @param {string} itemSelector - CSS selector for sortable items within container
   * @param {function(Element):string|null} typeExtractor - Returns the observation type for an item
   */
  function sortByObservationHierarchy(container, itemSelector, typeExtractor) {
    var items = Array.from(container.querySelectorAll(itemSelector));
    if (items.length < 2) return;

    // Check if multiple types exist — skip sorting if all same type
    var types = new Set();
    items.forEach(function(item) {
      var t = typeExtractor(item);
      if (t) types.add(t);
    });
    if (types.size < 2) return;

    // Sort by weight descending (higher weight first)
    items.sort(function(a, b) {
      var typeA = typeExtractor(a);
      var typeB = typeExtractor(b);
      var weightA = FEYNMAN_TYPE_WEIGHT[typeA] || 0;
      var weightB = FEYNMAN_TYPE_WEIGHT[typeB] || 0;
      return weightB - weightA;
    });

    // Re-append in sorted order
    items.forEach(function(item) {
      container.appendChild(item);
    });
  }

  // ── ExperimentView (Tasks as Experiments) ────────────────────────────────────

  const ExperimentView = {
    _observer: null,
    _originalPlaceholder: null,
    _concludeHandler: null,

    activate() {
      // Change the task input placeholder
      const descInput = document.querySelector('#add-task-form input[name="description"]');
      if (descInput) {
        this._originalPlaceholder = descInput.getAttribute('placeholder');
        descInput.setAttribute('placeholder', 'What do you want to find out?');
      }

      // Observe task list for re-renders and apply overlay
      const taskList = document.getElementById('task-list');
      if (taskList) {
        this._observer = new MutationObserver(() => {
          this.renderOverlay();
        });
        this._observer.observe(taskList, { childList: true, subtree: false });
      }

      // Wire conclude interception on the task list (delegated)
      this._concludeHandler = (e) => {
        const btn = e.target.closest('.act-done');
        if (!btn) return;
        // Check if this is already a conclude prompt situation
        const row = btn.closest('.task-row');
        if (!row) return;
        // If conclude prompt is already showing, let it handle itself
        if (row.nextElementSibling?.classList.contains('feynman-experiment-conclude')) return;
        // Intercept: show conclude prompt instead of immediate done
        e.stopPropagation();
        e.preventDefault();
        this._showConcludePrompt(row, btn.dataset.id);
      };
      if (taskList) {
        taskList.addEventListener('click', this._concludeHandler, true);
      }

      // Apply overlay to existing content
      this.renderOverlay();
    },

    deactivate() {
      // Disconnect observer
      if (this._observer) {
        this._observer.disconnect();
        this._observer = null;
      }

      // Remove conclude handler
      const taskList = document.getElementById('task-list');
      if (taskList && this._concludeHandler) {
        taskList.removeEventListener('click', this._concludeHandler, true);
        this._concludeHandler = null;
      }

      // Restore placeholder
      const descInput = document.querySelector('#add-task-form input[name="description"]');
      if (descInput && this._originalPlaceholder !== null) {
        descInput.setAttribute('placeholder', this._originalPlaceholder);
        this._originalPlaceholder = null;
      }

      // Remove all injected experiment elements
      document.querySelectorAll(
        '.feynman-experiment-fields, .feynman-experiment-confidence, ' +
        '.feynman-experiment-group-header, .feynman-experiment-conclude'
      ).forEach(el => el.remove());

      // Restore done button labels
      document.querySelectorAll('.act-done .btn-word').forEach(el => {
        if (el.textContent === 'conclude') el.textContent = 'done';
      });
    },

    renderOverlay() {
      const taskList = document.getElementById('task-list');
      if (!taskList) return;

      // Remove previously injected elements (avoid duplication)
      taskList.querySelectorAll(
        '.feynman-experiment-fields, .feynman-experiment-confidence, .feynman-experiment-group-header'
      ).forEach(el => el.remove());

      const rows = taskList.querySelectorAll('.task-row');
      if (!rows.length) return;

      // Collect tasks grouped by status from DOM
      const groups = {
        designing: [],  // pending
        running: [],    // active
        analyzing: [],  // has result: annotation but not completed
        concluded: []   // completed (if visible)
      };

      rows.forEach(row => {
        const taskData = this._extractTaskData(row);
        if (taskData.hasResult && taskData.status !== 'completed') {
          groups.analyzing.push({ row, data: taskData });
        } else if (taskData.status === 'completed') {
          groups.concluded.push({ row, data: taskData });
        } else if (taskData.status === 'active') {
          groups.running.push({ row, data: taskData });
        } else {
          groups.designing.push({ row, data: taskData });
        }

        // Inject scientific fields below each task row
        this._injectFields(row, taskData);

        // Inject confidence indicator
        this._injectConfidence(row, taskData);

        // Relabel "done" → "conclude"
        const doneBtn = row.querySelector('.act-done .btn-word');
        if (doneBtn && doneBtn.textContent === 'done') {
          doneBtn.textContent = 'conclude';
        }
      });

      // Insert group headers (in reverse order so positions stay correct)
      this._insertGroupHeaders(taskList, groups);
    },

    _extractTaskData(row) {
      const uuid = row.dataset.uuid || '';
      const id = row.dataset.id || '';
      const tags = (row.dataset.tags || '').split(',').filter(Boolean);
      const isActive = row.classList.contains('task-active');
      const status = isActive ? 'active' : 'pending';

      // Parse annotations from sibling .task-row-ann elements
      const annotations = [];
      let next = row.nextElementSibling;
      while (next && next.classList.contains('task-row-ann')) {
        annotations.push(next.textContent.replace(/^↳\s*/, '').replace(/^\d{4}-\d{2}-\d{2}\s*/, '').trim());
        next = next.nextElementSibling;
      }

      // Extract scientific field annotations
      const hypothesis = this._findAnnotation(annotations, 'hypothesis:');
      const method = this._findAnnotation(annotations, 'method:');
      const prediction = this._findAnnotation(annotations, 'prediction:');
      const result = this._findAnnotation(annotations, 'result:');
      const conclusion = this._findAnnotation(annotations, 'conclusion:');

      // Confidence from tags
      let confidence = null;
      if (tags.includes('conf_high') || tags.includes('+conf_high')) confidence = 'high';
      else if (tags.includes('conf_med') || tags.includes('+conf_med')) confidence = 'med';
      else if (tags.includes('conf_low') || tags.includes('+conf_low')) confidence = 'low';

      return {
        uuid, id, status, tags, annotations,
        hypothesis, method, prediction, result, conclusion,
        confidence,
        hasResult: !!result
      };
    },

    _findAnnotation(annotations, prefix) {
      for (const ann of annotations) {
        if (ann.toLowerCase().startsWith(prefix)) {
          return ann.slice(prefix.length).trim();
        }
      }
      return null;
    },

    _injectFields(row, data) {
      // Only inject if there are scientific annotations to show
      if (!data.hypothesis && !data.method && !data.prediction && !data.result && !data.conclusion) return;

      const fields = document.createElement('div');
      fields.className = 'feynman-experiment-fields';
      let html = '';
      if (data.hypothesis) html += `<div class="feynman-experiment-field"><span class="feynman-experiment-field-label">Hypothesis:</span> ${this._esc(data.hypothesis)}</div>`;
      if (data.method) html += `<div class="feynman-experiment-field"><span class="feynman-experiment-field-label">Method:</span> ${this._esc(data.method)}</div>`;
      if (data.prediction) html += `<div class="feynman-experiment-field"><span class="feynman-experiment-field-label">Prediction:</span> ${this._esc(data.prediction)}</div>`;
      if (data.result) html += `<div class="feynman-experiment-field"><span class="feynman-experiment-field-label">Result:</span> ${this._esc(data.result)}</div>`;
      if (data.conclusion) html += `<div class="feynman-experiment-field"><span class="feynman-experiment-field-label">Conclusion:</span> ${this._esc(data.conclusion)}</div>`;
      fields.innerHTML = html;

      // Insert after the task row (and after any annotation rows)
      let insertAfter = row;
      while (insertAfter.nextElementSibling && insertAfter.nextElementSibling.classList.contains('task-row-ann')) {
        insertAfter = insertAfter.nextElementSibling;
      }
      // Also skip inline detail divs
      if (insertAfter.nextElementSibling && insertAfter.nextElementSibling.classList.contains('task-inline-detail')) {
        insertAfter = insertAfter.nextElementSibling;
      }
      insertAfter.insertAdjacentElement('afterend', fields);
    },

    _injectConfidence(row, data) {
      if (!data.confidence) return;
      const indicator = document.createElement('span');
      indicator.className = `feynman-experiment-confidence feynman-confidence-${data.confidence}`;
      indicator.title = `Confidence: ${data.confidence}`;
      indicator.textContent = data.confidence === 'high' ? '●●●' : data.confidence === 'med' ? '●●○' : '●○○';
      // Insert before the task-actions span
      const actions = row.querySelector('.task-actions');
      if (actions) {
        actions.insertAdjacentElement('beforebegin', indicator);
      }
    },

    _insertGroupHeaders(taskList, groups) {
      const groupOrder = [
        { key: 'designing', label: '🔬 Designing', count: groups.designing.length },
        { key: 'running', label: '⚗️ Running', count: groups.running.length },
        { key: 'analyzing', label: '📊 Analyzing', count: groups.analyzing.length },
        { key: 'concluded', label: '✓ Concluded', count: groups.concluded.length }
      ];

      // Only insert headers if there are tasks in more than one group
      const nonEmpty = groupOrder.filter(g => g.count > 0);
      if (nonEmpty.length <= 1) return;

      // Insert headers before the first task of each group
      for (const group of groupOrder) {
        if (group.count === 0) continue;
        const firstRow = groups[group.key][0]?.row;
        if (!firstRow) continue;
        const header = document.createElement('div');
        header.className = 'feynman-experiment-group-header';
        header.innerHTML = `<span class="feynman-experiment-group-label">${group.label}</span><span class="feynman-experiment-group-count">${group.count}</span>`;
        firstRow.insertAdjacentElement('beforebegin', header);
      }
    },

    _showConcludePrompt(row, taskId) {
      // Don't show again if already open
      if (row.parentElement.querySelector('.feynman-experiment-conclude[data-for-id="' + taskId + '"]')) return;

      const prompt = document.createElement('div');
      prompt.className = 'feynman-experiment-conclude';
      prompt.dataset.forId = taskId;
      prompt.innerHTML = `
        <div class="feynman-experiment-conclude-title">Conclude Experiment</div>
        <div class="feynman-experiment-conclude-field">
          <label>Actual Result:</label>
          <input type="text" class="feynman-conclude-result" placeholder="What actually happened?" autocomplete="off" />
        </div>
        <div class="feynman-experiment-conclude-field">
          <label>Conclusion:</label>
          <input type="text" class="feynman-conclude-conclusion" placeholder="What did you learn?" autocomplete="off" />
        </div>
        <div class="feynman-experiment-conclude-actions">
          <button class="feynman-conclude-submit">✓ Conclude</button>
          <button class="feynman-conclude-skip">Skip (just complete)</button>
          <button class="feynman-conclude-cancel">Cancel</button>
        </div>
      `;

      // Insert after the row
      let insertAfter = row;
      while (insertAfter.nextElementSibling &&
             (insertAfter.nextElementSibling.classList.contains('task-row-ann') ||
              insertAfter.nextElementSibling.classList.contains('task-inline-detail') ||
              insertAfter.nextElementSibling.classList.contains('feynman-experiment-fields'))) {
        insertAfter = insertAfter.nextElementSibling;
      }
      insertAfter.insertAdjacentElement('afterend', prompt);

      // Focus the result input
      prompt.querySelector('.feynman-conclude-result')?.focus();

      // Wire buttons
      prompt.querySelector('.feynman-conclude-submit').addEventListener('click', async () => {
        const resultText = prompt.querySelector('.feynman-conclude-result').value.trim();
        const conclusionText = prompt.querySelector('.feynman-conclude-conclusion').value.trim();
        // Add annotations first, then mark done
        if (resultText) {
          await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'annotate', id: parseInt(taskId), args: { note: 'result: ' + resultText } }) });
        }
        if (conclusionText) {
          await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'annotate', id: parseInt(taskId), args: { note: 'conclusion: ' + conclusionText } }) });
        }
        // Now mark done
        const res = await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'done', id: parseInt(taskId) }) });
        const data = await res.json();
        if (data.ok) {
          prompt.remove();
        }
      });

      prompt.querySelector('.feynman-conclude-skip').addEventListener('click', async () => {
        prompt.remove();
        // Just do the done action directly
        const res = await fetch('/action', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'done', id: parseInt(taskId) }) });
        const data = await res.json();
        if (data.ok) prompt.remove();
      });

      prompt.querySelector('.feynman-conclude-cancel').addEventListener('click', () => {
        prompt.remove();
      });
    },

    _esc(str) {
      return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
  };

  const MeasurementView = {
    _observer: null,
    _originalStartText: null,

    activate() {
      // Relabel start button to "Begin Measurement"
      const startBtn = document.getElementById('btn-timew-start');
      if (startBtn) {
        this._originalStartText = startBtn.textContent;
        startBtn.textContent = '▶ Begin Measurement';
      }

      // Render overlay on current content
      this.renderOverlay();

      // Set up MutationObserver to re-render when time entries change
      const ints = document.getElementById('time-intervals');
      if (ints) {
        this._observer = new MutationObserver(() => {
          // Only re-render if we haven't already injected our overlay
          if (!ints.querySelector('.feynman-measurement-overlay')) {
            this.renderOverlay();
          }
        });
        this._observer.observe(ints, { childList: true, subtree: false });
      }
    },

    deactivate() {
      // Disconnect observer
      if (this._observer) {
        this._observer.disconnect();
        this._observer = null;
      }

      // Restore start button label
      const startBtn = document.getElementById('btn-timew-start');
      if (startBtn && this._originalStartText) {
        startBtn.textContent = this._originalStartText;
        this._originalStartText = null;
      }

      // Remove all injected measurement elements
      document.querySelectorAll('.feynman-measurement-overlay, .feynman-measurement-header').forEach(el => el.remove());

      // Restore original interval display
      const ints = document.getElementById('time-intervals');
      if (ints) {
        ints.querySelectorAll('.interval-row, .day-group-header, .intervals-header, .entry-action-row').forEach(el => {
          el.style.display = '';
        });
      }
    },

    renderOverlay() {
      const ints = document.getElementById('time-intervals');
      if (!ints) return;

      // Fetch time data from API for precise start/end timestamps
      fetch('/data/time').then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) return;
        var intervals = (data.intervals || []).slice(0, 50);
        MeasurementView._renderGrouped(ints, intervals);
      }).catch(function() {
        // Fallback: use DOM data only
        var intervals = MeasurementView._collectFromDOM(ints);
        MeasurementView._renderGrouped(ints, intervals);
      });
    },

    /** Render grouped measurement overlay from interval data */
    _renderGrouped(ints, intervals) {
      // Hide default date-grouped display
      ints.querySelectorAll('.interval-row, .day-group-header, .intervals-header, .entry-action-row').forEach(function(el) {
        el.style.display = 'none';
      });

      // Remove any existing overlay
      var existing = ints.querySelector('.feynman-measurement-overlay');
      if (existing) existing.remove();

      // Group intervals by experiment (tags = experiment name)
      var groups = {};
      intervals.forEach(function(iv) {
        var tags = Array.isArray(iv.tags) ? iv.tags.join(' ') : (iv.tags || '');
        var key = tags || '(untagged)';
        if (!groups[key]) groups[key] = [];
        groups[key].push({
          tags: key,
          start: iv.start || '',
          end: iv.end || '',
          durationSec: iv.duration || iv.duration_seconds || 0
        });
      });

      // Build overlay HTML
      var html = '<div class="feynman-measurement-overlay">';
      html += '<div class="feynman-measurement-title">Measurements</div>';

      var groupKeys = Object.keys(groups);
      if (groupKeys.length === 0) {
        html += '<div class="feynman-measurement-empty">No measurements recorded</div>';
      } else {
        groupKeys.forEach(function(experiment) {
          var ivs = groups[experiment];
          // Compute aggregates
          var totalSeconds = 0;
          ivs.forEach(function(iv) { totalSeconds += iv.durationSec; });
          var count = ivs.length;
          var avgSeconds = count > 0 ? totalSeconds / count : 0;

          html += '<div class="feynman-measurement-group">';
          html += '<div class="feynman-measurement-experiment">';
          html += '<span class="feynman-measurement-experiment-name">' + MeasurementView._esc(experiment) + '</span>';
          html += '</div>';

          // Aggregate stats
          html += '<div class="feynman-measurement-aggregates">';
          html += '<span class="feynman-measurement-stat">Total: <span class="feynman-duration">' + MeasurementView._fmtHM(totalSeconds) + '</span></span>';
          html += '<span class="feynman-measurement-stat">Count: ' + count + '</span>';
          html += '<span class="feynman-measurement-stat">Avg session: <span class="feynman-duration">' + MeasurementView._fmtHM(avgSeconds) + '</span></span>';
          html += '</div>';

          // Individual measurements
          ivs.forEach(function(iv) {
            html += '<div class="feynman-measurement-row">';
            html += '<span class="feynman-timestamp">' + MeasurementView._fmtTime(iv.start) + '</span>';
            html += '<span class="feynman-measurement-arrow">→</span>';
            html += '<span class="feynman-timestamp">' + MeasurementView._fmtTime(iv.end) + '</span>';
            html += '<span class="feynman-duration">' + MeasurementView._fmtHM(iv.durationSec) + '</span>';
            html += '</div>';
          });

          html += '</div>';
        });
      }

      html += '</div>';
      ints.insertAdjacentHTML('beforeend', html);
    },

    /** Fallback: collect interval data from the rendered DOM rows */
    _collectFromDOM(container) {
      var intervals = [];
      container.querySelectorAll('.interval-row').forEach(function(row) {
        var tags = row.dataset.tags || '';
        var durEl = row.querySelector('.int-dur');
        var durText = durEl ? durEl.textContent : '';
        var durationSec = MeasurementView._parseDuration(durText);
        intervals.push({ tags: tags, start: '', end: '', duration: durationSec });
      });
      return intervals;
    },

    /** Format seconds as h:mm */
    _fmtHM(seconds) {
      if (!seconds || seconds <= 0) return '0:00';
      var h = Math.floor(seconds / 3600);
      var m = Math.floor((seconds % 3600) / 60);
      return h + ':' + (m < 10 ? '0' : '') + m;
    },

    /** Format TW timestamp to HH:MM local time */
    _fmtTime(ts) {
      if (!ts) return '--:--';
      try {
        var d = new Date(ts.replace(/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z/, '$1-$2-$3T$4:$5:$6Z'));
        return d.getHours().toString().padStart(2, '0') + ':' + d.getMinutes().toString().padStart(2, '0');
      } catch (e) {
        return '--:--';
      }
    },

    /** Parse duration text like "1h 30m 5s" or "45m 0s" to seconds */
    _parseDuration(text) {
      if (!text) return 0;
      var total = 0;
      var hMatch = text.match(/(\d+)h/);
      var mMatch = text.match(/(\d+)m/);
      var sMatch = text.match(/(\d+(?:\.\d+)?)s/);
      if (hMatch) total += parseInt(hMatch[1]) * 3600;
      if (mMatch) total += parseInt(mMatch[1]) * 60;
      if (sMatch) total += parseFloat(sMatch[1]);
      return total;
    },

    /** Basic HTML escape */
    _esc(s) {
      var div = document.createElement('div');
      div.textContent = s;
      return div.innerHTML;
    }
  };

  const NotebookView = {
    _observer: null,
    _originalPlaceholder: null,
    _originalProjectPlaceholder: null,
    _questionsBankEl: null,
    _questionsBankBtn: null,

    activate() {
      // Change textarea placeholder to scientific framing
      const textarea = document.getElementById('journal-entry-textarea');
      if (textarea) {
        this._originalPlaceholder = textarea.getAttribute('placeholder');
        textarea.setAttribute('placeholder', 'Record observation… (Enter to submit, Shift+Enter for newline)');
      }

      // Change project/section input placeholder to hint at observation types
      const projInput = document.getElementById('journal-project-input');
      if (projInput) {
        this._originalProjectPlaceholder = projInput.getAttribute('placeholder');
        projInput.setAttribute('placeholder', '@observation @theory @question @discovery');
      }

      // Inject "Questions Bank" toggle button near the journal filter bar
      const filterBar = document.querySelector('.journal-filter-bar');
      if (filterBar && !document.getElementById('feynman-questions-bank-btn')) {
        this._questionsBankBtn = document.createElement('button');
        this._questionsBankBtn.className = 'journal-filter-btn feynman-questions-bank-btn';
        this._questionsBankBtn.id = 'feynman-questions-bank-btn';
        this._questionsBankBtn.textContent = '? Questions Bank';
        this._questionsBankBtn.title = 'Show questions bank';
        this._questionsBankBtn.addEventListener('click', () => this._toggleQuestionsBank());
        filterBar.appendChild(this._questionsBankBtn);
      }

      // Observe journal list for re-renders
      const journalList = document.getElementById('journal-list');
      if (journalList) {
        this._observer = new MutationObserver(() => {
          this.renderOverlay();
        });
        this._observer.observe(journalList, { childList: true, subtree: false });
      }

      // Apply overlay to existing content
      this.renderOverlay();
    },

    deactivate() {
      // Disconnect observer
      if (this._observer) {
        this._observer.disconnect();
        this._observer = null;
      }

      // Restore placeholders
      const textarea = document.getElementById('journal-entry-textarea');
      if (textarea && this._originalPlaceholder !== null) {
        textarea.setAttribute('placeholder', this._originalPlaceholder);
        this._originalPlaceholder = null;
      }

      const projInput = document.getElementById('journal-project-input');
      if (projInput && this._originalProjectPlaceholder !== null) {
        projInput.setAttribute('placeholder', this._originalProjectPlaceholder);
        this._originalProjectPlaceholder = null;
      }

      // Remove Questions Bank button
      if (this._questionsBankBtn) {
        this._questionsBankBtn.remove();
        this._questionsBankBtn = null;
      }

      // Remove Questions Bank panel
      if (this._questionsBankEl) {
        this._questionsBankEl.remove();
        this._questionsBankEl = null;
      }

      // Remove all injected notebook elements
      document.querySelectorAll(
        '.feynman-notebook-badge, .feynman-notebook-margin, .feynman-notebook-confidence, .feynman-questions-bank'
      ).forEach(function(el) { el.remove(); });

      // Remove timestamp class from entry-date elements
      document.querySelectorAll('.entry-date.feynman-timestamp').forEach(function(el) {
        el.classList.remove('feynman-timestamp');
      });
    },

    renderOverlay() {
      var journalList = document.getElementById('journal-list');
      if (!journalList) return;

      // Remove previously injected notebook elements to avoid duplication
      journalList.querySelectorAll(
        '.feynman-notebook-badge, .feynman-notebook-margin, .feynman-notebook-confidence'
      ).forEach(function(el) { el.remove(); });

      // Remove timestamp class
      journalList.querySelectorAll('.entry-date.feynman-timestamp').forEach(function(el) {
        el.classList.remove('feynman-timestamp');
      });

      var entries = journalList.querySelectorAll('.journal-entry');
      entries.forEach(function(entry) {
        var dateEl = entry.querySelector('.entry-date');
        var bodyEl = entry.querySelector('.entry-body');
        if (!dateEl) return;

        // Apply monospace timestamp class to date element
        dateEl.classList.add('feynman-timestamp');

        // Determine observation type from meta chips (tags and project)
        var obsType = NotebookView._getObservationType(entry);

        // Insert observation-type badge next to date
        if (obsType) {
          var badge = document.createElement('span');
          badge.className = 'feynman-notebook-badge feynman-badge feynman-badge-' + obsType;
          badge.textContent = obsType.charAt(0).toUpperCase() + obsType.slice(1);
          dateEl.insertAdjacentElement('afterend', badge);
        }

        // For Theory/Opinion entries, add confidence marker
        if (obsType === 'theory' || obsType === 'opinion') {
          var confidence = NotebookView._getConfidenceLevel(entry);
          var marker = document.createElement('span');
          marker.className = 'feynman-notebook-confidence feynman-confidence-' + confidence;
          marker.title = 'Confidence: ' + confidence;
          marker.textContent = confidence === 'high' ? '●●●' : confidence === 'med' ? '●●○' : '●○○';
          // Insert after badge or after date
          var afterEl = entry.querySelector('.feynman-notebook-badge') || dateEl;
          afterEl.insertAdjacentElement('afterend', marker);
        }

        // Add margin column for annotations/cross-references
        var margin = document.createElement('div');
        margin.className = 'feynman-notebook-margin';
        if (obsType) {
          margin.dataset.type = obsType;
        }
        // Show structured field label based on type
        var fieldLabel = NotebookView._getFieldLabel(obsType, bodyEl);
        if (fieldLabel) {
          margin.innerHTML = '<span class="feynman-notebook-margin-label">' + fieldLabel + '</span>';
        }
        entry.insertAdjacentElement('afterbegin', margin);
      });

      // Sort entries within each date group by observation hierarchy weight
      var dateGroups = journalList.querySelectorAll('.journal-date-group');
      if (dateGroups.length > 0) {
        dateGroups.forEach(function(group) {
          sortByObservationHierarchy(group, '.journal-entry', function(entry) {
            return NotebookView._getObservationType(entry);
          });
        });
      } else {
        // No date groups — sort entries directly within journal-list
        sortByObservationHierarchy(journalList, '.journal-entry', function(entry) {
          return NotebookView._getObservationType(entry);
        });
      }

      // If Questions Bank is open, refresh it
      if (this._questionsBankEl && !this._questionsBankEl.classList.contains('hidden')) {
        this._renderQuestionsBank();
      }
    },

    _getObservationType(entry) {
      // Check tags in meta chips
      var chips = entry.querySelectorAll('.jmeta-chip, .ledger-tag-chip');
      var project = '';
      var tags = [];

      chips.forEach(function(chip) {
        var text = chip.textContent.trim().toLowerCase();
        if (chip.classList.contains('ledger-project-chip')) {
          project = text;
        } else {
          tags.push(text);
        }
      });

      // Check for @type tags
      if (tags.includes('observation') || tags.includes('@observation') || project === 'observation') return 'observation';
      if (tags.includes('measurement') || tags.includes('@measurement') || project === 'measurement') return 'measurement';
      if (tags.includes('theory') || tags.includes('@theory') || project === 'theory') return 'theory';
      if (tags.includes('opinion') || tags.includes('@opinion') || project === 'opinion') return 'opinion';
      if (tags.includes('question') || tags.includes('@question') || project === 'question') return 'question';
      if (tags.includes('discovery') || tags.includes('@discovery') || project === 'discovery') return 'discovery';

      return null;
    },

    _getConfidenceLevel(entry) {
      // Look for confidence tags in chips
      var chips = entry.querySelectorAll('.jmeta-chip, .ledger-tag-chip');
      var tags = [];
      chips.forEach(function(chip) {
        tags.push(chip.textContent.trim().toLowerCase());
      });

      if (tags.includes('conf_high') || tags.includes('+conf_high')) return 'high';
      if (tags.includes('conf_med') || tags.includes('+conf_med')) return 'med';
      if (tags.includes('conf_low') || tags.includes('+conf_low')) return 'low';

      // Default for Theory: medium, for Opinion: low
      var obsType = this._getObservationType(entry);
      if (obsType === 'theory') return 'med';
      return 'low';
    },

    _getFieldLabel(obsType, bodyEl) {
      if (!obsType) return '';
      var labels = {
        observation: '📋 Observation',
        measurement: '📏 Measurement',
        theory: '💡 Theory',
        opinion: '💭 Opinion',
        question: '❓ Question',
        discovery: '🌟 Discovery'
      };
      return labels[obsType] || '';
    },

    _toggleQuestionsBank() {
      if (this._questionsBankEl && !this._questionsBankEl.classList.contains('hidden')) {
        // Hide
        this._questionsBankEl.classList.add('hidden');
        if (this._questionsBankBtn) this._questionsBankBtn.classList.remove('active');
      } else {
        // Show / create
        if (!this._questionsBankEl) {
          this._questionsBankEl = document.createElement('div');
          this._questionsBankEl.className = 'feynman-questions-bank';
          var journalSection = document.getElementById('section-journal');
          var journalList = document.getElementById('journal-list');
          if (journalList && journalSection) {
            journalList.insertAdjacentElement('beforebegin', this._questionsBankEl);
          }
        }
        this._questionsBankEl.classList.remove('hidden');
        if (this._questionsBankBtn) this._questionsBankBtn.classList.add('active');
        this._renderQuestionsBank();
      }
    },

    _renderQuestionsBank() {
      if (!this._questionsBankEl) return;

      // Fetch question-tagged entries from cached entries (if available)
      var questions = [];
      var entries = document.querySelectorAll('#journal-list .journal-entry');
      entries.forEach(function(entry) {
        var type = NotebookView._getObservationType(entry);
        if (type === 'question') {
          var dateEl = entry.querySelector('.entry-date');
          var bodyEl = entry.querySelector('.entry-body');
          var date = dateEl ? dateEl.textContent.trim() : '';
          var body = bodyEl ? bodyEl.textContent.trim() : '';
          var slug = entry.dataset.slug || '';

          // Check if resolved: look for @resolved tag or annotation with "resolved"
          var resolved = false;
          var chips = entry.querySelectorAll('.jmeta-chip, .ledger-tag-chip');
          chips.forEach(function(chip) {
            var t = chip.textContent.trim().toLowerCase();
            if (t === 'resolved' || t === '@resolved') resolved = true;
          });
          // Also check annotations for "resolved" text
          var annBlocks = entry.querySelectorAll('.entry-ann-text');
          annBlocks.forEach(function(ann) {
            if (ann.textContent.toLowerCase().includes('resolved')) resolved = true;
          });

          questions.push({ date: date, body: body, slug: slug, resolved: resolved });
        }
      });

      var html = '<div class="feynman-questions-bank-header">';
      html += '<span class="feynman-questions-bank-title">❓ Questions Bank</span>';
      html += '<span class="feynman-questions-bank-count">' + questions.length + ' question' + (questions.length !== 1 ? 's' : '') + '</span>';
      html += '</div>';

      if (questions.length === 0) {
        html += '<div class="feynman-questions-bank-empty">No questions recorded. Tag an entry with @question to add it here.</div>';
      } else {
        html += '<div class="feynman-questions-bank-list">';
        questions.forEach(function(q) {
          var statusClass = q.resolved ? 'feynman-question-resolved' : 'feynman-question-open';
          var statusLabel = q.resolved ? '✓ Resolved' : '○ Open';
          html += '<div class="feynman-questions-bank-item ' + statusClass + '">';
          html += '<span class="feynman-question-status">' + statusLabel + '</span>';
          html += '<span class="feynman-question-body">' + NotebookView._esc(q.body.slice(0, 120)) + (q.body.length > 120 ? '…' : '') + '</span>';
          html += '<span class="feynman-question-date feynman-timestamp">' + NotebookView._esc(q.date) + '</span>';
          html += '</div>';
        });
        html += '</div>';
      }

      this._questionsBankEl.innerHTML = html;
    },

    _esc(str) {
      return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
  };

  const ConservationView = {
    _observer: null,

    activate() {
      // Set up observer on ledger-recent to detect re-renders
      const recDiv = document.getElementById('ledger-recent');
      if (recDiv) {
        this._observer = new MutationObserver(() => {
          if (!recDiv.querySelector('.feynman-conservation-summary')) {
            this.renderOverlay();
          }
        });
        this._observer.observe(recDiv, { childList: true, subtree: false });
      }
      this.renderOverlay();
    },

    deactivate() {
      // Disconnect observer
      if (this._observer) {
        this._observer.disconnect();
        this._observer = null;
      }
      // Remove conservation summary card
      document.querySelectorAll('.feynman-conservation-summary').forEach(function(el) { el.remove(); });
      // Remove flow indicators from transaction rows
      document.querySelectorAll('.feynman-conservation-flow').forEach(function(el) { el.remove(); });
      // Remove transformation detail overlays
      document.querySelectorAll('.feynman-conservation-detail').forEach(function(el) { el.remove(); });
      // Restore balance type labels
      var balDiv = document.getElementById('ledger-balances');
      if (balDiv) {
        balDiv.querySelectorAll('.bal-type-label').forEach(function(label) {
          if (label.dataset.feynmanOriginal) {
            label.textContent = label.dataset.feynmanOriginal;
            delete label.dataset.feynmanOriginal;
          }
        });
      }
    },

    renderOverlay() {
      var self = this;
      fetch('/data/ledger').then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) return;
        self._renderSummary(data);
        self._relabelBalances();
        self._addFlowIndicators(data);
      }).catch(function() { /* silently skip on error */ });
    },

    _renderSummary(data) {
      var recDiv = document.getElementById('ledger-recent');
      if (!recDiv) return;

      // Remove existing summary if present
      var existing = recDiv.parentElement.querySelector('.feynman-conservation-summary');
      if (existing) existing.remove();

      // Compute totals from balances
      var totalIn = 0;
      var totalOut = 0;
      (data.balances || []).forEach(function(row) {
        var type = row.account.split(':')[0].toLowerCase();
        var amt = ConservationView._parseAmount(row.amount);
        if (type === 'income') {
          // Income balances are typically negative in hledger (credits)
          totalIn += Math.abs(amt);
        } else if (type === 'expenses') {
          totalOut += Math.abs(amt);
        }
      });
      var netChange = totalIn - totalOut;

      // Build summary card
      var card = document.createElement('div');
      card.className = 'feynman-conservation-summary';
      card.innerHTML =
        '<div class="feynman-conservation-summary-title">Conservation Summary</div>' +
        '<div class="feynman-conservation-summary-row">' +
          '<div class="feynman-conservation-metric feynman-conservation-in">' +
            '<span class="feynman-conservation-arrow">↓</span>' +
            '<span class="feynman-conservation-label">Energy In</span>' +
            '<span class="feynman-conservation-value">' + ConservationView._fmtCurrency(totalIn) + '</span>' +
          '</div>' +
          '<div class="feynman-conservation-metric feynman-conservation-out">' +
            '<span class="feynman-conservation-arrow">↑</span>' +
            '<span class="feynman-conservation-label">Energy Out</span>' +
            '<span class="feynman-conservation-value">' + ConservationView._fmtCurrency(totalOut) + '</span>' +
          '</div>' +
          '<div class="feynman-conservation-metric feynman-conservation-net">' +
            '<span class="feynman-conservation-arrow">' + (netChange >= 0 ? '⊕' : '⊖') + '</span>' +
            '<span class="feynman-conservation-label">Net Change</span>' +
            '<span class="feynman-conservation-value ' + (netChange >= 0 ? 'feynman-conservation-positive' : 'feynman-conservation-negative') + '">' + ConservationView._fmtCurrency(netChange) + '</span>' +
          '</div>' +
        '</div>';

      // Insert above the transaction list (before ledger-recent)
      recDiv.insertAdjacentElement('beforebegin', card);
    },

    _relabelBalances() {
      var balDiv = document.getElementById('ledger-balances');
      if (!balDiv) return;
      var labelMap = {
        'Income': 'Energy Sources',
        'Expenses': 'Energy Uses'
      };
      balDiv.querySelectorAll('.bal-type-label').forEach(function(label) {
        var text = label.textContent.trim();
        if (labelMap[text] && !label.dataset.feynmanOriginal) {
          label.dataset.feynmanOriginal = label.textContent;
          label.textContent = labelMap[text];
        }
      });
    },

    _addFlowIndicators(data) {
      var recDiv = document.getElementById('ledger-recent');
      if (!recDiv) return;

      // Remove existing flow indicators
      recDiv.querySelectorAll('.feynman-conservation-flow').forEach(function(el) { el.remove(); });
      recDiv.querySelectorAll('.feynman-conservation-detail').forEach(function(el) { el.remove(); });

      var items = recDiv.querySelectorAll('.ledger-item');
      var recent = data.recent || [];

      items.forEach(function(item, idx) {
        var txData = recent[idx];
        if (!txData) return;

        var ledgerRow = item.querySelector('.ledger-row');
        if (!ledgerRow) return;

        // Determine flow direction from account type
        var account = txData.account || '';
        var type = account.split(':')[0].toLowerCase();
        var flowLabel = '';
        var flowClass = '';
        var arrow = '';

        if (type === 'income') {
          flowLabel = 'Energy In';
          flowClass = 'feynman-conservation-flow-in';
          arrow = '↓';
        } else if (type === 'expenses') {
          flowLabel = 'Energy Out';
          flowClass = 'feynman-conservation-flow-out';
          arrow = '↑';
        } else if (type === 'assets') {
          flowLabel = 'Storage';
          flowClass = 'feynman-conservation-flow-store';
          arrow = '◈';
        } else if (type === 'liabilities') {
          flowLabel = 'Obligation';
          flowClass = 'feynman-conservation-flow-obligation';
          arrow = '◇';
        } else {
          flowLabel = 'Transfer';
          flowClass = 'feynman-conservation-flow-transfer';
          arrow = '⇄';
        }

        // Add flow indicator badge next to transaction row
        var indicator = document.createElement('span');
        indicator.className = 'feynman-conservation-flow ' + flowClass;
        indicator.innerHTML = '<span class="feynman-conservation-flow-arrow">' + arrow + '</span> ' + flowLabel;
        ledgerRow.insertAdjacentElement('afterbegin', indicator);

        // Add transformation detail on the ledger-detail panel
        var detailPanel = item.querySelector('.ledger-detail');
        if (detailPanel) {
          var detail = document.createElement('div');
          detail.className = 'feynman-conservation-detail';

          // Determine source and destination from the transaction context
          var source = '';
          var destination = '';
          var classification = 'expected';

          if (type === 'income') {
            source = account;
            destination = 'assets (inferred)';
            classification = 'expected';
          } else if (type === 'expenses') {
            source = 'assets (inferred)';
            destination = account;
            // Classify: transactions over a threshold or unusual accounts as "surprising"
            var amt = Math.abs(ConservationView._parseAmount(txData.amount));
            classification = amt > 500 ? 'surprising' : 'expected';
          } else {
            source = account;
            destination = '(counterpart)';
            classification = 'expected';
          }

          detail.innerHTML =
            '<div class="feynman-conservation-detail-title">Transformation Chain</div>' +
            '<div class="feynman-conservation-detail-flow">' +
              '<span class="feynman-conservation-source">' + ConservationView._esc(source) + '</span>' +
              ' <span class="feynman-conservation-detail-arrow">→</span> ' +
              '<span class="feynman-conservation-dest">' + ConservationView._esc(destination) + '</span>' +
            '</div>' +
            '<div class="feynman-conservation-detail-class feynman-conservation-' + classification + '">' +
              '<span class="feynman-conservation-class-badge">' + (classification === 'surprising' ? '⚡' : '✓') + '</span> ' +
              classification +
            '</div>';

          detailPanel.insertAdjacentElement('afterbegin', detail);
        }
      });
    },

    /** Parse a currency amount string like "$1,234.56" or "-$500" or "1000 USD" to a number */
    _parseAmount(str) {
      if (!str) return 0;
      var cleaned = str.replace(/[^0-9.\-]/g, '');
      var val = parseFloat(cleaned);
      if (isNaN(val)) return 0;
      // Respect negation: if original has leading minus or parentheses
      if (str.trim().startsWith('-') || str.trim().startsWith('(')) return -Math.abs(val);
      return val;
    },

    /** Format number as currency */
    _fmtCurrency(num) {
      var sign = num < 0 ? '-' : '';
      var abs = Math.abs(num).toFixed(2);
      // Add thousands separators
      var parts = abs.split('.');
      parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
      return sign + '$' + parts.join('.');
    },

    /** HTML-escape */
    _esc(s) {
      var div = document.createElement('div');
      div.textContent = s;
      return div.innerHTML;
    }
  };

  const FactsView = {
    _observer: null,
    _originalPlaceholder: null,
    _sourceInput: null,
    _reviewPanel: null,
    _reviewToggle: null,
    _formInterceptor: null,

    activate() {
      // Change the add-item placeholder
      const textInput = document.querySelector('#add-list-form input[name="text"]');
      if (textInput) {
        this._originalPlaceholder = textInput.getAttribute('placeholder');
        textInput.setAttribute('placeholder', 'Record a known fact...');
      }

      // Inject source/basis secondary input after main form input
      this._injectSourceInput();

      // Inject review queue toggle button
      this._injectReviewToggle();

      // Intercept form submission to prepend confidence and source
      this._wireFormInterceptor();

      // Observe list items for re-renders
      const listItems = document.getElementById('list-items');
      if (listItems) {
        this._observer = new MutationObserver(() => {
          this.renderOverlay();
        });
        this._observer.observe(listItems, { childList: true, subtree: false });
      }

      // Relabel the section title area
      this._relabelSection();

      // Apply overlay to existing content
      this.renderOverlay();
    },

    deactivate() {
      // Disconnect observer
      if (this._observer) {
        this._observer.disconnect();
        this._observer = null;
      }

      // Restore placeholder
      const textInput = document.querySelector('#add-list-form input[name="text"]');
      if (textInput && this._originalPlaceholder !== null) {
        textInput.setAttribute('placeholder', this._originalPlaceholder);
        this._originalPlaceholder = null;
      }

      // Remove source input
      if (this._sourceInput) {
        this._sourceInput.remove();
        this._sourceInput = null;
      }

      // Remove review toggle
      if (this._reviewToggle) {
        this._reviewToggle.remove();
        this._reviewToggle = null;
      }

      // Remove review panel
      if (this._reviewPanel) {
        this._reviewPanel.remove();
        this._reviewPanel = null;
      }

      // Remove form interceptor
      this._removeFormInterceptor();

      // Remove all injected fact elements
      document.querySelectorAll(
        '.feynman-facts-badge, .feynman-facts-review-panel, ' +
        '.feynman-facts-review-toggle, .feynman-facts-source-input, ' +
        '.feynman-facts-section-label'
      ).forEach(el => el.remove());

      // Restore opacity and borders on list rows
      document.querySelectorAll('#list-items .list-row').forEach(row => {
        row.style.opacity = '';
        row.style.borderLeft = '';
        row.style.paddingLeft = '';
      });

      // Restore section labels
      this._restoreSectionLabels();
    },

    renderOverlay() {
      const listItems = document.getElementById('list-items');
      if (!listItems) return;

      // Remove previous badges (avoid duplication)
      listItems.querySelectorAll('.feynman-facts-badge').forEach(el => el.remove());

      const rows = listItems.querySelectorAll('.list-row');
      const reviewItems = [];

      rows.forEach(row => {
        const textSpan = row.querySelector('.list-text');
        if (!textSpan) return;

        const rawText = textSpan.textContent;
        const parsed = this._parseConfidence(rawText);

        // Apply visual treatment based on confidence
        this._applyConfidenceStyle(row, parsed.level);

        // Add confidence badge
        if (parsed.level) {
          const badge = document.createElement('span');
          badge.className = 'feynman-facts-badge feynman-facts-badge-' + parsed.level;
          badge.textContent = parsed.label;
          badge.title = parsed.label;
          // Insert before the row actions
          const actions = row.querySelector('.list-row-actions');
          if (actions) {
            actions.insertAdjacentElement('beforebegin', badge);
          }
        }

        // Strip the prefix from display text
        if (parsed.cleanText !== rawText) {
          textSpan.textContent = parsed.cleanText;
        }

        // Collect items for review queue
        if (parsed.level === 'estimated' || parsed.level === 'assumed') {
          reviewItems.push({
            text: parsed.cleanText,
            level: parsed.level,
            label: parsed.label,
            idx: row.dataset.idx
          });
        }
      });

      // Update review queue panel
      this._updateReviewPanel(reviewItems);
    },

    _parseConfidence(text) {
      const prefixes = {
        '[V]': { level: 'verified', label: 'Verified' },
        '[O]': { level: 'observed', label: 'Observed' },
        '[E]': { level: 'estimated', label: 'Estimated' },
        '[A]': { level: 'assumed', label: 'Assumed' }
      };
      for (const [prefix, info] of Object.entries(prefixes)) {
        if (text.startsWith(prefix)) {
          return {
            level: info.level,
            label: info.label,
            cleanText: text.slice(prefix.length).trim()
          };
        }
      }
      return { level: null, label: '', cleanText: text };
    },

    _applyConfidenceStyle(row, level) {
      const copperColor = 'var(--feynman-copper, #b87333)';
      switch (level) {
        case 'verified':
          row.style.opacity = '1';
          row.style.borderLeft = '3px solid ' + copperColor;
          row.style.paddingLeft = '8px';
          break;
        case 'observed':
          row.style.opacity = '0.9';
          row.style.borderLeft = '3px solid color-mix(in srgb, ' + copperColor + ' 60%, transparent)';
          row.style.paddingLeft = '8px';
          break;
        case 'estimated':
          row.style.opacity = '0.7';
          row.style.borderLeft = '3px dashed ' + copperColor;
          row.style.paddingLeft = '8px';
          break;
        case 'assumed':
          row.style.opacity = '0.5';
          row.style.borderLeft = '3px dotted ' + copperColor;
          row.style.paddingLeft = '8px';
          break;
        default:
          row.style.opacity = '';
          row.style.borderLeft = '';
          row.style.paddingLeft = '';
          break;
      }
    },

    _injectSourceInput() {
      const form = document.getElementById('add-list-form');
      if (!form) return;

      const input = document.createElement('input');
      input.type = 'text';
      input.className = 'feynman-facts-source-input';
      input.name = 'feynman-source';
      input.placeholder = 'Source/basis (how was this established?)';
      input.autocomplete = 'off';
      input.style.cssText = 'flex:1;min-width:180px;font-size:11px;margin-top:4px;';
      // Insert after the form (as a sibling) to avoid layout issues
      form.insertAdjacentElement('afterend', input);
      this._sourceInput = input;
    },

    _injectReviewToggle() {
      const section = document.getElementById('section-lists');
      if (!section) return;

      const toggle = document.createElement('button');
      toggle.type = 'button';
      toggle.className = 'feynman-facts-review-toggle btn-inline-alt';
      toggle.textContent = '📋 Review Queue';
      toggle.title = 'Show facts needing verification (Estimated/Assumed)';
      toggle.addEventListener('click', () => {
        if (this._reviewPanel) {
          const isHidden = this._reviewPanel.classList.contains('hidden');
          this._reviewPanel.classList.toggle('hidden', !isHidden);
          toggle.classList.toggle('active', isHidden);
        }
      });

      // Insert after the filter row
      const filterRow = section.querySelector('.inline-filter')?.closest('div');
      if (filterRow) {
        filterRow.insertAdjacentElement('afterend', toggle);
      } else {
        const form = document.getElementById('add-list-form');
        if (form) form.insertAdjacentElement('afterend', toggle);
      }
      this._reviewToggle = toggle;

      // Create review panel (starts hidden)
      const panel = document.createElement('div');
      panel.className = 'feynman-facts-review-panel hidden';
      toggle.insertAdjacentElement('afterend', panel);
      this._reviewPanel = panel;
    },

    _updateReviewPanel(items) {
      if (!this._reviewPanel) return;

      if (items.length === 0) {
        this._reviewPanel.innerHTML = '<div class="feynman-facts-review-empty">No facts to review — all verified or observed.</div>';
        if (this._reviewToggle) {
          this._reviewToggle.textContent = '📋 Review Queue (0)';
        }
        return;
      }

      if (this._reviewToggle) {
        this._reviewToggle.textContent = '📋 Review Queue (' + items.length + ')';
      }

      let html = '<div class="feynman-facts-review-title">Facts to Verify or Update</div>';
      items.forEach(item => {
        html += '<div class="feynman-facts-review-item">';
        html += '<span class="feynman-facts-review-badge feynman-facts-badge-' + item.level + '">' + this._esc(item.label) + '</span>';
        html += '<span class="feynman-facts-review-text">' + this._esc(item.text) + '</span>';
        html += '<span class="feynman-facts-review-prompt">Verify or update this fact</span>';
        html += '</div>';
      });
      this._reviewPanel.innerHTML = html;
    },

    _wireFormInterceptor() {
      const form = document.getElementById('add-list-form');
      if (!form) return;

      this._formInterceptor = (e) => {
        // If the source input has a value, append it as a note to the text
        if (this._sourceInput && this._sourceInput.value.trim()) {
          const textInput = form.querySelector('input[name="text"]');
          if (textInput && textInput.value.trim()) {
            const source = this._sourceInput.value.trim();
            textInput.value = textInput.value.trim() + ' // source: ' + source;
          }
          // Clear source input after form submission processes
          setTimeout(() => {
            if (this._sourceInput) this._sourceInput.value = '';
          }, 100);
        }
      };
      form.addEventListener('submit', this._formInterceptor, false);
    },

    _removeFormInterceptor() {
      const form = document.getElementById('add-list-form');
      if (form && this._formInterceptor) {
        form.removeEventListener('submit', this._formInterceptor, false);
        this._formInterceptor = null;
      }
    },

    _relabelSection() {
      // Add "Fact Sets" / "Known Facts" labels
      const listItems = document.getElementById('list-items');
      if (!listItems) return;

      // Check if label already exists
      if (listItems.previousElementSibling?.classList.contains('feynman-facts-section-label')) return;

      const label = document.createElement('div');
      label.className = 'feynman-facts-section-label';
      label.innerHTML = '<span class="feynman-facts-section-title">Known Facts</span>';
      listItems.insertAdjacentElement('beforebegin', label);
    },

    _restoreSectionLabels() {
      document.querySelectorAll('.feynman-facts-section-label').forEach(el => el.remove());
    },

    _esc(str) {
      return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
  };

  const InquiryView = {
    _observer: null,
    _summaryPanel: null,
    _shareInterceptor: null,
    _originalLabels: [],

    activate() {
      // Observe community body for re-renders
      const body = document.getElementById('community-body');
      if (body) {
        this._observer = new MutationObserver(() => {
          this.renderOverlay();
        });
        this._observer.observe(body, { childList: true, subtree: false });
      }

      // Inject "Collective Understanding" summary panel at top of community panel body
      this._injectSummaryPanel();

      // Apply overlay to existing content
      this.renderOverlay();
    },

    deactivate() {
      // Disconnect observer
      if (this._observer) {
        this._observer.disconnect();
        this._observer = null;
      }

      // Remove summary panel
      if (this._summaryPanel) {
        this._summaryPanel.remove();
        this._summaryPanel = null;
      }

      // Remove all injected inquiry elements
      document.querySelectorAll(
        '.feynman-inquiry-badge, .feynman-inquiry-summary, ' +
        '.feynman-inquiry-section-label, .feynman-inquiry-response-badge, ' +
        '.feynman-inquiry-metrics, .feynman-inquiry-share-prompt, ' +
        '.feynman-inquiry-thread-label'
      ).forEach(el => el.remove());

      // Restore original labels
      this._restoreLabels();
    },

    renderOverlay() {
      const section = document.getElementById('section-community');
      if (!section) return;

      // Remove previously injected elements to avoid duplication
      section.querySelectorAll(
        '.feynman-inquiry-badge, .feynman-inquiry-section-label, ' +
        '.feynman-inquiry-response-badge, .feynman-inquiry-metrics, ' +
        '.feynman-inquiry-thread-label'
      ).forEach(el => el.remove());

      // Relabel community panel header
      this._relabelHeaders(section);

      // Process entry cards — add type badges and metrics
      const cards = section.querySelectorAll('.community-entry-card');
      const typeCounts = { finding: 0, question: 0, replication: 0, challenge: 0, synthesis: 0 };

      cards.forEach(card => {
        const type = this._classifyContribution(card);
        if (type && typeCounts[type] !== undefined) typeCounts[type]++;

        // Add type badge to card head
        this._injectTypeBadge(card, type);

        // Replace engagement metrics with citations + replication status
        this._injectMetrics(card, type);

        // Classify comment responses
        this._classifyResponses(card);
      });

      // Label members as "Research Peers" and add thread grouping
      this._relabelMembers(section);

      // Update summary panel counts
      this._updateSummary(typeCounts, cards.length);
    },

    _injectSummaryPanel() {
      const panel = document.getElementById('community-panel');
      if (!panel) return;
      const body = document.getElementById('community-body');
      if (!body) return;

      // Don't double-inject
      if (panel.querySelector('.feynman-inquiry-summary')) return;

      const summary = document.createElement('div');
      summary.className = 'feynman-inquiry-summary';
      summary.innerHTML = `
        <div class="feynman-inquiry-summary-title">Collective Understanding</div>
        <div class="feynman-inquiry-summary-stats">
          <span class="feynman-inquiry-stat"><span class="feynman-inquiry-stat-count" data-stat="findings">0</span> Findings</span>
          <span class="feynman-inquiry-stat"><span class="feynman-inquiry-stat-count" data-stat="questions">0</span> Open Questions</span>
          <span class="feynman-inquiry-stat"><span class="feynman-inquiry-stat-count" data-stat="investigations">0</span> Active Investigations</span>
        </div>
        <div class="feynman-inquiry-summary-peers">
          <span class="feynman-inquiry-peers-label">Research Peers</span>
        </div>
      `;
      body.insertAdjacentElement('beforebegin', summary);
      this._summaryPanel = summary;
    },

    _relabelHeaders(section) {
      // Relabel "Communities" header → "Research Collective"
      const panelHeader = section.querySelector('.service-panel-header span');
      if (panelHeader && panelHeader.textContent === 'Communities') {
        this._storeLabel(panelHeader, panelHeader.textContent);
        panelHeader.textContent = 'Research Collective';
      }

      // Relabel community hint text
      const hint = section.querySelector('.community-hint');
      if (hint && !hint.dataset.feynmanRelabeled) {
        this._storeLabel(hint, hint.innerHTML);
        hint.innerHTML = 'Choose a <strong>research collective</strong>, then add <strong>shared findings</strong> from your investigations. This bar stays visible while you scroll entries.';
        hint.dataset.feynmanRelabeled = 'true';
      }

      // Relabel tab labels
      const tabs = section.querySelectorAll('.community-tab');
      tabs.forEach(tab => {
        if (tab.dataset.view === 'comments' && tab.textContent === 'Comments') {
          this._storeLabel(tab, tab.textContent);
          tab.textContent = 'Peer Review';
        } else if (tab.dataset.view === 'unified' && tab.textContent === 'Unified') {
          this._storeLabel(tab, tab.textContent);
          tab.textContent = 'Shared Findings';
        }
      });

      // Relabel "collection" toolbar label
      const toolbarLabel = section.querySelector('.community-toolbar-label');
      if (toolbarLabel && toolbarLabel.textContent === 'collection') {
        this._storeLabel(toolbarLabel, toolbarLabel.textContent);
        toolbarLabel.textContent = 'collective';
      }

      // Relabel annotation headers
      section.querySelectorAll('.ann-h').forEach(ann => {
        if (ann.textContent === 'annotations' || ann.textContent === 'comments') {
          if (!ann.dataset.feynmanRelabeled) {
            this._storeLabel(ann, ann.textContent);
            ann.textContent = 'Peer Review';
            ann.dataset.feynmanRelabeled = 'true';
          }
        }
      });
    },

    _classifyContribution(card) {
      // Classify based on card content heuristics
      const headEl = card.querySelector('.community-entry-head code');
      const sourceRef = headEl ? headEl.textContent : '';
      const bodyText = (card.querySelector('.community-journal-body') ||
                        card.querySelector('.community-task-slim') ||
                        card.querySelector('.community-raw'))?.textContent || '';
      const lowerBody = bodyText.toLowerCase();

      // Check community tags on the card
      const tagsEl = card.querySelector('.comm-tag-pill');
      const tags = [];
      card.querySelectorAll('.comm-tag-pill').forEach(t => tags.push(t.textContent.toLowerCase()));

      // Explicit tag-based classification
      if (tags.includes('finding') || tags.includes('result')) return 'finding';
      if (tags.includes('question') || tags.includes('inquiry')) return 'question';
      if (tags.includes('replication') || tags.includes('replicate')) return 'replication';
      if (tags.includes('challenge') || tags.includes('counter')) return 'challenge';
      if (tags.includes('synthesis') || tags.includes('summary')) return 'synthesis';

      // Heuristic-based classification from content
      if (lowerBody.includes('?') && (lowerBody.includes('how') || lowerBody.includes('why') || lowerBody.includes('what'))) return 'question';
      if (lowerBody.includes('found') || lowerBody.includes('discovered') || lowerBody.includes('result:') || lowerBody.includes('conclusion:')) return 'finding';
      if (lowerBody.includes('replicated') || lowerBody.includes('confirmed') || lowerBody.includes('reproduced')) return 'replication';
      if (lowerBody.includes('however') || lowerBody.includes('contradicts') || lowerBody.includes('disagree') || lowerBody.includes('counter')) return 'challenge';
      if (lowerBody.includes('synthesis') || lowerBody.includes('combined') || lowerBody.includes('integrat')) return 'synthesis';

      // Default based on entry type
      if (sourceRef.includes('.task.')) return 'finding';
      if (sourceRef.includes('.journal.')) return 'finding';
      return 'finding'; // default
    },

    _injectTypeBadge(card, type) {
      const head = card.querySelector('.community-entry-head');
      if (!head) return;
      // Don't double-inject
      if (head.querySelector('.feynman-inquiry-badge')) return;

      const labels = {
        finding: 'Finding',
        question: 'Question',
        replication: 'Replication',
        challenge: 'Challenge',
        synthesis: 'Synthesis'
      };

      const badge = document.createElement('span');
      badge.className = 'feynman-inquiry-badge feynman-inquiry-badge-' + (type || 'finding');
      badge.textContent = labels[type] || 'Finding';
      head.insertAdjacentElement('afterbegin', badge);
    },

    _injectMetrics(card, type) {
      const head = card.querySelector('.community-entry-head');
      if (!head) return;
      // Don't double-inject
      if (card.querySelector('.feynman-inquiry-metrics')) return;

      // Count comments as citations
      const comments = card.querySelectorAll('.community-cmt');
      const citationCount = comments.length;

      // Determine replication status based on type and responses
      let replicationStatus = 'Not yet replicated';
      if (type === 'replication') {
        replicationStatus = 'Replication attempt';
      } else if (citationCount > 2) {
        replicationStatus = 'Under review';
      } else if (type === 'finding' && citationCount > 0) {
        replicationStatus = 'Cited';
      }

      const metrics = document.createElement('div');
      metrics.className = 'feynman-inquiry-metrics';
      metrics.innerHTML = `<span class="feynman-inquiry-metric-citations" title="Citations">${citationCount} citation${citationCount !== 1 ? 's' : ''}</span>` +
        `<span class="feynman-inquiry-metric-replication" title="Replication status">${this._esc(replicationStatus)}</span>`;

      // Insert after the entry head
      head.insertAdjacentElement('afterend', metrics);
    },

    _classifyResponses(card) {
      const comments = card.querySelectorAll('.community-cmt');
      comments.forEach(cmt => {
        // Don't double-inject
        if (cmt.querySelector('.feynman-inquiry-response-badge')) return;

        const body = cmt.textContent.toLowerCase();
        let responseType = 'Clarification Request'; // default

        if (body.includes('agree') || body.includes('confirm') || body.includes('same result') || body.includes('supports') || body.includes('corroborate')) {
          responseType = 'Corroboration';
        } else if (body.includes('also') || body.includes('additionally') || body.includes('building on') || body.includes('extending') || body.includes('furthermore')) {
          responseType = 'Extension';
        } else if (body.includes('however') || body.includes('disagree') || body.includes('counter') || body.includes('contradicts') || body.includes('opposite') || body.includes('but')) {
          responseType = 'Counter-Evidence';
        }

        const badge = document.createElement('span');
        badge.className = 'feynman-inquiry-response-badge feynman-inquiry-response-' + responseType.toLowerCase().replace(/[\s-]+/g, '-');
        badge.textContent = responseType;
        // Insert at beginning of comment
        const timeEl = cmt.querySelector('.community-cmt-t');
        if (timeEl) {
          timeEl.insertAdjacentElement('afterend', badge);
        } else {
          cmt.insertAdjacentElement('afterbegin', badge);
        }
      });
    },

    _relabelMembers(section) {
      // Add "Research Peers" label to the mini journal panel header if visible
      const miniHdr = section.querySelector('.comm-jmini-hdr');
      if (miniHdr && miniHdr.textContent === 'journal' && !miniHdr.dataset.feynmanRelabeled) {
        this._storeLabel(miniHdr, miniHdr.textContent);
        miniHdr.textContent = 'Research Peer Notes';
        miniHdr.dataset.feynmanRelabeled = 'true';
      }

      // Group cards under investigation thread labels
      const body = document.getElementById('community-body');
      if (!body) return;

      // Remove existing thread labels
      body.querySelectorAll('.feynman-inquiry-thread-label').forEach(el => el.remove());

      const cards = body.querySelectorAll('.community-entry-card');
      if (cards.length === 0) return;

      // Group cards by project tag as "investigation threads"
      const threads = {};
      cards.forEach(card => {
        const projBadge = card.querySelector('.badge-project');
        const thread = projBadge ? projBadge.textContent.trim() : '(general)';
        if (!threads[thread]) threads[thread] = [];
        threads[thread].push(card);
      });

      // Insert thread headers if there are multiple threads
      const threadKeys = Object.keys(threads);
      if (threadKeys.length > 1) {
        threadKeys.forEach(thread => {
          const firstCard = threads[thread][0];
          if (!firstCard) return;
          const label = document.createElement('div');
          label.className = 'feynman-inquiry-thread-label';
          label.innerHTML = '<span class="feynman-inquiry-thread-icon">🔬</span> Investigation: ' + this._esc(thread);
          firstCard.insertAdjacentElement('beforebegin', label);
        });
      }
    },

    _updateSummary(typeCounts, totalEntries) {
      if (!this._summaryPanel) return;

      const findingsEl = this._summaryPanel.querySelector('[data-stat="findings"]');
      const questionsEl = this._summaryPanel.querySelector('[data-stat="questions"]');
      const investigationsEl = this._summaryPanel.querySelector('[data-stat="investigations"]');

      if (findingsEl) findingsEl.textContent = typeCounts.finding + typeCounts.replication + typeCounts.synthesis;
      if (questionsEl) questionsEl.textContent = typeCounts.question;

      // Count active investigations = unique project tags across entries
      const body = document.getElementById('community-body');
      const projects = new Set();
      if (body) {
        body.querySelectorAll('.badge-project').forEach(el => {
          projects.add(el.textContent.trim());
        });
      }
      if (investigationsEl) investigationsEl.textContent = projects.size || (totalEntries > 0 ? 1 : 0);
    },

    _storeLabel(el, originalText) {
      this._originalLabels.push({ el, originalText });
    },

    _restoreLabels() {
      this._originalLabels.forEach(({ el, originalText }) => {
        if (el.dataset && el.dataset.feynmanRelabeled) {
          delete el.dataset.feynmanRelabeled;
        }
        if (el.tagName === 'DIV' || el.tagName === 'P') {
          el.innerHTML = originalText;
        } else {
          el.textContent = originalText;
        }
      });
      this._originalLabels = [];
    },

    _esc(str) {
      return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
  };

  // ── Investigation Context ───────────────────────────────────────────────────

  const InvestigationContext = {
    activeId: null,
    _recentKey: 'ww_feynman_investigations_recent',

    /**
     * Set the active investigation by id. Persists to localStorage,
     * updates the investigation bar, and applies cross-view filtering.
     */
    set(investigationId) {
      this.activeId = investigationId || null;
      localStorage.setItem('ww_feynman_investigation', this.activeId || '');
      if (this.activeId) this._pushRecent(this.activeId);
      this.updateHeader();
      this.applyFilter();
    },

    /**
     * Restore investigation context from localStorage on theme activation.
     */
    restore() {
      this.activeId = localStorage.getItem('ww_feynman_investigation') || null;
      this.updateHeader();
      if (this.activeId) this.applyFilter();
    },

    /**
     * Update the .feynman-investigation-bar content. Shows the active
     * investigation name, summary counts, and a clear button.
     * If no investigation is active, shows a prompt to set one.
     */
    updateHeader() {
      var bar = document.querySelector('.feynman-investigation-bar');
      if (!bar) return;

      if (!this.activeId) {
        bar.innerHTML = this._renderInactiveBar();
        bar.classList.remove('hidden');
        this._wireBarEvents(bar);
        return;
      }

      var summary = this.getSummary();
      bar.innerHTML =
        '<span class="feynman-investigation-icon">🔬</span>' +
        '<span class="feynman-investigation-label">Current Investigation:</span>' +
        '<span class="feynman-investigation-name">' + this._esc(this.activeId) + '</span>' +
        '<span class="feynman-investigation-summary">' +
          '<span class="feynman-inv-stat" title="Experiments">' + summary.experiments + ' exp</span>' +
          '<span class="feynman-inv-stat" title="Measurements">' + summary.measurements + ' meas</span>' +
          '<span class="feynman-inv-stat" title="Observations">' + summary.observations + ' obs</span>' +
          '<span class="feynman-inv-stat" title="Conclusions">' + summary.conclusions + ' concl</span>' +
        '</span>' +
        '<button class="feynman-investigation-edit-btn" title="Change investigation">✎</button>' +
        '<button class="feynman-investigation-clear-btn" title="Clear active investigation">✕</button>';

      bar.classList.remove('hidden');
      this._wireBarEvents(bar);
    },

    /**
     * Apply filter/highlight across the current view for records matching
     * the active investigation (tasks with +inv_{id} tag, time entries
     * for those tasks, journal entries with investigation:{id} content or tag).
     */
    applyFilter() {
      // Remove previous highlights
      document.querySelectorAll('.feynman-inv-highlight').forEach(function(el) {
        el.classList.remove('feynman-inv-highlight');
      });
      document.querySelectorAll('.feynman-inv-dim').forEach(function(el) {
        el.classList.remove('feynman-inv-dim');
      });

      if (!this.activeId) return;

      var invTag = 'inv_' + this.activeId;

      // Filter Tasks (Experiment View)
      this._filterTasks(invTag);

      // Filter Time entries (Measurement View)
      this._filterTimeEntries(invTag);

      // Filter Journal entries (Notebook View)
      this._filterJournalEntries();

      // List items - no filter for now (per design)
    },

    /**
     * Get summary counts for the active investigation by reading from DOM
     * or cached data.
     * Returns { experiments, measurements, observations, conclusions }
     */
    getSummary() {
      var result = { experiments: 0, measurements: 0, observations: 0, conclusions: 0 };
      if (!this.activeId) return result;

      var invTag = 'inv_' + this.activeId;

      // Count experiments (tasks with the investigation tag)
      var taskRows = document.querySelectorAll('#task-list .task-row');
      taskRows.forEach(function(row) {
        var tags = (row.dataset.tags || '').split(',').filter(Boolean);
        if (tags.includes(invTag)) {
          result.experiments++;
          // Check if concluded (has conclusion annotation)
          var next = row.nextElementSibling;
          while (next && next.classList.contains('task-row-ann')) {
            if (next.textContent.toLowerCase().includes('conclusion:')) {
              result.conclusions++;
              break;
            }
            next = next.nextElementSibling;
          }
        }
      });

      // Count measurements (time intervals associated with tagged tasks)
      var intervals = document.querySelectorAll('#time-intervals .interval-row');
      intervals.forEach(function(iv) {
        var tags = (iv.dataset.tags || '').toLowerCase();
        if (tags.includes(invTag.toLowerCase())) {
          result.measurements++;
        }
      });

      // Count observations (journal entries with investigation tag)
      var entries = document.querySelectorAll('#journal-list .journal-entry');
      entries.forEach(function(entry) {
        if (InvestigationContext._entryMatchesInvestigation(entry)) {
          result.observations++;
        }
      });

      return result;
    },

    /**
     * Hide the investigation indicator and remove all highlights.
     * Called on theme deactivation.
     */
    hide() {
      // Clear highlights
      document.querySelectorAll('.feynman-inv-highlight').forEach(function(el) {
        el.classList.remove('feynman-inv-highlight');
      });
      document.querySelectorAll('.feynman-inv-dim').forEach(function(el) {
        el.classList.remove('feynman-inv-dim');
      });
      // Clear bar content
      var bar = document.querySelector('.feynman-investigation-bar');
      if (bar) {
        bar.innerHTML = '';
        bar.classList.add('hidden');
      }
    },

    // ── Private helpers ────────────────────────────────────────────────────────

    _filterTasks(invTag) {
      var taskRows = document.querySelectorAll('#task-list .task-row');
      if (!taskRows.length) return;

      var hasAny = false;
      taskRows.forEach(function(row) {
        var tags = (row.dataset.tags || '').split(',').filter(Boolean);
        if (tags.includes(invTag)) {
          row.classList.add('feynman-inv-highlight');
          hasAny = true;
        } else {
          row.classList.add('feynman-inv-dim');
        }
      });

      // If no tasks match, remove dim (don't dim everything)
      if (!hasAny) {
        taskRows.forEach(function(row) {
          row.classList.remove('feynman-inv-dim');
        });
      }
    },

    _filterTimeEntries(invTag) {
      var intervals = document.querySelectorAll('#time-intervals .interval-row');
      if (!intervals.length) return;

      var hasAny = false;
      intervals.forEach(function(iv) {
        var tags = (iv.dataset.tags || '').toLowerCase();
        if (tags.includes(invTag.toLowerCase())) {
          iv.classList.add('feynman-inv-highlight');
          hasAny = true;
        } else {
          iv.classList.add('feynman-inv-dim');
        }
      });

      if (!hasAny) {
        intervals.forEach(function(iv) {
          iv.classList.remove('feynman-inv-dim');
        });
      }
    },

    _filterJournalEntries() {
      var entries = document.querySelectorAll('#journal-list .journal-entry');
      if (!entries.length) return;

      var self = this;
      var hasAny = false;
      entries.forEach(function(entry) {
        if (self._entryMatchesInvestigation(entry)) {
          entry.classList.add('feynman-inv-highlight');
          hasAny = true;
        } else {
          entry.classList.add('feynman-inv-dim');
        }
      });

      if (!hasAny) {
        entries.forEach(function(entry) {
          entry.classList.remove('feynman-inv-dim');
        });
      }
    },

    _entryMatchesInvestigation(entry) {
      if (!this.activeId) return false;
      var invTag = 'inv_' + this.activeId;

      // Check if entry body contains investigation:{id} or +inv_{id}
      var bodyEl = entry.querySelector('.entry-body');
      var body = bodyEl ? bodyEl.textContent.toLowerCase() : '';
      if (body.includes('investigation:' + this.activeId.toLowerCase())) return true;
      if (body.includes('+' + invTag.toLowerCase())) return true;

      // Check tags on the metadata button
      var metaBtn = entry.querySelector('.entry-meta-btn');
      if (metaBtn) {
        var tags = (metaBtn.dataset.tags || '').split(',').filter(Boolean);
        for (var i = 0; i < tags.length; i++) {
          if (tags[i].trim().toLowerCase() === invTag.toLowerCase()) return true;
        }
      }

      // Check meta chips for the tag
      var chips = entry.querySelectorAll('.jmeta-chip, .ledger-tag-chip');
      for (var j = 0; j < chips.length; j++) {
        var chipText = chips[j].textContent.trim().toLowerCase();
        if (chipText === invTag.toLowerCase() || chipText === '+' + invTag.toLowerCase()) return true;
      }

      return false;
    },

    _renderInactiveBar() {
      var recentHtml = this._getRecentInvestigations().map(function(id) {
        return '<button class="feynman-investigation-recent-btn" data-inv-id="' +
          InvestigationContext._esc(id) + '" title="Set investigation: ' +
          InvestigationContext._esc(id) + '">' + InvestigationContext._esc(id) + '</button>';
      }).join('');

      return '<span class="feynman-investigation-icon">🔬</span>' +
        '<span class="feynman-investigation-label feynman-investigation-inactive">No active investigation</span>' +
        '<input class="feynman-investigation-input" type="text" placeholder="Set investigation ID…" autocomplete="off" />' +
        '<button class="feynman-investigation-set-btn" title="Set investigation">→</button>' +
        (recentHtml ? '<span class="feynman-investigation-recents">' + recentHtml + '</span>' : '');
    },

    _wireBarEvents(bar) {
      var self = this;

      // Clear button
      var clearBtn = bar.querySelector('.feynman-investigation-clear-btn');
      if (clearBtn) {
        clearBtn.addEventListener('click', function() {
          self.set(null);
        });
      }

      // Edit/change button → toggle input inline
      var editBtn = bar.querySelector('.feynman-investigation-edit-btn');
      if (editBtn) {
        editBtn.addEventListener('click', function() {
          // Replace bar content with edit mode
          var currentId = self.activeId || '';
          bar.innerHTML =
            '<span class="feynman-investigation-icon">🔬</span>' +
            '<span class="feynman-investigation-label">Change investigation:</span>' +
            '<input class="feynman-investigation-input" type="text" value="' + self._esc(currentId) + '" autocomplete="off" />' +
            '<button class="feynman-investigation-set-btn" title="Set investigation">→</button>' +
            '<button class="feynman-investigation-cancel-btn" title="Cancel">✕</button>';
          self._wireInputEvents(bar);
          var input = bar.querySelector('.feynman-investigation-input');
          if (input) { input.focus(); input.select(); }
        });
      }

      // Set button (for inactive state)
      var setBtn = bar.querySelector('.feynman-investigation-set-btn');
      if (setBtn) {
        setBtn.addEventListener('click', function() {
          var input = bar.querySelector('.feynman-investigation-input');
          if (input && input.value.trim()) {
            self.set(input.value.trim());
          }
        });
      }

      // Input Enter key (for inactive state)
      var input = bar.querySelector('.feynman-investigation-input');
      if (input) {
        input.addEventListener('keydown', function(e) {
          if (e.key === 'Enter') {
            e.preventDefault();
            if (input.value.trim()) self.set(input.value.trim());
          } else if (e.key === 'Escape') {
            e.preventDefault();
            self.updateHeader();
          }
        });
      }

      // Recent investigation buttons
      bar.querySelectorAll('.feynman-investigation-recent-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
          self.set(btn.dataset.invId);
        });
      });
    },

    _wireInputEvents(bar) {
      var self = this;

      var setBtn = bar.querySelector('.feynman-investigation-set-btn');
      var cancelBtn = bar.querySelector('.feynman-investigation-cancel-btn');
      var input = bar.querySelector('.feynman-investigation-input');

      if (setBtn) {
        setBtn.addEventListener('click', function() {
          if (input && input.value.trim()) {
            self.set(input.value.trim());
          }
        });
      }

      if (cancelBtn) {
        cancelBtn.addEventListener('click', function() {
          self.updateHeader();
        });
      }

      if (input) {
        input.addEventListener('keydown', function(e) {
          if (e.key === 'Enter') {
            e.preventDefault();
            if (input.value.trim()) self.set(input.value.trim());
          } else if (e.key === 'Escape') {
            e.preventDefault();
            self.updateHeader();
          }
        });
      }
    },

    _pushRecent(id) {
      var recent = this._getRecentInvestigations();
      // Remove if already present
      recent = recent.filter(function(r) { return r !== id; });
      // Add to front
      recent.unshift(id);
      // Keep max 5
      if (recent.length > 5) recent = recent.slice(0, 5);
      try {
        localStorage.setItem(this._recentKey, JSON.stringify(recent));
      } catch (e) { /* ignore */ }
    },

    _getRecentInvestigations() {
      try {
        var raw = localStorage.getItem(this._recentKey);
        if (raw) return JSON.parse(raw);
      } catch (e) { /* ignore */ }
      return [];
    },

    _esc(str) {
      return String(str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
  };

  // ── Views dispatcher ───────────────────────────────────────────────────────

  const FeynmanViews = {
    _activeView: null,

    activateSection(section) {
      this.deactivateAll();
      const viewMap = {
        tasks: ExperimentView,
        time: MeasurementView,
        journal: NotebookView,
        ledger: ConservationView,
        lists: FactsView,
        community: InquiryView
      };
      const view = viewMap[section];
      if (view) {
        view.activate();
        this._activeView = view;
      }
      // Re-apply investigation filter after view activates
      if (InvestigationContext.activeId) {
        // Small delay to let the view's renderOverlay finish first
        setTimeout(function() {
          InvestigationContext.applyFilter();
          InvestigationContext.updateHeader();
        }, 50);
      }
    },

    deactivateAll() {
      if (this._activeView) {
        this._activeView.deactivate();
        this._activeView = null;
      }
      // Remove investigation highlights when switching views
      document.querySelectorAll('.feynman-inv-highlight').forEach(function(el) {
        el.classList.remove('feynman-inv-highlight');
      });
      document.querySelectorAll('.feynman-inv-dim').forEach(function(el) {
        el.classList.remove('feynman-inv-dim');
      });
    }
  };

  // ── Theme manifest ─────────────────────────────────────────────────────────

  window.registerTheme({
    id: 'feynman',
    label: 'Feynman ⚛',
    cssClass: 'feynman-active',
    modes: [
      { value: '', label: '—' },
      { value: 'focus', label: '🔬 focus' },
      { value: 'review', label: '📋 review' }
    ],
    affectedSections: ['tasks', 'time', 'journal', 'ledger', 'lists', 'community'],

    activate(section) {
      // Insert investigation bar if not present (must exist before restore)
      if (!document.querySelector('.feynman-investigation-bar')) {
        var header = document.querySelector('.content-header');
        if (header) {
          var bar = document.createElement('div');
          bar.className = 'feynman-investigation-bar';
          header.insertAdjacentElement('afterend', bar);
        }
      }
      InvestigationContext.restore();
      FeynmanViews.activateSection(section);
      applyFeynmanLabels(document.body);
    },

    deactivate() {
      restoreDefaultLabels(document.body);
      FeynmanViews.deactivateAll();
      InvestigationContext.hide();
      // Remove investigation bar
      var bar = document.querySelector('.feynman-investigation-bar');
      if (bar) bar.remove();
    },

    onSectionChange(section) {
      FeynmanViews.activateSection(section);
    },

    onModeChange(mode) {
      document.body.classList.remove('feynman-focus', 'feynman-review');
      if (mode) document.body.classList.add('feynman-' + mode);
    }
  });
})();
