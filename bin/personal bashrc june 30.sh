# MACBOOK BASHRC file

export PS1='\u@\h:\W\S '

export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
eval "$(rbenv init -)"' >> ~/.bash_profile

# Main Aliases
alias src="source ~/.bashrc"
alias bash="nano ~/.bashrc"
alias c="clear"
alias h="history"
alias copyl='fc -ln -1 | pbcopy'

# Main Workwarrior Aliases


# Clear and List Tasks

# User-Defined Attributes ("Custom Attributes")
alias u="task udas"
alias j="jrnl --list"

# SUBLIME
export EDITOR="subl -w"

# -- Task and Time
alias tm="timew"
alias tms="timew start"
alias tsum="timew summary :ids"


# JRNL Custom Setup

alias jrnl='jrnl --config-file "$HOME/ww/functions/journals/CONFIG/jrnl.yaml"'

# EXPORTS

export PATH="$HOME/ww/bin:$PATH"

# TASKWARRIOR -------------------------------------

# Taskwarrior Scripts EXEC

# for MAKING: WORKWARRIOR


alias p-new="$HOME/ww/services/profile/create-ww-profile.sh"


function use_task_profile() {
  local profile="$1"
  export WARRIOR_PROFILE="$profile"
  export TASKRC="$HOME/ww/profiles/$profile/.taskrc"
  export TASKDATA="$HOME/ww/profiles/$profile/.task"
  export TIMEWARRIORDB="$HOME/ww/profiles/$profile/.timewarrior"
  echo "Current Workwarrior Profile: $profile"
}

export PS1='[\u@\h \W ${WARRIOR_PROFILE:-default}]\$ '

# TASKS & TIME - PERSONAL: Per-profile aliases

alias p-fam='use_task_profile family'
alias p-tools='use_task_profile tools'
alias p-kids='use_task_profile kids'
alias t='use_task_profile '
alias t='use_task_profile '



# TASKS & TIME - BABB: Per-profile aliases
alias p-b='use_task_profile babb'
alias p-board='use_task_profile babb-board'
alias p-box='use_task_profile babb-box'
alias p-bs='use_task_profile babb-system'
alias p-bas='use_task_profile basics'
alias p-bfin='use_task_profile babb-fin'
alias p-wp='use_task_profile workpads'
alias p-bcli='use_task_profile babb-cli'


# Run task or timew  with current profile
alias list='task list'
alias add='task add'
alias tw='timew'
alias time='timew'

# -- TASKwarrior
alias tui='taskwarrior-tui'

# TASKwarrior - Custom TUI Assignments

alias tuiwp='TASKRC="$HOME/tasks/workpads/.taskrc" TASKDATA="$HOME/tasks/workpads/.task" taskwarrior-tui'
alias tuib='TASKRC="~/tasks/babb/.taskrc" TASKDATA="~/tasks/babb/data/.task" taskwarrior-tui'
alias tuibc='TASKRC="~/tasks/babb-fin/.taskrc" TASKDATA="~/tasks/babb-fin/data/.task" taskwarrior-tui'
alias tuibas='TASKRC="~/tasks/basics/.taskrc" TASKDATA="~/tasks/basics/data/.task" taskwarrior-tui'
alias tuibb='TASKRC="~/tasks/babb-board/.taskrc" TASKDATA="~/tasks/babb-board/data/.task" taskwarrior-tui'
alias tuibs='TASKRC="~/tasks/babb-system/.taskrc" TASKDATA="~/tasks/babb-system/data/.task" taskwarrior-tui'
alias tuibx='TASKRC="~/tasks/babb-box/.taskrc" TASKDATA="~/tasks/babb-box/data/.task" taskwarrior-tui'
alias tuifam='TASKRC="~/tasks/family/.taskrc" TASKDATA="~/tasks/family/data/.task" taskwarrior-tui'

# -- List TW Aliases

alias tal="alias | grep -E 'task'"

