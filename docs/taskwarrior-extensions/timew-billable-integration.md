# timew-billable integration (ww)

## Assessment

[timew-billable](https://github.com/trev-dev/timew-billable) (trev-dev · MIT) adds a `timew report billable` extension: per-client rates, CSV export, and terminal tables. It is implemented in **Nim** and ships as a single compiled binary.

TimeWarrior loads extensions from **`$TIMEWARRIORDB/extensions/`** (see `man timew`). Global installs under `~/.timewarrior/extensions/` do not apply when ww sets **`TIMEWARRIORDB`** to the active profile’s `.timewarrior/` directory, so billable must be installed **per profile**.

## Decision

- **Install path:** `<profile>/.timewarrior/extensions/billable`
- **Installer:** `ww timew extensions install billable` (clone upstream, `nim c -d:release src/billable.nim`, copy binary, write sidecar metadata `billable.ww-ext.json`).
- **Attribution:** Shown in `ww timew extensions help` and in this doc.

## Per-profile mechanism

1. Activate a ww profile (`p-<name>` or `ww --profile <name> …`).
2. Confirm `echo $TIMEWARRIORDB` points at `…/profiles/<name>/.timewarrior`.
3. Run:

```bash
ww timew extensions install billable
```

ww creates `extensions/` if needed, installs only under that profile, and records upstream URL + `git describe` in `billable.ww-ext.json`.

## Configuration (rates, project markers)

Follow upstream **README.md** and **example.cfg** in the timew-billable repository. Typical workflow:

- Copy `example.cfg` into your timew configuration area and adjust **rates** and tagging rules for clients/projects.
- Use tags or UDA-style markers as described upstream so intervals classify as billable vs non-billable.

ww does not rewrite timew configuration automatically; keep billable config alongside your normal timew setup under the same `TIMEWARRIORDB`.

## Example

```bash
# After install:
timew report billable
```

List installed profile extensions:

```bash
ww timew extensions list
ww --json timew extensions list   # machine-readable
```

Remove from the **active profile only**:

```bash
ww timew extensions remove billable
```

## Generic URL installs

`ww timew extensions install https://github.com/org/repo.git` clones shallowly and attempts, in order:

1. **Nim billable layout** — `src/billable.nim` (same build as preset `billable`).
2. **Nimble package** — `*.nimble` at repo root (`nimble build`, then first executable under `bin/` or repo root).
3. **Shell** — first `*.sh` under two levels, made executable and copied by basename.

Python-only extensions are **not** auto-installed; install manually and symlink into `$TIMEWARRIORDB/extensions/`.

## Prerequisites

- **Nim** (`nim`) on PATH to build timew-billable from source. If missing, the installer exits with install hints (no partial writes in `extensions/`).

## References

- Upstream: https://github.com/trev-dev/timew-billable  
- ww entry points: `ww timew extensions help`, `system/config/command-syntax.yaml` (`domain: timew`).
