# UDA Registry — v2-newent project additions

> Tracks UDAs appended to the wwdev `.taskrc` under the
> `=== PROJECT UDAs: v2-newent ===` section.
> Every new UDA gets a row here the same session it is added to `.taskrc`.

| UDA | Type | Label | Purpose |
|---|---|---|---|
| `schemachange` | string | Schema-Change | DDL impact: none \| new-table \| alter \| index |
| `storeops` | string | Store-Ops | Store method names involved in this task |
| `clicommand` | string | CLI-Command | CLI surface affected e.g. "plan-new / plan new" |
| `testcoverage` | string | Test-Coverage | missing \| partial \| full \| skip |
| `breakingchange` | string | Breaking-Change | none \| minor \| major |
| `docimpact` | string | Doc-Impact | Canonical docs to update: ARCHITECTURE \| CLI \| DATA \| SERVICES \| ALL |
| `changelognote` | string | Changelog-Note | Ready-to-paste CHANGELOG.md line |
| `agentid` | string | Agent-ID | Sub-agent task ID or name |
| `agentmodel` | string | Agent-Model | Claude model that performed the work |
| `deviations` | string | Deviations | Spec deviations discovered during implementation |
| `hierarchy` | string | Hierarchy | Entity level: business\|plan\|section\|doc\|heading\|content\|context |
| `parallelwith` | string | Parallel-With | Concurrent task UUIDs (comma-sep); tag tasks +parallel to exclude from totals |

## Expansion Protocol

1. Identify need mid-session
2. Add UDA block to `.taskrc` inside the `=== PROJECT UDAs: v2-newent ===` section
3. Add row to this table immediately — never one without the other
4. If UDA enables a new ledger account, update `ledger-accounts.md` in same pass
