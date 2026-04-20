# 00sapo/taskcheck

**URL:** https://github.com/00sapo/taskcheck  
**Stars:** 32  
**Language:** Python  
**Last push:** 2026-01-18  
**Archived:** No  
**Topics:** taskwarrior  

## Description

A non-AI automatic scheduler for taskwarrior (i.e. alternative to skedpal/timehero/flowsavvy/reclaim/trevor/motion)

## Category

Sync

## Workwarrior Integration Rating

**Score:** 9  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +2: Urgency coefficients are a ww UDA focus area
- +3: UDAs — core to ww service model
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- -2: Mobile — outside ww scope

## README excerpt

```
<div align="center">
  
```
########    ###     ######  ##    ##  ######  ##     ## ########  ######  ##    ## 
   ##      ## ##   ##    ## ##   ##  ##    ## ##     ## ##       ##    ## ##   ##  
   ##     ##   ##  ##       ##  ##   ##       ##     ## ##       ##       ##  ##   
   ##    ##     ##  ######  #####    ##       ######### ######   ##       #####    
   ##    #########       ## ##  ##   ##       ##     ## ##       ##       ##  ##   
   ##    ##     ## ##    ## ##   ##  ##    ## ##     ## ##       ##    ## ##   ##  
   ##    ##     ##  ######  ##    ##  ######  ##     ## ########  ######  ##    ## 
```

> _A non-AI automatic scheduler for taskwarrior (i.e. alternative to skedpal / timehero / flowsavvy / reclaim / trevor / motion)_

  ![immagine](https://github.com/user-attachments/assets/27b83bb1-7a50-4923-a453-0a958fbe11ed)

</div>

This is a taskwarrior extension that automatically schedules your tasks based on your working hours,
estimated time, and calendar events, finding an optimal time to work on each task and match all your
deadlines.

> [!IMPORTANT]
> Due to the new synchronization method of TaskWarrior and to the lack of simple Android integration, I have moved to Super Productivity.
> I won't develop this software anymore, but it is pretty stable, as I used it for about 1 year.
>
> I moved this same idea in a Super Productivity plugin: https://github.com/00sapo/sp-autoplan

## Features

- [x] **Use arbitrarily complex time maps for working hours**
- [x] Block scheduling time using iCal calendars (meetings, vacations, holidays, etc.)
- [x] **Parallel scheduling algorithm for multiple tasks, considering urgency and dependencies**
- [x] Dry-run mode: preview scheduling without modifying your Taskwarrior database
- [x] Custom urgency weighting for scheduling (via CLI or config)
- [x] **Auto-fix scheduling to match due dates**
- [x] Force update of iCal calendars, bypassing cache
- [x] Simple, customizable reports for planned and unplanned tasks
- [x] Emoji and attribute customization in reports
- [ ] Use Google API to access calendars
- [ ] Export tasks to iCal calendar and API calendars

## Install

1. `pipx install taskcheck`
2. `taskcheck --install`

## How does it work

This extension parses your pending and waiting tasks sorted decreasingly by urgency and tries to schedule them in the future.
It considers their estimated time to schedule all tasks starting from the most urgent one.

#### UDAs

Taskcheck leverages two UDAs, `estimated` and `time_map`. The `estimated` attribute is
the expected time to complete the task in hours. The `time_map` is a comma-separated list of strings
that indicates the hours per day in which you will work on a task (e.g. `work`, `weekend`, etc.).
The exact correspondence between the `time_map` and the hours of the day is defined in the configuration
file of taskcheck. For instance:

```toml
[time_maps]
# get an error)
[time_maps.work]
monday = [[9, 12.30], [14, 17]]
tuesday = [[9, 12.30], [14, 17]
```