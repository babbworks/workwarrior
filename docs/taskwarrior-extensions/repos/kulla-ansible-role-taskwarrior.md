# kulla/ansible-role-taskwarrior

**URL:** https://github.com/kulla/ansible-role-taskwarrior  
**Stars:** 1  
**Language:** —  
**Last push:** 2026-04-08  
**Archived:** No  
**Topics:** ansible, ansible-galaxy, ansible-role, task-management, taskwarrior  

## Description

Ansible role for installing and configuring the task management tool "taskwarrior" (see https://taskwarrior.org/ )

## Category

Sync

## Workwarrior Integration Rating

**Score:** 4  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- -1: Taskserver — ww doesn't use sync server

## README excerpt

```
taskwarrior
===========

Installs and configures the task management tool [taskwarrior](https://taskwarrior.org/).

Role Variables
--------------

The variables for configuring this role are:

```yaml
# Defines for which user taskwarrior shall be configured
# (This variable defaults to the value of the variable "ansible_user_id")
taskwarrior_user_id: "{{ ansible_user_id }}"

# Set to true, if an hourly cronjob for syncing taskwarrior shall be configured
# (The default value is "false")
taskwarrior_cronjob_sync:

# Configuration for taskwarrior
taskwarrior_configuration:

# Name of taskserver's certificate (taskd.ca)
taskwarrior_ca_certificate:

# Name of client's certifiacte (taskd.certificate)
taskwarrior_client_certificate:

# Name of client's key (taskd.key)
taskwarrior_client_key:
```

You can find more variables for a more specialized configuration in [`defaults/main.yml`](defaults/main.yml).
However, these variables might change in the future since they aren't considered part of the officially supported variables.

Example Playbook
----------------

```yaml
- hosts: localhost
  roles:
     - taskwarrior
  vars:
    taskwarrior_user_id: myusername

    taskwarrior_ca_certificate: ca.cert.pem
    taskwarrior_client_certificate: first_last.cert.pem
    taskwarrior_client_key: first_last.key.pem

    taskwarrior_cronjob_sync: true

    taskwarrior_configuration: |
      # -- My configuration of taskwarrior --
      weekstart=Sunday

      color.tag.important=bold white on rgb010

      context.work=project:work or +important
```

The taskwarrior configuration can also be read from a file using the [file lookup plugin](https://docs.ansible.com/ansible/latest/plugins/lookup/file.html) or from a template with the [template lookup plugin](https://docs.ansible.com/ansible/latest/plugins/lookup/template.html):

```yaml
taskwarrior_configuration: "{{ lookup('file', 'my_config.conf') }}"
```

Syncing to a taskserver
-----------------------

With the following variables you provide the names of certificates which are needed in order to connect to a taskserver.
If those variables are set, the certificates are copied to the remote machine. Note that you want to protect them properly (e.g. with [Ansible vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html):

```yaml
taskwarrior_ca_certificate: ca.cert.pem
taskwarrior_client_certificate: first_last.cert.pem
taskwarrior_client_key: first_last.key.pem
```

This role automatically sets the configuration settings `taskd.ca`, `taskd.key` and `taskd.certificate`.
However you need to add the missing configuration settings for using a taskserver in the variable `taskwarrior_configuration`:

```yaml
taskwarrior_configuration: |
  taskd.server=...
  taskd.credentials=...
```

In the taskwarrior documentation you can find more information for [configuring taskwarrior with a taskserver](https://taskwarrior.org/docs/taskserver/taskwarrior.html).

Dependencies and Requirements
----------------------------
```