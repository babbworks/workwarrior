#!/usr/bin/env python3
"""
Heuristic Compilation Script for Workwarrior CMD Service.

Scans all ww command sources, generates regex-based heuristic rules for
natural language → command translation, validates them against a synthetic
corpus, and outputs config/cmd-heuristics.yaml.

Usage:
    python3 scripts/compile-heuristics.py [--verbose] [--digest] [--output PATH]
    ww compile-heuristics [--verbose] [--digest]
"""

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


# ============================================================================
# Data Classes
# ============================================================================

@dataclass
class CommandEntry:
    domain: str
    subcommand: str
    syntax: str
    required_args: list = field(default_factory=list)
    optional_args: list = field(default_factory=list)
    aliases: list = field(default_factory=list)
    source: str = ""

@dataclass
class HeuristicRule:
    pattern: str
    action: str
    confidence: float
    source: str = "compiled"
    count: int = 0
    domain: str = ""
    sample_inputs: list = field(default_factory=list)

@dataclass
class CorpusEntry:
    input_text: str
    expected_command: str
    domain: str
    style: str = "casual"

@dataclass
class TestResult:
    rule_pattern: str
    sample_input: str
    matched: bool
    produced_command: str
    expected_command: str
    passed: bool

@dataclass
class ValidationReport:
    total_rules: int = 0
    passed: int = 0
    failed: int = 0
    conflicts_discarded: int = 0
    coverage_pct: float = 0.0
    rules_per_domain: dict = field(default_factory=dict)
    failures: list = field(default_factory=list)
    gaps_filled: int = 0


# ============================================================================
# Constants
# ============================================================================

ARTICLES = r"(?:a |the |my |an )?"
PREPS = r"(?:to |for |on |about |in |from )?"
POLITE = r"(?:please |can you |I want to |I need to |could you |would you )?"
FILLER = POLITE + ARTICLES

# Verb synonyms per action
VERB_SYNONYMS = {
    "add": ["add", "create", "new", "make"],
    "list": ["list", "show", "display", "view", "see"],
    "delete": ["delete", "remove", "drop", "destroy"],
    "info": ["info", "show", "details", "about", "describe"],
    "start": ["start", "begin", "launch", "run", "activate"],
    "stop": ["stop", "end", "finish", "halt", "pause"],
    "done": ["done", "complete", "finish", "close", "mark done"],
    "help": ["help", "usage", "how to", "guide"],
    "install": ["install", "setup", "set up", "get"],
    "enable": ["enable", "turn on", "activate"],
    "disable": ["disable", "turn off", "deactivate"],
    "backup": ["backup", "back up", "save", "archive"],
    "rename": ["rename", "change name"],
    "modify": ["modify", "change", "update", "edit", "set"],
}

DATE_EXPRESSIONS = {
    "today": "today",
    "tomorrow": "tomorrow",
    "yesterday": "yesterday",
    "next week": "1w",
    "next month": "1mo",
    "friday": "friday",
    "monday": "monday",
    "tuesday": "tuesday",
    "wednesday": "wednesday",
    "thursday": "thursday",
    "saturday": "saturday",
    "sunday": "sunday",
    "end of month": "eom",
    "end of week": "eow",
    "end of year": "eoy",
}

CONJUNCTIONS = re.compile(r'\b(?:and|then|also|plus)\b', re.IGNORECASE)


# ============================================================================
# Multi-Command Composition
# ============================================================================

def split_compound_input(input_text: str) -> list:
    """Split input on conjunctions into individual segments.

    Splits *input_text* on word-boundary conjunctions (and, then, also, plus),
    strips whitespace from each segment, and filters out empty segments.
    If no conjunctions are found the original text is returned as a
    single-element list.
    """
    segments = CONJUNCTIONS.split(input_text)
    segments = [s.strip() for s in segments if s.strip()]
    return segments if segments else [input_text]


def generate_composition_patterns() -> list:
    """Generate multi-command patterns for common workflows:
    - task creation + annotation
    - task creation + time tracking start
    - task completion + time tracking stop
    """
    rules = []

    # ---- Workflow 1: task creation + annotation ----
    task_add_verbs = "|".join(["add", "create", "make", "new"])
    annot_verbs = "|".join(["annotate", "note", "comment"])

    # "add task X and annotate it with Y"
    rules.append(HeuristicRule(
        pattern=(
            f"^(?:{POLITE})(?:{task_add_verbs}) {ARTICLES}task {PREPS}(.+?)"
            r"\s+(?:and|then|also|plus)\s+"
            f"(?:{annot_verbs})(?: it| that)? (?:with |saying )?(.+)"
        ),
        action="task add $1\ntask_annotate LAST $2",
        confidence=0.90,
        source="compiled",
        domain="task",
        sample_inputs=[
            "add task fix login and annotate it with check mobile layout",
            "create a task deploy API then note it with needs review",
        ],
    ))

    # "create task X with annotation Y" / "add task X with note Y"
    rules.append(HeuristicRule(
        pattern=(
            f"^(?:{POLITE})(?:{task_add_verbs}) {ARTICLES}task {PREPS}(.+?)"
            r"\s+with\s+(?:annotation|note|comment)\s+(.+)"
        ),
        action="task add $1\ntask_annotate LAST $2",
        confidence=0.90,
        source="compiled",
        domain="task",
        sample_inputs=[
            "create task update docs with annotation needs screenshots",
            "add a task review PR with note check test coverage",
        ],
    ))

    # "make task X and add a note Y"
    rules.append(HeuristicRule(
        pattern=(
            f"^(?:{POLITE})(?:{task_add_verbs}) {ARTICLES}task {PREPS}(.+?)"
            r"\s+(?:and|then|also|plus)\s+"
            f"(?:add |leave |write ){ARTICLES}(?:note|annotation|comment) (.+)"
        ),
        action="task add $1\ntask_annotate LAST $2",
        confidence=0.90,
        source="compiled",
        domain="task",
        sample_inputs=[
            "create a task refactor auth and add a note needs tests",
            "make task fix bug then write a comment blocked by API",
        ],
    ))

    # ---- Workflow 2: task creation + time tracking start ----
    start_verbs = "|".join(["start", "begin"])

    # "add task X and start tracking time"
    rules.append(HeuristicRule(
        pattern=(
            f"^(?:{POLITE})(?:{task_add_verbs}) {ARTICLES}task {PREPS}(.+?)"
            r"\s+(?:and|then|also|plus)\s+"
            f"(?:{start_verbs}) (?:tracking|timing|tracking time|time)"
        ),
        action="task add $1\ntimew start $1",
        confidence=0.90,
        source="compiled",
        domain="task",
        sample_inputs=[
            "add task design review and start tracking time",
            "create a task code review then begin tracking",
        ],
    ))

    # "create task X and start working on it"
    rules.append(HeuristicRule(
        pattern=(
            f"^(?:{POLITE})(?:{task_add_verbs}) {ARTICLES}task {PREPS}(.+?)"
            r"\s+(?:and|then|also|plus)\s+"
            f"(?:{start_verbs}) (?:working on it|working|work)"
        ),
        action="task add $1\ntimew start $1",
        confidence=0.90,
        source="compiled",
        domain="task",
        sample_inputs=[
            "add task API migration and start working on it",
            "create a task write tests then begin work",
        ],
    ))

    # "add task X and track it" / "create task X and time it"
    rules.append(HeuristicRule(
        pattern=(
            f"^(?:{POLITE})(?:{task_add_verbs}) {ARTICLES}task {PREPS}(.+?)"
            r"\s+(?:and|then|also|plus)\s+"
            r"(?:track|time) (?:it|that)"
        ),
        action="task add $1\ntimew start $1",
        confidence=0.90,
        source="compiled",
        domain="task",
        sample_inputs=[
            "add task client meeting and track it",
            "create a task sprint planning then time it",
        ],
    ))

    # ---- Workflow 3: task completion + time tracking stop ----
    done_verbs = "|".join(["finish", "complete", "done", "close"])
    stop_verbs = "|".join(["stop", "end", "halt"])

    # "finish task N and stop tracking"
    rules.append(HeuristicRule(
        pattern=(
            f"^(?:{POLITE})(?:{done_verbs}) (?:task )?(\\d+)"
            r"\s+(?:and|then|also|plus)\s+"
            f"(?:{stop_verbs}) (?:tracking|timing|tracking time|time|the timer)"
        ),
        action="task $1 done\ntimew stop",
        confidence=0.90,
        source="compiled",
        domain="task",
        sample_inputs=[
            "finish task 5 and stop tracking",
            "complete task 12 then end timing",
        ],
    ))

    # "mark task N done and stop tracking"
    rules.append(HeuristicRule(
        pattern=(
            r"^(?:mark )?task (\d+) (?:as )?(?:done|complete|finished)"
            r"\s+(?:and|then|also|plus)\s+"
            f"(?:{stop_verbs}) (?:tracking|timing|tracking time|time|the timer)"
        ),
        action="task $1 done\ntimew stop",
        confidence=0.90,
        source="compiled",
        domain="task",
        sample_inputs=[
            "mark task 8 done and stop tracking",
            "task 3 done then stop time",
        ],
    ))

    # "finish task N and stop working"
    rules.append(HeuristicRule(
        pattern=(
            f"^(?:{POLITE})(?:{done_verbs}) (?:task )?(\\d+)"
            r"\s+(?:and|then|also|plus)\s+"
            f"(?:{stop_verbs}) (?:working|work)"
        ),
        action="task $1 done\ntimew stop",
        confidence=0.90,
        source="compiled",
        domain="task",
        sample_inputs=[
            "finish task 7 and stop working",
            "complete task 10 then end work",
        ],
    ))

    return rules


