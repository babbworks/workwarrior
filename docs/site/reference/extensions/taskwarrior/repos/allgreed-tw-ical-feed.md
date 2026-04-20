# allgreed/tw-ical-feed

**URL:** https://github.com/allgreed/tw-ical-feed  
**Stars:** 2  
**Language:** Python  
**Last push:** 2024-12-25  
**Archived:** No  
**Topics:** icalendar, taskwarrior  

## Description

See your [due] dates for tasks on a calendar, generates an ics feed

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 6  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +3: UDAs — core to ww service model
- +1: Shell integration — ww is shell-first

## README excerpt

```
# tw-ical-feed
See your dates for tasks on a calendar, generates an ics feeds - one for due and one for planned dates

## Usage
For now go for [dev](#dev)

### Manual integration

There's also the experimental notion of planning.

- add the following to your `.taskrc`:
```
uda.estimate.type=duration
uda.estimate.label=Est
uda.plan.type=date
uda.plan.label=Planned
```

- populate this attribute, example:
```
task mod [id] estimate:15min plan:today+12h
```

And a plan event will be created for that task from today 12:00 to 12:15

## Dev

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