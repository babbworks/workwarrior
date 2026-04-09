# pauby/PSTodoWarrior

**URL:** https://github.com/pauby/PSTodoWarrior  
**Stars:** 10  
**Language:** PowerShell  
**Last push:** 2020-11-04  
**Archived:** No  
**Topics:** hacktoberfest, powershell, taskwarrior, todotxt  

## Description

This is a powershell CLI to the Todo.txt todo file format with some PowerShell like features and also taking inspiration from Taskwarrior.

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 4  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Urgency coefficients are a ww UDA focus area
- +1: Shell integration — ww is shell-first
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- -2: Mobile — outside ww scope

## README excerpt

```
# PSTodoWarrior

This is a powershell CLI to the [Todo.txt](http://todotxt.com/) todo file format with some PowerShell like features taking inspiration from [Taskwarrior](http://taskwarrior.org).

## Goal

The goal of this project is to create a command line interface to Todo.txt and add in some important Taskwarrior features such as prioritisation and ease of editing tasks.

## Configuration

```powershell
$TWSettings = [pscustomobject]@{
    TodoTaskPath        = $env:TODO_TASK
    TodoDonePath        = $env:TODO_DONE

    # Context and project name
    # name text of the Context property of the todo - usually 'Context' or 'List'
    NameContext         = 'List'
    # name text of the Project property of the todo - usually 'Project' or 'Tag'
    NameProject         = 'Tag'

    # Addons
    # addons to hide from output (note they are only hidden, not removed from the object)
    HideAddons          = @( 'uuid' )

    # Archives
    # if $true automatically archives completed todos to the TodoDoneFile, if $false they remain in the TodoTaskFile
    AutoArchive         = $true

    # Backups
    # backups are stored in the same folder as the TodoTaskFile
    BackupPath          = 'backups'
    # Number of backups to keep in the BackupFolder
    BackupDaysToKeep    = 7

    # Colours
    # Colours for each weights - any weight at or above the level will be that colour (up to the previous value).
    # This MUST be an ordered hashtable for it to work.
    # it's in the format 'weight number' = 'valid PowerShell colour'
    WeightForegroundColour = [ordered]@{
        20  = 'yellow'
        15  = 'red'
        1   = 'darkgreen'
    }

    # Colour for information messages
    ShowAlternatingColour   = 'DarkMagenta'
    InfoMsgsColour          = 'DarkCyan'
    DisableWriteHostUse     = $false

    # Weights
    # TODO: These needs explained
    WeightPriority    = 6.0
    WeightDueDate     = 12.0
    WeightHasProject  = 1.0
    WeightAge         = 2.0
    WeightProject     = @{                    # all projects / tags must be in lowercase
        next    = 15.0
        waiting = -3.0
        today   = 20.0
        someday = -15.0
    }

    # Views
    # TODO: These need explained
    TodoLimit   = 25
    View = @{
#            'default' = { param([Parameter(ValueFromPipeline=$true)][object[]]$todos, [hashtable]$config); begin { $output = @() } process { foreach ($todo in $todos) { if (($todo.Project -contains $config['ProjectDefault']) -or ($todo.Priority) -or ($todo.Project -contains $config['ProjectNextAction'])) { $output += $todo } } } end { $output | where { [string]::IsNullOrWhitespace($_.DoneDate) } | Sort-Object -Property @{e="Weight"; Descending=$true}, @{e="Line"; Descending=$False} | Select-Object -First $config['TodoLimit'] } };
#        default = { param([Parameter(ValueFromPipeline=$true)][object[]]$todos, [hashtable]$config); begin { $output = @() } process { foreach ($todo in $todos) { if (($todo.Context.Count -gt 0) -and ([string]::I
```