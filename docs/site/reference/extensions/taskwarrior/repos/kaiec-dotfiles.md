# kaiec/dotfiles

**URL:** https://github.com/kaiec/dotfiles  
**Stars:** 3  
**Language:** JavaScript  
**Last push:** 2024-11-27  
**Archived:** No  
**Topics:** gpg, i3, khal, mutt, notmuch, taskwarrior, vim  

## Description

My Linux configuration, feel free to steal or get in touch.

## Category

Import / Export

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell scripting — matches ww stack
- +1: Import/export useful for profile migration

## README excerpt

```
## Deactivate flow control (ctrl s)
Put this in .bashrc

    stty -ixon


## Remapping Caps Lock
### Ubuntu
Run

    dconf write /org/gnome/desktop/input-sources/xkb-options "['caps:escape']"

## Time zone change
While traveling, the time zone can be changed like this:

    timedatectl set-timezone Europe/Paris

## Setting up mail
Install:
   - neomutt
   - notmuch
   - notmuch-mutt
   - msmtp
   - offlineimap

From other computer:
   - Import GPG Keys
   - Copy folder with encrypted passwords
   - Copy ~/.mailboxes with default mailboxes

### Encrypt passwords
   - Encrypt: gpg -r pw@local -e > ~/.kak/hallo.gpg
   - Decrypt: gpg --no-tty -q -d ~/.kak/hallo.gpg

### Fingerprints for TLS
   - msmtp -a flokai --serverinfo --tls --tls-certcheck=off --tls-fingerprint=

```