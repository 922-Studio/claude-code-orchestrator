---
description: Open the statusline control panel for the current directory
---

# Edit Statusline

Open the interactive statusline control panel, scoped to the directory this session is running in.

Run the launcher, substituting the session's current working directory for `<cwd>`:

```bash
bash ~/.claude/statusline/open-panel.sh "<cwd>"
```

It starts the panel server if it isn't already running (idempotent — never spawns a second one)
and opens the browser pre-filled with `<cwd>`. Report the URL it prints back as a clickable link.

Then let the user know: toggle the segments they want, press **Apply**, and the bar updates on the
next turn — no restart. The panel manages this directory by default; they can switch to **Global
default** in the panel to change the baseline for every directory.
