#!/bin/bash

export PATH="$HOME/.local/bin:$PATH"


# -- Terminal Aliases
alias src="source ~/.bashrc"
# alias bash="nano ~/.bashrc"
alias c="clear"
alias cl="c && list"
alias copyl='fc -ln -1 | pbcopy'

# -- Terminal Behavior
#shopt -s


# -- Hledger Override of Default Setup
function hledger() {
  if [[ -n "$LEDGER_FILE" ]]; then
    command hledger -f "$LEDGER_FILE" "$@"
  else
    command hledger "$@"
  fi
}

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# -- Exports
export PATH="$HOME/ww/bin:$PATH"


# -- SUBLIME (command followed by path/to/file)
export EDITOR="subl -w"

# -- Confirmation of Alternative Workwarrior BASHRC

#export ACTIVE_BASHRC="$HOME/ww/terminals/bash/bashrc_ww"


# -- COLLECTED WORKWARRIOR ALIASES
alias u="task udas"
alias tm="timew"
alias tms="timew start"
alias tsum="timew summary :ids"
alias list='task list'
alias add='task add'
alias tw='timew'
alias time='timew'
alias tal="alias | grep -E 'task'"
alias tp="task project:"


# Main help menu
alias h="$HOME/ww/services/help/menu-help.sh"


# --- Workwarrior Help Aliases ---
alias h="$HOME/ww/services/help/menu-help.sh"
alias who="$HOME/ww/services/help/primary/who.sh"
alias what="$HOME/ww/services/help/primary/what.sh"
alias where="$HOME/ww/services/help/primary/where.sh"
alias why="$HOME/ww/services/help/primary/why.sh"
alias when="$HOME/ww/services/help/primary/when.sh"
alias how="$HOME/ww/services/help/primary/how.sh"

# -- GLOBAL WORKWARRIOR COMMANDS\

function p-list() {
  "$HOME/ww/services/profile/subservices/manage-profiles.sh" list
}
alias new-j="$HOME/ww/functions/journals/scripts/add_journal_current.sh"

alias p-manage="$HOME/ww/services/profile/subservices/manage-profiles.sh"
alias udas="$HOME/ww/services/profile/subservices/uda-manager.sh"
alias installed-pythons="$HOME/ww/services/find/installed-pythons.sh"
alias new-todo="$HOME/ww/functions/todos/scripts/add-todo-lists.sh"                        

# -- PYTHON

alias py13='python3.13'
alias py12='python3.12'
alias py11='python3.11'




# -- WW Management Scripts
alias new-journal="$HOME/ww/functions/journals/scripts/add_journal.sh"





# -- WORKWARRIOR (aka "WW") ------------------------------------

# -- This file (bashrc_ww) is organized from highest level components for WW \
# -- down to its Secondary and Ancillary Elements.
# -- 
# -- SECTIONS:
# -- Groups
# -- Profiles
# -- Kits
# -- Tools
# -- Extensions
# -- Tool Setups
# -- Attributes
# -- Stats
# -- Shortcuts
# -- Naming Conventions


# -- Group Creation
# -- Alias: ""

# -- Profile Creation
# -- Alias: "ww-new"
# -- Script(s) employed:
# ---- ~/scripts/taskwarrior/create-ww-profile.sh

alias p-new='$HOME/ww/services/profile/subservices/create-ww-profile.sh'

# -- Profile Selection
# -- Function: activiates a profile's taskrc file, taskwarrior database and \
# -- a timewarrior database contained within the profile folder.
# -- Selecting of profile via alias also states name of Profile Group.
# -- Group names recorded into functions below.

# -- Profile Switching for Group: Base
# --- Workwarrior Core Functions ---

# Global 'j' function for journaling
function j() {
  if [[ -z "$TASKDATA" ]]; then # Check TASKDATA directly
    echo "Error: No Workwarrior profile is currently active. TASKDATA is not set. Please use 'p-<profile-name>' first." >&2
    return 1
  fi
  local current_profile_base=$(dirname "$TASKDATA") # Derive base from TASKDATA
  if [[ ! -f "$current_profile_base/jrnl.yaml" ]]; then
    echo "Error: jrnl.yaml not found for current profile at '$current_profile_base/jrnl.yaml'." >&2
    return 1
  fi
  jrnl --config-file "$current_profile_base/jrnl.yaml" "$@"
}

# Global 'l' function for hledger
function l() {
  if [[ -z "$TASKDATA" ]]; then # Check TASKDATA directly
    echo "Error: No Workwarrior profile is currently active. TASKDATA is not set. Please use 'p-<profile-name>' first." >&2
    return 1
  fi
  local current_profile_base=$(dirname "$TASKDATA") # Derive base from TASKDATA
  local ledger_file="$current_profile_base/ledgers/$(basename "$current_profile_base").journal" # Derive ledger name from base
  if [[ ! -f "$ledger_file" ]]; then
    echo "Error: Default ledger file not found for current profile at '$ledger_file'." >&2
    return 1
  fi
  hledger -f "$ledger_file" "$@"
}

