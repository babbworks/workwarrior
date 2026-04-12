# Requirements Document

## Introduction

The Heuristic Compilation feature is a one-time (or periodic) build process that deeply analyzes the full workwarrior command syntax, studies how the AI agent translates natural language into commands, and compiles a comprehensive set of regex-based heuristic rules. These rules ship in `config/cmd-heuristics.yaml` and allow the CMD service to interpret natural language input without calling an LLM for routine operations. The system currently has 12 builtin rules; this process aims to produce hundreds of high-quality rules covering every valid command pattern across tasks, times, journals, ledgers, profiles, groups, models, ctrl, find, schedule, gun, next, mcp, browser, extensions, shortcuts, export, custom, questions, and delete operations.

## Glossary

- **Compiler**: The one-time build script (`bin/ww-compile-heuristics` or equivalent) that scans sources, generates rules, tests them, and writes the output YAML
- **Heuristic_Rule**: A single entry in `config/cmd-heuristics.yaml` consisting of a regex pattern, an action template, a confidence score, a source tag, and a usage count
- **CMD_Service**: The browser server endpoint (`POST /cmd/ai`) that accepts natural language and routes it through heuristic matching or AI translation
- **Command_Syntax_Registry**: The canonical command syntax file at `system/config/command-syntax.yaml` listing every valid ww command and its arguments
- **Heuristic_Engine**: The pattern-matching subsystem inside the CMD_Service that evaluates Heuristic_Rules against user input before falling back to AI
- **CMD_Log**: The JSONL log at `services/cmd/cmd.log` recording every command submission with route, input, output, and success status
- **AI_Route**: The code path that sends natural language to an LLM (ollama/openai) for translation into ww commands
- **Heuristic_Route**: The code path that matches natural language against Heuristic_Rules and executes directly without an LLM
- **Confidence_Threshold**: The minimum confidence value (currently 0.8) a Heuristic_Rule must meet for auto-execution
- **Rule_Source**: A tag indicating how a Heuristic_Rule was created: `builtin`, `compiled`, `ai-digest`, or `manual`

## Requirements

### Requirement 1: Command Syntax Scanning

**User Story:** As a developer, I want the Compiler to scan all command sources so that every valid ww command pattern is captured for heuristic generation.

#### Acceptance Criteria

1. WHEN invoked, THE Compiler SHALL parse `system/config/command-syntax.yaml` and extract every command syntax entry across all domains (profile, journal, ledger, service, group, model, ctrl, find, extensions, custom, schedule, next, gun, mcp, browser, questions, issues)
2. WHEN invoked, THE Compiler SHALL parse `bin/ww` and extract all command handler case branches, subcommand names, and argument patterns
3. WHEN invoked, THE Compiler SHALL scan service scripts in `services/*/` to extract additional command patterns not present in the Command_Syntax_Registry
4. WHEN invoked, THE Compiler SHALL scan `config/shortcuts.yaml` to extract shortcut aliases and their target commands
5. THE Compiler SHALL produce a structured intermediate representation listing every discovered command with its domain, subcommand, required arguments, and optional arguments
6. IF a command pattern in `bin/ww` is not present in the Command_Syntax_Registry, THEN THE Compiler SHALL flag the discrepancy in its output log

### Requirement 2: Natural Language Pattern Generation

**User Story:** As a developer, I want the Compiler to generate regex patterns for natural language variations of each command so that users can express commands in everyday English.

#### Acceptance Criteria

