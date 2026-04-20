# rucas/taskd

**URL:** https://github.com/rucas/taskd  
**Stars:** 4  
**Language:** Shell  
**Last push:** 2018-07-11  
**Archived:** No  
**Topics:** cli, container, docker, task, taskwarrior  

## Description

taskwarrior docker container

## Category

Sync

## Workwarrior Integration Rating

**Score:** 5  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos

## README excerpt

```
<h1 align="center">taskd</h1>

> A containerized taskwarrior server

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## Table of Contents

- [Install](#install)
- [Usage](#usage)
  - [Start a Taskwarrior Server](#start-a-taskwarrior-server)
  - [Find New User Key](#find-new-user-key)
  - [Sync with Taskwarrior Client](#sync-with-taskwarrior-client)
- [Contributing](#contributing)
- [FAQ](#faq)
  - [Who?](#who)
  - [What is Taskwarrior?](#what-is-taskwarrior)
  - [When?](#when)
  - [What is bootstrap.sh?](#what-is-bootstrapsh)
  - [Why?](#why)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Install

```sh
$ docker pull rucas/taskd
```

## Usage

### Start a Taskwarrior Server

```sh
$ docker run -d -p 53589:53589 \
    -v $PWD/taskd:/var/taskd \
    -e FIRST_NAME=rucas \
    -e LAST_NAME=mania \
    -e ORG=Public \
    -e CERT_CN=localhost \
    -e CERT_ORGANIZATION=rucas \
    -e CERT_COUNTRY=US \
    -e CERT_STATE=Oregon \
    -e CERT_LOCALITY=Portland \
    rucas/taskd
```

### Find New User Key

```sh
$ tail taskd/pki/stdout.txt

...
New user key: 004e3fbd-d501-4c55-ab42-35280ccd7229
Created user 'rucas mania' for organization 'Public'

```

### Sync with Taskwarrior Client

```sh
$ ./bootstrap.sh \
    --ca taskd/pki/ca.cert.pem \
    --key taskd/pki/rucas_mania.key.pem \
    --cert taskd/pki/rucas_mania.cert.pem \
    --host localhost:53589 \
    --id 004e3fbd-d501-4c55-ab42-35280ccd7229 \
    --firstname rucas \
    --lastname mania \
    client
```

## Contributing

:wave: :point_right: Check out the [Contributing](CONTRIBUTING.md) doc to get you started.

## FAQ

### Who?

Checkout the [Maintainers](MAINTAINERS.md) doc to see who has contributed.

### What is Taskwarrior?

[Taskwarrior](https://taskwarrior.org/) is the ultimate TODO app from the command line. It's simple, fast, and organized, get shit done and move on.

### When?

Since commit [5c73c9](https://github.com/rucas/taskd/commit/5c73c9d0efe5a9d870df33771e5664c8f02b2953)

### What is bootstrap.sh?

A simple bash script to save time and automates configuring the client. For more help:

```sh
$ ./bootstrap -h 
```

### Why?

Why not?

## License

MIT © rucas

```