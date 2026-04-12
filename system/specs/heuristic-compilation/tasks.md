# Implementation Plan: Heuristic Compilation

## Overview

Build `scripts/compile-heuristics.py` — a standalone Python 3 (stdlib + PyYAML) compiler that scans all ww command sources, generates regex-based heuristic rules with confidence scoring, validates them against a synthetic corpus, and outputs `config/cmd-heuristics.yaml`. Then integrate the heuristic engine into `services/browser/server.py` so matched inputs bypass the AI route. Finally, wire the CLI entry point `ww compile-heuristics`.

## Tasks

- [x] 1. Source Scanner — scan all command sources into an intermediate representation
  - [x] 1.1 Create `scripts/compile-heuristics.py` with the `CommandEntry` dataclass and `scan_command_syntax()` function
    - Parse `system/config/command-syntax.yaml`, iterate over all `commands` entries, extract domain, syntax strings, required/optional args, and aliases
    - Return a `list[CommandEntry]` with all fields populated
    - _Requirements: 1.1, 1.5_

  - [x] 1.2 Implement `scan_bin_ww()` to extract command patterns from `bin/ww`
    - Use regex to parse case-branch patterns (e.g., `profile|journal|...`) and their subcommand dispatching
    - Extract domain, subcommand, and argument patterns from each branch
    - _Requirements: 1.2, 1.5_

  - [x] 1.3 Implement `scan_service_scripts()` to scan `services/*/` for additional command patterns
    - Walk service directories, read shell/Python scripts, extract command patterns not in command-syntax.yaml
    - _Requirements: 1.3_

  - [x] 1.4 Implement `scan_shortcuts()` to parse `config/shortcuts.yaml`
    - Extract shortcut keys, their target commands, and categories
    - _Requirements: 1.4, 1.5_

  - [x] 1.5 Implement `build_command_inventory()` to aggregate, deduplicate, and flag discrepancies
    - Call all four scan functions, merge results, deduplicate by (domain, subcommand, syntax)
    - Compare bin/ww commands against command-syntax.yaml and flag any present in bin/ww but absent from the registry
    - Return `(list[CommandEntry], list[str])` — commands and discrepancy warnings
    - _Requirements: 1.5, 1.6_

  - [ ]* 1.6 Write property tests for Source Scanner (Hypothesis)
    - **Property 1: YAML Scanning Completeness** — generate random YAML structures with N commands across M domains, verify scanner extracts exactly N entries with all required fields
    - **Property 2: Discrepancy Detection** — generate two command sets, verify flagged discrepancies equal the exact set difference
    - **Validates: Requirements 1.1, 1.4, 1.5, 1.6**

  - [ ]* 1.7 Write unit tests for Source Scanner (pytest)
    - Test `scan_command_syntax()` against the real `system/config/command-syntax.yaml`
    - Test `scan_bin_ww()` against the real `bin/ww`
    - Test `scan_shortcuts()` against the real `config/shortcuts.yaml`
    - Test discrepancy detection with known mismatches
    - _Requirements: 1.1–1.6_

- [x] 2. Pattern Generator — generate regex variations per command with confidence scoring
  - [x] 2.1 Implement filler word constants and `assign_confidence()` function
    - Define `ARTICLES`, `PREPS`, `POLITE` as non-capturing optional regex groups
    - Implement confidence assignment: passthrough=1.0, imperative=0.95, declarative/interrogative/shorthand=0.90, verbose=0.85
    - _Requirements: 2.4, 2.6_

  - [x] 2.2 Implement `generate_patterns()` for a single `CommandEntry`
    - Generate 6+ regex variations: passthrough, imperative (verb synonyms), declarative, interrogative, shorthand, verbose
    - Build action templates with `$N` substitution from captured groups
    - Generate at least 2 sample inputs per rule for later validation
    - Handle optional arguments by producing separate patterns for base command and optional arg combinations
    - _Requirements: 2.1, 2.2, 2.3, 2.7_

  - [x] 2.3 Implement date expression mapping for time-related arguments
    - Define `DATE_PATTERNS` dict mapping natural expressions ("tomorrow", "next week", "friday", "in N days", "end of month", "next monday") to tool-native formats
    - Inject date sub-patterns into time-related command patterns
    - _Requirements: 2.5_

  - [ ]* 2.4 Write property tests for Pattern Generator (Hypothesis)
    - **Property 3: Pattern Variation Completeness** — for random CommandEntry, verify ≥6 variations covering all form types
    - **Property 4: Optional Argument Pattern Generation** — for commands with K>0 optional args, verify more patterns than equivalent with K=0
    - **Property 5: Filler Word Tolerance** — for generated rules, inserting filler words still matches and produces same action
    - **Property 6: Date Expression Mapping** — for each supported date expression, verify correct tool-native output
    - **Property 7: Confidence Assignment Correctness** — verify scores match pattern type rules and fall within [0.85, 1.0]
    - **Validates: Requirements 2.1–2.7**

  - [ ]* 2.5 Write unit tests for Pattern Generator (pytest)
    - Test pattern generation for specific commands: `task add`, `timew start`, `journal add`, `profile create`
    - Test date expression mapping for each supported format
    - Test edge cases: empty args, special characters in arguments
    - _Requirements: 2.1–2.7_

