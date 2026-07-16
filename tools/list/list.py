#!/usr/bin/env python

"""l is for people that want do things, not organize their tasks."""

from __future__ import with_statement, print_function

import os, re, sys, hashlib, json
from operator import itemgetter
from optparse import OptionParser, OptionGroup, SUPPRESS_HELP


class InvalidTaskfile(Exception):
    """Raised when the path to a task file already exists as a directory."""
    pass

class AmbiguousPrefix(Exception):
    """Raised when trying to use a prefix that could identify multiple tasks."""
    def __init__(self, prefix):
        super(AmbiguousPrefix, self).__init__()
        self.prefix = prefix

class UnknownPrefix(Exception):
    """Raised when trying to use a prefix that does not match any tasks."""
    def __init__(self, prefix):
        super(UnknownPrefix, self).__init__()
        self.prefix = prefix

class BadFile(Exception):
    """Raised when something else goes wrong trying to work with the task file."""
    def __init__(self, path, problem):
        super(BadFile, self).__init__()
        self.path = path
        self.problem = problem


def _hash(text):
    """Return a hash of the given text for use as an id.

    Currently SHA1 hashing is used.  It should be plenty for our purposes.

    """
    return hashlib.sha1(text.encode('utf-8')).hexdigest()

def _task_from_taskline(taskline):
    """Parse a taskline (from a task file) and return a task.

    A taskline should be in the format:

        summary text ... | meta1:meta1_value,meta2:meta2_value,...

    The task returned will be a dictionary such as:

        { 'id': <hash id>,
          'text': <summary text>,
           ... other metadata ... }

    A taskline can also consist of only summary text, in which case the id
    and other metadata will be generated when the line is read.  This is
    supported to enable editing of the taskfile with a simple text editor.
    """
    if taskline.strip().startswith('#'):
        return None
    elif '|' in taskline:
        text, _, meta = taskline.rpartition('|')
        task = { 'text': text.strip() }
        for piece in meta.strip().split(','):
            label, data = piece.split(':')
            task[label.strip()] = data.strip()
    else:
        text = taskline.strip()
        task = { 'id': _hash(text), 'text': text }
    return task

def _tasklines_from_tasks(tasks):
    """Parse a list of tasks into tasklines suitable for writing."""

    tasklines = []

    for task in tasks:
        meta = [m for m in task.items() if m[0] != 'text']
        meta_str = ', '.join('%s:%s' % m for m in meta)
        tasklines.append('%s | %s\n' % (task['text'], meta_str))

    return tasklines

def _prefixes(ids):
    """Return a mapping of ids to prefixes in O(n) time.

    Each prefix will be the shortest possible substring of the ID that
    can uniquely identify it among the given group of IDs.

    If an ID of one task is entirely a substring of another task's ID, the
    entire ID will be the prefix.
    """
    ps = {}
    for id in ids:
        id_len = len(id)
        for i in range(1, id_len+1):
            # identifies an empty prefix slot, or a singular collision
            prefix = id[:i]
            if (not prefix in ps) or (ps[prefix] and prefix != ps[prefix]):
                break
        if prefix in ps:
            # if there is a collision
            other_id = ps[prefix]
            for j in range(i, id_len+1):
                if other_id[:j] == id[:j]:
                    ps[id[:j]] = ''
                else:
                    ps[other_id[:j]] = other_id
                    ps[id[:j]] = id
                    break
            else:
                ps[other_id[:id_len+1]] = other_id
                ps[id] = id
        else:
            # no collision, can safely add
            ps[prefix] = id
    ps = dict(zip(ps.values(), ps.keys()))
    if '' in ps:
        del ps['']
    return ps


def _parse_item_text(text):
    """Parse item text into components: body, note, tags, timestamp.

    Returns a dict with keys: body, note, tags (list), timestamp (str or None).
    """
    remaining = text

    # Parse optional timestamp prefix: [YYYY-MM-DD HH:MM] or [YYYY-MM-DD]
    timestamp = None
    ts_match = re.match(r'^\[(\d{4}-\d{2}-\d{2}(?:\s+\d{2}:\d{2})?)\]\s*', remaining)
    if ts_match:
        timestamp = ts_match.group(1)
        remaining = remaining[ts_match.end():]

    # Split on first ' // ' for note
    note = None
    if ' // ' in remaining:
        body, _, note = remaining.partition(' // ')
    else:
        body = remaining

    # Extract tags from body: # followed by [a-zA-Z0-9_-]+, preceded by space or start
    tags = re.findall(r'(?:^|(?<=\s))#([a-zA-Z0-9_-]+)', body)

    return {
        'body': body,
        'note': note,
        'tags': tags,
        'timestamp': timestamp,
    }