# ============================================================================
# Source Scanner
# ============================================================================

def scan_command_syntax(yaml_path: str) -> list:
    """Parse command-syntax.yaml and extract all command entries."""
    commands = []
    if not os.path.isfile(yaml_path):
        return commands
    
    with open(yaml_path) as f:
        content = f.read()
    
    # Simple YAML parsing for the commands section
    in_commands = False
    current_domain = ""
    current_syntaxes = []
    
    for line in content.splitlines():
        if line.strip() == "commands:":
            in_commands = True
            continue
        if not in_commands:
            continue
        
        # New domain entry
        m = re.match(r'^  - domain:\s*"?([^"]+)"?', line)
        if m:
            # Save previous domain's commands
            if current_domain and current_syntaxes:
                for syn in current_syntaxes:
                    cmd = _parse_syntax(syn, current_domain, "command-syntax.yaml")
                    if cmd:
                        commands.append(cmd)
            current_domain = m.group(1).strip()
            current_syntaxes = []
            continue
        
        # Syntax line
        m2 = re.match(r'^\s+- "(.+)"', line)
        if m2 and current_domain:
            current_syntaxes.append(m2.group(1))
    
    # Don't forget the last domain
    if current_domain and current_syntaxes:
        for syn in current_syntaxes:
            cmd = _parse_syntax(syn, current_domain, "command-syntax.yaml")
            if cmd:
                commands.append(cmd)
    
    return commands


def _parse_syntax(syntax: str, domain: str, source: str) -> Optional[CommandEntry]:
    """Parse a syntax string like 'ww profile create <name>' into a CommandEntry."""
    parts = syntax.split()
    if not parts:
        return None
    
    # Strip leading 'ww' or 'q' or 'i'
    if parts[0] in ("ww", "q", "i"):
        parts = parts[1:]
    if not parts:
        return None
    
    # First token is domain (or domain.subdomain), rest is subcommand + args
    cmd_domain = parts[0] if not domain.startswith(parts[0]) else domain
    
    subcommand = ""
    required_args = []
    optional_args = []
    
    for i, p in enumerate(parts[1:], 1):
        if p.startswith("<") and p.endswith(">"):
            required_args.append(p[1:-1])
        elif p.startswith("[") and p.endswith("]"):
            optional_args.append(p[1:-1])
        elif p.startswith("[") or p.endswith("]"):
            optional_args.append(p.strip("[]"))
        elif p.startswith("-"):
            optional_args.append(p)
        elif not subcommand:
            subcommand = p
        else:
            # Additional positional args
            required_args.append(p)
    
    return CommandEntry(
        domain=domain,
        subcommand=subcommand,
        syntax=syntax,
        required_args=required_args,
        optional_args=optional_args,
        source=source,
    )


def scan_bin_ww(script_path: str) -> list:
    """Parse bin/ww case branches to extract command patterns."""
    commands = []
    if not os.path.isfile(script_path):
        return commands
    
    with open(script_path) as f:
        content = f.read()
    
    # Find main dispatcher case branches
    # Pattern: domain) or domain|alias)
    for m in re.finditer(r'^\s+([\w|.-]+)\)\s*$', content, re.MULTILINE):
        branch = m.group(1)
        domains = branch.split("|")
        primary = domains[0]
        if primary in ("*", '""', "help", "--help", "-h", "--version", "-v"):
            continue
        commands.append(CommandEntry(
            domain=primary,
            subcommand="",
            syntax=f"ww {primary}",
            aliases=domains[1:] if len(domains) > 1 else [],
            source="bin/ww",
        ))
    
    return commands


def scan_shortcuts(yaml_path: str) -> list:
    """Parse shortcuts.yaml and extract shortcut aliases."""
    commands = []
    if not os.path.isfile(yaml_path):
        return commands
    
    with open(yaml_path) as f:
        content = f.read()
    
    for m in re.finditer(r'^\s+(\w+):', content, re.MULTILINE):
        name = m.group(1)
        if name in ("shortcuts",):
            continue
        commands.append(CommandEntry(
            domain="shortcut",
            subcommand=name,
            syntax=f"ww shortcut {name}",
            source="shortcuts.yaml",
        ))
    
    return commands


