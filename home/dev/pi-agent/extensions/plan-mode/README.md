# Plan Mode Extension

Read-only exploration mode for safe code analysis.

Trimmed from the upstream pi 0.84.2 example: the automatic progress
tracking (plan step extraction, `[DONE:n]` markers, execution widget,
execute/refine menu) was removed — this version is a pure read-only
toggle.

## Features

- **Built-in write tools disabled**: Disables edit/write while preserving other active tools
- **Bash allowlist**: Only read-only bash commands are allowed
- **Session persistence**: State survives session resume

## Commands

- `/plan` - Toggle plan mode
- `Ctrl+Alt+P` - Toggle plan mode (shortcut)
- `--plan` flag - Start the session in plan mode

## Usage

1. Enable plan mode with `/plan`, `Ctrl+Alt+P`, or the `--plan` flag
2. Ask the agent to analyze code and propose an approach
3. Disable plan mode with `/plan` when you want changes applied

### Command Allowlist

Safe commands (allowed):
- File inspection: `cat`, `head`, `tail`, `less`, `more`
- Search: `grep`, `find`, `rg`, `fd`
- Directory: `ls`, `pwd`, `tree`
- Git read: `git status`, `git log`, `git diff`, `git branch`
- Package info: `npm list`, `npm outdated`, `yarn info`
- System info: `uname`, `whoami`, `date`, `uptime`

Blocked commands:
- File modification: `rm`, `mv`, `cp`, `mkdir`, `touch`
- Git write: `git add`, `git commit`, `git push`
- Package install: `npm install`, `yarn add`, `pip install`
- System: `sudo`, `kill`, `reboot`
- Editors: `vim`, `nano`, `code`
