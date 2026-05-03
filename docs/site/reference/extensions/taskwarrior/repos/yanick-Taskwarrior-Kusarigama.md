# yanick/Taskwarrior-Kusarigama

**URL:** https://github.com/yanick/Taskwarrior-Kusarigama  
**Stars:** 25  
**Language:** Perl  
**Last push:** 2019-05-01  
**Archived:** No  
**Topics:** taskwarrior  

## Description

plugin system for the Taskwarrior task manager

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 8  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +3: UDAs — core to ww service model
- +1: Reporting is a ww surface area
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration

## README excerpt

```
# NAME

Taskwarrior::Kusarigama - plugin system for the Taskwarrior task manager

# VERSION

version 0.12.0

# SYNOPSIS

```
$ task-kusarigama add GitCommit Command::ButBefore Command::AndAfter

$ task-kusarigama install

# enjoy!
```

# DESCRIPTION

This module provides a plugin-based way to run hooks and custom
commands for the
cli-based task manager [Taskwarrior](http://taskwarrior.org/).

## Configuring Taskwarrior to use Taskwarrior::Kusarigama

### Setting up the hooks

Taskwarrior's main method of customization is via hooks
that are executed when the command is run, when it exits, and when
tasks are modified or added. (see [https://taskwarrior.org/docs/hooks.html](https://taskwarrior.org/docs/hooks.html)
for the official documentation) `Taskwarrior::Kusarigama` leverages this
hook system to allow the creation of custom behaviors and commands.

First, you need to install hook scripts that will invoke `Taskwarrior::Kusarigama`
when `task` is running. You can do that by either using the helper `task-kusarigama`:

```
$ task-kusarigama install
```

Or dropping manually hook scripts in the `~/.task/hooks` directory. The scripts
should look like

```perl
#!/usr/bin/env perl

# script '~/.task/hooks/on-launch-kusarigama.pl'

use Taskwarrior::Kusarigama;

Taskwarrior::Kusarigama->new( raw_args => \@ARGV )
    ->run_event( 'launch' ); # change with 'add', 'modify', 'exit'
                             # for the different scripts
```

### Setting which plugins to use

Then you need to tell the system with plugins to use,
either via `task-kusarigama`

```
$ task-kusarigama add Command::AndAfter
```

or directly via the Taskwarrior config command

```
$ task config  kusarigama.plugins  Command::AndAfter
```

### Configure the plugins

The last step is to configure the different plugins. Read their
documentation to do it manually or, again, use `task-kusarigama`.

```
$ task-kusarigama install
```

## Writing plugins

The inner workings of the plugin system are fairly simple.

The list of plugins we want to be active lives in the taskwarrior
configuration under the key <kusarigama.plugins>. E.g.,

```
kusarigama.plugins=Renew,Command::ButBefore,Command::AndAfter,+FishCurrent
```

Plugin names prefixed with a plus sign are left alone (minus the '+'),
while the other ones get `Taskwarrior::Kusarigama::Plugin::` prefixed to
them.

The Taskwarrior::Kusarigama system itself is invoked via the
scripts put in `~/.task/hooks` by `task-kusarigama`. The scripts
detect in which stage they are called (launch, exit, add or modified),
and execute all plugins that consume the associated role (e.g.,
[Taskwarrior::Kusarigama::Hook::OnLaunch](https://metacpan.org/pod/Taskwarrior::Kusarigama::Hook::OnLaunch)), in the order they have been
configured.

For example, this plugin will runs on a four hook stages:

```perl
package Taskwarrior::Kusarigama::Plugin::PrintStage;

use 5.10.0;

use strict;
use warnings;

use Moo;

extends 'Taskwarrior::Kusarigama::Plugin';

with 'Task
```