def build_command_inventory(ww_base: str) -> tuple:
    """Aggregate all sources, deduplicate, flag discrepancies."""
    syntax_path = os.path.join(ww_base, "system", "config", "command-syntax.yaml")
    ww_path = os.path.join(ww_base, "bin", "ww")
    shortcuts_path = os.path.join(ww_base, "config", "shortcuts.yaml")
    
    syntax_cmds = scan_command_syntax(syntax_path)
    ww_cmds = scan_bin_ww(ww_path)
    shortcut_cmds = scan_shortcuts(shortcuts_path)
    
    all_cmds = syntax_cmds + shortcut_cmds
    
    # Flag discrepancies: commands in bin/ww not in command-syntax.yaml
    syntax_domains = {c.domain for c in syntax_cmds}
    warnings = []
    for c in ww_cmds:
        if c.domain not in syntax_domains and c.domain not in ("version", "help", "e", "d"):
            warnings.append(f"bin/ww has '{c.domain}' not in command-syntax.yaml")
            all_cmds.append(c)
    
    return all_cmds, warnings


# ============================================================================
# Pattern Generator
# ============================================================================

def generate_patterns(cmd: CommandEntry) -> list:
    """Generate 6+ regex variations for a single command."""
    rules = []
    domain = cmd.domain.split(".")[0]  # handle profile.density etc.
    sub = cmd.subcommand
    
    if not sub:
        return rules
    
    # Build the action template
    action = _build_action(cmd)
    if not action:
        return rules
    
    # Arg capture pattern
    arg_pattern = _build_arg_capture(cmd)
    
    # Get verb synonyms
    verbs = VERB_SYNONYMS.get(sub, [sub])
    verb_group = "|".join(re.escape(v) for v in verbs)
    
    # 1. Direct passthrough (confidence 1.0)
    passthrough = f"^{re.escape(domain)} {re.escape(sub)}"
    if arg_pattern:
        passthrough += r"\s+" + arg_pattern
    rules.append(HeuristicRule(
        pattern=passthrough,
        action=action,
        confidence=1.0,
        domain=domain,
        sample_inputs=[f"{domain} {sub} test-value"],
    ))
    
    # 2. Imperative with verb synonyms (confidence 0.95)
    for verb in verbs[:3]:
        imp = f"^(?:{verb}) {ARTICLES}{re.escape(domain)}"
        if arg_pattern:
            imp += r"\s+" + PREPS + arg_pattern
        rules.append(HeuristicRule(
            pattern=imp,
            action=action,
            confidence=0.95,
            domain=domain,
            sample_inputs=[f"{verb} a {domain} test-value", f"{verb} {domain} test-value"],
        ))
    
    # 3. Declarative (confidence 0.90)
    decl = f"^(?:I want to |I need to ){ARTICLES}(?:{verb_group}) {ARTICLES}{re.escape(domain)}"
    if arg_pattern:
        decl += r"\s+" + PREPS + arg_pattern
    rules.append(HeuristicRule(
        pattern=decl,
        action=action,
        confidence=0.90,
        domain=domain,
        sample_inputs=[f"I want to {verbs[0]} a {domain} test-value"],
    ))
    
    # 4. Interrogative (confidence 0.90)
    interr = f"^(?:can you |could you |would you )(?:{verb_group}) {ARTICLES}{re.escape(domain)}"
    if arg_pattern:
        interr += r"\s+" + PREPS + arg_pattern
    rules.append(HeuristicRule(
        pattern=interr,
        action=action,
        confidence=0.90,
        domain=domain,
        sample_inputs=[f"can you {verbs[0]} a {domain} test-value"],
    ))
    
    # 5. Shorthand (confidence 0.90)
    if arg_pattern:
        short = f"^{re.escape(domain)}:\\s*" + arg_pattern
        rules.append(HeuristicRule(
            pattern=short,
            action=action,
            confidence=0.90,
            domain=domain,
            sample_inputs=[f"{domain}: test-value"],
        ))
    
    # 6. Verbose/natural (confidence 0.85)
    verbose = f"^{POLITE}(?:{verb_group}) {ARTICLES}(?:new )?{re.escape(domain)}"
    if arg_pattern:
        verbose += r"(?:\s+(?:called|named|for|about|to))?\s+" + arg_pattern
    rules.append(HeuristicRule(
        pattern=verbose,
        action=action,
        confidence=0.85,
        domain=domain,
        sample_inputs=[f"please {verbs[0]} a new {domain} called test-value"],
    ))
    
    return rules


def _build_action(cmd: CommandEntry) -> str:
    """Build the action template from a CommandEntry."""
    domain = cmd.domain.split(".")[0]
    sub = cmd.subcommand
    
    # Special handling for different domains
    if domain == "task" and sub == "add":
        return "task add $1"
    elif domain == "task" and sub in ("start", "stop", "done"):
        return f"task $1 {sub}"
    elif domain == "task" and sub == "annotate":
        return "task $1 annotate $2"
    elif domain == "task" and sub == "modify":
        return "task $1 modify $2"
    elif domain in ("timew", "time"):
        if sub == "start":
            return "timew start $1"
        elif sub == "stop":
            return "timew stop"
        elif sub == "track":
            return "timew track $1"
    elif domain == "journal" and sub == "add":
        return "journal_add $1"
    elif domain == "profile":
        if cmd.required_args:
            return f"profile {sub} $1"
        return f"profile {sub}"
    elif domain == "group":
        if cmd.required_args:
            return f"group {sub} $1"
        return f"group {sub}"
    elif domain == "model":
        if cmd.required_args:
            return f"model {sub} $1"
        return f"model {sub}"
    elif domain == "ctrl":
        if cmd.required_args:
            return f"ctrl {sub} $1"
        return f"ctrl {sub}"
    
    # Generic: domain subcommand [args]
    if cmd.required_args:
        return f"{domain} {sub} $1"
    return f"{domain} {sub}"


def _build_arg_capture(cmd: CommandEntry) -> str:
    """Build a regex capture group for command arguments."""
    if cmd.required_args:
        return "(.+)"
    return ""


