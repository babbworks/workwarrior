# GitHub Two-Way Sync - Release Checklist

## Pre-Release Testing

### Automated Tests
- [ ] Run integration test suite: `./tests/run-integration-tests.sh`
- [ ] All tests pass
- [ ] No errors in test output

### Manual Testing
- [ ] Test with real GitHub repository
- [ ] Test with multiple profiles
- [ ] Test conflict resolution with real timing
- [ ] Test error correction flow interactively
- [ ] Test batch operations with 10+ tasks
- [ ] Test bugwarrior coexistence (if applicable)
- [ ] Test profile switching
- [ ] Verify all help text displays correctly
- [ ] Verify all error messages are helpful

### Functionality Verification
- [ ] All 5 bidirectional fields sync correctly
- [ ] All 7 pull-only metadata fields populate correctly
- [ ] System tags are excluded from sync
- [ ] Conflict resolution works (last-write-wins)
- [ ] Error handling works (validation, permission, rate limit)
- [ ] Batch operations work correctly
- [ ] Annotation/comment sync is bidirectional and idempotent

### Performance Verification
- [ ] Single task sync completes in <5 seconds
- [ ] Batch sync (10 tasks) completes in <60 seconds
- [ ] No excessive API calls
- [ ] Logs don't grow too large

## Documentation Review

- [ ] User guide is complete and accurate
- [ ] Configuration guide is complete
- [ ] Troubleshooting guide covers common issues
- [ ] Integration testing guide is clear
- [ ] All command examples work
- [ ] All file paths are correct
- [ ] All links work

## Code Quality

- [ ] All functions have comments
- [ ] Complex logic is explained
- [ ] No TODO comments remain
- [ ] No debug code remains
- [ ] Error messages are helpful
- [ ] Code follows shell scripting best practices

## Release Preparation

### Version Information
- [ ] Update version number in relevant files
- [ ] Create CHANGELOG.md with release notes
- [ ] Document breaking changes (if any)
- [ ] Document new features
- [ ] Document bug fixes

### Git Repository
- [ ] All changes committed
- [ ] Commit messages are clear
- [ ] Branch is up to date with main
- [ ] No merge conflicts

### Release Notes Template

```markdown
# GitHub Two-Way Sync v1.0.0

## Overview

First stable release of GitHub Two-Way Sync for Workwarrior. Enables bidirectional synchronization between TaskWarrior tasks and GitHub issues.

## Features

- Bidirectional sync for 5 fields (description, status, priority, tags, annotations)
- Pull-only sync for 7 metadata fields
- Automatic conflict resolution (last-write-wins)
- Interactive error correction
- Batch operations
- Profile isolation
- Bugwarrior coexistence

## Installation

See [Installation Guide](docs/INSTALLATION.md)

## Quick Start

```bash
# Enable sync for a task
i enable-sync 1 42 myorg/myrepo

# Push changes
i push 1

# Pull changes
i pull 1

# Bidirectional sync
i sync 1
```

## Documentation

- [User Guide](docs/github-sync-user-guide.md)
- [Configuration Guide](docs/github-sync-configuration-guide.md)
- [Troubleshooting Guide](docs/github-sync-troubleshooting.md)
- [Integration Testing](tests/integration-test-guide.md)

## Requirements

- bash 4.0+
- jq
- gh CLI (authenticated)
- TaskWarrior 2.6.0+

## Known Issues

- Dry-run mode not fully implemented (shows warning)
- Property-based tests not implemented (optional)

## Future Enhancements

- Full dry-run mode implementation
- Auto-sync on task modification
- Custom conflict resolution strategies
- Property-based testing

## Contributors

[List contributors]

## License

[License information]
```

## Post-Release

- [ ] Tag release in git: `git tag -a v1.0.0 -m "Release v1.0.0"`
- [ ] Push tag: `git push origin v1.0.0`
- [ ] Create GitHub release with release notes
- [ ] Update main documentation to reference new version
- [ ] Announce release (if applicable)

## Rollback Plan

If issues are discovered post-release:

1. Document the issue
2. Assess severity
3. If critical:
   - Revert to previous version
   - Communicate to users
   - Fix issue
   - Re-release as patch version
4. If non-critical:
   - Add to known issues
   - Fix in next release

## Support Plan

- Monitor for user-reported issues
- Respond to questions
- Triage bugs
- Plan future enhancements

## Success Criteria

Release is successful if:
- [ ] All tests pass
- [ ] Documentation is complete
- [ ] No critical bugs in first week
- [ ] Users can successfully sync tasks
- [ ] Performance is acceptable
- [ ] Error messages are helpful

## Sign-Off

- [ ] Lead developer approves
- [ ] Testing complete
- [ ] Documentation reviewed
- [ ] Ready for release

---

**Release Date**: [Date]
**Released By**: [Name]
**Version**: 1.0.0
