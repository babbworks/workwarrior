# Zebradil/tw-wifi-contexter

**URL:** https://github.com/Zebradil/tw-wifi-contexter  
**Stars:** 2  
**Language:** Python  
**Last push:** 2023-12-15  
**Archived:** No  
**Topics:** productivity, task-manager, tasklist, taskwarrior  

## Description

Simple hook for taskwarrior which switches context according to WIFI SSID.

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 3  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +1: Shell scripting — matches ww stack

## README excerpt

```
# tw-wifi-contexter
Simple hook for taskwarrior which switches context according to WIFI SSID.
Currently only MacOS is supported.

The hook executes on each invocation of `task` command. If it can get WIFI SSID, that SSID is listed in config, and according context is not set, then the hook sets this context.
If SSID is unknown or appropriate context already active, the hook does nothing. 


## Usage

All you need is to copy hook in hooks directory and create config.
Config is ini-file with one section `[DEFAULT]`. Keys are contexts, values are lists of SSIDs.
For example:
```ini
[DEFAULT]
work=office, office_guest
home=MY_WIFI_SPOT
```

```bash
# Copy `on-launch.switch-context.py` to hooks directory (it's `~/.task/hooks` by default).
cp src/on-launch.switch-context.py ~/.task/hooks/

# Create ini config in hooks directory
cp ssid_context_map.ini.example ~/.task/hooks/ssid_context_map.ini

# Set mappings: context-to-SSIDs
vim ~/.task/hooks/ssid_context_map.ini
```

## TODO

- support for Windows and Linux
- tests
- on/off hook switcher in taskwarrior config
- action for unknown SSID
```