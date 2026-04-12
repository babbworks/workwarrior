#!/usr/bin/env bats
# tests/test-models-service.bats — models service parsing and behavior checks

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export REPO_BASE="${BATS_TEST_DIRNAME}/.."
  export MODELS_SCRIPT="${REPO_BASE}/services/models/models.sh"
  export TEST_WW_BASE
  TEST_WW_BASE="$(mktemp -d)"
  mkdir -p "${TEST_WW_BASE}/config"
}

teardown() {
  rm -rf "${TEST_WW_BASE}"
}

write_models_fixture() {
  cat > "${TEST_WW_BASE}/config/models.yaml" << 'EOF'
models:
  default: gpt-4o-mini
  gpt-4o-mini:
    provider: openai
    id: gpt-4o-mini
  tiny-local:
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
EOF
}

@test "model list prints only model names and default" {
  write_models_fixture

  run env WW_BASE="${TEST_WW_BASE}" bash "${MODELS_SCRIPT}" list
  assert_success
  assert_output --partial "Models:"
  assert_output --partial "  • gpt-4o-mini"
  assert_output --partial "  • tiny-local"
  assert_output --partial "Default: gpt-4o-mini"
  refute_output --partial "provider"
  refute_output --partial "base_url"
  refute_output --partial "api_key_env"
}

@test "model providers prints only provider names" {
  write_models_fixture

  run env WW_BASE="${TEST_WW_BASE}" bash "${MODELS_SCRIPT}" providers
  assert_success
  assert_output --partial "Providers:"
  assert_output --partial "  • openai"
  assert_output --partial "  • ollama"
  refute_output --partial "default"
}

@test "model env only reports providers with configured env vars" {
  write_models_fixture

  run env WW_BASE="${TEST_WW_BASE}" bash "${MODELS_SCRIPT}" env
  assert_success
  assert_output --partial "Provider Environment Variables:"
  assert_output --partial "openai: OPENAI_API_KEY"
  refute_output --partial "ollama:"
}

@test "model check fails when required env var is missing" {
  write_models_fixture

  run env -u OPENAI_API_KEY WW_BASE="${TEST_WW_BASE}" bash "${MODELS_SCRIPT}" check
  assert_failure
  assert_output --partial "openai (OPENAI_API_KEY not set)"
}

@test "model check succeeds when required env var is present" {
  write_models_fixture

  run env OPENAI_API_KEY="test-key" WW_BASE="${TEST_WW_BASE}" bash "${MODELS_SCRIPT}" check
  assert_success
  assert_output --partial "openai (OPENAI_API_KEY set)"
}

@test "remove-model rejects removing the default model" {
  write_models_fixture

  run env WW_BASE="${TEST_WW_BASE}" bash "${MODELS_SCRIPT}" remove-model gpt-4o-mini
  assert_failure
  assert_output --partial "Cannot remove default model: gpt-4o-mini"
}

@test "singular create form adds provider" {
  write_models_fixture

  run env WW_BASE="${TEST_WW_BASE}" bash "${MODELS_SCRIPT}" remote openai https://example.test/v1 REMOTE_KEY
  assert_success
  assert_output --partial "Added provider: remote"

  run env WW_BASE="${TEST_WW_BASE}" bash "${MODELS_SCRIPT}" providers
  assert_success
  assert_output --partial "  • remote"
}

@test "remove-provider rejects providers still referenced by models" {
  write_models_fixture

  run env WW_BASE="${TEST_WW_BASE}" bash "${MODELS_SCRIPT}" remove-provider openai
  assert_failure
  assert_output --partial "Cannot remove provider 'openai'"
}
