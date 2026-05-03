# clemux/task-matrix-bot

**URL:** https://github.com/clemux/task-matrix-bot  
**Stars:** 2  
**Language:** Python  
**Last push:** 2022-04-26  
**Archived:** No  
**Topics:** bot, matrix, matrix-nio, python, taskw, taskwarrior  

## Description

Matrix bot for taskwarrior

## Category

TUI / Interactive

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: GitHub is ww's primary issue source
- +1: Python — tooling language used in ww

## README excerpt

```
# taskbot

Proof of concept of a Matrix interface for taskwarrior.

Initial codebase derived from https://github.com/anoadragon453/nio-template (Apache 2.0 License)

Matrix connection uses [matrix-nio](https://github.com/poljar/matrix-nio).

Interacting with takswarrior is done through [taskw](https://github.com/ralphbean/taskw).

## Setup (without docker)

### Dependencies

`matrix-nio` requires [libolm](https://gitlab.matrix.org/matrix-org/olm) for end-to-end encryption.

On debian:

```
apt install python-dev libolm-dev
```

### Installing

Preferably in a venv:

```
pip install .
```

### Configuration

`cp sample.config.yaml config.yaml`

Edit the `matrix` section. You must set `matrix.user_id` and either:

 - set `matrix.password`
 - run the `taskbot login [config file path]` to get an access token, and set it in `matrix.user_token`

### Running

`taskbot run [config file path]`

## Setup using docker

### Build container image

`docker build -t taskbot:latest -f container/Dockerfile .`

### Running

 - Create a directory where the bot will
   - create and access the matrix-nio store for e2e keys
   - access the configuration file
 - Change `-u 1000` to use the UID you want the bot to run as (must have read/write access to the data directory)

`docker run -u 1000 -ti --rm -v ~/taskbot:/data localhost/taskbot run /data/config.container.yaml`

## Usage

Once the bot is running, you can send it direct messages.

Commands implemented:

 - list: returns pending tasks
 - add <text>
 - done <id>

# TODO

 - handle due dates in task list
 - do not return all tasks in list
 - schedule reminders for due dates

```