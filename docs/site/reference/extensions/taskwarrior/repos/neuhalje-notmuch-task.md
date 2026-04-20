# neuhalje/notmuch-task

**URL:** https://github.com/neuhalje/notmuch-task  
**Stars:** 8  
**Language:** Python  
**Last push:** 2019-05-29  
**Archived:** No  
**Topics:** mutt, neomutt, notmuch, taskwarrior  

## Description

notmuchmail, taskwarrior and mutt are about to be your next dreamteam

## Category

API Libraries

## Workwarrior Integration Rating

**Score:** 6  
**Rating:** ★★★★☆  High  

### Scoring notes

- +3: UDAs — core to ww service model
- +1: Shell integration — ww is shell-first
- +1: CLI-first matches ww ethos
- +1: Python — tooling language used in ww

## README excerpt

```
mail to taskwarrior
#######################

.. image:: https://travis-ci.org/neuhalje/notmuch-task.svg?branch=master
    :target: https://travis-ci.org/neuhalje/notmuch-task
.. image:: https://badge.fury.io/py/notmuchtask.png
    :target: https://badge.fury.io/py/notmuchtask

Linking mails (mutt, neomutt) to taskwarrior tasks and the other way around by utilising notmuch.

- Create tasks from (neo)mutt with one command
- Find tasks already assigned to e-mails


Installing
**************

``pip install notmuchtask``


Usage
=============

``notmuchtask`` links e-mails to tasks in taskwarrior. This is done by assigning notmuch tags to the e-mails.

cli
**************

Finding tasks
===============

The ``find-task`` command will find the task(s) assigned to a message

.. code:: shell

  # reading the message from stdin
  cat test.eml|notmuchtask  find-task
  99c0768c-2dbd-4c8b-9b74-afe610653dd1

  # or reading the message by path
  notmuchtask  find-task test.eml

Exit codes
-----------

0
  Command ran successfully. The task-id has been written to stdout
90
  An unexpected error has occured
91
  File not found. The file passed could not be opened
92
  The message(-id) could not be found in notmuch
93
  The task could not be found

Creating tasks
===============

The ``find-or-create-task`` command will find the task(s) assigned to a
 message and will create a new task if needed.

.. code:: shell

  # reading the message from stdin
  cat test.eml|notmuchtask  find-or-create-task
  # the first time a new task is created with the subject as title
  99c0768c-2dbd-4c8b-9b74-afe610653dd1

  cat test.eml|notmuchtask  find-or-create-task
  # the second time no new task is created
  99c0768c-2dbd-4c8b-9b74-afe610653dd1

  # or reading the message by path
  notmuchtask  find-or-create-task test.eml
  99c0768c-2dbd-4c8b-9b74-afe610653dd1


Exit codes
-----------

0
  Command ran successfully. The task-id has been written to stdout
90
  An unexpected error has occurred
91
  File not found. The file passed could not be opened
92
  The message(-id) could not be found in notmuch

(neo)mutt
**************

Add this to your ``.muttrc``:

.. code:: text

  # Make sure that there are no spaces at the beginning of the line
  macro index,pager <F8> \
  "<enter-command>set my_old_pipe_decode=\$pipe_decode my_old_wait_key=\$wait_key nopipe_decode nowait_key<enter>\
  <pipe-message>notmuchtask --debug find-or-create-task<enter>\
  <enter-command>set pipe_decode=\$my_old_pipe_decode wait_key=\$my_old_wait_key<enter>" \
  "notmuchtask: assign mail to a task"



configuring
*************

notmuchtask can be configured by a config file:

.. code:: ini

  [tags]
  # notmuchtask uses notmuch tags to link messages to tasks
  # `prefix` is used as a prefix to the taskid. E.g.
  # if prefix is set to 'taskid:', and the task
  # e1544da8-8b9b-4bda-b4bc-8642c5627b59 is linked to the message
  # the tag 'taskid:e1544da8-8b9b-4bda-b4bc-8642c5627b59' is set on the
  # message.
  # de
```