# mainframev/task2habitica-rs

**URL:** https://github.com/mainframev/task2habitica-rs  
**Stars:** 1  
**Language:** Rust  
**Last push:** 2026-02-01  
**Archived:** No  
**Topics:** habitica, rust, taskwarrior  

## Description

Bidirectional sync tool between Taskwarrior and Habitica.

## Category

Sync

## Workwarrior Integration Rating

**Score:** 13  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +2: Sync capability relevant to ww profile isolation
- +3: UDAs — core to ww service model
- +2: Profile concept maps directly to ww
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration

## README excerpt

```
# task2habitica-rs

Bidirectional sync tool between [Taskwarrior](https://taskwarrior.org) and [Habitica](https://habitica.com).

## Features

- ✅ Bidirectional sync between Taskwarrior and Habitica
- ✅ Automatic task creation, updates, and completion tracking
- ✅ Task difficulty mapping (trivial/easy/medium/hard)
- ✅ Support for todos and dailies

## Requirements

- Rust 1.70 or higher
- Taskwarrior 3.4.2 or higher
- Habitica account

## Installation

### Using Cargo (Recommended)

```bash
cargo install task2habitica
task2habitica setup
```

The `setup` command will interactively:
- Install Taskwarrior hook scripts
- Configure required UDAs in your `.taskrc`
- Prompt for your Habitica credentials
- Validate your API connection
- Add credentials to your shell profile

### From Source

```bash
# Clone the repository
git clone https://github.com/mainframev/task2habitica-rs.git

# Build the release binary
cargo build --release

# Install the binary
cp target/release/task2habitica /usr/local/bin/

# Run interactive setup
task2habitica setup
```

## Configuration

The `task2habitica setup` command handles all configuration automatically. If you prefer manual configuration, see the sections below.

### Manual Configuration

#### Habitica Credentials

You can configure your Habitica credentials using either environment variables or your `.taskrc` file.
Environment variables take precedence if both are set.

##### Environment Variables (Recommended)

```bash
export HABITICA_USER_ID=YOUR_USER_ID
export HABITICA_API_KEY=YOUR_API_KEY
```

##### .taskrc

Add your Habitica user ID and API key to your `taskrc` file:

```
habitica.user_id=YOUR_USER_ID
habitica.api_key=YOUR_API_KEY
```

You can find these in your Habitica account settings under _Site Data tab_.

#### Required UDAs

Add the following User Defined Attributes (UDAs) to your `.taskrc` (automatically added by `task2habitica setup`):

```
uda.habitica_uuid.label=Habitica UUID
uda.habitica_uuid.type=string

uda.habitica_difficulty.label=Habitica Difficulty
uda.habitica_difficulty.type=string
uda.habitica_difficulty.values=trivial,easy,medium,hard

uda.habitica_task_type.label=Habitica Task Type
uda.habitica_task_type.type=string
uda.habitica_task_type.values=daily,todo
```

#### Hook Scripts

The setup command installs hook scripts to `~/.task/hooks/`. If you need to install them manually:

```bash
mkdir -p ~/.task/hooks
cp hooks/* ~/.task/hooks/
chmod +x ~/.task/hooks/*.task2habitica
```

#### Optional: Configure Task Notes

By default, task notes are stored in `~/.task/notes/`. You can customize this:

```
rc.tasknote.location=~/.task/notes/
rc.tasknote.prefix=[tasknote]
rc.tasknote.extension=.txt
```

## Usage

### Automatic Sync (via Hooks)

Once installed, the hooks will automatically sync your tasks:

- **on-add**: When you add a task in Taskwarrior, it's created on Habitica
- **on-modify**: When you modify a task, changes are synced to Habitica
- **on-exit**: Displays stat changes (HP, MP, Exp, 
```