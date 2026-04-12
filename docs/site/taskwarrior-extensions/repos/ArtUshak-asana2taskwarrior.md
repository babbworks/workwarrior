# ArtUshak/asana2taskwarrior

**URL:** https://github.com/ArtUshak/asana2taskwarrior  
**Stars:** 0  
**Language:** Rust  
**Last push:** 2024-08-03  
**Archived:** No  
**Topics:** asana, asana-api, converter, taskwarrior  

## Description

Script to convert JSON with tasks exported from Asana to Taskwarrior JSON

## Category

Import / Export

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration

## README excerpt

```
# Asana-to-Taskwarrior task converter

This is script to convert exported tasks from [Asana API](https://developers.asana.com/docs/get-tasks-from-a-project) JSON to [Taskwarrior import](https://github.com/GothenburgBitFactory/taskwarrior/blob/develop/doc/devel/rfcs/task.md) JSON.

## Usage

1. Export tasks from Asana project using API and get JSON file `input.json`.
2. Convert tasks: `asana2taskwarrior --input-asana-file input.json --output-taskwarrior-file output.json`
3. Import tasks to Taskwarrior: `task import output.json`

## Options

* `--append-sections-to-project` — add section names to output project names, for example, if task is in section **Labs** of project **Functional programming**, then output project name will be **Functional programming: Labs**
* `--children-to-dependencies` — mark parent tasks as dependencies of their children
* `--section-priority-mapping-file FILE` — JSON file with section-to-priority mapping (see below)

## Section-to-priority mapping file

Section-to-priority mapping can be used to determine output task priority from input section name.

Example:

```json
{
    "default_mapping": "L",
    "mapping": {
        "Квартира": "H",
        "Здоровье": "H",
        "Поиск работы": "H",
        "Фитнес": "M",
        "Компьютер": "M",
        "Книги (учебная литература)": "M",
        "Учёба: математика": "M",
        "Учёба: программирование": "M",
        "Книги (художественная литература)": "L",
        "Игры": "L",
        "Кино": "L",
        "Прочее": "M"
    }
}
```

```