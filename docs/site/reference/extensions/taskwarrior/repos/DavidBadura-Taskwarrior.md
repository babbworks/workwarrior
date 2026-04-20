# DavidBadura/Taskwarrior

**URL:** https://github.com/DavidBadura/Taskwarrior  
**Stars:** 16  
**Language:** PHP  
**Last push:** 2022-06-26  
**Archived:** Yes  
**Topics:** php, taskwarrior, todo  

## Description

a php lib for taskwarrior

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 6  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Urgency coefficients are a ww UDA focus area
- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration

## README excerpt

```
# Taskwarrior PHP lib

used by [doThings](https://github.com/DavidBadura/doThings) - a Taskwarrior web-ui.

[![Build Status](https://travis-ci.org/DavidBadura/Taskwarrior.svg?branch=master)](https://travis-ci.org/DavidBadura/Taskwarrior)

![WOW](http://i.imgur.com/mvSQh0M.gif)

## Install

```bash
composer require 'davidbadura/taskwarrior'
```

Unfortunately, the annotation reader is not automatically registered on composer. So you should add following line if you have `[Semantical Error] The annotation "@JMS\Serializer\Annotation\Type" in property [...] does not exist, or could not be auto-loaded.` exception:

```php
\Doctrine\Common\Annotations\AnnotationRegistry::registerLoader('class_exists');
```

## Requirements

Taskwarrior changes its behavior by patch level updates and it is very difficult to support all versions.
The current supported versions are:

|PHP Lib|Taskwarrior|PHP Version|
|----|---------|------|
|2.x|>=2.4.3|>=5.4|
|3.x|>=2.5.0|>=5.5|

## Usage

```php
use DavidBadura\Taskwarrior\TaskManager;
use DavidBadura\Taskwarrior\Task;
use DavidBadura\Taskwarrior\Recurring;
use DavidBadura\Taskwarrior\Annotation;

$tm = TaskManager::create();

$task = new Task();
$task->setDescription('program this lib');
$task->setProject('hobby');
$task->setDue('tomorrow');
$task->setPriority(Task::PRIORITY_HIGH);
$task->addTag('next');
$task->setRecurring(Recurring::DAILY);
$task->addAnnotation(new Annotation("and add many features"));

$tm->save($task);

$tasks = $tm->filterPending('project:hobby'); // one task

$tm->done($task);

$tasks = $tm->filterPending('project:hobby'); // empty
$tasks = $tm->filter('project:hobby'); // one task

$tasks = $tm->filterByReport('waiting'); // and sorting
```

## API

### Task

|attr|writeable|type|
|----|---------|----|
|uuid|false|string|
|description|true|string|
|priority|true|string|
|project|true|string|
|due|true|DateTime|
|wait|true|DateTime|
|tags|true|string[]|
|annotations|true|Annotation[]|
|urgency|false|float|
|entry|false|DateTime|
|start|false|DateTime|
|recur|true|Recurring|
|unti|true|DateTime|
|modified|false|DateTime|
|end|false|DateTime|
|status|false|string|

Example:

```php
$task = new Task();
$task->setDescription('program this lib');
$task->setProject('hobby');
$task->setDue('tomorrow');
$task->setPriority(Task::PRIORITY_HIGH);
$task->addTag('next');
$task->setRecurring(Recurring::DAILY);
```

### Taskwarrior

create TaskManager:

```php
$tm = TaskManager::create();
```


save a task:

```php
$task = new Task();
$task->setDescription('foo');
$tm->save($task);
```

find a task:

```php
$task = $tm->find('b1d46c75-63cc-4753-a20f-a0b376f1ead0');
```

filter tasks:

```php
$tasks = $tm->filter('status:pending');
$tasks = $tm->filter('status:pending +home');
$tasks = $tm->filter('status:pending and +home');
$tasks = $tm->filter(['status:pending', '+home']);
```

filter pending tasks:

```php
$tasks = $tm->filterPending('+home');
$tasks = $tm->filterPending('project:hobby +home');
$tasks = $tm
```