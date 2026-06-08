// themes/twain.js — Twain theme (self-registering)
(function() {
  'use strict';

  // Legacy migration: migrate old localStorage key to new system
  const legacyTheme = localStorage.getItem('ww_journal_theme');
  const newTheme = localStorage.getItem('ww_active_theme');
  if (legacyTheme === 'twain' && !newTheme) {
    localStorage.setItem('ww_active_theme', 'twain');
  }

  window.registerTheme({
    id: 'twain',
    label: 'Twain ✦',
    cssClass: 'twain-active',
    modes: [{ value: '', label: '—' }, { value: 'river', label: '〰 river' }],
    affectedSections: ['journal'],

    activate(section) {
      // For now, delegate to the existing activateJournalTheme function in app.js
      // This will be the only entry point after task 3.2 removes the old code
      if (typeof window._twainActivate === 'function') {
        window._twainActivate(section);
      } else if (typeof activateJournalTheme !== 'undefined') {
        activateJournalTheme('twain');
      }
    },

    deactivate() {
      if (typeof window._twainDeactivate === 'function') {
        window._twainDeactivate();
      } else if (typeof activateJournalTheme !== 'undefined') {
        activateJournalTheme('default');
      }
    },

    onModeChange(mode) {
      document.body.classList.toggle('river-mode', mode === 'river');
    },

    onSectionChange(section) {
      // Twain only affects journal, so toggle visibility based on section
      if (section === 'journal') {
        document.getElementById('content-area')?.classList.add('twain-journal-active');
      } else {
        document.getElementById('content-area')?.classList.remove('twain-journal-active');
      }
    }
  });
})();
