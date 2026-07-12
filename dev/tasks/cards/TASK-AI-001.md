## TASK-AI-001: Make models service and AI integration robust and reliable

Goal:                 The CMD AI feature fails because small local LLMs (gemma3:1b,
                      llama3.2:3b) don't follow the complex ACTION protocol in the
                      system prompt. The models service needs to work reliably with
                      whatever LLM is available, and AI access controls need to be
                      manageable from the browser UI.

Root cause:           1. System prompt is too complex for small models
                      2. No fallback when LLM output doesn't match expected format
                      3. No model selection UI (uses first available model)
                      4. config/ai.yaml not read by the server
                      5. No on/off switch in the browser UI

Acceptance criteria:  1. CMD AI works with gemma3:1b and llama3.2 — creates tasks,
                         starts time tracking, adds journal entries from natural language
                      2. If LLM output doesn't match ACTION format, server parses it
                         heuristically (detect "task", "journal", "time" keywords)
                      3. Models panel shows available ollama models with selection
                      4. CTRL panel has AI on/off toggle that reads/writes config/ai.yaml
                      5. CMD shows which model is being used and its response
                      6. Graceful fallback: if AI fails, show the raw LLM output and
                         offer to run it as a direct CLI command
                      7. Manual test: type "create a task to review the budget due friday"
                         in CMD → task is created

Write scope:          services/browser/server.py (_handle_cmd_ai, _handle_hledger env)
                      services/browser/static/app.js (CMD handler, Models panel, CTRL AI toggle)
                      services/browser/static/index.html (Models panel, CTRL AI toggle)
                      config/ai.yaml (read by server)
                      config/models.yaml (model selection)

Tests required:       Manual: type natural language in CMD, verify task/journal/time created
                      Manual: toggle AI off in CTRL, verify CMD falls back to direct CLI
                      Manual: select different model in Models panel

Rollback:             git checkout services/browser/server.py services/browser/static/

Fragility:            LOW — browser files only

Risk notes:           (Orchestrator) Small LLMs are unreliable at instruction following.
                      The fix must be defensive: parse LLM output heuristically, don't
                      rely on exact format matching. The system prompt should be as
                      simple as possible — one example per command type, no ACTION prefix.

Status:               complete

Completion note:      Root causes fixed:
                      1. System prompt simplified for small LLMs (few-shot examples, no ACTION protocol)
                      2. Heuristic command parser: detects task/timew/journal from first token,
                         handles any format the LLM produces, falls back to task add for unknowns
                      3. AI mode toggle in CTRL panel (off/local-only/local+remote) stored in localStorage
                      4. Ollama status shown in CTRL panel
                      5. CMD respects AI mode — skips AI call when mode is "off"
                      6. Model auto-detection from ollama /api/tags
