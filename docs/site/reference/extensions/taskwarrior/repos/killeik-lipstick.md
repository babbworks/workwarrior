# killeik/lipstick

**URL:** https://github.com/killeik/lipstick  
**Stars:** 0  
**Language:** Shell  
**Last push:** 2025-03-30  
**Archived:** No  
**Topics:** bash, bat, cli, color-scheme, command-line, dark-theme, delta, gnome, helix, light-theme, shell, taskwarrior, terminal  

## Description

Make terminal apps adhere to your light/dark mode setting.

## Category

Issue Tracker Bridges

## Workwarrior Integration Rating

**Score:** 3  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source

## README excerpt

```
# 🐷 Lipstick on a Pig

Lipstick makes command-line apps follow your light/dark mode settings.

[Learn more.](https://ar.al/2022/08/17/lipstick-on-a-pig/)

## System requirements

- GNOME 42+
- A colour scheme aware Terminal application like [Black Box](https://gitlab.gnome.org/raggesilver/blackbox#black-box) or [Ghostty](https://ghostty.org/)
- systemd

## Supported apps

- [Bat](https://github.com/sharkdp/bat#readme)
- [Btop](https://github.com/aristocratos/btop)
- [Delta](https://github.com/dandavison/delta#readme)
- [Helix](https://helix-editor.com)
- [Taskwarior](https://taskwarrior.org/)

> __💡 Got an app you use that isn’t supported?__
>
> Add it to the [lipstick-apps](src/lipstick-apps) file and [submit a pull request](https://github.com/killeik/lipstick/pulls).

## Install

Here are three ways you can install Lipstick on a Pig:

😇 [Download and run this installation script.](https://raw.githubusercontent.com/killeik/lipstick/refs/heads/main/dist/install) 

🤓 Clone this repository and run the `./install` script.

😈 Or, if you enjoy living dangerously, copy and paste one of the following commands into your terminal and run it (ooh, naughty!)

__Using wget:__

```shell
wget -qO- https://raw.githubusercontent.com/killeik/lipstick/refs/heads/main/dist/install | bash
```

__Using curl:__

```shell
curl -s https://raw.githubusercontent.com/killeik/lipstick/refs/heads/main/dist/install | bash
```

Lipstick will automatically find [supported apps](#supported-apps) on your system and configure itself. You shouldn’t have to do anything else.

## Notes

### Overrided Light and Dark Themes
Each application supported by Lipstick can have its default light and dark themes overridden by entries in the `~/.config/lipstick/lipstick.conf` file. The following example file is the equivalent of the Lipstick default themes:

```shell
bat_dark_theme=Dracula
bat_light_theme=Monokai Extended Light

btop_dark_theme=dracula
btop_light_theme=adapta

delta_dark_theme=Dracula
delta_light_theme=Monokai Extended Light

helix_dark_theme=dracula
helix_light_theme=onelight

taskwarrior_dark_theme=dark-256.theme
taskwarrior_light_theme=light-256.theme
```

### Refreshing running apps

Some apps may need to be restarted for the changes to take effect.

Whenever possible, Lipstick should attempt to signal to the app that its configuration has changed so it can reload it. This is what it does for Helix Editor, for example.

### Fedora Silverblue

Please either install Lipstick from the host system or from a [toolbox](https://docs.fedoraproject.org/en-US/fedora-silverblue/toolbox/) container.

(Distrobox currently doesn’t work with systemd `--user` services in either [initful](https://github.com/89luca89/distrobox/issues/380) or [initless](https://github.com/89luca89/distrobox/issues/379#issuecomment-1217864773) containers and the installer will fail under a Distrobox container.)

### Thanks
This repository is a fork of the [original lipstick repository on codeberg](https://code
```