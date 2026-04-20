# services/custom/configure-issues.sh

**Type:** Executed service script
**Invoked by:** `ww issues custom`, `ww custom issues`, `i custom`
**Subservient to:** Custom service (`services/custom/`)

---

## Role

Interactive wizard for configuring the issues service (bugwarrior + ww github-sync) for the active profile. Writes `bugwarriorrc` to `$WORKWARRIOR_BASE/.config/bugwarrior/`. Supports GitHub, GitLab, Jira, Trello, and generic services.

---

## Main Menu

```
1. Add/configure a service
2. List configured services
3. Remove a service
4. Generate UDAs for configured services
5. Test configuration
6. View current configuration
```

---

## GitHub Configuration (`configure_github()`)

The most complex wizard. Steps:
1. Detect `gh` CLI auth status
2. If authed: offer `@oracle:eval:gh auth token` (preferred) or manual PAT
3. Prompt for `github.login` (authenticated user — pre-filled from `gh api user`)
4. Prompt for `github.username` (namespace/org to pull from — defaults to login)
5. Prompt for repos to include/exclude
6. Set `github.project_template = {{label}}` for repo-based project labelling
7. Call `generate_udas()` to append bugwarrior UDA definitions to `.taskrc`

**login vs username distinction:** `github.login` = your personal account. `github.username` = the org/namespace to pull issues from. These are separate fields — setting both to the same value is correct for personal accounts but wrong for org-based workflows (e.g. `login=peers8862`, `username=babbworks`).

---

## UDA Generation (`generate_udas()`)

Runs `bugwarrior uda` and appends the output to the active profile's `.taskrc`. Idempotent — checks for existing UDA definitions before appending. This is the same operation as `ww issues uda install`.

---

## Token Security

The wizard never writes a plain-text token to the config file if `gh` CLI is available and authenticated. The oracle directive `@oracle:eval:gh auth token` is written instead — the token is evaluated at pull time from the OS keychain. Manual PAT entry is available as a fallback.

---

## Config File Location

```
$WORKWARRIOR_BASE/.config/bugwarrior/bugwarriorrc
```
or (newer bugwarrior):
```
$WORKWARRIOR_BASE/.config/bugwarrior/bugwarrior.toml
```

The `BUGWARRIORRC` env var is exported on profile activation to point bugwarrior to this profile-specific config.

## Changelog

- 2026-04-10 — Initial version
