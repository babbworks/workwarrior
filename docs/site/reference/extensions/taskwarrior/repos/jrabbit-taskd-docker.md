# jrabbit/taskd-docker

**URL:** https://github.com/jrabbit/taskd-docker  
**Stars:** 1  
**Language:** Shell  
**Last push:** 2021-05-07  
**Archived:** No  
**Topics:** docker-image, taskd, taskwarrior  

## Description

:hammer: :whale: docker images for taskd+debian debs+ next gnutls

## Category

CLI Tools

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos

## README excerpt

```
# taskd-docker


This image/dockerfile is based on debian & [debian's taskd](https://packages.debian.org/stretch/taskd). You won't need to build taskd from source if you modify this dockerfile. We also have a robust HEALTHCHECK thanks to https://github.com/jrabbit/taskd-client-go

# PKI

This is still all on you.

Mount your certs to /var/lib/taskd/pki

Use taskd's 1.2 sources for pki-scripts.
```