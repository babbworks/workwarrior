# gkssjovi/trackwarrior

**URL:** https://github.com/gkssjovi/trackwarrior  
**Stars:** 41  
**Language:** JavaScript  
**Last push:** 2022-11-08  
**Archived:** No  
**Topics:** taskwarrior, timewarrior  

## Description

This extension create a link between taskwarrior and timewarrior that allows you to keep track of time spend on tasks. The time will be displayed in a new column in taskwarrior.

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 14  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +3: Uses TimeWarrior — already integrated in ww
- +2: Hook-based — ww can install hooks per profile
- +2: Urgency coefficients are a ww UDA focus area
- +3: UDAs — core to ww service model
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source

## README excerpt

```
## Description

This extension create a link between [taskwarrior](https://github.com/GothenburgBitFactory/taskwarrior) and  [timewarrior](https://github.com/GothenburgBitFactory/timewarrior) that allows you to keep track of time spend on tasks. 
The time will be displayed in a new column in taskwarrior.

## Docker

```sh
git clone https://github.com/gkssjovi/trackwarrior.git
cd trackwarrior

sudo ln -s "$PWD/bin/trackwarrior-docker" /usr/local/bin/trackwarrior
```

### Use tasksh as main frontend
```sh
sudo rm /usr/local/bin/trackwarrior
sudo ln -s "$PWD/bin/trackwarrior-docker-tasksh" /usr/local/bin/trackwarrior
```

### Use taskwarrior-tui as main frontend
```sh
sudo rm /usr/local/bin/trackwarrior
sudo ln -s "$PWD/bin/trackwarrior-docker-tui" /usr/local/bin/trackwarrior
```

## Local Installation

```sh
git clone https://github.com/gkssjovi/trackwarrior.git
cd trackwarrior

cp -r ./taskwarrior/hooks/. ~/.task/hooks
cp -r ./timewarrior/extensions/. ~/.timewarrior/extensions

cd ~/.task/hooks
chmod +x on-modify.trackwarrior on-add.trackwarrior

cd ~/.timewarrior/extensions
chmod +x trackwarrior-duration.js trackwarrior-ids.js
```

## Configuration

Copy those lines into your `~/.taskrc` file
```sh
uda.trackwarrior.type=string
uda.trackwarrior.label=Total active time
uda.trackwarrior.values=

uda.trackwarrior_rate.type=string
uda.trackwarrior_rate.label=Rate
uda.trackwarrior_rate.values=

uda.trackwarrior_total_amount.type=string
uda.trackwarrior_total_amount.label=Total amount
uda.trackwarrior_total_amount.values=

# this allow only one task to be active
max_active_tasks=1 
# when you delete the task, the time tracking will be also be deleted from timewarrior 
erase_time_on_delete=false 
# those are tags in taskwarrior.When you add one of them the time tracking will be deleted from timewarrior
clear_time_tags=cleartime,ctime,deletetime,dtime
update_time_tags=update,updatetime,utime,recalc
create_time_when_add_task=false
rate_per_hour=10
rate_per_hour_decimals=2
rate_per_hour_project=Inbox:0,Other:10
rate_format_with_spaces=10
currency_format=de-DE,EUR
```

To display the new column on the next report modify the `~/.taskrc` file
```sh
report.next.labels=ID,St,Active,Age,Time,Rate,Total,...,Description,Urg
report.next.columns=id,status.short,start.age,entry.age,trackwarrior,trackwarrior_rate,trackwarrior_total_amount,...,description,urgency
```

## Usage
If you installed the docker version, just run `trackwarrior` to open the configured fronted (default: fish shell).

## Integrate with starship
1) Locally install taskwarrior
2) Install [starship](https://starship.rs/guide/#%F0%9F%9A%80-installation)
3) Set the correct rights for your local taskwarrior to read the data from the container
```sh
# trackwarrior needs to be used at least once
sudo chown "$(id -u):$(id -g)" ~/.trackwarrior-docker/.task/pending.data
```

4) Add the following to your starship.toml

```toml
[custom.current_task]
command = """TASKRC=~/.trackwarrior-docker/.taskrc TASKDATA=~
```