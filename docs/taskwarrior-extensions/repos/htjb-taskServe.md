# htjb/taskServe

**URL:** https://github.com/htjb/taskServe  
**Stars:** 0  
**Language:** Python  
**Last push:** 2026-01-26  
**Archived:** No  
**Topics:** task-management, tasks, taskwarrior  

## Description

Minimalist web based interface for taskwarrior.

## Category

TUI / Interactive

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell scripting — matches ww stack
- +1: CLI-first matches ww ethos

## README excerpt

```
# taskweb

Need to save 

```
[Unit]
Description=Minimal Taskwarrior Web Server
After=network.target

[Service]
User=harry
WorkingDirectory=/home/harry/taskweb
# Activate venv and run CLI
ExecStart=/bin/bash -c 'source /home/harry/taskweb/envtaskserve/      bin/activate && exec taskserve'
Restart=always
Environment=PATH=/home/harry/taskweb/envtaskserve/bin:/usr/bin:/      bin

[Install]
WantedBy=multi-user.target
```

in 

`/etc/systemd/system/todo.service`

and run 

```
sudo systemctl daemon-reload
sudo systemctl enable todo.service
sudo systemctl start todo.service
```

on initial set up or 

```
sudo systemctl restart todo.service
```

when I make changes.

## Licence

Released under a non-commercial, MIT-style license. See LICENSE for details.

```