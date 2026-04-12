# Models Service

The Models service manages configuration for local and remote LLM providers and models.
It stores configuration in:

`WW_BASE/config/models.yaml` (default: `~/ww/config/models.yaml`)

## Data Model

```yaml
models:
  default: "gpt-4o-mini"
  gpt-4o-mini:
    provider: openai
    id: gpt-4o-mini
    notes: fast
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

## Commands

```bash
ww model <name> <type> <base_url> [api_key_env]
ww model list
ww model providers
ww model env
ww model check
ww model show <model>
ww model add-provider <name> <type> <base_url> [api_key_env]
ww model remove-provider <name>
ww model add-model <name> <provider> <model_id> [notes]
ww model set-default <name>
ww model remove-model <name>
```

## Examples

```bash
ww model openai openai https://api.openai.com/v1 OPENAI_API_KEY
ww model add-provider openai openai https://api.openai.com/v1 OPENAI_API_KEY
ww model remove-provider openai
ww model add-model gpt-4o-mini openai gpt-4o-mini "fast"
ww model set-default gpt-4o-mini
```

## Notes

- Singular create pattern: `ww model <name> <type> <base_url> [api_key_env]` is a shortcut for `add-provider`.
- `ww models` maps to list behavior.
- This service only stores configuration. No network calls are made.
- Use `api_key_env` to store the environment variable name for credentials.
- `ww model remove-model` will fail if the model is currently set as default.
- `ww model remove-provider` will fail if any model still references that provider.
