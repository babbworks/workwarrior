# DCsunset/taskwarrior-webui

**URL:** https://github.com/DCsunset/taskwarrior-webui  
**Stars:** 251  
**Language:** Vue  
**Last push:** 2024-12-31  
**Archived:** No  
**Topics:** docker, self-hosted, taskwarrior, web-ui  

## Description

Self-hosted Responsive Web UI for Taskwarrior based on Vue.js and Koa.js

## Category

Sync

## Workwarrior Integration Rating

**Score:** 4  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: Shell integration — ww is shell-first
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- -1: Taskserver — ww doesn't use sync server

## README excerpt

```
# Taskwarrior-webui

[![Docker Image Size](https://badgen.net/docker/size/dcsunset/taskwarrior-webui)](https://hub.docker.com/r/dcsunset/taskwarrior-webui)

Responsive Web UI for Taskwarrior based on Vue.js and Koa.js.

## Screenshots

![Screenshot 1](./screenshots/Screenshot1.png)

![Screenshot 2](./screenshots/Screenshot2.png)

## Features

* Responsive layouts
* Material Design UI
* PWA support
* Easy to deploy (using Docker)
* Support for multiple types of tasks
* Support for light and dark themes
* Sync with a taskserver


## Deployment

### Using docker (recommended)

First pull the docker image:
(Note that taskwarrior v2 and v3 are not compatible with each other.
Choose based on your current data version.)
```sh
# For taskwarrior 3
docker pull dcsunset/taskwarrior-webui:3
# For taskwarrior 2
docker pull dcsunset/taskwarrior-webui
```

Then run it with the command:
```sh
docker run -d -p 8080:80 --name taskwarrior-webui \
	-v $HOME/.taskrc:/.taskrc -v $HOME/.task:/.task \
	dcsunset/taskwarrior-webui:3
```

Finally, open `http://127.0.0.1:8080` with your browser (replace `127.0.0.1` with your ip address if running on a remote server).

If you want to use already existing taskwarrior data in another container, use `:z` or `:Z` labels. See
[here](https://stackoverflow.com/questions/35218194/what-is-z-flag-in-docker-containers-volumes-from-option/35222815#35222815).
```
# e.g.
docker run -d -p 8080:80 --name taskwarrior-webui \
	-v $HOME/.taskrc:/.taskrc:z -v $HOME/.task:/.task:z \
	dcsunset/taskwarrior-webui
```

If your configuration file contains absolute path to your home directory like `/home/xxx/ca.cert.pem`,
you may want to mount files to the same paths in the container using the following command:

```sh
docker run -d -p 8080:80 --name taskwarrior-webui \
	-e TASKRC=$HOME/.taskrc -e TASKDATA=$HOME/.task \
	-v $HOME/.taskrc:$HOME/.taskrc -v $HOME/.task:$HOME/.task \
	dcsunset/taskwarrior-webui
```

## Configurations

The following environment variables may be set:
 * `TASKRC` - the location of the `.taskrc` file, `/.taskrc` by default when run in _production_ mode
 * `TASKDATA` - the location of the `.task` directory, `/.task` by default when run in _production_ mode

Remember to mount your files to **the corresponding locations** when you set `TASKRC` or `TASKDATA` to a different value.

### Manually deploy

First build the frontend:

```
cd frontend
npm install
npm run build
npm run export
```

Then build and start the backend:

```
cd backend
npm install
npm run build
npm start
```

Then install nginx or other web servers
to server frontend and proxy requests to backend
(you can refer to `nginx/nginx.conf`).

## Development

First start the server at backend:

```
cd backend
npm install
npm run dev
```

Then start the dev server at frontend:

```
cd frontend
npm install
npm run dev
```

Then the frontend will listen at port 8080.

## Contributing

Contributions are very welcome!
Please create or comment on an issue to discuss your ide
```