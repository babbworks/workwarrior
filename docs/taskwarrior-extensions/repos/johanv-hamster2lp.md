# johanv/hamster2lp

**URL:** https://github.com/johanv/hamster2lp  
**Stars:** 0  
**Language:** Shell  
**Last push:** 2016-12-20  
**Archived:** No  
**Topics:** hack, hamster, liquidplanner, taskwarrior  

## Description

Push data from hamster time tracker and taskwarrior to LiquidPlanner

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 7  
**Rating:** ★★★★☆  High  

### Scoring notes

- +3: Bugwarrior is in ww issues pipeline
- +2: Hook-based — ww can install hooks per profile
- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration

## README excerpt

```
# h2lp

h2lp contains two tools already to get stuff into LiquidPlanner.

## h2lp.sh

This was the initial tool. It fills out LiquidPlanner timesheets based on
information from the project hamster database.

It does not pull tasks from LiquidPlanner, it works the other way round. It
creates tasks in LiquidPlanner if hamster tasks aren't found. This is because
I don't use LiquidPlanner for planning, I only use it for time tracking.

## t2lp.sh

This is a second tool, that imports tasks from taskwarrior into
LiquidPlanner projects. It is able to package the new tasks, w00t ;-).

## how it works

Create a file `~/.h2lprc`, based on the contents of [h2lprc.example](h2lprc.example).
You need to provide your LiquidPlanner credentials, and mappings from
hamster categories/taskwarrior projects to LiquidPlanner folders. You
can also map all tasks of a project/category to one particular LiquidPlanner task.

Tasks in categories/projects without mapping are ignored.

`h2lp.sh` requires a data as command line argument. Only
time tracked on or after the date is entered in the LiquidPlanner timesheet.
E.g.

    ./h2lp.sh 2016-10-19

The script does some kind of logging in a file `~/.h2lp.facts` to prevent
times to be logged twice.

`t2lp.sh` just copies the pending tasks. It does not require any arguments.
If you want to package all newly created tasks (,
make sure the PACKAGE_ID variable is set correctly in `~/.h2lprc`.

## but why?

I recently discovered [taskwarrior](https://taskwarrior.org/), which quickly
became my favourite task manager. It can import issues from our issue tracker
(see [bugwarrior](https://github.com/ralphbean/bugwarrior)) and it also
integrates with [project hamster](https://github.com/projecthamster/hamster-gtk),
(see [taskwarrior-hamster-hook](https://github.com/fmeynadier/taskwarrior-hamster-hook)),
a time tracker I have been using for several years.

Now my collegues use LiquidPlanner for planning and time tracking, and I have to
enter my time tracking in LiquidPlanner as well. I have been doing this manually way too often,
so now at last I have a script to do this.

## don't try this at home

This is a hack. If you want to use it, you can, but don't recommend this to
others. It might ruin your LiquidPlanner. You can do script injection via task
names, and other horrible stuff. I just created this to avoid boring work.

```