# fyusuf-a/dockerized-taskd

**URL:** https://github.com/fyusuf-a/dockerized-taskd  
**Stars:** 1  
**Language:** Shell  
**Last push:** 2021-10-01  
**Archived:** No  
**Topics:** devops, taskwarrior  

## Description

A basic taskd server

## Category

API Libraries

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos

## README excerpt

```
# taskd-dockerized

taskd-dockerized is a containerized [Taskwarrior](https:/taskwarrior.org/) server based upon [ogarcia](https://github.com/ogarcia/docker-taskd)'s and [x4121](https://hub.docker.com/x4121/taskd)'s versions. It brings such niceness as the ability to log on stdout.

## Building

```
docker build -t taskd . --build-arg ALPINE_VERSION=latest
```

## Usage

If no config and public key infrastructure are present in the persistent directory of your choosing, the executable creates certificates and keys in the pki subdirectory. In this case, it is mandatory to provide the CERT\_CN environment variable.

If you intend to use those, you should set up your client according to the section 'Client configuration'.

Attention, the container will use the host's network. I was unable to make the binding of taskd's socket and the TLS handshake to work.

```
docker run -d --name taskd \
	--network=host
	-v path_to_persistent_host_dir:/var/taskd \
	-e CERT_CN="domain_name_or_ip" \
	[-e CERT_ORGANIZATION="Evil Corp"] \
	[-e CERT_COUNTRY="USA"] \
	[-e CERT_STATE="NY"] \
	[-e CERT_LOCALITY="New York City"] \
	taskd
```

## Client configuration

Run on your server:

```
docker exec taskd add_user your_name [your_organization]
```

```