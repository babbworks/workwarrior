list
====

`list` is a command-line todo list manager for people that want to *finish* tasks,
not organize them.

This tool is bundled with Workwarrior as a simple, quick-capture list utility.


Why list?
---------

Yeah, I know, *another* command-line todo list manager.  Several others already
exist ([todo.txt][] and [TaskWarrior][] come to mind), so why include another one?

[todo.txt]: http://ginatrapani.github.com/todo.txt-cli/
[TaskWarrior]: http://taskwarrior.org/

### It Does the Simplest Thing That Could Possibly Work

Todo.txt and TaskWarrior are feature-packed.  They let you tag tasks, split
them into projects, set priorities, order them, color-code them, and much more.

**That's the problem.**

It's easy to say "I'll just organize my todo list a bit" and spend 15 minutes
tagging your tasks.  In those 15 minutes you probably could have *finished*
a couple of them.

`list` was inspired by [j][].  It's simple, messy, has almost no features, and is
extremely effective at the one thing it does.  With `list` the only way to make
your todo list prettier is to **finish some damn tasks**.

[j]: http://github.com/rupa/j2/

### It's Flexible

`list`'s simplicity makes it extremely flexible.

Want to edit a bunch of tasks at once?  Open the list in a text editor.

Want to view the lists on a computer that doesn't have `list` installed?  Open the
list in a text editor.

Want to synchronize the list across a couple of computers?  Keep your task
lists in a [Dropbox][] folder.

Want to use it as a distributed bug tracking system like [BugsEverywhere][]?
Make the task list a `bugs` file in the project repository.

[Dropbox]: https://www.getdropbox.com/
[BugsEverywhere]: http://bugseverywhere.org/

### It Plays Nice with Version Control

Other systems keep your tasks in a plain text file.  This is a good thing, and
`list` follows their lead.

However, some of them append new tasks to the end of the file when you create
them.  This is not good if you're using a version control system to let more
than one person edit a todo list.  If two people add a task and then try to
merge, they'll get a conflict and have to resolve it manually.

`list` uses random IDs (actually SHA1 hashes) to order the todo list files.  Once
the list has a couple of tasks in it, adding more is far less likely to cause
a merge conflict because the list is sorted.


Using list with Workwarrior
---------------------------

In Workwarrior, `list` is available as a global function when a profile is active:

    $ p-work                    # Activate a profile
    $ list Clean the apartment. # Add a task
    $ list                      # View tasks

You can also use the profile-specific alias:

    $ list-work                 # Direct access to work profile's list

### Requirements

`list` requires [Python][] 3 and is included with Workwarrior.

[Python]: http://python.org/


Using list
----------

`list` is quick and easy to use.

### Add a Task

To add a task, use `list [task description]`:

    $ list Clean the apartment.
    $ list Write chapter 10 of the novel.
    $ list Buy more beer.
    $

### List Your Tasks

Listing your tasks is even easier -- just use `list`:

    $ list
    9  - Buy more beer.
    30 - Clean the apartment.
    31 - Write chapter 10 of the novel.
    $

`list` will list all of your unfinished tasks and their IDs.

### Finish a Task

After you're done with something, use `list -f ID` to finish it:

    $ list -f 31
    $ list
    9  - Buy more beer.
    30 - Clean the apartment.
    $

### Edit a Task

Sometimes you might want to change the wording of a task.  You can use
`list -e ID [new description]` to do that:

    $ list -e 30 Clean the entire apartment.
    $ list
    9  - Buy more beer.
    30 - Clean the entire apartment.
    $

Yes, nerds, you can use sed-style substitution strings:

    $ list -e 9 /more/a lot more/
    $ list
    9  - Buy a lot more beer.
    30 - Clean the entire apartment.
    $

### Delete the Task List if it's Empty

If you keep your task list in a visible place (like your desktop) you might
want it to be deleted if there are no tasks in it.  To do this automatically
you can use the `--delete-if-empty` option:

    python ~/ww/tools/list/list.py --task-dir ~/Desktop --list todo.txt --delete-if-empty


Tips and Tricks
---------------

`list` might be simple, but it can do a lot of interesting things.

### Count Your Tasks

Counting your tasks is simple using the `wc` program:

    $ list | wc -l
          2
    $

### Put Your Task Count in Your Bash Prompt

Want a count of your tasks right in your prompt?  Edit your `~/.bashrc` file:

    export PS1='[$(list | wc -l | sed -e"s/ *//")]'" $PS1"

Now you've got a prompt that looks something like this:

    [2] $ list -f 30
    [1] $ list Feed the cat.
    [2] $


Original Project
----------------

`list` was originally created by Steve Losh as `t`. See ACKNOWLEDGEMENTS.md for
attribution and license information.

If you want to request a feature feel free, but remember that `list` is meant to
be simple.  If you need anything beyond the basics you might want to look at
[todo.txt][] or [TaskWarrior][] instead.  They're great tools with lots of
bells and whistles.
