#!/usr/bin/env bash
# install.sh — interactive installer for the Claude Code Orchestrator.
#
# Sets up this orchestrator on a machine: the local overlay + config, the ~/.claude
# routing (settings, statusline, slash-commands), project registry + live map, optional
# machine automations, and MIGRATION from an older orchestrator setup.
#
# Run it from the repo root:   bash install.sh
# Non-interactive smoke check: bash install.sh --check
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# ── ui helpers ───────────────────────────────────────────────────────────────
c() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
h1() { echo; c '1;36' "== $* =="; echo; }
ok() { c '32' "  ✓ $*"; echo; }
sk() { c '33' "  – $*"; echo; }
info() { echo "  $*"; }
ask() { local q="$1" d="${2:-}" a; read -r -p "  $q${d:+ [$d]}: " a; echo "${a:-$d}"; }
yes() { local a; read -r -p "  $1 (y/N): " a; [[ "$a" =~ ^[Yy] ]]; }

need() { command -v "$1" >/dev/null 2>&1; }
require_tools() {
  local miss=()
  for t in git jq python3; do need "$t" || miss+=("$t"); done
  if [ "${#miss[@]}" -gt 0 ]; then
    c '31' "  missing tools: ${miss[*]} — install them first (brew install ${miss[*]})"; echo
    return 1
  fi
}

# ── steps ────────────────────────────────────────────────────────────────────
step_overlay() { # CLAUDE.local.md — ecosystem/machine rules
  h1 "Local overlay (CLAUDE.local.md)"
  if [ -f CLAUDE.local.md ]; then ok "CLAUDE.local.md already exists — leaving it"; return; fi
  cp CLAUDE.local.md.example CLAUDE.local.md
  ok "created CLAUDE.local.md from the template"
  info "Edit it to describe THIS machine's ecosystem (registry/server/conventions)."
}

step_config() { # orchestrator.config.local.json — behavior overrides
  h1 "Behavior config (orchestrator.config.local.json)"
  if [ -f orchestrator.config.local.json ]; then ok "override already exists — leaving it"; return; fi
  local fmt mode base
  fmt="$(ask 'Plan format (html/md)' html)"
  mode="$(ask 'Execution mode (pr/autonomous/direct)' pr)"
  base="$(ask 'Base branch (dev/main)' dev)"
  cat > orchestrator.config.local.json <<EOF
{
  "plan_format":    { "value": "$fmt" },
  "execution_mode": { "value": "$mode" },
  "base_branch":    { "value": "$base" }
}
EOF
  ok "wrote orchestrator.config.local.json (merges over orchestrator.config.json)"
}

step_cc_settings() { # ~/.claude/settings.json
  h1 "Claude Code settings (~/.claude/settings.json)"
  need jq || { sk "jq not found — skipping (brew install jq, then re-run)"; return; }
  mkdir -p ~/.claude
  local tmp; tmp="$(mktemp)"
  sed "s|__HOME__|$HOME|g" setup/claude-code-settings/settings.template.json > "$tmp"
  if [ -f ~/.claude/settings.json ]; then
    cp ~/.claude/settings.json ~/.claude/settings.json.bak
    jq -s '.[0] * .[1]' ~/.claude/settings.json "$tmp" > ~/.claude/settings.json.new \
      && mv ~/.claude/settings.json.new ~/.claude/settings.json
    ok "merged baseline settings (backup: ~/.claude/settings.json.bak)"
  else
    cp "$tmp" ~/.claude/settings.json; ok "wrote ~/.claude/settings.json"
  fi
  rm -f "$tmp"
}

step_statusline() { # ~/.claude/statusline/ctx_monitor.js
  h1 "Context-monitor statusline"
  mkdir -p ~/.claude/statusline
  cp setup/claude-statusline/ctx_monitor.js ~/.claude/statusline/ctx_monitor.js
  ok "installed ~/.claude/statusline/ctx_monitor.js (wired via settings step)"
}

