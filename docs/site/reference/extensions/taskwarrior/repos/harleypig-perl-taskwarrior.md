# harleypig/perl-taskwarrior

**URL:** https://github.com/harleypig/perl-taskwarrior  
**Stars:** 1  
**Language:** Perl  
**Last push:** 2015-11-15  
**Archived:** Yes  
**Topics:** library, perl, perl-module, perl5-module, task, task-management-system, taskwarrior  

## Description

A perl package for interacting with the Taskwarrior ( http://taskwarrior.com ) to-do application.

## Category

Reports & Visualisation

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Reporting is a ww surface area
- +1: Import/export useful for profile migration

## README excerpt

```
# SYNOPSIS

    use Taskwarrior qw( :all );

# DESCRIPTION

This is the main module for the Taskwarrior project. All modules in the
Taskwarrior namespace should use this module.

Using `Taskwarrior` is equivalent to the following code.

    use strict;
    use warnings;
    use feature qw( say state );

This module also exports a number of utility methods that make logging easier,
a dumper method that uses Data::Dumper and the
[Carp](https://metacpan.org/pod/Carp) methods `carp` and `croak` are
exported.

Additionally, a task execute method is exported that handles calls to the task
executable.

# EXPORT

This module does not export anything automatically.

When `:all` is included in the use line (see SYNOPSIS) the following methods
are exported into the calling codes namespace.

    alert carp critical croak debug dumper emergency error info notice task warning

See the description for each method for details.

I don't know why, but including just a specific method, e.g. `use Taskwarrior qw(
alert );` does not work.  You will have to use ':all' until this issue is resolved.

# SUBROUTINES AND METHODS

## import

This method is not exported.

`import` is called when `use Taskwarrior` is invoked.

This is equivalent to the following code.

    use utf8;
    use strict;
    use warnings;
    use feature qw( say state );

## unimport

This method is not exported.

`unimport` is called when `no Taskwarrior` is invoked.

This is equivalent to the following code.

    no utf8;
    no strict;
    no warnings;
    no feature;

## task

This method is exported.

`task` takes whatever is passed to it and calls the task executable with
those parameters and returns the raw results to the caller.

No validation is performed. The caller is expected to handle any errors
reported by the task executable.

You can pass either a reference to an array or a list.

    my @task_parms = qw( pro:personal _ids );
    task( \@task_parms );

or

    task( qw( pro:personal _ids ) );

## dumper

This method is exported.

`dumper` is equivalent to the following code.

    Dumper $somevariable;

## logmsg

This method is not exported.

If the value sent to `logmsg` is a scalar, `logmsg` figures out some basic
information about the environment of the calling code and prepends it to the
msg being sent to the log.

E.g., the code `debug( 'Some debugging message' );` will send something like
the following to the log file.

    [Package::Name::method] Some debugging message

If the value sent to `logmsg` is a reference then dumper will be used to dump
the contents of the variable. The subroutine name will not be prefixed.

`logmsg` accepts multiple values. The following is valid.

    debug( 'Debugging FooBar', \%somehash );

This will send something like the following to the log.

    [Package::Name::method] Debugging FooBar
    $VAR1 = {
              key => 'value',
            }

## debug

## info

## notice

## warning

## error

## critical

## alert

## emergency

These are 
```