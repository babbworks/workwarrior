# dev/schemas — Versioned Contracts

**Normative reference for every file format and wire format workwarrior depends on.**

## What lives here

One file per versioned contract: `<contract>-v<N>.md`. Each is the **authoritative
statement of *what* the format is** — fields, types, reserved keys, compatibility rules,
and the migration path to the next version.

## What does NOT live here

- **The data itself.** Runtime YAML the code loads lives in `config/` (global) or
  `profiles/<name>/` (per-profile). See the placement rule below.
- **The reasoning.** *Why* a contract is shaped this way is recorded, dated, in
  `dev/logs/decisions.md`. A decisions log is the wrong place to look up a field name;
  a schema doc is the wrong place to argue.
- **Designs for changes.** Those are specs in `dev/specs/`.

## The placement rule

> **If code reads it, it goes in `config/`. If a human or agent reads it, it goes in `dev/`.**

A file can therefore have a **home** (`config/actors.yaml`) and a **contract**
(`dev/schemas/actors-v1.md`). Data and contract always split.

## Why these ship

`dev/` ships with workwarrior. That makes every file here a **public contract**, not a
note-to-self: third parties write lenses, adapters, and importers against these
documents. Version increments are therefore an obligation, not hygiene.

## Versioning policy

- A new version file (`-v2.md`) is cut only for a **breaking** change — one that would
  cause an existing correct reader to misparse.
- **Additive, ignorable changes do not require a new version file.** They are recorded
  in the current version's changelog section. Contracts state explicitly which kinds of
  addition are safe (e.g. new `ctx` keys in the stream event format).
- The superseded version file is **kept**, never deleted. Readers in the wild persist.

## Contracts

| Contract | Version | Runtime home |
|---|---|---|
| [`stream-event-v1.md`](./stream-event-v1.md) | v1 | `$WW_BASE/stream/stream.log` |
| [`actors-v1.md`](./actors-v1.md) | v1 | `config/actors.yaml`, `profiles/*/actors.yaml`, `~/.config/ww/registry/actors.yaml` |
| [`ledgers-yaml-v1.md`](./ledgers-yaml-v1.md) | v1 | `profiles/*/ledgers.yaml` |
