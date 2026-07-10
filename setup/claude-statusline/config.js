#!/usr/bin/env node
"use strict";

// ============================================================================
// config.js — load / merge / save the per-directory statusline config.
//
// File shape (segments.config.json), version 2:
//   {
//     "version": 2,
//     "defaults":    { "enabled": {segId:bool}, "variants": {segId:variantId} },
//     "directories": { "<abs-dir>": { "enabled": {...}, "variants": {...} } }
//   }
//
// A "scope" (defaults, or one directory) holds two maps: `enabled` (show/hide
// per segment) and `variants` (chosen display mode for segments that offer one,
// e.g. context: pct / num / num_max / pct_num / pct_num_max).
//
// EFFECTIVE value for a scope, most→least specific:
//   directory override  ??  global default override  ??  registry default
// Anything missing at every level falls through to the registry default, so
// NEW segments/variants light up automatically for every pre-existing config
// and nothing old is destroyed. Directory match is longest-prefix, so a parent
// dir cascades to its children unless a child overrides.
//
// v1 configs (a flat {segId:bool} per scope, no variants) are migrated on read
// into the v2 shape without losing any enable choices — see normalizeScope().
// ============================================================================

const fs = require("fs");
const path = require("path");
const { SEGMENTS } = require("./segments");

const CONFIG_PATH =
  process.env.CLAUDE_STATUSLINE_CONFIG ||
  `${process.env.HOME}/.claude/statusline/segments.config.json`;

const CURRENT_VERSION = 2;

// Registry defaults as an effective scope: {enabled, variants}.
function registryDefaults() {
  const enabled = {};
  const variants = {};
  for (const s of SEGMENTS) {
    enabled[s.id] = s.default;
    if (s.variants && s.defaultVariant) variants[s.id] = s.defaultVariant;
  }
  return { enabled, variants };
}

function readRaw() {
  try {
    return JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
  } catch {
    return null;
  }
}

// Coerce any scope object (v1 flat or v2 nested) into {enabled, variants},
// preserving unknown keys on v2 objects (forward-compat with newer panels).
function normalizeScope(obj) {
  if (!obj || typeof obj !== "object") return { enabled: {}, variants: {} };
  if ("enabled" in obj || "variants" in obj) {
    if (!obj.enabled || typeof obj.enabled !== "object") obj.enabled = {};
    if (!obj.variants || typeof obj.variants !== "object") obj.variants = {};
    return obj;
  }
  // v1 flat: bare {segId:bool}
  const enabled = {};
  for (const [k, v] of Object.entries(obj)) if (typeof v === "boolean") enabled[k] = v;
  return { enabled, variants: {} };
}

// Bring any config (old, partial, or empty) up to the current shape WITHOUT
// dropping enable choices — future-proofing across versions.
function migrate(cfg) {
  if (!cfg || typeof cfg !== "object") {
    return { version: CURRENT_VERSION, defaults: { enabled: {}, variants: {} }, directories: {} };
  }
  cfg.version = CURRENT_VERSION;
  cfg.defaults = normalizeScope(cfg.defaults);
  const dirs = cfg.directories && typeof cfg.directories === "object" ? cfg.directories : {};
  cfg.directories = {};
  for (const [k, v] of Object.entries(dirs)) cfg.directories[k] = normalizeScope(v);
  return cfg;
}

function loadConfig() {
  return migrate(readRaw());
}

// Longest directory key that is `cwd` itself or a parent of it.
function bestDirKey(cfg, cwd) {
  let best = null;
  for (const key of Object.keys(cfg.directories || {})) {
    const parent = key.endsWith("/") ? key : key + "/";
    if (cwd === key || cwd.startsWith(parent)) {
      if (!best || key.length > best.length) best = key;
    }
  }
  return best;
}

// The resolved {enabled:{segId:bool}, variants:{segId:variantId}} for a cwd.
function loadEffectiveConfig(cwd) {
  const cfg = loadConfig();
  const reg = registryDefaults();
  const enabled = { ...reg.enabled, ...cfg.defaults.enabled };
  const variants = { ...reg.variants, ...cfg.defaults.variants };
  const dk = bestDirKey(cfg, cwd || "");
  if (dk) {
    Object.assign(enabled, cfg.directories[dk].enabled);
    Object.assign(variants, cfg.directories[dk].variants);
  }
  for (const k of Object.keys(enabled)) if (typeof enabled[k] !== "boolean") delete enabled[k];
  for (const k of Object.keys(variants)) if (typeof variants[k] !== "string") delete variants[k];
  return { enabled, variants };
}

// Merge a partial {enabled, variants} into a scope ("defaults" or a dir path),
// preserving every other key/scope. Returns the saved config.
function applyOverride(scope, patch) {
  const cfg = loadConfig();
  const target =
    scope === "defaults"
      ? cfg.defaults
      : (cfg.directories[scope] = normalizeScope(cfg.directories[scope]));

  const en = {};
  for (const [k, v] of Object.entries(patch?.enabled || {})) if (typeof v === "boolean") en[k] = v;
  const va = {};
  for (const [k, v] of Object.entries(patch?.variants || {})) if (typeof v === "string") va[k] = v;

  target.enabled = { ...target.enabled, ...en };
  target.variants = { ...target.variants, ...va };
  saveConfig(cfg);
  return cfg;
}

// Drop a scope's overrides entirely (revert it to defaults/registry).
function clearDirectory(scope) {
  const cfg = loadConfig();
  if (scope === "defaults") cfg.defaults = { enabled: {}, variants: {} };
  else delete cfg.directories[scope];
  saveConfig(cfg);
  return cfg;
}

function saveConfig(cfg) {
  cfg.version = CURRENT_VERSION;
  fs.mkdirSync(path.dirname(CONFIG_PATH), { recursive: true });
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 2) + "\n");
}

module.exports = {
  CONFIG_PATH,
  CURRENT_VERSION,
  registryDefaults,
  loadConfig,
  loadEffectiveConfig,
  bestDirKey,
  applyOverride,
  clearDirectory,
  saveConfig,
};
