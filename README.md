# dotfiles

Auto-installed into every GitHub Codespace I create.

## What it does

`install.sh` runs on Codespace creation and:

1. Installs the [Claude Code](https://claude.com/claude-code) CLI if missing.
2. Symlinks `.claude/settings.json` into `~/.claude/settings.json`, so edits in
   this repo take effect immediately in the Codespace.
3. Registers the `anthropics/claude-plugins-official` plugin marketplace and
   installs the plugins listed below.

## Installed plugins

- `superpowers` — skills library for structured workflows (brainstorming, TDD,
  debugging, code review, etc.)
- `ralph-loop` — recurring-task loop runner

Add or remove plugins by editing `.claude/settings.json` **and** the plugin list
at the bottom of `install.sh`.

## Enabling

1. Push this repo to GitHub as `<your-user>/dotfiles` (public, or private with
   Codespaces access).
2. Visit <https://github.com/settings/codespaces> and enable
   **"Automatically install dotfiles from ..."**, pointing at this repo.
3. Create a new Codespace — `install.sh` will run during setup.

## Local testing

From inside an existing Codespace, you can re-run the installer at any time:

```bash
bash ~/dotfiles/install.sh   # or wherever this repo is cloned
```