- [x] 3. Synthetic Corpus Generator — 200+ entries covering all domains and 5 phrasing styles
  - [x] 3.1 Implement `generate_synthetic_corpus()` function
    - For each domain in the command inventory, generate entries in 5 styles: casual, formal, terse, verbose, conversational
    - Ensure at least 200 total entries, every domain has at least one entry, each domain has entries in ≥3 styles
    - Return `list[CorpusEntry]` with input_text, expected_command, domain, style
    - _Requirements: 4.1, 4.2_

  - [x] 3.2 Implement `read_cmd_log_digest()` for `--digest` flag
    - Read `services/cmd/cmd.log` JSONL, extract entries where `route=ai` and `ok=true`
    - Convert to `CorpusEntry` objects, skip malformed lines with warning
    - _Requirements: 4.3_

  - [x] 3.3 Implement `merge_corpus()` and `write_corpus_yaml()`
    - Merge synthetic and digest corpus, deduplicate by input_text
    - Write to `config/cmd-heuristics-corpus.yaml` with timestamp and total count
    - _Requirements: 4.3, 4.6_

  - [ ]* 3.4 Write property tests for Corpus Generator (Hypothesis)
    - **Property 9: Corpus Domain and Style Coverage** — for random command inventory with D domains, verify ≥200 entries, every domain present, each domain has ≥3 styles
    - **Validates: Requirements 4.1, 4.2**

  - [ ]* 3.5 Write unit tests for Corpus Generator (pytest)
    - Test corpus generation produces correct structure
    - Test CMD log parsing with valid and malformed JSONL
    - Test merge deduplication
    - _Requirements: 4.1–4.6_

- [x] 4. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Validator / Tester — test rules against sample inputs, detect conflicts
  - [x] 5.1 Implement `validate_rule()` to test each rule against its sample inputs
    - For each rule, match sample inputs against the regex, apply action template substitution
    - Verify the produced command is syntactically valid (non-empty, starts with a known domain/command)
    - Return `list[TestResult]` per rule
    - _Requirements: 5.1_

  - [x] 5.2 Implement `detect_conflicts()` and `resolve_conflicts()`
    - Find pairs of rules that match the same sample input with different action outputs
    - Keep the rule with higher confidence, discard the other
    - _Requirements: 5.3, 5.4_

  - [x] 5.3 Implement `validate_corpus_coverage()` and gap-filling
    - Test all rules against the synthetic corpus
    - For corpus entries not matched by any rule, create new rules to cover them
    - _Requirements: 4.4, 4.5_

  - [x] 5.4 Implement `run_validation()` — full validation pipeline
    - Orchestrate: validate rules → detect/resolve conflicts → check corpus coverage → fill gaps
    - Return `ValidationReport` with total_rules, passed, failed, conflicts_discarded, coverage_pct, rules_per_domain, failures
    - _Requirements: 5.5, 7.7_

  - [ ]* 5.5 Write property tests for Validator (Hypothesis)
    - **Property 10: Pattern-Corpus Validation** — for each rule, at least one corpus entry matches and produces correct command
    - **Property 11: Gap-Filling Rule Creation** — for unmatched corpus entries, verify new rules are created
    - **Property 12: Rule Sample Validation** — each rule has ≥2 sample inputs that match and produce valid commands
    - **Property 13: Failed Rule Exclusion** — rules failing sample tests are excluded from final output
    - **Property 14: Conflict Resolution Correctness** — no two rules in final set match same input with different outputs; lower-confidence rule discarded
    - **Property 15: Report Metric Invariants** — passed + failed + discarded == total; coverage_pct == commands_with_passing_rule / total_commands * 100
    - **Validates: Requirements 4.4, 4.5, 5.1–5.5, 7.7**

  - [ ]* 5.6 Write unit tests for Validator (pytest)
    - Test conflict detection with known overlapping patterns
    - Test gap-filling with known unmatched corpus entries
    - Test report metric arithmetic
    - _Requirements: 5.1–5.5_

