# claui/vscode-taskwarrior

**URL:** https://github.com/claui/vscode-taskwarrior  
**Stars:** 9  
**Language:** TypeScript  
**Last push:** 2023-07-19  
**Archived:** No  
**Topics:** syntax-highlighting, task-management, taskwarrior, visual-studio-code, visual-studio-code-extension, vscode, vscode-extension  

## Description

VS Code extension to manage Taskwarrior tasks

## Category

Reports & Visualisation

## Workwarrior Integration Rating

**Score:** 4  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration

## README excerpt

```
# vscode-taskwarrior

This is the source code repository for the `taskwarrior` VS Code
extension.

This document is for **contributors,** not for users of this
extension.  
For **user documentation,** see: [extension/README.md](./extension/README.md)  
For **license information,** see the bottom of this document.

## About the extension

This VS Code extension provides syntax highlighting for Taskwarrior’s `task edit` command.

For more features and details, see the user documentation:
[extension/README.md](./extension/README.md)

## Requirements for contributing

Working on this VS Code extension requires the following programs to
be installed on your system:

- `yarn` (required)
- `nvm` (recommended)

## Preparing your session

To prepare your session, `cd` to the project root directory, then
run `nvm use`.

## Installing dependencies

To install dependencies, run: `yarn install`

If that fails, consult the _Maintenance_ section.

## Building the extension

To build the extension, run: `yarn package`

Unlike `vsce package`, running `yarn package` will work around issue
[microsoft/vscode-vsce#517](https://github.com/microsoft/vscode-vsce/issues/517).
Use `yarn package` as long as the issue is unresolved.

## Publishing the extension

Publishing the extension has several steps:

1. Merge the contributions.
2. Choose a target version number.
3. Publish to the Marketplace. (This modifies `extension/package.json`.)
4. Publish to the Open VSX Registry.
5. Create a Git commit, Git tag, GitHub prerelease and GitHub PR.

### Merging the contributions

Make sure that all the contributions you’re going to have in the
release have been merged to the `main` branch.

### Choosing a target version number

With all contributions merged into `main`, choose a target version
number.  
[The VS Code folks recommend](https://code.visualstudio.com/api/working-with-extensions/publishing-extension#prerelease-extensions)
the following numbering scheme:

- `major.ODD_NUMBER.patch` (e.g. 1.1.0) for **pre-release** versions; and
- `major.EVEN_NUMBER.patch` (e.g. 1.2.0) for **release** versions.

### Publishing to the Marketplace

After deciding on a target version, run:

- `git checkout main`
- `yarn login`
- `yarn publish-vsce [--pre-release] [version]`

The `yarn publish-vsce` command first updates the version number in
[extension/package.json](./extension/package.json) to the given
version. Then it packages and publishes the extension to the VS Code
Extension Marketplace.

### Publishing to the Open VSX Registry

Follow these steps to publish the extension to the Open VSX Registry:

1. Set the `OVSX_PAT` environment variable to your personal access
   token.

   For example, if you’re on Bash and you have your token in
   1Password, you could run the following command line:

   ```bash
   read -r OVSX_PAT < <(
     op item get 'Open VSX Registry' --fields password
   ) && export OVSX_PAT
   ```

2. Make sure you have published the extension to the VS Code
   Extension M
```