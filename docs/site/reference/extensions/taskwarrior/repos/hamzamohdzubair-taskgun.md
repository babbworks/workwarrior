# hamzamohdzubair/taskgun

**URL:** https://github.com/hamzamohdzubair/taskgun  
**Stars:** 2  
**Language:** Rust  
**Last push:** 2026-04-06  
**Archived:** No  
**Topics:** taskwarrior  

## Description

A gun for your friendly Taskwarrior. A Rust CLI that extends Taskwarrior with bulk task generation, modification and smart scheduling

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 9  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +3: UDAs — core to ww service model
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos

## README excerpt

```
# taskgun — A rusty gun for our [taskwarrior](https://taskwarrior.org)

A rusty gun for our [taskwarrior](https://taskwarrior.org) - bulk task generation, smart scheduling, and deadline-driven productivity.

## Why do you need taskgun?

Ever found a YouTube lecture series you want to complete but never quite finish? Started reading a technical book but lost momentum halfway through? **The problem is simple: no deadlines.**

Large sequential projects need structure and accountability. taskgun lets you break down big goals into smaller tasks with automatic deadlines, creating the external pressure you need to maintain momentum.

### Real-world Examples

#### 1. **YouTube Lecture Series** — 10 lectures, one per day

You discover a 10-part lecture series on Machine Learning. Schedule one lecture per day starting in 2 days:

```bash
taskgun create "ML Course" -p 10 -u Lecture --offset 2d --interval 1d
```

Creates:
- Lecture 1 (due in 2 days)
- Lecture 2 (due in 3 days)
- Lecture 3 (due in 4 days)
- ... and so on

#### 2. **Technical Book** — 12 chapters, one per week

Reading "Introduction to Algorithms" with 12 chapters. Schedule one chapter per week starting next week:

```bash
taskgun create CLRS -p 12 -u Chapter --offset 7d --interval 7d --skip weekend
```

Creates:
- Chapter 1 (due in 7 days, skips weekends)
- Chapter 2 (due in 14 days, skips weekends)
- Chapter 3 (due in 21 days, skips weekends)
- ... completing in 12 weeks

#### 3. **Book with Large Chapters** — Breaking down into sections

Reading "Design Patterns" with 3 chapters, but each chapter is too long. Chapter 1 has 3 sections, Chapter 2 has 4 sections, Chapter 3 has 2 sections. Schedule one section every 3 days:

```bash
taskgun create "Design Patterns" -p 3,4,2 -u Section --offset 3d --interval 3d
```

Creates:
- Section 1.1 (due in 3 days)
- Section 1.2 (due in 6 days)
- Section 1.3 (due in 9 days)
- Section 2.1 (due in 12 days)
- Section 2.2 (due in 15 days)
- Section 2.3 (due in 18 days)
- Section 2.4 (due in 21 days)
- Section 3.1 (due in 24 days)
- Section 3.2 (due in 27 days)

#### 4. **Quick Revision** — 30 lectures in 2 days

You have an exam in 2 days and need to revise 30 lectures quickly. Schedule one lecture every 2 hours, skipping bedtime:

```bash
taskgun create "Exam Prep" -p 30 -u Lecture --offset 2h --interval 2h --skip bedtime
```

Creates 30 lectures scheduled every 2 hours starting in 2 hours, automatically skipping 22:00-06:00 (bedtime). With ~16 waking hours per day, you'll complete all 30 lectures in approximately 2 days.

#### 5. **Rapid Practice** — 20 exercises with minute-level precision

You want to practice 20 short coding exercises, dedicating 30 minutes to each, with 15-minute breaks:

```bash
taskgun create "Coding Practice" -p 20 -u Exercise --offset 30m --interval 45min --skip bedtime
```

Creates 20 exercises scheduled every 45 minutes (30 min work + 15 min break), starting in 30 minutes, automatically skipping bedtime hours.

**Result:** What see
```