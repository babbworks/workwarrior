## TASK-AI-002: Ollama sensing, activation, and per-profile AI config

Goal:                 Make ollama automatically sensed, easily activated, and
                      configurable per-profile.

Acceptance criteria:  1. Shell init probes ollama in background (1s timeout), sets WW_OLLAMA_AVAILABLE
                      2. ww ctrl ai-on enables AI + checks ollama + shows status
                      3. ww ctrl ai-off disables all AI
                      4. ww ctrl ai-status shows: mode, cmd_ai, preferred provider,
                         profile override, ollama probe result with model list
                      5. profiles/<name>/ai.yaml overrides global mode and preferred_provider
                      6. Browser server reads profile-level ai.yaml when resolving providers

Write scope:          bin/ww-init.sh (background probe)
                      services/ctrl/ctrl.sh (ai-on, ai-off, ai-status, _probe_ollama)
                      services/browser/server.py (_read_ai_config profile override)

Tests required:       Manual: ww ctrl ai-status (with and without ollama running)
                      Manual: ww ctrl ai-on / ai-off
                      Manual: create profiles/acme/ai.yaml with mode: off, verify browser respects it

Fragility:            LOW (ctrl.sh is new, ww-init.sh is SERIALIZED but change is additive)

Status:               complete

Completion note:      All three levels implemented:
                      L1: ww-init.sh background probe sets WW_OLLAMA_AVAILABLE
                      L2: ww ctrl ai-on/off/status commands with ollama probe
                      L3: server reads profiles/<name>/ai.yaml as override
