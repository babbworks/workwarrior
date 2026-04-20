# services/models/models.sh

**Type:** Executed service script
**Invoked by:** `ww model <action>`
**Subservient to:** Models service (`services/models/`)

---

## Role

LLM provider and model registry. Stores provider configurations (base URL, API key env var) and model definitions (provider, model ID, notes) in `config/models.yaml`. Powers `ww model list/show/add/set-default` and provides model/provider metadata to AI-integrated services.

---

## Data Store

`config/models.yaml`:
```yaml
models:
  default: gpt-4o-mini
  gpt-4o-mini:
    provider: openai
    id: gpt-4o-mini
    notes: "Fast, cheap, good for task management"
  llama-local:
    provider: ollama
    id: llama3.2:3b
providers:
  openai:
    type: openai
    base_url: https://api.openai.com/v1
    api_key_env: OPENAI_API_KEY
  ollama:
    type: ollama
    base_url: http://localhost:11434
    api_key_env: ""
```

---

## Functions

**`ensure_models_config()`** — Creates `config/models.yaml` with empty structure if not present.

**`list_models()`** — Lists configured model names and the default model.

**`list_providers()`** — Lists configured provider names.

**`show_model(name)`** — Full details for a model including provider config and notes.

**`add_provider(name, type, base_url, [api_key_env])`** — Adds a provider entry.

**`remove_provider(name)`** — Removes a provider entry if no models reference it.

**`add_model(name, provider, model_id, [notes])`** — Adds a model entry. Validates provider exists.

**`set_default(name)`** — Sets the `default:` field in `models.yaml`. Validates model exists.

**`remove_model(name)`** — Removes a model entry. Errors if it does not exist or is the current default.

**Singular create shortcut** — `ww model <name> <type> <base_url> [api_key_env]` maps to provider creation for agentic flows.

---

## Environment Check

**`ww model env`** — Shows which API key env vars are set/unset for all configured providers.

**`ww model check`** — Returns non-zero if any configured provider with an `api_key_env` is missing that environment variable.

---

## Usage by Other Services

The models registry is consumed by ww services that make LLM calls. `ww model` itself is configuration-only and makes no external API calls.

## Changelog

- 2026-04-10 — Initial version
- 2026-04-11 — Corrected YAML shape and command behavior notes (`ww model` primary, `ww models` list alias), added `remove-provider` + singular create shortcut
