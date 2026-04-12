# Workwarrior Documentation

Workwarrior is a profile-based productivity system that unifies TaskWarrior, TimeWarrior, JRNL, and Hledger under a single CLI and browser UI.

---

## Core

1. [Why Workwarrior](whyworkwarrior.md) — the problem, the approach, who it's for
2. [Getting Started](getting-started.md) — install, first profile, basic usage
3. [Installation](install.md) — detailed install policy, platform notes, dependency management
4. [Profiles](profiles.md) — isolation, multiple resources, UDAs, backup/restore, removal
5. [Commands](commands.md) — the full command surface, shell functions, scope flags
6. [Usage Examples](usage-examples.md) — practical workflows and CLI patterns

## Features

7. [Browser UI](browser.md) — the web interface, CMD input, panels, API endpoints
8. [Heuristic Engine](heuristics.md) — natural language translation, 627 rules, self-improvement
9. [Weapons](weapons.md) — gun, sword, next, schedule
10. [Services](services.md) — all 20+ service domains, issue sync, building new services

## GitHub Sync

11. [GitHub Sync Guide](github-sync-guide.md) — user guide for two-way sync
12. [GitHub Sync Configuration](github-sync-configuration.md) — setup and config reference
13. [GitHub Sync Troubleshooting](github-sync-troubleshooting.md) — common issues and fixes
14. [Issues Troubleshooting](issues-troubleshooting.md) — bugwarrior and issue service debugging

## Search Guides

15. [Task Search](search-guides/task.md)
16. [Time Search](search-guides/time.md)
17. [Journal Search](search-guides/journal.md)
18. [Ledger Search](search-guides/ledger.md)
19. [List Search](search-guides/list.md)

## Architecture

20. [Architecture Overview](architecture.md) — directory structure, env vars, how it all connects
21. [Service Development](service-development.md) — how to build and register new services
22. [Testing Guide](testing-guide.md) — manual testing procedures
23. [Release Checklist](release-checklist.md) — production readiness gates

## Technical Reference — bin/

24. [bin/ww](bin/ww.md) — main CLI dispatcher
25. [bin/ww-init.sh](bin/ww-init.md) — shell bootstrap

## Technical Reference — lib/

26. [core-utils.sh](lib/core-utils.md) — profile validation, path resolution
27. [profile-manager.sh](lib/profile-manager.md) — profile lifecycle
28. [shell-integration.sh](lib/shell-integration.md) — shell function injection, aliases
29. [logging.sh](lib/logging.md) — log functions
30. [github-api.sh](lib/github-api.md) — GitHub REST API wrapper
31. [sync-pull.sh + sync-push.sh](lib/sync-pull-push.md) — sync directions
32. [field-mapper.sh](lib/field-mapper.md) — TW ↔ GitHub field mapping
33. [sync-detector.sh + github-sync-state.sh](lib/sync-detector-state.md) — change detection and state
34. [sync-permissions.sh](lib/sync-permissions.md) — per-UDA sync permissions
35. [taskwarrior-api.sh](lib/taskwarrior-api.md) — TaskWarrior CLI wrappers
36. [config-utils.sh](lib/config-utils.md) — YAML parsing utilities
37. [bugwarrior-integration.sh](lib/bugwarrior-integration.md) — bugwarrior helpers
38. [export-utils.sh](lib/export-utils.md) — data export
39. [delete-utils.sh](lib/delete-utils.md) — profile deletion
40. [profile-stats.sh](lib/profile-stats.md) — profile statistics
41. [shortcode-registry.sh](lib/shortcode-registry.md) — shortcut registry
42. [dependency-installer.sh](lib/dependency-installer.md) — platform-aware installer

## Technical Reference — services/

43. [github-sync.sh](services/github-sync.md) — sync CLI
44. [profile-uda.sh](services/profile-uda.md) — UDA management
45. [profile-urgency.sh](services/profile-urgency.md) — urgency tuning
46. [questions/q.sh](services/questions.md) — questions service
47. [create-ww-profile.sh](services/profile/create-ww-profile.md) — profile creation
48. [manage-profiles.sh](services/profile/manage-profiles.md) — profile management
49. [configure-issues.sh](services/custom/configure-issues.md) — issue config wizard
50. [extensions.sh](services/extensions/extensions.md) — extension registry
51. [find.sh + find.py](services/find/find.md) — cross-profile search
52. [groups.sh](services/groups/groups.md) — profile groups
53. [models.sh](services/models/models.md) — LLM model registry
54. [export.sh](services/export/export.md) — data export service

## Technical Reference — cross-cutting

55. [installer-utils.sh](cross-cutting/installer-utils.md) — install infrastructure
56. [config-loader.sh](cross-cutting/config-loader.md) — config loading
57. [error-handler.sh](cross-cutting/error-handler.md) — error classification
58. [Sync Engine Overview](cross-cutting/sync-engine/overview.md) — full sync cycle
59. [conflict-resolver.sh](cross-cutting/sync-engine/conflict-resolver.md) — conflict resolution
60. [annotation-sync.sh](cross-cutting/sync-engine/annotation-sync.md) — annotation ↔ comment sync
61. [sync-bidirectional.sh](cross-cutting/sync-engine/sync-bidirectional.md) — bidirectional orchestration

## Extension Registry

62. [TaskWarrior Extensions Index](taskwarrior-extensions/index.md) — rated registry of 150+ extensions
63. [TimeWarrior Extensions](taskwarrior-extensions/timewarrior-extensions.md) — timew extension registry
64. [MCP Integration](taskwarrior-extensions/mcp-integration.md)
65. [TUI Integration](taskwarrior-extensions/tui-integration.md)
66. [Scheduler Integration](taskwarrior-extensions/scheduler-integration.md)
67. [TaskGun Integration](taskwarrior-extensions/taskgun-integration.md)
68. [TaskCheck Integration](taskwarrior-extensions/taskcheck-integration.md)
69. [TWDensity Integration](taskwarrior-extensions/twdensity-integration.md)

## Metadata

70. [Source Map](source-map.yaml) — maps each doc to its source files (for staleness detection)
