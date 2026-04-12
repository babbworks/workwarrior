# initBasti/context-switch-warrior

**URL:** https://github.com/initBasti/context-switch-warrior  
**Stars:** 2  
**Language:** C  
**Last push:** 2021-02-14  
**Archived:** No  
**Topics:** context, schedule, tasks, taskwarrior, zones  

## Description

An extension for taskwarrior to switch between task contexts with a specified schedule

## Category

CLI Tools

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell scripting — matches ww stack
- +1: CLI-first matches ww ethos

## README excerpt

```
# Context-Switch-Warrior
Add-on for **taskwarrior** to *switch* the task **context** depending on the *daytime* and the *defined schedule*.

### Features:
* create and modify a cronjob for the program
* define zones with assigned taskwarrior contexts
* delay zone switches and cancel
* notifications on errors
* toggle if tasks are automatically canceled
* exclude time zones from the schedule(holiday, weekend)

### Todo:
* notification for upcoming events
* zone and exclusion definition from the CLI
* multiple schedules

---

#### Written in C, with the following requirments:
* taskwarrior
* getopt.h
* notify-send
* crontab
* doxygen

---

### How to Build
* make
* sudo make install

### Testing
make test

*generates results in the bin folder*

### Example configuration:

```bash
Zone=Morning;Start=05:00;End=08:00;Context=study
Zone=Work;Start=08:30;End=16:00;Context=work
Zone=Study;Start=16:30;End=20:00;Context=study
Zone=Evening;Start=20:00;End=21:30;Context=freetime
Exclude=permanent(su,sa)
Exclude=temporary(2020-12-09)
Exclude=temporary(2020-12-24#2020-12-27)
Cancel=off
Interval=1min
```

---

#### Found Bugs or want to contribute?
please contact me @ sebastian.fricke.linux@gmail.de

```