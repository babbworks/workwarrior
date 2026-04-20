# mehdidc/task_gcal_sync

**URL:** https://github.com/mehdidc/task_gcal_sync  
**Stars:** 0  
**Language:** Python  
**Last push:** 2018-05-13  
**Archived:** No  
**Topics:** task-manager, task-scheduler, task-warrior, taskwarrior  

## Description

_No description provided._

## Category

Sync

## Workwarrior Integration Rating

**Score:** 5  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Python — tooling language used in ww

## README excerpt

```
## task sync google calendar

Task google calendar sync is a script that syncs taskwarrior (http://taskwarrior.org)
tasks from and to google calendar.

## How to install

```pip install git+https://github.com/mehdidc/task_gcal_sync```

## How to use ?

First, you will need to obtain authorization to use your google calendar.
To do that, please follow https://developers.google.com/calendar/quickstart/python.
In principle, now you should have downloaded a file called client_secret.json.
You need to create a folder in ~/.task_gcal_sync and put client_secret.json there.

Then, you can type:

```task_gcal_sync init```


in order to choose the google calendar on which to sync.
Google calendars have an identifier that you can get from
the sharing menu of the corresponding calendar.



Then, you can use the action sync_to_gcal to synchronize your tasks
on google calendar.

```task_gcal_sync sync_to_gcal```

Each task will correspond to one event in the calendar.
Only tasks in taskwarrior with the "scheduled" option are considered.
The "scheduled" datetime will correspond to the starting event in google calendar.
If the task in taskwarrior has a "due" option, then it will correspond to the end of the event
in google calendar. If the task in taskwarrior has no "due" option, then the end of the event
is the same as the start of the event in google calendar.

You can then change the task starting and end times directly in google calendar and sync back
to task warrior.

```task_gcal_sync sync_from_gcal```

Note that only start end end datetimes are synced back from google calendar.

```