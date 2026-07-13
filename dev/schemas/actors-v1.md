# Actor Registry — v1

**Contract for:** `config/actors.yaml` · `profiles/<name>/actors.yaml` ·
`~/.config/ww/registry/actors.yaml`
**Status:** normative, v1.
**Consumed by:** `services/stream/` (actor resolution, the board, reconciliation), and any
service that needs to know who or what is doing the work.
**Related:** [`stream-event-v1.md`](./stream-event-v1.md) §4.

---

## 1. What an actor is

**An actor is anything that can punch in.** A human operator, an AI agent, an autonomous
machine.

> **Actors punch. Objects get punched onto.**

A machine an operator is working is an *object*. A machine running unattended is an
*actor*. The same machine legitimately appears in both roles in different events.

For an adopting organisation, the actor registry **is the operational roster**: the
people, the agents, and the equipment. It is an org chart and an asset register in one
file.

---

## 2. The three tiers — and why the scoping is forced

The stream log lives at `$WW_BASE/stream/stream.log` — **one append-only log per
instance**, shared by every profile in that instance.

That decides the scope. If actor IDs were profile-scoped, the same human would carry
different IDs in different profiles and the shared log would be incoherent — you could
never ask "what did op-03 do today" across contexts. **Actor identity must be at least
instance-scoped, because the log is instance-scoped.**

But *identity* and *participation* are different things:

| Tier | File | Holds | Required |
|---|---|---|---|
| **Registry** | `~/.config/ww/registry/actors.yaml` | The cross-instance roster. Stable IDs across sites. | Optional — multi-instance deployments only |
| **Instance** | `config/actors.yaml` | **Identity.** Who and what exists here. | **Yes** |
| **Profile** | `profiles/<name>/actors.yaml` | **Participation.** Which actors take part here, in what role, with what coefficients. | Optional |

Resolution order is **profile → instance → registry**, first match wins for participation
fields; **identity fields always resolve at the instance tier or above.** A profile may
not invent an actor that the instance does not know.

This mirrors the pattern already used for services: profile-level definitions shadow
global ones.

---

## 3. Instance tier — `config/actors.yaml`

Identity. The roster.

```yaml
schema: v1

actors:
  human:op-03:
    kind: human
    display: "Marta Ruiz"
    status: active
    source: local
    belongs_to: site-a/line-1

  agent:claude-07:
    kind: agent
    display: "Claude — ledger builder"
    status: active
    source: local
    model: claude-opus-4-8

  machine:lathe-01:
    kind: machine
    display: "Haas ST-20"
    status: active
    source: cmms
    belongs_to: site-a/line-1
    installed: 2021-03-14
```

### Fields

| Field | Type | Required | Meaning |
|---|---|---|---|
| *(key)* | actor ID | yes | `<kind>:<local-id>`. Immutable. See §5. |
| `kind` | `human`\|`agent`\|`machine` | yes | Must match the ID prefix. |
| `display` | string | yes | Human-readable name. |
| `status` | `active`\|`inactive` | yes | Inactive actors are retained, never deleted — historical events still reference them. |
| `source` | string | yes | `local`, or the external system of record. See §4. |
| `belongs_to` | path string | no | Org/asset hierarchy, `/`-delimited: `site-a/line-1`. |
| `model` | string | no | Agents: which model. |
| `installed` | date | no | Machines: commissioning date. |

**Actors are never deleted.** A departed employee or a scrapped machine is set
`status: inactive`. The log holds their history forever, and a dangling actor reference
is worse than a stale row.

---

## 4. `source` — import-first, not hand-edit-first

No organisation will hand-maintain this file. The roster already exists — in an HR
system, a CMMS, an asset database. **The registry is designed to be imported and synced,
with hand-editing as the fallback rather than the assumption.**

- `source: local` — authored here. Hand-editing is safe.
- `source: <system>` (e.g. `cmms`, `hris`) — **mirrored from an external system of
  record. MUST NOT be hand-edited locally**; the next sync will silently revert it.

Tooling MUST refuse to write to a non-`local` row unless the write originates from that
row's sync process.

---

## 5. Actor IDs

```
<kind>:<local-id>
```

- `kind` ∈ `human` | `agent` | `machine`, and MUST match the record's `kind`.
- `local-id` — `[a-z0-9][a-z0-9_-]*`. No spaces, no colons.
- **IDs are immutable.** They appear in the append-only stream log; renaming one
  rewrites history by implication. Change `display`, never the ID.
- **Unique per instance.** Uniqueness across instances is guaranteed only when the
  registry tier is in use.

### Forward compatibility with the registry tier

A multi-site deployment qualifies IDs by instance: `<instance>/<kind>:<local-id>`
(e.g. `factory-a/human:op-03`). **v1 IDs are forward-compatible** — an unqualified ID is
read as belonging to the local instance. Adding the registry tier later does not break
any existing ID or any event already written.

---

## 6. Profile tier — `profiles/<name>/actors.yaml`

Participation, not identity. **A profile may not define an actor; it may only qualify
one the instance already knows.**

```yaml
schema: v1

members:
  human:op-03:
    role: operator
    weight: 1.0

  machine:lathe-01:
    role: asset
    weight: 3.0        # criticality — a stale punch here matters 3x

  agent:claude-07:
    role: builder
    weight: 0.5
```

| Field | Type | Meaning |
|---|---|---|
| `role` | string | What this actor does *in this profile*. |
| `weight` | number | **Attention coefficient.** How much this actor's state matters here. |

### `weight` is the ledger's coefficient, in a different hat

This is not a new mechanism. `dev/docs/ledger-systems-accounting.md` §6.5 established —
and verified — that **a mode is a price table**: the same records valued under different
coefficients produce different attention rankings. An actor's `weight` *is* such a
coefficient. The same roster under a safety-mode profile and a throughput-mode profile
yields different priority orders, from one immutable log.

An actor listed in the instance but absent from a profile's `members` does not
participate in that profile and is omitted from its board and its rankings.

---

## 7. Compatibility rules

**Readers:**
- MUST tolerate unknown fields.
- MUST treat an unresolvable actor ID as an **opaque but valid** identity — display it,
  never drop the event. The log is the record of truth; the registry is a lookup table,
  and a missing row is a registry problem, not an event problem.
- MUST apply the v0 fallback for events with no actor
  ([`stream-event-v1.md`](./stream-event-v1.md) §4).

**Writers:**
- MUST NOT change an existing actor ID.
- MUST NOT delete an actor. Set `status: inactive`.
- MUST NOT write to a row whose `source` is not `local`.

---

## 8. Changelog

**v1 — 2026-07-12** — initial contract. Three tiers; `<kind>:<local-id>` IDs;
import-first via `source`; profile-tier `weight` as the attention coefficient.
