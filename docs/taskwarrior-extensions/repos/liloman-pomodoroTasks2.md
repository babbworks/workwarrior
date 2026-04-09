# liloman/pomodoroTasks2

**URL:** https://github.com/liloman/pomodoroTasks2  
**Stars:** 35  
**Language:** Python  
**Last push:** 2017-11-11  
**Archived:** No  
**Topics:** dbus, gtk, gui, habit-tracking, pomodoro-technique, reminder, taskwarrior, timewarrior, workflow  

## Description

 Systray app for pomodoro with taskwarrior 

## Category

Sync

## Workwarrior Integration Rating

**Score:** 13  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +3: Uses TimeWarrior — already integrated in ww
- +2: Hook-based — ww can install hooks per profile
- +2: Sync capability relevant to ww profile isolation
- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww

## README excerpt

```

[ ![PomodoroTasks2 in copr](https://copr.fedorainfracloud.org/coprs/liloman/githubs/package/pomodoroTasks2/status_image/last_build.png "PomodoroTasks2 in copr")](https://copr.fedorainfracloud.org/coprs/liloman/githubs/package/pomodoroTasks2)

Don't make any excuse anymore to not use the [Pomodoro Technique wikipedia](https://en.wikipedia.org/wiki/Pomodoro_Technique) or [The Pomodoro Technique ](extras/technique.pdf)!

Pomodoro technique allows you to concentrate on the current task and take short breaks meanwhile works.
If you get that and join it with a task manager alike taskwarrior (or any other) you can have a complete workflow, accounting the time spend on any task meanwhile you take the proper rests for your brain, body, life and eyes. :)

Table of Contents
=================

   * [Table of Contents](#table-of-contents)
   * [INSTALL](#install)
      * [Packages](#packages)
      * [Manual](#manual)
   * [Why do I need timewarrior?](#why-do-i-need-timewarrior)
   * [Reminders](#reminders)
   * [Screenshots](#screenshots)
   * [Spec](#spec)
   * [TODO](#todo)
   * [FIXED](#fixed)

INSTALL
=================

Packages
--------------

1. Fedora 24/25 x86:

```bash
dnf copr enable liloman/githubs
dnf install pomodoroTasks2
```

This will install all the timewarrior stuff and set the enviroment properly.

Manual
--------------

1. Taskwarrior dependencies (python based)

```bash
pip install tasklib --user (stable branch)
pip install tasklib future --user (other branches)

sudo dnf/apt-get/whatever install taskwarrior/task/whatever
task <<< yes
```

2. Timewarrior

```bash
sudo dnf/apt-get/whatever install build-essential cmake 
git clone --recursive https://git.tasktools.org/TM/timew.git timew.git
cd timew.git
git checkout master 
cmake -DCMAKE_BUILD_TYPE=release .
make
sudo make install
timew <<< yes
```

3. PomodoroTasks2

```bash
git clone https://github.com/liloman/pomodoroTasks2
git checkout stable
cd pomodoroTasks2/
./pomodoro-daemon.py
```

You can customize the working time and the break times (short and long), just exporting a few ENV variables in your ~/.bashrc.

```bash
#default pomodoro session (minutes)
export POMODORO_TIMEOUT=25
#default pomodoro short break (minutes)
export POMODORO_STIMEOUT=5
#default pomodoro long break (minutes)
export POMODORO_LTIMEOUT=15
```


So just launch the pomodoro-daemon.py and you are ready to go, feel free to add it in ~/.local/bin,autostart,systemd,... :)


Why do I need timewarrior?
=================

Because you the objective is track all your workflow and nothing better for that purpose than the newcomer and taskwarrior brother timewarrior. :)

If you wish to track every task of taskwarrior in timewarrior you need to:

1. Execute the extras/prepare_hooks.sh script:

 So it will be: 

 ```bash
 git clone https://github.com/liloman/pomodoroTasks2
 git checkout stable
 cd pomodoroTasks2/
 ./extras/prepare_hooks.sh install .
 ```

 And for now on: 
 a. Each time you start/stop a task it will be track
```