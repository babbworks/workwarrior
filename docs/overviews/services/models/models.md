# services/models/models.sh

**Type:** Executed service script
**Invoked by:** `ww model <action>`
**Subservient to:** Models service (`services/models/`)

---

## Role

LLM provider and model registry. Stores provider configurations (base URL, API key env var) and model definitions (provider, model ID, notes) in `config/models.yaml`. Powers `ww model list/show/add/set-default` and provides the model resolution used by AI-integrated services.

---

## Data Store

`config/models.yaml`:
```yaml
default: gpt-4o-mini
providers:
  openai:
    type: openai
    base_url: https://api.openai.com/v1
    api_key_env: OPENAI_API_KEY
  anthropic:
    type: anthropic
    base_url: https://api.anthropic.com
    api_key_env: ANTHROPIC_API_KEY
models:
  gpt-4o-mini:
    provider: openai
    model_id: gpt-4o-mini
    notes: "Fast, cheap, good for task management"
  claude-sonnet:
    provider: anthropic
    model_id: claude-sonnet-4-5
```

---

## Functions

**`ensure_models_config()`** — Creates `config/models.yaml` with empty structure if not present.

**`list_models()`** — Lists all models with provider, model ID, and default marker.

**`list_providers()`** — Lists all providers with type and base URL.

**`show_model(name)`** — Full details for a model including provider config and notes.

**`add_provider(name, type, base_url, [api_key_env])`** — Adds a provider entry. Validates type is a known value.

**`add_model(name, provider, model_id, [notes])`** — Adds a model entry. Validates provider exists.

**`set_default(name)`** — Sets the `default:` field in `models.yaml`. Validates model exists.

**`remove_model(name)`** — Removes a model entry. Errors if it is the current default.

---

## Environment Check

**`ww model env`** — Shows which API key env vars are set/unset for all configured providers.

**`ww model check`** — Returns non-zero if the default model's provider API key env var is not set. Used by services that need a model to be available before proceeding.

---

## Usage by Other Services

The models registry is consumed by any ww service that makes LLM calls. Currently used by `ww mcp` (for model selection in the MCP server) and planned for use by `ww questions` (AI-assisted question generation) and future AI-native services.
