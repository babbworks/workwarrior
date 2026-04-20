# AliGhahraei/just-start

**URL:** https://github.com/AliGhahraei/just-start  
**Stars:** 7  
**Language:** Python  
**Last push:** 2024-05-25  
**Archived:** Yes  
**Topics:** pomodoro-timer, productivity, python, taskwarrior  

## Description

An app to defeat procrastination

## Category

Reports & Visualisation

## Workwarrior Integration Rating

**Score:** 5  
**Rating:** ★★★★☆  High  

### Scoring notes

- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Python — tooling language used in ww

## README excerpt

```
NO LONGER MAINTAINED
====================
Check out the new app: https://github.com/AliGhahraei/little-by-little

just-start
==========

|Build Status| |Coverage Status|

An app to defeat procrastination!

Introduction
------------

Just-Start is a to-do list application and productivity booster. It prevents
you from procrastinating (too much).

The program is a wrapper for TaskWarrior_ with a timer implementing the
`Pomodoro Technique`_ (time management). It also draws a bit of inspiration from
Omodoro_.

Features:

- Configurable pomodoro phase durations
- Support for multiple configurations (a.k.a. *locations*) based on the current time and day of the
  week
- Desktop notifications
- Block time-wasting sites while you’re working

Installation and usage
----------------------

Supported platforms:

- Linux
- macOS

Requirements:

- Python 3.6+
- TaskWarrior_ (latest)

Pick a client name from the table below and run:

.. code:: bash

    $ pip install just-start[<client_name>]
    $ just-start-<client_name>

So for the urwid client:

.. code:: bash

    $ pip install just-start-urwid
    $ just-start-urwid

Press h to see a list of available user actions.

Clients
-------

+--------------------+----------+------------------------------------------------------------+
|Name                |Framework |Notes                                                       |
+====================+==========+============================================================+
|urwid (recommended) |Urwid_    |Inspired by Calcurse_. Similar to a graphical               |
|                    |          |application, but in your terminal                           |
+--------------------+----------+------------------------------------------------------------+
|term                |Terminal  |Example client. Useful for seeing how to write a brand new  |
|                    |(none)    |one but not intended for continuous usage                   |
+--------------------+----------+------------------------------------------------------------+

Development
-----------

If you want to help out please install Poetry_, clone the repo and run:

.. code:: bash

    $ cd just-start/
    $ poetry install

This will ensure you have both the development and install dependencies.

You can also install the package in editable mode to test manually without having to run a build
after every change, but you'll need to generate a setup.py since projects using pyproject.toml alone
can't be used this way (see the note about editable mode in PEP517_ for more info). I use Dephell_
for this:

.. code:: bash

    $ cd just-start
    $ dephell deps convert --from=pyproject.toml --to=setup.py
    $ pip install -e just_start

Bug reports
-----------

Issues are tracked using `GitHub Issues`_

Running Tests
-------------

You just need Poetry_ and Tox_

.. code:: bash

    $ tox

.. |Build Status| image:: https://travis-ci.org/AliGhahraei/
   just-start.svg?branch=master
   :target: https://travis-ci.o
```