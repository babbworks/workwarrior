# jonathanvanschenck/taskwarrior-telegram-bot

**URL:** https://github.com/jonathanvanschenck/taskwarrior-telegram-bot  
**Stars:** 0  
**Language:** JavaScript  
**Last push:** 2026-02-15  
**Archived:** No  
**Topics:** taskwarrior, taskwarrior2, taskwarrior3, telegraf, telegram  

## Description

A telegram bot for all your taskwarrior needs

## Category

TUI / Interactive

## Workwarrior Integration Rating

**Score:** 3  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source

## README excerpt

```
# Taskwarrior Telegram Bot

A Telegram bot that provides a chat interface to [Taskwarrior](https://taskwarrior.org/), the command-line task management tool.


[![GitHub Release](https://img.shields.io/github/v/release/jonathanvanschenck/taskwarrior-telegram-bot)](https://github.com/jonathanvanschenck/taskwarrior-telegram-bot/releases)
[![License: ISC](https://img.shields.io/badge/License-ISC-blue.svg)](LICENSE)

## Note from the author
I really just made this for myself, to get push notifications and easy task creation on mobile, but hopefully you will find it useful too!

This bot is still in early development and may have bugs or incomplete features. Use at your own risk, and feel free to contribute or report issues! Additionally, many features are still being worked on, so breaking changes may occur in the future.

Additionally, I primarily use Taskwarrior 3, but I hope to maintain some compatibility with Taskwarrior 2 as well. If you encounter any issues specific to one version, please let me know.

## Features

| Command | Description |
|---|---|
| `/start` | Register with the bot and receive a welcome message |
| `/stop` | Unregister from the bot and stop receiving messages |
| `/help` | Show available commands |
| `/version` | Show bot and Taskwarrior versions |
| `/list [filter]` | List tasks (with optional filter) |
| `/info <id>` | Show detailed task info |
| `/add <description>` | Add a new task |
| `/modify <id> <mods>` | Modify an existing task |
| `/annotate <id> <text>` | Add an annotation to a task |
| `/begin <id>` | Start a task |
| `/end <id>` | Stop a task |
| `/done <id>` | Mark a task as done |
| `/delete <id>` | Delete a task |

## Setup

### Environment Variables

| Variable | Required | Description |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | Yes | Telegram bot API token |
| `TELEGRAM_CHAT_ID` | No | Restrict bot to a specific chat. This is *highly* suggested, otherwise anyone can edit your tasks |
| `TELEGRAM_USER_ID` | No | Restrict bot to a specific user |
| `DB_DATA` | No | Path to directory for sqlite database, default is `$HOME/.ttb` (you can use ':memory:' to run in RAM, or set to empty string to turn the db off completely) |
| `TW_BIN` | No | Path to `task` binary, default is `task` |
| `TW_TASKRC` | No | Path to `.taskrc`, default is `$HOME/.task` |
| `TW_TASKDATA` | No | Path to task data directory, default is `$HOME/.taskrc` |
| `CRON_DATA` | No | Path to the diretory for the cron files (`*.json`) defualt is `$HOME/.ttb` |

### Telegram Setup

1. Create a new bot using [@BotFather](https://t.me/BotFather) and get the API token.
2. (Highly recommended) Get your user ID using a bot like [@JsonDumpBot](https://t.me/JsonDumpBot).
3. Set your environment variables, including `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, and/or `TELEGRAM_USER_ID` to restrict access to the bot.
4. Create a chat with your bot (or use an existing group chat) and send the `/start` command to register with the bot.

### Cron
The bot can run sched
```