# djotaku/taskwarrior_web

**URL:** https://github.com/djotaku/taskwarrior_web  
**Stars:** 4  
**Language:** Python  
**Last push:** 2026-04-07  
**Archived:** No  
**Topics:** taskwarrior, taskwarrior2, taskwarrior3  

## Description

To handle the closure of Inthe.am and FreeCinc.

## Category

Sync

## Workwarrior Integration Rating

**Score:** 5  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww
- -2: GUI/browser — not ww-native
- -1: Taskserver — ww doesn't use sync server

## README excerpt

```
# taskwarrior_web

![screenshot](https://github.com/djotaku/taskwarrior_web/blob/main/taskwarrior_web/screenshots/Taskwarrior_web.png)

## Why this repo?

Taskwarrior_web is meant for use by one user to be able to access, create, modify, and complete their tasks from the web.

## Instructions for taskwarrior_web using taskwarrior 3.x

### Usage

- Need taskwarrior 3.x installed on your personal computer if you're syncing with the web interface.
- Need the [taskchampion sync-server](https://github.com/GothenburgBitFactory/taskchampion-sync-server)
  - Currently the easiest thing is to clone the repo, build the conatainer (with Docker or Buildah), and then run the server.  

Example, building with buildah:

```bash
buildah build \
  -t taskchampion-sync-server \
  -f Dockerfile-sqlite
# note: at the time I write this, I had to change the dockerfile to point at Rush 1.88
```
Running with podman:

```bash
podman run -dt --name taskchampion -p 8080:8080 -v taskchampion_sync:/var/lib/taskchampion-sync-server/data localhost/taskchampion-sync-server
```
On the computer with your taskwarrior instance, run:

```bash
task config sync.encryption_secret <encryption_secret>
```
According to the official docs pwgen will give a good value.

Then you need to run

```bash
task config sync.server.url               <url>
task config sync.server.client_id         <client_id>
```
The url must have http or https. If you are not running at port 80 or 443, specify the port. Client ID must be a valid UUID.

- use create_new_password_hash() function in utility_functions.py
- need a file called secrets_config with:
- 
```json
{
  "SECRET_KEY":"some random letters",
  "user": {"username_you_want": 
  {"password": "output of create_new_password_hash()"}}
}
```
If you wish to run this web app as a container, the script I use to create the container with buildah is create_container.sh. This is the one I push to Docker Hub. (In the future I may consider pushing to the github container registry if that doesn't cost money)

## Instructions for taskwarrior_web using taskwarrior 2.x

The final release for taskwarrior 2.x is taskwarrior_web v1.1.

###
Usage

- Need taskwarrior installed
- use create_new_password_hash() function in utility_functions.py
- need a file called secrets_config with:
- 
```json
{
  "SECRET_KEY":"some random letters",
  "user": {"username_you_want": 
  {"password": "output of create_new_password_hash()"}}
}
```


I used the taskd container at https://github.com/ogarcia/docker-taskd which I have forked just in case. 

You might set it up like this:

```shell
#! /bin/bash

podman run -d \
          --name=taskd \
            -e CERT_BITS=4096 \
              -e CERT_EXPIRATION_DAYS=365 \
                -e CERT_ORGANIZATION="Your Name" \
                  -e CERT_CN=yoururl.com \
                    -e CERT_COUNTRY=US \
                      -e CERT_STATE="YourState" \
                        -e CERT_LOCALITY="YourCity" \
                          -p 53589:5358
```