def generate_task_specific_patterns() -> list:
    """Generate task-specific patterns with due date and priority handling."""
    rules = []
    
    # Task add with various natural phrasings
    task_verbs = "|".join(["add", "create", "new", "make"])
    
    # Basic task creation
    rules.append(HeuristicRule(
        pattern=f"^(?:{POLITE})(?:{task_verbs}) {ARTICLES}task {PREPS}(.+)",
        action="task add $1",
        confidence=0.92,
        domain="task",
        sample_inputs=[
            "create a task to review the budget",
            "add task fix the login page",
            "make a task for grocery shopping",
            "new task deploy the API",
            "please create a task to update docs",
            "I need to add a task for code review",
        ],
    ))
    
    # Task with due date
    for date_word, date_val in DATE_EXPRESSIONS.items():
        rules.append(HeuristicRule(
            pattern=f"^(?:{POLITE})(?:{task_verbs}) {ARTICLES}task {PREPS}(.+?)\\s+(?:due |by ){date_word}",
            action=f"task add $1 due:{date_val}",
            confidence=0.90,
            domain="task",
            sample_inputs=[f"create a task to review budget due {date_word}"],
        ))
    
    # Task with "due in N days"
    rules.append(HeuristicRule(
        pattern=f"^(?:{POLITE})(?:{task_verbs}) {ARTICLES}task {PREPS}(.+?)\\s+due in (\\d+) days?",
        action="task add $1 due:$2d",
        confidence=0.90,
        domain="task",
        sample_inputs=["create a task to review budget due in 3 days"],
    ))
    
    # Task with priority
    rules.append(HeuristicRule(
        pattern=f"^(?:{POLITE})(?:{task_verbs}) {ARTICLES}(?:high |medium |low )?(?:priority )?task {PREPS}(.+)",
        action="task add $1 priority:H",
        confidence=0.88,
        domain="task",
        sample_inputs=["create a high priority task to fix the bug"],
    ))
    
    # Task with annotation
    rules.append(HeuristicRule(
        pattern=f"^(?:{POLITE})(?:{task_verbs}) {ARTICLES}task {PREPS}(.+?)\\s+(?:with )?(?:annotation|note|comment)[: ]+(.+)",
        action="task add $1\ntask_annotate LAST $2",
        confidence=0.88,
        domain="task",
        sample_inputs=[
            "create a task fix login with annotation: check mobile layout",
            "add task go shopping with note get milk and bread",
        ],
    ))
    
    # Task start/stop/done by description
    for action_word in ["start", "stop", "done"]:
        action_verbs = VERB_SYNONYMS.get(action_word, [action_word])
        verb_group = "|".join(action_verbs)
        rules.append(HeuristicRule(
            pattern=f"^(?:{POLITE})(?:{verb_group}) (?:task |working on )?(.+)",
            action=f"task $1 {action_word}",
            confidence=0.85,
            domain="task",
            sample_inputs=[f"{action_word} task 5", f"{action_verbs[0]} working on the API"],
        ))
    
    return rules


def generate_time_specific_patterns() -> list:
    """Generate time tracking patterns."""
    rules = []
    
    start_verbs = "|".join(["start", "begin", "track", "log"])
    
    rules.append(HeuristicRule(
        pattern=f"^(?:{POLITE})(?:{start_verbs}) (?:tracking |timing |time on |working on )?(.+)",
        action="timew start $1",
        confidence=0.90,
        domain="time",
        sample_inputs=[
            "start tracking project meeting",
            "begin working on API review",
            "track time on code review",
            "log time for client call",
            "please start timing the design session",
            "I need to track my work on the report",
        ],
    ))
    
    rules.append(HeuristicRule(
        pattern=f"^(?:{POLITE})(?:stop|end|finish|halt|pause) (?:tracking|timing|time|working|work)",
        action="timew stop",
        confidence=0.95,
        domain="time",
        sample_inputs=[
            "stop tracking",
            "end timing",
            "finish working",
            "stop time",
            "please stop tracking time",
            "halt tracking",
        ],
    ))
    
    rules.append(HeuristicRule(
        pattern=f"^(?:{POLITE})(?:record|log|track) (\\S+) (?:of |for |on )?(.+)",
        action="timew track $1 $2",
        confidence=0.88,
        domain="time",
        sample_inputs=["record 30min of project meeting", "log 1h for code review"],
    ))
    
    return rules


def generate_journal_specific_patterns() -> list:
    """Generate journal entry patterns."""
    rules = []
    
    write_verbs = "|".join(["add", "write", "log", "record", "note", "jot"])
    
    rules.append(HeuristicRule(
        pattern=f"^(?:{POLITE})(?:{write_verbs}) {ARTICLES}(?:journal |entry |note )?(?:about |for |on )?(.+)",
        action="journal_add $1",
        confidence=0.88,
        domain="journal",
        sample_inputs=[
            "add a journal entry about today's progress",
            "write a note about the meeting",
            "log that we shipped the feature",
            "record a journal entry for the standup",
            "jot down notes about the design review",
            "please note that the client approved the proposal",
        ],
    ))
    
    return rules


def generate_profile_specific_patterns() -> list:
    """Generate profile management patterns."""
    rules = []
    
    rules.append(HeuristicRule(
        pattern=f"^(?:{POLITE})(?:list|show|display|view) {ARTICLES}(?:all )?profiles?",
        action="profile list",
        confidence=0.95,
        domain="profile",
        sample_inputs=["list profiles", "show all profiles", "view my profiles",
                       "display profiles", "can you list the profiles", "show me profiles"],
    ))
    
    rules.append(HeuristicRule(
        pattern=f"^(?:{POLITE})(?:create|add|new|make) {ARTICLES}(?:new )?profile (?:called |named )?(.+)",
        action="profile create $1",
        confidence=0.92,
        domain="profile",
        sample_inputs=["create a new profile called work", "add profile client-x",
                       "make a new profile named personal", "new profile test",
                       "please create a profile called dev", "I want to create a profile work"],
    ))
    
    rules.append(HeuristicRule(
        pattern=f"^(?:{POLITE})(?:show|info|details|about|describe) (?:profile )?(.+)",
        action="profile info $1",
        confidence=0.85,
        domain="profile",
        sample_inputs=["show profile acme", "info about work", "details for demo",
                       "describe profile personal", "can you show me profile acme", "profile info work"],
    ))
    
    return rules


def generate_all_patterns(commands: list) -> list:
    """Generate patterns for all commands plus domain-specific patterns."""
    all_rules = []
    
    # Generate from command inventory
    for cmd in commands:
        all_rules.extend(generate_patterns(cmd))
    
    # Add domain-specific patterns with richer natural language
    all_rules.extend(generate_task_specific_patterns())
    all_rules.extend(generate_time_specific_patterns())
    all_rules.extend(generate_journal_specific_patterns())
    all_rules.extend(generate_profile_specific_patterns())
    
    # Add multi-command composition patterns
    all_rules.extend(generate_composition_patterns())
    
    return all_rules


# ============================================================================
# Synthetic Corpus Generator
# ============================================================================

