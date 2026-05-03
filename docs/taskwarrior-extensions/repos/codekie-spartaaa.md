# codekie/spartaaa

**URL:** https://github.com/codekie/spartaaa  
**Stars:** 1  
**Language:** JavaScript  
**Last push:** 2026-02-13  
**Archived:** No  
**Topics:** bulma, es6, eslint, expressjs, immutablejs, javascript, jest, react, redux, rxjs, rxjs6, sass, solarized, solarized-dark-theme, taskwarrior, webpack, websockets  

## Description

Web-app for taskwarrior

## Category

Import / Export

## Workwarrior Integration Rating

**Score:** 3  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration

## README excerpt

```
# Spartaaa

[![Build Status](https://travis-ci.com/codekie/spartaaa.svg?branch=master)](https://travis-ci.com/codekie/spartaaa)
[![Coverage Status](https://coveralls.io/repos/github/codekie/spartaaa/badge.svg?branch=master)](https://coveralls.io/github/codekie/spartaaa?branch=master) [![Greenkeeper badge](https://badges.greenkeeper.io/codekie/spartaaa.svg)](https://greenkeeper.io/)

`Spartaaa` is a Web-frontend for taskwarrior.

**CAUTION: USE AT OWN RISK!** If you use this app, make sure that you made a backup of the Taskwarrior-data, first.


# Requirements

- `Taskwarrior` pre-installed
- NodeJS `10`
- macOS

If the app is not run on a `macOS`, the path to the Taskwarrior-data, has to be set as env-variable
(`SPARTAAA_PATH_TASKWARRIOR_DATA`).


# How to run the app

The dependencies, for the server, have to be installed first. To do this, run

```
yarn install
```

To start the server, execute

```
yarn start
```

The web-app will be accessible at http://localhost:3010


# How does it work

While the web-app itself, is served from an express-webserver, the communication between frontend and backend happens
via Websockets.

This app does not access the Taskwarrior-data directly. The access happens through the Taskwarrior-CLI.

There is a watch on the directory, which contains the Taskwarrior-data (preconfigured for `macOS`, which is `~/.task`)
and as soon as any file within that directory is modified, the tasks will be exported and pushed to the client.


# Development

## How to start the tests

```
yarn test
```


## Start the server in dev mode

```
yarn run start-dev
```

This will start the express- and websocket-server, additionally to a Webpack-dev-server. There are file-watches on
the server-components, which will restart the server automatically, as well as file-watches on the frontend-code, which
will recompile the frontend and hot-reload it in the browser.

The Webpack-dev-server, which will serve the hot-reloadable frontend, will be accessible at http://localhost:8080


## Motivation

The initial motivation, was to create a React-boilerplate for future projects. Taskwarrior was just a proof of concept
to build upon. However, it turned to out to become useful and so the development went on.

## Used technologies / frameworks

- Yarn
- React
- Redux
- immutable.js
- RxJS
- SASS
- Bulma
- Fontawesome
- Webpack
- Jest
- Babel
- Express
- lodash
- moment.js
- winston
- ws

```