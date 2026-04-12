# Zebradil/docker-services

**URL:** https://github.com/Zebradil/docker-services  
**Stars:** 0  
**Language:** —  
**Last push:** 2024-05-01  
**Archived:** Yes  
**Topics:** docker, taskd, taskwarrior  

## Description

Personal collection of docker service files

## Category

Sync

## Workwarrior Integration Rating

**Score:** 3  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: GitHub is ww's primary issue source

## README excerpt

```
Docker services collection
===

Taskd
---

**Containers**:
 - [ogarcia/taskd](https://github.com/ogarcia/docker-taskd)

**Volumes**:
 - `/var/taskd`

**Ports**:
 - 53589

**Run**: `docker stack deploy -c taskd.yml taskd`

Syncthing
---

**Containers**:
 - [zebradil/syncthing](https://github.com/zebradil/syncthing)

**Volumes**:
 - `data` (may change through `SYNCTHING_DATA_DIR`)
 - `config` (may change through `SYNCTHING_CONFIG_DIR`)

**Ports**:
 - 8384
 - 22000
 - 21027/udp

**Run**: `SYNCTHING_DATA_DIR=/var/sync docker stack deploy -c syncthing.yml syncthing`

```