- [x] 6. YAML Merger / Output — merge with existing rules, organize by domain
  - [x] 6.1 Implement `load_existing_rules()` to read current `config/cmd-heuristics.yaml`
    - Parse YAML, return (config dict with threshold, list of existing rule dicts)
    - Handle missing or malformed file gracefully (backup malformed, treat as empty)
    - _Requirements: 6.1, 6.5_

  - [x] 6.2 Implement `merge_rules()` to combine existing and compiled rules
    - Preserve `count` values from existing rules when patterns match
    - Update pattern/confidence only when compiled version has strictly higher confidence
    - Preserve all rules with `source: manual` unchanged
    - Append new rules not present in existing set
    - _Requirements: 6.2, 6.4_

  - [x] 6.3 Implement `write_heuristics_yaml()` to write organized output
    - Group rules by domain, write YAML comment headers for each section
    - Include `threshold` field at top, default 0.8
    - Tag all new rules with `source: compiled`
    - _Requirements: 6.1, 6.3, 6.5_

  - [ ]* 6.4 Write property tests for YAML Merger (Hypothesis)
    - **Property 16: YAML Output Round-Trip** — write rules to YAML and re-read, verify all fields preserved exactly
    - **Property 17: Merge Preserves Counts and Updates Confidence** — verify count preservation and confidence-only updates
    - **Property 18: Manual Rules Immutability** — verify `source: manual` rules unchanged after merge
    - **Validates: Requirements 6.1, 6.2, 6.4**

  - [ ]* 6.5 Write unit tests for YAML Merger (pytest)
    - Test merge with real existing `config/cmd-heuristics.yaml`
    - Test domain section organization in output
    - Test handling of malformed existing file
    - _Requirements: 6.1–6.5_

- [x] 7. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Heuristic Engine Integration — load rules in server.py, match before AI
  - [x] 8.1 Implement `HeuristicEngine` class with `__init__` and `_load_rules()`
    - Load `config/cmd-heuristics.yaml`, compile all regex patterns into `CompiledRule` objects
    - Handle missing/invalid YAML gracefully (empty rule set, log warning)
    - Store threshold from YAML config
    - _Requirements: 8.1_

  - [x] 8.2 Implement `HeuristicEngine.match()` for single-command matching
    - Evaluate input against all compiled rules
    - Return highest-confidence match above threshold, or None
    - Handle empty action template substitution (treat as no-match)
    - _Requirements: 8.2, 8.3, 8.6_

  - [x] 8.3 Implement `increment_count()` and `flush_counts()` for usage tracking
    - Increment count in memory on successful match
    - Periodically flush updated counts back to YAML file
    - Handle flush failures gracefully (log warning, keep in memory)
    - _Requirements: 8.4_

  - [x] 8.4 Integrate `HeuristicEngine` into `services/browser/server.py` POST /cmd/ai handler
    - Instantiate engine at server startup
    - In the `/cmd/ai` handler, call `engine.match()` before the AI route
    - If match found: execute command directly, set route to `heuristic`, log result
    - If no match: fall through to existing AI route unchanged
    - _Requirements: 8.2, 8.3, 8.5_

  - [ ]* 8.5 Write property tests for Heuristic Engine (Hypothesis)
    - **Property 19: Engine Match Selection** — verify highest-confidence match returned; no match if all below threshold
    - **Property 20: Engine Count Increment** — verify matched rule count incremented by exactly 1, no other counts change
    - **Validates: Requirements 8.3, 8.4, 8.6**

  - [ ]* 8.6 Write unit tests for Heuristic Engine (pytest)
    - Test loading real `config/cmd-heuristics.yaml`
    - Test matching known inputs against builtin rules
    - Test fallback when no rules match
    - Test graceful handling of missing/invalid YAML
    - _Requirements: 8.1–8.6_

