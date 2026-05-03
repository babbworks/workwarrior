# tom-doerr/taskwarrior-auto-tag-hook

**URL:** https://github.com/tom-doerr/taskwarrior-auto-tag-hook  
**Stars:** 1  
**Language:** Python  
**Last push:** 2022-08-28  
**Archived:** No  
**Topics:** taskwarrior  

## Description

This hook script allows to automatically add tags to a task.

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile

## README excerpt

```
# Taskwarrior-auto-tag-hook

This hook script allows to automatically add tags to a task. 

## Installation

Option 1:
1. Copy `tags.config` to your `task/hooks/` folder
2. Copy `auto_tag.py` to you `task/hooks/` folder, rename it to `on-add.auto_tag.py` and make it executable by running `chmod +x on-add.auto_tag.py`
3. Copy `auto_tag.py` to you `task/hooks/` folder a second time, rename it to `on-modify.auto_tag.py` and make it executable by running `chmod +x on-modify.auto_tag.py`

Option 2:

Just execute `./setup` and it will create links to the script and configuration files you just downloaded.


## Configuration

Each attribute name in the tags.config file represents the tag to which another tag should be added. In the json file, the value following the attribute name is the tag that is going to be added to the task. 


```