# Issues Service (Bugwarrior Integration)

## Overview

The Issues service integrates [Bugwarrior](https://bugwarrior.readthedocs.io/) into Workwarrior, enabling synchronization of issues from 25+ external services (GitHub, GitLab, Jira, Trello, etc.) into TaskWarrior.

**⚠️ IMPORTANT: One-Way Sync Only**

Bugwarrior pulls issues FROM external services TO TaskWarrior. Changes made in TaskWarrior do NOT sync back to the external issue trackers. External services are authoritative.

## Features

- **Multi-Service Support**: GitHub, GitLab, Jira, Trello, Todoist, Bitbucket, and 20+ more
- **Profile Isolation**: Each profile has its own bugwarrior configuration
- **Secure Credentials**: Support for keyring, password prompts, and external password managers
- **UDA Management**: Automatic generation and management of User Defined Attributes
- **Configuration Tool**: Interactive setup for common services
- **Format Support**: Both INI and TOML configuration formats

## Quick Start

### 1. Install Bugwarrior

```bash
# Using pip
pip install bugwarrior

# Using pipx (recommended)
pipx install bugwarrior

# With service-specific extras
pip install 'bugwarrior[jira]'
```

### 2. Activate a Profile

```bash
p-work  # or p-<your-profile-name>
```

### 3. Configure Services

```bash
i custom
```

This launches an interactive configuration tool where you can:
- Add external services (GitHub, GitLab, Jira, etc.)
- Configure credentials
- Generate TaskWarrior UDAs
- Test your configuration

### 4. Sync Issues

```bash
i pull
```

This pulls issues from all configured services into TaskWarrior.

## Usage

### Shell Function: `i`

The `i` function provides access to bugwarrior commands:

```bash
# Pull issues from configured services
i pull

# Test configuration without syncing
i pull --dry-run

# List bugwarrior UDAs
i uda

# Open configuration tool
i custom
```

### Configuration Tool

Launch with `i custom` to access:

1. **Add/configure external service** - Set up GitHub, GitLab, Jira, Trello, or other services
2. **List configured services** - View all configured services
3. **Remove service** - Remove a service configuration
4. **Generate/update UDAs** - Create TaskWarrior User Defined Attributes
5. **Test configuration** - Run a dry-run to validate setup
6. **View current configuration** - Display bugwarriorrc contents
7. **Credential security information** - Learn about secure credential storage

## Supported Services

### Fully Supported (with templates)
- **GitHub** - Issues and pull requests
- **GitLab** - Issues and merge requests
- **Jira** - Issues with JQL queries
- **Trello** - Cards from boards

### Also Supported (manual configuration)
- Bitbucket, Pagure, Gerrit, Git-Bug
- Bugzilla, Redmine, YouTrack, Phabricator, Trac
- Taiga, Pivotal Tracker, Teamwork Projects, ClickUp, Linear
- Todoist, Logseq, Nextcloud Deck, Kanboard
- Gmail, Azure DevOps, Debian BTS

See [Bugwarrior documentation](https://bugwarrior.readthedocs.io/en/latest/services/) for complete list.

## Configuration

### Configuration Files

Each profile has its own bugwarrior configuration:

```
profiles/<profile-name>/.config/bugwarrior/
├── bugwarriorrc        # INI format (default)
└── bugwarrior.toml     # TOML format (alternative)
```

### Example Configuration (INI)

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

## Credential Security

**⚠️ Security Warning**: By default, credentials are stored in plain text in `bugwarriorrc`.

### Secure Storage Options

Bugwarrior supports secure credential storage using `@oracle` directives:

#### 1. System Keyring (Recommended)
```ini
github.token = @oracle:use_keyring
```

#### 2. Password Prompt
```ini
github.token = @oracle:ask_password
```

#### 3. External Password Manager
```ini
github.token = @oracle:eval:pass github/token
```

#### 4. Environment Variable
```ini
github.token = @oracle:eval:echo $GITHUB_TOKEN
```

### File Permissions

Configuration files are automatically created with restrictive permissions (600) to prevent unauthorized access.

## User Defined Attributes (UDAs)

Bugwarrior creates TaskWarrior UDAs for each service to store metadata (issue URLs, IDs, etc.).

### Generate UDAs

```bash
i custom
# Select option 4: Generate/update UDAs
```

Or manually:
```bash
bugwarrior uda >> ~/.taskrc
```

### UDA Examples

After syncing GitHub issues, tasks will have:
- `githuburl` - Issue URL
- `githubtitle` - Issue title
- `githubtype` - Issue or PR
- `githubstate` - Open/closed status
- And more...

## Workflow Examples

### GitHub Issues

```bash
# Configure GitHub
i custom
# Select: Add/configure external service → GitHub
# Enter: token, repos, filters

# Generate UDAs
i custom
# Select: Generate/update UDAs

# Sync issues
i pull

# View synced tasks
task list

# Filter by GitHub issues
task project:github list
```

### Multiple Services

```bash
# Configure multiple services
i custom
# Add GitHub, GitLab, Jira

# Sync all services
i pull

# View tasks from specific service
task +github list
task +jira list
```

### Profile Switching

```bash
# Work profile with Jira
p-work
i pull
task list

# Personal profile with GitHub
p-personal
i pull
task list
```

## Troubleshooting

### Bugwarrior Not Found

```bash
# Check installation
which bugwarrior

# Install if missing
pipx install bugwarrior
```

### Configuration Not Found

```bash
# Ensure profile is active
echo $WORKWARRIOR_BASE

# Create configuration
i custom
```

### Authentication Errors

1. Verify credentials in `bugwarriorrc`
2. Check token permissions/scopes
3. Test with dry-run: `i pull --dry-run`

### UDA Errors

```bash
# Regenerate UDAs
i custom
# Select: Generate/update UDAs

# Or manually
bugwarrior uda >> ~/.taskrc
```

### Network Issues

- Check internet connectivity
- Verify service URLs are accessible
- Check firewall/proxy settings

## Advanced Configuration

### Filtering

```ini
# GitHub: Only assigned issues
github.only_if_assigned = username

# Jira: Custom JQL
jira.query = project=PROJ AND assignee=currentUser()

# GitLab: Specific projects
gitlab.include_repos = 123, 456
```

### Metadata

```ini
# Add tags to synced tasks
github.add_tags = github, external

# Set default project
github.default_priority = M
```

### Templates

```ini
# Custom task description template
github.description_template = {{githubtitle}} - {{githuburl}}
```

See [Bugwarrior documentation](https://bugwarrior.readthedocs.io/) for complete configuration options.

## CLI Integration

### Via `ww` Command

```bash
ww custom issues    # Open configuration tool
ww i pull           # Sync issues
```

### Via `custom` Command

```bash
custom issues       # Open configuration tool
```

## Files and Locations

```
~/ww/
├── services/custom/
│   └── configure-issues.sh          # Configuration tool
├── resources/config-files/
│   └── bugwarriorrc.template        # Template file
└── lib/
    └── shell-integration.sh         # i() function

profiles/<profile-name>/
├── .config/bugwarrior/
│   └── bugwarriorrc                 # Profile configuration
└── .taskrc                          # TaskWarrior config (with UDAs)
```

## Best Practices

1. **Use Secure Credentials**: Replace plain text tokens with `@oracle` directives
2. **Test First**: Use `i pull --dry-run` before syncing
3. **Filter Wisely**: Only sync issues you need to reduce clutter
4. **Regular Syncs**: Run `i pull` regularly to stay updated
5. **Profile Isolation**: Use separate profiles for work/personal projects
6. **Backup Configs**: Keep backups of `bugwarriorrc` and `.taskrc`

## Resources

- [Bugwarrior Documentation](https://bugwarrior.readthedocs.io/)
- [Bugwarrior GitHub](https://github.com/ralphbean/bugwarrior)
- [TaskWarrior UDAs](https://taskwarrior.org/docs/udas.html)
- [Workwarrior Documentation](../../readme.md)

## Support

For issues specific to:
- **Bugwarrior**: See [Bugwarrior issues](https://github.com/ralphbean/bugwarrior/issues)
- **Workwarrior integration**: Check Workwarrior documentation
- **Service-specific**: Consult service API documentation