def generate_synthetic_corpus(commands: list) -> list:
    """Generate 200+ corpus entries covering all domains and 5 phrasing styles."""
    corpus = []
    
    # Task domain — most entries since it's the most used
    task_entries = [
        ("add a task to review the budget", "task add review the budget", "casual"),
        ("please create a new task for the API review", "task add API review", "formal"),
        ("task fix login page due:tomorrow", "task add fix login page due:tomorrow", "terse"),
        ("I would like to create a new task called quarterly report that is due next friday", "task add quarterly report due:friday", "verbose"),
        ("hey can you make me a task to buy groceries", "task add buy groceries", "conversational"),
        ("create task deploy staging server", "task add deploy staging server", "casual"),
        ("new task write unit tests priority:H", "task add write unit tests priority:H", "terse"),
        ("I need to add a task for code review due tomorrow", "task add code review due:tomorrow", "formal"),
        ("add task update documentation with annotation: needs screenshots", "task add update documentation\ntask_annotate LAST needs screenshots", "casual"),
        ("make a high priority task to fix the production bug", "task add fix the production bug priority:H", "casual"),
        ("create a task called design review due in 3 days", "task add design review due:3d", "casual"),
        ("task: weekly standup prep due monday", "task add weekly standup prep due:monday", "terse"),
        ("could you create a task for the client presentation", "task add client presentation", "conversational"),
        ("I want to add a task to refactor the auth module", "task add refactor the auth module", "formal"),
        ("please add task migrate database due next week", "task add migrate database due:1w", "formal"),
        ("start task 5", "task 5 start", "terse"),
        ("begin working on task 12", "task 12 start", "casual"),
        ("can you start task number 3", "task 3 start", "conversational"),
        ("stop task 5", "task 5 stop", "terse"),
        ("finish task 8", "task 8 done", "casual"),
        ("mark task 3 as done", "task 3 done", "casual"),
        ("complete task 15", "task 15 done", "casual"),
        ("I'm done with task 7", "task 7 done", "conversational"),
        ("annotate task 5 with: needs review from team lead", "task 5 annotate needs review from team lead", "casual"),
        ("add a note to task 3: blocked by API changes", "task 3 annotate blocked by API changes", "casual"),
    ]
    
    # Time domain
    time_entries = [
        ("start tracking project meeting", "timew start project meeting", "casual"),
        ("please begin timing the design session", "timew start design session", "formal"),
        ("timew start code-review", "timew start code-review", "terse"),
        ("I would like to start tracking my time on the quarterly report", "timew start quarterly report", "verbose"),
        ("hey start tracking time on client call", "timew start client call", "conversational"),
        ("stop tracking", "timew stop", "casual"),
        ("please stop timing", "timew stop", "formal"),
        ("timew stop", "timew stop", "terse"),
        ("end time tracking", "timew stop", "casual"),
        ("I'm done tracking time", "timew stop", "conversational"),
        ("record 30min of project meeting", "timew track 30min project meeting", "casual"),
        ("log 1h for code review", "timew track 1h code review", "casual"),
        ("track 2h on design work", "timew track 2h design work", "casual"),
        ("begin tracking API development", "timew start API development", "casual"),
        ("start timing the standup", "timew start standup", "casual"),
    ]
    
    # Journal domain
    journal_entries = [
        ("add a journal entry about today's progress", "journal_add today's progress", "casual"),
        ("please write a note about the meeting outcomes", "journal_add meeting outcomes", "formal"),
        ("journal: shipped the new feature today", "journal_add shipped the new feature today", "terse"),
        ("I would like to record a journal entry about the design decisions we made", "journal_add design decisions we made", "verbose"),
        ("hey jot down that the client approved the proposal", "journal_add client approved the proposal", "conversational"),
        ("log that we completed the sprint", "journal_add completed the sprint", "casual"),
        ("note: team morale is high after the launch", "journal_add team morale is high after the launch", "terse"),
        ("write in my journal about the architecture review", "journal_add architecture review", "casual"),
        ("record a note about the budget meeting", "journal_add budget meeting", "casual"),
        ("add entry: quarterly goals reviewed and approved", "journal_add quarterly goals reviewed and approved", "terse"),
        ("list journals", "journal list", "terse"),
        ("show my journals", "journal list", "casual"),
        ("add a new journal called work-log", "journal add work-log", "casual"),
        ("create journal personal", "journal add personal", "terse"),
        ("remove journal old-notes", "journal remove old-notes", "casual"),
    ]
    
    # Ledger domain
    ledger_entries = [
        ("list ledgers", "ledger list", "terse"),
        ("show my ledgers", "ledger list", "casual"),
        ("add a new ledger called business", "ledger add business", "casual"),
        ("create ledger taxes", "ledger add taxes", "terse"),
        ("remove ledger old-accounts", "ledger remove old-accounts", "casual"),
    ]
    
    # Profile domain
    profile_entries = [
        ("list profiles", "profile list", "terse"),
        ("show all profiles", "profile list", "casual"),
        ("create a new profile called work", "profile create work", "casual"),
        ("please create profile client-x", "profile create client-x", "formal"),
        ("new profile personal", "profile create personal", "terse"),
        ("I want to create a profile for my side project", "profile create side-project", "verbose"),
        ("can you make me a new profile called freelance", "profile create freelance", "conversational"),
        ("show profile acme", "profile info acme", "casual"),
        ("profile info demo", "profile info demo", "terse"),
        ("delete profile test", "profile delete test", "terse"),
        ("backup profile work", "profile backup work", "casual"),
        ("please back up my work profile", "profile backup work", "formal"),
    ]
    
    # Group domain
    group_entries = [
        ("list groups", "group list", "terse"),
        ("show all groups", "group list", "casual"),
        ("create a group called focus with work and personal", "group create focus work personal", "casual"),
        ("add profile client-x to group focus", "group add focus client-x", "casual"),
        ("remove profile test from group focus", "group remove focus test", "casual"),
        ("delete group old-team", "group delete old-team", "casual"),
        ("show group focus", "group show focus", "casual"),
    ]
    
    # Model domain
    model_entries = [
        ("list models", "model list", "terse"),
        ("show available models", "model list", "casual"),
        ("list model providers", "model providers", "casual"),
        ("check model environment", "model check", "casual"),
        ("set default model to llama3", "model set-default llama3", "casual"),
        ("show model env variables", "model env", "casual"),
    ]
    
    # CTRL domain
    ctrl_entries = [
        ("show ctrl status", "ctrl status", "terse"),
        ("turn on AI", "ctrl ai-mode local-only", "casual"),
        ("disable AI", "ctrl ai-mode off", "casual"),
        ("enable AI with remote access", "ctrl ai-mode local+remote", "casual"),
        ("check AI status", "ctrl ai-status", "casual"),
        ("show settings", "ctrl status", "casual"),
    ]
    
    # Schedule domain
    schedule_entries = [
        ("enable schedule", "schedule enable", "terse"),
        ("disable scheduling", "schedule disable", "casual"),
        ("show schedule status", "schedule status", "casual"),
        ("run the scheduler", "schedule run", "casual"),
        ("do a dry run of the schedule", "schedule run --dry-run", "casual"),
        ("install the scheduler", "schedule install", "casual"),
    ]
    
    # Next domain
    next_entries = [
        ("what should I work on next", "next", "conversational"),
        ("show next task", "next", "casual"),
        ("next", "next", "terse"),
        ("what's the next task", "next", "conversational"),
        ("recommend a task", "next", "casual"),
    ]
    
    # Gun domain
    gun_entries = [
        ("create a task series for ML Course with 10 lectures", "gun create ML_Course -p 10 -u Lecture", "casual"),
        ("gun create CLRS -p 12 -u Chapter --interval 7d", "gun create CLRS -p 12 -u Chapter --interval 7d", "terse"),
        ("make a series of 5 exercises for math", "gun create math -p 5 -u Exercise", "casual"),
    ]
    
    # Sword domain
    sword_entries = [
        ("split task 5 into 3 parts", "sword 5 -p 3", "casual"),
        ("sword 12 -p 4 --interval 2d", "sword 12 -p 4 --interval 2d", "terse"),
        ("break task 8 into 5 subtasks", "sword 8 -p 5", "casual"),
        ("slice task 3 into 2 phases", "sword 3 -p 2 --prefix Phase", "casual"),
    ]
    
    # Find domain
    find_entries = [
        ("search for invoice", "find invoice", "casual"),
        ("find budget in journals", "find --type journal budget", "casual"),
        ("search across all profiles for meeting notes", "find meeting notes", "casual"),
    ]
    
    # Export domain
    export_entries = [
        ("export data as json", "export json", "casual"),
        ("export profile data", "export", "terse"),
    ]
    
    # Deps domain
    deps_entries = [
        ("check dependencies", "deps check", "casual"),
        ("install dependencies", "deps install", "casual"),
    ]
    
    # Version/help
    misc_entries = [
        ("show version", "version", "casual"),
        ("what version is this", "version", "conversational"),
        ("help", "help", "terse"),
        ("show help", "help", "casual"),
    ]
    
    # Combine all
    all_entries = (task_entries + time_entries + journal_entries + ledger_entries +
                   profile_entries + group_entries + model_entries + ctrl_entries +
                   schedule_entries + next_entries + gun_entries + sword_entries +
                   find_entries + export_entries + deps_entries + misc_entries)
    
    for input_text, expected_cmd, style in all_entries:
        domain = expected_cmd.split()[0] if expected_cmd else "misc"
        # Map to canonical domain names
        if domain in ("task", "task_annotate"):
            domain = "task"
        elif domain in ("timew",):
            domain = "time"
        elif domain in ("journal_add",):
            domain = "journal"
        corpus.append(CorpusEntry(
            input_text=input_text,
            expected_command=expected_cmd,
            domain=domain,
            style=style,
        ))
    
    return corpus


