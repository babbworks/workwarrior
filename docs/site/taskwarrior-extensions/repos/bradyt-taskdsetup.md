# bradyt/taskdsetup

**URL:** https://github.com/bradyt/taskdsetup  
**Stars:** 0  
**Language:** Python  
**Last push:** 2018-03-19  
**Archived:** No  
**Topics:** python3, taskd, taskwarrior  

## Description

An exercise in scripting the steps described at https://taskwarrior.org/docs/taskserver/setup.html TaskWarrior

## Category

Sync

## Workwarrior Integration Rating

**Score:** 4  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Python — tooling language used in ww
- -1: Taskserver — ww doesn't use sync server

## README excerpt

```

About
=====

This CLI tool assists in setup of the TaskServer tool `taskd`. It
helps in initializing taskd and adding users. Besides this, an effort
will also be made to make (multiple) client configuration smoother,
and easy to do after the fact.

In general, issues with TaskServer should be first checked via steps
described at https://taskwarrior.org/docs/taskserver/setup.html.

There's also a pdf of troubleshooting steps, current link is at
https://git.tasktools.org/ST/guides/raw/master/taskserver-setup/taskserver-setup.pdf

Configuration
=============

Before running, you'll want to specify your configuration with a
`~/.taskdsetup.py`

.. code-block:: json

   {
        "data": "/tmp/var/taskd",
        "source": null,
        "dns_name": "localhost",
        "internal_ip": "localhost",
        "port": "53589",
        "orgs": {
            "Public": {"John Smith": {}
                    }
        }
    }

Some minimal setup to try
=========================

::

   sudo apt-get install taskwarrior taskd -y
   git clone --recursive https://github.com/bradyt/taskdsetup
   pip3 install --user -e .

   taskdsetup init
   # check if it can serve
   # taskd server --data /tmp/var/taskd

   taskdsetup user
   taskdsetup client

   TASKDDATA=/tmp/var/taskd taskdctl start
   task rc.confirmation=no sync init

If this is working for you, you can try `cp sample.json
~/.taskdsetup.json`, edit the `data` directory to something like
`~/var/taskd`, the `user` name, and unless you're only serving to
`localhost`, edit `dns_name` and `internal_ip`. The latter can be
`0.0.0.0` if you're troubleshooting. If you have a different location
for `source` where the `pki` directory will be, can edit that too.

Dev
====

::

   python3 -m venv .
   . bin/activate
   python -m taskdsetup.application
   pip3 install -e .
   taskdsetup --help
   python setup.py sdist
   twine upload -r test dist/*
   # note that a single file cannot be uploaded twice
   pip3 install --user -i https://testpypi.python.org/pypi taskdsetup

   git clone --recursive https://github.com/bradyt/taskdsetup.git
   cd taskdsetup
   pip3 install --user -e .

```