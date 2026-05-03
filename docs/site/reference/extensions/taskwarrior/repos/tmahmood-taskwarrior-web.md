# tmahmood/taskwarrior-web

**URL:** https://github.com/tmahmood/taskwarrior-web  
**Stars:** 193  
**Language:** Rust  
**Last push:** 2026-03-19  
**Archived:** No  
**Topics:** task-manager, taskwarrior  

## Description

Minimalistic web UI for Task warrior

## Category

Sync

## Workwarrior Integration Rating

**Score:** 11  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +3: Uses TimeWarrior — already integrated in ww
- +2: Hook-based — ww can install hooks per profile
- +2: Sync capability relevant to ww profile isolation
- +1: Shell integration — ww is shell-first
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos

## README excerpt

```
# Current Update

All dist files are embeded in the binary. So, no more carrying around the dist folder! 

[I would appreciate if you can support the development effort](https://tmahmood.gumroad.com/coffee)


Please report any bugs, contributions are welcome.

# What is this?

A Minimalistic Web UI for Task Warrior focusing on Keyboard navigation.

It's completely local. No intention to have any kind of online interactions.
Font in the screenshot is [Maple Mono NF](https://github.com/subframe7536/maple-font)

## Stack

- [Rust](https://www.rust-lang.org/) [nightly, will fail to build on stable]
- [axum](https://github.com/tokio-rs/axum)
- [tera](https://github.com/Keats/tera)
- [TailwindCSS](https://tailwindcss.com/)
- [daisyUI](https://daisyui.com/)
- [HTMX](https://htmx.org)
- [hotkeys](https://github.com/jaywcjlove/hotkeys-js)
- [rollup](https://rollupjs.org/)
- [Taskwarrior](https://taskwarrior.org/) (obviously :))
- [Timewarrior](https://timewarrior.net)

Still work in progress. But in the current stage it is pretty usable. You can see the list at the bottom, for what I intend to add, and what's been done.

![Application](./screenshots/full_page.png)

# Using Release Binary

Latest release binaries are now available. Check the release tags on the sidebar

# Using Docker

Docker image is provided. A lot of thanks go to [DCsunset](https://github.com/DCsunset/taskwarrior-webui)
and [RustDesk](https://github.com/rustdesk/rustdesk/)

```shell
docker build -t taskwarrior-web-rs . \
&& docker run --init -d -p 3000:3000 \
-v ~/.task/:/app/taskdata/ \
-v ~/.taskrc:/app/.taskrc \
-v ~/.timewarrior/:/app/.timewarrior/ \
--name taskwarrior-web-rs taskwarrior-web-rs
```

As a service, every push to the `main` branch of this repository will provide automatic a docker image and can be pulled via

```shell
docker pull ghcr.io/tmahmood/taskwarrior-web:main
```

That should do it.

## Volumes

The docker shares following directories as volumes to store data:

| Volume path                  | Purpose                                        |
| -----------------            | ---------------------------------------------- |
| /app/taskdata                | Stores task data (mostly taskchampion.sqlite3) |
| /app/.timewarrior            | Stores timewarrior data                        |
| /app/.config/taskwarrior-web | Stores taskwarrior-web configuration file      |

It is recommend to specify the corresponding volume in order to persist the data.

## Ports

`taskwarrior-web` is by default internally listening on port `3000`:

| Port | Protocol | Purpose                          |
| ---- | -------- | -------------------------------- |
| 3000 | tcp      | Main webserver to serve the page |

## Environment variables

In order to configure the environment variables and contexts for `timewarrior-web`, docker environments can be specified:

| Docker environment               | Shell environment       | Purpose                                                  |
|-------
```