- [x] 9. Multi-Command Composition — split compound inputs on conjunctions
  - [x] 9.1 Implement `split_compound_input()` function
    - Split input on conjunctions ("and", "then", "also", "plus") using word-boundary regex
    - Return list of individual segments, stripped and non-empty
    - _Requirements: 3.1_

  - [x] 9.2 Implement `HeuristicEngine.match_compound()` for multi-command matching
    - Try compound split, match each segment independently
    - Support context passing (e.g., `LAST` task ID) between sequential commands
    - Fall through to AI route if any segment is unrecognizable
    - _Requirements: 3.1, 3.3_

  - [x] 9.3 Implement `generate_composition_patterns()` in the compiler
    - Generate patterns for common multi-command workflows: task creation + annotation, task creation + time tracking start, task completion + time tracking stop
    - _Requirements: 3.2_

  - [ ]* 9.4 Write property tests for Multi-Command Composition (Hypothesis)
    - **Property 8: Compound Input Splitting** — for two valid inputs A and B joined by any conjunction, verify split produces both commands in order
    - **Validates: Requirements 3.1**

  - [ ]* 9.5 Write unit tests for Multi-Command Composition (pytest)
    - Test splitting "add task groceries and start tracking time"
    - Test splitting with each conjunction type
    - Test fallback when segments are unrecognizable
    - _Requirements: 3.1–3.3_

- [x] 10. CLI Integration — `ww compile-heuristics` command in `bin/ww`
  - [x] 10.1 Add `compile-heuristics` case branch to `bin/ww`
    - Route to `python3 scripts/compile-heuristics.py` with passthrough of `--verbose`, `--digest`, and `--help` flags
    - _Requirements: 1.1 (invocation), 9.2, 9.3_

  - [x] 10.2 Implement CLI argument parsing in `scripts/compile-heuristics.py`
    - Use `argparse` for `--verbose`, `--digest`, `--help`, `--output` (default: `config/cmd-heuristics.yaml`)
    - Wire the main pipeline: scan → generate → corpus → validate → merge → write → report
    - _Requirements: 1.1, 4.3, 9.1–9.3_

  - [ ]* 10.3 Write unit tests for CLI integration (pytest)
    - Test argument parsing for all flag combinations
    - Test main pipeline end-to-end with real source files
    - _Requirements: 1.1, 4.3, 9.1–9.3_

- [x] 11. Compilation Report — coverage metrics, test pass rates
  - [x] 11.1 Implement report generation in the compiler
    - Print to stdout: total commands discovered, total rules generated, rules passed/failed/discarded, coverage percentage, per-domain breakdown, discrepancy list
    - _Requirements: 9.1_

  - [x] 11.2 Implement `--verbose` report mode
    - Include every generated rule with its sample inputs and test results
    - _Requirements: 9.2_

  - [x] 11.3 Implement `--digest` report additions
    - Include CMD_Log entries analyzed count, AI-digest rules extracted count, conflicts with existing rules
    - _Requirements: 9.3_

  - [ ]* 11.4 Write unit tests for report output (pytest)
    - Test report format and metric arithmetic
    - Test verbose output includes rule details
    - Test digest report includes log analysis stats
    - _Requirements: 9.1–9.3_

- [x] 12. Final Checkpoint — Full integration validation
  - Run full pipeline: `python3 scripts/compile-heuristics.py --verbose`
  - Verify `config/cmd-heuristics.yaml` is generated with rules organized by domain
  - Verify `config/cmd-heuristics-corpus.yaml` is generated with 200+ entries
  - Verify domain coverage metric meets expectations (Requirements 7.1–7.6)
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- The compiler is a single Python 3 script at `scripts/compile-heuristics.py` using stdlib + PyYAML only
- Property tests use Hypothesis; unit tests use pytest
- Each task references specific requirements for traceability
- Checkpoints at tasks 4, 7, and 12 ensure incremental validation
- The heuristic engine integration (task 8) modifies `services/browser/server.py` — the existing AI route remains as fallback
