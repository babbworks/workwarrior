# Issues Service Troubleshooting Guide

This guide covers common issues and solutions for the Workwarrior Issues service (Bugwarrior integration).

## Table of Contents

- [Installation Issues](#installation-issues)
- [Configuration Issues](#configuration-issues)
- [Authentication Issues](#authentication-issues)
- [Network Issues](#network-issues)
- [Sync Issues](#sync-issues)
- [UDA Issues](#uda-issues)
- [Profile Issues](#profile-issues)

---

## Installation Issues

### Bugwarrior Not Found

**Symptom:**
```
Error: bugwarrior is not installed
```

**Solution:**
Install bugwarrior using pip or pipx:

```bash
# Using pipx (recommended)
pipx install bugwarrior

# Using pip
pip install bugwarrior

# With service-specific extras
pip install 'bugwarrior[jira]'
pip install 'bugwarrior[gmail]'
```

**Verify installation:**
```bash
which bugwarrior
bugwarrior --version
```

### Python/Pip Not Found

**Symptom:**
```
command not found: pip
```

**Solution:**
Install Python and pip:

```bash
# macOS
brew install python3

# Ubuntu/Debian
sudo apt install python3 python3-pip

# Fedora
sudo dnf install python3 python3-pip
```

### Pipx Not Found

**Symptom:**
```
command not found: pipx
```

**Solution:**
Install pipx:

```bash
# macOS
brew install pipx
pipx ensurepath

# Ubuntu/Debian
sudo apt install pipx
pipx ensurepath

# Using pip
pip install --user pipx
pipx ensurepath
```

---

## Configuration Issues

### Configuration File Not Found

**Symptom:**
```
Error: Bugwarrior configuration not found
Run 'i custom' to configure the issues service
```

**Solution:**
1. Ensure a profile is active:
   ```bash
   p-work  # or your profile name
   ```

2. Create configuration:
   ```bash
   i custom
   ```

3. Add at least one service (GitHub, Jira, etc.)

### Invalid Configuration Format

**Symptom:**
```
Error parsing configuration file
```

**Solution:**
1. Check configuration syntax:
   ```bash
   i custom
   # Select: View current configuration
   ```

2. Validate INI format:
   - Sections must be in brackets: `[section_name]`
   - Key-value pairs: `key = value`
   - No duplicate sections

3. For TOML format, validate with:
   ```bash
   python3 -c "import tomli; tomli.load(open('bugwarrior.toml', 'rb'))"
   ```

### Missing [general] Section

**Symptom:**
```
Error: No targets defined
```

**Solution:**
Add `[general]` section with targets:

```ini
[general]
targets = my_github, my_jira

[my_github]
service = github
...
```

### Service Not in Targets

**Symptom:**
Service configured but not syncing.

**Solution:**
Add service name to targets in `[general]` section:

```ini
[general]
targets = my_github, my_jira, my_new_service
```

---

## Authentication Issues

### GitHub Authentication Failed

**Symptom:**
```
401 Unauthorized
Bad credentials
```

**Solution:**
1. Verify token is valid:
   - Go to https://github.com/settings/tokens
   - Check token hasn't expired
   - Verify token has `repo` scope

2. Test token manually:
   ```bash
   curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user
   ```

3. Update token in configuration:
   ```bash
   i custom
   # Select: Add/configure external service → GitHub
   ```

### GitLab Authentication Failed

**Symptom:**
```
401 Unauthorized
```

**Solution:**
1. Verify token:
   - Go to https://gitlab.com/-/profile/personal_access_tokens
   - Check token has `read_api` scope
   - Verify token hasn't expired

2. Test token:
   ```bash
   curl --header "PRIVATE-TOKEN: YOUR_TOKEN" https://gitlab.com/api/v4/user
   ```

### Jira Authentication Failed

**Symptom:**
```
401 Unauthorized
CAPTCHA_CHALLENGE
```

**Solution:**
1. For Jira Cloud, use API token (not password):
   - Create at: https://id.atlassian.com/manage-profile/security/api-tokens
   - Use email as username
   - Use API token as password

2. For Jira Server, verify credentials:
   ```bash
   curl -u username:password https://jira.company.com/rest/api/2/myself
   ```

3. If CAPTCHA appears, log in via browser first

### Keyring Issues

**Symptom:**
```
Error: Failed to get password from keyring
```

**Solution:**
1. Install keyring backend:
   ```bash
   # macOS (uses Keychain)
   pip install keyring

   # Linux
   pip install keyring secretstorage
   ```

2. Store password in keyring:
   ```bash
   python3 -c "import keyring; keyring.set_password('bugwarrior', 'github.token', 'YOUR_TOKEN')"
   ```

3. Test keyring:
   ```bash
   python3 -c "import keyring; print(keyring.get_password('bugwarrior', 'github.token'))"
   ```

---

## Network Issues

### Connection Timeout

**Symptom:**
```
Connection timed out
Failed to connect to api.github.com
```

**Solution:**
1. Check internet connectivity:
   ```bash
   ping api.github.com
   ```

2. Check firewall/proxy settings

3. Test with dry-run:
   ```bash
   i pull --dry-run
   ```

4. Increase timeout in bugwarriorrc:
   ```ini
   [general]
   targets = my_github
   timeout = 60
   ```

### SSL Certificate Errors

**Symptom:**
```
SSL: CERTIFICATE_VERIFY_FAILED
```

**Solution:**
1. Update CA certificates:
   ```bash
   # macOS
   brew install ca-certificates

   # Ubuntu/Debian
   sudo apt update && sudo apt install ca-certificates
   ```

2. For self-signed certificates (not recommended):
   ```ini
   [my_service]
   verify_ssl = False
   ```

### Proxy Issues

**Symptom:**
```
ProxyError
```

**Solution:**
Set proxy environment variables:

```bash
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
i pull
```

Or in bugwarriorrc:
```ini
[general]
proxy = http://proxy.company.com:8080
```

---

## Sync Issues

### No Issues Synced

**Symptom:**
`i pull` completes but no tasks appear.

**Solution:**
1. Check filters:
   ```ini
   # GitHub - remove restrictive filters
   github.only_if_assigned = username  # Remove if too restrictive
   github.include_repos = owner/repo   # Verify repo names
   ```

2. Test with dry-run:
   ```bash
   i pull --dry-run
   ```

3. Check service has issues:
   - Verify issues exist in external service
   - Check issue state (open vs closed)

4. Verify targets:
   ```ini
   [general]
   targets = my_github  # Must match service section name
   ```

### Duplicate Tasks

**Symptom:**
Same issue appears multiple times in TaskWarrior.

**Solution:**
1. Bugwarrior uses UUIDs to prevent duplicates
2. Check for multiple service configurations pointing to same source
3. Remove duplicates manually:
   ```bash
   task <id> delete
   ```

4. Re-sync:
   ```bash
   i pull
   ```

### Tasks Not Updating

**Symptom:**
Changes in external service don't reflect in TaskWarrior.

**Solution:**
1. Run sync again:
   ```bash
   i pull
   ```

2. Check sync frequency - bugwarrior doesn't auto-sync
3. Set up cron job for automatic syncing:
   ```bash
   # Add to crontab
   */15 * * * * source ~/.bashrc && p-work && i pull
   ```

### Sync Direction Confusion

**Symptom:**
Changes in TaskWarrior don't appear in external service.

**Solution:**
This is expected behavior. Bugwarrior is ONE-WAY SYNC ONLY:
- External services → TaskWarrior ✓
- TaskWarrior → External services ✗

To update external issues, use the service's web interface or API directly.

---

## UDA Issues

### UDA Not Found

**Symptom:**
```
Unrecognized attribute 'githuburl'
```

**Solution:**
Generate UDAs:

```bash
i custom
# Select: Generate/update UDAs
```

Or manually:
```bash
bugwarrior uda >> ~/.taskrc
```

### Duplicate UDA Definitions

**Symptom:**
```
Warning: Duplicate UDA definition
```

**Solution:**
1. Backup .taskrc:
   ```bash
   cp ~/.taskrc ~/.taskrc.bak
   ```

2. Remove old bugwarrior UDAs:
   ```bash
   sed -i '/# Bugwarrior UDAs/,/^$/d' ~/.taskrc
   ```

3. Regenerate:
   ```bash
   i custom
   # Select: Generate/update UDAs
   ```

### UDA Type Mismatch

**Symptom:**
```
Error: UDA type mismatch
```

**Solution:**
1. Remove conflicting UDA from .taskrc
2. Regenerate UDAs
3. Clear TaskWarrior cache:
   ```bash
   rm -rf ~/.task/*.data
   task list  # Rebuilds cache
   ```

---

## Profile Issues

### No Active Profile

**Symptom:**
```
Error: No active profile. Activate a profile first with: p-<profile-name>
```

**Solution:**
Activate a profile:

```bash
p-work  # or your profile name
```

Verify:
```bash
echo $WORKWARRIOR_BASE
echo $WARRIOR_PROFILE
```

### Wrong Profile Active

**Symptom:**
Syncing to wrong profile's TaskWarrior.

**Solution:**
1. Check active profile:
   ```bash
   echo $WARRIOR_PROFILE
   ```

2. Switch profiles:
   ```bash
   p-correct-profile
   ```

3. Verify configuration:
   ```bash
   i custom
   # Select: View current configuration
   ```

### Profile Configuration Missing

**Symptom:**
```
Error: Profile 'work' does not exist
```

**Solution:**
1. List profiles:
   ```bash
   ww profile list
   ```

2. Create profile if missing:
   ```bash
   ww profile create work
   ```

3. Configure issues service:
   ```bash
   p-work
   i custom
   ```

---

## Advanced Troubleshooting

### Enable Debug Logging

Add to bugwarriorrc:

```ini
[general]
log.level = DEBUG
log.file = /tmp/bugwarrior.log
```

Then check logs:
```bash
tail -f /tmp/bugwarrior.log
```

### Test Configuration

```bash
# Dry run (no changes)
i pull --dry-run

# Verbose output
BUGWARRIOR_DEBUG=1 i pull --dry-run
```

### Inspect Environment

```bash
# Check environment variables
env | grep -E 'BUGWARRIOR|WARRIOR|TASK'

# Check configuration path
echo $BUGWARRIORRC

# Verify files exist
ls -la $WORKWARRIOR_BASE/.config/bugwarrior/
```

### Reset Configuration

```bash
# Backup current config
cp $WORKWARRIOR_BASE/.config/bugwarrior/bugwarriorrc ~/bugwarriorrc.bak

# Remove configuration
rm $WORKWARRIOR_BASE/.config/bugwarrior/bugwarriorrc

# Reconfigure
i custom
```

---

## Getting Help

### Check Bugwarrior Documentation

- [Bugwarrior Docs](https://bugwarrior.readthedocs.io/)
- [Service Configuration](https://bugwarrior.readthedocs.io/en/latest/services/)
- [Common Configuration](https://bugwarrior.readthedocs.io/en/latest/common_configuration.html)

### Check Workwarrior Documentation

- Main README: `~/ww/readme.md`
- Issues service: `~/ww/services/custom/README-issues.md`
- Service development: `~/ww/docs/service-development.md`

### Report Issues

For Bugwarrior issues:
- [Bugwarrior GitHub Issues](https://github.com/ralphbean/bugwarrior/issues)

For Workwarrior integration issues:
- Check Workwarrior documentation
- Review configuration with `i custom`

---

## Quick Reference

### Common Commands

```bash
# Configuration
i custom                    # Open configuration tool
i pull --dry-run            # Test without syncing

# Sync
i pull                      # Sync all services
i pull --service github     # Sync specific service

# UDAs
i uda                       # List UDAs
bugwarrior uda >> ~/.taskrc # Add UDAs manually

# Debugging
BUGWARRIOR_DEBUG=1 i pull   # Verbose output
i custom                    # View configuration
```

### Configuration Files

```
Profile configuration:
  $WORKWARRIOR_BASE/.config/bugwarrior/bugwarriorrc

TaskWarrior config:
  $WORKWARRIOR_BASE/.taskrc

TaskWarrior data:
  $WORKWARRIOR_BASE/.task/
```

### Environment Variables

```bash
WORKWARRIOR_BASE           # Profile base directory
WARRIOR_PROFILE            # Active profile name
BUGWARRIORRC               # Config file path (auto-set)
BUGWARRIOR_TASKRC          # TaskWarrior config (auto-set)
BUGWARRIOR_TASKDATA        # TaskWarrior data (auto-set)
```
