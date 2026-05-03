# caomem/financewarrior

**URL:** https://github.com/caomem/financewarrior  
**Stars:** 0  
**Language:** Julia  
**Last push:** 2026-01-04  
**Archived:** No  
**Topics:** finance, finance-management, taskwarrior  

## Description

A CLI tool for personal finance management, inspired by taskwarrior style and by the plain-text accounting ecosystem.

## Category

Sync

## Workwarrior Integration Rating

**Score:** 7  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +2: Sync capability relevant to ww profile isolation
- +1: Reporting is a ww surface area
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration

## README excerpt

```
# financewarrior

`financewarrior` is a Julia CLI tool for personal finance management, inspired by [taskwarrior](https://taskwarrior.org)-style syntax and by the *plain-text accounting* ecosystem.

The goal of the project is to allow users to describe their financial life in a **declarative, versionable, and auditable** way, using only plain-text files (TOML) and version control (git), with a strong focus on:

- cash-flow predictability (real balance vs. projected balance)
- recurring and expected expenses
- installments and debts
- investments
- clear and reproducible reports

The project is written in **Julia** and assumes that financial data belongs to the user and should be readable, editable, and easily synchronized across devices.


## Project principles

- CLI-first
- Plain text as the source of truth
- Git friendly
- No database lock-in
- Fully functional offline (external APIs are optional)
- Clear separation between:
  - cash flow
  - net worth
  - projections


## Installation

Requirements:
- Julia >= 1.10

It is possible to use the `finance` script inside of the main repository without building a binary, with
```sh
./finance --help
```
 but it is really recommended to build for regular use.

To build and install the `finance` binary, clone this repository and run:
```sh
make install
```
The first build may take a few minutes as it compiles a native executable (something slow in Julia..). The resulting binary is self-contained but may be relatively large due to Julia's static compilation.

## Basic usage

Add an expense:
```sh
finance add expense candy 10
```

Add a recurring bill:
```sh
finance add bill rent 1200 recur:monthly
```

List all events:
```sh
finance list
```

Show current balance:
```sh
finance balance
```

Mark an event as completed:
```sh
finance complete rent
```

Cancel an event:
```sh
finance cancel <id>
```



## TODO

- [ ] Categorization, tags, notes, CSV import
- [ ] Installments and debt models
- [ ] Investments (stocks, ETFs, etc.)
- [ ] Reports and export (CSV, charts)
- [ ] Automate versioning with git hooks
- [ ] Redo everything in C or Rust for performance

Extensions and future features:
- [ ] Investment tracking and reporting
- [ ] Advanced reports (monthly summary, breakdowns, evolution)
- [ ] Data schema versioning

## License

This project is licensed under the GNU General Public License v3. See `LICENSE` for details.
```