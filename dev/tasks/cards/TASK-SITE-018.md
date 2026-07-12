## TASK-SITE-018: Type-aware UDA inputs in task inline editor

Goal:                 UDA input fields in the task inline editor currently
                     render all UDAs as <input type="text">. Fields should
                     use type-appropriate controls based on the UDA type
                     returned from /data/udas.

Scope summary:
  UDA type → input type mapping:
    date     → <input type="date"> with date format conversion
    numeric  → <input type="number">
    duration → <input type="text" pattern="[0-9]+[smhd]"> with hint
    string   → <input type="text"> (current behavior)

  For UDAs with a defined set of valid values (e.g. priority-like enums),
  render a <select> if the UDA definition includes allowed values.

  The /data/udas endpoint already returns {name, type, label} per UDA —
  extend it (or use it as-is) to determine input type.

  Also: the "add UDA" row in the editor should validate the input type
  before submission (prevent "abc" for a numeric UDA).

Write scope:          services/browser/static/app.js
                      services/browser/server.py (/data/udas: add type info)

Fragility:            LOW (browser static + minor server.py addition)

Dependencies:         none

Status:               complete — 2026-04-13
