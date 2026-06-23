# Entry commands

`project-new.md` and `project-remove.md` are the canonical, version-controlled source for
the two slash commands. Claude Code discovers slash commands from `~/.claude/commands/`,
which is outside this repo — so install (or update) them with:

```bash
cp skills/project-lifecycle/commands/project-new.md    ~/.claude/commands/project-new.md
cp skills/project-lifecycle/commands/project-remove.md  ~/.claude/commands/project-remove.md
```

After copying, `/project-new` and `/project-remove` are available as skills. Edit the files
here (tracked in git), then re-run the copy to roll the change out.
