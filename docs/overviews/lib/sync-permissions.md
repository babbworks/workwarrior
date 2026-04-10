# lib/sync-permissions.sh

**Type:** Sourced bash library  
**Invoked by:** `services/profile/subservices/profile-uda.sh`, sync engine

---

## Role

Per-UDA sync permission storage. Allows users to mark individual UDAs with tokens that control how they participate in sync, export, reporting, and AI context. Permissions are stored in a sidecar file, not in `.taskrc`.

---

## Storage

Permissions live at `profiles/<name>/.config/sync-permissions` — one line per UDA:
```
goals=nosync,noai
phase=readonly
githubbody=noreport
```

This file is gitignored (profile config, not code).

---

## Permission Tokens

| Token | Meaning |
|---|---|
| `nosync` | Never sync this UDA (any service, any direction) |
| `deny:<svc>` | Block all sync for a specific service (e.g. `deny:bugwarrior`) |
| `deny:<svc>:<channel>` | Block a specific sync channel |
| `readonly` | External services can read but not write |
| `writeonly` | External services can write but not read |
| `private` | Exclude from any export visible to other users |
| `noreport` | Hide from report output |
| `noexport` | Exclude from data exports |
| `noai` | Exclude from AI context (MCP server, ww mcp) |
| `managed` | Externally managed — warn before manual edit |
| `locked` | Prevent any modification via ww surfaces |

Multiple tokens are comma-separated: `nosync,noai`.

---

## Public Functions

**`sp_get_permissions(profile_base, uda_name)`**  
Returns newline-separated list of permission tokens for a UDA.

**`sp_set_permissions(profile_base, uda_name, tokens)`**  
Writes/replaces permission tokens for a UDA. Empty string clears all permissions.

**`sp_has_permission(profile_base, uda_name, token)`**  
Returns 0 if the UDA has the specified token.

---

## Integration with MCP Server

When `ww mcp` is active, the MCP server should respect `noai` permissions — UDAs marked `noai` should not be included in task data returned to AI agents. This integration is planned but not yet implemented in the MCP server wrapper.

## Changelog

- 2026-04-10 — Initial version
