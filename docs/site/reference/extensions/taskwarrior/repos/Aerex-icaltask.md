# Aerex/icaltask

**URL:** https://github.com/Aerex/icaltask  
**Stars:** 7  
**Language:** Python  
**Last push:** 2022-07-05  
**Archived:** No  
**Topics:** ical, task-management, taskwarrior  

## Description

Synchronize between Taskwarrior and iCalendar TODO events

## Category

Sync

## Workwarrior Integration Rating

**Score:** 10  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +2: Sync capability relevant to ww profile isolation
- +3: UDAs — core to ww service model
- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww

## README excerpt

```
icaltask 
========

.. image:: https://img.shields.io/badge/version-0.0.1-blue.svg?cacheSeconds=2592000
   :alt: version
   :width: 100%
   :align: center

icaltask is a `taskwarrior <https://taskwarrior.org/>`_ hook that converts taskwarrior tasks into iCalendar VTODO events and exports them to an iCalendar server.  

Install
-------

Using python-setuptools
~~~~~~~~~~~~~~~~~~~~~~~
::

   $ python3 setup.py install

Configuration
-------------
Generate the sample configuration file by running the following command. How to use configure the file is documented in the file.
::

  $ icaltask copy-config

Hooks and UDA Configs
~~~~~~~~~~~~~~~~~~~~~
Run the following command to create the on-add and on-modify hooks. This will also add the necessary UDA configuration into your taskwarrior configuration file
::
  
  $ icaltask install 

To remove the hooks and UDA configuration run the following command
::

  $ icaltask uninstall

Related Projects
----------------
`baikal-storage-plugin <https://github.com/Aerex/baikal-storage-plugin>`_

```