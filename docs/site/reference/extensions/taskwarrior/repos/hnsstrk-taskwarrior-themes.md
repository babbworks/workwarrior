# hnsstrk/taskwarrior-themes

**URL:** https://github.com/hnsstrk/taskwarrior-themes  
**Stars:** 0  
**Language:** —  
**Last push:** 2026-03-18  
**Archived:** No  
**Topics:** nord, taskwarrior, terminal, themes  

## Description

Nord color themes for Taskwarrior and taskwarrior-tui

## Category

TUI / Interactive

## Workwarrior Integration Rating

**Score:** 1  
**Rating:** ★★☆☆☆  Low  

### Scoring notes

- +1: GitHub is ww's primary issue source

## README excerpt

```
# Taskwarrior Themes

A collection of color themes for [Taskwarrior](https://taskwarrior.org/) and [taskwarrior-tui](https://kdheepak.com/taskwarrior-tui/) using the 256-color palette.

## Available Themes

| Theme | File | Description |
|-------|------|-------------|
| Nord Dark | `nord-dark.theme` | Dark variant of the [Nord](https://www.nordtheme.com) color palette |
| Nord Light | `nord-light.theme` | Light variant of the [Nord](https://www.nordtheme.com) color palette |

All themes include styles for taskwarrior-tui (selection, navbar, scrollbar, calendar, auto-completion). No additional configuration needed.

## Installation

1. Clone the repository or download the [ZIP archive](../../archive/refs/heads/main.zip):

```sh
git clone https://github.com/hnsstrk/taskwarrior-themes.git
```

2. Copy the desired theme file to your Taskwarrior data directory:

```sh
cp taskwarrior-themes/<theme-file>.theme ~/.task/
```

3. Add the following line to your `~/.taskrc`:

```
include ~/.task/<theme-file>.theme
```

4. Verify the theme is loaded:

```sh
task color
```

## Acknowledgments

- Nord color palette based on [Nord](https://www.nordtheme.com) by [Sven Greb](https://github.com/svengreb), licensed under the [MIT License](https://github.com/nordtheme/nord/blob/develop/license). This project is not affiliated with or endorsed by the Nord theme project.

## License

[MIT](LICENSE)

```