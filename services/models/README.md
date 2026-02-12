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
ww models list
ww models providers
ww models env
ww models check
ww models show <model>
ww models add-provider <name> <type> <base_url> [api_key_env]
ww models add-model <name> <provider> <model_id> [notes]
ww models set-default <name>
ww models remove-model <name>
```

## Examples

```bash
ww models add-provider openai openai https://api.openai.com/v1 OPENAI_API_KEY
ww models add-model gpt-4o-mini openai gpt-4o-mini "fast"
ww models set-default gpt-4o-mini
```

## Notes

- This service only stores configuration. No network calls are made.
- Use `api_key_env` to store the environment variable name for credentials.