class TaskDict(object):
    """A set of tasks, both finished and unfinished, for a given list.

    The list's files are read from disk when the TaskDict is initialized. They
    can be written back out to disk with the write() function.

    """
    def __init__(self, taskdir='.', name='tasks'):
        """Initialize by reading the task files, if they exist."""
        self.tasks = {}
        self.done = {}
        self.name = name
        self.taskdir = taskdir
        filemap = (('tasks', self.name), ('done', '.%s.done' % self.name))
        for kind, filename in filemap:
            path = os.path.join(os.path.expanduser(self.taskdir), filename)
            if os.path.isdir(path):
                raise InvalidTaskfile
            if os.path.exists(path):
                try:
                    with open(path, 'r') as tfile:
                        tls = [tl.strip() for tl in tfile if tl]
                        tasks = map(_task_from_taskline, tls)
                        for task in tasks:
                            if task is not None:
                                getattr(self, kind)[task['id']] = task
                except IOError as e:
                    raise BadFile(path, e.strerror)

    def __getitem__(self, prefix):
        """Return the unfinished task with the given prefix.

        If more than one task matches the prefix an AmbiguousPrefix exception
        will be raised, unless the prefix is the entire ID of one task.

        If no tasks match the prefix an UnknownPrefix exception will be raised.

        """
        matched = [tid for tid in self.tasks.keys() if tid.startswith(prefix)]
        if len(matched) == 1:
            return self.tasks[matched[0]]
        elif len(matched) == 0:
            raise UnknownPrefix(prefix)
        elif prefix in matched:
            return self.tasks[prefix]
        else:
            raise AmbiguousPrefix(prefix)

    def add_task(self, text, verbose, quiet):
        """Add a new, unfinished task with the given summary text."""
        task_id = _hash(text)
        self.tasks[task_id] = {'id': task_id, 'text': text}

        if not quiet:
            if verbose:
                print(task_id)
            else:
                prefixes = _prefixes(self.tasks)
                print(prefixes[task_id])

    def edit_task(self, prefix, text):
        """Edit the task with the given prefix.

        If more than one task matches the prefix an AmbiguousPrefix exception
        will be raised, unless the prefix is the entire ID of one task.

        If no tasks match the prefix an UnknownPrefix exception will be raised.

        """
        task = self[prefix]
        if text.startswith('s/') or text.startswith('/'):
            text = re.sub('^s?/', '', text).rstrip('/')
            find, _, repl = text.partition('/')
            text = re.sub(find, repl, task['text'])

        task['text'] = text
        task['id'] = _hash(text)

    def finish_task(self, prefix):
        """Mark the task with the given prefix as finished.

        If more than one task matches the prefix an AmbiguousPrefix exception
        will be raised, if no tasks match it an UnknownPrefix exception will
        be raised.

        """
        task = self.tasks.pop(self[prefix]['id'])
        self.done[task['id']] = task

    def remove_task(self, prefix):
        """Remove the task from tasks list.

        If more than one task matches the prefix an AmbiguousPrefix exception
        will be raised, if no tasks match it an UnknownPrefix exception will
        be raised.

        """
        self.tasks.pop(self[prefix]['id'])


    def print_list(self, kind='tasks', verbose=False, quiet=False, grep=''):
        """Print out a nicely formatted list of unfinished tasks."""
        tasks = dict(getattr(self, kind).items())
        label = 'prefix' if not verbose else 'id'

        if not verbose:
            for task_id, prefix in _prefixes(tasks).items():
                tasks[task_id]['prefix'] = prefix

        plen = max(map(lambda t: len(t[label]), tasks.values())) if tasks else 0
        for _, task in sorted(tasks.items()):
            if grep.lower() in task['text'].lower():
                p = '%s - ' % task[label].ljust(plen) if not quiet else ''
                print(p + task['text'])

    def write(self, delete_if_empty=False):
        """Flush the finished and unfinished tasks to the files on disk."""
        filemap = (('tasks', self.name), ('done', '.%s.done' % self.name))
        for kind, filename in filemap:
            path = os.path.join(os.path.expanduser(self.taskdir), filename)
            if os.path.isdir(path):
                raise InvalidTaskfile
            tasks = sorted(getattr(self, kind).values(), key=itemgetter('id'))
            if tasks or not delete_if_empty:
                try:
                    with open(path, 'w') as tfile:
                        for taskline in _tasklines_from_tasks(tasks):
                            tfile.write(taskline)
                except IOError as e:
                    raise BadFile(path, e.strerror)

            elif not tasks and os.path.isfile(path):
                os.remove(path)


