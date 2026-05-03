# ogarcia/trellowarrior

**URL:** https://github.com/ogarcia/trellowarrior  
**Stars:** 106  
**Language:** Python  
**Last push:** 2024-06-12  
**Archived:** No  
**Topics:** sync, task, taskwarrior, todo, trello  

## Description

Tool to sync Taskwarrior projects with Trello boards

## Category

Sync

## Workwarrior Integration Rating

**Score:** 8  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +3: UDAs — core to ww service model
- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww

## README excerpt

```
# TrelloWarrior

Tool to sync Taskwarrior projects with Trello boards.

## Requirements

### In Taskwarrior

First for all you need configure some UDAs in Taskwarrior to store some
Trello data. This is very, very, very important. If you dont have the UDAs
configured before run TrelloWarrior you'll destroy your Taskwarrior tasks
data.

To set UDAs in Taskwarrior simply edit `.taskrc` and add the following
lines.

```
# UDAs
uda.trelloid.type=string
uda.trelloid.label=Trello ID
uda.trellolistname.type=string
uda.trellolistname.label=Trello List Name
```

The first UDA `trelloid` is used to store the Trello Card ID and establish
an equivalence between Trello Cards and Taskwarrior Tasks. Note that you
never, never, never, never, (period), should edit this field.

The second UDA `trellolistname` is used to determine the Trello List where
the Card/Task is stored. You can edit this field without problems to move
the task to another list.

### For TrelloWarrior

#### Prepare the environment

##### In Arch Linux

TrelloWarrior is packaged in
[AUR](https://aur.archlinux.org/packages/trellowarrior), to obtain it simply
use your AUR helper. For example with [yay](https://github.com/jguer/yay):

```
yay -S trellowarrior
```

Or if you prefer a fully binary package you can configure [Connectical Arch
Linux repository](https://repo.connectical.com/).

##### The easy way

Simply create a Python 3 virtualenv and install [via
pip](https://pypi.org/project/trellowarrior/):

```
python3 -m venv trw
. trw/bin/activate
python3 -m pip install trellowarrior
```

##### By hand

For run TrelloWarrior you need to install
[tasklib](https://github.com/robgolding63/tasklib) and
[py-trello](https://github.com/sarumont/py-trello). TrelloWarrior uses these
Python helpers to comunicate with Taskwarrior and Trello.

You can use your package system to install it, but the best way is to use
a Python 3 virtualenv:

```sh
python3 -m venv trw
. trw/bin/activate
python3 -m pip install tasklib
python3 -m pip install py-trello
```

#### Get the keys

TrelloWarrior access to Trello via API. You need generate an access token
for it.

First go to: https://trello.com/app-key to get your API Key and API Secret.

Then call TrelloWarrior with the authenticate command:

```sh
trellowarrior auth --api-key your_api_key --api-key-secret your_api_secret --expiration 30days --name TrelloWarrior
```

Note: `--expiration` and `--name` are optional, they are set by default to
`30days` and `TrelloWarrior` respectively.

You can set the `TRELLO_EXPIRATION` to `1hour`, `1day`, `30days`,
`never`. We recomend use `30days` for tests and `never` for daily use.

This return some like this.

```
Request Token:
    - oauth_token        = 1c5ad394834dde42a7655437ab3e0060
    - oauth_token_secret = dffc3a62622ef450028f685406bceacc

Go to the following link in your browser:
https://trello.com/1/OAuthAuthorizeToken?oauth_token=1c5ad334134dde46a8659437ab3e0069&scope=read,write&expiration=30days&name=trellowarrior
Have 
```