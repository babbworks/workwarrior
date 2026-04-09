# enricoschumann/taskwarrior.utils

**URL:** https://github.com/enricoschumann/taskwarrior.utils  
**Stars:** 0  
**Language:** R  
**Last push:** 2024-11-05  
**Archived:** No  
**Topics:** r, taskwarrior  

## Description

Utilities for Handling Taskwarrior Data

## Category

Import / Export

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell integration — ww is shell-first
- +1: Import/export useful for profile migration

## README excerpt

```
* taskwarrior.utils

Utilities for handling Taskwarrior
(https://taskwarrior.org/) data: parsing export files,
retrieving tags and projects.

** Installing the package

   The latest build of the package is always available from
   [[https://enricoschumann.net/R/packages/taskwarrior.utils/]].

   To install the package from within an R session, type:
#+BEGIN_SRC R :eval never :export code
install.packages("taskwarrior.utils",  ## development version
                 repos = c("https://enricoschumann.net/R",
                           getOption("repos")))
#+END_SRC


** Examples

#+BEGIN_SRC R :results none :exports code :session **R**
library("taskwarrior.utils")

file <- "<path to export>/tasks.json"  ## in a shell: `task export > tasks.json`
tasks <- read_tasks(file)
tasks <- as.data.frame(tasks)
str(tasks)

tasks <- tasks[!tasks$status %in% c("completed", "deleted"),]
#+END_SRC

```