# ============================================================================
# Multi-list management helpers
# ============================================================================

def _read_lists_yaml(lists_yaml_path):
    """Read lists.yaml and return the default list name."""
    default = 'tasks'
    if os.path.isfile(lists_yaml_path):
        try:
            with open(lists_yaml_path, 'r') as f:
                for line in f:
                    stripped = line.strip()
                    if stripped.startswith('default:'):
                        val = stripped[len('default:'):].strip()
                        if val:
                            default = val
                        break
        except IOError:
            pass
    return default


def _write_lists_yaml(lists_yaml_path, default_name):
    """Write lists.yaml with the given default list name, preserving other entries."""
    # Read existing content to preserve extra entries
    lines = []
    if os.path.isfile(lists_yaml_path):
        try:
            with open(lists_yaml_path, 'r') as f:
                lines = f.readlines()
        except IOError:
            lines = []

    # If file is empty or doesn't exist, write fresh
    if not lines:
        with open(lists_yaml_path, 'w') as f:
            f.write('lists:\n')
            f.write('  default: %s\n' % default_name)
        return

    # Update the default: line in-place
    updated = False
    new_lines = []
    for line in lines:
        if line.strip().startswith('default:'):
            new_lines.append('  default: %s\n' % default_name)
            updated = True
        else:
            new_lines.append(line)

    if not updated:
        # Insert default: after lists: header
        final_lines = []
        inserted = False
        for line in new_lines:
            final_lines.append(line)
            if not inserted and line.strip() == 'lists:':
                final_lines.append('  default: %s\n' % default_name)
                inserted = True
        if not inserted:
            final_lines.append('lists:\n')
            final_lines.append('  default: %s\n' % default_name)
        new_lines = final_lines

    with open(lists_yaml_path, 'w') as f:
        f.writelines(new_lines)


def _get_all_lists(list_dir):
    """Return sorted list of all list names (files in list_dir, excluding dotfiles)."""
    lists = []
    if os.path.isdir(list_dir):
        for entry in os.listdir(list_dir):
            path = os.path.join(list_dir, entry)
            # Skip dotfiles (done files are .name.done) and directories
            if not entry.startswith('.') and os.path.isfile(path):
                lists.append(entry)
    return sorted(lists)


def _show_lists_picker(list_dir, default_name, profile_name):
    """Print numbered list of all lists. Returns selected name or None."""
    lists = _get_all_lists(list_dir)
    if not lists:
        print('No lists found.')
        return None

    for i, name in enumerate(lists, 1):
        marker = ' *' if name == default_name else ''
        print('  %d. %s%s' % (i, name, marker))

    # Non-TTY: just print and exit without blocking
    if not sys.stdin.isatty():
        return None

    sys.stdout.write('\nSwitch to (number or name): ')
    sys.stdout.flush()
    try:
        choice = input().strip()
    except (EOFError, KeyboardInterrupt):
        return None

    if not choice:
        return None

    # Try as number
    try:
        idx = int(choice)
        if 1 <= idx <= len(lists):
            return lists[idx - 1]
        else:
            sys.stderr.write('error: invalid number\n')
            return None
    except ValueError:
        pass

    # Try as name
    if choice in lists:
        return choice

    sys.stderr.write('error: list "%s" not found\n' % choice)
    return None


def _cmd_new(args, list_dir, lists_yaml_path):
    """Create a new named list."""
    if not args:
        sys.stderr.write('error: list new requires a name\n')
        sys.exit(1)

    name = args[0]

    # Validate name (alphanumeric, hyphens, underscores)
    if not re.match(r'^[a-zA-Z0-9_-]+$', name):
        sys.stderr.write('error: list name must be alphanumeric (hyphens and underscores allowed)\n')
        sys.exit(1)

    list_file = os.path.join(list_dir, name)
    if os.path.exists(list_file):
        sys.stderr.write('error: list "%s" already exists\n' % name)
        sys.exit(1)

    # Create the list file
    os.makedirs(list_dir, exist_ok=True)
    with open(list_file, 'w') as f:
        pass  # empty file

    # Ensure lists.yaml exists and has default
    if not os.path.isfile(lists_yaml_path):
        with open(lists_yaml_path, 'w') as f:
            f.write('lists:\n')
            f.write('  default: tasks\n')

    print('Created list: %s' % name)
    sys.exit(0)


