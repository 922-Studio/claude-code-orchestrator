# 04 — Worktree & PR Flow

**Prev**: [03 — Orchestrator Workflow](03-orchestrator-workflow.md) | **Next**: [05 — Settings and Permissions](05-settings-and-permissions.md)

Every code-changing task runs in an isolated git worktree on a feature branch. **Never commit directly to a project's `main`.**

## Exact Commands

### 1. Create worktree + branch

```bash
# From the repo root (or use -C to target it)
git -C /Users/gregor/dev/922/<ProjectName> \
    worktree add \
    /Users/gregor/dev/922/<ProjectName>/.worktrees/<branch-name> \
    -b <branch-name>
```

Branch naming:
- Single step: `feat/<plan-slug>` (e.g. `feat/agent-setup-handover-docs`)
- Parallel steps in the same repo: `feat/<plan-slug>-step-<N>`

### 2. All edits happen inside the worktree

```bash
cd /Users/gregor/dev/922/<ProjectName>/.worktrees/<branch-name>
# edit, test, commit here
git commit -m "feat: <description>"
```

### 3. Push the branch

```bash
git push -u origin <branch-name>
```

### 4. Monitor CI

Watch the pipeline. If it goes red, fix and push again before opening the PR.

```bash
gh run list --branch <branch-name>
gh run watch <run-id>
```

### 5. Open the PR

```bash
gh pr create \
  --title "<title>" \
  --body "$(cat <<'EOF'
## Summary
- <bullet>

## Plan
orchestrator/plans/<plan-file>.md — Step <N>

## Test plan
- [ ] <test step>
EOF
)"
```

Report the PR URL back — a step is not complete without it.

### 6. Remove the worktree (on success only)

```bash
git -C /Users/gregor/dev/922/<ProjectName> worktree remove .worktrees/<branch-name>
```

**Do NOT delete the remote branch** — the PR owns it. The branch is cleaned up after merge.

## When to Leave the Worktree in Place

If a step is blocked or only partially done:
- Do NOT remove the worktree.
- Push whatever work exists (so it's not lost).
- Do NOT open the PR yet.
- Report the worktree path so Gregor can inspect or continue.

## Quick Reference

```
create worktree → edit inside worktree → push branch → CI green → gh pr create → get URL → remove worktree
                                                                                             (success only)
```
