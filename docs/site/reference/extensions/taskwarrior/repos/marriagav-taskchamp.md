# marriagav/taskchamp

**URL:** https://github.com/marriagav/taskchamp  
**Stars:** 67  
**Language:** Swift  
**Last push:** 2026-04-06  
**Archived:** No  
**Topics:** cli, ios, ios-app, obsidian, open-source, productivity, tasks-manager, taskwarrior, taskwarrior3  

## Description

Taskwarrior iOS interface app

## Category

Sync

## Workwarrior Integration Rating

**Score:** 4  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- -2: Mobile — outside ww scope

## README excerpt

```
<!-- TOC --><a name="taskchamp"></a>

# Taskchamp

![image](https://github.com/user-attachments/assets/9520b546-c709-4a62-bda0-e20816985e14)

Use [Taskwarrior](https://taskwarrior.org/), a simple command line interface to manage your tasks from you computer, and a beautiful native app to manage them from your phone. Create notes for your tasks with seamless [Obsidian](https://obsidian.md/) integration.

> For contributing to Taskchamp, please read the [CONTRIBUTING.md](CONTRIBUTING.md) file.

> [!IMPORTANT]
> We are looking for beta testers to help us test new builds before releasing them to the App Store, or simply if you want to test the app before buying it. For becoming a beta tester, please go to the [TestFlight page](https://testflight.apple.com/join/K4wrKrzg).

<!-- TOC start -->

- [Contributing](CONTRIBUTING.md)
- [Installation](#installation)
- [Setup with Taskwarrior](#setup-with-taskwarrior)
  - [Setup with Taskchampion Sync Server](#setup-with-taskchampion-sync-server)
  - [Setup with AWS](#setup-with-aws)
  - [Setup with GCP](#setup-with-gcp)
  - [Setup with iCloud Drive](#setup-with-icloud-drive)
- [Obsidian integration](#obsidian-integration)
  - [Interact with Obsidian notes from Taskwarrior](#interact-with-obsidian-notes-from-taskwarrior)

<!-- TOC end -->

<!-- TOC --><a name="installation"></a>

## Installation

To install Taskchamp, download the latest [release from the App Store](https://apps.apple.com/us/app/taskchamp-tasks-for-devs/id6633442700).

Taskchamp can work as a standalone iOS app, but it's recommended to use it with Taskwarrior. To install Taskwarrior, follow the instructions [here](https://taskwarrior.org/download/).

> Taskchamp is only compatible with Taskwarrior 3.0.0 or later.

<!-- TOC --><a name="setup-with-taskwarrior"></a>

## Setup with Taskwarrior

There are currently four ways to setup Taskchamp to work with Taskwarrior: using a Taskchampion Sync Server, using AWS, using GCP, or using iCloud Drive.

> [!NOTE]
> You only need to setup one of these methods, not all of them.

The documentation for how sync works in Taskwarrior can be found [here](https://taskwarrior.org/docs/sync/).

<!-- TOC --><a name="setup-with-taskchampion-sync-server"></a>

### Setup with Taskchampion Sync Server

> Remote Sync works by connecting to a remote taskchampion-sync-server that will handle the synchronization of your tasks across devices.

1. Setup a Taskchampion Sync Server by following the instructions [here](https://gothenburgbitfactory.org/taskchampion-sync-server/introduction.html).

2. Connect to the server from your computer by following the instructions [here](https://man.archlinux.org/man/extra/task/task-sync.5.en#Sync_Server).

3. Open the Taskchamp app on your phone and select `Taskchampion Sync Server` as your sync service.

4. Enter the URL of your sync server, your client id and encryption secret.

5. You will be able to trigger the sync from your computer by executing: `task sync`.

- Read more about Taskw
```