def _cmd_which(profile_name, list_name):
    """Print profile / list identity."""
    print('%s / %s' % (profile_name, list_name))
    sys.exit(0)


def _cmd_switch(args, list_dir, lists_yaml_path, profile_name):
    """Switch the default list."""
    if args:
        name = args[0]
    else:
        # Interactive picker
        default_name = _read_lists_yaml(lists_yaml_path)
        name = _show_lists_picker(list_dir, default_name, profile_name)
        if name is None:
            sys.exit(0)

    # Verify list exists
    list_file = os.path.join(list_dir, name)
    if not os.path.isfile(list_file):
        sys.stderr.write('error: list "%s" does not exist\n' % name)
        sys.exit(1)

    _write_lists_yaml(lists_yaml_path, name)
    print('Switched to list: %s' % name)
    sys.exit(0)


def _cmd_show_lists(list_dir, lists_yaml_path, profile_name, notes=False, tag_filter='', export_format=''):
    """Show all lists (the `lists` command). Supports --notes, #tag, and --export."""
    default_name = _read_lists_yaml(lists_yaml_path)

    # --export json: dump all lists as JSON object
    if export_format == 'json':
        all_lists = _get_all_lists(list_dir)
        result = {}
        for lname in all_lists:
            td = TaskDict(taskdir=list_dir, name=lname)
            items = _tasks_to_json_list(td)
            result[lname] = items
        print(json.dumps(result, indent=2))
        sys.exit(0)

    # #tag filter: search all lists for items matching tag
    if tag_filter:
        all_lists = _get_all_lists(list_dir)
        found_any = False
        for lname in all_lists:
            td = TaskDict(taskdir=list_dir, name=lname)
            matching = []
            for task in td.tasks.values():
                parsed = _parse_item_text(task['text'])
                if tag_filter.lower() in [t.lower() for t in parsed['tags']]:
                    matching.append(task)
            if matching:
                if found_any:
                    print('')
                print('%s:' % lname)
                for task in sorted(matching, key=itemgetter('id')):
                    print('  %s' % task['text'])
                found_any = True
        if not found_any:
            print('No items with #%s found.' % tag_filter)
        sys.exit(0)

    # --notes: show all annotated items across lists
    if notes:
        all_lists = _get_all_lists(list_dir)
        found_any = False
        for lname in all_lists:
            td = TaskDict(taskdir=list_dir, name=lname)
            annotated = []
            for task in td.tasks.values():
                parsed = _parse_item_text(task['text'])
                if parsed['note']:
                    annotated.append((task, parsed))
            if annotated:
                if found_any:
                    print('')
                print('%s:' % lname)
                for task, parsed in sorted(annotated, key=lambda x: x[0]['id']):
                    print('  %s' % parsed['body'])
                    print('  \u21b3 %s' % parsed['note'])
                found_any = True
        if not found_any:
            print('No annotated items found.')
        sys.exit(0)

    # Default: show list picker
    selected = _show_lists_picker(list_dir, default_name, profile_name)
    if selected is not None and selected != default_name:
        _write_lists_yaml(lists_yaml_path, selected)
        print('Switched to list: %s' % selected)
    sys.exit(0)


def _tasks_to_json_list(td):
    """Convert a TaskDict's tasks to a JSON-serializable list."""
    tasks = dict(td.tasks.items())
    prefixes = _prefixes(tasks)
    items = []
    for task_id in sorted(tasks.keys()):
        task = tasks[task_id]
        parsed = _parse_item_text(task['text'])
        item = {
            'id': task_id,
            'prefix': prefixes.get(task_id, task_id),
            'text': task['text'],
            'body': parsed['body'],
            'tags': parsed['tags'],
            'note': parsed['note'],
            'done': False,
        }
        if parsed['timestamp']:
            item['added'] = parsed['timestamp']
        items.append(item)
    return items


def _die(message):
    sys.stderr.write('error: %s\n' % message)
    sys.exit(1)

