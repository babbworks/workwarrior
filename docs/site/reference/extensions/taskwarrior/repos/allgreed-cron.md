# allgreed/cron

**URL:** https://github.com/allgreed/cron  
**Stars:** 1  
**Language:** Python  
**Last push:** 2026-02-25  
**Archived:** No  
**Topics:** taskwarrior, taskwarrior2  

## Description

Stateful, small-yet-robust cron - mostly meant for managing my routines by generating Taskwarrior tasks

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 7  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww

## README excerpt

```
# cron
Stateful, small-yet-robust cron - mostly meant for managing my routines by generating Taskwarrior tasks.
Though you can probably extend it to do pretty much everything. If you're brave enough.

I'm open sourcing it because **[@oneacik](https://github.com/oneacik/)** liked it

## What's wrong with `crontab` or [native recurring tasks](https://taskwarrior.org/docs/recurrence/)?

TODO: elaborate

## Features (at the time of writing)
**Disclaimer:** I don't intend to keep this section up to date, maybe will autogenerate in the future, whatever

The source is small enough that I recommend going through it for a comprehensive overview

- making simple things simple

    let's say for the sake of the argument that as per Papa Peterson you'd like to clean your room every week:

    ```python
    class CleanRoom(Weekly):
        task = T("clean the room!")
    ```
- reasonable defaults
    - example: create tags are automatically tagged with `+cron` and `until` is set for their recurrence date (so a Weekly task has `until:7d`)
    - there are already present durations for week, month, etc.
- escape hatch
    ```python
    TODO: show shell for browser for example
    ```
- deep Taskwarrior integration - interval rollover
    ```python
    # TODO: provide code example
    ```
    TODO: explain this feature
- making complex things possible
    ```python
    # TODO: provide code example
    mkPeriodic
    + class override
    ```


## Usage
```bash
git clone git@github.com:allgreed/cron.git
mkdir mycron
# or whatever you want to call it
cd $_
ln -s ../cron/cron.py cron.py
ln -s ../cron/default.nix default.nix
cat << EOF > mycron.py
from cron import main, Task as T, Weekly

# here go your Recurrings
...

if __name__ == "__main__":
    main()
EOF
```

write an actual `Recurring` and then

```bash
nix-shell
python3 mycron.py
```

## Dev

### Design principles
1. specific purpose - my use case will Trump all other concerns
2. straightforward - at the same time I believe that my use case is common enough that there should be something already. I couldn't find anything, so I'm doing this. This is **not** innovative, surprises are a bug, this is not a place of honor.
3. optionally a bit clever - re:epistemological value of programming - while coding this I'm learning more about routines and recurrence - this leads to ideas, however they're a) optional b) specific - example: interval rollover (which needs to be explicitly enabled)

### Prerequisites
- [nix](https://nixos.org/download.html)
- `direnv` (`nix-env -iA nixpkgs.direnv`)
- [configured direnv shell hook ](https://direnv.net/docs/hook.html)
- some form of `make` (`nix-env -iA nixpkgs.gnumake`)

Hint: if something doesn't work because of missing package please add the package to `default.nix` instead of installing it on your computer. Why solve the problem for one if you can solve the problem for all? ;)

### One-time setup
```
make init
```

### Everything
```
make help
```

```