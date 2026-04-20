# ttschnz/task

**URL:** https://github.com/ttschnz/task  
**Stars:** 0  
**Language:** —  
**Last push:** 2021-12-14  
**Archived:** No  
**Topics:** subsystem, taskwarrior, windows  

## Description

a bridge for taskwarrior inside ubuntu subsystem

## Category

NLP / AI

## Workwarrior Integration Rating

**Score:** 1  
**Rating:** ★★☆☆☆  Low  

### Scoring notes

- +1: GitHub is ww's primary issue source

## README excerpt

```
# task-bridge
a simple bridge for taskwarrior to ubuntu subsystem on windows.

## installation 
### a) activate subsystem and install taskwarrior
1. install ubuntu:
https://www.microsoft.com/store/productId/9NBLGGH4MSV6 follow its instructions in the description
2. install taskwarrior: start the ubuntu app, run `sudo apt update && sudo apt install taskwarrior`
3. test taskwarrior `task` and configure as you wish
### b) install this repo
```
npm i -g git+https://github.com/ttschnz/task.git#master
```
for some reason it opens the .js file in an editor instead of running it via node, so you need to change some things after the installation:
1. edit `%appdata%/npm/task.cmd` to:
```bat
@ECHO off
SETLOCAL
CALL :find_dp0

IF EXIST "%dp0%\node.exe" (
  SET "_prog=%dp0%\node.exe"
) ELSE (
  SET "_prog=node"
  SET PATHEXT=%PATHEXT:;.JS;=;%
)

"%_prog%"  "%dp0%\node_modules\task\bin\main.js" %*
ENDLOCAL
EXIT /b %errorlevel%
:find_dp0
SET dp0=%~dp0
EXIT /b
```
2. edit `%appdata%/npm/task` to 
```sh
#!/bin/sh
basedir=$(dirname "$(echo "$0" | sed -e 's,\\,/,g')")

case `uname` in
    *CYGWIN*|*MINGW*|*MSYS*) basedir=`cygpath -w "$basedir"`;;
esac

if [ -x "$basedir/node" ]; then
  "$basedir/node"  "$basedir/node_modules/task/bin/main.js" "$@"
  ret=$?
else 
  node  "$basedir/node_modules/task/bin/main.js" "$@"
  ret=$?
fi
exit $ret
```
3. edit `%appdata%/npm/task.ps1` to
```ps1
#!/usr/bin/env pwsh
$basedir=Split-Path $MyInvocation.MyCommand.Definition -Parent

$exe=""
if ($PSVersionTable.PSVersion -lt "6.0" -or $IsWindows) {
  # Fix case when both the Windows and Linux builds of Node
  # are installed in the same directory
  $exe=".exe"
}
if (Test-Path "$basedir/node$exe") {
  & "$basedir/node$exe"  "$basedir/node_modules/task/bin/main.js" $args
  $ret=$LASTEXITCODE
} else {
  & "node$exe"  "$basedir/node_modules/task/bin/main.js" $args
  $ret=$LASTEXITCODE
}
exit $ret
```

## usage
1. open cmd
2. use task command as if you were in the ubuntu subsystem

```