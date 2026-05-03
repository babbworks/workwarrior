# Gun — Bulk Task Series Generator

Extension weapon wrapping [taskgun](https://github.com/hamzamohdzubair/taskgun)
by hamzamohdzubair · MIT License · Rust

## Install

```
ww gun install    # uses cargo or brew
```

## Usage

```
ww gun create <project> -p <parts> -u <unit> --offset <dur> --interval <dur>
ww gun create ML_Course -p 10 -u Lecture --offset 2d --interval 1d
```

## Limitations

- Project names with spaces are split by TaskWarrior — use underscores
- No --dry-run (not implemented upstream)
- See system/audits/gun-limitations.md for full analysis

## Task Card

TASK-EXT-GUN-001 (complete)