function t() {
  # Check if Workwarrior profile is active
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No Workwarrior profile is currently active. Please activate one with 'p-<profile-name>'." >&2
    return 1
  fi

  # Validate WORKWARRIOR_BASE exists
  if [[ ! -d "$WORKWARRIOR_BASE" ]]; then
    echo "Error: WORKWARRIOR_BASE directory '$WORKWARRIOR_BASE' does not exist." >&2
    return 1
  fi

  # Set up paths
  local todo_dir="$WORKWARRIOR_BASE/todo"
  local profile_name
  profile_name=$(basename "$WORKWARRIOR_BASE")
  local default_todo_file="$todo_dir/${profile_name}_default.todo"
  local t_script="$HOME/ww/tools/todo/t/t.py"

  # Validate t.py script exists
  if [[ ! -f "$t_script" ]]; then
    echo "Error: t.py script not found at '$t_script'" >&2
    return 1
  fi

  # Create todo directory if it doesn't exist
  if [[ ! -d "$todo_dir" ]]; then
    mkdir -p "$todo_dir" || {
      echo "Error: Failed to create todo directory '$todo_dir'" >&2
      return 1
    }
  fi

  # Create default todo file if it doesn't exist
  if [[ ! -f "$default_todo_file" ]]; then
    touch "$default_todo_file" || {
      echo "Error: Failed to create default todo file '$default_todo_file'" >&2
      return 1
    }
  fi

  # Handle no arguments - show default list
  if [[ $# -eq 0 ]]; then
    python3 "$t_script" -t "$todo_dir" -l "${profile_name}_default.todo"
    return $?
  fi

  # Handle special "list" command to show all todo files
  if [[ "$1" == "list" ]]; then
    echo "Available todo lists for profile '$profile_name':"
    local found_lists=0
    for todo_file in "$todo_dir"/${profile_name}_*.todo; do
      if [[ -f "$todo_file" ]]; then
        local list_name=$(basename "$todo_file" .todo)
        list_name=${list_name#${profile_name}_}
        echo "  $list_name"
        found_lists=1
      fi
    done
    if [[ $found_lists -eq 0 ]]; then
      echo "  No todo lists found."
    fi
    return 0
  fi

  # Check if first argument is a valid todo list
  local first_arg="$1"
  local potential_list_file="$todo_dir/${profile_name}_${first_arg}.todo"
  
  if [[ -f "$potential_list_file" ]]; then
    # First argument is a valid todo list name
    shift
    if [[ $# -eq 0 ]]; then
      # Just show the specified todo list
      python3 "$t_script" -t "$todo_dir" -l "${profile_name}_${first_arg}.todo"
    else
      # Add new todo entry to specified list
      python3 "$t_script" -t "$todo_dir" -l "${profile_name}_${first_arg}.todo" "$@"
    fi
  else
    # First argument not a list name, treat all args as todo entry for default list
    python3 "$t_script" -t "$todo_dir" -l "${profile_name}_default.todo" "$@"
  fi
  
  return $?
}

# Load a Taskwarrior + Timewarrior + Hledger profile (no change here)
function use_task_profile() {
  local profile="$1"
  if [[ -z "$profile" ]]; then
    echo "Usage: use_task_profile <profile-name>" >&2
    return 1
  fi

  local base="$HOME/ww/profiles/$profile"
  if [[ ! -d "$base" ]]; then
    echo "Error: Profile '$profile' not found at $base" >&2
    return 1
  fi

  # Set environment variables for the current session
  # Keeping WARRIOR_PROFILE for clarity of current profile, but not strictly needed by j/hl
  export WARRIOR_PROFILE="$profile"
  export WORKWARRIOR_BASE="$base" 
  export TASKRC="$base/.taskrc"
  export TASKDATA="$base/.task"
  export TIMEWARRIORDB="$base/.timewarrior"

  # These 'eval' lines are still useful to ensure the *function definitions*
  # are refreshed in the current shell, but j/hl now rely directly on exported vars.
  eval "$(declare -f j)"
  eval "$(declare -f l)"
  eval "$(declare -f t)" 

  echo "Now using Workwarrior profile: $profile"
  echo "✓ Global 'j' command now writes to $profile's default journal"
  echo "✓ Global 'l' command now uses $profile's default ledger"
  echo "✓ Global 't' command now uses $profile's default todo list"
  echo "✓ Use 'task start <id>' to start tasks with timewarrior integration"
}

# -- Profile Identification in Terminal Prompt:
export PS1='[\u@\h \W ${WARRIOR_PROFILE:-default}]\$ '

# "Include creation date for profile in prompt?"

# -- Workwarrior Profile Aliases for Group: "all"
# -- "all" is the default Group in WW System
ALIAS_LINE="alias ${PROFILE_NAME}='use_task_profile $PROFILE_NAME'"

alias p-ww='use_task_profile workwarrior'
alias p-fam='use_task_profile family'
alias p-tools='use_task_profile tools'
alias p-kids='use_task_profile kids'
alias p-b='use_task_profile babb'
alias p-board='use_task_profile babb-board'
alias p-box='use_task_profile babb-box'
alias p-bs='use_task_profile babb-system'
alias p-bas='use_task_profile basics'
alias p-bfin='use_task_profile babb-fin'
alias p-wp='use_task_profile workpads'
alias p-bcli='use_task_profile babb-cli'

# Workwarrior Profile Aliases
alias desk='use_task_profile desk'



# -- TASKWARRIOR ----------------------------------------
# -- About Tool:
# -- 

# -- DIRECTION ACTIVATION OF TASK PROFILES
# -- Convention: "t-" plus profile alias

alias t-ww='unset TASKDATA && TASKRC=~/tasks/workwarrior/.timewarrior-babb TASKRC=~/tasks/babb/.taskrc task'


# -- Task Aliases for Prefixing with Project


# -- TIMEWARRIOR ----------------------------------------
# -- About Tool:
# -- 

# -- Old Configurations (REMOVE)
alias timeww='TIMEWARRIORDB=~/tasks/workwarrior/.timewarrior timew'
alias timetw='TIMEWARRIORDB=~/times/.timewarrior-toolwarrior/data timew'
alias timewps='TIMEWARRIORDB=~/tasks/.timewarrior/data timew'
alias timebabb='TIMEWARRIORDB=~/times/.timewarrior-babbdevelopment/data timew'
alias timebasics='TIMEWARRIORDB=~/times/.timewarrior-basics/data timew'
alias timebsys='TIMEWARRIORDB=~/times/.timewarrior-babbsystem/data timew'
alias timeboard='TIMEWARRIORDB=~/times/.timewarrior-babbboard/data timew'
alias timebox='TIMEWARRIORDB=~/times/.timewarrior-babbbox/data timew'
alias timebcli='TIMEWARRIORDB=~/times/.timewarrior-babbcli/data timew'
alias timebfin='TIMEWARRIORDB=~/times/.timewarrior-babbfinancials/data timew'
alias timefam='TIMEWARRIORDB=~/times/.timewarrior-family/data timew'
alias timekids='TIMEWARRIORDB=~/times/.timewarrior-kidslearning/data timew'
alias timemath='TIMEWARRIORDB=~/times/.timewarrior-math/data timew'


# -- JRNL -----------------------------------------------
# -- About Tool:
# -- 

# -- JRNL Configuration
alias j-config="nano ~/ww/.config/jrnl/jrnl.yaml"

# -- Direct Aliases for Journals ---
alias j-athree='jrnl --config-file "/Users/mp/ww/profiles/athree/jrnl.yaml"'
alias j-desk='jrnl --config-file "/Users/mp/ww/profiles/desk/jrnl.yaml"'


# -- Old Configuration (REMOVE)
alias jwp="jrnl wp"
alias jb="jrnl babb"
alias jbs="jrnl babb-system"
alias jl="jrnl linux"
alias jboard="jrnl board"
alias jbox="jrnl box"
alias jbfin="jrnl babbfin"
alias jbash="jrnl bash"
alias ja="jrnl assembly"
alias jmath="jrnl math"
alias jc="jrnl c"
alias jpers="jrnl personal"
alias jfam="jrnl fam"
alias jrust="jrnl rust"
alias jbuffalo="jrnl buffalo"
alias jacc="jrnl accounting"
alias jlearn="jrnl learn"
alias jpython="jrnl python"
alias jch="jrnl christ"
alias jmg="jrnl mgroup"
alias jham="jrnl hamilton"
alias jp="jrnl prompts"
alias jds="jrnl devsys"
alias jpitt="jrnl pittsburgh"
alias jnev="jrnl nevada"
alias jtools="jrnl tools"
alias jmac="jrnl mac"
alias jscr="jrnl scripts"
alias jww="jrnl workwarrior"
alias jtw="jrnl toolwarrior"
alias jbk="jrnl books"
alias jwr="jrnl warrior"


# -- Journal Scripts 
# -- 
# -- Populated via Script:
# -- 

# -- Journal Response Templates
alias j-ww-general='~/scripts/journals/base/workwarrior/general.sh'

# -- Journal Export Aliases
alias j-exp-w='export JOURNAL_FILE="~/docs/journals/j-workpads.txt"'

# -- Journal Meta Scripts
# -- 
# -- Populated via Script:
# -- 

# -- Create New Jouranl Entry Template
alias j-temp='$HOME/ww/services/questions/templates/journal/create-new-template-jrnl.sh'



# -- TO DO by SJL
# -- About Tool:
# -- 

# -- Alias for T Program ---


# -- Aliases for Simplified Todo Lists
alias todo-ww='python3 ~/apps/t/t.py --task-dir ~/todo --list tasks'

# -- Old Configuration (REMOVE)


alias tg='python3 "$HOME/ww/tools/todo/t/t.py --task-dir ~/todo --list groceries'
alias tpi='python3 ~/apps/t/t.py --task-dir ~/todo --list workpadsissues'
alias tbi='python3 ~/apps/t/t.py --task-dir ~/todo --list basicsissues'
alias tsi='python3 ~/apps/t/t.py --task-dir ~/todo --list systemissues'
alias tw='python3 ~/apps/t/t.py --task-dir ~/todo --list writing'
alias tf='python3 ~/apps/t/t.py --task-dir ~/todo --list family'
alias tr='python3 ~/apps/t/t.py --task-dir ~/todo --list reading'
alias tbabb='python3 "$HOME/ww/tools/todo/t/t.py --task-dir ~/todo --list babb'
alias tww='python3 "$HOME/ww/tools/todo/t/t.py --task-dir ~/todo --list workwarrior'

# -- Hledger --------------------------------------------
# -- About Tool:
# -- 

# -- General Aliases for Hledger
alias hl='hledger'
alias hi="~/.cabal/bin/hledger-iadd"
alias f="~/src/hledger/bin/ft"
alias ha="h add"
alias hb='h bal'

# -- Direct Aliases for Ledger Files per Profile
alias l-desk='hledger -f "/Users/mp/ww/profiles/desk/ledgers/hledger.journal"'
alias l-ww='export LEDGER_FILE="~/accounting/base/workwarrior/demo-ledger.journal"'

# -- Old Configuration (REMOVE)
alias hmg22='export LEDGER_FILE="~/docs/acc/mg/desk/2022/ledgersmg2022.journal"'
alias hmg23='export LEDGER_FILE="~/docs/acc/mg/desk/2023/ledgersmg2023.journal"'
alias hmg24='export LEDGER_FILE="~/docs/acc/mg/desk/2024/2024accounts-main.journal"'
alias hmg25='export LEDGER_FILE="~/docs/acc/mg/desk/2025/main25.journal"'
alias hsptax='export LEDGER_FILE="~/docs/acc/taxcalc/overview-ledger-sps.journal"'
alias hfam='export LEDGER_FILE="~/docs/acc/fam/fam.j"'
alias hbabb='export LEDGER_FILE="~/docs/acc/babb/babb.j"'
alias hwp='export LEDGER_FILE="~/docs/acc/babb/workpads.j"'
alias hhc='export LEDGER_FILE="~/docs/acc/hc/hc.j"'
alias hret24='export LEDGER_FILE="~/docs/acc/temp/2024return.j"'
alias hbf='export LEDGER_FILE="~/docs/acc/babb/Corp_Accounts_862.journal"'



# -- EXTENSIONS -----------------------------------------


# -- TaskWarrior TUI - Terminal User Interface
# -- About Extension:
# -- 
# -- Populated via Script:
# -- 
# -- Convention: "tui-" plus profile alias

alias tui='taskwarrior-tui'
alias tui-ww='TASKRC="~/tasks/workwarrior/.taskrc" TASKDATA="~/tasks/workwarrior/.task" taskwarrior-tui'
alias tuiwp='TASKRC="$HOME/tasks/workpads/.taskrc" TASKDATA="$HOME/tasks/workpads/.task" taskwarrior-tui'
alias tuib='TASKRC="~/tasks/babb/.taskrc" TASKDATA="~/tasks/babb/data/.task" taskwarrior-tui'
alias tuibc='TASKRC="~/tasks/babb-fin/.taskrc" TASKDATA="~/tasks/babb-fin/data/.task" taskwarrior-tui'
alias tuibas='TASKRC="~/tasks/basics/.taskrc" TASKDATA="~/tasks/basics/data/.task" taskwarrior-tui'
alias tuibb='TASKRC="~/tasks/babb-board/.taskrc" TASKDATA="~/tasks/babb-board/data/.task" taskwarrior-tui'
alias tuibs='TASKRC="~/tasks/babb-system/.taskrc" TASKDATA="~/tasks/babb-system/data/.task" taskwarrior-tui'
alias tuibx='TASKRC="~/tasks/babb-box/.taskrc" TASKDATA="~/tasks/babb-box/data/.task" taskwarrior-tui'
alias tuifam='TASKRC="~/tasks/family/.taskrc" TASKDATA="~/tasks/family/data/.task" taskwarrior-tui'


# -- TaskSH - Shell for Taskwarrior
# -- About Extension:
# -- Created by Maintainers of Taskwarrior
# -- Populated via Script:
# -- 
# -- Convention: COMPLETE

# -- Activation of TASKSH for Each Profile
alias tasksh-wp='TASKRC=~/tasks/workpads/.taskrc TASKDATA=~/tasks/workpads/data/.task tasksh'



# -- Activation of VIT for Various Profiles
alias vit-bs='TASKRC="~/tasks/babb-system/.taskrc" vit'


# -- HLEDGER ----------------------------------------





# -- Direct Aliases for Hledger ---
alias l-bash='hledger -f "/Users/mp/ww/profiles/bash/ledgers/bash.journal"'
alias l-testing='hledger -f "/Users/mp/ww/profiles/testing/ledgers/testing.journal"'
alias l-yazooooooooo='hledger -f "/Users/mp/ww/profiles/yazooooooooo/ledgers/yazooooooooo.journal"'
alias l-babbbox='hledger -f "/Users/mp/ww/profiles/babbbox/ledgers/babbbox.journal"'
alias l-babbboard='hledger -f "/Users/mp/ww/profiles/babbboard/ledgers/babbboard.journal"'
alias l-babbcli='hledger -f "/Users/mp/ww/profiles/babbcli/ledgers/babbcli.journal"'
alias l-babbfin='hledger -f "/Users/mp/ww/profiles/babbfin/ledgers/babbfin.journal"'
alias l-babbsystem='hledger -f "/Users/mp/ww/profiles/babbsystem/ledgers/babbsystem.journal"'
alias l-basics='hledger -f "/Users/mp/ww/profiles/basics/ledgers/basics.journal"'
alias l-family='hledger -f "/Users/mp/ww/profiles/family/ledgers/family.journal"'
alias l-kids='hledger -f "/Users/mp/ww/profiles/kids/ledgers/kids.journal"'
alias l-kingston='hledger -f "/Users/mp/ww/profiles/kingston/ledgers/kingston.journal"'
alias l-yello='hledger -f "/Users/mp/ww/profiles/yello/ledgers/yello.journal"'
alias l-wdotapp='hledger -f "/Users/mp/ww/profiles/wdotapp/ledgers/wdotapp.journal"'
alias l-springcoding='hledger -f "/Users/mp/ww/profiles/springcoding/ledgers/springcoding.journal"'
alias l-babbworks='hledger -f "/Users/mp/ww/profiles/babbworks/ledgers/babbworks.journal"'
alias l-wporg='hledger -f "/Users/mp/ww/profiles/wporg/ledgers/wporg.journal"'
alias l-babbhome='hledger -f "/Users/mp/ww/profiles/babbhome/ledgers/babbhome.journal"'
alias l-w='hledger -f "/Users/mp/ww/profiles/w/ledgers/w.journal"'
alias l-writing='hledger -f "/Users/mp/ww/profiles/writing/ledgers/writing.journal"'
alias l-jobs='hledger -f "/Users/mp/ww/profiles/jobs/ledgers/jobs.journal"'
alias l-test='hledger -f "/Users/mp/ww/profiles/test/ledgers/test.journal"'
alias l-a11='hledger -f "/Users/mp/ww/profiles/a11/ledgers/a11.journal"'


# -- Workwarrior Profile Aliases ---
alias bash='use_task_profile bash'
alias p-bash='use_task_profile bash'
alias testing='use_task_profile testing'
alias p-testing='use_task_profile testing'
alias yazooooooooo='use_task_profile yazooooooooo'
alias p-yazooooooooo='use_task_profile yazooooooooo'
alias babbbox='use_task_profile babbbox'
alias p-babbbox='use_task_profile babbbox'
alias babbboard='use_task_profile babbboard'
alias p-babbboard='use_task_profile babbboard'
alias babbcli='use_task_profile babbcli'
alias p-babbcli='use_task_profile babbcli'
alias babbfin='use_task_profile babbfin'
alias p-babbfin='use_task_profile babbfin'
alias babbsystem='use_task_profile babbsystem'
alias p-babbsystem='use_task_profile babbsystem'
alias basics='use_task_profile basics'
alias p-basics='use_task_profile basics'
alias family='use_task_profile family'
alias p-family='use_task_profile family'
alias kids='use_task_profile kids'
alias kingston='use_task_profile kingston'
alias p-kingston='use_task_profile kingston'
alias yello='use_task_profile yello'
alias p-yello='use_task_profile yello'
alias wdotapp='use_task_profile wdotapp'
alias p-wdotapp='use_task_profile wdotapp'
alias springcoding='use_task_profile springcoding'
alias p-springcoding='use_task_profile springcoding'
alias babbworks='use_task_profile babbworks'
alias p-babbworks='use_task_profile babbworks'
alias wporg='use_task_profile wporg'
alias p-wporg='use_task_profile wporg'
alias babbhome='use_task_profile babbhome'
alias p-babbhome='use_task_profile babbhome'
alias w='use_task_profile w'
alias p-w='use_task_profile w'
alias writing='use_task_profile writing'
alias p-writing='use_task_profile writing'
alias jobs='use_task_profile jobs'
alias p-jobs='use_task_profile jobs'
alias test='use_task_profile test'
alias p-test='use_task_profile test'
alias a11='use_task_profile a11'
alias p-a11='use_task_profile a11'


# -- Direct Alias for Journals ---
alias j-bash='jrnl --config-file "/Users/mp/ww/profiles/bash/jrnl.yaml"'
alias j-testing='jrnl --config-file "/Users/mp/ww/profiles/testing/jrnl.yaml"'
alias j-yazooooooooo='jrnl --config-file "/Users/mp/ww/profiles/yazooooooooo/jrnl.yaml"'
alias j-babbbox='jrnl --config-file "/Users/mp/ww/profiles/babbbox/jrnl.yaml"'
alias j-babbboard='jrnl --config-file "/Users/mp/ww/profiles/babbboard/jrnl.yaml"'
alias j-babbcli='jrnl --config-file "/Users/mp/ww/profiles/babbcli/jrnl.yaml"'
alias j-babbfin='jrnl --config-file "/Users/mp/ww/profiles/babbfin/jrnl.yaml"'
alias j-babbsystem='jrnl --config-file "/Users/mp/ww/profiles/babbsystem/jrnl.yaml"'
alias j-basics='jrnl --config-file "/Users/mp/ww/profiles/basics/jrnl.yaml"'
alias j-family='jrnl --config-file "/Users/mp/ww/profiles/family/jrnl.yaml"'
alias j-kids='jrnl --config-file "/Users/mp/ww/profiles/kids/jrnl.yaml"'
alias j-kingston='jrnl --config-file "/Users/mp/ww/profiles/kingston/jrnl.yaml"'
alias j-tools-lkajslkdfjalksjdflkajsd='jrnl --config-file "/Users/mp/ww/profiles/tools/jrnl.yaml" --journal "lkajslkdfjalksjdflkajsd"'
alias j-lkajslkdfjalksjdflkajsd='jrnl --config-file "/Users/mp/ww/profiles/tools/jrnl.yaml" --journal "lkajslkdfjalksjdflkajsd"'
alias j-tools-powerdrilling='jrnl --config-file "/Users/mp/ww/profiles/tools/jrnl.yaml" --journal "powerdrilling"'
alias j-powerdrilling='jrnl --config-file "/Users/mp/ww/profiles/tools/jrnl.yaml" --journal "powerdrilling"'
alias j-tools-powerdrill='jrnl --config-file "/Users/mp/ww/profiles/tools/jrnl.yaml" --journal "powerdrill"'
alias j-powerdrill='jrnl --config-file "/Users/mp/ww/profiles/tools/jrnl.yaml" --journal "powerdrill"'
alias j-yello='jrnl --config-file "/Users/mp/ww/profiles/yello/jrnl.yaml"'
alias j-wdotapp='jrnl --config-file "/Users/mp/ww/profiles/wdotapp/jrnl.yaml"'
alias j-springcoding='jrnl --config-file "/Users/mp/ww/profiles/springcoding/jrnl.yaml"'
alias j-babbworks='jrnl --config-file "/Users/mp/ww/profiles/babbworks/jrnl.yaml"'
alias j-wporg='jrnl --config-file "/Users/mp/ww/profiles/wporg/jrnl.yaml"'
alias j-babbhome='jrnl --config-file "/Users/mp/ww/profiles/babbhome/jrnl.yaml"'
alias j-w='jrnl --config-file "/Users/mp/ww/profiles/w/jrnl.yaml"'
alias j-writing-front='jrnl --config-file "/Users/mp/ww/profiles/writing/jrnl.yaml" --journal "front"'
alias j-front='jrnl --config-file "/Users/mp/ww/profiles/writing/jrnl.yaml" --journal "front"'
alias j-writing='jrnl --config-file "/Users/mp/ww/profiles/writing/jrnl.yaml"'
alias j-jobs='jrnl --config-file "/Users/mp/ww/profiles/jobs/jrnl.yaml"'
alias j-test='jrnl --config-file "/Users/mp/ww/profiles/test/jrnl.yaml"'
alias j-a11='jrnl --config-file "/Users/mp/ww/profiles/a11/jrnl.yaml"'

# -- Direct Aliases for TODO tool ---
alias t-w-plain='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/w/todo" -l "w_plain.todo"'
alias t-bash-syntax='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/bash/todo" -l "bash_syntax.todo"'
alias t-bash='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/bash/todo"'
alias t-testing='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/testing/todo"'
alias t-yazooooooooo='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/yazooooooooo/todo"'
alias t-babbbox='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/babbbox/todo"'
alias t-babbboard='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/babbboard/todo"'
alias t-babbcli='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/babbcli/todo"'
alias t-babbfin='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/babbfin/todo"'
alias t-babbsystem='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/babbsystem/todo"'
alias t-basics='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/basics/todo"'
alias t-family='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/family/todo"'
alias t-kids='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/kids/todo"'
alias t-kingston='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/kingston/todo"'
alias t-yello='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/yello/todo"'
alias t-babb-buffalotests='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/babb/todo" -l "babb_buffalotests.todo"'
alias t-wdotapp='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/wdotapp/todo"'
alias t-springcoding='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/springcoding/todo"'
alias t-babbworks='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/babbworks/todo"'
alias t-wporg='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/wporg/todo"'
alias t-babbhome='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/babbhome/todo"'
alias t-w='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/w/todo"'
alias t-writing-front='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/writing/todo" -l "writing_front.todo"'
alias t-writing='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/writing/todo"'
alias t-jobs-king='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/jobs/todo" -l "jobs_king.todo"'
alias t-jobs-hamilton='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/jobs/todo" -l "jobs_hamilton.todo"'
alias t-jobs='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/jobs/todo"'
alias t-test-here='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/test/todo" -l "test_here.todo"'
alias t-test-extra='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/test/todo" -l "test_extra.todo"'
alias t-test='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/test/todo"'
alias t-a11='python3 "/Users/mp/ww/tools/todo/t/t.py" -t "/Users/mp/ww/profiles/a11/todo"'



# -- QUESTION Service ---
function q() {
  # Check if Workwarrior profile is active
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No Workwarrior profile is currently active. Please activate one with 'p-<profile-name>'." >&2
    return 1
  fi

  local questions_dir="$WORKWARRIOR_BASE/services/questions"
  local templates_dir="$questions_dir/templates"
  local handlers_dir="$questions_dir/handlers"
  local lib_dir="$questions_dir/lib"
  
  # Create directory structure if it doesn't exist
  if [[ ! -d "$questions_dir" ]]; then
    mkdir -p "$templates_dir"/{task,journal,time,todo,ledger,custom}
    mkdir -p "$handlers_dir"
    mkdir -p "$lib_dir"
    mkdir -p "$questions_dir/config"
  fi

  # No arguments - show main menu
  if [[ $# -eq 0 ]]; then
    echo "Questions Manager"
    echo "========================"
    echo "Services:"
    echo "    task     - Task management questions"
    echo "    journal  - Journal entry questions"
    echo "    time     - Time tracking questions"
    echo "    todo     - Todo list questions"
    echo "    ledger   - Financial/ledger questions"
    echo ""
    echo "Usage:"
    echo "    q <service>            - List templates for service"
    echo "    q <service> <template> - Use existing template"
    echo "    q new                  - Create new custom template"
    echo "    q new <service>        - Create new template for service"
    echo "    q list                 - List all templates"
    echo "    q edit <template>      - Edit existing template"
    echo "    q delete <template>    - Delete template"
    return 0
  fi

  local command="$1"
  
  case "$command" in
    "new")
      if [[ $# -eq 1 ]]; then
        # Create custom template
        _q_create_template "custom"
      else
        # Create template for specific service
        local service="$2"
        if [[ "$service" =~ ^(task|journal|time|todo|ledger)$ ]]; then
          _q_create_template "$service"
        else
          echo "Error: Invalid service '$service'. Valid services: task, journal, time, todo, ledger" >&2
          return 1
        fi
      fi
      ;;
    "list")
      _q_list_all_templates
      ;;
    "edit")
      if [[ $# -lt 2 ]]; then
        echo "Error: Please specify a template to edit." >&2
        return 1
      fi
      _q_edit_template "$2"
      ;;
    "delete")
      if [[ $# -lt 2 ]]; then
        echo "Error: Please specify a template to delete." >&2
        return 1
      fi
      _q_delete_template "$2"
      ;;
    "task"|"journal"|"time"|"todo"|"ledger")
      if [[ $# -eq 1 ]]; then
        # List templates for this service
        _q_list_service_templates "$command"
      else
        # Use specific template
        _q_use_template "$command" "$2"
      fi
      ;;
    *)
      echo "Error: Unknown command '$command'" >&2
      echo "Run 'q' for help."
      return 1
      ;;
  esac
}

# Helper function to create a new template
_q_create_template() {
  local service="$1"
  local templates_dir="$WORKWARRIOR_BASE/services/questions/templates"
  
  echo "Creating new template for service: $service"
  echo "=========================================="
  
  # Get template name
  read -p "Template filename (without .json): " template_name
  if [[ -z "$template_name" ]]; then
    echo "Error: Template name cannot be empty." >&2
    return 1
  fi
  
  # Get display name (optional)
  read -p "Display name (press Enter for '$template_name'): " display_name
  if [[ -z "$display_name" ]]; then
    display_name="$template_name"
  fi
  
  # Get description
  read -p "Description: " description
  
  # Collect questions
  echo ""
  echo "Enter questions (press Enter with empty input to finish):"
  local questions=()
  local question_num=1
  
  while true; do
    read -p "Question $question_num: " question_text
    if [[ -z "$question_text" ]]; then
      break
    fi
    questions+=("$question_text")
    ((question_num++))
  done
  
  if [[ ${#questions[@]} -eq 0 ]]; then
    echo "Error: At least one question is required." >&2
    return 1
  fi
  
  # Create template file
  local template_file="$templates_dir/$service/${template_name}.json"
  _q_write_template_file "$template_file" "$display_name" "$description" "$service" "${questions[@]}"
  
  echo "Template created: $template_file"
  echo "Use with: q $service $template_name"
}

# Helper function to write template JSON file
_q_write_template_file() {
  local template_file="$1"
  local display_name="$2"
  local description="$3"
  local service="$4"
  shift 4
  local questions=("$@")
  
  cat > "$template_file" << EOF
{
  "name": "$display_name",
  "description": "$description",
  "service": "$service",
  "questions": [
EOF
  
  for i in "${!questions[@]}"; do
    local comma=""
    if [[ $i -lt $((${#questions[@]} - 1)) ]]; then
      comma=","
    fi
    cat >> "$template_file" << EOF
    {
      "id": "q$((i+1))",
      "text": "${questions[i]}",
      "type": "text",
      "required": true
    }$comma
EOF
  done
  
  cat >> "$template_file" << EOF
  ],
  "output_format": {
    "title": "$display_name - {date}",
    "description": "Generated from template",
    "tags": ["$service", "template"]
  }
}
EOF
}

# Helper function to list templates for a service
_q_list_service_templates() {
  local service="$1"
  local templates_dir="$WORKWARRIOR_BASE/services/questions/templates/$service"
  
  echo "Templates for $service:"
  echo "======================"
  
  if [[ ! -d "$templates_dir" ]]; then
    echo "No templates found for $service"
    return 0
  fi
  
  local found_templates=0
  for template_file in "$templates_dir"/*.json; do
    if [[ -f "$template_file" ]]; then
      local template_name=$(basename "$template_file" .json)
      echo "    $template_name"
      found_templates=1
    fi
  done
  
  if [[ $found_templates -eq 0 ]]; then
    echo "No templates found for $service"
  fi
}

# Helper function to list all templates
_q_list_all_templates() {
  local templates_dir="$WORKWARRIOR_BASE/services/questions/templates"
  
  echo "All Templates:"
  echo "=============="
  
  for service in task journal time todo ledger custom; do
    local service_dir="$templates_dir/$service"
    if [[ -d "$service_dir" ]]; then
      local has_templates=0
      for template_file in "$service_dir"/*.json; do
        if [[ -f "$template_file" ]]; then
          if [[ $has_templates -eq 0 ]]; then
            echo "$service:"
            has_templates=1
          fi
          local template_name=$(basename "$template_file" .json)
          echo "    $template_name"
        fi
      done
    fi
  done
}

# Helper function to use a template
_q_use_template() {
  local service="$1"
  local template_name="$2"
  local template_file="$WORKWARRIOR_BASE/services/questions/templates/$service/${template_name}.json"
  
  if [[ ! -f "$template_file" ]]; then
    echo "Error: Template '$template_name' not found for service '$service'" >&2
    return 1
  fi
  
  # Check if python3 is available for JSON parsing
  if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required for JSON parsing" >&2
    return 1
  fi
  
  # Parse template and prompt for answers
  local answers_file=$(mktemp)
  if _q_prompt_questions "$template_file" "$answers_file"; then
    # Process answers and call appropriate handler
    _q_process_answers "$service" "$template_file" "$answers_file"
    local result=$?
    rm -f "$answers_file"
    return $result
  else
    rm -f "$answers_file"
    return 1
  fi
}

# Helper function to prompt for questions from template
_q_prompt_questions() {
  local template_file="$1"
  local answers_file="$2"
  
  # Extract template info using python3
  local template_info=$(python3 -c "
import json, sys
try:
    with open('$template_file', 'r') as f:
        template = json.load(f)
    print(template['name'])
    print(template['description'])
    print(len(template['questions']))
    for i, q in enumerate(template['questions']):
        print(f\"{i}|{q['id']}|{q['text']}|{q.get('required', True)}\")
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
")
  
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to parse template JSON" >&2
    return 1
  fi
  
  # Parse template info
  local lines=($template_info)
  local template_name="${lines[0]}"
  local template_desc="${lines[1]}"
  local question_count="${lines[2]}"
  
  echo "Template: $template_name"
  echo "Description: $template_desc"
  echo "=========================================="
  echo ""
  
  # Initialize answers file
  echo "{" > "$answers_file"
  echo "    \"template\": \"$template_file\"," >> "$answers_file"
  echo "    \"timestamp\": \"$(date -Iseconds)\"," >> "$answers_file"
  echo "    \"answers\": {" >> "$answers_file"
  
  local answer_count=0
  
  # Process each question
  for ((i=3; i<$((question_count+3)); i++)); do
    local question_line="${lines[i]}"
    IFS='|' read -r q_index q_id q_text q_required <<< "$question_line"
    
    # Prompt for answer
    local answer=""
    while true; do
      read -p "$q_text: " answer
      
      # Check if required field is empty
      if [[ "$q_required" == "True" && -z "$answer" ]]; then
        echo "This field is required. Please provide an answer."
        continue
      fi
      
      break
    done
    
    # Add comma if not first answer
    if [[ $answer_count -gt 0 ]]; then
      echo "," >> "$answers_file"
    fi
    
    # Escape quotes in answer for JSON
    local escaped_answer=$(echo "$answer" | sed 's/"/\\"/g')
    echo -n "    \"$q_id\": \"$escaped_answer\"" >> "$answers_file"
    
    ((answer_count++))
  done
  
  echo "" >> "$answers_file" # Newline after last answer
  echo "    }" >> "$answers_file" # Close the "answers" object

  # --- NEW: Universal option to add a note ---
  local note_text=""
  echo "" # Ensure a clear line before the note prompt
  echo "--- Optional Note ---" # Add a clear header for the note section
  read -p "Would you like to add an additional note? (y/N): " add_note_choice
  if [[ "$add_note_choice" =~ ^[Yy]$ ]]; then
    echo "Please enter your note. Press Enter on an empty line to finish."
    local temp_note_lines=()
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            break
        fi
        temp_note_lines+=("$line")
    done
    # Join lines with newline characters and escape for JSON
    note_text=$(printf "%s\\n" "${temp_note_lines[@]}" | sed 's/"/\\"/g')
  fi

  # Add note to answers JSON if provided.
  # This will be a sibling to "answers", "template", "timestamp".
  if [[ -n "$note_text" ]]; then
    echo "," >> "$answers_file" # Comma to separate "answers" object from "note" key
    echo "    \"note\": \"$note_text\"" >> "$answers_file"
  fi
  # --- END NEW ---
  
  echo "}" >> "$answers_file" # Close the main JSON object
  
  echo ""
  echo "Answers collected successfully."
  return 0
}

# Helper function to process answers and call service handler
_q_process_answers() {
  local service="$1"
  local template_file="$2"
  local answers_file="$3"
  local handlers_dir="$WORKWARRIOR_BASE/services/questions/handlers"
  local handler_script="$handlers_dir/${service}_handler.sh"
  
  echo "Processing answers for service: $service"
  
  # Check if handler exists
  if [[ ! -f "$handler_script" ]]; then
    echo "Warning: Handler script not found: $handler_script"
    echo "Creating basic handler template..."
    _q_create_handler_template "$service" "$handler_script"
  fi
  
  # Make handler executable
  chmod +x "$handler_script"
  
  # Call the handler with template and answers
  if "$handler_script" "$template_file" "$answers_file"; then
    echo "✓ Successfully processed answers with $service handler"
    return 0
  else
    echo "✗ Error processing answers with $service handler" >&2
    return 1
  fi
}

# Helper function to create a basic handler template
_q_create_handler_template() {
  local service="$1"
  local handler_script="$2"
  
  cat > "$handler_script" << 'EOF'
#!/bin/bash
# Auto-generated handler template for SERVICE_NAME service

template_file="$1"
answers_file="$2"

if [[ ! -f "$template_file" || ! -f "$answers_file" ]]; then
    echo "Error: Template or answers file not found" >&2
    exit 1
fi

echo "Handler: SERVICE_NAME"
echo "Template: $template_file"
echo "Answers: $answers_file"
echo ""

# Extract answers and note using python3
python3 -c "
import json
with open('$answers_file', 'r') as f:
    data = json.load(f)
    
print('Collected Answers:')
print('==================')
for key, value in data['answers'].items():
    print(f'{key}: {value}')

# Check for and print the optional note
if 'note' in data:
    print('\nAdditional Note:')
    print('================')
    print(data['note'])

print('')
print('TODO: Implement SERVICE_NAME-specific processing')
print('This handler should format the answers and integrate with SERVICE_NAME')
"

# TODO: Add SERVICE_NAME-specific integration here
# For example:
# - Format answers into task description
# - Create Workwarrior task with appropriate tags
# - Add to journal with proper formatting
# - etc.

echo "Handler completed successfully"
EOF

  # Replace SERVICE_NAME placeholder
  sed -i "s/SERVICE_NAME/$service/g" "$handler_script"
  
  echo "Created handler template: $handler_script"
  echo "You can customize this handler for $service-specific integration."
}

# Placeholder helper functions for future implementation
_q_edit_template() {
  local template_name="$1"
  echo "Edit template functionality not yet implemented: $template_name"
}

_q_delete_template() {
  local template_name="$1"
  echo "Delete template functionality not yet implemented: $template_name"
}
alias p-bigbird='use_task_profile bigbird'
alias bigbird='use_task_profile bigbird'

# -- Lists ---
alias Time='/Users/mp/ww/profiles/custom/.timewarrior'
alias List='/Users/mp/ww/profiles/custom/todo/custom_default.todo'
alias Work='/Users/mp/ww/profiles/custom/.taskrc'
alias Time='/Users/mp/ww/profiles/April/.timewarrior'
alias List='/Users/mp/ww/profiles/April/todo/April_default.todo'
alias Work='/Users/mp/ww/profiles/April/.taskrc'
alias Time='/Users/mp/ww/profiles/tommy/.timewarrior'
alias List='/Users/mp/ww/profiles/tommy/todo/tommy_default.todo'
alias Work='/Users/mp/ww/profiles/tommy/.taskrc'

# -- Books ---
alias ledger='hledger -f "/Users/mp/ww/profiles/custom/ledgers/custom.journal"'
alias Workbook='hledger -f "/Users/mp/ww/profiles/custom/ledgers/custom.journal"'
alias journal='jrnl --config-file "/Users/mp/ww/profiles/custom/jrnl.yaml"'
alias Notebook='jrnl --config-file "/Users/mp/ww/profiles/custom/jrnl.yaml"'
alias ledger='hledger -f "/Users/mp/ww/profiles/April/ledgers/April.journal"'
alias Workbook='hledger -f "/Users/mp/ww/profiles/April/ledgers/April.journal"'
alias journal='jrnl --config-file "/Users/mp/ww/profiles/April/jrnl.yaml"'
alias Notebook='jrnl --config-file "/Users/mp/ww/profiles/April/jrnl.yaml"'
alias ledger='hledger -f "/Users/mp/ww/profiles/tommy/ledgers/tommy.journal"'
alias Workbook='hledger -f "/Users/mp/ww/profiles/tommy/ledgers/tommy.journal"'
alias journal='jrnl --config-file "/Users/mp/ww/profiles/tommy/jrnl.yaml"'
alias Notebook='jrnl --config-file "/Users/mp/ww/profiles/tommy/jrnl.yaml"'
