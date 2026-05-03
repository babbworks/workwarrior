# svamberg/xfce4-taskwarrior

**URL:** https://github.com/svamberg/xfce4-taskwarrior  
**Stars:** 0  
**Language:** Shell  
**Last push:** 2021-11-15  
**Archived:** No  
**Topics:** taskwarrior  

## Description

Taskwarrior plugin for xfce4 panel

## Category

Issue Tracker Bridges

## Workwarrior Integration Rating

**Score:** 5  
**Rating:** ★★★★☆  High  

### Scoring notes

- +3: Uses TimeWarrior — already integrated in ww
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos

## README excerpt

```
# XFCE TaskWarrior widget
Taskwarrior widget for xfce4 panel inspired by https://github.com/bimlas/xfce4-timewarrior

XFCE Generic Monitor widget that allows you to easily *show the actual (or the most recent) task in TaskWarrior*.

https://gitlab.com/svamberg/xfce4-taskwarrior 

# Create the widget
* Install the packages first if they are not already on your system
 + [XFCE Generic Monitor plugin](https://docs.xfce.org/panel-plugins/xfce4-genmon-plugin) `xfce4-genmon-plugin`
 + [TaskWarrior](https://taskwarrior.net/) `taskwarrior`
 + [FZF](https://github.com/junegunn/fzf) `fzf` or [Rofi](https://github.com/davatorium/rofi) `rofi`
* Add the monitor to the panel
 + Right click on the panel
 + Select _Panel -> Add new items_
 + Add _Generic Monitor_ plugin
* Set up the generic monitor to use with this script
 + Right click on the newly added generic monitor -> _Properties_
 + Command: `/path/to/xfce4-taskwarrior.sh rofi` or `/path/to/xfce4-taskwarrior.sh fzf`
 + Uncheck the checkbox of _Label_
 + Set _Period_ to `5` seconds

# Usage
* Click on the image to start/stop the most recent task
* Click on the task name to select new task

```