def _build_parser():
    """Return a parser for the command-line interface."""
    usage = "Usage: %prog [-t DIR] [-l LIST] [options] [TEXT]"
    parser = OptionParser(usage=usage)

    actions = OptionGroup(parser, "Actions",
        "If no actions are specified the TEXT will be added as a new task.")
    actions.add_option("-e", "--edit", dest="edit", default="",
                       help="edit TASK to contain TEXT", metavar="TASK")
    actions.add_option("-f", "--finish", dest="finish",
                       help="mark TASK as finished", metavar="TASK")
    actions.add_option("-r", "--remove", dest="remove",
                       help="Remove TASK from list", metavar="TASK")
    parser.add_option_group(actions)

    config = OptionGroup(parser, "Configuration Options")
    config.add_option("-l", "--list", dest="name", default="tasks",
                      help="work on LIST", metavar="LIST")
    config.add_option("-t", "--task-dir", dest="taskdir", default="",
                      help="work on the lists in DIR", metavar="DIR")
    config.add_option("-d", "--delete-if-empty",
                      action="store_true", dest="delete", default=False,
                      help="delete the task file if it becomes empty")
    parser.add_option_group(config)

    output = OptionGroup(parser, "Output Options")
    output.add_option("-g", "--grep", dest="grep", default='',
                      help="print only tasks that contain WORD", metavar="WORD")
    output.add_option("-v", "--verbose",
                      action="store_true", dest="verbose", default=False,
                      help="print more detailed output (full task ids, etc)")
    output.add_option("-q", "--quiet",
                      action="store_true", dest="quiet", default=False,
                      help="print less detailed output (no task ids, etc)")
    output.add_option("--done",
                      action="store_true", dest="done", default=False,
                      help="list done tasks instead of unfinished ones")
    output.add_option("-n", "--notes",
                      action="store_true", dest="notes", default=False,
                      help="show inline notes on a second line")
    output.add_option("--json",
                      action="store_true", dest="json_output", default=False,
                      help="output items as JSON array")
    output.add_option("--print",
                      action="store_true", dest="print_clean", default=False,
                      help="clean text output, no IDs or metadata")
    output.add_option("--export", dest="export_format", default='',
                      help="export all lists (e.g., --export json)", metavar="FORMAT")
    parser.add_option_group(output)

    # Hidden options for multi-list management
    parser.add_option("--profile-name", dest="profile_name", default="",
                      help=SUPPRESS_HELP)
    parser.add_option("--show-lists", dest="show_lists",
                      action="store_true", default=False,
                      help=SUPPRESS_HELP)

    return parser

