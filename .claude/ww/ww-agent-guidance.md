# Workwarrior Agent Guidance

> **Canonical source:** `$WW_BASE/resources/agent-templates/ww-agent-guidance.md`
> This file is a local pointer. The canonical template ships with the product.

See `resources/agent-templates/ww-agent-guidance.md` for the full reference.

---

## Local Overrides (this project)

Profile config: `.claude/ww/config`

```
WW_PROFILE=ww-development
WW_BASE=~/ww
```

Session init:
```bash
eval "$(ww agent init --instance ~/ww --profile ww-development)"
```

---

## Quick Reference

- Roles: `resources/agent-templates/roles/` (Orchestrator, Builder, Verifier, Docs)
- Task lifecycle: resolve UUID first, then start→annotate→modify→journal→stop→done
- Parallel tracking: resolve all UUIDs before spawning, tag `+parallel`
- UDA check: `$WW_BASE/resources/udas/uda-inventory.md` before creating new
- Ledger check: `$WW_BASE/resources/ledgers/ledger-inventory.md` before defining new
- Handoff: Orchestrator → Builder → Verifier → Docs (non-negotiable)
