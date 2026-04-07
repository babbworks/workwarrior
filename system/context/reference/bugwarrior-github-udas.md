# Reference: Bugwarrior GitHub UDAs

Bugwarrior GitHub UDA schema as of bugwarrior 2.1.0.
Generated via `bugwarrior uda` with the babb profile config. Written to `profiles/babb/.taskrc`.

## UDA Schema

| UDA name | Type | Label | Notes |
|---|---|---|---|
| `githubtitle` | string | Github Title | Issue/PR title — mirrors `description` but preserved separately |
| `githubbody` | string | Github Body | Full issue body text — can be long/multiline |
| `githubcreatedon` | date | Github Created | ISO date of issue creation on GitHub |
| `githubupdatedat` | date | Github Updated | ISO date of last update on GitHub |
| `githubclosedon` | date | GitHub Closed | ISO date issue was closed (blank if open) |
| `githubmilestone` | string | Github Milestone | Milestone name, if set |
| `githubrepo` | string | Github Repo Slug | e.g. `babbworks/Team` — org/repo format |
| `githuburl` | string | Github URL | Full https URL to the issue/PR |
| `githubtype` | string | Github Type | `issue` or `pullrequest` |
| `githubnumber` | numeric | Github Issue/PR # | Number within the repo |
| `githubuser` | string | Github User | Username of issue author |
| `githubnamespace` | string | Github Namespace | The org or user owning the repo (e.g. `babbworks`) |
| `githubstate` | string | GitHub State | `open` or `closed` |
| `githubdraft` | numeric | GitHub Draft | 1 = draft PR, 0 = not draft |
| `githubproject` | string | GitHub-Project | Set by `github.project_template` in bugwarriorrc (e.g. repo label) |

---

## Design Notes for ww UDA Service

### Gaps exposed by bugwarrior integration

1. **Service-source awareness** — UDAs fall into user-defined and service-injected categories. `classify_uda()` in `uda-manager.sh` classifies by prefix (`github*`, `gitlab*`, `jira*`, `trello*`, `bw*` = service-managed). Future integrations must follow this prefix convention.

2. **Bulk install** — `bugwarrior uda` outputs a ready-to-paste block. A `ww issues uda --install` command running `bugwarrior uda >> .taskrc` idempotently would close this gap. Tracked in TASK-ISSUES-001.

3. **`githubbody` is long text** — string type, no length constraint. UDA manager 3-column display will wrap badly. Worth noting for display/report filtering.

4. **`githubtype` as enum discriminator** — `issue` vs `pullrequest`. Could drive `ww issues list --prs` vs `--issues` filtering. Would live in `field-mapper.sh` or `sync-pull.sh`.

5. **`githubrepo` + `githubnamespace` redundancy** — `githubrepo` is `org/repo`; `githubnamespace` is just `org`. For multi-org setups (babb: babbworks/Team, babbworks/Workpads, peers8862/linuxweb), `githubrepo` is the useful grouping key.

6. **`githubdraft` is numeric not boolean** — TaskWarrior has no native boolean UDA type. Any display or filter logic must treat `1` as true, not `"true"`.

7. **`githubupdatedat` drives sync freshness** — right key for "has this issue changed on GitHub since last pull?" The sync engine uses `save_sync_state`/`get_sync_state`; `githubupdatedat` is a lighter-weight alternative for pull-only freshness checks.

8. **UDA groups** — a pre-defined group `github` covering all 15 UDAs would let users add `+github` to taskrc reports with one command.

### field-mapper.sh relationship

`lib/field-mapper.sh` handles status↔state mapping, priority labels, and annotation formatting. It does NOT reference `github*` UDA names — those are bugwarrior's domain. If ww ever grows direct issue-writing bypassing bugwarrior, field-mapper would need these field names.
