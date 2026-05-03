# taskvanguard/taskvanguard

**URL:** https://github.com/taskvanguard/taskvanguard  
**Stars:** 40  
**Language:** Go  
**Last push:** 2026-02-07  
**Archived:** No  
**Topics:** ai, cli, golang, llm, taskwarrior  

## Description

TaskVanguard - LLM / AI Wrapper for TaskWarrior via API (OpenAI, Deepseek etc.)

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 11  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Urgency coefficients are a ww UDA focus area
- +3: UDAs — core to ww service model
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration

## README excerpt

```
<a id="readme-top"></a>

<!-- <div align="center"> -->
<!-- [![Contributors][contributors-shield]][contributors-url] -->
<!-- [![Forks][forks-shield]][forks-url] -->
<!-- [![Stargazers][stars-shield]][stars-url] -->
<!-- [![Issues][issues-shield]][issues-url] -->
<!-- [![Task][license-shield]][license-url] -->
<!-- [![LinkedIn][linkedin-shield]][linkedin-url] -->
<!-- </div> -->

<!-- PROJECT LOGO -->
<div align="center">
  <a href="https://github.com/taskvanguard/taskvanguard">
    <img src="docs/images/logo.png" alt="Logo" width="200" height="200">
  </a>

<h3 align="center">Task Vanguard</h3>

<p align="center">

**TaskVanguard** is a lightweight, fast, highly configurable CLI wrapper for [TaskWarrior](https://taskwarrior.org/), written in Go. It brings AI-powered suggestions, smart tagging, goal management and cognitive support using any OpenAI-compatible LLM API.

<br>
<a href="https://coff.ee/xarcdev">Donate</a>
&middot;
<a href="https://github.com/taskvanguard/taskvanguard/issues/new?labels=bug&template=bug-report---.md">Report Bug</a>
&middot;
<a href="https://github.com/taskvanguard/taskvanguard/issues/new?labels=enhancement&template=feature-request---.md">Request Feature</a>
  </p>

<!-- <div align="center"> -->
[![Contributors][contributors-shield]][contributors-url]
<!-- [![Forks][forks-shield]][forks-url] -->
[![Go][Go-shield]][Go.dev]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![Task][license-shield]][license-url]
<!-- [![LinkedIn][linkedin-shield]][linkedin-url] -->
<!-- </div> -->

</div>


<!-- ABOUT THE PROJECT -->
## What is TaskVanguard?

Use `vanguard add <task>` just like `taskwarrior add <task>`. TaskVanguard creates the task, then suggests improvements using an LLM (OpenAI, Deepseek, etc).

<div align="center">

![Product Name Screen Shot][product-screenshot]

</div>

### Features

✨ **Add:** AI-Enhanced Task Creation: Improves task titles, tags, project and annotations.<br>
🎯 **Spot:** Do the Right Thing Next: Identifies the most impactful next task. Based on urgency, context, mood etc.<br>
🧭 **Guidance:** Generate concrete, step-by-step roadmaps to achieve goals.<br>
⛰️ **Goal Management:** Link tasks to long-term objectives.<br>
📦 **Batch Analysis:** Refactor, annotate task backlogs by tags or projects.<br>
🗡️ **Subtask Splitting:** Suggests splitting up vague tasks and suggests clear, actionable subtasks.

**Tip:** You can stop certain tasks from being sent to the API by blacklisting tags or projects.   


## Why TaskVanguard?

- **Stalled by stale high-priority tasks?** Reframe what moves your mission forward.
- **Tasks too broad or unclear?** Break them into precise, executable steps.
- **Spending time on structure instead of action?** Let the system handle the overhead.
- **Unsure what’s worth doing now?** Surface the tasks with real leverage.

**⚔️ TaskVanguard** fills those gaps using LLMs for real cognitive support. It’s especially useful for ADHD-driven procrastination: it r
```