1. WHEN a command syntax entry is processed, THE Compiler SHALL generate at least six natural language regex variations per command (e.g., for `task add <desc>`: "add a task ...", "create a task ...", "new task ...", "make a task ...", "I need to ...", "can you add task ...")
2. THE Compiler SHALL generate patterns that capture variable arguments using named regex groups or positional capture groups compatible with the existing `$N` substitution format in `config/cmd-heuristics.yaml`
3. WHEN generating patterns for commands with optional arguments, THE Compiler SHALL produce separate patterns for the base command and for each optional argument combination
4. THE Compiler SHALL generate patterns that handle common English filler words (articles: "a", "the", "my"; prepositions: "to", "for", "on", "about", "in"; politeness: "please", "can you", "I want to", "I need to") as optional non-capturing groups
5. WHEN generating patterns for time-related arguments (due dates, tracking tags), THE Compiler SHALL recognize natural date expressions ("tomorrow", "next week", "friday", "in 3 days", "end of month", "next monday") and map them to the tool-native format (e.g., `due:friday`, `due:tomorrow`, `due:eom`)
6. THE Compiler SHALL assign a confidence score between 0.85 and 1.0 to each generated Heuristic_Rule based on pattern specificity: direct command passthrough receives 1.0, single-variation patterns receive 0.95, multi-variation patterns receive 0.90, and patterns with ambiguous captures receive 0.85
7. THE Compiler SHALL generate variations that cover imperative ("add task"), declarative ("I need a task for"), interrogative ("can you create a task"), and shorthand ("task: review budget due friday") forms

### Requirement 3: Multi-Command Composition Patterns

**User Story:** As a developer, I want the Compiler to generate patterns for compound natural language instructions so that users can express multi-step operations in a single sentence.

#### Acceptance Criteria

1. WHEN a natural language input contains conjunctions ("and", "then", "also", "plus") joining two recognizable command patterns, THE Heuristic_Engine SHALL split the input and produce multiple commands in sequence
2. THE Compiler SHALL generate composition patterns for common multi-command workflows: task creation with annotation, task creation with time tracking start, and task completion with time tracking stop
3. WHEN a composition pattern matches, THE Heuristic_Engine SHALL execute the commands in the order they appear in the action template, passing context (e.g., `LAST` task ID) between commands

### Requirement 4: Synthetic AI Translation Corpus and Digest

**User Story:** As a developer, I want the Compiler to generate a synthetic corpus of imagined AI translations so that the heuristic rules cover how users would naturally phrase commands, even without extensive real AI log data.

#### Acceptance Criteria

1. THE Compiler SHALL generate a synthetic corpus of at least 200 natural language inputs paired with their expected ww command translations, covering all command domains
2. THE synthetic corpus SHALL include variations in phrasing style: casual ("add a task for groceries"), formal ("please create a new task"), terse ("task groceries due tomorrow"), verbose ("I would like to create a new task called groceries that is due tomorrow with high priority"), and conversational ("hey can you make me a task to buy groceries")
3. WHEN the `--digest` flag is provided, THE Compiler SHALL ALSO read `services/cmd/cmd.log` and extract any entries where `route` is `ai` and `ok` is `true`, merging them with the synthetic corpus
4. THE Compiler SHALL use the synthetic corpus to validate generated regex patterns: each pattern must match at least one synthetic input and produce the correct command
5. WHEN a synthetic input is not matched by any generated rule, THE Compiler SHALL create a new rule to cover it and log the gap
6. THE synthetic corpus SHALL be written to `config/cmd-heuristics-corpus.yaml` for future reference and manual expansion by users

### Requirement 5: Rule Testing and Validation

**User Story:** As a developer, I want the Compiler to test generated patterns against sample inputs so that only correct rules are included in the output.

#### Acceptance Criteria

1. THE Compiler SHALL generate at least two sample natural language inputs per Heuristic_Rule and verify that the regex matches and the action template produces a syntactically valid ww command
2. WHEN a generated Heuristic_Rule fails its sample input test, THE Compiler SHALL exclude the rule from the output and log the failure with the pattern, sample input, and expected output
3. THE Compiler SHALL verify that no two generated rules match the same sample input with overlapping capture groups that would produce different commands
4. WHEN rule conflicts are detected, THE Compiler SHALL keep the rule with higher confidence and log the discarded rule
5. THE Compiler SHALL produce a test summary reporting: total rules generated, rules passed, rules failed, rules discarded due to conflicts, and coverage percentage (commands with at least one passing rule divided by total commands discovered)

### Requirement 6: YAML Output Generation

**User Story:** As a developer, I want the Compiler to output a comprehensive `config/cmd-heuristics.yaml` so that the Heuristic_Engine can load the rules at startup.

#### Acceptance Criteria