step_commands() { # ~/.claude/commands/*
  h1 "Orchestrator slash-commands (~/.claude/commands)"
  ORCH_ROOT="$ROOT" bash setup/orchestrator-commands/install.sh
}

step_projects() { # registry.md + projects/
  h1 "Projects & registry"
  mkdir -p projects
  if [ -f registry.md ]; then ok "registry.md exists — leaving it"; else
    cat > registry.md <<'EOF'
# Project Registry

> Add/remove projects with the lifecycle skill: `/project-new <name> like <ref>`,
> `/project-remove <name>`. This file is local-only (gitignored).

| # | Project | Path | Type | Status | Mapping |
|---|---------|------|------|--------|---------|
EOF
    ok "created a registry.md skeleton — populate it with /project-new"
  fi
}

step_map() { # plans/INDEX.md
  h1 "Live map & plan index"
  mkdir -p plans .planning/handover
  python3 scripts/build-plan-index.py || sk "index build skipped (no plans yet is fine)"
  info "Directory map: overview.md · capability catalog: CAPABILITIES.md"
}

step_automations() { # optional machine automations
  h1 "Optional machine automations"
  if yes "Install daily Homebrew auto-upgrade (launchd, macOS)?"; then
    ( cd "$ROOT" && bash -c 'SRC="$PWD/setup/brew-autoupgrade"; mkdir -p ~/.local/bin ~/Library/Logs;
      cp "$SRC/brew-autoupgrade.sh" ~/.local/bin/; chmod +x ~/.local/bin/brew-autoupgrade.sh;
      sed "s|__HOME__|$HOME|g" "$SRC/com.gregor.brew-autoupgrade.plist.template" > ~/Library/LaunchAgents/com.gregor.brew-autoupgrade.plist;
      launchctl unload ~/Library/LaunchAgents/com.gregor.brew-autoupgrade.plist 2>/dev/null;
      launchctl load -w ~/Library/LaunchAgents/com.gregor.brew-autoupgrade.plist' ) \
      && ok "brew-autoupgrade installed" || sk "brew-autoupgrade failed (see setup/brew-autoupgrade/SETUP.md)"
  else sk "skipped brew-autoupgrade"; fi
  if yes "Put repo-sync on PATH (~/.local/bin/repo-sync)?"; then
    chmod +x setup/repo-sync/repo-sync.sh; mkdir -p ~/.local/bin
    ln -sf "$ROOT/setup/repo-sync/repo-sync.sh" ~/.local/bin/repo-sync; ok "repo-sync linked"
  else sk "skipped repo-sync"; fi
  if yes "Install periodic reminders (launchd, macOS; incl. weekly /token-diet nudge)?"; then
    ( cd "$ROOT" && ORCH_ROOT="$ROOT" bash setup/reminders/install.sh ) \
      && ok "reminders installed" || sk "reminders failed (see setup/reminders/SETUP.md)"
  else sk "skipped reminders"; fi
}

step_provision() { # git hooks that auto-adopt setup changes on every pull
  h1 "Auto-provisioning (adopt setup changes on every pull)"
  if yes "Install git hooks so future pulls auto-apply setup changes?"; then
    ( cd "$ROOT" && bash setup/provision/provision.sh ) \
      && ok "provisioning installed + applied" || sk "provision failed (see setup/provision/SETUP.md)"
  else sk "skipped auto-provisioning"; fi
}

step_migrate() { # import from an old orchestrator
  h1 "Migrate from an existing orchestrator"
  local old; old="$(ask 'Path to the OLD orchestrator directory')"
  [ -d "$old" ] || { c '31' "  not a directory: $old"; echo; return 1; }
  info "Importing ecosystem data (won't overwrite files that already exist here)…"
  # data dirs / files — copy if present in old and absent here
  for p in registry.md server.md server-name-ideas.json projects dashboards ideas \
           plans hub/plans hub/learnings hub/discussions .planning; do
    if [ -e "$old/$p" ]; then
      mkdir -p "$(dirname "$p")"
      cp -Rn "$old/$p" "$(dirname "$p")/" 2>/dev/null && ok "imported $p" || sk "$p (kept existing)"
    fi
  done
  # old planning/<topic>/ layout -> plans/ (flat copy of files, preserved)
  if [ -d "$old/planning" ] && [ ! -e plans/_imported-planning ]; then
    mkdir -p plans/_imported-planning
    cp -Rn "$old/planning/." plans/_imported-planning/ 2>/dev/null && ok "imported old planning/ -> plans/_imported-planning/"
  fi
  # personal/machine setups -> setup/local/ (kept out of the shared framework)
  if [ -d "$old/setup" ]; then
    for d in "$old"/setup/*/; do
      id="$(basename "$d")"; [ -e "setup/$id" ] && continue
      cp -Rn "$d" "setup/local/$id" 2>/dev/null && ok "imported setup/$id -> setup/local/$id"
    done
  fi
  # old reports/ automations -> setup/local/reports
  [ -d "$old/reports" ] && cp -Rn "$old/reports" setup/local/reports 2>/dev/null && ok "imported reports/ -> setup/local/reports"
  # old CLAUDE.md rules -> CLAUDE.local.md (if we don't have one yet)
  if [ -f "$old/CLAUDE.md" ] && [ ! -f CLAUDE.local.md ]; then
    { echo "# Orchestrator — Local Overlay (migrated $(date +%F))"; echo;
      echo "> Imported from the previous orchestrator's CLAUDE.md. Trim to ecosystem-specific rules;";
      echo "> generic framework rules already live in the committed CLAUDE.md."; echo; echo '---'; echo;
      cat "$old/CLAUDE.md"; } > CLAUDE.local.md
    ok "seeded CLAUDE.local.md from the old CLAUDE.md (review & trim)"
  fi
  info "Review: CLAUDE.local.md, setup/local/, plans/_imported-planning/. Then rebuild the index."
}

run_all() { step_migrate_opt=""; step_overlay; step_config; step_cc_settings; step_statusline; step_commands; step_projects; step_map; step_automations; step_provision; }

menu() {
  h1 "Claude Code Orchestrator — installer"
  info "root: $ROOT"
  echo "  1) Fresh install (guided: overlay, config, .claude, projects, map, automations)"
  echo "  2) Migrate from an existing orchestrator, then finish the fresh steps"
  echo "  3) Custom — pick individual steps"
  echo "  4) Quit"
  local m; m="$(ask 'Choose' 1)"
  case "$m" in
    1) run_all ;;
    2) step_migrate; step_overlay; step_config; step_cc_settings; step_statusline; step_commands; step_map ;;
    3) custom ;;
    *) exit 0 ;;
  esac
  h1 "Done"
  info "Restart Claude Code to pick up settings/commands."
  info "Then launch Claude Code in this repo and paste the post-install prompt to finish setup:"
  c '1;36' "    prompts/post-install-setup.md"; echo
  info "(orient · verify · fill CLAUDE.local.md · registry · MCP · build the map). Explore: overview.md"
}

custom() {
  h1 "Custom — enter numbers separated by spaces"
  echo "  1 overlay  2 config  3 cc-settings  4 statusline  5 commands  6 projects  7 map  8 automations  9 migrate  10 provision"
  local sel; sel="$(ask 'Steps')"
  for n in $sel; do case "$n" in
    1) step_overlay;; 2) step_config;; 3) step_cc_settings;; 4) step_statusline;;
    5) step_commands;; 6) step_projects;; 7) step_map;; 8) step_automations;; 9) step_migrate;; 10) step_provision;;
  esac; done
}

# ── entry ────────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--check" ]; then
  require_tools && echo "install.sh: syntax OK, tools present" || exit 1
  exit 0
fi
require_tools || { yes "Continue anyway?" || exit 1; }
menu
