# nya1/scatola

**URL:** https://github.com/nya1/scatola  
**Stars:** 0  
**Language:** TypeScript  
**Last push:** 2022-10-26  
**Archived:** No  
**Topics:** remix-run, task-manager, taskwarrior, todo, todoist  

## Description

Web-based task manager inspired by taskwarrior

## Category

CLI Tools

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source

## README excerpt

```

# Scatola

Web-based task manager inspired by taskwarrior.


- Run via docker

```bash
docker run -d --name scatola -e SESSION_SECRET="super-secret-1" -e ENCRYPTION_KEY="super-secret-2" -v $PWD/scatola.db:/data/sqlite.db -p 8080:8080 ghcr.io/nya1/scatola:latest
```

Scatola will be available on localhost:8080

## Local development

All types of contributions are encouraged and valued, please refer to the [CONTRIBUTING guidelines](./CONTRIBUTING.md).

1. install dependencies, because of Remix issues with other package managers **npm** is mandatory

```sh
npm i
```

2. Setup prisma and SQLite

```sh
npm run setup
```

3. Start dev server:

```sh
npm run dev
```

This starts your app in development mode, rebuilding assets on file changes.



## Credits

- Based on [Remix Indie Stack](https://github.com/remix-run/indie-stack/)
- UI Components from [Mantine](https://github.com/mantinedev/mantine/)

```