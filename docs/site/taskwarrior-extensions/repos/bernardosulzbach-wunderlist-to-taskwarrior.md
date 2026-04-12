# bernardosulzbach/wunderlist-to-taskwarrior

**URL:** https://github.com/bernardosulzbach/wunderlist-to-taskwarrior  
**Stars:** 3  
**Language:** Haskell  
**Last push:** 2017-05-27  
**Archived:** No  
**Topics:** taskwarrior, wunderlist  

## Description

Fetch your tasks from Wunderlist and add them to TaskWarrior

## Category

Sync

## Workwarrior Integration Rating

**Score:** 3  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: CLI-first matches ww ethos

## README excerpt

```
# Wunderlist to Taskwarrior

[![Build Status](https://travis-ci.org/mafagafogigante/wunderlist-to-taskwarrior.svg?branch=master)](https://travis-ci.org/mafagafogigante/wunderlist-to-taskwarrior)

A simple project that fetches your tasks from Wunderlist and inserts them into
TaskWarrior. Can be run by the operating system to keep Taskwarrior up-to-date.

## Configuration

Wunderlist lists starting with '!' are **never fetched for synchronization**.

All communication is done via HTTPS.

### Program directory

All the configuration and persistent data resides in the program directory.

```
$HOME/.wunderlist-to-taskwarrior/
```

### Wunderlist API

You must get an API key from Wunderlist before using this for your own stuff.

Create the `tokens.json` file in the program directory with the following contents:

```javascript
{
   "clientId": "....................",
   "clientSecret": "............................................................",
   "accessToken": "............................................................"
}
```

> You must obtain these values for yourself, the dots are just there to give you
> an idea of how long each field is.

## Installation

```sh
# Build and install the executable.
stack install

# Run the executable.
wunderlist-to-taskwarrior

# Add the executable to your crontab.
# Make sure to use the path for the executable in your machine.
(crontab -l; echo "* * * * * /home/mg/.local/bin/wunderlist-to-taskwarrior") | crontab
```

In practice, the program finishes in less than two seconds.

If you have hundreds of lists or many new tasks it may take longer.

```