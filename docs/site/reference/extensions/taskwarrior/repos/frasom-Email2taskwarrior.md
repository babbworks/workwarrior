# frasom/Email2taskwarrior

**URL:** https://github.com/frasom/Email2taskwarrior  
**Stars:** 1  
**Language:** Shell  
**Last push:** 2026-03-03  
**Archived:** No  
**Topics:** automation, email, email-parsing, taskwarrior  

## Description

Simple solution to create tasks via email in taskwarrior

## Category

NLP / AI

## Workwarrior Integration Rating

**Score:** 1  
**Rating:** ★★☆☆☆  Low  

### Scoring notes

- +1: GitHub is ww's primary issue source

## README excerpt

```
# Email2taskwarrior
Simple solution to create tasks via email in taskworrior

![Static Badge](https://img.shields.io/badge/OS-macOS_%7C_Linux-lightgrey)
![Static Badge](https://img.shields.io/badge/Taskwarrior_is_needed-red)
![GitHub top language](https://img.shields.io/github/languages/top/frasom/Email2taskwarrior)
![GitHub License](https://img.shields.io/github/license/frasom/Email2taskwarrior)
![GitHub repo size](https://img.shields.io/github/repo-size/frasom/Email2taskwarrior)
![GitHub Release](https://img.shields.io/github/v/release/frasom/Email2taskwarrior)

## Description
[Taskwarrior](https://github.com/GothenburgBitFactory/taskwarrior) is a great solution for TODO lists but unfortunately not available everywhere.
With email2task you can send yourself a new task via email. **A separate email account is required as all emails are read and then deleted.**
the script uses IMAP, so the mail server should also support the IMAP protocol

## Installation
Clone the repo or copy email2task.sh to your computer
after that, the following parameters still have to be adjusted

access="user@mailhost.com:topsecret"  
host="imaps://mailhost.com"  
logfile="/var/log/email2task.log"   

Make sure you have write-access to the logfile

## Usage

Send a Email (text no HTML) to your Taskwarrior-Email Account
Subject:    whatever you want, it will not be used
Text/Body:  {task command} 
Example:    add Pay the rent

On your computer start **email2task.sh** 

_You can also run the script automatically every time you start the system._

```