1. THE Compiler SHALL write the output to `config/cmd-heuristics.yaml`, preserving the existing YAML schema (threshold, rules array with pattern, action, confidence, source, count fields)
2. WHEN the output file already exists, THE Compiler SHALL merge new rules with existing rules: preserve `count` values from existing rules, update patterns where the compiled version has higher confidence, and append new rules
3. THE Compiler SHALL organize rules in the output file by domain sections (task, time, journal, ledger, profile, group, model, ctrl, find, schedule, gun, next, mcp, browser, extensions, custom, questions, shortcut, export, delete) with YAML comments marking each section
4. THE Compiler SHALL preserve any rules with source tag `manual` from the existing file without modification
5. THE Compiler SHALL include the `threshold` field at the top of the file, defaulting to 0.8 if not already set

### Requirement 7: Domain Coverage Completeness

**User Story:** As a developer, I want the compiled heuristics to cover every ww command domain so that routine operations across all functions work without AI.

#### Acceptance Criteria

1. THE Compiler SHALL generate Heuristic_Rules covering all task operations: add, list, done, start, stop, modify, annotate, delete, and filter expressions (project, tag, priority, due date)
2. THE Compiler SHALL generate Heuristic_Rules covering all time operations: start, stop, track, summary, tags, and duration queries
3. THE Compiler SHALL generate Heuristic_Rules covering all journal operations: add entry, list journals, remove journal, rename journal
4. THE Compiler SHALL generate Heuristic_Rules covering all ledger operations: add ledger, list ledgers, remove ledger, rename ledger
5. THE Compiler SHALL generate Heuristic_Rules covering all profile operations: create, list, info, delete, backup, import, restore, urgency subcommands, density subcommands, and UDA subcommands
6. THE Compiler SHALL generate Heuristic_Rules covering all administrative domains: group (create, list, show, add, remove, delete), model (list, providers, add-provider, remove-provider, add-model, set-default, remove-model, env, check, show), ctrl (status, ai-mode, ai-cmd, prompt-ww, prompt-ai, ui-model-indicator), find, schedule, next, gun, mcp, browser, extensions, custom, questions, shortcut, export, deps, and x (delete)
7. THE Compiler SHALL report a coverage metric: the percentage of commands from the Command_Syntax_Registry that have at least one Heuristic_Rule with confidence above the Confidence_Threshold

### Requirement 8: Heuristic Engine Integration

**User Story:** As a developer, I want the CMD_Service to load and apply the compiled heuristics so that matched inputs bypass the AI route.

#### Acceptance Criteria

1. WHEN the CMD_Service starts, THE Heuristic_Engine SHALL load all rules from `config/cmd-heuristics.yaml` and compile the regex patterns
2. WHEN a natural language input is received at `POST /cmd/ai`, THE Heuristic_Engine SHALL evaluate the input against all loaded rules before attempting the AI_Route
3. WHEN a Heuristic_Rule matches with confidence at or above the Confidence_Threshold, THE Heuristic_Engine SHALL execute the action template directly and set the response route to `heuristic`
4. WHEN a Heuristic_Rule matches and executes successfully, THE Heuristic_Engine SHALL increment the `count` field for that rule in memory (and periodically flush to disk)
5. IF no Heuristic_Rule matches with sufficient confidence, THEN THE Heuristic_Engine SHALL fall through to the AI_Route as the current system does
6. WHEN multiple Heuristic_Rules match the same input, THE Heuristic_Engine SHALL select the rule with the highest confidence score

### Requirement 9: Compilation Reporting

**User Story:** As a developer, I want the Compiler to produce a detailed report so that I can review what was generated and identify gaps.

#### Acceptance Criteria

1. WHEN compilation completes, THE Compiler SHALL write a report to stdout containing: total commands discovered, total rules generated, rules per domain, test pass rate, coverage percentage, and any flagged discrepancies
2. WHEN the `--verbose` flag is provided, THE Compiler SHALL include in the report: every generated rule with its sample inputs and test results
3. WHEN the `--digest` flag is used, THE Compiler SHALL include in the report: number of CMD_Log entries analyzed, number of AI-digest rules extracted, and any conflicts with existing rules