def _main():
    """Run the command-line interface."""

    # Detect subcommands BEFORE option parsing.
    # Subcommands: new, which, switch
    # These appear as the first positional argument after -t/-l flags.
    # We need to scan raw args to find subcommands while allowing -t and -l first.
    raw_args = sys.argv[1:]

    # Extract -t and -l values first (they may appear before subcommands)
    taskdir = ''
    list_name = 'tasks'
    profile_name = os.environ.get('WARRIOR_PROFILE', '')
    quiet = False
    show_lists = False
    notes = False
    json_output = False
    print_clean = False
    export_format = ''
    remaining = []

    i = 0
    while i < len(raw_args):
        arg = raw_args[i]
        if arg in ('-t', '--task-dir') and i + 1 < len(raw_args):
            taskdir = raw_args[i + 1]
            i += 2
        elif arg in ('-l', '--list') and i + 1 < len(raw_args):
            list_name = raw_args[i + 1]
            i += 2
        elif arg == '--profile-name' and i + 1 < len(raw_args):
            profile_name = raw_args[i + 1]
            i += 2
        elif arg in ('-q', '--quiet'):
            quiet = True
            remaining.append(arg)
            i += 1
        elif arg in ('-n', '--notes'):
            notes = True
            i += 1
        elif arg == '--json':
            json_output = True
            i += 1
        elif arg == '--print':
            print_clean = True
            i += 1
        elif arg == '--export' and i + 1 < len(raw_args):
            export_format = raw_args[i + 1]
            i += 2
        elif arg == '--show-lists':
            show_lists = True
            i += 1
        else:
            remaining.append(arg)
            i += 1

    # Determine lists.yaml path
    lists_yaml_path = os.path.join(taskdir, '..', 'lists.yaml') if taskdir else 'lists.yaml'
    lists_yaml_path = os.path.normpath(lists_yaml_path)
    # list_dir is taskdir itself (the list/ directory)
    list_dir = taskdir if taskdir else '.'

    # Detect tag filter shorthand: first positional arg starting with #
    tag_filter = ''
    if remaining and re.match(r'^#[a-zA-Z0-9_-]+$', remaining[0]):
        tag_filter = remaining[0][1:]  # strip the #
        remaining.pop(0)

    # Handle --show-lists (invoked by `ww lists` or `lists` shell function)
    if show_lists:
        _cmd_show_lists(list_dir, lists_yaml_path, profile_name,
                        notes=notes, tag_filter=tag_filter, export_format=export_format)

    # Check for subcommands in remaining args
    if remaining and remaining[0] in ('new', 'which', 'switch'):
        subcmd = remaining[0]
        sub_args = remaining[1:]

        if subcmd == 'new':
            _cmd_new(sub_args, list_dir, lists_yaml_path)
        elif subcmd == 'which':
            _cmd_which(profile_name, list_name)
        elif subcmd == 'switch':
            _cmd_switch(sub_args, list_dir, lists_yaml_path, profile_name)

    # Fall through to original behavior — re-parse with optparse for full flag support
    # We need to reconstruct argv for optparse since we consumed some flags
    optparse_args = []
    if taskdir:
        optparse_args.extend(['-t', taskdir])
    optparse_args.extend(['-l', list_name])
    if profile_name:
        optparse_args.extend(['--profile-name', profile_name])
    if quiet:
        optparse_args.append('-q')
    # Pass through remaining args (which may include -g, -v, -f, -r, -e, --done, etc)
    optparse_args.extend(remaining)

    (options, args) = _build_parser().parse_args(optparse_args)

    # If tag_filter is set and not show_lists, treat as grep on '#tag'
    grep = options.grep
    if tag_filter and not grep:
        grep = '#' + tag_filter

    td = TaskDict(taskdir=options.taskdir, name=options.name)
    text = ' '.join(args).strip()

    if '\n' in text:
        _die('task text cannot contain newlines')

    try:
        if options.finish:
            td.finish_task(options.finish)
            td.write(options.delete)
        elif options.remove:
            td.remove_task(options.remove)
            td.write(options.delete)
        elif options.edit:
            td.edit_task(options.edit, text)
            td.write(options.delete)
        elif text:
            td.add_task(text, verbose=options.verbose, quiet=options.quiet)
            td.write(options.delete)
        else:
            # Show items
            pname = options.profile_name or os.environ.get('WARRIOR_PROFILE', '')

            # --json output
            if json_output:
                items = _tasks_to_json_list(td)
                # Apply grep/tag filter
                if grep:
                    items = [it for it in items if grep.lower() in it['text'].lower()]
                print(json.dumps(items, indent=2))
                sys.exit(0)

            # --print output (clean, no IDs)
            if print_clean:
                tasks = dict(td.tasks.items())
                for _, task in sorted(tasks.items()):
                    if grep.lower() in task['text'].lower() if grep else True:
                        parsed = _parse_item_text(task['text'])
                        # Print body only (no timestamps prefix in clean output)
                        body = parsed['body']
                        if parsed['timestamp']:
                            body = '[%s] %s' % (parsed['timestamp'], body)
                        print(body)
                sys.exit(0)

            # Normal display — print orientation header unless --quiet or special output
            if pname and not options.quiet:
                print('%s / %s' % (pname, options.name))

            kind = 'tasks' if not options.done else 'done'
            tasks = dict(getattr(td, kind).items())
            label = 'prefix' if not options.verbose else 'id'

            if not options.verbose:
                for task_id, prefix in _prefixes(tasks).items():
                    tasks[task_id]['prefix'] = prefix

            plen = max(map(lambda t: len(t[label]), tasks.values())) if tasks else 0
            for _, task in sorted(tasks.items()):
                if grep.lower() in task['text'].lower() if grep else True:
                    p = '%s - ' % task[label].ljust(plen) if not options.quiet else ''
                    print(p + task['text'])
                    # --notes: show note on next line
                    if notes:
                        parsed = _parse_item_text(task['text'])
                        if parsed['note']:
                            indent = ' ' * (plen + 3) if not options.quiet else ''
                            print('%s\u21b3 %s' % (indent, parsed['note']))

    except AmbiguousPrefix:
        e = sys.exc_info()[1]
        _die('the ID "%s" matches more than one task' % e.prefix)
    except UnknownPrefix:
        e = sys.exc_info()[1]
        _die('the ID "%s" does not match any task' % e.prefix)
    except BadFile as e:
        _die('%s - %s' % (e.problem, e.path))


if __name__ == '__main__':
    _main()
