# Decommission a project

Tear down a 922-Studio project safely — monitoring, infra, cross-service wiring, and docs —
in the order that avoids orphaned data and permanent false alerts.

Argument (optional): the project name (e.g. `/project-remove anime-tracker`).

Load and follow the playbook:

1. Read `/Users/gregor/dev/922/orchestrator/skills/project-lifecycle/remove.md`
2. Execute it, starting with Phase 1 audit.

Hard rules: present the full teardown table and wait for `execute` before any destructive
action; back up the DB before dropping it; never auto-delete the GitHub repo.
