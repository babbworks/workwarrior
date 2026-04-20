# kantord/blogtato

**URL:** https://github.com/kantord/blogtato  
**Stars:** 218  
**Language:** Rust  
**Last push:** 2026-04-06  
**Archived:** No  
**Topics:** atom-feed-reader, cli, git-synced, rss, rss-reader, rust, taskwarrior  

## Description

A CLI RSS/Atom feed reader inspired by Taskwarrior

## Category

Sync

## Workwarrior Integration Rating

**Score:** 5  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- -2: Mobile — outside ww scope

## README excerpt

```
# blogtato

A CLI RSS/Atom feed reader inspired by Taskwarrior.

![demo](demo/demo.gif)

## Features

- Subscribe to RSS and Atom feeds
- Simple query language for filtering by feed, read status, and date, with
  grouping and export
- Git-based sync across machines with conflict-free merge
  ([why git?](#design-philosophy))
- No accounts, no servers, no continuous network dependency
- Mark content as read
- Designed to be distraction free, minimalistic and work out of the box

## Install

```bash
cargo install blogtato
```

### Git sync

`git` based synchronization is entire optional. `blogtato` can work entirely
offline on a single device.

To set up git synchronization, create a private repo on your git host, then:

```bash
# On your first machine
blog clone user/repo

# From now on, sync fetches feeds and pushes/pulls from the remote
# with no remote repository, `blog sync` just pulls the latest posts from
# all feeds
blog sync
```

On your device(s), run the same `blog clone` to pull down your feeds and posts.

Don't worry about setting git sync up if you are just trying `blogtato` out:
you can run `blog clone user/repo` later and your existing feeds will be merged
with the remote automatically.

### Quick start

Once you set up your `git`-based sync, or if you decided to skip it, subscribe
to your favorite feeds using `blog feed add`:

```bash
blog feed add https://michael.stapelberg.ch
blog feed add https://www.justinmklam.com
```

You can import your subscriptions from other RSS readers
([Feedly](https://docs.feedly.com/article/52-how-can-i-export-my-sources-and-feeds-through-opml),
[Inoreader](https://www.inoreader.com/blog/2014/05/opml-subscriptions.html),
[NetNewsWire](https://netnewswire.com/help/mac/5.0/en/export-opml.html),
[FreshRSS](https://freshrss.github.io/FreshRSS/en/developers/OPML.html),
[Feeder](https://news.nononsenseapps.com/posts/2.5.0_opml/),
[Tiny Tiny RSS](https://tt-rss.org/docs/Installation-Guide.html#opml),
[Outlook](https://support.microsoft.com/en-us/office/share-or-export-rss-feeds-5b514f38-8671-447c-8c25-7f02cc0833e0),
and others) using an OPML file:

```bash
blog feed import feeds.opml
```

Fetch and list latest posts:

```bash
blog sync
blog
```

Read whatever you found interesting by referring to its shorthand

```bash
blog df read
```

You can subscribe to `blogtato` releases to know when new features or fixes are
available:

```bash
blog feed add https://github.com/kantord/blogtato/releases.atom
```

## Usage examples

```bash
# Subscribe to a feed
blog feed add https://news.ycombinator.com/rss

# Fetch new posts and sync with git remote
blog sync

# Sync only selected feeds by @shorthand from `blog feed ls`
blog sync --feed @df --feed @dg

# Show posts (defaults to unread posts from the last 3 months, grouped by week)
blog

# Group by date, week, or feed
blog /d
blog /w
blog /f

# Combine groupings
blog /d /f

# Filter by feed shorthand
blog @hn

# Filter by read status
blog .unread
blog .read
blog .all

#
```