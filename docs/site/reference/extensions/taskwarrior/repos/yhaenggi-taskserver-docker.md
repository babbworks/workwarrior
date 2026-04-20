# yhaenggi/taskserver-docker

**URL:** https://github.com/yhaenggi/taskserver-docker  
**Stars:** 0  
**Language:** Dockerfile  
**Last push:** 2020-01-18  
**Archived:** No  
**Topics:** docker, docker-multiarch, k8s, kubernetes, multiarch, taskd, taskserver, taskwarrior  

## Description

multiarch docker container with taskserver/taskd

## Category

Widgets & Editor Integrations

## Workwarrior Integration Rating

**Score:** -1  
**Rating:** ★☆☆☆☆  Unlikely  

### Scoring notes

- -1: Taskserver — ww doesn't use sync server

## README excerpt

```
These images have been built and tested on docker i386, amd64, arm32v7 and arm64v8. This is a multi platform image.

## Usage ##

    docker run -d -p 53589:53589/tcp yhaenggi/taskserver:v1.1.0

## Build ##

If you want to build the images yourself, you'll have to adapt the registry file, copy qemu and enable binfmt.

    cp /usr/bin/qemu-{i386,x86_64,arm,aarch64}-static .

In case you want other arches, just add them in the ARCHES files and copy the corresponding qemu user static binary. If you want support for another archtitecture, open an issue.

On some distros, you have to manually enable binfmt support:

    sudo service binfmt-support restart

You can verify if it worked with this (should show enabled):

    update-binfmts --display|grep -E "arm|aarch"

## Tags ##
   * v1.1.0

```