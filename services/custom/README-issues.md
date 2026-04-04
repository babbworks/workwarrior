# Issues Service

The `i` command (and its alias `ww issues`) routes issue and sync operations across two engines:

- **github-sync** — bidirectional two-way sync with GitHub Issues
- **bugwarrior** — one-way pull from GitHub, GitLab, Jira, Trello, and 20+ other services

---

## Command Routing Matrix

| Command | Engine | Direction | Notes |
|---|---|---|---|
| `i pull [--dry-run] [--json]` | bugwarrior | External → TaskWarrior | One-way only |
| `i uda` | bugwarrior | local | List TaskWarrior UDAs |
| `i push [task-id]` | github-sync | TaskWarrior → GitHub | Two-way |
| `i sync [task-id]` | github-sync | Bidirectional | Two-way |
| `i enable-sync <task> <issue> <repo>` | github-sync | — | Link task to GitHub issue |
| `i disable-sync <task>` | github-sync | — | Unlink task |
| `i status [--json]` | github-sync | — | Show sync state |
| `i custom` | configure-issues.sh | — | Interactive config |
| `i help` | — | — | Show this routing matrix |

`i` and `ww issues` are synonymous. Both require an active profile.

---

## GitHub Quick Start

GitHub is the recommended starting point. It supports both sync engines.

### 1. Activate a profile

```bash
p-work
```

### 2. Configure GitHub (interactive)

```bash
i custom
# Select: Add/configure external service → GitHub
# Enter: personal access token, repos to watch, filters
# Then: Generate/update UDAs
```

### 3. Pull GitHub issues into TaskWarrior

```bash
i pull             # one-way: GitHub Issues → TaskWarrior
i pull --dry-run   # test without writing
```

### 4. Two-way sync a task back to GitHub

```bash
i enable-sync <task-id> <issue-number> <owner/repo>
i push             # push local changes to GitHub
i status           # check sync state
```

---

## Other Services (bugwarrior pull only)

GitLab, Jira, Trello, and 20+ other services are supported via bugwarrior (one-way pull only — no write-back).

```bash
i custom
# Select: Add/configure external service → GitLab / Jira / Trello / etc.
i pull
```

**⚠️ Bugwarrior is one-way.** Changes made in TaskWarrior are not pushed back to external issue trackers. External services are the source of truth for bugwarrior-synced tasks.

Supported services: GitHub, GitLab, Jira, Trello, Bitbucket, Pagure, Gerrit, Bugzilla, Redmine, YouTrack, Phabricator, Trac, Taiga, Pivotal Tracker, Teamwork, ClickUp, Linear, Todoist, Logseq, Nextcloud Deck, Kanboard, Gmail, Azure DevOps, Debian BTS.

See [Bugwarrior documentation](https://bugwarrior.readthedocs.io/en/latest/services/) for the full list.

---

## Installation

```bash
pipx install bugwarrior          # recommended
pip install bugwarrior           # alternative
pip install 'bugwarrior[jira]'   # with Jira extras
```

---

## Configuration Files

Each profile has its own bugwarrior configuration:

```
profiles/<name>/.config/bugwarrior/
├── bugwarriorrc        # INI format (default)
└── bugwarrior.toml     # TOML format (alternative)
```

### Example (INI)

```ini
[general]
targets = my_github, my_jira

[my_github]
service = github
github.login = username
github.token = @oracle:use_keyring
github.username = username
github.include_repos = owner/repo1, owner/repo2
github.only_if_assigned = username
github.import_labels_as_tags = True

[my_jira]
service = jira
jira.base_uri = https://company.atlassian.net
jira.username = user@company.com
jira.password = @oracle:use_keyring
jira.query = assignee=currentUser() AND status!=Done
```

---

## Credential Security

**⚠️ Warning**: Credentials stored in plain text in `bugwarriorrc` without `@oracle` directives.

```ini
# System keyring (recommended)
github.token = @oracle:use_keyring

# Password prompt
github.token = @oracle:ask_password

# External password manager
github.token = @oracle:eval:pass github/token

# Environment variable
github.token = @oracle:eval:echo $GITHUB_TOKEN
```

Configuration files are created with restrictive permissions (600).

---

## User Defined Attributes (UDAs)

Bugwarrior creates TaskWarrior UDAs for each service (issue URLs, IDs, types, etc.).

```bash
i custom              # Select: Generate/update UDAs
# or manually:
bugwarrior uda >> ~/.taskrc
```

After syncing GitHub, tasks will have: `githuburl`, `githubtitle`, `githubtype`, `githubstate`, and more.

---

## Profile Isolation

Each profile has independent bugwarrior config. Switch profiles to switch contexts:

```bash
p-work     && i pull   # work Jira + GitHub
p-personal && i pull   # personal GitHub only
```

---

## AI Agent Usage

Workwarrior profiles are designed for AI agent use. An agent managing its own profile can use the issues service to:

```bash
# Pull assigned issues from GitHub into TaskWarrior
i pull

# Link a TaskWarrior task to a GitHub issue for two-way tracking
i enable-sync <task-id> <issue-number> owner/repo

# Push task status updates back to GitHub
i push

# Check sync state in machine-readable format
i status --json

# Pull and emit result as JSON (useful in scripts/pipelines)
i pull --json
```

The `--json` flag on `i pull` and `i status` suppresses human-readable output and emits a structured result:

```json
{"command": "pull", "status": "success"}
{"command": "status", "status": "success", "output": "..."}
```

---

## Troubleshooting

**bugwarrior not found:**
```bash
pipx install bugwarrior
```

**No configuration found:**
```bash
echo $WORKWARRIOR_BASE   # must be non-empty (profile active)
i custom                 # create configuration
```

**Authentication errors:**
- Verify credentials in `bugwarriorrc`
- Check token permissions/scopes
- Test: `i pull --dry-run`

**UDA errors:**
```bash
i custom   # Select: Generate/update UDAs
```

**Filtering (advanced):**
```ini
github.only_if_assigned = username
jira.query = project=PROJ AND assignee=currentUser()
```