#alias tb='unset TASKDATA && TIMEWARRIORDB=~/tasks/babb/.timewarrior-babb TASKRC=~/tasks/babb/.taskrc task'
#alias twp='unset TASKDATA && TASKRC=~/tasks/workpads/.taskrc task'
#alias tmg='unset TASKDATA && TASKRC=~/tasks/mg/.taskrc task'
#alias thc='unset TASKDATA && TASKRC=~/tasks/hc/.taskrc task'
#alias tfam='unset TASKDATA && TASKRC=~/tasks/family/.taskrc task'
#alias tboard='unset TASKDATA && TASKRC=~/tasks/babb-board/.taskrc task'
#alias tbox='unset TASKDATA && TASKRC=~/tasks/babb-box/.taskrc task'
#alias tbas='unset TASKDATA && TASKRC=~/tasks/basics/.taskrc task'
#alias tbs='unset TASKDATA && TASKRC=~/tasks/babb-system/.taskrc task'
#alias tbcli='unset TASKDATA && TASKRC=~/tasks/babb-cli/.taskrc task'
#alias tbfin='unset TASKDATA && TASKRC=~/tasks/babb-fin/.taskrc task'
#alias tkids='unset TASKDATA && TASKRC=~/tasks/kids/.taskrc task'
#alias twr='unset TASKDATA && TASKRC=~/tasks/tools/.taskrc task'


# Task Aliases for Prefixing with Project
alias twa='unset TASKDATA && TASKRC=~/tasks/workpads/.taskrc task add'
alias twcore='unset TASKDATA && TASKRC=~/tasks/workpads/.taskrc task add project:core'

# TASKSH Aliases
alias tasksh-wp='TASKRC=~/tasks/workpads/.taskrc TASKDATA=~/tasks/workpads/data/.task tasksh'

# VIT
alias vit-bs='TASKRC="~/tasks/babb-system/.taskrc" vit'

# TIMEWARRIOR: CONFIGURATIONS

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


# -- Journal Scripts --------------------------------
alias jmg-lead='~/docs/templates/JRNL/mg/scripts/mglead-prompting.sh'
alias gh-res='~/docs/templates/JRNL/dev/scripts/github-research.sh'
alias wp-tech='~/docs/templates/JRNL/babb/scripts/workpads-dev.sh'
alias wp-story='~/docs/templates/JRNL/babb/scripts/wp-story.sh'

# -- Journal META Scripts
alias j-temp='~/docs/scripts/jrnl/create-new-template-jrnl.sh'

# JRNL Aliases
alias jconfig="nano /Users/mp/.config/jrnl/jrnl.yaml"

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


# Journal Scripts
alias jmg-lead='~/docs/templates/JRNL/mg/scripts/mglead-prompting.sh'
alias gh-res='~/docs/templates/JRNL/dev/scripts/github-research.sh'
alias wp-tech='~/docs/templates/JRNL/babb/scripts/workpads-dev.sh'
alias wp-story='~/docs/templates/JRNL/babb/scripts/wp-story.sh'

# -- Journal META Scripts
alias j-temp='~/docs/scripts/jrnl/create-new-template-jrnl.sh'

# -- Journal - Environment Variables
alias j-b='export JOURNAL_FILE="~/docs/journals/j-babb.txt"'
alias j-w='export JOURNAL_FILE="~/docs/journals/j-workpads.txt"'

# -- Scripts
alias mg-ns="./mg-general-questions.sh"
alias src="source ~/.bashrc"
alias bash="nano ~/.bashrc"

# ─── End ─────────────────────────────────────────────────────────────────────
alias jw-algo='~/scripts/jrnl/prompts/wp-algorithm'
alias workpad-blocks='~/scripts/jrnl/prompts/workpad-blocks.sh'

# TO DO by SJL

alias t='python3 ~/apps/t/t.py --task-dir ~/todo --list tasks'
alias tg='python3 ~/apps/t/t.py --task-dir ~/todo --list groceries'
alias tpi='python3 ~/apps/t/t.py --task-dir ~/todo --list workpadsissues'
alias tbi='python3 ~/apps/t/t.py --task-dir ~/todo --list basicsissues'
alias tsi='python3 ~/apps/t/t.py --task-dir ~/todo --list systemissues'
alias tw='python3 ~/apps/t/t.py --task-dir ~/todo --list writing'
alias tf='python3 ~/apps/t/t.py --task-dir ~/todo --list family'
alias tr='python3 ~/apps/t/t.py --task-dir ~/todo --list reading'
alias tbabb='python3 ~/apps/t/t.py --task-dir ~/todo --list babb'
alias tww='python3 ~/apps/t/t.py --task-dir ~/todo --list workwarrior'

# -- Hledger
alias h='hledger'
alias hi="~/.cabal/bin/hledger-iadd"
alias f="~/src/hledger/bin/ft"
alias ha="h add"
alias hb='h bal'

# -- Ledger files
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


# Workwarrior Profile Aliases
alias Oranges='use_task_profile Oranges'
alias ww='use_task_profile workwarrior'