def read_cmd_log_digest(log_path: str) -> tuple:
    """Read cmd.log JSONL, extract entries where route=ai and ok=true.

    Returns a tuple of (list[CorpusEntry], int, int) where:
    - list[CorpusEntry]: extracted digest entries
    - int: count of malformed lines skipped
    - int: total lines analyzed from the log
    """
    entries = []
    malformed = 0
    total_lines = 0

    if not os.path.isfile(log_path):
        print(f"  ⚠ CMD log not found: {log_path}")
        return entries, malformed, total_lines

    with open(log_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            total_lines += 1
            try:
                obj = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                malformed += 1
                continue

            if not isinstance(obj, dict):
                malformed += 1
                continue

            route = obj.get("route")
            ok = obj.get("ok")
            command_text = obj.get("command")
            commands_list = obj.get("commands")

            if route != "ai" or ok is not True:
                continue

            if not command_text or not commands_list:
                malformed += 1
                continue

            if not isinstance(commands_list, list) or len(commands_list) == 0:
                malformed += 1
                continue

            expected = commands_list[0] if len(commands_list) == 1 else "\n".join(commands_list)
            domain = expected.split()[0] if expected else "misc"

            entries.append(CorpusEntry(
                input_text=command_text,
                expected_command=expected,
                domain=domain,
                style="ai-digest",
            ))

    return entries, malformed, total_lines


def merge_corpus(synthetic: list, digest: list) -> list:
    """Merge synthetic and digest corpus, deduplicating by input_text."""
    seen = set()
    merged = []
    for entry in synthetic:
        if entry.input_text not in seen:
            seen.add(entry.input_text)
            merged.append(entry)
    for entry in digest:
        if entry.input_text not in seen:
            seen.add(entry.input_text)
            merged.append(entry)
    return merged


def write_corpus_yaml(corpus: list, output_path: str):
    """Write corpus to YAML file."""
    with open(output_path, "w") as f:
        f.write(f"# Synthetic Heuristic Corpus\n")
        f.write(f"generated: \"{datetime.now().isoformat()}\"\n")
        f.write(f"total_entries: {len(corpus)}\n")
        f.write(f"entries:\n")
        for entry in corpus:
            f.write(f"  - input: \"{entry.input_text}\"\n")
            f.write(f"    command: \"{entry.expected_command}\"\n")
            f.write(f"    domain: {entry.domain}\n")
            f.write(f"    style: {entry.style}\n")


# ============================================================================
# Validator / Tester
# ============================================================================

def validate_rule(rule: HeuristicRule) -> list:
    """Test a rule against its sample inputs."""
    results = []
    try:
        compiled = re.compile(rule.pattern, re.IGNORECASE)
    except re.error:
        results.append(TestResult(rule.pattern, "", False, "", "", False))
        return results
    
    for sample in rule.sample_inputs:
        m = compiled.search(sample)
        if m:
            # Apply substitution
            produced = rule.action
            for i, g in enumerate(m.groups(), 1):
                if g:
                    produced = produced.replace(f"${i}", g.strip())
            results.append(TestResult(rule.pattern, sample, True, produced, "", True))
        else:
            results.append(TestResult(rule.pattern, sample, False, "", "", False))
    
    return results


def validate_all_rules(rules: list) -> tuple:
    """Validate all rules and return (passed_rules, report)."""
    report = ValidationReport()
    report.total_rules = len(rules)
    passed_rules = []
    
    for rule in rules:
        results = validate_rule(rule)
        any_passed = any(r.passed for r in results)
        if any_passed:
            report.passed += 1
            passed_rules.append(rule)
        else:
            report.failed += 1
            report.failures.extend(results)
    
    # Count per domain
    for rule in passed_rules:
        d = rule.domain
        report.rules_per_domain[d] = report.rules_per_domain.get(d, 0) + 1
    
    return passed_rules, report


def detect_conflicts(rules: list) -> list:
    """Find pairs of rules that match the same input with different outputs.
    
    For each rule's sample_inputs, check if any other rule also matches that
    input. If two rules match the same input but produce different action
    outputs, they conflict. Returns a list of (rule_a, rule_b) tuples.
    """
    conflicts = []
    seen_pairs = set()
    
    # Pre-compile all patterns, skip rules with invalid regex
    compiled_rules = []
    for rule in rules:
        try:
            compiled_rules.append((rule, re.compile(rule.pattern, re.IGNORECASE)))
        except re.error:
            continue
    
    for i, (rule_a, regex_a) in enumerate(compiled_rules):
        for sample in rule_a.sample_inputs:
            match_a = regex_a.search(sample)
            if not match_a:
                continue
            # Compute the action output for rule_a on this sample
            action_a = rule_a.action
            for gi, g in enumerate(match_a.groups(), 1):
                if g:
                    action_a = action_a.replace(f"${gi}", g.strip())
            
            for j, (rule_b, regex_b) in enumerate(compiled_rules):
                if i == j:
                    continue
                # Avoid duplicate pairs
                pair_key = (min(id(rule_a), id(rule_b)), max(id(rule_a), id(rule_b)))
                if pair_key in seen_pairs:
                    continue
                
                match_b = regex_b.search(sample)
                if not match_b:
                    continue
                # Compute the action output for rule_b on this sample
                action_b = rule_b.action
                for gi, g in enumerate(match_b.groups(), 1):
                    if g:
                        action_b = action_b.replace(f"${gi}", g.strip())
                
                if action_a != action_b:
                    conflicts.append((rule_a, rule_b))
                    seen_pairs.add(pair_key)
    
    return conflicts


def resolve_conflicts(conflicts: list, rules: list) -> list:
    """Keep higher-confidence rule, discard the other. Returns filtered list.
    
    For each conflict pair, the rule with lower confidence is removed.
    If both have equal confidence, the first one encountered is kept.
    """
    to_discard = set()
    for rule_a, rule_b in conflicts:
        if rule_a.confidence >= rule_b.confidence:
            to_discard.add(id(rule_b))
        else:
            to_discard.add(id(rule_a))
    
    return [r for r in rules if id(r) not in to_discard]


def validate_corpus_coverage(rules: list, corpus: list) -> list:
    """Return corpus entries not matched by any rule (gaps).

    For each corpus entry, check if any rule's regex matches the entry's
    input_text. If no rule matches, the entry is a gap.
    """
    # Pre-compile all rule patterns, skip invalid ones
    compiled_rules = []
    for rule in rules:
        try:
            compiled_rules.append(re.compile(rule.pattern, re.IGNORECASE))
        except re.error:
            continue

    gaps = []
    for entry in corpus:
        matched = False
        for regex in compiled_rules:
            if regex.search(entry.input_text):
                matched = True
                break
        if not matched:
            gaps.append(entry)

    return gaps


def fill_gaps(gaps: list) -> list:
    """Create new HeuristicRules to cover unmatched corpus entries.

    For each gap, build a rule using an escaped regex of the input_text
    with confidence 0.85 and source 'compiled-gap'.
    """
    new_rules = []
    for entry in gaps:
        escaped = re.escape(entry.input_text)
        pattern = f"^{escaped}$"
        new_rules.append(HeuristicRule(
            pattern=pattern,
            action=entry.expected_command,
            confidence=0.85,
            source="compiled-gap",
            count=0,
            domain=entry.domain,
            sample_inputs=[entry.input_text],
        ))
    return new_rules


# ============================================================================
# YAML Output
# ============================================================================

def load_existing_rules(yaml_path: str) -> tuple:
    """Load existing cmd-heuristics.yaml. Returns (threshold, existing_rules)."""
    if not os.path.isfile(yaml_path):
        return 0.8, []
    
    threshold = 0.8
    rules = []
    
    with open(yaml_path) as f:
        content = f.read()
    
    # Parse threshold
    m = re.search(r'^threshold:\s*([\d.]+)', content, re.MULTILINE)
    if m:
        threshold = float(m.group(1))
    
    # Parse rules
    in_rules = False
    current = {}
    for line in content.splitlines():
        if line.strip() == "rules:":
            in_rules = True
            continue
        if not in_rules:
            continue
        
        if line.strip().startswith("- pattern:"):
            if current:
                rules.append(current)
            current = {"pattern": line.split(":", 1)[1].strip().strip('"')}
        elif line.strip().startswith("action:"):
            current["action"] = line.split(":", 1)[1].strip().strip('"')
        elif line.strip().startswith("confidence:"):
            current["confidence"] = float(line.split(":", 1)[1].strip())
        elif line.strip().startswith("source:"):
            current["source"] = line.split(":", 1)[1].strip()
        elif line.strip().startswith("count:"):
            current["count"] = int(line.split(":", 1)[1].strip())
    
    if current:
        rules.append(current)
    
    return threshold, rules


def merge_rules(existing: list, compiled: list) -> list:
    """Merge compiled rules with existing, preserving counts and manual rules."""
    existing_by_pattern = {r.get("pattern", ""): r for r in existing}
    merged = []
    seen_patterns = set()
    
    # First: preserve all manual rules unchanged
    for r in existing:
        if r.get("source") == "manual":
            merged.append(r)
            seen_patterns.add(r.get("pattern", ""))
    
    # Then: merge compiled rules
    for rule in compiled:
        p = rule.pattern
        if p in seen_patterns:
            continue
        
        entry = {
            "pattern": p,
            "action": rule.action,
            "confidence": rule.confidence,
            "source": rule.source,
            "count": 0,
        }
        
        # Preserve count from existing if pattern matches
        if p in existing_by_pattern:
            entry["count"] = existing_by_pattern[p].get("count", 0)
            # Only update confidence if compiled is higher
            if rule.confidence <= existing_by_pattern[p].get("confidence", 0):
                entry["confidence"] = existing_by_pattern[p]["confidence"]
        
        merged.append(entry)
        seen_patterns.add(p)
    
    # Add remaining existing rules not in compiled set
    for r in existing:
        p = r.get("pattern", "")
        if p not in seen_patterns:
            merged.append(r)
            seen_patterns.add(p)
    
    return merged


def write_heuristics_yaml(threshold: float, rules: list, output_path: str):
    """Write config/cmd-heuristics.yaml organized by domain sections."""
    # Group by domain
    by_domain = {}
    for r in rules:
        d = r.get("domain", "misc") if isinstance(r, dict) else getattr(r, "domain", "misc")
        if d not in by_domain:
            by_domain[d] = []
        by_domain[d].append(r)
    
    with open(output_path, "w") as f:
        f.write("# CMD Heuristic Rules — compiled by scripts/compile-heuristics.py\n")
        f.write(f"# Generated: {datetime.now().isoformat()}\n")
        f.write(f"# Total rules: {len(rules)}\n\n")
        f.write(f"threshold: {threshold}\n\n")
        f.write("rules:\n")
        
        domain_order = ["task", "time", "journal", "ledger", "profile", "group",
                        "model", "ctrl", "schedule", "next", "gun", "sword",
                        "find", "export", "deps", "extensions", "custom",
                        "questions", "shortcut", "browser", "mcp", "tui",
                        "issues", "misc"]
        
        for domain in domain_order:
            domain_rules = by_domain.pop(domain, [])
            if not domain_rules:
                continue
            f.write(f"\n  # --- {domain.title()} ---\n")
            for r in domain_rules:
                if isinstance(r, dict):
                    p = r.get("pattern", "")
                    a = r.get("action", "")
                    c = r.get("confidence", 0.9)
                    s = r.get("source", "compiled")
                    cnt = r.get("count", 0)
                else:
                    p, a, c, s, cnt = r.pattern, r.action, r.confidence, r.source, r.count
                f.write(f'  - pattern: "{p}"\n')
                f.write(f'    action: "{a}"\n')
                f.write(f"    confidence: {c}\n")
                f.write(f"    source: {s}\n")
                f.write(f"    count: {cnt}\n")
        
        # Any remaining domains
        for domain, domain_rules in by_domain.items():
            f.write(f"\n  # --- {domain.title()} ---\n")
            for r in domain_rules:
                if isinstance(r, dict):
                    p = r.get("pattern", "")
                    a = r.get("action", "")
                    c = r.get("confidence", 0.9)
                    s = r.get("source", "compiled")
                    cnt = r.get("count", 0)
                else:
                    p, a, c, s, cnt = r.pattern, r.action, r.confidence, r.source, r.count
                f.write(f'  - pattern: "{p}"\n')
                f.write(f'    action: "{a}"\n')
                f.write(f"    confidence: {c}\n")
                f.write(f"    source: {s}\n")
                f.write(f"    count: {cnt}\n")


# ============================================================================
# Main Pipeline
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Compile heuristic rules for the CMD service",
        prog="compile-heuristics",
    )
    parser.add_argument("--verbose", action="store_true", help="Show detailed output")
    parser.add_argument("--digest", action="store_true", help="Also analyze CMD log")
    parser.add_argument("--output", default=None, help="Output YAML path")
    parser.add_argument("--ww-base", default=os.environ.get("WW_BASE", os.path.expanduser("~/ww")),
                        help="Workwarrior base directory")
    args = parser.parse_args()
    
    ww_base = args.ww_base
    output_path = args.output or os.path.join(ww_base, "config", "cmd-heuristics.yaml")
    corpus_path = os.path.join(ww_base, "config", "cmd-heuristics-corpus.yaml")
    
    print("=== Heuristic Compilation ===\n")
    
    # Step 1: Scan
    print("Scanning command sources...")
    commands, warnings = build_command_inventory(ww_base)
    print(f"  Commands discovered: {len(commands)}")
    for w in warnings:
        print(f"  ⚠ {w}")
    
    # Step 2: Generate patterns
    print("\nGenerating patterns...")
    rules = generate_all_patterns(commands)
    print(f"  Rules generated: {len(rules)}")
    
    # Step 3: Generate corpus
    print("\nGenerating synthetic corpus...")
    corpus = generate_synthetic_corpus(commands)
    print(f"  Synthetic corpus entries: {len(corpus)}")

    # Step 3b: Digest — merge CMD log entries if --digest
    digest_entries = []
    digest_malformed = 0
    digest_total_lines = 0
    digest_conflicts = 0
    if args.digest:
        log_path = os.path.join(ww_base, "services", "cmd", "cmd.log")
        print(f"\nReading CMD log digest: {log_path}")
        digest_entries, digest_malformed, digest_total_lines = read_cmd_log_digest(log_path)
        print(f"  AI-digest entries extracted: {len(digest_entries)}")
        if digest_malformed:
            print(f"  Malformed lines skipped: {digest_malformed}")
        pre_merge_count = len(corpus)
        corpus = merge_corpus(corpus, digest_entries)
        print(f"  Merged corpus entries: {len(corpus)}")

    print(f"  Total corpus entries: {len(corpus)}")
    
    # Step 4: Validate
    print("\nValidating rules...")
    passed_rules, report = validate_all_rules(rules)
    print(f"  Passed: {report.passed}")
    print(f"  Failed: {report.failed}")
    
    # Step 4b: Detect and resolve conflicts
    print("\nDetecting conflicts...")
    conflicts = detect_conflicts(passed_rules)
    if conflicts:
        resolved_rules = resolve_conflicts(conflicts, passed_rules)
        report.conflicts_discarded = len(passed_rules) - len(resolved_rules)
        passed_rules = resolved_rules
        print(f"  Conflicts found: {len(conflicts)}")
        print(f"  Rules discarded: {report.conflicts_discarded}")
    else:
        print("  No conflicts found")
    
    # Step 4c: Corpus coverage and gap-filling
    print("\nChecking corpus coverage...")
    gaps = validate_corpus_coverage(passed_rules, corpus)
    if gaps:
        gap_rules = fill_gaps(gaps)
        passed_rules.extend(gap_rules)
        report.gaps_filled = len(gap_rules)
        print(f"  Gaps found: {len(gaps)}")
        print(f"  Gap-filling rules created: {report.gaps_filled}")
    else:
        print("  Full coverage — no gaps")
    report.coverage_pct = round(
        ((len(corpus) - len(gaps)) / len(corpus) * 100) if corpus else 0.0, 1
    )
    
    # Step 5: Load existing and merge
    print("\nMerging with existing rules...")
    threshold, existing = load_existing_rules(output_path)
    merged = merge_rules(existing, passed_rules)
    print(f"  Existing rules: {len(existing)}")
    print(f"  Merged total: {len(merged)}")

    # Detect digest conflicts with existing rules
    if args.digest and digest_entries:
        existing_compiled = []
        for r in existing:
            try:
                existing_compiled.append((re.compile(r.get("pattern", ""), re.IGNORECASE), r))
            except re.error:
                continue
        for entry in digest_entries:
            for regex, ex_rule in existing_compiled:
                m = regex.search(entry.input_text)
                if m:
                    # Existing rule matches this digest input — check if action differs
                    produced = ex_rule.get("action", "")
                    for i, g in enumerate(m.groups(), 1):
                        if g:
                            produced = produced.replace(f"${i}", g.strip())
                    if produced != entry.expected_command:
                        digest_conflicts += 1
                    break
    
    # Step 6: Write output
    print(f"\nWriting {output_path}...")
    write_heuristics_yaml(threshold, merged, output_path)
    
    print(f"Writing {corpus_path}...")
    write_corpus_yaml(corpus, corpus_path)
    
    # Step 7: Report
    print("\n=== Compilation Report ===")
    print(f"Commands discovered: {len(commands)}")
    print(f"Rules generated:     {len(rules)}")
    print(f"Rules passed:        {report.passed}")
    print(f"Rules failed:        {report.failed}")
    print(f"Rules discarded:     {report.conflicts_discarded} (conflicts)")
    print(f"Gaps filled:         {report.gaps_filled}")
    print(f"Coverage:            {report.coverage_pct}%")
    print(f"Merged total:        {len(merged)}")
    print(f"Corpus entries:      {len(corpus)}")

    if args.digest:
        print(f"\n--- Digest Report ---")
        print(f"CMD Log entries analyzed:       {digest_total_lines}")
        print(f"AI-digest entries extracted:    {len(digest_entries)}")
        print(f"Malformed lines skipped:        {digest_malformed}")
        print(f"Conflicts with existing rules:  {digest_conflicts}")

    print(f"\nPer-domain breakdown:")
    for d, count in sorted(report.rules_per_domain.items()):
        print(f"  {d:20s} {count} rules")
    
    if args.verbose:
        print(f"\n=== Detailed Rule Report ===")

        # Group passed rules by domain
        rules_by_domain = {}
        for rule in passed_rules:
            d = rule.domain or "misc"
            if d not in rules_by_domain:
                rules_by_domain[d] = []
            rules_by_domain[d].append(rule)

        for domain in sorted(rules_by_domain.keys()):
            domain_rules = rules_by_domain[domain]
            print(f"\n--- {domain.title()} ({len(domain_rules)} rules) ---")
            for rule in domain_rules:
                print(f"  Pattern:    {rule.pattern[:80]}")
                print(f"  Action:     {rule.action}")
                print(f"  Confidence: {rule.confidence}")
                print(f"  Domain:     {rule.domain}")
                results = validate_rule(rule)
                if rule.sample_inputs:
                    print(f"  Samples:")
                    for res in results:
                        status = "PASS" if res.passed else "FAIL"
                        print(f"    [{status}] {res.sample_input}")
                print()

        if report.failures:
            print(f"\nFailed rules ({len(report.failures)}):")
            for f in report.failures[:20]:
                print(f"  pattern: {f.rule_pattern[:60]}")
                print(f"  sample:  {f.sample_input}")
    
    print(f"\n✓ Done. Output: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
