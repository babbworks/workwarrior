# mrVanDalo/taskwarrior-hooks

**URL:** https://github.com/mrVanDalo/taskwarrior-hooks  
**Stars:** 25  
**Language:** Rust  
**Last push:** 2025-04-04  
**Archived:** No  
**Topics:** hooks, rust, taskwarrior  

## Description

A collection of taskwarrior hooks written in rust (because of speed)

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 6  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +3: UDAs — core to ww service model
- +1: Shell scripting — matches ww stack

## README excerpt

```
# How to install

to install all binaries in `~/.cargo/bin` run.

```
cargo install --path .
```

# Executables

* [scheduled-recur](#scheduled-recur) reschedule tasks instead of completing them.
* [auto-tagger](#auto-tagger) extract tags from description for convenience .

## scheduled-recur

Reschedule tasks, instead of completing them.
Task will be rescheduled `today + (given duration)`.

### setup

Add this UDA to your `~/.taskrc`.

```
# scheduled_recur
uda.scheduled_recur.type=duration
uda.scheduled_recur.label=Scheduled Recurance
# END scheduled_recur
```

and this hook to `~/.task/hooks/on-modify.scheduled-recur.sh`

```sh
#!/usr/bin/env bash
~/.cargo/bin/scheduled-recur
```

### use

Duration are set using
[ISO8601](https://en.wikipedia.org/wiki/ISO_8601#Durations).
For example : `scheduled_recur:P1D` or `scheduled_recur:P1DT8H`

## auto-tagger 

Automatic adds tags by parsing the description.
The description string will be split in words and the
matching must be exact, no regular expressions supported (yet?).

### setup

You have to define a configuration file `tag-map.json`,
here is an example :

```
[
  {
    "name": "buy",
    "keywords": ["buy" "shopping" "shop" ]
  },
  {
    "name": "bug",
    "keywords": ["fix", "bug"]
  }
]
```


#### on-add 

To use for on-add 

```sh
#!/usr/bin/env bash
~/.cargo/bin/auto-tagger <path/to/tag-map.json>
```

#### on-modify

to use for on-modify (just drop the original line)

```sh
#!/usr/bin/env bash
read original_line
~/.cargo/bin/auto-tagger <path/to/tag-map.json>
```

```