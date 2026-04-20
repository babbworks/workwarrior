# nerab/twmail

**URL:** https://github.com/nerab/twmail  
**Stars:** 17  
**Language:** Ruby  
**Last push:** 2021-04-30  
**Archived:** No  
**Topics:** email, mda, taskwarrior  

## Description

Mail new tasks to your TaskWarrior inbox

## Category

Sync

## Workwarrior Integration Rating

**Score:** 7  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +2: Sync capability relevant to ww profile isolation
- +1: Shell integration — ww is shell-first
- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration

## README excerpt

```
# twmail

[![Build Status](https://travis-ci.org/nerab/TaskWarriorMail.svg?branch=master)](https://travis-ci.org/nerab/TaskWarriorMail)

`twmail` allows you to mail new tasks to your TaskWarrior inbox.

## Installation

    $ gem install twmail

## Usage

1. Install ruby and this gem
1. If you don't have a `~/.fetchmailrc` yet, copy `doc/fetchmailrc.sample` to `~/.fetchmailrc`
1. Edit `~/.fetchmailrc` and adjust mail account settings (the example was made for Google Mail account). If in doubt, consult the `fetchmail` documentation, e.g. by executing `man fetchmailconf` in a terminal.

If Docker is your thing, check out [eyenx/docker-taskwarriormail](https://github.com/eyenx/docker-taskwarriormail).

## Motivation

I would like to add new tasks to my TaskWarrior inbox from remote places where I don't have immediate access to my personal TaskWarrior database; e.g. from my iPhone, from work (where I don't have access to my personal TaskWarrior installation) or from another computer.

Using eMail for this looks like a great candidate:

1. I don't want to (or cannot) install TaskWarrior on all the places and machines where I would like to add tasks from. Sending a note as eMail is pretty much universally available.
1. Many applications were not made for integration with TaskWarrior. But even the dumbest iPhone app can forward text or a URL via eMail.
1. eMail is asynchronous by design (fire and forget). Even if disconnected from the net, I can send eMail and the system will deliver it on the very next occassion.

What is missing from a TaskWarrior perspective right now is a way to add these mails to a TaskWarrior installation automatically.

## Architecture

The simplest solution I could come up with is this:

1. A dedicated email account is used to collect the tasks.
1. A script that imports all eMails as new tasks.

As a prerequisite, TaskWarrior is assumed to be installed and configured. With this architecture in place, the functionality is rather simple to implement:

    For each mail{
      Transaction{
        * Fetch mail from mailbox
        * Store mail as new task in Taskwarrior
        * Delete mail from mailbox
      }
    }

  As the word `Transaction` implies, the whole operation needs to be atomic per mail. No task must be added if fetching a mail went wrong, and no mail must be deleted if storing the task in TaskWarrior failed.

The solution presented here maintains a one-to-one relation between the INBOX of an mail account and the TaskWarrior database.

## Components

Mail fetching is done with `fetchmail`, a proven solution available on all major Unices incl. MacOS. It will be configured to use the `twmail` script as a mail delivery agent (mda), which means nothing more than that `fetchmail` fetches the mail from the configured account and hands it over to our script. There is no further storage of the received mails except in TaskWarrior.

## Error Handling

If our MDA returns non-zero, `fetchmail` will not assume the message to be
```