# benelan/dotfiles

**URL:** https://github.com/benelan/dotfiles  
**Stars:** 5  
**Language:** Lua  
**Last push:** 2026-01-31  
**Archived:** No  
**Topics:** bash, config, dotfiles, dunst, git, i3wm, linux, mpv, mutt, neovim, rofi, swaywm, taskwarrior, tmux, ubuntu, vifm, vim, w3m, waybar, wezterm  

## Description

"Decorate your home. It gives the illusion that your life is more interesting than it really is."     —  Charles M. Schulz

## Category

Sync

## Workwarrior Integration Rating

**Score:** 8  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +2: Profile concept maps directly to ww
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration

## README excerpt

```
# dotfiles

This is my personal setup, **I strongly discourage using the initialization script unless you're me**. I recommend
looking through the files and picking bits and pieces that fit your workflows.

## Setup

Make sure `git` and `curl` are installed before running the dotfiles initialization script. For example, in Ubuntu:

```sh
sudo apt install -y git curl
```

Then run the dotfiles script, which installs everything into your `$HOME` directory:

```sh
curl -sSL benelan.dev/s/dotfiles | sh
```

If the link above dies, use the [`dot`](../.dotfiles/bin/dot) script's `init` subcommand instead:

```sh
curl -sSL https://raw.githubusercontent.com/benelan/dotfiles/master/.dotfiles/bin/dot | bash -s init
```

The scripts do the same thing, but the first link is easier for me to remember and type.

The script will backup any conflicting files to `~/.dotfiles-backup`. It will set up the dotfiles as a bare git repo,
which makes syncing changes easy. You can also create separate branches for different machines. Read this
[Atlassian tutorial] for more info. A common alternative is managing dotfiles with symlinks (e.g., [GNU stow]), but in
my experience that can get messy.

## `dot` command

The `dot` script has the following custom subcommands:

- `init`: Initialize the dotfiles bare repo, as mentioned [above](#setup).

- `clone`: Clone a repo to the `$LIB` directory (see [`exports.sh`](../.dotfiles/shell/exports.sh)) instead of `$PWD`.

- `deps`: Install various dependencies, including development tools, GUI apps, shell scripts, fonts, themes, and more.
  See `dot deps -h` for usage info.

- `edit`: Open nvim/vim with environment variables set so git plugins work with the bare dotfiles repo.

All other subcommands and their arguments are passed to `git` with environment variables set to ensure `dot` always
runs on the bare repo. A typical workflow for adding a new config file to the repo is:

```sh
dot add .config/xyz/config.yml
dot commit -m "chore(xyz): add config"
dot push
```

Technically, the whole home directory is under version control. However, [`.gitignore`](../.gitignore) blacklists
everything, and then whitelists specific directories and files. This adds an extra level of security and prevents most
files from being untracked. The remaining untracked files are hidden from `dot status`, so you need to `dot add` new
files/directories before they show up.

Git's bash completion and the git aliases defined at the bottom of [`~/.config/git/config`](../.config/git/config) will
also work for `dot`.

## Operating systems

### Linux

My setup was primarily created for Ubuntu/Debian and their derivatives. However, I try to separate the Ubuntu-only code
and make sure executables exist before using them. The main issue you'll face with other linux distros is missing
dependencies, which I install with `dot deps -U` on Ubuntu. See the [apt dependency lists], although names may vary
depending on your distro's package manager.

### macOS

Mac users should
```