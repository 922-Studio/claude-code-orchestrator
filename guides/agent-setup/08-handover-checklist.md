# 08 — Handover Checklist

**Prev**: [07 — Skills and Commands](07-skills-and-commands.md) | **Back to**: [README](README.md)

Concrete steps for a newcomer on day 1.

## Prerequisites

- [ ] macOS with Zed installed
- [ ] Claude Code installed (`npm install -g @anthropic-ai/claude-code` or via Zed extension)
- [ ] Anthropic API key configured (`ANTHROPIC_API_KEY` in env or Claude Code settings)
- [ ] SSH access to the lab server: `ssh lab` should work passwordless
  - Add your key to `~/.ssh/authorized_keys` on the server, then add a `lab` entry to `~/.ssh/config`
- [ ] GitHub CLI installed and authenticated: `gh auth login`
- [ ] Access to the 922-Studio GitHub org

## Clone the Repositories

Each project is an independent repo. Clone what you need. At minimum, clone the orchestrator:

```bash
mkdir -p ~/dev/922
cd ~/dev/922
git clone git@github.com:922-Studio/orchestrator.git orchestrator
# Then clone the projects you'll be working on, e.g.:
git clone git@github.com:922-Studio/HomeAPI.git HomeAPI
git clone git@github.com:922-Studio/HomeUI.git HomeUI
```

The workspace root (`~/dev/922`) does not need to be a git repo — it is intentionally not one.

## Set Up Root Workspace Files

The workspace root needs two things that are **not** in any of the project repos:

**Symlinks** (so orchestrator files are reachable without a path prefix):
```bash
cd ~/dev/922
ln -s orchestrator/registry.md registry.md
ln -s orchestrator/server.md server.md
```

**Root `CLAUDE.md`** — this is the universal rules file that loads for every session. It lives at `~/dev/922/CLAUDE.md`. Copy it from a teammate or restore from the orchestrator repo if it's tracked there. Without it, Claude won't know the worktree/PR workflow or orchestrator pointer.

**Workspace settings** at `~/dev/922/.claude/settings.local.json` — controls the permission allowlist for this workspace. Create the directory and file if missing:
```bash
mkdir -p ~/dev/922/.claude
# Then write or copy settings.local.json — see 05-settings-and-permissions.md for current contents
```

## Configure Global Claude Settings

Copy or create `~/.claude/settings.json`. At minimum set your preferred model:

```json
{
  "model": "opus",
  "includeCoAuthoredBy": false
}
```

See [05 — Settings and Permissions](05-settings-and-permissions.md) for the full current config.

## Open the Workspace in Zed

```
File → Open… → ~/dev/922
```

Open the Claude Code panel. Verify the session starts from `~/dev/922` (check the working directory shown in Claude Code).

## Smoke Test: Verify Context Loads

Ask Claude:

> "What does the orchestrator do, and where does the registry live?"

Expected answer: describes `orchestrator/` as the planning hub, mentions `registry.md` listing 14 projects. If Claude seems unaware of the workspace structure, the root `CLAUDE.md` may not have loaded — confirm you opened Zed at `~/dev/922`, not a subdirectory.

## Run a No-Op Plan

Pick an existing plan from `orchestrator/plans/` (not archive). Ask Claude to explain what Step 1 would do without executing it. This verifies:
- Plan files are readable
- Claude can load project mapping files from `orchestrator/projects/<name>.md`
- Execution overview format makes sense to you

## Verify SSH to Lab

```bash
ssh lab
# Should connect without a password prompt
sudo systemctl status traefik
# Should show service status
```

If this fails, check `orchestrator/server.md` for the expected hostname and key setup.

## Run `/fewer-permission-prompts`

After your first real work session, run this skill to add the commands you actually used to the allowlist:

```
/fewer-permission-prompts
```

Review the proposed additions before accepting.

## You're Ready When

- [ ] Claude correctly describes the orchestrator and registry in response to a cold question
- [ ] You can SSH to `lab` without a password
- [ ] You understand the worktree+PR flow (see [04 — Worktree & PR Flow](04-worktree-pr-flow.md))
- [ ] You've read `orchestrator/registry.md` and know which projects exist
- [ ] You've read `orchestrator/server.md` and know what runs on the lab
