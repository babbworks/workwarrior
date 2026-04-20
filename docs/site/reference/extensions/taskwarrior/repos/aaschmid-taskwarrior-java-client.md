# aaschmid/taskwarrior-java-client

**URL:** https://github.com/aaschmid/taskwarrior-java-client  
**Stars:** 16  
**Language:** Java  
**Last push:** 2020-02-09  
**Archived:** No  
**Topics:** client, java, java-client, pem, pkcs, taskd, taskserver, taskwarrior, taskwarrior-java-client  

## Description

A Java client to communicate with a taskwarrior server (= taskd).

## Category

Reports & Visualisation

## Workwarrior Integration Rating

**Score:** 0  
**Rating:** ★★☆☆☆  Low  

### Scoring notes

- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- -2: Mobile — outside ww scope
- -1: Taskserver — ww doesn't use sync server

## README excerpt

```
[![Travis CI](https://travis-ci.org/aaschmid/taskwarrior-java-client.png?branch=master)](https://travis-ci.org/aaschmid/taskwarrior-java-client)
[![CircleCI](https://circleci.com/gh/aaschmid/taskwarrior-java-client.svg?style=svg)](https://circleci.com/gh/aaschmid/taskwarrior-java-client)
[![codebeat](https://codebeat.co/badges/90f3d360-88bb-4040-b8b6-2e3e684f11f4)](https://codebeat.co/projects/github-com-aaschmid-taskwarrior-java-client-master)
[![Maven Central](https://maven-badges.herokuapp.com/maven-central/de.aaschmid/taskwarrior-java-client/badge.svg)](http://search.maven.org/#search%7Cgav%7C1%7Cg%3A%22de.aaschmid%22%20AND%20a%3A%22taskwarrior-java-client%22)
[![License](https://img.shields.io/github/license/aaschmid/taskwarrior-java-client.svg)](https://github.com/aaschmid/taskwarrior-java-client/blob/master/LICENSE)
[![Issues](https://img.shields.io/github/issues/aaschmid/taskwarrior-java-client.svg)](https://github.com/aaschmid/taskwarrior-java-client/issues)

taskwarrior-java-client
=======================

#### Table of Contents
* [What is it](#what-is-it)
* [Motivation and distinction](#motivation-and-distinction)
* [Requirements](#requirements)
* [Download](#download)
* [Usage example](#usage-example)
* [Release notes](#release-notes)


What is it
----------

A Java client to communicate with a [taskwarrior][] server (= [taskd](https://taskwarrior.org/docs/taskserver/why.html)).

[taskwarrior]: https://taskwarrior.org/


Motivation and distinction
--------------------------

The current taskwarrior Android app does not satisfy my requirements. Therefore I created this client library to
integrate it into my preferred task app. And I also want to share it with everybody who will love to use it.


Requirements
-----------

* JDK 8


Download
--------

Currently there is no released version available but feel free to clone / fork and build it yourself. If you would
love to see this on [Maven Central](http://search.maven.org/) feel free to create an issue.

Usage example
-------------

For example using it with [Java](https://www.java.com/):


```java
import java.io.IOException;
import java.net.URL;

import de.aaschmid.taskwarrior.TaskwarriorClient;
import de.aaschmid.taskwarrior.config.TaskwarriorConfiguration;
import de.aaschmid.taskwarrior.message.MessageType;
import de.aaschmid.taskwarrior.message.TaskwarriorMessage;
import de.aaschmid.taskwarrior.message.TaskwarriorRequestHeader;

import static de.aaschmid.taskwarrior.config.TaskwarriorConfiguration.taskwarriorPropertiesConfiguration;
import static de.aaschmid.taskwarrior.message.TaskwarriorMessage.taskwarriorMessage;
import static de.aaschmid.taskwarrior.message.TaskwarriorRequestHeader.taskwarriorRequestHeaderBuilder;

class Taskwarrior {

    private static final URL PROPERTIES_TASKWARRIOR = Taskwarrior.class.getResource("/taskwarrior.properties");

    public static void main(String[] args) {
        if (PROPERTIES_TASKWARRIOR == null) {
            throw new IllegalStateException
```